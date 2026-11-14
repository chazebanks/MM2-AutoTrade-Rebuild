-- System2 Component 4: REAL-source read-only bilateral decision research.
-- Input: local private context from component3 original scanner/P4 observer.
-- Does NOT infer partner willingness from publisher demand or trade postings.
-- Does NOT issue remotes, offers, final Accept, Discord events or profit.
local M={}
local SCHEMA="gingerscope-system2-local-bilateral-context-v1"
local OUT_SCHEMA="gingerscope-system2-bilateral-market-shadow-v1"
local function block(why)
 return {schema=OUT_SCHEMA,status="BLOCKED",reason=why,readOnly=true,
  clientOnly=true,selectedIndex=nil,empiricalPartnerAcceptanceProbability=nil,
  verifiedCounterpartyPreference=false,completedTradeProven=false,
  authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
  mayReportProfit=false,maySendDiscordWebhook=false,mayUseForStrategyLearning=false}
end
local function key(k)
 return type(k)=="string" and #k>=1 and #k<=90 and
  k:match("^[A-Za-z0-9_]+$")~=nil
end
local function qty(q)
 return type(q)=="number" and q==math.floor(q) and q>=1 and q<=1000000
end
local function positive(n)
 return type(n)=="number" and n==math.floor(n) and n>0 and n<10000000000
end
local function scalar(n)
 return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end
local function priceRows(m,ctx)
 if type(m)~="table" or m.schema~="gingerscope-system2-exact-market-gamekey-crosswalk-v1"
  or m.status~="EXACT_HISTORICAL_GAMEKEY_MARKET_CROSSWALK" or
  m.authorizesTrade~=false or m.authorizesAccept~=false or
  m.mayUseForLiveOffer~=false or type(m.items)~="table" or #m.items~=189
  or m.crosswalkRowsSha256~=ctx.crosswalkRowsSha256
  or m.sourceRetrievedUtc~=ctx.sourceRetrievedUtc
  then return nil,"CROSSWALK_SOURCE_REVISION_CONFLICT" end
 local index={}
 for _,row in ipairs(m.items) do
  if type(row)~="table" or not key(row.rawGameKeyCandidate)
   or index[row.rawGameKeyCandidate] or
   not positive(row.mm2Listed) and row.mm2Listed~=nil or
   not positive(row.supremeListed) and row.supremeListed~=nil or
   type(row.demandOrdinal)~="string" or
   not scalar(tonumber(row.demandOrdinal)) or
   tonumber(row.demandOrdinal)<0 or tonumber(row.demandOrdinal)>11 or
   (row.stabilityLabel~=nil and type(row.stabilityLabel)~="string") or
   type(row.gameChroma)~="boolean" then
   return nil,"MARKET_VALUE_DEMAND_OR_VARIANT_MALFORMED"
  end
  index[row.rawGameKeyCandidate]=row
 end
 if not index.Gingerscope or index.Gingerscope.outgoingGingerscopeProtected~=true then
  return nil,"GINGERSCOPE_PROTECTION_MISSING" end
 return index,nil
end
local function slots(list,maxSlots)
 if type(list)~="table" or #list<1 or #list>maxSlots then
  return nil,"ONE_TO_FOUR_PHYSICAL_SLOTS_REQUIRED" end
 local result={}
 local size=0
 for _,item in ipairs(list) do
  if type(item)~="table" or not key(item.id) or not qty(item.quantity)
   or result[item.id] then
   return nil,"UNRESOLVED_DUPLICATE_OR_BAD_STACK" end
  size+=1
  result[item.id]=item.quantity
 end
 return result,nil
end
local function beforeAfter(own,give,receive)
 local nextOwned={}
 for k,q in pairs(own) do nextOwned[k]=q end
 for id,q in pairs(give) do
  if id=="Gingerscope" then return nil,"OUTGOING_GINGERSCOPE_FORBIDDEN" end
  if not nextOwned[id] or nextOwned[id]<q then
   return nil,"GIVE_EXCEEDS_FRESH_OWNED_COPIES" end
  nextOwned[id]-=q
  if nextOwned[id]==0 then nextOwned[id]=nil end
 end
 for id,q in pairs(receive) do
  nextOwned[id]=(nextOwned[id] or 0)+q
  if nextOwned[id]>1000000 then return nil,"POST_TRADE_STACK_OVERFLOW" end
 end
 return nextOwned,nil
