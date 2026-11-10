-- Stage99: READ-ONLY original Stage9 Part4 GUI -> Stage98 local offer epoch.
-- Operator manually adds two DIFFERENT ALT-side items, then removes one.
-- No request, offer, Accept, Decline, hop, event listener, market or webhook.
-- Local visual revisions are NOT server-assigned revisions or item-ID proofs.
local E=(type(getgenv)=="function" and getgenv()) or _G
local KEY="GINGERSCOPE_STAGE99_OFFER_EPOCH_READONLY"
local SCHEMA="gingerscope-stage99-native-client-offer-epoch-research-v1"
local targetName=E.PDIDDLER_STAGE99_TARGET_USERNAME
if E.PDIDDLER_STAGE99_READONLY_ARMED~=true
   or type(targetName)~="string" or #targetName<3 or #targetName>20
   or not targetName:match("^[A-Za-z0-9_]+$") then
 warn("[STAGE99] explicitly arm READONLY and set exact consenting ALT username")
 return nil
end
if game.PlaceId~=142823291 then
 warn("[STAGE99] original MM2 place only")
 return nil
end
if E[KEY]~=nil then
 warn("[STAGE99] one-shot already used: fresh server required")
 return E[KEY]
end
for _,k in ipairs({
 "GINGERSCOPE_STAGE88_CONTACT_READONLY_PREVIEW",
 "GINGERSCOPE_STAGE89_SINGLE_REQUEST_DIAGNOSTIC",
 "GINGERSCOPE_STAGE90_CARD_LAYOUT_AUDIT",
 "GINGERSCOPE_STAGE91_SINGLE_REQUEST_DIAGNOSTIC",
 "GINGERSCOPE_STAGE92_SINGLE_REQUEST_DIAGNOSTIC",
 "GINGERSCOPE_STAGE93_SINGLE_REQUEST_DIAGNOSTIC",
 "PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW",
 "PDIDDLER_OUTGOING_CONTROLLER","PDIDDLER_OUTGOING_SESSION",
 "PDIDDLER_OUTGOING_BUSY_SESSION","PDIDDLER_PART4_SESSION",
 "PDIDDLER_PART4_CONTROLLER","PDIDDLER_HOPPING_SESSION",
 "PDIDDLER_PART5_CONTROLLER","PDIDDLER_STATUS_OWNER"
}) do
 if E[k]~=nil then
  warn("[STAGE99] existing transaction/probe owner, use fresh MM2 server")
  return nil
 end
end
local R={
 schema=SCHEMA,status="STARTING",reason="INITIALIZING",
 readOnly=true,clientOnly=true,oneShot=true,
 targetClientBound=false,exactPartnerGuiObserved=false,
 tradeWindowWaitPolls=0,stage9ObserverBound=false,stage9Frames=0,
 observedFirstAdd=false,observedSecondAdd=false,
 observedOneRemoval=false,revocationsVerified=0,
 localOfferEpoch=0,ourMaxSlotCount=0,theirMaxSlotCount=0,
 maxNameOnlySlotCount=0,stableResearchPreviews=0,
 actualRequestTaps=0,actualOffers=0,actualAccepts=0,
 actualDeclines=0,actualTeleports=0,
 guiOnlyNoEventCausality=true,noUnobservedMutationsProven=false,
 eventSessionAssociationProven=false,callbackCausalityProven=false,
 ownerSideSlotBound=false,rawItemIdConfirmed=false,
 uniqueWeaponInstanceProven=false,authenticatedOwnedInventory=false,
 currentGameCatalogueAuthenticated=false,numericSupremeCheckerIdVerified=false,
 sourcePublisherFresh=false,currentPricesVerified=false,
 priceForTradeVerified=false,marketValueAuthority=false,
 serverTradeRevisionProven=false,serverAttestation=false,
 serverCompletionProven=false,authorizesTrade=false,
 authorizesAccept=false,mayRecordCompletedTrade=false,
 mayReportProfit=false,maySendDiscordWebhook=false,
 mayUseForStrategyLearning=false,tradeOutcome="UNKNOWN",
 elapsedSeconds=0
}
local started=os.clock()
local Players=game:GetService("Players")
local LP=Players and Players.LocalPlayer
local PG=LP and LP:FindFirstChildOfClass("PlayerGui")
local I={running=true,report=R,jobId=tostring(game.JobId)}
E[KEY]=I
local target=nil
local function result()
 R.elapsedSeconds=math.floor(math.max(0,os.clock()-started))
 local ok,json=pcall(function()
  return game:GetService("HttpService"):JSONEncode(R)
 end)
 if ok and type(json)=="string" and #json<2500 then
  local line="[GINGERSCOPE STAGE99 OFFER EPOCH] "..json
  print(line)
  if type(setclipboard)=="function" then pcall(setclipboard,line) end
 else
  warn("[STAGE99] sanitized JSON report unavailable")
 end
