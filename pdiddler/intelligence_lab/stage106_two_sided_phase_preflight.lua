-- Stage106 pure preflight: original Stage9 GUI phases + original Stage101
-- two-sided UpdateTrade candidate matcher. NO Roblox actions or remotes.
-- A client callback remains un-attributed to any authenticated game session.
local M={}
local function finite(x)
 return type(x)=="number" and x==x and x~=math.huge and x~=-math.huge
end
local function text(x)
 return type(x)=="string" and #x>=1 and #x<=180 and not x:find("[%c]")
end
local function refuse(reason)
 return {
  schema="gingerscope-stage106-readonly-phase-preflight-v1",
  status="INCONCLUSIVE",reason=reason or "CLIENT_EVIDENCE_INSUFFICIENT",
  readOnly=true,clientOnly=true,phaseSequenceObserved=false,
  clientTwoSidedCandidatesObserved=false,ourMatchedSlotCount=0,
  theirMatchedSlotCount=0,inputClientEventCount=0,
  eventSessionAssociationProven=false,callbackCausalityProven=false,
  serverTradeRevisionProven=false,rawItemIdConfirmed=false,
  uniqueWeaponInstanceProven=false,ownerSideSlotBound=false,
  currentPricesVerified=false,priceForTradeVerified=false,
  serverCompletionProven=false,authorizesTrade=false,
  authorizesAccept=false,mayReportProfit=false,
  maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
  tradeOutcome="UNKNOWN"
 }
end
local function scopeValid(s)
 return type(s)=="table" and text(s.session) and text(s.jobId) and
   s.root~=nil and s.localPlayer~=nil and s.partnerPlayer~=nil and
   not rawequal(s.localPlayer,s.partnerPlayer)
end
local function dense(slots)
 if type(slots)~="table" or getmetatable(slots)~=nil then return nil end
 local n=#slots
 if n>4 then return nil end
 local count=0
 for k in pairs(slots) do
  if type(k)~="number" or k~=math.floor(k) or k<1 or k>n then
   return nil
  end
  count=count+1
 end
 if count~=n then return nil end
 return n
