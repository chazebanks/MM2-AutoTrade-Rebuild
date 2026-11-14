-- Execute REAL original MM2 MAIN read-only Accept discovery GUI under Lune.
-- Fake games, fake trade slots and no real requests, offers or final Accept.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local runner=fs.readFile("pdiddler/supervised/MAIN_ALT_ACCEPT_DISCOVERY_READONLY_NATIVE.lua")
local coreCode=fs.readFile("pdiddler/supervised/main_alt_accept_control_shape_probe.lua")
local stage9Code=fs.readFile("pdiddler/new_part4/p4_native_observer.lua")
local contractCode=fs.readFile("pdiddler/new_part4/p4_observer_contract.lua")
local geomCode=fs.readFile("pdiddler/new_part4/stage100_screen_prompt_overlay.lua")
local passed=0
local function eq(a,b,label)
 passed+=1
 assert(a==b,tostring(label)..": "..tostring(a).." != "..tostring(b))
end
local function ok(a,label)passed+=1;assert(a,label)end
local function event()
 local ev={handlers={}}
 function ev:Connect(fn)
  local h={fn=fn,live=true}
  table.insert(self.handlers,h)
  return {Disconnect=function()h.live=false end}
 end
 function ev:Fire()
  for _,h in ipairs(self.handlers)do
   if h.live then h.fn() end
  end
 end
 return ev
