-- Source-pinned original Stage83 PUBLIC expired candidate, NEVER current price.
-- Exercise real new read-only iPad runner AND pure key-reconciliation module in Lune.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local coreCode=fs.readFile("pdiddler/system2/native_key_reconciliation_core.lua")
local runnerCode=fs.readFile("pdiddler/system2/SYSTEM2_KEY_RECONCILIATION_READONLY_NATIVE.lua")
local registryCode=fs.readFile("pdiddler/intelligence_lab/stage83_public_slug_registry.lua")
local geometryCode=fs.readFile("pdiddler/new_part4/stage100_screen_prompt_overlay.lua")
local tests=0
local function eq(a,b,name)
    tests+=1
    assert(a==b,name..": "..tostring(a).." != "..tostring(b))
end
local function ok(a,name)
    tests+=1; assert(a,name)
end
local core=luau.load(coreCode)()
local registry=luau.load(registryCode)()
local function clone(t)
    if type(t)~="table" then return t end
    local r={}
    for k,v in pairs(t) do r[k]=clone(v) end
    return r
end
local SAMPLE_SYNC={Weapons={}}
for id,row in pairs(registry.entries) do
    SAMPLE_SYNC.Weapons[id]={
        ItemName=row[1],ItemType=row[2],Rarity=row[3],Chroma=row[4],
    }
end
SAMPLE_SYNC.Weapons.NewFutureGodly={
    ItemName="New Future Godly",ItemType="Gun",Rarity="Godly",Chroma=false,
}
local SAMPLE_OWN={Celestial=2,EmberbowChroma=6,Immortal=3,NewFutureGodly=1,GhostZero=0}
local function profile(items) return {ProfileData={Weapons={Owned=items}}} end
local function evaluate(own,sync,reg)
    return core.assess(profile(own or SAMPLE_OWN),sync or SAMPLE_SYNC,
                      reg or registry,"FAKE_JOB_001",10,10.25)
