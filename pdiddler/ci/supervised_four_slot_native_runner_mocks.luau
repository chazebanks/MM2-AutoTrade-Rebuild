-- Execute the EXACT supervised iPad loader with fake Roblox GUI, RenderStepped,
-- ORIGINAL protected TradeIO and real pure policy/Stage100 geometry modules.
-- Tests both physical offer safety and mandatory MAIN/ALT on-screen guidance.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local runnerSource=fs.readFile("pdiddler/supervised/SUPERVISED_FOUR_SLOT_MANUAL_PILOT.lua")
local tradeIOSource=fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua")
local bridgeSource=fs.readFile("pdiddler/supervised/supervised_p3_p4_handoff.lua")
local planSource=fs.readFile("pdiddler/supervised/supervised_four_slot_operator_plan.lua")
local overlaySource=fs.readFile("pdiddler/new_part4/stage100_screen_prompt_overlay.lua")
local tests=0
local function check(value,expected,label)
 tests+=1
 assert(value==expected,tostring(label)..": "..tostring(value).." ~= "..tostring(expected))
end
local function event()
 local handlers={}
 local ev={}
 function ev:Connect(fn)
  local h={fn=fn,connected=true}
  table.insert(handlers,h)
  return {Disconnect=function()
    h.connected=false
  end}
 end
 function ev:Fire()
  for _,h in ipairs(handlers) do if h.connected then h.fn() end end
 end
 return ev
end
local function vec(x,y)return {X=x,Y=y}end
local function node(class,name)
 local o={ClassName=class,Name=name or class,Visible=true,Enabled=true,
          Active=false,children={},AbsolutePosition=vec(0,0),
          AbsoluteSize=vec(0,0),Activated=event()}
 function o:IsA(kind)
   return kind==self.ClassName or (kind=="GuiObject" and
       (class=="Frame" or class=="TextLabel" or class=="TextButton"))
 end
 function o:FindFirstChild(k)return self.children[k] end
 function o:GetDescendants()return {} end
 function o:GetAttribute(k)return nil end
 function o:GetFullName()return self.Name end
 function o:put(n)
    n.Parent=self
    self.children[n.Name]=n
    return n
 end
 function o:Destroy()self.Parent=nil;self.Visible=false end
 return o
