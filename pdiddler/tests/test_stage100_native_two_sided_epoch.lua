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
 epoch=file(assert(os.getenv("STAGE100_ORIGINAL_STAGE98")))
}
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
 function game:GetService(k)
  if k=="Players" then return players end
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
 _G.getgenv=function()return env end
 _G.warn=function(msg)printed[#printed+1]="WARN: "..tostring(msg) end
 _G.print=function(msg)
  printed[#printed+1]=tostring(msg)
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
  clipboard=env.clipboard}
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
 eq(t.sources,3)
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
 eq(t.sources,0)
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