end
local function quality(owned,index)
 local val,most,weightedDemand,riskValue=0,0,0,0
 for id,q in pairs(owned) do
  local r=index[id]
  if not r or not positive(r.mm2Listed) or type(r.stabilityLabel)~="string" then return nil end
  local contribution=q*r.mm2Listed
  val+=contribution
  most=math.max(most,contribution)
  weightedDemand+=contribution*tonumber(r.demandOrdinal)
  local status=r.stabilityLabel:lower():gsub("[^%a]","")
  if status=="unsafe" or status=="decreasing" or status=="underpaidfor" then
   riskValue+=contribution end
 end
 return {listedValue=val,concentrationBasisPoints=val>0 and
   math.floor(most*10000/val) or 0,
   weightedDemandOrdinal=val>0 and weightedDemand/val or 0,
   atRiskValueShareBasisPoints=val>0 and math.floor(riskValue*10000/val) or 0}
end
local function sumQuotes(bundle,index)
 local mm2,sup,dem,totalDemand,stackRisk=0,0,0,0,false
 local lowDemand=false
 local risky=false
 local uncertainty={}
 for id,q in pairs(bundle) do
  local row=index[id]
  if not row then return nil,"UNKNOWN_MARKET_WEAPON" end
  if type(row.stabilityLabel)~="string" or #row.stabilityLabel==0 then
   return nil,"PUBLISHER_STABILITY_MISSING" end
  if row.mm2Listed==nil or row.supremeListed==nil then
   return nil,"DUAL_PUBLISHER_PRICE_NOT_AVAILABLE" end
  local demand=tonumber(row.demandOrdinal)
  if not scalar(demand) then return nil,"UNKNOWN_PUBLISHER_DEMAND" end
  mm2+=row.mm2Listed*q
  sup+=row.supremeListed*q
  dem+=row.mm2Listed*q*demand
  totalDemand+=row.mm2Listed*q
  if demand<=2 then lowDemand=true end
  local label=row.stabilityLabel:lower():gsub("[^%a]","")
  if label=="unsafe" or label=="decreasing" or label=="underpaidfor" then
   risky=true end
  if label=="fluctuating" then uncertainty[#uncertainty+1]="FLUCTUATING_PUBLISHER_LABEL" end
  if q>=5 and row.mm2Listed>1 then stackRisk=true end
 end
 return {mm2=mm2,supreme=sup,demand=totalDemand>0 and dem/totalDemand or 0,
   lowDemand=lowDemand,risky=risky,stackRisk=stackRisk,
   uncertainty=uncertainty},nil
end
local function sameBundle(a,b)
 if type(a)~="table" or type(b)~="table" then return false end
 for k,v in pairs(a) do if b[k]~=v then return false end end
 for k,v in pairs(b) do if a[k]~=v then return false end end
 return true
end
local function resultRow(i,reason)
 return {index=i,status="FILTERED",reason=reason,
  partnerSurplusProven=false,realLiquidityVerified=false,
  mayUseForTrade=false}
end
local function interestExact(current,observed,accepted)
 if accepted~=true then return false end
 local indexed={}
 if type(observed)~="table" or type(observed.items)~="table" then return false end
 for _,x in ipairs(observed.items) do
  if not key(x.id) or not qty(x.quantity) or indexed[x.id] then return false end
  indexed[x.id]=x.quantity
 end
 return sameBundle(current,indexed)
end
local function compare(a,b)
 -- Two-sided uncertainty first, future retradability labels second, paper gain last.
 if a.partnerSignal~=b.partnerSignal then return a.partnerSignal end
 if a.incomingAtRisk~=b.incomingAtRisk then return not a.incomingAtRisk end
 if a.incomingDemandOrdinal~=b.incomingDemandOrdinal then
  return a.incomingDemandOrdinal>b.incomingDemandOrdinal end
 if a.afterConcentrationBasisPoints~=b.afterConcentrationBasisPoints then
  return a.afterConcentrationBasisPoints<b.afterConcentrationBasisPoints end
 if a.afterAtRiskShareBasisPoints~=b.afterAtRiskShareBasisPoints then
  return a.afterAtRiskShareBasisPoints<b.afterAtRiskShareBasisPoints end
 -- A partner who would need to sacrifice less listed value faces less friction,
 -- even though real subjective willingness remains unobserved.
 if a.partnerMm2ListedDelta~=b.partnerMm2ListedDelta then
  return a.partnerMm2ListedDelta>b.partnerMm2ListedDelta end
 if a.minCrossListGain~=b.minCrossListGain then
  return a.minCrossListGain>b.minCrossListGain end
 return a.index<b.index
end
function M.compare(context,market,alternatives)
 if type(context)~="table" or context.schema~=SCHEMA or
  context.status~="LOCAL_READONLY_MARKET_OFFER_CONTEXT" or
  context.clientOnly~=true or context.readOnly~=true or
  context.marketSourceVerifiedForLiveTrade~=false or
  context.counterpartyWillingnessVerified~=false or
  context.authorizesOffer~=false or context.authorizesAccept~=false or
  type(context.ownCounts)~="table" or type(context.offer)~="table" or
  context.offer.clientOnly~=true or context.offer.readOnly~=true or
  context.offer.authorizesOffer~=false or context.offer.authorizesAccept~=false or
  type(context.clientOfferRevision)~="number" or
  context.clientOfferRevision~=context.offer.clientRevision or
  context.clientOfferRevision<1 or
  context.clientOfferRevision~=math.floor(context.clientOfferRevision) or
  not scalar(context.offer.sourceAgeSeconds) or
  context.offer.sourceAgeSeconds<0 or context.offer.sourceAgeSeconds>21600 or
  not scalar(context.offer.ownedCensusAgeSeconds) or
  context.offer.ownedCensusAgeSeconds<0 or context.offer.ownedCensusAgeSeconds>30 then
  return block("FRESH_UNAUTHORIZED_OR_WRONG_CLIENT_CONTEXT")
 end
 local index,err=priceRows(market,context)
 if not index then return block(err) end
 local before=quality(context.ownCounts,index)
 if not before then return block("OWN_RAW_KEY_WITHOUT_CURRENT_PRICE") end
 local opponentCurrent={}
 if type(context.offer.their)~="table" or
    type(context.offer.their.items)~="table" or
    #context.offer.their.items>4 or
    type(context.offer.our)~="table" or
    type(context.offer.our.items)~="table" or
    #context.offer.our.items>4 or
    type(context.offer.theirAccepted)~="boolean" or
    type(context.offer.ourAccepted)~="boolean" or
    type(context.offer.nameOnlyCatalogCandidateCount)~="number" or
    not scalar(context.offer.nameOnlyCatalogCandidateCount) or
    context.offer.nameOnlyCatalogCandidateCount<0 or
    context.offer.nameOnlyCatalogCandidateCount~=math.floor(context.offer.nameOnlyCatalogCandidateCount) or
    type(context.offer.exactRawAttributesBothSidesObserved)~="boolean" then
  return block("TWO_SIDED_CLIENT_OFFER_REQUIRED") end
 for _,item in ipairs(context.offer.their.items) do
  if not key(item.id) or not qty(item.quantity) or
     opponentCurrent[item.id] then return block("OPPONENT_OFFER_UNRESOLVED") end
  opponentCurrent[item.id]=item.quantity
 end
 if type(alternatives)~="table" or #alternatives<2 or #alternatives>12 then
  return block("TWO_TO_TWELVE_ALTERNATIVES_REQUIRED") end
 local report,viable,seen={}, {},{}
 for i,option in ipairs(alternatives) do
  if type(option)~="table" or option.kind~="HYPOTHETICAL_CURRENT_OFFER_VARIANT"
   then return block("UNTRUSTED_ALT_OPTION") end
  local give,errGive=slots(option.give,4)
  local receive,errReceive=slots(option.receive,4)
  if not give or not receive then
   report[#report+1]=resultRow(i,errGive or errReceive)
  else
   local fragments={}
   for id,q in pairs(give) do fragments[#fragments+1]="G:"..id..":"..q end
   for id,q in pairs(receive) do fragments[#fragments+1]="R:"..id..":"..q end
   table.sort(fragments)
   local fingerprint=table.concat(fragments,"|")
   if seen[fingerprint] then return block("DUPLICATE_ALTERNATIVES") end
   seen[fingerprint]=true
   local err=nil
   for id,q in pairs(receive) do
    if opponentCurrent[id]==nil or q>opponentCurrent[id] then
     err="PARTNER_STOCK_NOT_IN_CURRENT_VISIBLE_OFFER" break end
   end
   local nextOwned=nil
   if not err then
    nextOwned,err=beforeAfter(context.ownCounts,give,receive) end
   local incoming,outgoing=nil,nil
   if not err then
    outgoing,err=sumQuotes(give,index)
    if not err then incoming,err=sumQuotes(receive,index) end
   end
   if err then
    report[#report+1]=resultRow(i,err)
   else
    local mm2gain=incoming.mm2-outgoing.mm2
    local supgain=incoming.supreme-outgoing.supreme
    local after=quality(nextOwned,index)
    if not after then return block("POST_PORTFOLIO_PRICE_GAP") end
    local copyUncertain=incoming.stackRisk or outgoing.stackRisk
    local isBadIncoming=incoming.risky
    local valid=mm2gain>=0 and supgain>=0 and not copyUncertain and not isBadIncoming
    local partnerSignal=interestExact(give,context.offer.our,context.offer.theirAccepted)
      and interestExact(receive,context.offer.their,context.offer.theirAccepted)
    if context.offer.nameOnlyCatalogCandidateCount~=0 or
      context.offer.exactRawAttributesBothSidesObserved~=true then
      partnerSignal=false end
    local reasons={}
    if mm2gain<0 or supgain<0 then reasons[#reasons+1]="UNAPPROVED_LISTED_VALUE_LOSS" end
    if copyUncertain then reasons[#reasons+1]="FIVE_PLUS_COPY_PRICE_NONLINEAR" end
    if isBadIncoming then reasons[#reasons+1]="UNSAFE_INCOMING_STABILITY" end
    if incoming.lowDemand then reasons[#reasons+1]="LOW_ORDINAL_DEMAND_CAUTION" end
    if not partnerSignal then reasons[#reasons+1]="PARTNER_EXPLICIT_PREFERENCE_NOT_PROVEN" end
    reasons[#reasons+1]="POSTED_TRADES_NOT_EXECUTED_LIQUIDITY"
    local record={
     index=i,status=valid and "RESEARCH_FEASIBLE_UNAUTHORIZED" or "RISK_FILTERED",
     reason=valid and "CLIENT_ONLY_NO_SETTLEMENT_OR_WILLINGNESS_PROOF"
       or "RESEARCH_RISK_POLICY_STOP",
     giveSlots=#option.give,receiveSlots=#option.receive,
     mm2ListedDelta=mm2gain,supremeListedDelta=supgain,
     partnerMm2ListedDelta=-mm2gain,partnerSupremeListedDelta=-supgain,
     minCrossListGain=math.min(mm2gain,supgain),
     incomingDemandOrdinal=incoming.demand,
     outgoingDemandOrdinal=outgoing.demand,
     incomingAtRisk=isBadIncoming,incomingLowOrdinalDemand=incoming.lowDemand,
     nonlinearStackPricingUnverified=copyUncertain,
     beforeConcentrationBasisPoints=before.concentrationBasisPoints,
     afterConcentrationBasisPoints=after.concentrationBasisPoints,
     afterAtRiskShareBasisPoints=after.atRiskValueShareBasisPoints,
     qualityChangeDemandOrdinal=after.weightedDemandOrdinal-before.weightedDemandOrdinal,
     partnerSignal=partnerSignal,
     partnerSignalKind=partnerSignal and
      "CLIENT_ACCEPTED_IDENTICAL_CURRENT_GUI_ONLY" or "UNVERIFIED",
     counterpartSpecificSubjectiveValueMeasured=false,
     empiricalFillRate=nil,
     verifiedCounterpartyPreference=false,
     mayUseForTrade=false,warnings=reasons}
    report[#report+1]=record
    if valid then viable[#viable+1]=record end
   end
  end
 end
 table.sort(viable,compare)
 local researchOrder={}
 for _,x in ipairs(viable) do researchOrder[#researchOrder+1]=x.index end
 local selected=nil
 -- Only existing, visibly accepted, unchanged client offer may receive a
 -- shadow preferred index; never infer a counteroffer's acceptance from this.
 if #viable>0 and viable[1].partnerSignal then
  selected=viable[1].index end
 return {
  schema=OUT_SCHEMA,
  status=selected and "CLIENT_SHADOW_PREFERS_OBSERVED_ACCEPTED_OFFER"
    or "ABSTAIN_PARTNER_INTENT_UNVERIFIED",
  reason=selected and "CLIENT_INDICATOR_ONLY_NOT_SERVER_PROOF"
    or "NO_ACTIONABLE_PROOF_OF_COUNTERPARTY_WILLINGNESS",
  readOnly=true,clientOnly=true,
  sourceEdition=market.marketEdition,sourceRowsSha256=market.crosswalkRowsSha256,
  clientOfferRevision=context.clientOfferRevision,
  considered=#report,researchAttentionIndices=researchOrder,
  selectedIndex=selected,
  selectedIndexIsActionable=false,
  alternatives=report,
  empiricalPartnerAcceptanceProbability=nil,
  verifiedCounterpartyPreference=false,completedTradeProven=false,
  authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
  mayReportProfit=false,maySendDiscordWebhook=false,mayUseForStrategyLearning=false}
end
return M
