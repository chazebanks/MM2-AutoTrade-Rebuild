-- Actual System2 multi-feature catalog classifier and real native UI runner:
-- mocked Roblox only. No real MM2 requests or device interactions.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local coreCode=fs.readFile("pdiddler/system2/native_multifeature_catalog_core.lua")
local runnerCode=fs.readFile("pdiddler/system2/SYSTEM2_MULTIFEATURE_READONLY_NATIVE.lua")
local geometryCode=fs.readFile("pdiddler/new_part4/stage100_screen_prompt_overlay.lua")
local tests=0
local function eq(a,b,name)
    tests+=1
    assert(a==b,name..": "..tostring(a).." != "..tostring(b))
end
local function ok(a,name)
    tests+=1;assert(a,name)
end
local core=luau.load(coreCode)()
local function profile(items)
    return {ProfileData={Weapons={Owned=items}}}
end
local SAMPLE_OWN={
    Celestial=2,EmberbowChroma=6,ChromaAncientTest=1,
    CommonKnife=4,Reaver_Ancient=1,UnknownBlob=3,
    Emptybringer=1,BattleRifle=2,MalformedKnife=1,GhostZero=0,
}
local SAMPLE_SYNC={Weapons={
    Celestial={ItemName="Celestial",ItemType="Knife",Rarity="Ancient"},
    EmberbowChroma={ItemName="Emberbow",ItemType="Gun",Rarity="Godly",Chroma=true},
    ChromaAncientTest={ItemName="Travellers Axe",ItemType="Knife",Rarity="Ancient",Chroma=true},
    CommonKnife={ItemName="Common Knife",ItemType="Knife",Rarity="Common"},
    Reaver_Ancient={ItemName="Reaver",ItemType="Knife",Rarity="Ancient",EvoIndex=2},
    Emptybringer={ItemName="???",ItemType="Gun",Rarity="Godly"},
    BattleRifle={ItemName="Battle Rifle",ItemType="Gun",Rarity="Godly"},
    MalformedKnife={ItemName="bad",Rarity="Godly"},
},Item={
    BattleRifle={ItemName="Battle Rifle",ItemType="Gun",Rarity="Ancient"},
}}
local function pure()
    local report=core.assess(profile(SAMPLE_OWN),SAMPLE_SYNC,"FAKE_JOB_001",10,10.5)
    eq(report.status,"CLIENT_MULTI_FEATURE_REPORT","full report")
    eq(report.features.ownCensus.status,"PASS_CLIENT_ONLY","full census")
    eq(report.features.ownCensus.keys,9,"nine nonzero keys")
    eq(report.features.ownCensus.copies,21,"raw copies")
    eq(report.features.classification.ancientKeys,1,"Ancient exact")
    eq(report.features.classification.godlyKeys,0,"Godly counted separately")
    eq(report.features.classification.chromaGodlyKeys,1,"Chroma Godly")
    eq(report.features.classification.chromaAncientKeys,1,"Chroma Ancient")
    eq(report.features.classification.eligibleKeys,3,"eligible keys")
    eq(report.features.classification.eligibleCopies,9,"eligible copies")
    eq(report.features.classification.excludedKeys,3,"ordinary evo placeholder")
    eq(report.features.classification.excludedCopies,6,"excluded copies")
    eq(report.features.classification.unknownKeys,3,"unmapped conflicting malformed")
    eq(report.features.classification.unknownCopies,6,"unknown copies")
    eq(report.features.metadata.unmappedKeys,1,"unmapped")
    eq(report.features.metadata.conflictingKeys,1,"conflicting")
    eq(report.features.metadata.malformedKeys,1,"malformed")
    eq(report.features.integrity.bucketsReconciled,true,"reconciliation")
    eq(report.features.publisher.currentVerifiedPriceSource,false,"not a market quote")
    eq(report.authorizesAccept,false,"no Accept")
    eq(report.liveOfferRankingAuthorized,false,"no live ranking")
    ok(not serde.encode("json",report):find("Celestial",1,true),"no weapon raw leaked")
    ok(not serde.encode("json",report):find("FAKE_JOB_",1,true),"no JobId leaked")
    local missing=core.assess(profile(SAMPLE_OWN),nil,"FAKE_JOB_001",10,10.1)
    eq(missing.status,"CLIENT_MULTI_FEATURE_REPORT","missing metadata not fake global failure")
    eq(missing.features.metadata.status,"INCONCLUSIVE_SYNC_UNAVAILABLE","catalog unknown explicitly")
    eq(missing.features.classification.unknownKeys,9,"unavailable cannot imply classifications")
    local changed=core.assess(profile({A=1}),{Weapons={
        A={ItemName="A",ItemType="Gun",Rarity="Godly"}
    }},"FAKE_JOB_001",10,10)
    eq(changed.features.classification.godlyKeys,1,"Godly category branch")
    local other=core.assess(profile({A=1}),{Weapons={
        A={ItemName="A",ItemType="Pet",Rarity="Godly"}
    }},"FAKE_JOB_001",10,10)
    eq(other.features.classification.excludedKeys,1,"non-weapon category excluded")
    -- Original P3 scanner excludes explicit non-tradable weapon metadata.
    for _,flag in ipairs({"Tradable","CanTrade","Untradable","NonTradable"}) do
        local d={ItemName="Blocked",ItemType="Gun",Rarity="Godly"}
        d[flag]=(flag=="Tradable" or flag=="CanTrade") and false or true
        local out=core.assess(profile({A=1}),{Weapons={A=d}},"FAKE_JOB_001",10,10)
        eq(out.features.classification.eligibleKeys,0,flag.." not eligible")
        eq(out.features.classification.excludedKeys,1,flag.." excluded")
        eq(out.features.integrity.bucketsReconciled,true,flag.." buckets")
    end
    local conflict=core.assess(profile({A=1}),{
        Weapons={A={ItemName="A",ItemType="Gun",Rarity="Godly",Tradable=false}},
        Item={A={ItemName="A",ItemType="Gun",Rarity="Godly",Tradable=true}}
    },"FAKE_JOB_001",10,10)
    eq(conflict.features.metadata.conflictingKeys,1,"conflicting tradeability rejected")
    eq(conflict.features.classification.eligibleKeys,0,"conflict never promotes eligible")

    local both={Weapons={A={ItemName="A",ItemType="Gun",Rarity="Godly"}},
                Item={A={ItemName="A",ItemType="Gun",Rarity="Godly"}}}
    eq(core.assess(profile({A=2}),both,"FAKE_JOB_001",10,10).features.classification.eligibleCopies,
        2,"equivalent duplicate sources match")
    local bads={{A=-1},{A=1.5},{A=true},{A="4.5"},{A=1000001}}
    for _,item in ipairs(bads) do
        eq(core.assess(profile(item),SAMPLE_SYNC,"FAKE_JOB_001",10,10).status,
            "BLOCKED","hostile quantity rejected")
    end
    eq(core.assess(profile({["bad/id"]=1}),SAMPLE_SYNC,"FAKE_JOB_001",10,10).reason,
        "CENSUS_RAW_KEY_INVALID","hostile raw ID rejected")
    eq(core.assess(profile({A=1}),SAMPLE_SYNC,"FAKE_JOB_001",10,26).reason,
        "SESSION_OR_READ_AGE_INVALID","stale read")
    eq(core.assess(profile({A=1}),SAMPLE_SYNC,"FAKE_JOB_001",11,10).status,
        "BLOCKED","clock rollback")
    eq(core.assess(profile({A=1}),SAMPLE_SYNC,"short",10,10).status,
        "BLOCKED","job missing")
    eq(core.assess({Weapons={}},SAMPLE_SYNC,"FAKE_JOB_001",10,10).status,
        "BLOCKED","owned missing")
    local huge={}
    for i=1,4001 do huge["Zero_"..tostring(i)]=0 end
    eq(core.assess(profile(huge),SAMPLE_SYNC,"FAKE_JOB_001",10,10).reason,
        "CENSUS_RAW_ENTRIES_LIMIT","zero-only oversize denied")
    local zero=core.assess(profile({A=0}),SAMPLE_SYNC,"FAKE_JOB_001",10,10)
    eq(zero.features.ownCensus.copies,0,"zero copy rows ignored")