end
local function pure()
    local r=evaluate()
    eq(r.status,"CLIENT_KEY_RECONCILIATION_BATCH","new batch status")
    eq(r.features.historicalSource.registryRows,189,"exact historic rows")
    eq(r.features.historicalSource.status,"EXPIRED_NO_PUBLISHER_EDITION_AUTH","expired explicit")
    eq(r.features.currentGameCatalog.rowsInspected,189,"all historical keys audited")
    eq(r.features.currentGameCatalog.keysPresent,189,"full mock sync present")
    eq(r.features.currentGameCatalog.keysMissing,0,"none absent")
    eq(r.features.currentGameCatalog.exactMatch,189,"full structural labels")
    eq(r.features.currentGameCatalog.status,"HISTORICAL_REGISTRY_CLIENT_META_PARITY",
       "historical parity not current quote")
    eq(r.features.ownedKeyMapping.eligibleRawKeys,4,"four eligible owned keys")
    eq(r.features.ownedKeyMapping.eligibleRawCopies,12,"twelve eligible owned copies")
    eq(r.features.ownedKeyMapping.keysInHistoricalRegistry,3,"three historical keyed")
    eq(r.features.ownedKeyMapping.copiesInHistoricalRegistry,11,"historical copy sums")
    eq(r.features.ownedKeyMapping.keysOutsideHistoricalRegistry,1,"new eligible outside old")
    eq(r.features.ownedKeyMapping.copiesOutsideHistoricalRegistry,1,"one future copy")
    eq(r.features.ownedKeyMapping.exactMetaNameTypeKeys,3,"exact identities")
    eq(r.features.ownedKeyMapping.status,"PARTIAL_HISTORICAL_KEY_OR_METADATA_DRIFT",
       "newly added game weapons not silently priced")
    eq(r.features.ownedKeyMapping.allowsListedValue,false,"no market source")
    eq(r.features.stackConcentration.eligibleStackedKeys,3,"stacked keys")
    eq(r.features.stackConcentration.copiesBeyondFirst,8,"extra copies summed")
    eq(r.features.stackConcentration.keysWithOverFourCopies,1,"over four copies one key")
    eq(r.features.stackConcentration.maxCopiesPerEligibleKey,6,"max stack")
    eq(r.features.stackConcentration.physicalSlotFeasibilityProven,false,"no offer proof")
    eq(r.features.targetProtection.targetInRegistry,true,"target registry present")
    eq(r.features.targetProtection.mayOfferTarget,false,"target never outgoing")
    eq(r.features.targetProtection.targetOwnershipRevealed,false,"no ownership disclosure")
    eq(r.authorizesOffer,false,"no offers")
    eq(r.authorizesAccept,false,"no Accept")
    eq(r.currentMarketPriceAuthenticated,false,"no live values")
    eq(r.publisherEditionBound,false,"publisher edition NOT bound")
    eq(r.gameItemInstanceProven,false,"no game item instance proof")
    eq(r.rawInventoryExported,false,"no private inventory export")
    ok(not serde.encode("json",r):find("Celestial",1,true),"no client raw weapon")
    ok(not serde.encode("json",r):find("FAKE_JOB_",1,true),"no client job")
    local c=clone(SAMPLE_SYNC)
    c.Weapons.Celestial.ItemName="DRIFTED"
    local drift=evaluate(SAMPLE_OWN,c)
    eq(drift.features.currentGameCatalog.labelDrift,1,"catalog label drift")
    eq(drift.features.ownedKeyMapping.gameLabelDriftKeys,1,"owned drift detected")
    eq(drift.features.ownedKeyMapping.status,"PARTIAL_HISTORICAL_KEY_OR_METADATA_DRIFT","drift never trusted")
    c=clone(SAMPLE_SYNC)
    c.Weapons.Immortal.ItemType="Knife"
    local bad=evaluate(SAMPLE_OWN,c)
    eq(bad.features.currentGameCatalog.structuralMismatch,1,"catalog variant drift")
    eq(bad.features.ownedKeyMapping.structuralMismatchKeys,1,"owned structural mismatch")
    c=clone(SAMPLE_SYNC)
    c.Weapons.EmberbowChroma=nil
    local missing=evaluate(SAMPLE_OWN,c)
    eq(missing.features.currentGameCatalog.keysMissing,1,"lost catalog key")
    eq(missing.features.ownedKeyMapping.ownedUnresolvedMetaKeys,1,"unresolved owned key")
    c=clone(SAMPLE_SYNC)
    c.Weapons.Celestial.Tradable=false
    local noTrade=evaluate(SAMPLE_OWN,c)
    eq(noTrade.features.currentGameCatalog.explicitlyIneligible,1,"game tradeability flag")
    eq(noTrade.features.ownedKeyMapping.eligibleRawKeys,3,"untradable not eligible")
    c=clone(SAMPLE_SYNC)
    c.Item={Immortal={ItemName="Immortal",ItemType="Gun",Rarity="Ancient",Chroma=false}}
    local conflict=evaluate(SAMPLE_OWN,c)
    eq(conflict.features.currentGameCatalog.metadataConflict,1,"conflicting source")
    eq(conflict.features.ownedKeyMapping.ownedUnresolvedMetaKeys,1,"owned source conflict")
    local withTarget=evaluate({Gingerscope=3},SAMPLE_SYNC)
    eq(withTarget.features.targetProtection.mayOfferTarget,false,"owned target protected")
    eq(withTarget.features.targetProtection.targetOwnershipRevealed,false,"no Gingerscope possession flag")
    ok(not serde.encode("json",withTarget):find('"Gingerscope"',1,true),
       "target item key never exported")
    local tam=clone(registry)
    tam.entries.Celestial=nil
    eq(evaluate(SAMPLE_OWN,SAMPLE_SYNC,tam).status,"BLOCKED","registry 188 blocked")
    tam=clone(registry)
    tam.publisherExpiryUtc="2026-11-14T23:59:59Z"
    eq(evaluate(SAMPLE_OWN,SAMPLE_SYNC,tam).reason,
       "HISTORICAL_REGISTRY_MANIFEST_INVALID","never restamp old publisher")
    tam=clone(registry)
    tam.authorizesAccept=true
    eq(evaluate(SAMPLE_OWN,SAMPLE_SYNC,tam).status,"BLOCKED","forged price permit")
    tam=clone(registry)
    tam.entries.Celestial[4]=true
    eq(evaluate(SAMPLE_OWN,SAMPLE_SYNC,tam).reason,
       "HISTORICAL_REGISTRY_ROW_INVALID","variant mismatch in roster blocked")
    eq(core.assess(profile(SAMPLE_OWN),nil,registry,"FAKE_JOB_001",10,10).reason,
       "LIVE_GAME_SYNC_UNAVAILABLE","no game sync no claim")
    eq(core.assess(profile(SAMPLE_OWN),SAMPLE_SYNC,registry,"FAKE_JOB_001",10,26).reason,
       "LOCAL_SESSION_CLOCK_INVALID","stale read blocked")
    eq(core.assess(profile(SAMPLE_OWN),SAMPLE_SYNC,registry,"short",10,10).status,
       "BLOCKED","short job blocked")
    eq(evaluate({["INVALID/KEY"]=1}).status,"BLOCKED","raw ID validation")
    for _,own in ipairs({{Celestial=-1},{Celestial=1.1},{Celestial=true},
                         {Celestial="oops"},{Celestial=1000001}}) do
        eq(evaluate(own).reason,"OWNED_QUANTITY_INVALID","bad quantity blocked")
    end
    local huge={}
    for i=1,4001 do huge["Zero_"..tostring(i)]=0 end
    eq(evaluate(huge).reason,"OWNED_RAW_ENTRY_CAP","oversize zero-only blocked")
    local zero=evaluate({Celestial=0})
    eq(zero.features.ownedKeyMapping.eligibleRawCopies,0,"zero-copy item excluded")
    -- Historical registry must never influence current price or offer authority.
    for _,field in ipairs({"currentMarketPriceAuthenticated","publisherEditionBound",
        "observedTransferabilityProven","serverCompletionProven","authorizesTrade",
        "authorizesOffer","authorizesAccept","mayReportProfit","mayUseForStrategyLearning"}) do
        eq(r[field],false,"authority denied: "..field)
    end
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
        if url:find("native_key_reconciliation_core.lua",1,true) then
            ok(url:find("eea9d6f5da3dfac8599e2f3e7b9fe1764d6ba288",1,true)~=nil,"core source pinned")
            return coreCode
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
    ok(type(c)=="table","native wrapper started")
    eq(t.sources(),3,"3 immutable modules loaded, no market endpoint")
    eq(t.reads(),0,"manual press required")
    local start=t.button("RunHistoricalKeyAudit")
    local stop=t.button("CopyClose")
    eq(start.Text,"RUN 6 NEW CHECKS","all checks one button")
    start.Activated:Fire()
    eq(t.reads(),1,"one own profile read")
    eq(c.status().status,"CLIENT_KEY_RECONCILIATION_BATCH","new client report")
    start.Activated:Fire()
    eq(t.reads(),1,"double tap never repeats")
    eq(c.status().features.currentGameCatalog.keysPresent,189,"full registry in native")
    eq(c.status().features.ownedKeyMapping.keysOutsideHistoricalRegistry,1,
       "actual wrapper compares raw game keys")
    stop.Activated:Fire()
    eq(#t.copied,1,"sanitized copied")
    local d=serde.decode("json",t.copied[1])
    eq(d.features.stackConcentration.maxCopiesPerEligibleKey,6,"native copies")
    eq(d.authorizesAccept,false,"native no accept")
    eq(d.actualOffers,0,"native no offers")
    ok(not t.copied[1]:find("Celestial",1,true),"no private key exported")
    ok(not t.copied[1]:find("FAKE_JOB_",1,true),"no JobId exported")
    eq(t.run(),nil,"same job cannot re-run")
end
do
    local t=mock({noSync=true})
    local c=t.run()
    t.button("RunHistoricalKeyAudit").Activated:Fire()
    eq(c.status().reason,"LIVE_GAME_SYNC_UNAVAILABLE","missing Sync inconclusive")
    eq(c.status().authorizesTrade,false,"missing metadata blocks trade")
end
do
    local t=mock({remoteFailure=true})
    local c=t.run()
    t.button("RunHistoricalKeyAudit").Activated:Fire()
    eq(c.status().reason,"OWN_PROFILE_READ_FAILED","remote failure blocked")
end
do
    local t=mock({noRemote=true})
    local c=t.run()
    t.button("RunHistoricalKeyAudit").Activated:Fire()
    eq(c.status().reason,"OWN_PROFILE_READ_REMOTE_MISSING","remote missing blocked")
end
do
    local t=mock({tradeOpen=true})
    eq(t.run(),nil,"trade UI prior source read blocked")
    eq(t.reads(),0,"no profile RPC with trade")
end
do
    local t=mock()
    local c=t.run()
    t.openTrade()
    t.heartbeat()
    eq(c.status().reason,"DYNAMIC_UI_OR_JOB_CONTEXT_LOST","trade mid-session blocks")
    eq(t.reads(),0,"no read when interrupted")
end
do
    local t=mock({width=320,height=250})
    eq(t.run(),nil,"unsafe viewport blocked")
    eq(t.reads(),0,"no read with unsafe overlay")
end
do
    local t=mock({uiFailure=true})
    eq(t.run(),nil,"cannot build UI fails closed")
    eq(t.reads(),0,"UI failure no RPC")
end
do
    local t=mock({sourceFailure=true})
    eq(t.run(),nil,"missing pinned source blocked")
    eq(t.reads(),0,"source failure no RPC")
end
do
    local t=mock({wrongPlace=true})
    eq(t.run(),nil,"original MM2 place only")
    eq(t.sources(),0,"place guard before network")
end
do
    local t=mock({E={PDIDDLER_S2_MULTIFEATURE_OWNER={}}})
    eq(t.run(),nil,"no dual owner with previous batch")
    eq(t.sources(),0,"owner guard before network")
end
print("[PASS] System2 historical-key six-feature real native batch: "..tests.." assertions")
