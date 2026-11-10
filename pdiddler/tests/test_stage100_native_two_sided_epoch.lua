-- Stage100 executes the actual read-only Delta wrapper with mocked Roblox UI.
-- Fetches IMMUTABLE original Stage9 + already reviewed Stage98 Lua source.
-- No server, no real user inventory, no clicked Roblox GUI.
local SCRIPT="pdiddler/new_part4/STAGE100_READONLY_TWO_SIDED_EPOCH.lua"
local function file(p)
 local f=assert(io.open(p,"rb"));local s=f:read("*a");f:close();return s
end
local modules={
 contract=file(assert(os.getenv("STAGE100_ORIGINAL_STAGE9"))),
 native=file(assert(os.getenv("STAGE100_ORIGINAL_NATIVE"))),
 epoch=file(assert(os.getenv("STAGE100_ORIGINAL_STAGE98"))),
 layout=file("pdiddler/new_part4/stage100_screen_prompt_overlay.lua")
}
local Layout=assert(load(modules.layout))()
local printOriginal=print
local clockOriginal=os.clock
local xpcallOriginal=xpcall
local groups=0
local function eq(a,b,why)
 assert(a==b,(why or "mismatch").." actual="..tostring(a).." expected="..tostring(b))
end
local function test(name,fn)
 local ok,err=pcall(fn)
 if not ok then error("STAGE100 FAIL "..name..": "..tostring(err)) end
 groups=groups+1
 printOriginal("PASS Stage100 "..name)
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
  if url:find("stage100_screen_prompt_overlay.lua",1,true) then
   return modules.layout
  end
  error("Unexpected requested module "..url)
 end
 local armed=true
 if mode.disarmed then armed=false end
 local env={
  PDIDDLER_STAGE100_TARGET_USERNAME=mode.badUsername and "%" or alt.Name,
  PDIDDLER_STAGE100_READONLY_ARMED=armed
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
     (msg:find("[STAGE100] WAIT_FOR_MANUAL_TRADE_WINDOW",1,true) or
      msg:find("[STAGE100] READY_",1,true)) then
   local step=guiObjectByName("GuideStep")
   local instruction=guiObjectByName("GuideInstruction")
   guideSnapshots[#guideSnapshots+1]={
    step=step and step.Text, instruction=instruction and instruction.Text
   }
  end
  if type(msg)=="string" and msg:find("[STAGE100] READY_ALT_ADD_ONE",1,true) then
   phase=1;phaseAt=elapsed;readyCount=readyCount+1
  elseif type(msg)=="string" and msg:find("[STAGE100] READY_MAIN_ADD_ONE",1,true) then
   phase=2;phaseAt=elapsed;readyCount=readyCount+1
  elseif type(msg)=="string" and msg:find("[STAGE100] READY_ALT_REMOVE_ONE",1,true) then
   phase=3;phaseAt=elapsed;readyCount=readyCount+1
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
    place(ownBox,1,"Gingerscope",mode.ownStack and "x2" or "")
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
 end
 os.clock=function()return elapsed end
 _G.xpcall=function(fn,handler)
  local ok,x=xpcallOriginal(fn,function(err)return debug.traceback(tostring(err),2)end)
  if not ok then errorDetails=x end
  return ok,x
 end
 local ok,handle=pcall(function()return assert(loadfile(SCRIPT))()end)
 _G.print=printOriginal;_G.xpcall=xpcallOriginal;os.clock=clockOriginal
 if not ok then error("Stage100 launcher threw: "..tostring(handle)) end
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

test("two-sided real original GUI ALT add→MAIN add→ALT remove",function()
 local t=scenario()
 eq(t.report.status,"CLIENT_TWO_SIDED_OFFER_WITHDRAWAL_EPOCH_OBSERVED",
    tostring(t.report.reason).." debug="..tostring(t.errorDetails))
 eq(t.report.observedAltAdd,true)
 eq(t.report.observedMainAdd,true)
 eq(t.report.observedAltRemoval,true)
 eq(t.report.stableResearchPreviews,3)
 eq(t.report.revocationsVerified,2)
 eq(t.report.localOfferEpoch,4)
 eq(t.report.ourMaxSlotCount,1)
 eq(t.report.theirMaxSlotCount,1)
 eq(t.report.finalOwnSlotCount,1)
 eq(t.report.finalPartnerSlotCount,0)
 assert(t.report.stage9Frames>=10)
 eq(t.ready,3)
 eq(t.sources,4)
 eq(t.report.onScreenGuideShown,true)
 eq(t.report.onScreenGuideFinalShown,true)
 eq(t.report.onScreenGuideCurrentStep,"COMPLETE - CLIENT GUI ONLY")
 eq(#t.guideSteps,4)
 eq(t.guideSteps[1].step,"STEP 1/4: OPEN TRADE")
 eq(t.guideSteps[2].step,"STEP 2/4: ALT ADD")
 eq(t.guideSteps[3].step,"STEP 3/4: MAIN ADD")
 eq(t.guideSteps[4].step,"STEP 4/4: ALT REMOVE")
 assert(t.guideSteps[2].instruction:find("On ALT:",1,true))
 assert(t.guideSteps[3].instruction:find("On MAIN:",1,true))
 eq(t.guidePanel.Draggable,false)
 eq(t.guidePanel.Active,false)
 eq(t.report.onScreenGuideNonOverlappingTrade,true)
 eq(t.guideDismiss.Visible,true)
 denied(t)
end)
test("on-screen prompt cannot initialize: fail closed rather than console-only",function()
 local t=scenario({promptCreationUnavailable=true})
 eq(t.report.status,"INCONCLUSIVE")
 eq(t.report.reason,"IN_GAME_PROMPT_PANEL_UNAVAILABLE")
 eq(t.report.onScreenGuideShown,false)
 eq(t.report.observedAltAdd,false)
 eq(t.sources,1)
 eq(t.ready,0)
 denied(t)
end)
test("on-screen guide reports safe timeout visibly and can be dismissed afterwards",function()
 local t=scenario({noAltAdd=true})
 eq(t.report.status,"INCONCLUSIVE")
 eq(t.report.onScreenGuideShown,true)
 eq(t.report.onScreenGuideFinalShown,true)
 eq(t.guideStep.Text,"STOPPED - INCONCLUSIVE")
 eq(t.guideDismiss.Visible,true)
 assert(type(t.guideDismiss.closeCallback)=="function")
 t.guideDismiss.closeCallback()
 eq(t.promptGui.destroyed,true)
 denied(t)
end)
test("geometry planner chooses corners outside trade for varied screen layouts",function()
 local cases={
  {vp={x=1024,y=768},r={x=330,y=190,w=360,h=385}},
  {vp={x=1024,y=768},r={x=0,y=100,w=685,h=615}},
  {vp={x=768,y=1024},r={x=230,y=280,w=385,h=400}},
  {vp={x=1366,y=1024},r={x=335,y=190,w=705,h=700}}
 }
 for i,c in ipairs(cases) do
  local p,why=Layout.choose(c.vp,c.r,{w=292,h=154})
  assert(p,"missing free corner: "..tostring(why).." case "..i)
  assert(p.x>=14 and p.y>=72)
  assert(p.x+p.w<=c.vp.x-14 and p.y+p.h<=c.vp.y-34)
  assert(not (
    p.x<c.r.x+c.r.w+12 and p.x+p.w>c.r.x-12 and
    p.y<c.r.y+c.r.h+12 and p.y+p.h>c.r.y-12
  ),"panel overlaps trade GUI: "..i)
 end
end)
test("native overlay repositions to safe right side when trade occupies left",function()
 local t=scenario({tradeRight=true})
 eq(t.report.status,"CLIENT_TWO_SIDED_OFFER_WITHDRAWAL_EPOCH_OBSERVED",t.report.reason)
 assert(t.guidePanel.Position.X.Offset>700,"expected right safe strip")
 eq(t.report.onScreenGuideNonOverlappingTrade,true)
 denied(t)
end)
test("full-screen trade leaves no safe panel space; fail closed rather than cover",function()
 local t=scenario({tradeFullscreen=true})
 eq(t.report.status,"INCONCLUSIVE")
 eq(t.report.reason,"ONSCREEN_GUIDE_NO_SAFE_SPACE_OUTSIDE_TRADE")
 eq(t.report.observedAltAdd,false)
 eq(t.report.onScreenGuideNonOverlappingTrade,false)
 denied(t)
end)
test("tiny viewport cannot fit safe instructions; no manual prompts authorised",function()
 local t=scenario({tinyViewport=true})
 eq(t.report.status,"INCONCLUSIVE")
 eq(t.report.onScreenGuideShown,true)
 eq(t.report.onScreenGuidePlacementFailures>0,true)
 eq(t.ready,0)
 denied(t)
end)
test("manual trade window appears after startup",function()
 local t=scenario({delayedWindow=true})
 eq(t.report.status,"CLIENT_TWO_SIDED_OFFER_WITHDRAWAL_EPOCH_OBSERVED",t.report.reason)
 assert(t.report.tradeWindowWaitPolls>=5)
 denied(t)
end)
test("missing trade window times out with no original-source activation",function()
 local t=scenario({noWindow=true})
 eq(t.report.status,"INCONCLUSIVE")
 eq(t.report.reason,"MANUAL_TRADE_WINDOW_NOT_OBSERVED_WITHIN_30S")
 eq(t.sources,1)
 denied(t)
end)
test("wrong partner, ambiguous GUI and wrong game cannot bind",function()
 for _,m in ipairs({{wrongPartner=true},{doubleRoot=true},{wrongPlace=true},
  {noTarget=true},{duplicateTarget=true},{competingOwner=true}}) do
  local t=scenario(m)
  if t.report then eq(t.report.status,"INCONCLUSIVE",t.report.reason);denied(t) end
 end
end)
test("preexisting initial item prevents borrowed baseline",function()
 local t=scenario({preexistingOffer=true})
 eq(t.report.status,"INCONCLUSIVE")
 denied(t)
end)
test("ALT x2 stack does not mimic one independent item",function()
 local t=scenario({altStack=true})
 eq(t.report.status,"INCONCLUSIVE")
 eq(t.report.reason,"UNEXPECTED_TWO_SIDED_SLOT_COUNT_OR_STACK")
 denied(t)
end)
test("MAIN x2 stack does not mimic one owned offer item",function()
 local t=scenario({ownStack=true})
 eq(t.report.status,"INCONCLUSIVE")
 denied(t)
end)
test("ALT changes their item while MAIN adds: fail continuity",function()
 local t=scenario({altChangedDuringMain=true})
 eq(t.report.status,"INCONCLUSIVE")
 eq(t.report.reason,"ALT_ITEM_CHANGED_DURING_MAIN_ADD")
 denied(t)
end)
test("MAIN changes their own item during ALT removal: fail continuity",function()
 local t=scenario({mainChangedDuringRemoval=true})
 eq(t.report.status,"INCONCLUSIVE")
 eq(t.report.reason,"MAIN_ITEM_CHANGED_DURING_ALT_REMOVAL")
 denied(t)
end)
test("ALT replacing instead of withdrawing must fail",function()
 local t=scenario({altReplacedInsteadOfRemoved=true})
 eq(t.report.status,"INCONCLUSIVE")
 eq(t.report.reason,"UNEXPECTED_TWO_SIDED_SLOT_COUNT_OR_STACK")
 denied(t)
end)
test("skipped manual phase times out",function()
 for _,m in ipairs({{noAltAdd=true},{noMainAdd=true},{noAltRemoval=true}}) do
  local t=scenario(m)
  eq(t.report.status,"INCONCLUSIVE",t.report.reason)
  denied(t)
 end
end)
test("changed job, acceptance, closed trade and invalid Amount stop",function()
 for _,m in ipairs({{jobChanged=true},{accepted=true},
                    {guiClosed=true},{noAmount=true}}) do
  local t=scenario(m)
  eq(t.report.status,"INCONCLUSIVE",t.report.reason)
  denied(t)
 end
end)
test("disarmed or invalid consent username blocks source loading",function()
 for _,m in ipairs({{disarmed=true},{badUsername=true}}) do
  local t=scenario(m)
  eq(t.report,nil)
  eq(t.sources,0)
 end
end)
printOriginal("STAGE100_NATIVE_TWO_SIDED_MOCK_PASS groups="..groups)
