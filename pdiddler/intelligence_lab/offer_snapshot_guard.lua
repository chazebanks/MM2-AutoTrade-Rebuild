-- Gingerscope offer snapshot guard: PURE, read-only research candidate evaluator.
-- No game, trade remotes, source fetches, clipboard, webhook, Accept, or UI.
-- Even a "RESEARCH_CANDIDATE_ONLY" output NEVER authorizes a real trade.
local M={}
local MAX_SLOTS=4
local MAX_QUANTITY=1000000
local MAX_VALUE=1000000
local MAX_OBSERVATION_AGE=2
local MAX_CATALOG_AGE=48*3600
local SAFE_STABILITY={Stable=true,["Overpaid For"]=true}

local function integer(x,min,max)
 return type(x)=="number" and x==math.floor(x) and x>=min and x<=max
end
local function reject(reason)
 return {
  schema="gingerscope-offer-snapshot-guard-v1",
  status="REJECTED",reason=reason,
  exactItemIdentityAuthenticatedByGuard=false,
  serverCompletionProven=false,mayRecordCompletedTrade=false,
  mayReportProfit=false,mayUseForStrategyLearning=false,
  authorizesTrade=false,authorizesAccept=false,tradeOutcome="UNKNOWN",
 }
end
local function slots(value)
 if type(value)~="table" then return nil end
 local count=#value
 if count<1 or count>MAX_SLOTS then return nil end
 -- A sparse or dictionary-like table is not a valid stable slot snapshot.
 local keys=0
 for k,_ in pairs(value) do
  if not integer(k,1,count) then return nil end
  keys=keys+1
 end
 if keys~=count then return nil end
 local used={}
 local out={}
 for i=1,count do
  local slot=value[i]
  if type(slot)~="table" then return nil end
  local index,key,qty=slot.index,slot.key,slot.quantity
  if not integer(index,1,MAX_SLOTS) or used[index] or
     type(key)~="string" or #key==0 or #key>90 or
     not integer(qty,1,MAX_QUANTITY) then return nil end
  used[index]=true
  out[#out+1]={index,key,qty}
 end
 table.sort(out,function(a,b)return a[1]<b[1]end)
 return out
end
local function equalSlots(a,b)
 if #a~=#b then return false end
 for i=1,#a do
  for j=1,3 do if a[i][j]~=b[i][j] then return false end end
 end
 return true
end
local function textId(x)
 return type(x)=="string" and #x>0 and #x<=160
end
function M.evaluate(proposal,observation,catalog,now,minimumGain,minimumReceivedDemand)
 minimumGain=minimumGain==nil and 0 or minimumGain
 minimumReceivedDemand=minimumReceivedDemand==nil and 4 or minimumReceivedDemand
 if type(proposal)~="table" or type(observation)~="table" or type(catalog)~="table" then
  return reject("INPUT_SHAPE_INVALID")
 end
 if not integer(now,1700000000,2100000000) or
    not integer(minimumGain,0,MAX_VALUE) or
    not integer(minimumReceivedDemand,1,10) then
  return reject("POLICY_OR_CLOCK_INVALID")
 end
 for _,k in ipairs({"sessionId","jobId","partnerKey","catalogVersion"}) do
  if not textId(proposal[k]) then return reject("PROPOSAL_BINDING_MISSING") end
  if observation[k]~=proposal[k] then
   return reject("SESSION_PARTNER_OR_CATALOG_CHANGED")
  end
 end
 if observation.tradeOpen~=true or observation.exactPartnerBound~=true then
  return reject("TRADE_OR_PARTNER_UNVERIFIED")
 end
 if observation.ourAccepted~=false or observation.theirAccepted~=false then
  return reject("ACCEPT_STATE_CHANGED_OR_UNKNOWN")
 end
 if observation.offerMutationPending~=false then
  return reject("OFFER_MUTATION_PENDING_OR_UNKNOWN")
 end
 local rev=proposal.offerRevision
 if not integer(rev,0,2147483647) then return reject("OFFER_REVISION_INVALID") end
 if not integer(observation.offerRevision,0,2147483647) or observation.offerRevision~=rev then
  return reject("OFFER_REVISION_CHANGED")
 end
 local observedAt,proposedAt=observation.observedAtUnix,proposal.observedAtUnix
 if not integer(observedAt,0,2100000000) or not integer(proposedAt,0,2100000000) or
    proposedAt>observedAt or observedAt>now or
    now-observedAt>MAX_OBSERVATION_AGE or
    proposedAt<observedAt-MAX_OBSERVATION_AGE then
  return reject("OBSERVATION_STALE_OR_CLOCK_INVALID")
 end
 if catalog.version~=proposal.catalogVersion or
   catalog.source~="SUPREME_DISPLAY_RESEARCH_ONLY" then
  return reject("MARKET_SOURCE_OR_VERSION_UNMATCHED")
 end
 local updated,fetched=catalog.publisherUpdatedAtUnix,catalog.retrievedAtUnix
 if not integer(updated,0,2100000000) or not integer(fetched,0,2100000000) or
   updated>fetched or fetched>now or now-updated>MAX_CATALOG_AGE or
   updated<1700000000 then
  return reject("PUBLISHER_TIMESTAMP_MISSING_OR_EXPIRED")
 end
 local ours,theirs,currentOurs,currentTheirs=slots(proposal.ours),
  slots(proposal.theirs),slots(observation.ours),slots(observation.theirs)
 if not ours or not theirs or not currentOurs or not currentTheirs then
  return reject("OFFER_SLOTS_UNREADABLE_OR_EMPTY")
 end
 if not equalSlots(ours,currentOurs) or not equalSlots(theirs,currentTheirs) then
  return reject("OFFER_SLOTS_CHANGED")
 end
 -- Stage83 exact raw game key, not an unverified display-name guess:
 -- OUR Gingerscope is protected regardless of any hypothetical listed gain.
 for _,row in ipairs(ours) do
  if row[2]=="Gingerscope" then
   return reject("PROTECTED_GINGERSCOPE_OUTGOING")
  end
 end
 if type(catalog.items)~="table" then return reject("MARKET_ITEMS_MISSING") end
 local totalOurs,totalTheirs=0,0
 for _,record in ipairs({{name="ours",rows=ours},{name="theirs",rows=theirs}}) do
  for _,slot in ipairs(record.rows) do
   local _,key,qty=slot[1],slot[2],slot[3]
   local entry=catalog.items[key]
   if type(entry)~="table" then return reject("UNKNOWN_CATALOG_ITEM") end
   if entry.identityLinkEvidence~="INDEPENDENT_EXACT" then
    return reject("RAW_KEY_TO_DISPLAY_ID_UNVERIFIED")
   end
   if not integer(entry.value,1,MAX_VALUE) then return reject("CATALOG_PRICE_INVALID") end
   if not integer(entry.demand,1,10) then return reject("DEMAND_UNKNOWN_OR_INVALID") end
   if type(entry.stability)~="string" then return reject("STABILITY_UNKNOWN") end
   if record.name=="theirs" then
    if entry.demand<minimumReceivedDemand then
     return reject("RECEIVED_ITEM_LOW_DEMAND")
    end
    if not SAFE_STABILITY[entry.stability] then
     return reject("RECEIVED_ITEM_UNSTABLE")
    end
    totalTheirs=totalTheirs+entry.value*qty
   else
    totalOurs=totalOurs+entry.value*qty
   end
  end
 end
 local gain=totalTheirs-totalOurs
 if gain<minimumGain then return reject("PROJECTED_LISTED_GAIN_BELOW_POLICY") end
 local result=reject("INTERNAL_SNAPSHOT_MATCH_NOT_SERVER_PROOF")
 result.status="RESEARCH_CANDIDATE_ONLY"
 result.valueOffered=totalOurs
 result.valueRequested=totalTheirs
 result.projectedListedGain=gain
 return result
end
return M
