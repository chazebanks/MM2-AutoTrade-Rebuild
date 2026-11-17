-- Gingerscope System2: ONE human-supervised five-scenario session.
-- Exactly one original P3 manual ARM to a consenting ALT. ALL trade-window
-- weapon changes must be MANUAL on the two accounts. No GUI click automation,
-- game remote, chat, final Accept, item mutation or learning is implemented.
-- Does not make an unverified price quote authoritative.
local M={}
local SCHEMA="gingerscope-supreme-only-five-scenario-manual-test-v1"
local SOURCE="SUPREME_ONLY"
local STATUS="SUPREME_ONLY_CURRENT_OFFER_CLIENT_PREVIEW"
local INCOMPLETE="BOTH_PHYSICAL_OFFERS_MUST_BE_NONEMPTY"
local labels={
 "Original protected P3/P4 lease",
 "Both offers empty",
 "Exactly one offer populated",
 "Two-sided Supreme listed values",
 "Manual change then safe fresh re-preview",
}
local directions={
 "Keep BOTH offers empty. Tap SUPREME PREVIEW.",
 "Manually add ONE cheap weapon on ONE side; tap PREVIEW.",
 "Manually add a cheap weapon on the OTHER side; tap PREVIEW.",
 "Manually change an offered weapon/quantity; tap PREVIEW.",
 "5/5 completed. Manually close trade, then STOP / COPY. Never Accept.",
}
local function receipt(state,kind,reason,display)
 local results={}
 for i=1,5 do
  results[i]={step=i,status=state.passed[i] and "PASS" or "NOT_PASSED",
    code=state.passed[i] and ("S"..i.."_PASS") or "NOT_TESTED"}
 end
 local finished=state.completed==5
 return {
  schema=SCHEMA,status=kind,reason=reason,
  valueSource=SOURCE,completedCount=state.completed,done=finished,
  nextStep=finished and 0 or state.completed+1,results=results,
  display=display or "",
  readOnly=true,clientOnly=true,researchOnly=true,
  actualRobloxItemInstancesProven=false,
  serverTradeSettlementProven=false,
  authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
  mayReportProfit=false,maySendDiscordWebhook=false,
  mayUseForStrategyLearning=false,
 }
end
local function bad(state,why,display)
 state.blockedCount+=1
 return receipt(state,"SCENARIO_BLOCKED",why,
    display or ("S"..tostring(math.min(state.completed+1,5))..
    "/5 BLOCKED. Fix and tap Preview; never Accept."))
end
local function viable(frame)
 return type(frame)=="table" and frame.clientOnly==true and
  frame.contextOK==true and frame.tradeOpen==true and
  frame.rootBound==true and frame.doubleReadStable==true and
  type(frame.clientRawCaptureSignature)=="string" and
  type(frame.jobId)=="string" and type(frame.tradeLeaseId)=="string" and
  frame.partnerUserId~=nil and frame.ourAccepted==false and
  frame.theirAccepted==false and
  type(frame.ourSlots)=="table" and type(frame.theirSlots)=="table" and
  #frame.ourSlots<=4 and #frame.theirSlots<=4
end
local function equalSlots(x,y)
 if #x~=#y then return false end
 for i,a in ipairs(x) do
  local b=y[i]
  if type(a)~="table" or type(b)~="table" or
   a.slot~=b.slot or a.rawId~=b.rawId or
   a.rawIdObserved~=b.rawIdObserved or a.label~=b.label or
   a.amountText~=b.amountText or a.chromaTag~=b.chromaTag then
   return false
  end
 end
 return true
end
local function unchanged(a,b)
 return viable(a) and viable(b) and
  a.jobId==b.jobId and a.tradeLeaseId==b.tradeLeaseId and
  a.partnerUserId==b.partnerUserId and
  a.clientRawCaptureSignature==b.clientRawCaptureSignature and
  equalSlots(a.ourSlots,b.ourSlots) and
  equalSlots(a.theirSlots,b.theirSlots)
end
local function safeQuote(output)
 return type(output)=="table" and
  output.schema=="gingerscope-supreme-only-intrade-button-research-v1" and
  output.status==STATUS and
  output.valueSource==SOURCE and
  output.sourceStatus=="SUPREME_ONLY_PAPER_RESEARCH_NOT_EXECUTABLE" and
  output.readOnly==true and output.clientOnly==true and
  output.researchOnly==true and
  output.authorizesTrade==false and
  output.authorizesOffer==false and output.authorizesAccept==false and
  output.mayReportProfit==false and output.mayUseForStrategyLearning==false and
  output.maySendDiscordWebhook==false and
  type(output.listedDelta)=="number" and
  output.listedDelta==output.listedDelta and
  output.listedDelta~=-math.huge and output.listedDelta~=math.huge
end
local function safeBlock(output,reason)
 return type(output)=="table" and
  output.schema=="gingerscope-supreme-only-intrade-button-research-v1" and
  output.status=="BLOCKED" and output.reason==reason and
  output.valueSource==SOURCE and output.readOnly==true and
  output.clientOnly==true and output.researchOnly==true and
  output.authorizesOffer==false and output.authorizesAccept==false and
  output.authorizesTrade==false and
  output.mayReportProfit==false and output.mayUseForStrategyLearning==false
