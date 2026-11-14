-- System2 shadow-planning actual LUA runtime mocks; historically priced data
-- NEVER becomes a real market quote, partner decision or offer authorization.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local coreCode=fs.readFile("pdiddler/system2/native_structural_shadow_core.lua")
local auditorCode=fs.readFile("pdiddler/system2/native_key_reconciliation_core.lua")
local runnerCode=fs.readFile("pdiddler/system2/SYSTEM2_STRUCTURAL_SHADOW_READONLY_NATIVE.lua")
local registryCode=fs.readFile("pdiddler/intelligence_lab/stage83_public_slug_registry.lua")
local geometryCode=fs.readFile("pdiddler/new_part4/stage100_screen_prompt_overlay.lua")
local tests=0
local function eq(a,b,name)
 tests+=1
 assert(a==b,name..": "..tostring(a).." != "..tostring(b))
end
local function ok(v,name)
 tests+=1;assert(v,name)
end
local core=luau.load(coreCode)()
local auditor=luau.load(auditorCode)()
local registry=luau.load(registryCode)()
local function clone(t)
 if type(t)~="table" then return t end
 local o={}
 for k,v in pairs(t) do o[k]=clone(v) end
 return o
end
local SAMPLE_SYNC={Weapons={}}
for id,row in pairs(registry.entries) do
 SAMPLE_SYNC.Weapons[id]={ItemName=row[1],ItemType=row[2],
                          Rarity=row[3],Chroma=row[4]}
end
local SAMPLE_OWN={Celestial=2,EmberbowChroma=6,Immortal=3,TheSeer=1,GhostZero=0}
local function profile(items)return {ProfileData={Weapons={Owned=items}}} end
local function auditFor(p,s)
 return auditor.assess(p,s,registry,"FAKE_JOB_001",10,10.25)
end
local function evaluate(own,sync,admission)
 local p=profile(own or SAMPLE_OWN)
 local s=sync or SAMPLE_SYNC
 local a=admission or auditFor(p,s)
 return core.assess(p,s,registry,"FAKE_JOB_001",10,10.25,a)
