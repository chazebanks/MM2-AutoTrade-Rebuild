-- Stage97 actual standalone READ-ONLY Delta wrapper under fake Roblox instances.
-- Executes original pinned Stage9 observer and Stage95/96 pure inspectors.
local SCRIPT="pdiddler/new_part4/STAGE97_READONLY_PARTNER_EVENT_WITNESS.lua"
local function read(path)
 local f=assert(io.open(path,"rb"));local s=f:read("*a");f:close();return s
end
local modules={
 stage9contract=read(assert(os.getenv("STAGE97_ORIGINAL_STAGE9"))),
 stage9native=read(assert(os.getenv("STAGE97_ORIGINAL_NATIVE"))),
 stage83=read(assert(os.getenv("STAGE97_ORIGINAL_STAGE83"))),
 stage95=read("pdiddler/intelligence_lab/stage95_p4_public_slot_boundary.lua"),
 stage96=read("pdiddler/intelligence_lab/stage96_partner_event_gui_correlation.lua"),
}
local total=0
local function test(name,fn)
 local ok,err=pcall(fn)
 if not ok then error("STAGE97 FAIL "..name..": "..tostring(err)) end
 total=total+1
 print("PASS Stage97 "..name)
end
local function equals(a,b,label)
 assert(a==b,(label or "mismatch").." got="..tostring(a).." expected="..tostring(b))