end
local function slotSignature(frame)
 -- Private, never serialized: distinguishes manual modification from re-click.
 local parts={}
 for _,side in ipairs({"ourSlots","theirSlots"}) do
  local arr={}
  for _,s in ipairs(frame[side]) do
   arr[#arr+1]=table.concat({
    tostring(s.slot),tostring(s.rawId),tostring(s.label),
    tostring(s.amountText),tostring(s.chromaTag),
    tostring(s.rawIdObserved)
   },":")
  end
  table.sort(arr)
  parts[#parts+1]=side.."="..table.concat(arr,",")
 end
 return table.concat(parts,"|")
end
function M.new()
 local state={completed=0,passed={},previousOfferSignature=nil,
              blockedCount=0}
 local obj={}
 local function mark(step,display)
  if step~=state.completed+1 then
   return bad(state,"SCENARIO_ORDER_INVALID") end
  state.completed=step
  state.passed[step]=true
  return receipt(state,"SCENARIO_PASS","S"..step.."_PASS",display)
 end
 function obj.record(before,after,output,leaseBound)
  if state.completed==5 then
   return receipt(state,"ALL_FIVE_SCENARIOS_PASSED","COMPLETE",
    "5/5 PASS. Close trade manually; STOP / COPY. Never final Accept.")
  end
  if leaseBound~=true or not viable(before) or not viable(after) then
   return bad(state,"ORIGINAL_PROTECTED_P3_P4_FRAME_OR_LEASE_UNVERIFIED")
  end
  if not unchanged(before,after) then
   return bad(state,"OFFER_OR_SESSION_CHANGED_DURING_SCENARIO",
     "SUPREME: Offer changed. Wait for stable GUI; tap again.")
  end
  if state.completed==0 then
   local startup=mark(1,"1/5 PASS: Protected trade observed. Next: both empty.")
   if startup.status~="SCENARIO_PASS" then return startup end
   -- Stage 1 and Stage 2 may pass on the first empty-offer Preview tap.
  end
  local nextStep=state.completed+1
  local ours,theirs=#before.ourSlots,#before.theirSlots
  if nextStep==2 then
   if ours==0 and theirs==0 and safeBlock(output,INCOMPLETE) then
    return mark(2,"2/5 PASS: Both empty blocked. Now offer ONE side manually.")
   end
   return bad(state,"STAGE2_REQUIRES_BOTH_EMPTY",
     "2/5: Remove both offers; tap Preview. No final Accept.")
  elseif nextStep==3 then
   if ((ours>0 and theirs==0) or (theirs>0 and ours==0)) and
       safeBlock(output,INCOMPLETE) then
    return mark(3,"3/5 PASS: One-sided blocked. Add other side manually.")
   end
   return bad(state,"STAGE3_REQUIRES_EXACTLY_ONE_OFFER_SIDE",
     "3/5: Manually offer only ONE side, then Preview.")
  elseif nextStep==4 then
   if ours>0 and theirs>0 and safeQuote(output) then
    state.previousOfferSignature=slotSignature(before)
    return mark(4,"4/5 PASS: Supreme prices checked. Manually change one item.")
   end
   return bad(state,"STAGE4_TWO_SIDED_VERIFIED_SUPREME_QUOTE_REQUIRED",
    type(output)=="table" and output.reason==
      "GUI_RAW_WEAPON_ID_OR_SLOT_NOT_PROVEN" and
      "4/5 BLOCKED: MM2 raw weapon ID missing; do not guess." or
      "4/5: Both offers + verified Supreme quote required.")
  elseif nextStep==5 then
   if ours<1 or theirs<1 then
    return bad(state,"STAGE5_REQUIRES_TWO_NONEMPTY_SIDES",
      "5/5: Change a weapon or stack, keeping both sides populated.")
   end
   local signature=slotSignature(before)
   if signature==state.previousOfferSignature then
    return bad(state,"STAGE5_OFFER_NOT_CHANGED",
      "5/5: Change weapon or quantity manually before Preview.")
   end
   if not safeQuote(output) then
    return bad(state,"STAGE5_FRESH_VERIFIED_QUOTE_REQUIRED",
      "5/5: Changed; but no safe new Supreme quote. Fix and retry.")
   end
   state.previousOfferSignature=nil
   return mark(5,"5/5 PASS: Change detected; fresh Supreme quote validated. STOP.")
  end
  return bad(state,"SCENARIO_STATE_UNEXPECTED")
 end
 function obj.progress()
  local n=state.completed
  return receipt(state,"SCENARIO_PROGRESS","IN_PROGRESS",
    n==5 and "5/5 PASS. Close trade manually; STOP / COPY." or
    ("Stage "..tostring(n+1).."/5: "..directions[n+1]))
 end
 function obj.summary()
  local r=obj.progress()
  r.blockedAttempts=state.blockedCount
  -- Do not export the previous raw slot signature.
  return r
 end
 return obj
end
return M