end
local function vec(x,y)return {X=x,Y=y}end
local function fake(options)
 options=options or {}
 local everything={}
 local function node(class,name)
  local n={ClassName=class,Name=name or class,Visible=true,Enabled=true,
   Active=true,Text="",AbsolutePosition=vec(20,110),
   AbsoluteSize=vec(60,30),Activated=event()}
  table.insert(everything,n)
  function n:IsA(target)
   return target==self.ClassName or
    (target=="GuiObject" and (class=="Frame" or
     class=="TextLabel" or class=="TextButton" or class=="ImageButton"))
  end
  function n:FindFirstChild(name)
   for _,c in ipairs(everything)do
    if c.Parent==self and c.Name==name then return c end
   end
   return nil
  end
  function n:FindFirstChildOfClass(target)
   for _,c in ipairs(everything) do
    if c.Parent==self and c.ClassName==target then return c end
   end
  end
  function n:GetDescendants()
   local found={}
   for _,x in ipairs(everything)do
    local p=x.Parent
    while p do
     if p==self then table.insert(found,x);break end
     p=p.Parent
    end
   end
   return found
  end
  function n:GetAttribute(k)return nil end
  function n:Destroy()n.Parent=nil;n.Visible=false end
  return n
 end
 local function put(parent,child)
  child.Parent=parent
  return child
 end
 local PG=node("PlayerGui","PlayerGui")
 local scr=put(PG,node("ScreenGui","TradeGUI_Phone"))
 scr.Enabled=false
 local cont=put(scr,node("Frame","Container"))
 local root=put(cont,node("Frame","Trade"))
 root.AbsolutePosition=vec(options.tradeX or 380,130)
 root.AbsoluteSize=vec(options.tradeW or 400,options.tradeH or 420)
 local our=put(root,node("Frame","YourOffer"))
 local ownItems=put(our,node("Frame","Container"))
 local mineAccepted=put(our,node("Frame","Accepted"));mineAccepted.Visible=false
 local their=put(root,node("Frame","TheirOffer"))
 local theirItems=put(their,node("Frame","Container"))
 local altAccepted=put(their,node("Frame","Accepted"));altAccepted.Visible=false
 local username=put(their,node("TextLabel","Username"))
 username.Text=options.wrongPartner and "Imposter" or "FixtureAlt"
 local acceptParent=options.acceptInYourOffer and our
   or put(root,node("Frame","Buttons"))
 local acceptFrame=put(acceptParent,node("Frame","Accept"))
 local acceptControl=nil
 if options.labelOnly then
  local label=put(acceptFrame,node("TextLabel","AcceptText"))
  label.Text="Accept"
 end
 if not options.noAccept then
  acceptControl=put(acceptFrame,node("ImageButton","ActionButton"))
  acceptControl.AbsolutePosition=vec(520,570)
  acceptControl.AbsoluteSize=vec(140,37)
 end
 local secondControl=nil
 if options.twoAccept then
  local extra=put(root,node("Frame","AcceptButton"))
  secondControl=put(extra,node("TextButton","ActionButton"))
  secondControl.AbsolutePosition=vec(530,610)
  secondControl.AbsoluteSize=vec(120,30)
 end
 local addSlot=function()
  local slot=put(theirItems,node("Frame","NewItem1"))
  local itemName=put(slot,node("Frame","ItemName"))
  local label=put(itemName,node("TextLabel","Label"))
  label.Text="FixtureValueItem"
  local small=put(slot,node("Frame","Container"))
  local amount=put(small,node("TextLabel","Amount"))
  amount.Text=options.stacked and "x5" or ""
  return slot
 end
 local altSlot=nil
 local Players={}
 local lp={Name="FixtureMain",UserId=101,Parent=Players}
 local alt={Name="FixtureAlt",DisplayName="FakeDisplayName",UserId=202,Parent=Players}
 Players.LocalPlayer=lp
 function Players:FindFirstChild(name) if name=="FixtureAlt" then return alt end end
 function Players:GetPlayerByUserId(id)if id==202 then return alt end
  if id==101 then return lp end end
 function lp:FindFirstChildOfClass(k)if k=="PlayerGui" then return PG end end
 local rs=node("ReplicatedStorage","ReplicatedStorage")
 local remotes=put(rs,node("Folder","Trade"))
 if not options.noRemote then
  put(remotes,node("RemoteEvent","AcceptTrade"))
 end
 local time=10
 local render=event()
 local services={Players=Players,ReplicatedStorage=rs,
  Workspace={CurrentCamera={ViewportSize=vec(options.vw or 1024,options.vh or 768)}},
  RunService={RenderStepped=render},
  HttpService={JSONEncode=function(_,obj)return serde.encode("json",obj)end}
 }
 local reads={}
 local game={
  PlaceId=options.wrongPlace and 34567 or 142823291,
  JobId="JOB_TEST_20261114_A",
  GetService=function(_,key)return services[key]end,
  HttpGet=function(_,url)
   table.insert(reads,url)
   if url:find("c6830816c23624d43da2242e15a716127629a189",1,true)
     and url:find("main_alt_accept_control_shape_probe.lua",1,true)then
    return coreCode
   elseif url:find("1971b93d324f0275e6a9affb472ac3e804439ed8",1,true)
     and url:find("p4_native_observer.lua",1,true)then
    return stage9Code
   elseif url:find("1971b93d324f0275e6a9affb472ac3e804439ed8",1,true)
     and url:find("p4_observer_contract.lua",1,true)then
    return contractCode
   elseif url:find("5b8ee35d7f281c23d9c2181abd97a063e59a0660",1,true)
     and url:find("stage100_screen_prompt_overlay.lua",1,true)then
    return geomCode
   end
   error("un-pinned source "..tostring(url))
  end
 }
 local E={PDIDDLER_ACCEPT_DISCOVERY_ALT_NAME="FixtureAlt"}
 if options.existingOwner then
  E.PDIDDLER_SUPERVISED_P3_NATIVE_OWNER={}
 end
 local copied={}
 local printLog={}
 local env={
  game=game,getgenv=function()return E end,
  Instance={new=function(class)
   if options.failUI and class=="ScreenGui" then error("UI FAIL")end
   return node(class)
  end},
  Enum={ZIndexBehavior={Sibling="Sibling"},
   TextXAlignment={Left="Left"},
   Font={GothamBold="GothamBold"}},
  Color3={fromRGB=function(...)return {...}end},
  UDim={new=function(...)return {...}end},
  UDim2={fromOffset=function(...)return {...}end},
  os={clock=function()return time end},
  typeof=function(x)return type(x)end,
  warn=function()end,
  print=function(...)table.insert(printLog,tostring((...)))end,
  setclipboard=function(txt)table.insert(copied,txt)end
 }
 env.loadstring=function(code)
  return luau.load(code,{environment=env,injectGlobals=true})
 end
 local function run()
  return luau.load(runner,{environment=env,injectGlobals=true})()
 end
 local function button(name)
  for _,x in ipairs(everything) do
   if x.Name==name and x.Parent~=nil then return x end
  end
  return nil
 end
 local function open()
  scr.Enabled=true
  if options.twoRoots then
   local scr2=put(PG,node("ScreenGui","TradeGUI"))
   local cont2=put(scr2,node("Frame","Container"))
   put(cont2,node("Frame","Trade"))
  end
 end
 local function tick(dt)
  time+=dt or 0.08
  render:Fire()
 end
 return {run=run,open=open,tick=tick,addSlot=addSlot,
  button=button,copied=copied,E=E,root=root,screen=scr,
  username=username,alt=alt,mineAccepted=mineAccepted,
  altAccepted=altAccepted,acceptControl=acceptControl,
  secondControl=secondControl,reads=reads,
  printLog=printLog,game=game,services=services}