end
local function fakeEnv(options)
 options=options or {}
 local pg=node("PlayerGui","PlayerGui")
 local screen=pg:put(node("ScreenGui","TradeGUI"))
 local layout=screen:put(node("Frame","Container"))
 local t=layout:put(node("Frame","Trade"))
 t.AbsolutePosition=vec(options.x or 370,options.y or 150)
 t.AbsoluteSize=vec(options.w or 440,options.h or 410)
 if options.startClosed then screen.Enabled=false end
 local ours=t:put(node("Frame","YourOffer"))
 ours:put(node("Frame","Container"))
 local accepted=ours:put(node("Frame","Accepted"))
 accepted.Visible=false
 local theirs=t:put(node("Frame","TheirOffer"))
 theirs:put(node("Frame","Container"))
 local theirAccepted=theirs:put(node("Frame","Accepted"))
 theirAccepted.Visible=false
 local username=theirs:put(node("TextLabel","Username"))
 username.Text="TrustedAlt"
 local players={}
 local lp={Name="MainAccount",UserId=1,Parent=players}
 players.LocalPlayer=lp
 local partner={Name="TrustedAlt",DisplayName="TrustedAlt",UserId=2,Parent=players}
 function players:FindFirstChild(name)
   if type(name)~="string" then
     error("Roblox FindFirstChild requires a string")
   end
   if name=="TrustedAlt" then return partner end
 end
 function players:GetPlayers()return {lp,partner} end
 function lp:FindFirstChildOfClass(kind)
   if kind=="PlayerGui" then return pg end
 end
 local remote=node("RemoteEvent","OfferItem")
 local calls={}
 local afterOfferWaits=0
 function remote:FireServer(raw,category)
   table.insert(calls,{raw=raw,category=category})
   if options.noGuiReplication then return end
   local index=#calls
   local slot=ours.children.Container:put(node("Frame","NewItem"..index))
   local textLabel=slot:put(node("Frame","ItemName")):put(node("TextLabel","Label"))
   textLabel.Text=(options.aliases and options.aliases[raw]) or raw
   if options.transientBlankFirstLabel or options.persistentBlankFirstLabel then
      if index==1 then textLabel.Text="" end
   end
   if options.flipAcceptedAfterFirst and index==1 then
      theirAccepted.Visible=true
   end
   if options.chromaRaw and options.chromaRaw[raw] then
     slot:put(node("Frame","Tags")):put(node("Frame","Chroma"))
   end
   slot:put(node("Frame","Container")):put(node("TextLabel","Amount")).Text=
      options.malformedFirstAmount and index==1 and options.malformedFirstAmount
      or options.blankSingletonAmount and "" or "x1"
   if options.mutatePartnerAfterFirst and index==1 then
     local pslot=theirs.children.Container:put(node("Frame","NewItem1"))
     pslot:put(node("Frame","ItemName")):put(node("TextLabel","Label")).Text="Emberbow"
     pslot:put(node("Frame","Container")):put(node("TextLabel","Amount")).Text="x1"
   end
 end
 local tradeFolder=node("Folder","Trade")
 tradeFolder:put(remote)
 local RS=node("ReplicatedStorage","ReplicatedStorage")
 RS:put(tradeFolder)
 local runService={RenderStepped=event()}
 local world={CurrentCamera={ViewportSize=vec(options.vw or 1024,options.vh or 768)}}
 if options.noCamera then world.CurrentCamera=nil end
 local service={Players=players,ReplicatedStorage=RS,
       VirtualInputManager={},GuiService={},Workspace=world,
       RunService=runService,
       HttpService={JSONEncode=function(_,value)
          if options.jsonFailure then error("mock JSON unavailable") end
          return serde.encode("json",value)
       end}}
 if options.noRender then service.RunService=nil end
 local sourceReads={}
 local game={
   PlaceId=142823291,JobId="MOCK_JOB_123",
   GetService=function(_,name)return service[name] end,
   HttpGet=function(_,url)
     table.insert(sourceReads,url)
     if url:find("a599c31c53d25e6799b9d631f45f282b445dcda0",1,true)
        and url:find("pdiddler4_tradeio_supervised_v2.lua",1,true)
     then return tradeIOSource end
     if url:find("616f905739ffb7bf70183475a79ec6c278dc9ddb",1,true)
        and url:find("supervised_p3_p4_handoff.lua",1,true)
     then return bridgeSource end
     if url:find("27e061555321c6a87bdd835ce3d1ff557443a909",1,true)
        and url:find("supervised_four_slot_operator_plan.lua",1,true)
     then return planSource end
     if url:find("5b8ee35d7f281c23d9c2181abd97a063e59a0660",1,true)
        and url:find("stage100_screen_prompt_overlay.lua",1,true)
     then return overlaySource end
     error("not immutable audited source: "..url)
   end
 }
 local E={PDIDDLER_SUPERVISED_FOUR_SLOT_PILOT={
   armed=true,manualOfferOnly=true,
   noAutomaticAcceptAcknowledged=true,targetName="TrustedAlt",
   weaponKeys={"Iceblaster","Batwing"}
 }}
 local created={}
 local createIndex=0
 local instance={}
 function instance.new(class)
    createIndex+=1
    if options.failUI and class=="ScreenGui" then error("cannot create UI") end
    local n=node(class)
    table.insert(created,n)
    return n
 end
 local enums={
   ZIndexBehavior={Sibling="Sibling"},
   TextXAlignment={Left="Left"},
   Font={GothamBold="GothamBold"}
 }
 local copied={}
 local stepTexts={}
 local waitCount=0
 local env={
    game=game,getgenv=function()return E end,
    Instance=instance,Enum=enums,
    setclipboard=function(txt)
        if options.clipboardFailure then error("clipboard permission denied") end
        table.insert(copied,txt)
    end,
    UDim={new=function(...)return {...}end},
    UDim2={fromOffset=function(...)return {...}end},
    Color3={fromRGB=function(...)return {...}end},
    warn=function()end,
    print=function(...)
       local first=tostring(select(1,...))
       if first:find("MAIN",1,true) then table.insert(stepTexts,first) end
    end,
    task={wait=function()
       waitCount+=1
       if options.startClosed and options.openAfter==waitCount then
         screen.Enabled=true
       end
       if options.moveDuringOffer and waitCount==1 then
         t.AbsolutePosition=vec(0,0)
         t.AbsoluteSize=vec(1024,768)
       end
       if options.shrinkDuringOffer and waitCount==1 then
         world.CurrentCamera.ViewportSize=vec(240,250)
       end
       if options.hideDuringOffer and waitCount==1 then screen.Enabled=false end
       if options.transientBlankFirstLabel and #calls==1 then
          afterOfferWaits+=1
          if afterOfferWaits==2 then
             local slot=ours.children.Container:FindFirstChild("NewItem1")
             local label=slot and slot.children.ItemName and
                slot.children.ItemName.children.Label
             if label then label.Text=
                (options.aliases and options.aliases[calls[1].raw]) or
                calls[1].raw end
          end
       end
       if options.obstructAfterFirst and #calls==1 then
         t.AbsolutePosition=vec(0,0)
         t.AbsoluteSize=vec(1024,768)
       end
       runService.RenderStepped:Fire()
    end}
 }
 if options.clipboardUnavailable then env.setclipboard=nil end
 if options.toclipboardOnly then
    env.toclipboard=env.setclipboard
    env.setclipboard=nil
 end
 env.loadstring=function(source)
   return luau.load(source,{environment=env,injectGlobals=true})
 end
 local function execute()
   return luau.load(runnerSource,{environment=env,injectGlobals=true})()
 end
 return {run=execute,E=E,t=t,screen=screen,partner=partner,
         username=username,calls=calls,reads=sourceReads,created=created,
         accepted=accepted,theirAccepted=theirAccepted,world=world,
         stepTexts=stepTexts,runService=runService,pg=pg,
         copied=copied}
