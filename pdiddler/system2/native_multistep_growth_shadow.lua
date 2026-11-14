-- Gingerscope System2 component 5: native BOUNDED multi-step market-path discovery.
-- Uses actual component3 local scanner/GUI state + component4 bilateral oracle;
-- future "sellers" are EXPLICIT HYPOTHETICAL STOCK POOLS, never observed players.
-- No gameplay actions, trade/Accept, Discord, realized profit or training authority.
local M={}
local SCHEMA="gingerscope-system2-multistep-source-growth-shadow-v1"
local KIND="EXPLICIT_HYPOTHETICAL_FUTURE_SELLER_STOCK"
local TARGET="Gingerscope"
local MAX_SEARCH_PAIRS=80000
local BEAM=14
local function denied(status,reason)
 return {schema=SCHEMA,status=status,reason=reason,
  readOnly=true,clientOnly=true,selectedResearchRouteIndex=nil,
  selectedRouteActionable=false,originalMM2LivePass=false,
  futureSellerAvailabilityVerified=false,anyPartnerWillingnessVerified=false,
  futureTradesExecuted=false,tradeOutcome="UNKNOWN",
  verifiedProfit=false,authorizesTrade=false,authorizesOffer=false,
  authorizesAccept=false,maySendDiscordWebhook=false,
  mayReportProfit=false,mayUseForStrategyLearning=false}
end
local function number(n)
 return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end
local function pos(n)
 return number(n) and n==math.floor(n) and n>0 and n<=1000000
end
local function raw(k)
 return type(k)=="string" and #k>0 and #k<=90 and k:match("^[A-Za-z0-9_]+$")~=nil
end
local function copy(t)
 local x={}
 for k,v in pairs(t) do x[k]=v end
 return x