end
local savedPrint=print
local function scenario(mode)
 mode=mode or {}
 local elapsed=5000
 local readyAt=nil
 local emitted=false
 local guiPreadded=false
 local receiptCount=0
 local connects,disconnects=0,0
 local sources=0
 local printed={}
 local p={}
 local function node(cls,name,parent)
  local n={ClassName=cls,Name=name,Parent=parent,Visible=true,Enabled=true,
   children={},order={},attrs={}}
  function n:IsA(x)
   return x==self.ClassName or
     (x=="GuiObject" and
      (self.ClassName=="Frame" or self.ClassName=="TextLabel" or
       self.ClassName=="TextButton"))
  end
  function n:FindFirstChild(name,recursive)
   if self.children[name] then return self.children[name] end
   if recursive then
    for _,ch in ipairs(self.order) do
     local res=ch:FindFirstChild(name,true)
     if res then return res end
    end
   end
   return nil
  end
  function n:GetDescendants()
   local out={}
   local function collect(root)
    for _,child in ipairs(root.order) do
     out[#out+1]=child
     collect(child)
    end
   end
   collect(self)
   return out
  end
  function n:GetChildren()return self.order end
  function n:GetAttribute(k)return self.attrs[k] end
  if parent then
   parent.children[name]=n;parent.order[#parent.order+1]=n
  end
  return n
 end
 local players={Name="Players"}
 local me={Name="test_main",UserId=1,Parent=players}
 local alt={Name="venossgaming90190",UserId=2,Parent=players}
 players.LocalPlayer=me
 function players:GetPlayers()
  if mode.noTarget then return {me} end
  if mode.duplicateTarget then
   return {me,alt,{Name=alt.Name:upper(),UserId=3,Parent=players}}
  end
  return {me,alt}
 end
 function players:GetPlayerByUserId(id)
  if mode.partnerChanged then return nil end
  if id==2 then return alt end
  if id==1 then return me end
  return nil
 end
 local pg=node("PlayerGui","PlayerGui",nil)
 pg.Parent=me
 function me:FindFirstChildOfClass(k)
  return k=="PlayerGui" and pg or nil
 end
 local gui=node("ScreenGui","TradeGUI_Phone",pg)
 local container=node("Frame","Container",gui)
 local trade=node("Frame","Trade",container)
 local own=node("Frame","YourOffer",trade)
 local their=node("Frame","TheirOffer",trade)
 local on=node("Frame","Container",own)
 local tn=node("Frame","Container",their)
 local u=node("TextLabel","Username",their)
 u.Text=mode.wrongPartner and "(wrong)" or "("..alt.Name..")"
 node("Frame","Accepted",own).Visible=false
 node("Frame","Accepted",their).Visible=false
 if mode.doubleTradeRoot then
  local g2=node("ScreenGui","TradeGUI",pg)
  local co=node("Frame","Container",g2)
  node("Frame","Trade",co)
 end
 local rep=node("ReplicatedStorage","ReplicatedStorage")
 local db=node("Folder","Database",rep)
 local sync=node("ModuleScript","Sync",db)
 local tradeFolder=node("Folder","Trade",rep)
 local remote=node("RemoteEvent","UpdateTrade",tradeFolder)
 local listeners={}
 local signal={}
 function signal:Connect(cb)
  connects=connects+1
  listeners[#listeners+1]=cb
  local connected=true
  return {Disconnect=function()
   if connected then disconnects=disconnects+1 end
   connected=false
   for i=1,#listeners do
    if listeners[i]==cb then table.remove(listeners,i);break end
   end
  end}
 end
 remote.OnClientEvent=signal
 if mode.ambiguousRemote then
  node("RemoteEvent","UpdateTrade",tradeFolder)
 end
 local cat={
  Scythe={ItemName="Batwing",ItemType="Knife",Rarity="Ancient",Chroma=false},
  Gingerscope={ItemName="Gingerscope",ItemType="Gun",Rarity="Ancient",Chroma=false},
 }
 local itemRaw=mode.wrongRawKey and "UnknownKey" or "Scythe"
 if mode.wrongCatalogue then cat.Scythe.ItemName="wrong" end
 local game={PlaceId=mode.wrongPlace and 999 or 142823291,
             JobId="JOB_TEST"}
 function game:GetService(k)
  if k=="Players" then return players end
  if k=="ReplicatedStorage" then return rep end
  if k=="HttpService" then return {
   JSONEncode=function(_,r)
    return '{"status":"'..tostring(r.status)..'","reason":"'..tostring(r.reason)..'"}'
   end
  } end
  error("unexpected service "..tostring(k))
 end
 function game:HttpGet(url)
  sources=sources+1
  for key,part in pairs({
    stage9contract="p4_observer_contract.lua",
    stage9native="p4_native_observer.lua",
    stage95="stage95_p4_public_slot_boundary.lua",
    stage96="stage96_partner_event_gui_correlation.lua",
    stage83="stage83_public_slug_registry.lua",
  }) do
   if url:find(part,1,true) then
    assert(url:find("raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/",1,true))
    return modules[key]
   end
  end
  error("unapproved url "..url)
 end
 local function addVisible(side,raw,qty)
  local slot=node("Frame","NewItem1",side)
  if mode.guiRaw then slot.attrs.ItemId="Scythe" end
  local named=node("Frame","ItemName",slot)
  local label=node("TextLabel","Label",named)
  label.Text=mode.wrongLabel and "Wrong" or "Batwing"
  local c=node("Frame","Container",slot)
  local amount=node("TextLabel","Amount",c)
  amount.Text=mode.wrongQuantity and "x2" or qty==2 and "x2" or ""
  return slot
 end
 if mode.preexistingOffer then addVisible(tn,"Scythe",1) end
 local function emit()
  emitted=true
  local ours={}
  local theirs={{itemRaw,mode.eventQuantity or 1,"Weapons"}}
  if mode.ownEventOffer then ours={{"Scythe",1,"Weapons"}} end
  local ev={LastOffer=1,Locked=false,
   Player1={Player=me,Accepted=false,Offer=ours},
   Player2={Player=mode.wrongEventPlayer and {} or alt,
     Accepted=false,Offer=theirs}}
  if mode.localSecond then
   ev.Player1,ev.Player2=
     {Player=alt,Accepted=false,Offer=theirs},
     {Player=me,Accepted=false,Offer=ours}
  end
  if mode.eventMalformed then ev.Locked=true end
  for _,cb in ipairs(listeners) do cb(ev);receiptCount=receiptCount+1 end
  if mode.duplicateEvent then
   for _,cb in ipairs(listeners) do cb(ev);receiptCount=receiptCount+1 end
  end
  if not mode.guiFirst then
   if mode.ourGuiChanged then addVisible(on,"Scythe",1) end
   addVisible(tn,"Scythe",mode.eventQuantity or 1)
  end
 end
 local env={PDIDDLER_STAGE97_READONLY_ARMED=mode.armed~=false,
    PDIDDLER_STAGE97_TARGET_USERNAME=mode.user or alt.Name}
 if mode.owner then env.PDIDDLER_OUTGOING_CONTROLLER={} end
 _G.getgenv=function()return env end
 _G.warn=function(s)printed[#printed+1]="WARN: "..tostring(s) end
 _G.print=function(s)
  printed[#printed+1]=tostring(s)
  if type(s)=="string" and s:find("[STAGE97] READY",1,true) then
   readyAt=elapsed
  end
 end
 _G.setclipboard=function(s)env.clipboard=s end
 _G.game=game
 _G.loadstring=load
 _G.require=function(x)
  assert(x==sync,"Unexpected ModuleScript required")
  return {Weapons=cat}
 end
 _G.task={}
 function task.spawn(fn) fn() end
 function task.wait(sec)
  elapsed=elapsed+(tonumber(sec) or 0.1)
  if readyAt and mode.guiFirst and not guiPreadded and elapsed-readyAt>=.08 then
   guiPreadded=true
   addVisible(tn,"Scythe",1)
  end
  if readyAt and not emitted and not mode.noEvent and
      elapsed-readyAt>=.24 then
   if mode.jobChanged then game.JobId="JOB_CHANGED" end
   emit()
  end
 end
 os.clock=function()return elapsed end
 local ok,ret=pcall(function()
  return assert(loadfile(SCRIPT))()
 end)
 _G.print=savedPrint
 if not ok then error("wrapper error: "..tostring(ret)) end
 local r=ret and ret.report or nil
 return {report=r,connects=connects,disconnects=disconnects,
  eventReceiptCount=receiptCount,sources=sources,logs=printed,
  clipboard=env.clipboard}
end
local function denied(s)
 local r=s.report
 assert(r,"report missing")
 for _,k in ipairs({
 "actualRequestTaps","actualOffers","actualAccepts","actualDeclines",
 "actualTeleports"
 }) do equals(r[k],0,k) end
 for _,k in ipairs({
 "eventSessionAssociationProven","callbackCausalityProven",
 "ownerSideSlotBound","rawItemIdConfirmed","uniqueWeaponInstanceProven",
 "authenticatedOwnedInventory","currentGameCatalogueAuthenticated",
 "numericSupremeCheckerIdVerified","sourcePublisherFresh",
 "currentPricesVerified","priceForTradeVerified","marketValueAuthority",
 "serverAttestation","serverCompletionProven",
 "authorizesTrade","authorizesAccept","mayRecordCompletedTrade",
 "mayReportProfit","maySendDiscordWebhook","mayUseForStrategyLearning"
 }) do equals(r[k],false,k) end
 equals(r.tradeOutcome,"UNKNOWN")
 equals(r.readOnly,true)
 equals(s.connects,s.disconnects)
 for _,l in ipairs(s.logs) do
  assert(not l:find("Scythe",1,true),"raw key leaked")
  assert(not l:find("Batwing",1,true),"weapon display leaked")
  assert(not l:find("venossgaming90190",1,true),"target name leaked")
 end
end
test("actual read-only original Stage9/95/96 wrapper observes partner event GUI consistency",function()
 local s=scenario()
 equals(s.report.status,"CLIENT_PARTNER_EVENT_GUI_NAME_QTY_CONSISTENT_UNATTRIBUTED",s.report.reason)
 equals(s.report.stage9ObserverBound,true)
 equals(s.report.partnerEventTupleObserved,true)
 equals(s.report.onePartnerGuiSlotObserved,true)
 equals(s.report.clientNameOnlyUnbound,true)
 equals(s.report.eventReceiptCount,1)
 equals(s.connects,1)
 denied(s)
end)
test("GUI raw attribute remains client-only even when exactly equal to event text",function()
 local s=scenario({guiRaw=true})
 equals(s.report.status,"CLIENT_PARTNER_EVENT_GUI_RAW_TEXT_CONSISTENT_UNATTRIBUTED",s.report.reason)
 equals(s.report.clientRawTextConsistent,true)
 denied(s)
end)
test("original Stage42 partner may be Player1 while local client is Player2",function()
 local s=scenario({localSecond=true})
 equals(s.report.status,"CLIENT_PARTNER_EVENT_GUI_NAME_QTY_CONSISTENT_UNATTRIBUTED",s.report.reason)
 denied(s)
end)
test("unknown event raw key is not silently inferred from GUI Batwing name",function()
 local s=scenario({wrongRawKey=true})
 equals(s.report.status,"INCONCLUSIVE")
 denied(s)
end)
test("wrong label, wrong quantity and current-client metadata fail closed",function()
 for _,m in ipairs({{wrongLabel=true},{wrongQuantity=true},{wrongCatalogue=true},
   {wrongEventPlayer=true},{eventMalformed=true},{ownEventOffer=true}}) do
  local s=scenario(m)
  equals(s.report.status,"INCONCLUSIVE",s.report.reason)
  denied(s)
 end
end)
test("multiple event receipts and missing event produce no attribution",function()
 for _,m in ipairs({{duplicateEvent=true},{noEvent=true}}) do
  local s=scenario(m)
  equals(s.report.status,"INCONCLUSIVE",s.report.reason)
  denied(s)
 end
end)
test("existing offer and ambiguous root/remote stop before any event binding",function()
 for _,m in ipairs({{preexistingOffer=true},{doubleTradeRoot=true},
    {ambiguousRemote=true}}) do
  local s=scenario(m)
  equals(s.report.status,"INCONCLUSIVE",s.report.reason)
  denied(s)
 end
end)
test("wrong partner, missing ALT, wrong game and competing owner never attach",function()
 for _,m in ipairs({{wrongPartner=true},{noTarget=true},
   {duplicateTarget=true},{wrongPlace=true},{owner=true}}) do
  local s=scenario(m)
  if s.report then
   equals(s.report.status,"INCONCLUSIVE",s.report.reason)
  else
   equals(s.connects,0)
  end
 end
end)
test("unexpected own-side GUI changes or changed job always reject",function()
 for _,m in ipairs({{ourGuiChanged=true},{jobChanged=true},{guiFirst=true}}) do
  local s=scenario(m)
  equals(s.report.status,"INCONCLUSIVE",s.report.reason)
  denied(s)
 end
end)
print("STAGE97_NATIVE_WRAPPER_MOCK_PASS groups="..total)
