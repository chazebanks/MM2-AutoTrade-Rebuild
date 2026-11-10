-- Stage103 executes the actual read-only Delta wrapper with mocked Roblox UI.
-- Fetches IMMUTABLE original Stage9 + already reviewed Stage98 Lua source.
-- No server, no real user inventory, no clicked Roblox GUI.
local SCRIPT="pdiddler/new_part4/STAGE103_READONLY_ARCHIVED_VALUE_OVERLAY.lua"
local function file(p)
 local f=assert(io.open(p,"rb"));local s=f:read("*a");f:close();return s
end
local modules={
 contract=file(assert(os.getenv("STAGE103_ORIGINAL_STAGE9"))),
 native=file(assert(os.getenv("STAGE103_ORIGINAL_NATIVE"))),
 epoch=file(assert(os.getenv("STAGE103_ORIGINAL_STAGE98"))),
 values=file(assert(os.getenv("STAGE103_ORIGINAL_STAGE102"))),
 archive=file("pdiddler/intelligence_lab/stage102_pinned_public_reference_2026_11_09.json"),
 layout=file("pdiddler/new_part4/stage100_screen_prompt_overlay.lua")
}
local Layout=assert(load(modules.layout))()
local decodedArchive=assert(loadfile(assert(os.getenv("STAGE103_ARCHIVE_LUA"))))()
local printOriginal=print
local clockOriginal=os.clock
local timeOriginal=os.time
local xpcallOriginal=xpcall
local groups=0
local function eq(a,b,why)
 assert(a==b,(why or "mismatch").." actual="..tostring(a).." expected="..tostring(b))
end
local function test(name,fn)
 local ok,err=pcall(fn)
 if not ok then error("STAGE103 FAIL "..name..": "..tostring(err)) end
 groups=groups+1
 printOriginal("PASS Stage103 "..name)