end
local core=luau.load(coreCode)()
do
 local f=fake()
 local r=core.inspect(f.root,{x=1024,y=768})
 eq(r.status,"ONE_VISIBLE_CANDIDATE_SHAPE","pure one visible control")
 eq(r.candidatePath,"Buttons/Accept/ActionButton","relative exact GUI path")
 eq(r.candidateClass,"ImageButton","class from actual GUI")
 eq(r.candidateBoundsVerified,true,"onscreen bounds")
 eq(r.candidateCount,1,"one candidate")
 eq(r.authorizesAccept,false,"no pure grant")
 eq(core.remotePresence(f.services.ReplicatedStorage),
   "NAMED_REMOTE_EVENT_EXISTS_UNAUTHENTICATED","remote exists but no proof")
end
do
 local f=fake({noAccept=true})
 eq(core.inspect(f.root,{x=1024,y=768}).status,
    "INCONCLUSIVE","missing clickable control inconclusive")
end
do
 local f=fake({acceptInYourOffer=true})
 local result=core.inspect(f.root,{x=1024,y=768})
 eq(result.status,"ONE_VISIBLE_CANDIDATE_SHAPE",
    "Accept control under MAIN YourOffer is considered")
 eq(result.candidatePath,"YourOffer/Accept/ActionButton",
    "no incorrect exclusion of MAIN-side control")
end
do
 local f=fake({noAccept=true,labelOnly=true})
 local result=core.inspect(f.root,{x=1024,y=768})
 eq(result.status,"INCONCLUSIVE","label alone is not clickable")
 eq(result.labelOnlyCount,1,"label-only discovery correctly reported")
 eq(result.candidateCount,0,"never treat text-only Accept label as action")
end

do
 local f=fake({twoAccept=true})
 eq(core.inspect(f.root,{x=1024,y=768}).status,
    "AMBIGUOUS","two controls never auto-selected")
end
do
 local f=fake({noRemote=true})
 eq(core.remotePresence(f.services.ReplicatedStorage),
    "ABSENT_OR_UNVERIFIED","no remote no invention")