end
pure()
local function event()
    local handlers={}
    local o={}
    function o:Connect(fn)
        local sub={fn=fn,live=true}
        handlers[#handlers+1]=sub
        return {Disconnect=function()sub.live=false end}
    end
    function o:Fire(...)
        for _,h in ipairs(handlers) do if h.live then h.fn(...) end end
    end
    return o
end
local function node(class,name)
    local v={ClassName=class,Name=name or class,children={},
             Visible=true,Enabled=false,Active=false,Text="",
             Activated=event()}
    function v:IsA(k)return k==self.ClassName end
    function v:FindFirstChild(k)return self.children[k] end
    function v:FindFirstChildOfClass(k)
        for _,x in pairs(self.children) do if x:IsA(k) then return x end end
    end
    function v:put(x)x.Parent=self;self.children[x.Name]=x;return x end
    function v:Destroy()self.Parent=nil;self.Visible=false;self.destroyed=true end
    return v
end
local function mock(opts)
    opts=opts or {}
    local now=100
    local pg=node("PlayerGui","PlayerGui")
    local tradeScreen=pg:put(node("ScreenGui","TradeGUI"))
    local container=tradeScreen:put(node("Frame","Container"))
    container:put(node("Frame","Trade"))
    tradeScreen.Enabled=opts.tradeOpen==true
    container.Visible=true
    local players={LocalPlayer={}}
    function players.LocalPlayer:FindFirstChildOfClass(typ)
        if typ=="PlayerGui" then return pg end
    end
    local world={CurrentCamera={ViewportSize={X=opts.width or 1180,Y=opts.height or 820}}}
    local hb=event()
    local reads=0
    local rs=node("ReplicatedStorage","ReplicatedStorage")
    local remote=rs:put(node("Folder","Remotes")):put(node("Folder","Inventory")):put(node("RemoteFunction","GetProfileData"))
    function remote:InvokeServer()
        reads+=1
        if opts.remoteFailure then error("profile denied") end
        return opts.profile or profile(SAMPLE_OWN)
    end
    local db=rs:put(node("Folder","Database"))
    local syncModule=db:put(node("ModuleScript","Sync"))
    if opts.noSync then db.children.Sync=nil end
    if opts.noRemote then
        rs.children.Remotes.children.Inventory.children.GetProfileData=nil
    end
    local services={Players=players,Workspace=world,RunService={Heartbeat=hb},
        ReplicatedStorage=rs,
        HttpService={JSONEncode=function(_,v)return serde.encode("json",v)end}}
    local game={JobId="FAKE_JOB_001",PlaceId=opts.wrongPlace and 9 or 142823291}
    local sourceFetches=0
    function game:GetService(x)return services[x] end
    function game:HttpGet(url)
        sourceFetches+=1
        if opts.sourceFailure then error("no GitHub source") end
        if url:find("native_multifeature_catalog_core.lua",1,true) then
            ok(url:find("139311e7eb5dc8d155652218ac1acc30e33955c5",1,true)~=nil,"core source pinned")
            return coreCode
        elseif url:find("stage100_screen_prompt_overlay.lua",1,true) then
            return geometryCode
        end
        error("unexpected source URL")
    end
    local objs={}
    local Instance={new=function(class)
        if opts.uiFailure and class=="ScreenGui" then error("UI denied") end
        local v=node(class);objs[#objs+1]=v;return v
    end}
    local E=opts.E or {}
    local copied={}
    local env={
        game=game,getgenv=function()return E end,
        Instance=Instance,
        Enum={ZIndexBehavior={Sibling="Sibling"},
              TextXAlignment={Left="Left"},Font={GothamBold="GothamBold"}},
        UDim={new=function(...)return {...}end},
        UDim2={fromOffset=function(...)return {...}end},
        Color3={fromRGB=function(...)return {...}end},
        print=function()end,warn=function()end,
        setclipboard=function(s)copied[#copied+1]=s end,
        os={clock=function()return now end},
        task={spawn=function(fn)fn()end,wait=function()end},
        require=function(x)
            if opts.syncFailure then error("sync require denied") end
            if x==syncModule then return opts.sync or SAMPLE_SYNC end
            error("bad require")
        end,
    }
    env.loadstring=function(src)
        return luau.load(src,{environment=env,injectGlobals=true})
    end
    local function run()
        return luau.load(runnerCode,{environment=env,injectGlobals=true})()
    end
    local function button(name)
        for _,o in ipairs(objs) do if o.Name==name then return o end end
    end
    return {run=run,button=button,E=E,copied=copied,
        reads=function()return reads end,sources=function()return sourceFetches end,
        clock=function(t)now=t end,
        heartbeat=function()hb:Fire()end,
        openTrade=function()tradeScreen.Enabled=true end,
        resize=function(w,h)world.CurrentCamera.ViewportSize={X=w,Y=h}end}
end
do
    local t=mock()
    local control=t.run()
    ok(type(control)=="table","real native returns controller")
    eq(t.sources(),2,"two pinned modules only")
    eq(t.reads(),0,"NO profile RPC before explicit operator tap")
    local start=t.button("CaptureCatalogBatch")
    local stop=t.button("CopyClose")
    ok(start.Active and start.Visible,"in-game capture active")
    eq(start.Text,"RUN 5 CHECKS","on-screen multi-feature label")
    start.Activated:Fire()
    eq(t.reads(),1,"exactly one GetProfileData read")
    eq(control.status().status,"CLIENT_MULTI_FEATURE_REPORT","actual native classifier finished")
    eq(start.Active,false,"no double read after first tap")
    start.Activated:Fire()
    eq(t.reads(),1,"double tap cannot repeat inventory RPC")
    eq(stop.Text,"COPY / CLOSE","terminal safe copy")
    stop.Activated:Fire()
    eq(#t.copied,1,"sanitized clipboard once")
    local report=serde.decode("json",t.copied[1])
    eq(report.features.metadata.status,"CLIENT_METADATA_COVERAGE_OBSERVED","live wrapper Sync metadata")
    eq(report.features.classification.chromaAncientKeys,1,"live wrapper chroma ancient")
    eq(report.features.classification.eligibleCopies,9,"live wrapper eligible copies")
    eq(report.features.integrity.bucketsReconciled,true,"all buckets reconcile")
    eq(report.actualOffers,0,"no script offers")
    eq(report.authorizesAccept,false,"no Accept permission")
    ok(not t.copied[1]:find("Celestial",1,true),"no raw weapon key in clipboard")
    ok(not t.copied[1]:find("FAKE_JOB_",1,true),"no job key in clipboard")
    eq(t.run(),nil,"same JobId cannot be rerun")
end
do
    local t=mock({noSync=true})
    local c=t.run()
    t.button("CaptureCatalogBatch").Activated:Fire()
    eq(c.status().features.metadata.status,"INCONCLUSIVE_SYNC_UNAVAILABLE","missing Sync isolated")
    eq(c.status().features.integrity.status,"PASS_CLIENT_COUNTS_RECONCILED","independent quantity intact")
end
do
    local t=mock({syncFailure=true})
    local c=t.run()
    t.button("CaptureCatalogBatch").Activated:Fire()
    eq(c.status().features.metadata.status,"INCONCLUSIVE_SYNC_UNAVAILABLE","denied Sync isolated")
end
do
    local t=mock({profile=profile({Celestial="not-int"})})
    local c=t.run()
    t.button("CaptureCatalogBatch").Activated:Fire()
    eq(c.status().reason,"CENSUS_QUANTITY_INVALID","bad client quantity blocks")
end
do
    local t=mock({remoteFailure=true})
    local c=t.run()
    t.button("CaptureCatalogBatch").Activated:Fire()
    eq(c.status().reason,"OWN_PROFILE_READ_FAILED","remote failure blocked")
end
do
    local t=mock({noRemote=true})
    local c=t.run()
    t.button("CaptureCatalogBatch").Activated:Fire()
    eq(c.status().reason,"OWN_PROFILE_READ_REMOTE_MISSING","missing remote blocked")
end
do
    local t=mock({tradeOpen=true})
    eq(t.run(),nil,"no runner if trade window already active")
    eq(t.reads(),0,"no remote RPC with active trade")
end
do
    local t=mock()
    local c=t.run()
    t.openTrade()
    t.heartbeat()
    eq(c.status().reason,"DYNAMIC_UI_OR_JOB_CONTEXT_LOST","trade mid-session denied")
    eq(t.reads(),0,"no RPC after trade appeared")
end
do
    local t=mock({width=320,height=250})
    eq(t.run(),nil,"no safe space denies test")
    eq(t.reads(),0,"no unsafe UI RPC")
end
do
    local t=mock({uiFailure=true})
    eq(t.run(),nil,"GUI construction failure blocks")
    eq(t.reads(),0,"no UI no remote")
end
do
    local t=mock({sourceFailure=true})
    eq(t.run(),nil,"source unavailable blocks")
    eq(t.reads(),0,"no source no remote")
end
do
    local t=mock({wrongPlace=true})
    eq(t.run(),nil,"MM2 place required")
    eq(t.sources(),0,"wrong place no source fetch")
end
do
    local t=mock({E={PDIDDLER_AUTOTRADE_ACTIVE=true}})
    eq(t.run(),nil,"active trading script blocks batch")
    eq(t.sources(),0,"competing owner checked before source load")
end
print("[PASS] System2 real multifeature core and one-tap native runner: "..tests.." assertions")
