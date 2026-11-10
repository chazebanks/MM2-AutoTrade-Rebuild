-- Stage98: local offer-revision invalidation over unchanged Stage9 physical GUI
-- observations. Research-only; a client revision is NOT a server trade nonce.
-- No GUI access, game remotes, pricing, ownership, item placement, or Accept.
local M={}
local function response(status,reason,s)
 return {
  schema="gingerscope-stage98-client-offer-epoch-v1",
  status=status,reason=reason,readOnly=true,clientOnly=true,
  localObservationRevision=s and s.epoch or 0,
  ourSlotCount=s and s.countO or 0,
  theirSlotCount=s and s.countT or 0,
  ourCopyCount=s and s.copiesO or 0,
  theirCopyCount=s and s.copiesT or 0,
  nameOnlyGuiSlotCount=s and s.nameOnly or 0,
  stableGuiReads=s and s.stable or 0,
  pendingClientCallback=s and s.pending or false,
  serverTradeRevisionProven=false,
  eventSessionAssociationProven=false,callbackCausalityProven=false,
  rawOfferKeyBoundToPreprofile=false,rawItemIdConfirmed=false,
  uniqueWeaponInstanceProven=false,currentPricesVerified=false,
  priceForTradeVerified=false,authenticatedOwnedInventory=false,
  numericSupremeCheckerIdVerified=false,serverAttestation=false,
  serverCompletionProven=false,authorizesTrade=false,
  authorizesAccept=false,mayRecordCompletedTrade=false,
  mayReportProfit=false,maySendDiscordWebhook=false,
  mayUseForStrategyLearning=false,tradeOutcome="UNKNOWN",
 }
end
local function finite(n)
 return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end
local function integer(n,lo,hi)
 return finite(n) and n==math.floor(n) and n>=lo and n<=hi
end
local function text(s)
 return type(s)=="string" and #s>=1 and #s<=180
  and not s:find("[%c]")
end
local function name(s)
 if not text(s) then return nil end
 return s:gsub("^%s+",""):gsub("%s+$",""):gsub("%s+"," "):lower()
end
local function dense(t,maximum)
 if type(t)~="table" or getmetatable(t)~=nil then return false end
 local n=#t
 if n>maximum then return false end
 local seen=0
 for k in pairs(t) do
  if not integer(k,1,n) then return false end
  seen=seen+1
 end
 return seen==n