end
local function pure()
 local a=core.syntheticTests()
 eq(a.status,"PURE_SYNTHETIC_SCENARIOS_PASSED","pure synthetic harness")
 eq(a.cases,10,"10 separately checked synthetic trade constraints")
 eq(a.estimatedAcceptanceProbabilityAvailable,false,"do not invent partner odds")
 local r=evaluate()
 eq(r.status,"CLIENT_STRUCTURAL_SHADOW_REPORT","normal test status")
 eq(r.features.physicalSlots.status,"CLIENT_NONPRICE_LAYOUT_CAPACITY_OBSERVED","no-price physical slots")
 eq(r.features.physicalSlots.atLeastFourNonTargetSlots,true,"four distinct keys")
 eq(r.features.physicalSlots.maximUMslotLimit,nil,"only known controlled fields")
 eq(r.features.physicalSlots.maximumSlotLimit,4,"physical limit four")
 eq(r.features.stackConstraints.singletonNonTargetKeys,1,"single copy shape")
 eq(r.features.stackConstraints.nonTargetKeysWithTwoToFourCopies,2,"2-4 stack shape")
 eq(r.features.stackConstraints.nonTargetKeysWithFivePlusCopies,1,"5-plus stack")
 eq(r.features.stackConstraints.topFourKeyCopyCountUpperBound,12,"top 4 distinct stacks")
 eq(r.features.stackConstraints.nonlinearFivePlusRequiresIndependentPricing,true,"nonlinear stacks flagged")
 eq(r.features.syntheticBilateralModels.cases,10,"fixture cases independently pass")
 eq(r.features.protectedTarget.mayOfferTarget,false,"target never offer")
 eq(r.features.protectedTarget.targetOwnershipRevealed,false,"no ownership leak")
 eq(r.features.quoteProvenance.status,"HISTORICAL_KEYS_ONLY_NO_CURRENT_PRICE","old source denied")
 eq(r.features.quoteProvenance.liveValueDeltaCalculated,false,"no live delta")
 eq(r.features.quoteProvenance.marketLiquidity,"UNKNOWN","no trade acceptance statistics")
 eq(r.features.freshness.serverBoundSessionOrRevisionProven,false,"local only")
 eq(r.features.integration.originalPlannerMutated,false,"no P3/P4 modifications")
 eq(r.authorizesAccept,false,"no Accept")
 eq(r.authorizesOffer,false,"no Offer")
 eq(r.authorizesTrade,false,"no trading")
 eq(r.mayUseForStrategyLearning,false,"no fake outcomes")
 eq(r.actualOffers,0,"no action")
 eq(r.rawIdsExported,false,"nothing private")
 ok(not serde.encode("json",r):find("Celestial",1,true),"no owned weapon names")
 ok(not serde.encode("json",r):find("FAKE_JOB",1,true),"no JobId")
 local withTarget=evaluate({Celestial=2,EmberbowChroma=6,Immortal=3,TheSeer=1,Gingerscope=7})
 eq(withTarget.status,"CLIENT_STRUCTURAL_SHADOW_REPORT","own target safely handled")
 eq(withTarget.features.protectedTarget.targetOwnershipRevealed,false,"target possession hidden")
 eq(withTarget.features.stackConstraints.topFourKeyCopyCountUpperBound,12,"target not outbound")
 ok(not serde.encode("json",withTarget):find("Gingerscope",1,true),"no target name output")
 local low=evaluate({Celestial=1})
 eq(low.features.physicalSlots.atLeastOneNonTargetSlot,true,"one slot available")
 eq(low.features.physicalSlots.atLeastTwoNonTargetSlots,false,"two slot not available")
 eq(low.features.physicalSlots.atLeastFourNonTargetSlots,false,"four slot unavailable")
 eq(low.features.stackConstraints.topFourKeyCopyCountUpperBound,1,"one copy upper bound")
 local blank=evaluate({Celestial=0})
 eq(blank.features.physicalSlots.atLeastOneNonTargetSlot,false,"zero case")
 eq(blank.features.stackConstraints.topFourKeyCopyCountUpperBound,0,"zero layout bound")
 local b=clone(auditFor(profile(SAMPLE_OWN),SAMPLE_SYNC))
 b.authorizesAccept=true
 eq(evaluate(SAMPLE_OWN,SAMPLE_SYNC,b).reason,
    "PRIOR_NATIVE_KEY_AUDIT_INCOMPLETE_OR_MUTATED","forged audit no accept")
 b=clone(auditFor(profile(SAMPLE_OWN),SAMPLE_SYNC))
 b.features.ownedKeyMapping.eligibleRawCopies=133
 eq(evaluate(SAMPLE_OWN,SAMPLE_SYNC,b).reason,
    "CENSUS_OR_ELIGIBILITY_CHANGED_INSIDE_SAME_READ","same read changed")
 local bad=clone(SAMPLE_SYNC)
 bad.Weapons.Celestial.Rarity="Common"
 eq(evaluate(SAMPLE_OWN,bad).status,"BLOCKED","rarity drift blocks previous audit")
 bad=clone(SAMPLE_SYNC)
 bad.Weapons.Immortal.Tradable=false
 eq(evaluate(SAMPLE_OWN,bad).status,"BLOCKED","metadata no-trade drift blocks")
 eq(evaluate({["invalid/key"]=1}).status,"BLOCKED","bad key stop")
 for _,p in ipairs({{Celestial=-1},{Celestial=1.1},{Celestial=true},
                     {Celestial="bad"},{Celestial=1000001}}) do
  eq(evaluate(p).status,"BLOCKED","bad quantity denied")
 end
 local huge={}
 for i=1,4001 do huge["Zero_"..tostring(i)]=0 end
 eq(evaluate(huge).status,"BLOCKED","limit zero-only entries")
 local prev=auditFor(profile(SAMPLE_OWN),SAMPLE_SYNC)
 eq(core.assess(profile(SAMPLE_OWN),SAMPLE_SYNC,registry,"FAKE_JOB_001",10,26,prev).reason,
    "LOCAL_SESSION_OR_READ_WINDOW_INVALID","stale read")
 eq(core.assess(profile(SAMPLE_OWN),SAMPLE_SYNC,registry,"short",10,10.1,prev).status,
    "BLOCKED","bad JobId")
 -- Original registry may not be rewritten to pretend a new publication.
 local registryFake=clone(registry)
 registryFake.publisherExpiryUtc="2026-11-16T00:00:00Z"
 eq(core.assess(profile(SAMPLE_OWN),SAMPLE_SYNC,registryFake,
      "FAKE_JOB_001",10,10.25,prev).reason,
    "EXPIRED_REGISTRY_CONTRACT_CHANGED","no source restamp")
 local otherSync=clone(SAMPLE_SYNC)
 otherSync.Weapons.NewFutureGodly={ItemName="new",ItemType="Gun",Rarity="Godly",Chroma=false}
 eq(evaluate({NewFutureGodly=1},otherSync).status,"BLOCKED","outside historical source blocked")
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
        if url:find("native_structural_shadow_core.lua",1,true) then
            ok(url:find("95139f6c05f8c186239017ca19f50dbd33cff029",1,true)~=nil,"shadow core immutable")
            return coreCode
        elseif url:find("native_key_reconciliation_core.lua",1,true) then
            ok(url:find("eea9d6f5da3dfac8599e2f3e7b9fe1764d6ba288",1,true)~=nil,"original key audit immutable")
            return auditorCode
        elseif url:find("stage83_public_slug_registry.lua",1,true) then
            ok(url:find("25b48b60fdb2f971bbb6b2a2020f3c7c4432f7ae",1,true)~=nil,"source roster pinned")
            return registryCode
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
 local c=t.run()
 ok(type(c)=="table","actual native loads")
 eq(t.sources(),4,"4 pinned modules including previous tested key auditor")
 eq(t.reads(),0,"no inventory RPC without operator")
 local start=t.button("RunStructuralShadowBatch")
 local stop=t.button("CopyClose")
 ok(start.Active and start.Visible,"safe purple button visible")
 eq(start.Text,"RUN SHADOW BATCH","new distinct test UI")
 start.Activated:Fire()
 eq(t.reads(),1,"ONE own-profile RPC")
 eq(c.status().status,"CLIENT_STRUCTURAL_SHADOW_REPORT","real module invoked by runner")
 eq(c.status().features.syntheticBilateralModels.cases,10,"fixture integrated")
 eq(c.status().features.stackConstraints.topFourKeyCopyCountUpperBound,12,"real client structural combos")
 start.Activated:Fire()
 eq(t.reads(),1,"double tap ignored")
 stop.Activated:Fire()
 eq(#t.copied,1,"sanitized result copied")
 local v=serde.decode("json",t.copied[1])
 eq(v.features.physicalSlots.atLeastFourNonTargetSlots,true,"four-slot layout")
 eq(v.authorizesTrade,false,"no actual trade")
 eq(v.actualAccepts,0,"no actual Accept")
 ok(not t.copied[1]:find("Celestial",1,true),"no raw owned item exported")
 ok(not t.copied[1]:find("FAKE_JOB",1,true),"no JobId exported")
 eq(t.run(),nil,"same server job cannot repeat read")
end
do
 local t=mock({noSync=true})
 local c=t.run()
 t.button("RunStructuralShadowBatch").Activated:Fire()
 eq(c.status().status,"BLOCKED","no Sync no readiness")
 eq(c.status().reason,"PRIOR_NATIVE_KEY_AUDIT_INCOMPLETE_OR_MUTATED","missing Sync linked failure")
end
do
 local t=mock({remoteFailure=true})
 local c=t.run()
 t.button("RunStructuralShadowBatch").Activated:Fire()
 eq(c.status().reason,"OWN_PROFILE_READ_FAILED","profile failure controlled")
end
do
 local t=mock({noRemote=true})
 local c=t.run()
 t.button("RunStructuralShadowBatch").Activated:Fire()
 eq(c.status().reason,"OWN_PROFILE_READ_REMOTE_MISSING","missing RPC controlled")
end
do
 local t=mock({tradeOpen=true})
 eq(t.run(),nil,"existing TradeGUI blocks")
 eq(t.reads(),0,"no RPC while trading")
end
do
 local t=mock()
 local c=t.run()
 t.openTrade()
 t.heartbeat()
 eq(c.status().reason,"DYNAMIC_UI_OR_JOB_CONTEXT_LOST","trade appears while open")
 eq(t.reads(),0,"no unsafe RPC after trade UI")
end
do
 local t=mock({width=320,height=250})
 eq(t.run(),nil,"unsafe viewport no panel")
 eq(t.reads(),0,"unsafe UI no remote")
end
do
 local t=mock({uiFailure=true})
 eq(t.run(),nil,"UI fail closed")
 eq(t.reads(),0,"no fake GUI no data read")
end
do
 local t=mock({sourceFailure=true})
 eq(t.run(),nil,"source pin unavailable blocks")
 eq(t.reads(),0,"cannot source no remote")
end
do
 local t=mock({wrongPlace=true})
 eq(t.run(),nil,"place must be original MM2")
 eq(t.sources(),0,"wrong place no network")
end
do
 local t=mock({E={PDIDDLER_S2_KEY_RECON_OWNER={}}})
 eq(t.run(),nil,"no overlapping key audit owner")
 eq(t.sources(),0,"owner guard before network")
end
print("[PASS] System2 structural shadow actual native 6-feature batch: "..tests.." assertions")
