-- Exercise REAL System2 own-census pure logic and iPad runner under Lune.
-- All Roblox services, profile reads, GUI objects, clocks and networking MOCKED.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local coreCode=fs.readFile("pdiddler/system2/native_own_census_core.lua")
local runnerCode=fs.readFile("pdiddler/system2/SYSTEM2_OWN_CENSUS_READONLY_NATIVE.lua")
local geometryCode=fs.readFile("pdiddler/new_part4/stage100_screen_prompt_overlay.lua")
local tests=0
local function check(v,tag)
    tests+=1
    assert(v,tag)
end
local function eq(a,b,tag)
    tests+=1
    assert(a==b,tag..": "..tostring(a).." != "..tostring(b))
end
local core=luau.load(coreCode)()
local function profile(items)
    return {ProfileData={Weapons={Owned=items}}}
end
local function pure()
    local a,ra=core.observe(profile({Celestial=2,CommonKnife="1"}),
        "FAKE_JOB_0001",100)
    eq(ra.status,"CLIENT_CENSUS_SNAPSHOT_ONLY","first read")
    eq(ra.rawDistinctKeysObserved,2,"distinct")
    eq(ra.rawCopiesObserved,3,"copies")
    local b=core.observe(profile({CommonKnife=1,Celestial=2}),
        "FAKE_JOB_0001",103)
    local same=core.compare(a,b)
    eq(same.status,"CLIENT_TWO_READS_STABLE","key ordering stable")
    eq(same.clientCensusChanged,false,"no mutation")
    eq(same.serverInventoryAuthoritative,false,"not proof")
    eq(same.authorizesTrade,false,"never trade")
    eq(same.authorizesAccept,false,"never accept")
    check(not tostring(same):find("Celestial",1,true),"no key leaked")
    local change=core.observe(profile({Celestial=3,CommonKnife=1}),
        "FAKE_JOB_0001",103)
    eq(core.compare(a,change).status,"CLIENT_TWO_READS_DIFFERENT",
        "single quantity changed")
    local added=core.observe(profile({Celestial=2,CommonKnife=1,OtherKey=1}),
        "FAKE_JOB_0001",103)
    eq(core.compare(a,added).clientCensusChanged,true,
        "added distinct item changes census")
    eq(core.compare(a,core.observe(profile({Celestial=2}),
        "NEW_JOB_9999",103)).reason,"CLIENT_GAME_JOB_CHANGED","job bound")
    local tooSoon=core.observe(profile({Celestial=2}),
        "FAKE_JOB_0001",101)
    eq(core.compare(a,tooSoon).status,"BLOCKED","2sec minimum")
    local tooOld=core.observe(profile({Celestial=2}),
        "FAKE_JOB_0001",161)
    eq(core.compare(a,tooOld).reason,"TWO_READS_TIMING_WINDOW_INVALID","60s max")
    local zero,zr=core.observe(profile({Unused=0,Celestial=2}),
        "FAKE_JOB_0001",100)
    eq(zero.distinct,1,"zero count ignored")
    for _,items in ipairs({
        {Celestial=-1},{Celestial=1.5},{Celestial="1e9"},
        {Celestial=true},{Celestial=1000001},
    }) do
        local stamp,result=core.observe(profile(items),"FAKE_JOB_0001",100)
        eq(stamp,nil,"bad profile not admitted")
        eq(result.status,"BLOCKED","bad quantity blocks")
    end
    local bogus,bad=core.observe(profile({["not/a/key"]=1}),
        "FAKE_JOB_0001",100)
    eq(bogus,nil,"bad raw key denied")
    eq(bad.reason,"RAW_GAME_CENSUS_KEY_INVALID","explicit reason")
    eq(core.observe(profile({Celestial=1}),"NO",100),nil,"short job denied")
    eq(core.observe({Weapons={}},"FAKE_JOB_0001",100),nil,"missing Owned")