end
local function side(raw,parseQuantity)
 if type(raw)~="table" or raw.complete~=true or
    raw.accepted~=false or not dense(raw.slots,4) then
  return nil,"SIDE_OR_ACCEPT_STATE_UNVERIFIED"
 end
 local out,used={},{}
 local copies,names=0,0
 for _,v in ipairs(raw.slots) do
  if type(v)~="table" or getmetatable(v)~=nil or
    not integer(v.slot,1,4) or used[v.slot] or
    type(v.chroma)~="boolean" or not name(v.label) then
   return nil,"PHYSICAL_SLOT_SHAPE_OR_VARIANT_INVALID"
  end
  local qty=parseQuantity(v.amountText)
  if not integer(qty,1,20) then
   return nil,"PHYSICAL_STACK_QUANTITY_UNVERIFIED"
  end
  local rawId=v.rawId
  if rawId~=nil and (type(rawId)~="string" or
     #rawId>128 or rawId:find("[%c]")) then
   return nil,"PHYSICAL_RAW_TEXT_INVALID"
  end
  local canonical=name(v.label)
  if canonical=="" then return nil,"PHYSICAL_NAME_EMPTY" end
  used[v.slot]=true
  copies=copies+qty
  if rawId==nil or rawId=="" then names=names+1 end
  -- These private strings remain internal, never sent in a report/token.
  out[#out+1]={v.slot,canonical,v.chroma,qty,rawId or ""}
 end
 if copies>4 then return nil,"FOUR_COPY_CONSERVATIVE_LIMIT_EXCEEDED" end
 table.sort(out,function(a,b)return a[1]<b[1]end)
 return {rows=out,copies=copies,nameOnly=names}
end
local function equalRows(a,b)
 if #a~=#b then return false end
 for i=1,#a do
  for j=1,5 do if a[i][j]~=b[i][j] then return false end end
 end
 return true
end
local function sameScope(v,c)
 return type(v)=="table" and type(v.raw)=="table" and
   v.session==c.session and v.jobId==c.jobId and
   rawequal(v.root,c.root) and
   rawequal(v.localPlayer,c.localPlayer) and
   rawequal(v.partnerPlayer,c.partnerPlayer)
end
local function halt(s,reason)
 s.dead=true
 s.epoch=s.epoch+1
 s.pending=false
 s.stable=0
 return response("INCONCLUSIVE",reason,s)
end
function M.new(scope,stage9)
 if type(scope)~="table" or type(stage9)~="table" or
    type(stage9.parseQuantity)~="function" or
    not text(scope.session) or not text(scope.jobId) or
    scope.root==nil or scope.localPlayer==nil or
    scope.partnerPlayer==nil or
    rawequal(scope.localPlayer,scope.partnerPlayer) then
  return nil
 end
 return {scope=scope,parse=stage9.parseQuantity,
  epoch=0,stable=0,dead=false,pending=false,first=true,
  lastAt=nil,changedAt=nil,our=nil,their=nil,ourSnapshot=nil,
  countO=0,countT=0,copiesO=0,copiesT=0,nameOnly=0}
end
function M.observe(s,v)
 if type(s)~="table" or s.dead then
  return response("INCONCLUSIVE","STATE_ALREADY_CLOSED",s)
 end
 if not sameScope(v,s.scope) or not finite(v.at) or v.at<0 or
    (s.lastAt~=nil and v.at<=s.lastAt) then
  return halt(s,"CLIENT_SCOPE_OR_MONOTONIC_CLOCK_CHANGED")
 end
 local raw=v.raw
 if raw.tradeOpen~=true or raw.contextOK~=true or
    raw.session~=s.scope.session then
  return halt(s,"CLIENT_GUI_SESSION_NOT_EXACT")
 end
 local ours,err=side(raw.our,s.parse)
 if not ours then return halt(s,err) end
 local theirs,why=side(raw.their,s.parse)
 if not theirs then return halt(s,why) end
 if s.first and (#ours.rows~=0 or #theirs.rows~=0) then
  return halt(s,"INITIAL_CLIENT_GUI_NOT_BOTH_EMPTY")
 end
 s.lastAt=v.at
 local different=s.first or not equalRows(s.our,ours.rows)
    or not equalRows(s.their,theirs.rows)
 if different then
  s.epoch=s.epoch+1
  s.changedAt=v.at
  s.stable=1
  s.our=ours.rows;s.their=theirs.rows
  s.countO=#ours.rows;s.countT=#theirs.rows
  s.copiesO=ours.copies;s.copiesT=theirs.copies
  s.nameOnly=ours.nameOnly+theirs.nameOnly
  s.first=false
  s.pending=false  -- GUI change clears pending, NOT event causality.
  return response("CLIENT_LOCAL_OFFER_REVISION_CHANGED",
                  "REVISION_IS_LOCAL_OBSERVATION_ONLY",s)
 end
 s.stable=s.stable+1
 if s.pending then
  if v.at-s.callbackAt>3 then
   return halt(s,"CLIENT_CALLBACK_WITHOUT_GUI_REVISION")
  end
  return response("CLIENT_EVENT_WITHOUT_GUI_CHANGE_PENDING",
       "NO_CALLBACK_CAUSALITY_ASSUMED",s)
 end
 if s.stable>=2 and v.at-s.changedAt>=.15 then
  return response("CLIENT_OFFER_STABLE_RESEARCH_ONLY",
     "LOCAL_GUI_STABLE_NOT_PRICE_OR_SERVER_AUTHORITY",s)
 end
 return response("CLIENT_GUI_STILL_SETTLING","SECOND_STABLE_READ_REQUIRED",s)
end
function M.noteClientCallback(s,e)
 if type(s)~="table" or s.dead then
  return response("INCONCLUSIVE","STATE_ALREADY_CLOSED",s)
 end
 if s.first or s.pending or not sameScope(e,s.scope) or
    not finite(e.at) or e.at<=s.lastAt or e.at-s.lastAt>3 then
  return halt(s,"CLIENT_CALLBACK_OUTSIDE_SINGLE_OBSERVATION_WINDOW")
 end
 s.epoch=s.epoch+1
 s.pending=true
 s.callbackAt=e.at
 s.stable=0
 return response("CLIENT_CALLBACK_INVALIDATED_PRIOR_PREVIEW",
    "NO_SERVER_TRANSACTION_OR_REVISION_PROOF",s)
end
local MARKER={}
function M.freezePreview(s)
 if type(s)~="table" or s.dead or s.first or s.pending or
    s.stable<2 or s.lastAt==nil or s.changedAt==nil or
    s.lastAt-s.changedAt<.15 or
    s.countO+s.countT==0 then
  return nil,response("CLIENT_PREVIEW_NOT_READY",
    "UNVERIFIED_OR_UNSTABLE_LOCAL_OFFER",s)
 end
 return {marker=MARKER,owner=s,epoch=s.epoch},response(
   "CLIENT_PREVIEW_TOKEN_CREATED_RESEARCH_ONLY",
   "LOCAL_REVISION_TOKEN_NEVER_AUTHORIZES_TRADE",s)
end
function M.checkPreview(s,token)
 if type(s)~="table" or s.dead or type(token)~="table"
    or token.marker~=MARKER or not rawequal(token.owner,s)
    or token.epoch~=s.epoch or s.pending or s.stable<2 then
  return response("CLIENT_PREVIEW_REVOKED",
    "LOCAL_REVISION_OR_SESSION_CHANGED",s)
 end
 return response("CLIENT_PREVIEW_STILL_CURRENT_RESEARCH_ONLY",
   "NOT_A_TRADE_OR_ACCEPT_PERMISSION",s)
end
return M
