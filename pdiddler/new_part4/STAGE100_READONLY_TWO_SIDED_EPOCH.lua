-- Stage100: READ-ONLY original Stage9 Part4 GUI -> Stage98 two-sided offer epoch.
-- ALT manually adds one item, MAIN manually adds one, ALT removes theirs.
-- No request, offer, Accept, Decline, hop, event listener, market or webhook.
-- Local visual revisions are NOT server-assigned revisions or item-ID proofs.
local E=(type(getgenv)=="function" and getgenv()) or _G
local KEY="GINGERSCOPE_STAGE100_TWO_SIDED_OFFER_EPOCH_READONLY"
local SCHEMA="gingerscope-stage100-native-two-sided-offer-epoch-research-v1"
local targetName=E.PDIDDLER_STAGE100_TARGET_USERNAME
if E.PDIDDLER_STAGE100_READONLY_ARMED~=true
   or type(targetName)~="string" or #targetName<3 or #targetName>20
   or not targetName:match("^[A-Za-z0-9_]+$") then
 warn("[STAGE100] explicitly arm READONLY and set exact consenting ALT username")
 return nil
end
if game.PlaceId~=142823291 then
 warn("[STAGE100] original MM2 place only")
 return nil
end
if E[KEY]~=nil then
 warn("[STAGE100] one-shot already used: fresh server required")
 return E[KEY]
end
for _,k in ipairs({
 "GINGERSCOPE_STAGE88_CONTACT_READONLY_PREVIEW",
 "GINGERSCOPE_STAGE89_SINGLE_REQUEST_DIAGNOSTIC",
 "GINGERSCOPE_STAGE90_CARD_LAYOUT_AUDIT",
 "GINGERSCOPE_STAGE91_SINGLE_REQUEST_DIAGNOSTIC",
 "GINGERSCOPE_STAGE92_SINGLE_REQUEST_DIAGNOSTIC",
 "GINGERSCOPE_STAGE93_SINGLE_REQUEST_DIAGNOSTIC",
 "GINGERSCOPE_STAGE97_PARTNER_EVENT_READONLY",
 "PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW",
 "PDIDDLER_OUTGOING_CONTROLLER","PDIDDLER_OUTGOING_SESSION",
 "PDIDDLER_OUTGOING_BUSY_SESSION","PDIDDLER_PART4_SESSION",
 "PDIDDLER_PART4_CONTROLLER","PDIDDLER_HOPPING_SESSION",
 "PDIDDLER_PART5_CONTROLLER","PDIDDLER_STATUS_OWNER"
}) do
 if E[k]~=nil then
  warn("[STAGE100] existing transaction/probe owner, use fresh MM2 server")
  return nil
 end