end
local x=fakeEnv()
local r=x.run()
check(type(r),"table","actual runner returns")
check(r.status,"CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED","two-slot client GUI pass")
check(r.offerAttempts,2,"two guarded sends attempted")
check(r.clientVisibleAddedSlots,2,"two GUI slots confirmed")
check(r.onScreenGuideShown,true,"on-screen guide shown")
check(r.onScreenGuideFinalShown,true,"terminal guide shown")
check(r.onScreenGuidePlacementFailures,0,"no guide collision")
check(r.clipboardCopied,true,"clipboard auto-export")
check(r.tradeOutcome,"UNKNOWN","no settlement")
check(r.authorizesAccept,false,"no automatic Accept")
check(r.mayReportProfit,false,"no profit")
local function itemStepLogs(env)
 local result={}
 for _,line in ipairs(env.stepTexts) do
  if line:find("MAIN - ITEM",1,true) then result[#result+1]=line end
 end
 return result
end
local stepLogs=itemStepLogs(x)
check(#stepLogs,2,"actual runner displays two ordered current item steps")
check(stepLogs[1]:find("ITEM 1/2",1,true)~=nil,true,"first item 1 of 2")
check(stepLogs[2]:find("ITEM 2/2",1,true)~=nil,true,"second item 2 of 2")
check(#x.calls,2,"two physical OfferItem sends")
check(x.calls[1].raw,"Iceblaster","first approved key")
check(x.calls[2].raw,"Batwing","second approved key")
check(x.calls[1].category,"Weapons","category Weapons")
check(#x.reads,4,"four SHA-pinned modules")
check(x.E.PDIDDLER_SUPERVISED_FOUR_SLOT_SPENT_JOB,"MOCK_JOB_123","job one-shot")
check(x.E.PDIDDLER_SUPERVISED_FOUR_SLOT_PILOT._consumed,true,"approval spent")
check(x.run(),nil,"same job no rerun")
check(#x.calls,2,"no duplicate item")
local four=fakeEnv()
four.E.PDIDDLER_SUPERVISED_FOUR_SLOT_PILOT.weaponKeys={
 "Iceblaster","Batwing","Laser","Luger"
}
local r4=four.run()
check(r4.status,"CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED","four-slot visible")
check(r4.clientVisibleAddedSlots,4,"four physical GUI slots")
check(#four.calls,4,"exact four remote sends")
check(#itemStepLogs(four),4,"four verified screen step transitions")
-- Raw Scythe is historically displayed as Batwing. Pin the NEW REAL
-- Lua controller source; the old immutable PR200 source must fail this test.
do
 local aliased=fakeEnv({aliases={Scythe="Batwing"}})
 local a=aliased.E.PDIDDLER_SUPERVISED_FOUR_SLOT_PILOT
 a.weaponKeys={"Iceblaster","Scythe"}
 a.expectedDisplayNames={"Iceblaster","Batwing"}
 a.expectedChromaFlags={false,false}
 local result=aliased.run()
 check(result.status,"CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED","native raw/display alias")
 check(result.clientVisibleAddedSlots,2,"both GUI entries reconciled")
 check(aliased.calls[2].raw,"Scythe","physical raw key is Scythe, never Batwing")
end
do
 local chroma=fakeEnv({chromaRaw={ChromaFang=true},aliases={ChromaFang="Fang"}})
 local a=chroma.E.PDIDDLER_SUPERVISED_FOUR_SLOT_PILOT
 a.weaponKeys={"ChromaFang"}
 a.expectedDisplayNames={"Fang"}
 a.expectedChromaFlags={true}
 local result=chroma.run()
 check(result.status,"CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED","native explicit Chroma-tag match")
 check(#chroma.calls,1,"one Chroma remote")
end
do
 local protectedName=fakeEnv()
 local a=protectedName.E.PDIDDLER_SUPERVISED_FOUR_SLOT_PILOT
 a.weaponKeys={"Iceblaster"}
 a.expectedDisplayNames={"Gingerscope"}
 local result=protectedName.run()
 check(result.status,"BLOCKED","cannot hide Gingerscope as a display alias")
 check(#protectedName.calls,0,"zero outgoing protected alias")
end
local noGui=fakeEnv({noGuiReplication=true})
local miss=noGui.run()
check(miss.status,"STOPPED","no GUI proof stops")
check(miss.offerAttempts,1,"one uncertain send only")
check(#noGui.calls,1,"never retry unconfirmed send")
check(#itemStepLogs(noGui),1,"no second step without first GUI item")
local changed=fakeEnv({mutatePartnerAfterFirst=true})
local c=changed.run()
check(c.status,"STOPPED","opponent mutation stops")
check(#changed.calls,1,"no further offers after opponent change")
local obstructed=fakeEnv({obstructAfterFirst=true})
local blockedByGeometry=obstructed.run()
check(blockedByGeometry.status,"STOPPED","screen collision prevents second offer")
check(#obstructed.calls,1,"no second remote after screen collision")
local delayed=fakeEnv({startClosed=true,openAfter=3})
local d=delayed.run()
check(d.status,"CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED","manual open step before trade")
check(#delayed.calls,2,"two sends after opening")
local absent=fakeEnv({startClosed=true})
local n=absent.run()
check(n.status,"BLOCKED","timeout blocked")
check(n.reason,"MANUAL_TRADE_OPEN_TIMED_OUT","bounded manual timeout")
check(#absent.calls,0,"no remote without trade")
local bad={
 function(t)t.E.PDIDDLER_SUPERVISED_FOUR_SLOT_PILOT.armed=false end,
 function(t)t.E.PDIDDLER_SUPERVISED_FOUR_SLOT_PILOT.noAutomaticAcceptAcknowledged=false end,
 function(t)t.E.PDIDDLER_SUPERVISED_FOUR_SLOT_PILOT.weaponKeys={"Gingerscope"} end,
 function(t)t.E.PDIDDLER_SUPERVISED_FOUR_SLOT_PILOT.weaponKeys={"Iceblaster","Iceblaster"} end,
 function(t)t.E.PDIDDLER_SUPERVISED_FOUR_SLOT_PILOT.weaponKeys={"Iceblaster","Batwing","Laser","Luger","Shark"} end,
 function(t)t.E.PDIDDLER_SUPERVISED_FOUR_SLOT_PILOT.targetName="WrongUser" end,
 function(t)t.username.Text="WrongUser" end,
 function(t)t.accepted.Visible=true end,
 function(t)t.theirAccepted.Visible=true end,
 function(t)t.E.PDIDDLER_OUTGOING_SESSION=1 end,
}
for i,change in ipairs(bad) do
 local b=fakeEnv()
 change(b)
 local result=b.run()
 if result then
  check(result.authorizesAccept,false,"never Accept invalid "..i)
  check(result.tradeOutcome,"UNKNOWN","unknown outcome invalid "..i)
 end
 check(#b.calls,0,"no unapproved item "..i)
end
for _,options in ipairs({
 {noCamera=true},{noRender=true},{failUI=true},
 {vw=240,vh=250},{x=0,y=0,w=1024,h=768}
}) do
 local v=fakeEnv(options)
 local result=v.run()
 check(type(result),"table","unsafe guide report")
 check(result.status,"BLOCKED","unsafe guide blocks")
 check(#v.calls,0,"no remote when UI unsafe")
end
-- A malformed exact username must not throw or arm any remote.
do
 local invalid=fakeEnv()
 invalid.E.PDIDDLER_SUPERVISED_FOUR_SLOT_PILOT.targetName=nil
 local ok,report=pcall(invalid.run)
 check(ok,true,"nil target config handled without runtime crash")
 check(#invalid.calls,0,"nil target cannot offer")
end

-- Reproduce the native first-item receipt: one physical remote was sent,
-- GUI slot exists but ItemName label is initially blank during replication.
do
 local pending=fakeEnv({transientBlankFirstLabel=true})
 local observed=pending.run()
 check(observed.status,"CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED","temporary partial slot reconciled")
 check(observed.clientVisibleAddedSlots,2,"both slots confirmed after stable client frame")
 check(observed.offerAttempts,2,"no extra remote on temporary frame")
 check(#pending.calls,2,"one send per planned raw weapon")
 check(observed.clipboardCopied,true,"client result automatically copied")
end
do
 local pending=fakeEnv({persistentBlankFirstLabel=true})
 local observed=pending.run()
 check(observed.status,"STOPPED","persistent missing label stopped")
 check(observed.reason,"P3_P4_LIVE_SNAPSHOT_REJECTED","prior user status retained")
 check(observed.snapshotRejectReason,"PHYSICAL_GUI_SLOTS_NOT_RECONCILED","precise runtime cause")
 check(observed.clientVisibleAddedSlots,0,"no fabricated verified slots")
 check(observed.offerAttempts,1,"one physical attempt")
 check(#pending.calls,1,"no retry or second send on persistent missing label")
 check(pending.copied[1]:find("PHYSICAL_GUI_SLOTS_NOT_RECONCILED",1,true)~=nil,true,
  "clipboard explicitly reports exact safe cause")
end
do
 local accepted=fakeEnv({flipAcceptedAfterFirst=true})
 local observed=accepted.run()
 check(observed.status,"STOPPED","live accept state stops after first item")
 check(observed.snapshotRejectReason,"ACCEPT_ALREADY_SET","accept flag never hidden")
 check(#accepted.calls,1,"never dispatch second after acceptance")
end


-- Full pinned native launcher: actual first/second offered singleton GUI slots
-- show EMPTY Amount.Text, matching observed MM2 client display convention.
do
 local singleton=fakeEnv({blankSingletonAmount=true})
 local r=singleton.run()
 check(r.status,"CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED","real singleton blank quantity label")
 check(r.offerAttempts,2,"two precisely approved physical requests")
 check(r.clientVisibleAddedSlots,2,"two blank-labeled singleton slots seen")
 check(#singleton.calls,2,"no item offer retry")
 check(r.authorizesAccept,false,"still no final Accept")
 check(r.clipboardCopied,true,"auto-copy after blank singleton proof")
end
-- Invalid x0 means unresolved quantity, NOT a valid singleton.
do
 local zero=fakeEnv({malformedFirstAmount="x0"})
 local r=zero.run()
 check(r.status,"STOPPED","zero quantity remains blocked")
 check(r.snapshotRejectReason,"VISIBLE_STACK_TEXT_INVALID","zero reason detailed")
 check(r.offerAttempts,1,"only first remote attempted")
 check(r.clientVisibleAddedSlots,0,"never fake a copy for x0")
 check(#zero.calls,1,"second remote suppressed on zero")
end

print("[PASS] actual supervised 4-slot iPad runner original MM2 mocks:",tests)
print("[PASS] 1..4 selected OfferItem, mandatory on-screen UI, clipboard; no final Accept")