end
local function scenario(mode)
 mode=mode or {}
 local elapsed=5000
 local traces={}
 local gui=nil
 local target=nil
 local phase=0
 local phaseAt=0
 local actions={}
 local extraSecondRevisionDone=false
 local errorDetails=nil
 local readyCount=0
 local sources=0
 local printed={}
 local guiObjects={}
 local createdPromptGui=nil
 local guideSnapshots={}
 local function guiObjectByName(name)
  for _,x in ipairs(guiObjects) do
   if x.Name==name then return x end
  end
  return nil
 end
 local function node(class,name,parent)
  local n={ClassName=class,Name=name,Parent=parent,
    Visible=true,Enabled=true,Text="",children={},order={},attrs={}}
  function n:IsA(which)
   return which==self.ClassName or (which=="GuiObject" and
     (self.ClassName=="Frame" or self.ClassName=="TextLabel" or
      self.ClassName=="TextButton"))
  end
  function n:FindFirstChild(which,recursive)
   if self.children[which] then return self.children[which] end
   if recursive then
    for _,v in ipairs(self.order) do
     local found=v:FindFirstChild(which,true)
     if found then return found end
    end
   end
   return nil
  end
  function n:GetAttribute(k)return self.attrs[k] end
  function n:GetDescendants()
   local out={}
   local function visit(x)
    for _,v in ipairs(x.order) do
     out[#out+1]=v;visit(v)
    end
   end
   visit(self);return out
  end
  if parent then
   parent.children[name]=n
   parent.order[#parent.order+1]=n
  end
  return n
 end
 local function remove(parent,key)
  local x=parent.children[key]
  if not x then return end
  parent.children[key]=nil
  x.Parent=nil
  for i,v in ipairs(parent.order) do
   if v==x then table.remove(parent.order,i);break end
  end
 end
 local players={Name="Players"}
 function players:IsA(x)return x=="Players" end
 local main={Name="main_test_user",UserId=1,Parent=players}
 local alt={Name="venossgaming90190",UserId=2,Parent=players}
 function main:IsA(x)return x=="Player" end
 function alt:IsA(x)return x=="Player" end
 players.LocalPlayer=main
 function players:GetPlayers()
  if mode.noTarget then return {main} end
  if mode.duplicateTarget then
   local shadow={Name=alt.Name:upper(),UserId=3,Parent=players}
   return {main,alt,shadow}
  end
  return {main,alt}
 end
 function players:GetPlayerByUserId(id)
  if mode.partnerGone then return nil end
  if id==1 then return main end
  if id==2 then return alt end
  return nil
 end
 local pg=node("PlayerGui","PlayerGui")
 pg.Parent=main
 function main:FindFirstChildOfClass(k)
  return k=="PlayerGui" and pg or nil
 end
 gui=node("ScreenGui","TradeGUI_Phone",pg)
 if mode.delayedWindow or mode.noWindow then gui.Enabled=false end
 local container=node("Frame","Container",gui)
 local trade=node("Frame","Trade",container)
 trade.AbsolutePosition={X=330,Y=190}
 trade.AbsoluteSize={X=360,Y=385}
 if mode.tradeRight then
  trade.AbsolutePosition={X=0,Y=100}
  trade.AbsoluteSize={X=685,Y=615}
 end
 if mode.tradeFullscreen then
  trade.AbsolutePosition={X=0,Y=0}
  trade.AbsoluteSize={X=1024,Y=768}
 end
 local own=node("Frame","YourOffer",trade)
 local their=node("Frame","TheirOffer",trade)
 local ownBox=node("Frame","Container",own)
 local theirBox=node("Frame","Container",their)
 local username=node("TextLabel","Username",their)
 username.Text=mode.wrongPartner and "(random)" or "("..alt.Name..")"
 local ourAccepted=node("Frame","Accepted",own);ourAccepted.Visible=false
 local theirAccepted=node("Frame","Accepted",their);theirAccepted.Visible=false
 if mode.doubleRoot then
  local g2=node("ScreenGui","TradeGUI",pg)
  local c=node("Frame","Container",g2)
  node("Frame","Trade",c)
 end
 local function place(box,n,label,amount)
  local frame=node("Frame","NewItem"..n,box)
  local named=node("Frame","ItemName",frame)
  local text=node("TextLabel","Label",named);text.Text=label
  local area=node("Frame","Container",frame)
  if not mode.noAmount then
   local amountNode=node("TextLabel","Amount",area)
   amountNode.Text=amount or ""
  end
  return frame
 end
 if mode.preexistingOffer then place(theirBox,1,"Batwing","") end
 local game={PlaceId=mode.wrongPlace and 123 or 142823291,JobId="server-mock"}
 local workspaceService={CurrentCamera={
  ViewportSize={X=1024,Y=768}
 }}
 if mode.tinyViewport then
  workspaceService.CurrentCamera.ViewportSize={X=260,Y=240}
 end
 function game:GetService(k)
  if k=="Players" then return players end
  if k=="Workspace" then return workspaceService end
  if k=="HttpService" then return {JSONEncode=function(_,r)
    return '{"status":"'..tostring(r.status)..'","reason":"'..tostring(r.reason)..'"}'
   end,JSONDecode=function(_,raw)
    assert(type(raw)=="string" and #raw>16000 and #raw<52000)
    if mode.badArchive then return {} end
    return decodedArchive
   end}
  end
  error("Unsupported GetService "..tostring(k))
 end
 function game:HttpGet(url)
  sources=sources+1
  assert(url:find("raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/",1,true))
  if url:find("p4_observer_contract.lua",1,true) then return modules.contract end
  if url:find("p4_native_observer.lua",1,true) then return modules.native end
  if url:find("stage98_client_offer_epoch.lua",1,true) then return modules.epoch end
  if url:find("stage102_lua_public_reference_preview.lua",1,true) then return modules.values end
  if url:find("stage102_pinned_public_reference_2026_11_09.json",1,true) then return modules.archive end
  if url:find("stage100_screen_prompt_overlay.lua",1,true) then
   return modules.layout
  end
  error("Unexpected requested module "..url)
 end
 local armed=true
 if mode.disarmed then armed=false end
 local env={
  PDIDDLER_STAGE103_TARGET_USERNAME=mode.badUsername and "%" or alt.Name,
  PDIDDLER_STAGE103_READONLY_ARMED=armed
 }
 if mode.competingOwner then env.PDIDDLER_OUTGOING_CONTROLLER={} end
 if mode.oldStage97 then env.GINGERSCOPE_STAGE97_PARTNER_EVENT_READONLY={} end
 -- Roblox GUI primitives needed by the actual user-visible instruction panel.
 -- These mocks do not expose or click any MM2 TradeGUI controls.
 _G.UDim2={new=function(xs,xo,ys,yo)
  return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}}
 end,fromOffset=function(x,y)
  return {X={Scale=0,Offset=x},Y={Scale=0,Offset=y}}
 end}
 _G.UDim={new=function(scale,offset)
  return {Scale=scale,Offset=offset}
 end}
 _G.Color3={fromRGB=function(r,g,b)return {r=r,g=g,b=b} end}
 _G.Enum={
  Font={Gotham="Gotham",GothamBold="GothamBold"},
  TextXAlignment={Left="Left"},
  TextYAlignment={Top="Top"}
 }
 _G.Instance={new=function(class)
  if mode.promptCreationUnavailable then error("GUI primitives unavailable") end
  local item={ClassName=class,Name="",Visible=true,Parent=nil}
  function item:Destroy() self.Parent=nil;self.destroyed=true end
  if class=="TextButton" then
   item.MouseButton1Click={Connect=function(_,cb)
    item.closeCallback=cb
    return {Disconnect=function()end}
   end}
  end
  guiObjects[#guiObjects+1]=item
  if class=="ScreenGui" then createdPromptGui=item end
  return item
 end}
 _G.getgenv=function()return env end
 _G.warn=function(msg)printed[#printed+1]="WARN: "..tostring(msg) end
 _G.print=function(msg)
  printed[#printed+1]=tostring(msg)
  if type(msg)=="string" and
     (msg:find("[STAGE103] WAIT_FOR_MANUAL_TRADE_WINDOW",1,true) or
      msg:find("[STAGE103] READY_",1,true)) then
   local step=guiObjectByName("GuideStep")
   local instruction=guiObjectByName("GuideInstruction")
   guideSnapshots[#guideSnapshots+1]={
    step=step and step.Text, instruction=instruction and instruction.Text
   }
  end
  if type(msg)=="string" and msg:find("[STAGE103] READY_ALT_ADD_ONE",1,true) then
   phase=1;phaseAt=elapsed;readyCount=readyCount+1
  elseif type(msg)=="string" and msg:find("[STAGE103] READY_MAIN_ADD_ONE",1,true) then
   phase=2;phaseAt=elapsed;readyCount=readyCount+1
  end
 end
 _G.setclipboard=function(t)env.clipboard=t end
 _G.game=game
 _G.loadstring=load
 _G.task={}
 function task.spawn(fn)fn()end
 function task.wait(delta)
  elapsed=elapsed+(tonumber(delta) or .1)
  if mode.delayedWindow and elapsed>=5000.7 then gui.Enabled=true end
  if phase>0 and not actions[phase] and elapsed-phaseAt>=.33 then
   actions[phase]=true
   if mode.jobChanged then game.JobId="new_job" end
   if mode.guiClosed then gui.Enabled=false end
   if mode.accepted then theirAccepted.Visible=true end
   if phase==1 and not mode.noAltAdd then
    place(theirBox,1,"Batwing",mode.altStack and "x2" or "")
   elseif phase==2 and not mode.noMainAdd then
    if mode.altChangedDuringMain then
     remove(theirBox,"NewItem1")
     place(theirBox,1,"ChangedAltItem","")
    end
    place(ownBox,1,mode.protectedOwn and "Gingerscope" or mode.unknownOwn and "Mystery Sword" or "Emberbow",mode.ownStack and "x2" or "")
   elseif phase==3 and not mode.noAltRemoval then
    remove(theirBox,"NewItem1")
    if mode.mainChangedDuringRemoval then
     remove(ownBox,"NewItem1")
     place(ownBox,1,"DifferentOwnItem","")
    end
    if mode.altReplacedInsteadOfRemoved then
     place(theirBox,1,"NewAltItem","")
    end
   end
  end
  if mode.mutateDuringPreview and phase==2 and actions[2] and
     not extraSecondRevisionDone and elapsed-phaseAt>=1.3 then
    extraSecondRevisionDone=true
    local item=ownBox:FindFirstChild("NewItem1")
    local names=item and item:FindFirstChild("ItemName")
    local label=names and names:FindFirstChild("Label")
    if label then label.Text="OtherAfterPreview" end
  end
 end
 os.clock=function()return elapsed end
 os.time=function()return mode.preExpiry and 1794300000 or 1794349609 end
 _G.xpcall=function(fn,handler)
  local ok,x=xpcallOriginal(fn,function(err)return debug.traceback(tostring(err),2)end)
  if not ok then errorDetails=x end
  return ok,x
 end
 local ok,handle=pcall(function()return assert(loadfile(SCRIPT))()end)
 _G.print=printOriginal;_G.xpcall=xpcallOriginal;os.clock=clockOriginal;os.time=timeOriginal
 if not ok then error("Stage103 launcher threw: "..tostring(handle)) end
 return {report=handle and handle.report,logs=printed,
  errorDetails=errorDetails,sources=sources,ready=readyCount,
  clipboard=env.clipboard,promptGui=createdPromptGui,
  guideSteps=guideSnapshots,guideStep=guiObjectByName("GuideStep"),
  guideInstruction=guiObjectByName("GuideInstruction"),
  guidePanel=guiObjectByName("GuidePanel"),
  guideDismiss=guiObjectByName("DismissWhenFinished")}
end
local function denied(t)
 local r=t.report
 assert(type(r)=="table","missing structured sanitized report")
 for _,k in ipairs({"actualRequestTaps","actualOffers","actualAccepts",
 "actualDeclines","actualTeleports"}) do eq(r[k],0,k) end
 for _,k in ipairs({"eventSessionAssociationProven","callbackCausalityProven",
 "ownerSideSlotBound","rawItemIdConfirmed","uniqueWeaponInstanceProven",
 "authenticatedOwnedInventory","currentGameCatalogueAuthenticated",
 "numericSupremeCheckerIdVerified","sourcePublisherFresh",
 "currentPricesVerified","priceForTradeVerified","marketValueAuthority",
 "serverTradeRevisionProven","serverAttestation","serverCompletionProven",
 "authorizesTrade","authorizesAccept","mayRecordCompletedTrade",
 "mayReportProfit","maySendDiscordWebhook","mayUseForStrategyLearning",
 "noUnobservedMutationsProven"}) do eq(r[k],false,k) end
 eq(r.readOnly,true);eq(r.clientOnly,true);eq(r.tradeOutcome,"UNKNOWN")
 for _,v in ipairs(t.logs) do
  assert(not v:find("Batwing",1,true),"item name leaked")
  assert(not v:find("Gingerscope",1,true),"second item name leaked")
  assert(not v:find("venossgaming90190",1,true),"partner leaked")
  assert(not v:find("server-mock",1,true),"job id leaked")
 end
end


test("actual original Part4 and 189 archive rendered on trade-safe in-game panel",function()
 local t=scenario()
 eq(t.report.status,"CLIENT_ARCHIVED_TWO_SIDED_NAME_VALUE_PREVIEW_DISPLAYED",
    tostring(t.report.reason).." "..tostring(t.errorDetails))
 eq(t.report.archiveRowsLoaded,189)
 eq(t.report.marketSourceState,"ARCHIVED_RESEARCH_CAPTURE_EXPIRED")
 eq(t.report.matchedOfferCandidates,2)
 eq(t.report.twoSidedReferencePreviewObserved,true)
 eq(t.report.protectedGingerscopeCandidateVisible,false)
 eq(t.ready,2);eq(t.sources,6)
 eq(t.report.onScreenGuideFinalShown,true)
 eq(t.report.onScreenGuideNonOverlappingTrade,true)
 eq(t.guidePanel.Draggable,false);eq(t.guidePanel.Active,false)
 eq(t.guideDismiss.Visible,true)
 assert(t.guideInstruction.Text:find("Emberbow",1,true))
 assert(t.guideInstruction.Text:find("Batwing",1,true))
 assert(t.guideInstruction.Text:find("650",1,true))
 eq(t.report.onScreenGuideCurrentStep,"ARCHIVED NOV 9 • NOT CURRENT")
 denied(t)
end)
test("preexpiry snapshot remains public research without current price authority",function()
 local t=scenario({preExpiry=true})
 eq(t.report.status,"CLIENT_ARCHIVED_TWO_SIDED_NAME_VALUE_PREVIEW_DISPLAYED",t.report.reason)
 eq(t.report.marketSourceState,"HISTORICAL_RESEARCH_WITHIN_CAPTURE_WINDOW")
 denied(t)
end)
test("protected MAIN Gingerscope halts without real offer or Accept",function()
 local t=scenario({protectedOwn=true})
 eq(t.report.status,"INCONCLUSIVE")
 eq(t.report.reason,"PROTECTED_GINGERSCOPE_IN_OUR_OFFER")
 eq(t.report.protectedGingerscopeCandidateVisible,true)
 denied(t)
end)
test("unmatched public item is disclosed as missing",function()
 local t=scenario({unknownOwn=true})
 eq(t.report.status,"CLIENT_ARCHIVED_TWO_SIDED_NAME_VALUE_PREVIEW_DISPLAYED",t.report.reason)
 eq(t.report.unmatchedOfferCandidates,1)
 assert(t.guideInstruction.Text:find("NO EXACT PUBLIC MATCH",1,true))
 denied(t)
end)
test("invalid source data fails before rendering values",function()
 local t=scenario({badArchive=true})
 eq(t.report.status,"INCONCLUSIVE")
 eq(t.report.reason,"PINNED_READONLY_MODULES_UNAVAILABLE")
 denied(t)
end)
test("manual offer mutation during archival price hold invalidates",function()
 local t=scenario({mutateDuringPreview=true})
 eq(t.report.status,"INCONCLUSIVE",t.report.reason)
 eq(t.report.offerPreviewInvalidatedDuringHold,true)
 denied(t)
end)
test("trade window on left uses safe right panel geometry",function()
 local t=scenario({tradeRight=true,delayedWindow=true})
 eq(t.report.status,"CLIENT_ARCHIVED_TWO_SIDED_NAME_VALUE_PREVIEW_DISPLAYED",t.report.reason)
 assert(t.guidePanel.Position.X.Offset>700)
 denied(t)
end)
test("fullscreen trade and tiny viewport never obstruct controls",function()
 for _,m in ipairs({{tradeFullscreen=true},{tinyViewport=true}}) do
  local t=scenario(m);eq(t.report.status,"INCONCLUSIVE");denied(t)
 end
end)
test("wrong partner and ambiguous GUI fail",function()
 for _,m in ipairs({{wrongPartner=true},{doubleRoot=true},{noTarget=true},
    {duplicateTarget=true},{competingOwner=true}}) do
  local t=scenario(m)
  if t.report then
   eq(t.report.status,"INCONCLUSIVE");denied(t)
  else
   eq(t.sources,0)
  end
 end
end)
test("disabled or invalid test account cannot start",function()
 for _,m in ipairs({{disarmed=true},{badUsername=true}}) do
  local t=scenario(m);eq(t.report,nil)
 end
end)
test("missing manual offer, accepted state or job change blocks value view",function()
 for _,m in ipairs({{noAltAdd=true},{noMainAdd=true},{accepted=true},
    {jobChanged=true},{guiClosed=true},{altStack=true},{ownStack=true}}) do
  local t=scenario(m);eq(t.report.status,"INCONCLUSIVE");denied(t)
 end
end)
test("no trade window within 30s never presents data",function()
 local t=scenario({noWindow=true})
 eq(t.report.status,"INCONCLUSIVE")
 eq(t.report.reason,"MANUAL_TRADE_WINDOW_NOT_OBSERVED_WITHIN_30S")
 denied(t)
end)
printOriginal("STAGE103_REAL_ARCHIVE_NATIVE_GUI_MOCK_PASS groups="..groups)