end
local function finish(status,reason)
 if not I.running then return I end
 I.running=false
 R.status=status;R.reason=reason
 result()
 return I
end
local function live()
 return I.running and E[KEY]==I
  and tostring(game.JobId)==I.jobId and LP~=nil
  and LP.Parent==Players and PG~=nil and PG.Parent==LP
  and LP:FindFirstChildOfClass("PlayerGui")==PG
  and target~=nil and target.Parent==Players
  and Players:GetPlayerByUserId(target.UserId)==target
end
local function visible(node)
 if not node then return false end
 local x=node
 while x do
  if x:IsA("ScreenGui") and x.Enabled==false then return false end
  if x:IsA("GuiObject") and x.Visible==false then return false end
  x=x.Parent
 end
 return true
end
local function trim(s)
 if type(s)~="string" then return "" end
 return s:gsub("^%s+",""):gsub("%s+$",""):gsub("^@","")
end
local function exactRoot()
 if not live() then return nil,"SESSION_OR_TARGET_CHANGED" end
 local roots={}
 for _,gn in ipairs({"TradeGUI_Phone","TradeGUI"}) do
  local gui=PG:FindFirstChild(gn)
  local c=gui and gui:FindFirstChild("Container")
  local t=c and c:FindFirstChild("Trade")
  if t and visible(gui) and visible(t) then
   roots[#roots+1]=t
  end
 end
 if #roots~=1 then
  return nil,#roots>1 and "MULTIPLE_VISIBLE_TRADE_GUI_ROOTS" or
    "EXACT_TRADE_WINDOW_NOT_OPEN"
 end
 local root=roots[1]
 local theirs=root:FindFirstChild("TheirOffer")
 local name=theirs and theirs:FindFirstChild("Username")
 if not name or not (name:IsA("TextLabel") or name:IsA("TextButton"))
    or not visible(name) or type(name.Text)~="string" then
  return nil,"TRADE_PARTNER_HEADER_UNAVAILABLE"
 end
 local shown=name.Text:match("^%s*%((.-)%)%s*$") or name.Text
 if trim(shown):lower()~=target.Name:lower() then
  return nil,"TRADE_GUI_WRONG_PARTNER"
 end
 return root,"EXACT_CURRENT_CLIENT_PARTNER"
end
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local SOURCES={
 stage9contract={"1971b93d324f0275e6a9affb472ac3e804439ed8",
 "pdiddler/new_part4/p4_observer_contract.lua"},
 stage9native={"1971b93d324f0275e6a9affb472ac3e804439ed8",
 "pdiddler/new_part4/p4_native_observer.lua"},
 stage98={"642768973f5eb560a184119237c44c84697a208f",
 "pdiddler/intelligence_lab/stage98_client_offer_epoch.lua"}
}
local function source(key)
 local p=SOURCES[key]
 local ok,mod=pcall(function()
  local text=game:HttpGet(ROOT..p[1].."/"..p[2])
  assert(type(text)=="string" and #text>50 and #text<100000)
  return assert(loadstring(text))()
 end)
 if not ok or type(mod)~="table" then return nil end
 return mod
end
local function run()
 if LP==nil or PG==nil or not PG.Parent or PG.Parent~=LP then
  return finish("INCONCLUSIVE","MAIN_CLIENT_GUI_UNAVAILABLE")
 end
 local matches={}
 for _,p in ipairs(Players:GetPlayers()) do
  if p~=LP and type(p.Name)=="string"
     and p.Name:lower()==targetName:lower() and p.Parent==Players then
    matches[#matches+1]=p
  end
 end
 if #matches~=1 then return finish("INCONCLUSIVE","TARGET_NOT_UNIQUE_IN_SERVER") end
 target=matches[1]
 R.targetClientBound=true
 print("[STAGE99] WAIT_FOR_MANUAL_TRADE_WINDOW: open an EMPTY trade with the ALT within 30 seconds. Never final Accept.")
 local root,why=nil,"EXACT_TRADE_WINDOW_NOT_OPEN"
 local deadline=os.clock()+30
 while live() and os.clock()<deadline do
  root,why=exactRoot()
  R.tradeWindowWaitPolls=math.min(R.tradeWindowWaitPolls+1,600)
  if root then break end
  if why~="EXACT_TRADE_WINDOW_NOT_OPEN" then
   return finish("INCONCLUSIVE",why)
  end
  task.wait(.1)
 end
 if not live() then
  return finish("INCONCLUSIVE","SESSION_OR_TARGET_CHANGED_DURING_MANUAL_OPEN")
 end
 if not root then
  return finish("INCONCLUSIVE","MANUAL_TRADE_WINDOW_NOT_OBSERVED_WITHIN_30S")
 end
 R.exactPartnerGuiObserved=true
 local contract=source("stage9contract")
 local native=source("stage9native")
 local epochs=source("stage98")
 if not contract or not native or not epochs or
    type(contract.normalize)~="function" or
    type(contract.parseQuantity)~="function" or
    type(native.new)~="function" or type(native.capture)~="function" or
    type(epochs.new)~="function" or type(epochs.observe)~="function" or
    type(epochs.freezePreview)~="function" or
    type(epochs.checkPreview)~="function" then
  return finish("INCONCLUSIVE","PINNED_READONLY_MODULES_UNAVAILABLE")
 end
 local session="stage99:"..tostring(started)
 local lastRaw=nil
 local adapter={normalize=function(raw,_)
  lastRaw=raw
  return contract.normalize(raw,{marketFresh=false})
 end}
 local ok,handle=pcall(native.new,{
  game=game,players=Players,root=root,session=session,
  jobId=I.jobId,partnerUserId=target.UserId,localUserId=LP.UserId,
  contract=adapter,ownInventory=nil,opponentInventory=nil,
  marketFresh=function()return false end
 })
 if not ok or type(handle)~="table" then
  return finish("INCONCLUSIVE","ORIGINAL_STAGE9_OBSERVER_UNAVAILABLE")
 end
 local scope={session=session,jobId=I.jobId,root=root,
  localPlayer=LP,partnerPlayer=target}
 local state=epochs.new(scope,contract)
 if type(state)~="table" then
  return finish("INCONCLUSIVE","LOCAL_REVISION_STATE_UNAVAILABLE")
 end
 local function capture()
  local nowRoot,rootWhy=exactRoot()
  if not nowRoot or nowRoot~=root then
   return nil,rootWhy or "TRADE_GUI_ROOT_CHANGED"
  end
  lastRaw=nil
  local good,out,diag=pcall(native.capture,handle)
  local raw=lastRaw
  if not good or type(out)~="table" or type(diag)~="table"
     or type(raw)~="table" or out.tradeOpen~=true
     or out.session~=session or raw.contextOK~=true
     or out.quoteSafe~=false
     or type(out.ourSig)~="string" or type(out.theirSig)~="string"
     or out.ourSig:sub(1,10)=="unverified"
     or out.theirSig:sub(1,10)=="unverified"
     or out.ourSig=="capture-error" or out.theirSig=="capture-error"
     or type(out.ourSlots)~="number" or type(out.theirSlots)~="number"
     or out.ourSlots>4 or out.theirSlots>4
     or raw.our==nil or raw.their==nil
     or raw.our.accepted~=false or raw.their.accepted~=false
     or diag.authorizesTrade~=false or diag.authorizesAccept~=false then
   return nil,"ORIGINAL_STAGE9_CAPTURE_UNVERIFIED"
  end
  R.stage9Frames=R.stage9Frames+1
  return {
   raw=raw,at=os.clock(),session=session,jobId=I.jobId,
   root=root,localPlayer=LP,partnerPlayer=target
  }
 end
 local function observe()
  local v,reason=capture()
  if not v then return nil,reason end
  local report=epochs.observe(state,v)
  if type(report)~="table" or
     report.authorizesTrade~=false or report.authorizesAccept~=false
     or report.serverTradeRevisionProven~=false
     or report.serverCompletionProven~=false
     or report.currentPricesVerified~=false then
   return nil,"CLIENT_EPOCH_AUTHORITY_OR_RESULT_INVALID"
  end
  R.localOfferEpoch=report.localObservationRevision or 0
  R.ourMaxSlotCount=math.max(R.ourMaxSlotCount,report.ourSlotCount or 0)
  R.theirMaxSlotCount=math.max(R.theirMaxSlotCount,report.theirSlotCount or 0)
  R.maxNameOnlySlotCount=math.max(R.maxNameOnlySlotCount,
     report.nameOnlyGuiSlotCount or 0)
  if report.status=="INCONCLUSIVE" then return nil,report.reason end
  if (report.ourSlotCount or 0)~=0 or (report.ourCopyCount or 0)~=0 then
   return nil,"OUR_GUI_OFFER_NOT_EMPTY"
  end
  return report
 end
 -- Original Stage98 refuses starting from an already populated offer.
 local first,reason=observe()
 if not first then return finish("INCONCLUSIVE",reason) end
 if first.status~="CLIENT_LOCAL_OFFER_REVISION_CHANGED" or
    first.theirSlotCount~=0 then
  return finish("INCONCLUSIVE","INITIAL_OFFERS_NOT_EMPTY")
 end
 task.wait(.19)
 local baseline,why2=observe()
 if not baseline or baseline.status~="CLIENT_OFFER_STABLE_RESEARCH_ONLY"
    or baseline.theirSlotCount~=0 then
  return finish("INCONCLUSIVE",why2 or "INITIAL_EMPTY_OFFER_UNSTABLE")
 end
 R.stage9ObserverBound=true
 local token=nil
 local function phase(expectedCount,phaseName)
  print("[STAGE99] READY_"..phaseName..": change ALT offer MANUALLY to "..tostring(expectedCount).." DIFFERENT item slot(s). Leave MAIN empty. No Accept.")
  local untilAt=os.clock()+25
  local seenChange=false
  while live() and os.clock()<untilAt do
   task.wait(.08)
   local report,err=observe()
   if not report then return nil,err end
   if report.status=="CLIENT_LOCAL_OFFER_REVISION_CHANGED" then
    if report.theirSlotCount~=expectedCount or
       report.theirCopyCount~=expectedCount then
     return nil,"UNEXPECTED_SLOT_COUNT_OR_STACK_TRANSITION"
    end
    seenChange=true
    if token~=nil then
     local rev=epochs.checkPreview(state,token,os.clock())
     if not rev or rev.status~="CLIENT_PREVIEW_REVOKED" then
      return nil,"PREVIOUS_RESEARCH_PREVIEW_NOT_REVOKED"
     end
     R.revocationsVerified=R.revocationsVerified+1
     token=nil
    end
   elseif seenChange and
       report.status=="CLIENT_OFFER_STABLE_RESEARCH_ONLY" then
    local prepared,preview=epochs.freezePreview(state,os.clock())
    if not prepared or not preview or
       preview.status~="CLIENT_PREVIEW_TOKEN_CREATED_RESEARCH_ONLY"
       or preview.authorizesTrade~=false or
       preview.authorizesAccept~=false then
     return nil,"RESEARCH_PREVIEW_NOT_STABLE"
    end
    token=prepared
    R.stableResearchPreviews=R.stableResearchPreviews+1
    return true
   end
  end
  return nil,"MANUAL_ALT_OFFER_PHASE_TIMEOUT"
 end
 local function samePrivateSlot(a,b)
  if type(a)~="table" or type(b)~="table" then return false end
  for i=1,5 do if a[i]~=b[i] then return false end end
  return true
 end
 local function copyPrivateSlot(a)
  return {a[1],a[2],a[3],a[4],a[5]}
 end
 local ok1,why1=phase(1,"ADD_FIRST")
 if not ok1 then return finish("INCONCLUSIVE",why1) end
 R.observedFirstAdd=true
 local firstItem=copyPrivateSlot(state.their[1])
 local ok2,why3=phase(2,"ADD_SECOND_DIFFERENT")
 if not ok2 then return finish("INCONCLUSIVE",why3) end
 -- Two slots alone are insufficient: forbid silent substitution or a
 -- duplicate visible type. Compare private client strings WITHOUT logging.
 local firstStill=false
 local otherItem=nil
 for _,item in ipairs(state.their or {}) do
  if samePrivateSlot(item,firstItem) then
   firstStill=true
  else
   otherItem=copyPrivateSlot(item)
  end
 end
 if not firstStill or not otherItem or
    (otherItem[2]==firstItem[2] and otherItem[3]==firstItem[3]) then
  return finish("INCONCLUSIVE","SECOND_ITEM_NOT_DISTINCT_OR_FIRST_REPLACED")
 end
 R.observedSecondAdd=true
 local ok3,why4=phase(1,"REMOVE_ONE")
 if not ok3 then return finish("INCONCLUSIVE",why4) end
 if not samePrivateSlot(state.their[1],firstItem) and
    not samePrivateSlot(state.their[1],otherItem) then
  return finish("INCONCLUSIVE","REMAINING_ITEM_NOT_FROM_PRIOR_TWO")
 end
 R.observedOneRemoval=true
 if R.revocationsVerified~=2 or
    R.localOfferEpoch<4 or R.theirMaxSlotCount~=2 then
  return finish("INCONCLUSIVE","REVISIONS_OR_REVOCATIONS_NOT_COMPLETELY_OBSERVED")
 end
 return finish("CLIENT_MULTI_SLOT_ADD_REMOVE_EPOCH_OBSERVED",
    "CLIENT_VISUAL_REVISIONS_NOT_SERVER_CAUSALITY")
end
task.spawn(function()
 local ok,err=xpcall(run,function(e)return tostring(e)end)
 if not ok then
  finish("INCONCLUSIVE","READONLY_RUNTIME_OR_GUI_FAILURE")
  warn("[STAGE99] read-only GUI epoch witness stopped safely")
 end
end)
return I