end
local R={
 schema=SCHEMA,status="STARTING",reason="INITIALIZING",
 readOnly=true,clientOnly=true,oneShot=true,
 onScreenGuideShown=false,onScreenGuideUpdates=0,
 onScreenGuideFinalShown=false,onScreenGuideCurrentStep="NOT_READY",
 targetClientBound=false,exactPartnerGuiObserved=false,
 tradeWindowWaitPolls=0,stage9ObserverBound=false,stage9Frames=0,
 observedAltAdd=false,observedMainAdd=false,
 observedAltRemoval=false,revocationsVerified=0,
 finalOwnSlotCount=0,finalPartnerSlotCount=0,
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
-- In-game prompts are mandatory for any user-facing manual Stage100 action.
-- Small draggable panel; GUI-only display, no trading input or game remotes.
local guide=nil
local function createGuide()
 if not PG or PG.Parent~=LP then return false end
 local screen=nil
 local ok,created=pcall(function()
  screen=Instance.new("ScreenGui")
  screen.Name="PDIDDLER_STAGE100_ONSCREEN_GUIDE"
  screen.ResetOnSpawn=false
  screen.IgnoreGuiInset=false
  screen.DisplayOrder=1200
  local frame=Instance.new("Frame")
  frame.Name="GuidePanel"
  frame.Size=UDim2.new(0,292,0,154)
  frame.Position=UDim2.new(1,-304,0,85)
  frame.BackgroundColor3=Color3.fromRGB(29,23,42)
  frame.BorderSizePixel=0
  frame.Active=true
  frame.Draggable=true -- Touch/mouse reposition, no game GUI interaction.
  frame.Parent=screen
  local corner=Instance.new("UICorner")
  corner.CornerRadius=UDim.new(0,9)
  corner.Parent=frame
  local border=Instance.new("UIStroke")
  border.Color=Color3.fromRGB(130,92,191)
  border.Thickness=2
  border.Parent=frame
  local title=Instance.new("TextLabel")
  title.Name="GuideTitle"
  title.Position=UDim2.new(0,10,0,6)
  title.Size=UDim2.new(1,-52,0,23)
  title.BackgroundTransparency=1
  title.Font=Enum.Font.GothamBold
  title.TextSize=15
  title.TextColor3=Color3.fromRGB(232,209,255)
  title.TextXAlignment=Enum.TextXAlignment.Left
  title.Text="PDIDDLER / STAGE 100"
  title.Parent=frame
  local step=Instance.new("TextLabel")
  step.Name="GuideStep"
  step.Position=UDim2.new(0,11,0,33)
  step.Size=UDim2.new(1,-22,0,23)
  step.BackgroundTransparency=1
  step.Font=Enum.Font.GothamBold
  step.TextSize=15
  step.TextColor3=Color3.fromRGB(255,255,255)
  step.TextXAlignment=Enum.TextXAlignment.Left
  step.Text="STARTING"
  step.Parent=frame
  local instruction=Instance.new("TextLabel")
  instruction.Name="GuideInstruction"
  instruction.Position=UDim2.new(0,11,0,60)
  instruction.Size=UDim2.new(1,-22,0,65)
  instruction.BackgroundTransparency=1
  instruction.Font=Enum.Font.Gotham
  instruction.TextSize=14
  instruction.TextColor3=Color3.fromRGB(239,234,248)
  instruction.TextXAlignment=Enum.TextXAlignment.Left
  instruction.TextYAlignment=Enum.TextYAlignment.Top
  instruction.TextWrapped=true
  instruction.Text="Preparing read-only test..."
  instruction.Parent=frame
  local warning=Instance.new("TextLabel")
  warning.Name="GuideWarning"
  warning.Position=UDim2.new(0,11,1,-25)
  warning.Size=UDim2.new(1,-22,0,19)
  warning.BackgroundTransparency=1
  warning.Font=Enum.Font.GothamBold
  warning.TextSize=11
  warning.TextColor3=Color3.fromRGB(255,176,176)
  warning.TextXAlignment=Enum.TextXAlignment.Left
  warning.Text="MANUAL ONLY  |  NEVER FINAL ACCEPT"
  warning.Parent=frame
  local close=Instance.new("TextButton")
  close.Name="DismissWhenFinished"
  close.Position=UDim2.new(1,-34,0,5)
  close.Size=UDim2.new(0,27,0,24)
  close.BackgroundColor3=Color3.fromRGB(73,54,98)
  close.BorderSizePixel=0
  close.Text="X"
  close.Font=Enum.Font.GothamBold
  close.TextSize=13
  close.TextColor3=Color3.fromRGB(255,255,255)
  close.Visible=false
  close.Parent=frame
  close.MouseButton1Click:Connect(function()
   pcall(function() screen:Destroy() end)
  end)
  screen.Parent=PG
  return {root=screen,step=step,instruction=instruction,close=close}
 end)
 if not ok or type(created)~="table" then
  if screen then pcall(function() screen:Destroy() end) end
  return false
 end
 guide=created
 R.onScreenGuideShown=true
 return true
end
local function showGuide(step,message)
 if not guide or guide.root.Parent~=PG then return false end
 local ok=pcall(function()
  guide.step.Text=step
  guide.instruction.Text=message
 end)
 if ok then
  R.onScreenGuideUpdates=R.onScreenGuideUpdates+1
  R.onScreenGuideCurrentStep=step
 end
 return ok
end
local function result()
 R.elapsedSeconds=math.floor(math.max(0,os.clock()-started))
 local ok,json=pcall(function()
  return game:GetService("HttpService"):JSONEncode(R)
 end)
 if ok and type(json)=="string" and #json<2500 then
  local line="[GINGERSCOPE STAGE100 TWO SIDED EPOCH] "..json
  print(line)
  if type(setclipboard)=="function" then pcall(setclipboard,line) end
 else
  warn("[STAGE100] sanitized JSON report unavailable")
 end
end
local function finish(status,reason)
 if not I.running then return I end
 I.running=false
 R.status=status;R.reason=reason
 if guide and guide.root.Parent==PG then
  local isPass=status=="CLIENT_TWO_SIDED_OFFER_WITHDRAWAL_EPOCH_OBSERVED"
  local label=isPass and "COMPLETE - CLIENT GUI ONLY" or "STOPPED - INCONCLUSIVE"
  local detail=isPass and
   "All three manual changes observed. No trade occurred. Copy the sanitized Stage100 report from Delta." or
   ("Stopped safely: "..tostring(reason)..". No final Accept. Copy the Stage100 report from Delta.")
  if showGuide(label,detail) then
   R.onScreenGuideFinalShown=true
   pcall(function()guide.close.Visible=true end)
  end
 end
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
 if not createGuide() then
  return finish("INCONCLUSIVE","IN_GAME_PROMPT_PANEL_UNAVAILABLE")
 end
 if not showGuide("STEP 1/4: OPEN TRADE",
   "MAIN: manually open an EMPTY trade with ALT within 30 seconds. Do not put items in yet.") then
  return finish("INCONCLUSIVE","ONSCREEN_PROMPT_UPDATE_FAILED")
 end
 print("[STAGE100] WAIT_FOR_MANUAL_TRADE_WINDOW: open an EMPTY trade with the ALT within 30 seconds. Never final Accept.")
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
 local session="stage100:"..tostring(started)
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
  -- Two-sided manual trade is intended; never infer item identity/ownership.
  if (report.ourSlotCount or 0)>1 or (report.ourCopyCount or 0)>1 then
   return nil,"MORE_THAN_ONE_OWN_SIDE_TEST_ITEM"
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
 local function phase(expectedOur,expectedTheir,name)
  local steps={
   ALT_ADD_ONE={"STEP 2/4: ALT ADD","On ALT: add ONE expendable weapon to their offer. MAIN stays EMPTY. Wait for the next prompt."},
   MAIN_ADD_ONE={"STEP 3/4: MAIN ADD","On MAIN: add ONE expendable weapon to your offer. Leave ALT's item unchanged. Wait for next prompt."},
   ALT_REMOVE_ONE={"STEP 4/4: ALT REMOVE","On ALT: REMOVE their offered weapon. Leave MAIN's weapon untouched. NEVER final Accept."}
  }
  local prompt=steps[name]
  if not prompt or not showGuide(prompt[1],prompt[2]) then
   return nil,"ONSCREEN_PROMPT_UPDATE_FAILED"
  end
  print("[STAGE100] READY_"..name..": manually change only the requested side to "
    ..tostring(expectedOur).." MAIN slot(s) and "..tostring(expectedTheir)
    .." ALT slot(s). Leave both unaccepted. DO NOT final Accept.")
  local untilAt=os.clock()+30
  local sawChange=false
  while live() and os.clock()<untilAt do
   task.wait(.08)
   local report,err=observe()
   if not report then return nil,err end
   if report.status=="CLIENT_LOCAL_OFFER_REVISION_CHANGED" then
    if sawChange then return nil,"MULTIPLE_VISUAL_REVISIONS_IN_ONE_PHASE" end
    if report.ourSlotCount~=expectedOur or
       report.theirSlotCount~=expectedTheir or
       report.ourCopyCount~=expectedOur or
       report.theirCopyCount~=expectedTheir then
     return nil,"UNEXPECTED_TWO_SIDED_SLOT_COUNT_OR_STACK"
    end
    sawChange=true
    if token~=nil then
     local revoked=epochs.checkPreview(state,token,os.clock())
     if not revoked or revoked.status~="CLIENT_PREVIEW_REVOKED" then
      return nil,"PREVIOUS_TWO_SIDED_RESEARCH_PREVIEW_NOT_REVOKED"
     end
     R.revocationsVerified=R.revocationsVerified+1
     token=nil
    end
   elseif sawChange and
      report.status=="CLIENT_OFFER_STABLE_RESEARCH_ONLY" then
    local newToken,preview=epochs.freezePreview(state,os.clock())
    if not newToken or not preview
       or preview.status~="CLIENT_PREVIEW_TOKEN_CREATED_RESEARCH_ONLY"
       or preview.authorizesTrade~=false or
       preview.authorizesAccept~=false or
       preview.serverTradeRevisionProven~=false then
     return nil,"TWO_SIDED_RESEARCH_PREVIEW_UNSTABLE"
    end
    token=newToken
    R.stableResearchPreviews=R.stableResearchPreviews+1
    return true
   end
  end
  return nil,"TWO_SIDED_MANUAL_PHASE_TIMEOUT"
 end
 local function samePrivateItem(a,b)
  if type(a)~="table" or type(b)~="table" then return false end
  -- Slot may visually renumber, but label, Chroma, amount and optional GUI
  -- raw text must remain identical; still NOT unique authenticated item ID.
  for i=2,5 do if a[i]~=b[i] then return false end end
  return true
 end
 local function privateCopy(a)
  if type(a)~="table" then return nil end
  return {a[1],a[2],a[3],a[4],a[5]}
 end

 local a,whyA=phase(0,1,"ALT_ADD_ONE")
 if not a then return finish("INCONCLUSIVE",whyA) end
 R.observedAltAdd=true
 local originalAlt=privateCopy(state.their[1])

 local b,whyB=phase(1,1,"MAIN_ADD_ONE")
 if not b then return finish("INCONCLUSIVE",whyB) end
 if not samePrivateItem(state.their[1],originalAlt) then
  return finish("INCONCLUSIVE","ALT_ITEM_CHANGED_DURING_MAIN_ADD")
 end
 R.observedMainAdd=true
 local originalOwn=privateCopy(state.our[1])

 local c,whyC=phase(1,0,"ALT_REMOVE_ONE")
 if not c then return finish("INCONCLUSIVE",whyC) end
 if not samePrivateItem(state.our[1],originalOwn) then
  return finish("INCONCLUSIVE","MAIN_ITEM_CHANGED_DURING_ALT_REMOVAL")
 end
 R.observedAltRemoval=true
 R.finalOwnSlotCount=#state.our
 R.finalPartnerSlotCount=#state.their
 if R.localOfferEpoch~=4 or R.revocationsVerified~=2 or
    R.stableResearchPreviews~=3 or
    R.ourMaxSlotCount~=1 or R.theirMaxSlotCount~=1 or
    R.finalOwnSlotCount~=1 or R.finalPartnerSlotCount~=0 then
  return finish("INCONCLUSIVE","TWO_SIDED_REVISION_EVIDENCE_INCOMPLETE")
 end
 return finish("CLIENT_TWO_SIDED_OFFER_WITHDRAWAL_EPOCH_OBSERVED",
  "CLIENT_GUI_CONSISTENCY_ONLY_NO_PRICE_OR_SERVER_AUTHORITY")
end
task.spawn(function()
 local ok,err=xpcall(run,function(e)return tostring(e)end)
 if not ok then
  finish("INCONCLUSIVE","READONLY_RUNTIME_OR_GUI_FAILURE")
  warn("[STAGE100] read-only GUI epoch witness stopped safely")
 end
end)
return I