end
local function rows(side,parse)
 if type(side)~="table" or side.complete~=true or
    side.accepted~=false then return nil end
 local n=dense(side.slots)
 if not n then return nil end
 local out,seen={},{}
 for i=1,n do
  local slot=side.slots[i]
  if type(slot)~="table" or getmetatable(slot)~=nil or
     type(slot.slot)~="number" or slot.slot~=math.floor(slot.slot) or
     slot.slot<1 or slot.slot>4 or seen[slot.slot] or
     type(slot.label)~="string" or #slot.label<1 or
     #slot.label>128 or slot.label:find("[%c]") or
     type(slot.chroma)~="boolean" then return nil end
  local qty=parse(slot.amountText)
  if type(qty)~="number" or qty~=math.floor(qty) or
     qty<1 or qty>1000000 then return nil end
  if slot.rawId~=nil and (type(slot.rawId)~="string" or
     #slot.rawId>128 or slot.rawId:find("[%c]")) then return nil end
  seen[slot.slot]=true
  out[#out+1]={slot.slot,
    slot.label:gsub("^%s+",""):gsub("%s+$",""):lower(),
    slot.chroma,qty,slot.rawId or ""}
 end
 table.sort(out,function(a,b)return a[1]<b[1] end)
 return out
end
local function frame(v,s,parse)
 if type(v)~="table" or not finite(v.at) or v.at<0 or
    v.jobId~=s.jobId or v.session~=s.session or
    not rawequal(v.root,s.root) or
    not rawequal(v.localPlayer,s.localPlayer) or
    not rawequal(v.partnerPlayer,s.partnerPlayer) then return nil end
 local raw=v.raw
 if type(raw)~="table" or raw.tradeOpen~=true or
    raw.contextOK~=true or raw.session~=s.session then return nil end
 local ours=rows(raw.our,parse)
 local theirs=rows(raw.their,parse)
 if not ours or not theirs then return nil end
 return {at=v.at,ours=ours,theirs=theirs}
end
local function same(a,b)
 if #a~=#b then return false end
 for i=1,#a do
  for j=1,5 do if a[i][j]~=b[i][j] then return false end end
 end
 return true
end
function M.inspect(input,catalogue,registry,stage9,stage101)
 local out=refuse()
 if type(input)~="table" or not scopeValid(input.scope) or
    type(stage9)~="table" or type(stage9.parseQuantity)~="function" or
    type(stage101)~="table" or type(stage101.inspect)~="function" then
  out.reason="ORIGINAL_CLIENT_SOURCE_OR_SCOPE_UNAVAILABLE";return out
 end
 local s=input.scope
 local e1=frame(input.empty1,s,stage9.parseQuantity)
 local e2=frame(input.empty2,s,stage9.parseQuantity)
 local a1=frame(input.alt1,s,stage9.parseQuantity)
 local a2=frame(input.alt2,s,stage9.parseQuantity)
 local p1=frame(input.after1,s,stage9.parseQuantity)
 local p2=frame(input.after2,s,stage9.parseQuantity)
 if not e1 or not e2 or not a1 or not a2 or not p1 or not p2 then
  out.reason="CLIENT_FRAME_OR_EXACT_PARTNER_UNVERIFIED";return out
 end
 if not (e1.at<e2.at and e2.at<a1.at and a1.at<a2.at
    and a2.at<p1.at and p1.at<p2.at and
    e2.at-e1.at>=.15 and a2.at-a1.at>=.15 and
    p2.at-p1.at>=.15 and p2.at-p1.at<=1 and
    a2.at-e2.at<=30 and p2.at-a2.at<=35) then
  out.reason="TWO_SIDED_CLIENT_PHASE_CLOCK_INVALID";return out
 end
 if #e1.ours~=0 or #e1.theirs~=0 or
    #e2.ours~=0 or #e2.theirs~=0 then
  out.reason="INITIAL_CLIENT_OFFERS_NOT_EMPTY";return out
 end
 if #a1.ours~=0 or #a2.ours~=0 or
    #a1.theirs~=1 or #a2.theirs~=1 or
    not same(a1.theirs,a2.theirs) then
  out.reason="ALT_ONLY_CLIENT_BASELINE_NOT_STABLE";return out
 end
 if #p1.ours~=1 or #p2.ours~=1 or
    #p1.theirs~=1 or #p2.theirs~=1 or
    not same(p1.ours,p2.ours) or
    not same(p1.theirs,p2.theirs) or
    not same(p2.theirs,a2.theirs) then
  out.reason="MAIN_ONLY_CHANGE_OR_ALT_ITEM_UNVERIFIED";return out
 end
 -- Protected Gingerscope is never an outgoing test item, even manually.
 if p2.ours[1][2]=="gingerscope" then
  out.reason="PROTECTED_GINGERSCOPE_IN_OUR_OFFER";return out
 end
 local at=input.listenerArmedAt
 local receipt=input.receipt
 if not finite(at) or not receipt or not finite(receipt.at) or
    input.eventCount~=1 or at<a2.at or at>=receipt.at or
    receipt.at>p1.at or receipt.at-a2.at>30 then
  out.reason="LISTENER_PHASE_OR_SINGLE_CALLBACK_NOT_VERIFIED";return out
 end
 -- This cannot authenticate delivery causality. The older ALT callback might
 -- arrive late, which the complete two-sided packet matcher must reject.
 local result=stage101.inspect({
   scope=s,eventCount=input.eventCount,
   before=input.alt2,receipt=receipt,
   after1=input.after1,after2=input.after2
 },catalogue,registry,stage9)
 if type(result)~="table" or
    result.status~="CLIENT_MULTISLOT_RAW_KEY_CANDIDATES_MATCH_GUI_UNATTRIBUTED" or
    result.authorizesTrade~=false or result.authorizesAccept~=false or
    result.serverCompletionProven~=false or
    result.eventSessionAssociationProven~=false or
    result.callbackCausalityProven~=false or
    result.ourMatchedSlotCount~=1 or result.theirMatchedSlotCount~=1 then
  out.reason="CLIENT_RAW_KEY_GUI_CANDIDATE_NOT_PROVEN";return out
 end
 out.status="CLIENT_TWO_SIDED_RAW_KEY_GUI_CANDIDATES_UNATTRIBUTED"
 out.reason="CLIENT_ONLY_NO_SIGNED_EVENT_SESSION_OR_TRADE"
 out.phaseSequenceObserved=true
 out.clientTwoSidedCandidatesObserved=true
 out.ourMatchedSlotCount=1
 out.theirMatchedSlotCount=1
 out.inputClientEventCount=1
 return out -- Never return the private Stage101 raw key candidate table.
end
return M