end
pure()
local function event()
    local handlers={}
    local o={}
    function o:Connect(fn)
        local h={fn=fn,live=true}
        handlers[#handlers+1]=h
        return {Disconnect=function()h.live=false end}
    end
    function o:Fire(...)
        for _,h in ipairs(handlers) do
            if h.live then h.fn(...) end
        end
    end
    return o
end
local function node(class,name)
    local o={Name=name or class,ClassName=class,children={},
        Enabled=false,Visible=true,Active=false,Text="",
        AbsolutePosition={X=0,Y=0},AbsoluteSize={X=0,Y=0},
        Activated=event()}
    function o:IsA(x)return x==self.ClassName end
    function o:FindFirstChild(x)return self.children[x] end
    function o:FindFirstChildOfClass(x)
        for _,item in pairs(self.children) do
            if item:IsA(x) then return item end
        end
    end
    function o:put(child)
        self.children[child.Name]=child;child.Parent=self;return child
    end
    function o:Destroy()
        self.Parent=nil;self.Visible=false;self.destroyed=true
    end
    return o
end
local function mock(options)
    options=options or {}
    local now=100
    local pg=node("PlayerGui","PlayerGui")
    local sg=pg:put(node("ScreenGui","TradeGUI"))
    local container=sg:put(node("Frame","Container"))
    local trade=container:put(node("Frame","Trade"))
    sg.Enabled=options.tradeOpen==true
    trade.Visible=true
    container.Visible=true
    local players={LocalPlayer={}}
    function players.LocalPlayer:FindFirstChildOfClass(t)
        if t=="PlayerGui" then return pg end
    end
    local world={CurrentCamera={ViewportSize={X=options.width or 1180,
                                             Y=options.height or 820}}}
    local heartbeat=event()
    local reads=0
    local remote=node("RemoteFunction","GetProfileData")
    function remote:InvokeServer()
        reads+=1
        if options.failRemote then error("blocked fake read") end
        return (options.profiles or {
            profile({Celestial=2,CommonKnife=1}),
            profile({CommonKnife=1,Celestial=2}),
        })[math.min(reads,2)]
    end
    local rs=node("ReplicatedStorage","ReplicatedStorage")
    local remotes=rs:put(node("Folder","Remotes"))
    remotes:put(node("Folder","Inventory")):put(remote)
    if options.noRemote then remotes.children.Inventory.children.GetProfileData=nil end
    local services={Players=players,Workspace=world,RunService={Heartbeat=heartbeat},
        HttpService={JSONEncode=function(_,v)return serde.encode("json",v)end},
        ReplicatedStorage=rs}
    local game={PlaceId=options.wrongPlace and 1 or 142823291,
        JobId="FAKE_JOB_0001"}
    local readsSource=0
    function game:GetService(k)return services[k]end
    function game:HttpGet(url)
        readsSource+=1
        if options.failSource then error("source unavailable") end
        if string.find(url,"native_own_census_core.lua",1,true) then
            check(string.find(url,"85a633eb54010e0b2aba770e857bccf0d33e8b21",1,true)~=nil,
                "source pin expected")
            return coreCode
        end
        if string.find(url,"stage100_screen_prompt_overlay.lua",1,true) then
            return geometryCode
        end
        error("unexpected source")
    end
    local instances={}
    local instance={new=function(class)
        if options.failUI and class=="ScreenGui" then error("UI failure") end
        local v=node(class)
        instances[#instances+1]=v
        return v
    end}
    local E=options.E or {}
    local clipboard={}
    local env={
        game=game,getgenv=function()return E end,
        Instance=instance,
        Enum={ZIndexBehavior={Sibling="Sibling"},
              TextXAlignment={Left="Left"},Font={GothamBold="GothamBold"}},
        UDim={new=function(...)return {...}end},
        UDim2={fromOffset=function(...)return {...}end},
        Color3={fromRGB=function(...)return {...}end},
        print=function()end,warn=function()end,
        setclipboard=function(s)clipboard[#clipboard+1]=s end,
        os={clock=function()return now end},
        task={spawn=function(fn)fn()end,wait=function()end},
    }
    env.loadstring=function(raw)
        return luau.load(raw,{environment=env,injectGlobals=true})
    end
    local function run()
        return luau.load(runnerCode,{environment=env,injectGlobals=true})()
    end
    local function btn(name)
        for _,obj in ipairs(instances) do
            if obj.Name==name then return obj end
        end
    end
    return {run=run,btn=btn,clipboard=clipboard,E=E,
        profileReads=function()return reads end,
        sources=function()return readsSource end,
        clock=function(v)now=v end,
        openTrade=function()sg.Enabled=true end,
        resize=function(w,h)world.CurrentCamera.ViewportSize={X=w,Y=h}end,
        pulse=function()heartbeat:Fire()end,
        screen=pg}
end
do
    local x=mock()
    local control=x.run()
    check(type(control)=="table","actual runner mounted")
    eq(x.sources(),2,"exact two pinned source requests")
    eq(x.profileReads(),0,"no own inventory requested on start")
    local cap=x.btn("ManualCapture")
    local stop=x.btn("StopCopy")
    check(cap and stop,"physical UI buttons created")
    eq(cap.Text,"CAPTURE 1","first on-screen instruction")
    check(cap.Visible and cap.Active,"first capture tap enabled")
    cap.Activated:Fire()
    eq(x.profileReads(),1,"exactly one first RemoteFunction read")
    eq(cap.Text,"CAPTURE 2","second instruction")
    cap.Activated:Fire()
    eq(x.profileReads(),1,"early second tap cannot read")
    x.clock(103)
    cap.Activated:Fire()
    eq(x.profileReads(),2,"manual second read only")
    eq(control.status().status,"CLIENT_TWO_READS_STABLE","native stable result")
    eq(x.btn("ManualCapture").Active,false,"no third capture")
    eq(stop.Text,"COPY / CLOSE","terminal on-screen copy action")
    stop.Activated:Fire()
    eq(#x.clipboard,1,"sanitized evidence copied")
    local result=serde.decode("json",x.clipboard[1])
    eq(result.status,"CLIENT_TWO_READS_STABLE","clipboard state")
    eq(result.serverInventoryAuthoritative,false,"no authority")
    check(not x.clipboard[1]:find("Celestial",1,true),"never clipboard raw item")
    check(not x.clipboard[1]:find("FAKE_JOB_",1,true),"never clipboard JobId")
    eq(result.actualOffers,0,"no offers")
    eq(result.authorizesAccept,false,"no accept")
    eq(x.run(),nil,"same job cannot rerun")
end
do
    local x=mock({profiles={profile({Celestial=2}),profile({Celestial=3})}})
    local control=x.run()
    x.btn("ManualCapture").Activated:Fire()
    x.clock(105)
    x.btn("ManualCapture").Activated:Fire()
    eq(control.status().status,"CLIENT_TWO_READS_DIFFERENT","changed census")
    eq(control.status().clientCensusChanged,true,"local delta detected")
    eq(control.status().researchDecisionReusable,false,"no stale use")
end
do
    local x=mock({noRemote=true})
    local c=x.run()
    x.btn("ManualCapture").Activated:Fire()
    eq(c.status().status,"BLOCKED","missing read-only remote fail closed")
    eq(c.status().authorizesOffer,false,"no offers on failure")
end
do
    local x=mock({failRemote=true})
    local c=x.run()
    x.btn("ManualCapture").Activated:Fire()
    eq(c.status().reason,"PROFILE_READ_FAILED","RPC fail closed")
end
do
    local x=mock({profiles={profile({Celestial=math.huge})}})
    local c=x.run()
    x.btn("ManualCapture").Activated:Fire()
    eq(c.status().reason,"RAW_GAME_CENSUS_QUANTITY_INVALID","invalid response")
end
do
    local x=mock({tradeOpen=true})
    eq(x.run(),nil,"no native test started with active trade window")
    eq(x.profileReads(),0,"no RPC while active trade")
end
do
    local x=mock()
    local c=x.run()
    x.openTrade()
    x.pulse()
    eq(c.status().status,"BLOCKED","trade GUI appeared mid-test")
    eq(x.profileReads(),0,"no remote after trade appeared")
end
do
    local x=mock({width=320,height=250})
    eq(x.run(),nil,"tiny viewport cannot show safe panel")
    eq(x.profileReads(),0,"no remote on unsafe viewport")
end
do
    local x=mock({failUI=true})
    eq(x.run(),nil,"UI creation fails before any remote read")
    eq(x.profileReads(),0,"no UI no inventory RPC")
end
do
    local x=mock({failSource=true})
    eq(x.run(),nil,"missing source pins fail closed")
    eq(x.profileReads(),0,"no source no RPC")
end
do
    local x=mock({wrongPlace=true})
    eq(x.run(),nil,"original MM2 place only")
    eq(x.sources(),0,"wrong place no network")
end
do
    local x=mock({E={PDIDDLER_AUTOTRADE_ACTIVE=true}})
    eq(x.run(),nil,"running trading script conflicts")
    eq(x.sources(),0,"conflict blocks before any fetch")
end
print("[PASS] System2 real native own-census runner and pure core tests: "..tostring(tests))