end
local function fingerprint(t)
 local s={}
 for k,v in pairs(t) do
  if v>0 then s[#s+1]=k..":"..tostring(v) end
 end
 table.sort(s)
 return table.concat(s,"|")
end
local function rowIndex(m,ctx)
 if type(m)~="table" or type(ctx)~="table" or
    m.schema~="gingerscope-system2-exact-market-gamekey-crosswalk-v1" or
    m.status~="EXACT_HISTORICAL_GAMEKEY_MARKET_CROSSWALK" or
    m.crosswalkRowsSha256~=ctx.crosswalkRowsSha256 or
    m.sourceRetrievedUtc~=ctx.sourceRetrievedUtc or
    m.authorizesTrade~=false or m.authorizesAccept~=false or
    m.mayUseForLiveOffer~=false or type(m.items)~="table" or #m.items~=189
    then return nil,"SOURCE_MARKET_CROSSWALK_UNVERIFIED" end
 local idx={}
 for _,item in ipairs(m.items) do
  if type(item)~="table" or not raw(item.rawGameKeyCandidate) or
      idx[item.rawGameKeyCandidate] or
      (item.mm2Listed~=nil and not pos(item.mm2Listed)) or
      (item.supremeListed~=nil and not pos(item.supremeListed)) or
      (type(item.demandOrdinal)~="string" or
       not number(tonumber(item.demandOrdinal))) or
      (item.stabilityLabel~=nil and type(item.stabilityLabel)~="string") or
      item.exactGameInstanceProven~=false then
   return nil,"SOURCE_ITEM_OR_PRICE_CONTRACT_INVALID" end
  idx[item.rawGameKeyCandidate]=item
 end
 if not idx[TARGET] or idx[TARGET].outgoingGingerscopeProtected~=true
    or not pos(idx[TARGET].mm2Listed) then
  return nil,"SOURCE_TARGET_NOT_PROTECTED_OR_PRICED" end
 return idx,nil
end
local function stock(list,index,allowEmpty)
 if type(list)~="table" or #list>4 or (not allowEmpty and #list==0) then
  return nil,"STOCK_REQUIRES_ONE_TO_FOUR_PHYSICAL_KEYS" end
 local out={}
 for _,item in ipairs(list) do
  if type(item)~="table" or not raw(item.id) or not pos(item.quantity) or
    not index[item.id] or out[item.id]~=nil then
   return nil,"STOCK_RAW_KEY_OR_QUANTITY_INVALID" end
  out[item.id]=item.quantity
 end
 return out,nil
end
local function validateOwned(own,index)
 if type(own)~="table" then return nil,"FRESH_OWN_SCANNER_CENSUS_MISSING" end
 local copyCounts,count={},0
 for key,q in pairs(own) do
  if not raw(key) or not pos(q) or not index[key] then
   return nil,"OWN_CENSUS_UNKNOWN_OR_BAD_RAW_KEY" end
  copyCounts[key]=q;count+=1
  if count>189 then return nil,"OWN_CENSUS_EXCEEDS_MARKET_CATALOG" end
 end
 if count==0 then return nil,"EMPTY_OWN_INVENTORY_CANNOT_GROW" end
 return copyCounts,nil
end
local function valuation(bundle,index)
 local mm2,sup,low,good,demandSum,weight=0,0,0,0,0,0
 local risky,lowDemand,nonlinear,unknown=false,0,false,false
 for key,q in pairs(bundle) do
  local r=index[key]
  if not r or not pos(r.mm2Listed) or not pos(r.supremeListed) then
   return nil,"DUAL_MARKET_QUOTE_MISSING" end
  if type(r.stabilityLabel)~="string" then
   return nil,"MISSING_STABILITY_EVIDENCE" end
  local d=tonumber(r.demandOrdinal)
  if not number(d) or d<0 or d>11 then
   return nil,"DEMAND_MARKER_INVALID" end
  local st=r.stabilityLabel:lower():gsub("[^%a]","")
  if st=="unsafe" or st=="decreasing" or st=="underpaidfor" then risky=true end
  if d<=2 then lowDemand+=1 end
  -- Publisher linear multiples of 5+ copies are not empirically verified.
  if q>=5 then nonlinear=true end
  mm2+=q*r.mm2Listed
  sup+=q*r.supremeListed
  demandSum+=q*r.mm2Listed*d;weight+=q*r.mm2Listed
 end
 return {mm2=mm2,supreme=sup,
  demand=weight>0 and demandSum/weight or 0,
  lowDemandKeys=lowDemand,hasUnsafeIncoming=risky,
  nonlinearStack=nonlinear},nil
end
local function apply(owned,give,receive)
 local future=copy(owned)
 for id,q in pairs(give) do
  if id==TARGET then return nil,"GINGERSCOPE_NEVER_OUTBOUND" end
  if not future[id] or future[id]<q then
   return nil,"GIVE_EXCEEDS_HYPOTHETICAL_AVAILABLE_COPIES" end
  future[id]-=q
  if future[id]==0 then future[id]=nil end
 end
 for id,q in pairs(receive) do
  future[id]=(future[id] or 0)+q
  if future[id]>1000000 then return nil,"POST_TRADE_COPY_LIMIT_EXCEEDED" end
 end
 return future,nil
end
local function quality(owned,index)
 local total,largest,weighted,unsafe=0,0,0,0
 for id,q in pairs(owned) do
  local r=index[id]
  if not r or not pos(r.mm2Listed) then return nil end
  local piece=q*r.mm2Listed
  local d=tonumber(r.demandOrdinal)
  if not number(d) then return nil end
  total+=piece
  largest=math.max(largest,piece)
  weighted+=piece*d
  local st=type(r.stabilityLabel)=="string" and
    r.stabilityLabel:lower():gsub("[^%a]","") or "unknown"
  if st=="unsafe" or st=="decreasing" or st=="underpaidfor" or
     st=="unknown" then unsafe+=piece end
 end
 return {listed=total,demandOrdinal=total>0 and weighted/total or 0,
  concentrationBps=total>0 and math.floor(10000*largest/total) or 0,
  uncertainBps=total>0 and math.floor(10000*unsafe/total) or 0}
end
local function bundles(held,maxKeys)
 local keys={}
 for id,q in pairs(held) do
  if q>0 and id~=TARGET then keys[#keys+1]=id end
 end
 table.sort(keys)
 if #keys>maxKeys then return nil,"BOUNDED_SEARCH_REQUIRES_AT_MOST_FOUR_HELD_KEYS" end
 local result={}
 local function go(i,acc)
  if i>#keys then
   if next(acc)~=nil then result[#result+1]=copy(acc) end
   return
  end
  local key=keys[i]
  local q=held[key]
  go(i+1,acc)
  local counts={1}
  if q>=2 then counts[#counts+1]=2 end
  if q>2 then counts[#counts+1]=q end
  for _,n in ipairs(counts) do
   acc[key]=n;go(i+1,acc);acc[key]=nil
  end
 end
 go(1,{})
 return result,nil
end
local function selectHeld(held,index,limit)
 local items={}
 for id,q in pairs(held) do
  if id~=TARGET and pos(q) and index[id] and index[id].mm2Listed then
   items[#items+1]=id end
 end
 -- Search heuristic intentionally considers VALUE and DEMAND, never claims
 -- complete enumeration of an account with >4 different sellable items.
 table.sort(items,function(a,b)
  local x,y=index[a],index[b]
  local wx=x.mm2Listed*held[a];local wy=y.mm2Listed*held[b]
  if wx~=wy then return wx>wy end
  if tonumber(x.demandOrdinal)~=tonumber(y.demandOrdinal) then
   return tonumber(x.demandOrdinal)>tonumber(y.demandOrdinal) end
  return a<b
 end)
 local used={}
 for i=1,math.min(limit,#items) do used[items[i]]=held[items[i]] end
 return used,#items>limit
end
local function transition(owned,give,receive,index,scope)
 -- A hypothetical future market listing of Gingerscope is NOT evidence that
 -- any real seller owns or would transfer it. Keep target-acquisition routes
 -- out of actionable-looking projections until independently verified intent.
 if scope=="EXPLICIT_HYPOTHETICAL_FUTURE_SELLER_UNVERIFIED" and receive[TARGET] then
  return nil,"FUTURE_GINGERSCOPE_SELLER_UNATTRIBUTED"
 end
 local outgoing,why=valuation(give,index)
 if not outgoing then return nil,why end
 local incoming,why2=valuation(receive,index)
 if not incoming then return nil,why2 end
 if outgoing.nonlinearStack or incoming.nonlinearStack then
  return nil,"NONLINEAR_FIVE_PLUS_COPY_STACK_NOT_PRICED" end
 if incoming.hasUnsafeIncoming then return nil,"UNSAFE_INCOMING_PUBLISHER_LABEL" end
 local dMM2=incoming.mm2-outgoing.mm2
 local dSup=incoming.supreme-outgoing.supreme
 if dMM2<0 or dSup<0 then return nil,"UNAPPROVED_LISTED_VALUE_LOSS" end
 if fingerprint(give)==fingerprint(receive) then
  return nil,"SAME_ITEMS_NOT_A_REAL_GROWTH_STEP" end
 local after,why3=apply(owned,give,receive)
 if not after then return nil,why3 end
 local beforeQ=quality(owned,index)
 local afterQ=quality(after,index)
 if not beforeQ or not afterQ or
    afterQ.listed~=beforeQ.listed+dMM2 then
  return nil,"HYPOTHETICAL_PORTFOLIO_CONSERVATION_FAILED" end
 local gg,rr=0,0
 local gList,rList={},{}
 for id,q in pairs(give) do gg+=1;gList[#gList+1]={id=id,quantity=q} end
 for id,q in pairs(receive) do rr+=1;rList[#rList+1]={id=id,quantity=q} end
 table.sort(gList,function(a,b)return a.id<b.id end)
 table.sort(rList,function(a,b)return a.id<b.id end)
 return {give=gList,receive=rList,ownedAfter=after,
  kind=rr<gg and "UPGRADE" or rr>gg and "DOWNGRADE" or "SIDEGRADE",
  scope=scope,mm2Gain=dMM2,supremeGain=dSup,
  partnerMm2ListedDelta=-dMM2,
  partnerSupremeListedDelta=-dSup,
  receivedDemandOrdinal=incoming.demand,
  lowDemandIncomingKeys=incoming.lowDemandKeys,
  atRiskIncoming=false,listedValueAfter=afterQ.listed,
  afterDemandOrdinal=afterQ.demandOrdinal,
  afterConcentrationBps=afterQ.concentrationBps,
  clientSessionSettlementVerified=false,
  executableWithCurrentPartner=false,
  hypotheticalOnly=true},nil
end
local function score(p,index)
 local final=p.holdings
 local q=quality(final,index)
 local gap=math.max(0,index[TARGET].mm2Listed-q.listed)
 local minGain=math.huge
 local lowDemand=0;local sellerSacrifice=0;local tempRisk=0
 local speculativeSellerFrictionBps=0
 for _,step in ipairs(p.steps) do
  minGain=math.min(minGain,math.min(step.mm2Gain,step.supremeGain))
  lowDemand+=step.lowDemandIncomingKeys
  sellerSacrifice+=math.max(step.mm2Gain,step.supremeGain)
  if step.scope=="EXPLICIT_HYPOTHETICAL_FUTURE_SELLER_UNVERIFIED" then
   local rec=0
   for _,z in ipairs(step.receive) do rec+=index[z.id].mm2Listed*z.quantity end
   if rec>0 then
    speculativeSellerFrictionBps+=math.floor(10000*step.mm2Gain/rec)
   end
  end
  if step.scope=="ACTUAL_CLIENT_OFFER_VISIBLE_UNVERIFIED_ACCEPTANCE" and
     step.receivedDemandOrdinal<3 then tempRisk+=1 end
 end
 return {targetGap=gap,listedValue=q.listed,
  finalDemandOrdinal=q.demandOrdinal,
  finalConcentrationBps=q.concentrationBps,
  finalUncertaintyBps=q.uncertainBps,
  lowDemandIncomingOccurrences=lowDemand,
  lowDemandFirstStep=tempRisk,
  aggregatePartnerListedSacrifice=sellerSacrifice,
  unverifiedFutureSellerSacrificeBasisPoints=speculativeSellerFrictionBps,
  minimumCrossListStepGain=minGain}
end
local function better(a,b)
 local x,y=a.metrics,b.metrics
 if x.lowDemandFirstStep~=y.lowDemandFirstStep then
  return x.lowDemandFirstStep<y.lowDemandFirstStep end
 if x.finalUncertaintyBps~=y.finalUncertaintyBps then
  return x.finalUncertaintyBps<y.finalUncertaintyBps end
 if x.lowDemandIncomingOccurrences~=y.lowDemandIncomingOccurrences then
  return x.lowDemandIncomingOccurrences<y.lowDemandIncomingOccurrences end
 if x.unverifiedFutureSellerSacrificeBasisPoints~=
     y.unverifiedFutureSellerSacrificeBasisPoints then
  return x.unverifiedFutureSellerSacrificeBasisPoints<
    y.unverifiedFutureSellerSacrificeBasisPoints end
 if x.targetGap~=y.targetGap then return x.targetGap<y.targetGap end
 if x.finalDemandOrdinal~=y.finalDemandOrdinal then
  return x.finalDemandOrdinal>y.finalDemandOrdinal end
 if x.finalConcentrationBps~=y.finalConcentrationBps then
  return x.finalConcentrationBps<y.finalConcentrationBps end
 if x.aggregatePartnerListedSacrifice~=y.aggregatePartnerListedSacrifice then
  return x.aggregatePartnerListedSacrifice<y.aggregatePartnerListedSacrifice end
 if x.minimumCrossListStepGain~=y.minimumCrossListStepGain then
  return x.minimumCrossListStepGain>y.minimumCrossListStepGain end
 return a.pathKey<b.pathKey
end
local function beamPick(nodes)
 table.sort(nodes,better)
 local out,perFirst={},{}
 for _,candidate in ipairs(nodes) do
  local seed=candidate.firstChoiceFingerprint
  if (perFirst[seed] or 0)<3 then
   out[#out+1]=candidate
   perFirst[seed]=(perFirst[seed] or 0)+1
   if #out==BEAM then break end
  end
 end
 return out
end
local function convert(list)
 local entries={}
 for _,v in ipairs(list) do entries[v.id]=v.quantity end
 return entries
end
local function newState(first,index)
 local stamp=fingerprint(first.ownedAfter)
 local node={steps={first},holdings=copy(first.ownedAfter),seen={[stamp]=true},
  pathKey=fingerprint(first.ownedAfter)..":1",
  firstChoiceFingerprint=fingerprint(convert(first.give)).."/"..fingerprint(convert(first.receive))}
 node.metrics=score(node,index)
 return node
end
local function details(steps)
 local out={}
 for i,s in ipairs(steps) do
  out[#out+1]={step=i,kind=s.kind,scope=s.scope,
   give=s.give,receive=s.receive,
   mm2ListedGain=s.mm2Gain,supremeListedGain=s.supremeGain,
   partnerMm2ListedDelta=s.partnerMm2ListedDelta,
   partnerSupremeListedDelta=s.partnerSupremeListedDelta,
   receivedDemandOrdinal=s.receivedDemandOrdinal,
   lowDemandIncomingKeys=s.lowDemandIncomingKeys,
   paperOwnedListedValueAfter=s.listedValueAfter,
   sellerActuallyVerified=false,authorizedAction=false}
 end
 return out
end
function M.search(context,market,spec,bilateral)
 if type(spec)~="table" or
    spec.kind~="BOUNDED_RESEARCH_FUTURE_SELLER_ROUTE_SEARCH" or
    type(spec.futureSellerStages)~="table" or
    #spec.futureSellerStages<1 or #spec.futureSellerStages>3 or
    type(bilateral)~="table" or type(bilateral.compare)~="function" then
  return denied("BLOCKED","BOUNDED_MULTISTEP_RESEARCH_INPUT_REQUIRED") end
 if type(context)~="table" or
    context.schema~="gingerscope-system2-local-bilateral-context-v1" or
    context.status~="LOCAL_READONLY_MARKET_OFFER_CONTEXT" or
    context.readOnly~=true or context.authorizesOffer~=false or
    type(context.offer)~="table" or
    type(context.offer.their)~="table" or
    type(context.offer.their.items)~="table" or
    context.offer.clientOnly~=true then
  return denied("BLOCKED","FRESH_COMPONENT3_LOCAL_CONTEXT_REQUIRED") end
 local index,why=rowIndex(market,context)
 if not index then return denied("BLOCKED",why) end
 local original,err=validateOwned(context.ownCounts,index)
 if not original then return denied("BLOCKED",err) end
 local partner,partnerErr=stock(context.offer.their.items,index,true)
 if not partner then return denied("BLOCKED",partnerErr) end
 if next(partner)==nil then return denied("ABSTAIN","PARTNER_CURRENT_OFFER_EMPTY") end
 local stagePools={}
 for i,stage in ipairs(spec.futureSellerStages) do
  if type(stage)~="table" or stage.kind~=KIND or
    type(stage.stock)~="table" or #stage.stock<1 or #stage.stock>4 or
    stage.availabilityVerified~=false or stage.willingnessVerified~=false then
   return denied("BLOCKED","FUTURE_SELLER_STAGE_MUST_BE_HYPOTHETICAL") end
  local pool,stockErr=stock(stage.stock,index,false)
  if not pool then return denied("BLOCKED",stockErr) end
  stagePools[i]=pool
 end
 local shortlist,notExhaustive=selectHeld(original,index,4)
 if next(shortlist)==nil then
  return denied("ABSTAIN","ONLY_PROTECTED_OR_UNPRICED_OWNED_ITEMS") end
 local ourBundles,bundleErr=bundles(shortlist,4)
 local theirBundles,recvErr=bundles(partner,4)
 if not ourBundles or not theirBundles then
  return denied("BLOCKED",bundleErr or recvErr) end
 local candidates={}
 local skipped={loss=0,stack=0,other=0}
 for _,g in ipairs(ourBundles) do
  for _,r in ipairs(theirBundles) do
   local step,stepWhy=transition(original,g,r,index,
     "ACTUAL_CLIENT_OFFER_VISIBLE_UNVERIFIED_ACCEPTANCE")
   if step then candidates[#candidates+1]=step
   elseif stepWhy=="UNAPPROVED_LISTED_VALUE_LOSS" then skipped.loss+=1
   elseif stepWhy=="NONLINEAR_FIVE_PLUS_COPY_STACK_NOT_PRICED" then skipped.stack+=1
   else skipped.other+=1 end
  end
 end
 if #candidates<2 then
  return denied("ABSTAIN","TWO_DISTINCT_FIRST_STEP_ALTERNATIVES_NOT_FOUND") end
 -- C4 is the existing market/current partner/stock attractiveness oracle.
 -- Ask it to inspect the 12 best DIVERSE first steps; a research attention
 -- order is not partner agreement or permission to send an offer.
 table.sort(candidates,function(a,b)
  local x,y=a.receivedDemandOrdinal,b.receivedDemandOrdinal
  if x~=y then return x>y end
  local gainA=math.min(a.mm2Gain,a.supremeGain)
  local gainB=math.min(b.mm2Gain,b.supremeGain)
  if gainA~=gainB then return gainA>gainB end
  local keyA=fingerprint(convert(a.give)).."/"..fingerprint(convert(a.receive))
  local keyB=fingerprint(convert(b.give)).."/"..fingerprint(convert(b.receive))
  return keyA<keyB
 end)
 local attention,selected,used={},{},{}
 for _,step in ipairs(candidates) do
  local sig=fingerprint(convert(step.give)).."/"..fingerprint(convert(step.receive))
  if not used[sig] then
   used[sig]=true
   attention[#attention+1]=step
   if #attention==12 then break end
  end
 end
 local options={}
 for _,s in ipairs(attention) do
  options[#options+1]={
   kind="HYPOTHETICAL_CURRENT_OFFER_VARIANT",give=s.give,receive=s.receive}
 end
 local check=bilateral.compare(context,market,options)
 if type(check)~="table" or check.schema~="gingerscope-system2-bilateral-market-shadow-v1"
   or check.authorizesOffer~=false or check.authorizesAccept~=false or
   type(check.alternatives)~="table" or #check.alternatives~=#options or
   check.status=="BLOCKED" then
  return denied("BLOCKED","COMPONENT4_BILATERAL_ORACLE_REJECTED_FIRST_STEPS") end
 local frontier={}
 for i,record in ipairs(check.alternatives) do
  if record.status=="RESEARCH_FEASIBLE_UNAUTHORIZED" and
     record.mayUseForTrade==false then
   local route=newState(attention[i],index)
   frontier[#frontier+1]=route
  end
 end
 if #frontier<1 then
  return denied("ABSTAIN","NO_SOURCE_SAFE_FIRST_STEP_FROM_CURRENT_OFFER") end
 frontier=beamPick(frontier)
 local comparisons=0
 local terminal={}
 local stageStats={}
 for level,pool in ipairs(stagePools) do
  local incomingOptions,whyB=bundles(pool,4)
  if not incomingOptions then return denied("BLOCKED",whyB) end
  local nextFrontier,repeatSeen={},{}
  local levelUsed=0
  for _,node in ipairs(frontier) do
   local selectedKeys,shortlisted=selectHeld(node.holdings,index,4)
   if next(selectedKeys) then
    local ownOptions,whyA=bundles(selectedKeys,4)
    if not ownOptions then return denied("BLOCKED",whyA) end
    for _,give in ipairs(ownOptions) do
     for _,receive in ipairs(incomingOptions) do
      comparisons+=1
      if comparisons>MAX_SEARCH_PAIRS then
       return denied("BLOCKED","SEARCH_BUDGET_EXCEEDED_REDUCE_SELLER_STAGES") end
      local step,whyStep=transition(node.holdings,give,receive,index,
       "EXPLICIT_HYPOTHETICAL_FUTURE_SELLER_UNVERIFIED")
      if step then
       local stamp=fingerprint(step.ownedAfter)
       if not node.seen[stamp] then
        local newSteps={}
        for _,prior in ipairs(node.steps) do newSteps[#newSteps+1]=prior end
        newSteps[#newSteps+1]=step
        local pathKey=node.pathKey.."/"..stamp..":"..tostring(level+1)
        if not repeatSeen[pathKey] then
         repeatSeen[pathKey]=true
         local traces=copy(node.seen);traces[stamp]=true
         local extended={steps=newSteps,holdings=step.ownedAfter,
          seen=traces,pathKey=pathKey,
          firstChoiceFingerprint=node.firstChoiceFingerprint}
         extended.metrics=score(extended,index)
         nextFrontier[#nextFrontier+1]=extended
         levelUsed+=1
        end
       end
      elseif whyStep=="NONLINEAR_FIVE_PLUS_COPY_STACK_NOT_PRICED" then
       skipped.stack+=1
      elseif whyStep=="UNAPPROVED_LISTED_VALUE_LOSS" then
       skipped.loss+=1
      else skipped.other+=1 end
     end
    end
   end
  end
  stageStats[#stageStats+1]={futureLevel=level,
    hypotheticalAcceptedRoutesAtLevel=levelUsed,
    futureSellerActuallyObserved=false}
  nextFrontier=beamPick(nextFrontier)
  if #nextFrontier==0 then break end
  for _,x in ipairs(nextFrontier) do terminal[#terminal+1]=x end
  frontier=nextFrontier
 end
 if #terminal<2 then
  return denied("ABSTAIN","TWO_DISTINCT_MULTI_STEP_FEASIBLE_ROUTES_NOT_FOUND") end
 table.sort(terminal,better)
 local seenRoute,results={},{}
 for _,p in ipairs(terminal) do
  if not seenRoute[p.pathKey] then
   seenRoute[p.pathKey]=true
   local q=p.metrics
   results[#results+1]={
    index=#results+1,routeLength=#p.steps,
    distinctFirstStepSignature=p.firstChoiceFingerprint,
    paperTargetHypotheticallyHeld=(p.holdings[TARGET] or 0)>0,
    typeSequence=(function()
     local ty={}
     for _,step in ipairs(p.steps) do ty[#ty+1]=step.kind end
     return ty
    end)(),
    comparisonMetrics=q,
    steps=details(p.steps),
    sourceEdition=market.marketEdition,
    futureSellerStocksIndependentlyObserved=false,
    originalMM2LivePass=false,
    validAsActualProposal=false,
    partnerWillingnessProven=false,
    authorizesOffer=false,
   }
   if #results>=6 then break end
  end
 end
 local firstSet={}
 for _,route in ipairs(results) do firstSet[route.distinctFirstStepSignature]=true end
 local distinctFirst=0
 for _ in pairs(firstSet) do distinctFirst+=1 end
 if #results<2 or distinctFirst<2 then
  return denied("ABSTAIN","NO_TWO_INDEPENDENT_FIRST_STEP_PATH_HYPOTHESES") end
 return {
  schema=SCHEMA,
  status="RESEARCH_GROWTH_ROUTE_DISCOVERY_ONLY",
  reason="CURRENT_OFFER_FIRST_STEP_PLUS_HYPOTHETICAL_UNVERIFIED_SELLERS",
  marketEdition=market.marketEdition,
  marketRowsSha256=market.crosswalkRowsSha256,
  clientOfferRevision=context.clientOfferRevision,
  initialClientOfferDecisionStatus=check.status,
  firstOptionsCompared=#options,
  firstOptionsFromActualClientOfferedStock=true,
  boundedOwnShortlistNotGloballyExhaustive=notExhaustive,
  futureSellerStageCount=#stagePools,
  futureStages=stageStats,
  paperRoutesConsidered=#terminal,
  distinctFirstStepRoutesDisplayed=distinctFirst,
  searchPairEvaluations=comparisons,
  rejectedListedLossPairs=skipped.loss,
  rejectedUnverifiedStackPairs=skipped.stack,
  selectedResearchRouteIndex=1,
  selectedRouteActionable=false,
  alternativeRoutes=results,
  targetListedValue= index[TARGET].mm2Listed,
  futureSellerAvailabilityVerified=false,
  anyPartnerWillingnessVerified=false,
  futureTradesExecuted=false,
  originalMM2LivePass=false,
  marketLiquidityMeasured=false,
  clientOnly=true,readOnly=true,
  verifiedProfit=false,
  authorizesTrade=false,authorizesOffer=false,
  authorizesAccept=false,mayReportProfit=false,
  maySendDiscordWebhook=false,mayUseForStrategyLearning=false}
end
return M