end
do
 local f=fake()
 local runner=f.run()
 ok(type(runner)=="table","actual native controller loaded")
 eq(#f.reads,4,"four frozen modules loaded")
 eq(f.button("ArmObserver").Text,"ARM READ-ONLY","explicit arm required")
 eq(runner.status().actualAccepts,0,"no Accept before arm")
 f.button("ArmObserver").Activated:Fire()
 f.tick(0.1)
 f.open();f.tick(0.08)
 f.addSlot();f.tick(0.1)
 f.tick(0.55)
 eq(runner.status().status,"CLIENT_ACCEPT_CONTROL_OBSERVED","client shape probe complete")
 eq(runner.status().controlShapeStatus,
   "ONE_VISIBLE_CANDIDATE_SHAPE","one candidate in original GUI")
 eq(runner.status().visibleButtonCount,1,"one visible clickable candidate in trade root")
 eq(runner.status().acceptTextLabelOnlyCount,0,"no title mistaken for Accept label")
 eq(runner.status().candidatePath,"Buttons/Accept/ActionButton","no dynamic path from user")
 eq(runner.status().theirVisibleSlots,1,"one ALT physical slot")
 eq(runner.status().ourVisibleSlots,0,"MAIN empty")
 eq(runner.status().bothAcceptedIndicatorsReadable,true,"both accepted indicators read")
 eq(runner.status().acceptedState,"MAIN_FALSE_ALT_FALSE","no final Accept either side")
 eq(runner.status().twoStableCaptures,true,"independent repeated read")
 eq(runner.status().mainAltAccountLookupExact,true,"MAIN and ALT exact client objects")
 eq(runner.status().clientTradePartnerLabelMatches,true,"label exact account")
 eq(runner.status().acceptNamedRemoteStatus,
   "NAMED_REMOTE_EVENT_EXISTS_UNAUTHENTICATED","remote metadata only")
 eq(runner.status().confirmedNativeAcceptBinding,false,"not a binding proof")
 eq(runner.status().authorizedAutoAccept,false,"no live grant")
 eq(runner.status().actualOffers,0,"no outgoing item")
 eq(runner.status().actualAccepts,0,"no final Accept")
 f.button("StopAndCopy").Activated:Fire()
 eq(#f.copied,1,"copied one sanitized report")
 local encoded=f.copied[1]
 local data=serde.decode("json",encoded)
 eq(data.status,"CLIENT_ACCEPT_CONTROL_OBSERVED","copied actual result")
 for _,secret in ipairs({"FixtureAlt","FixtureMain","FixtureValueItem",
     "JOB_TEST_20261114_A","101","202"}) do
  ok(not encoded:find('"'..secret..'"',1,true),"private identifiers excluded: "..secret)
 end
 ok(runner.status().authorizesAccept==false,"no authorization after copy")
 f.tick(1)
 eq(#f.copied,1,"stopped controller never repeats")
end
do
 local f=fake({noAccept=true})
 local runner=f.run()
 f.button("ArmObserver").Activated:Fire()
 f.open();f.tick()
 f.addSlot();f.tick()
 f.tick(0.5)
 eq(runner.status().status,"CLIENT_ACCEPT_CONTROL_OBSERVED","source observation retained if no control")
 eq(runner.status().controlShapeStatus,"INCONCLUSIVE","no candidate explicitly inconclusive")
 eq(runner.status().candidateCount,0,"no false control")
end
do
 local f=fake({twoAccept=true})
 local runner=f.run()
 f.button("ArmObserver").Activated:Fire()
 f.open();f.tick()
 f.addSlot();f.tick()
 f.tick(0.5)
 eq(runner.status().controlShapeStatus,"AMBIGUOUS","multiple control candidates")
 eq(runner.status().authorizesAccept,false,"ambiguous never offers Accept")
end
do
 local f=fake({wrongPartner=true})
 local runner=f.run()
 f.button("ArmObserver").Activated:Fire()
 f.open();f.tick()
 eq(runner.status().status,"STOPPED","wrong partner label full stop")
 eq(runner.status().reason,"UNVERIFIED_OR_WRONG_PARTNER_LABEL","exact reason")
end
do
 local f=fake({twoRoots=true})
 local runner=f.run()
 f.button("ArmObserver").Activated:Fire()
 f.open();f.tick()
 eq(runner.status().reason,"MULTIPLE_VISIBLE_TRADE_ROOTS","duplicate GUI root stop")
end
do
 local f=fake()
 local runner=f.run()
 f.button("ArmObserver").Activated:Fire()
 f.open();f.tick()
 f.addSlot();f.tick()
 f.altAccepted.Visible=true;f.tick(0.5)
 eq(runner.status().status,"STOPPED","ALT manually final accepted aborts")
 eq(runner.status().reason,"UNEXPECTED_MANUAL_FINAL_ACCEPT_STATE","specific manual final Accept stop")
end
do
 local f=fake()
 local runner=f.run()
 f.button("ArmObserver").Activated:Fire()
 f.open();f.tick()
 f.addSlot();f.tick()
 f.acceptControl.Name="UnexpectedButton";f.tick(0.5)
 eq(runner.status().reason,"ACTIVE_TRADE_OFFER_OR_ACCEPT_CONTROL_CHANGED",
    "GUI button changes between observations abort")
end
do
 local f=fake()
 local runner=f.run()
 f.button("ArmObserver").Activated:Fire()
 f.open();f.tick()
 f.addSlot();f.tick()
 f.alt.Parent=nil;f.tick(0.5)
 eq(runner.status().reason,"EXACT_PAIR_JOB_OR_CONTROLLER_CHANGED","ALT left server")
end
do
 local f=fake({existingOwner=true})
 eq(f.run(),nil,"another controller blocks startup")
 eq(#f.reads,0,"no remote source fetch with overlapping controller")
end
do
 local f=fake({wrongPlace=true})
 eq(f.run(),nil,"different Roblox place blocks")
 eq(#f.reads,0,"game check before source read")
end
do
 local f=fake({failUI=true})
 eq(f.run(),nil,"panel construction fails closed")
end
print("[PASS] MAIN ALT original-MM2 Accept control read-only native: "..passed.." Lune assertions")
