-- System 2: new native SUPREME-ONLY read-only bilateral economics.
-- No dual publisher inputs, mixing, fallback, remotes, offer, Accept, or profit.
-- The original C3/P4 observation still requires separate native integration.
-- This is NOT a live deployable MM2/Delta trade strategy.
local M={}
local SCHEMA="gingerscope-system2-native-supreme-only-bilateral-research-v1"
local SOURCE_SCHEMA="gingerscope-system2-supreme-only-189-publisher-catalog-v3"
local SOURCE_SHA="958038a6b22c43e8d0359cb15e6704bc84253430"
local ORIGINAL_SUPREME_SHA="5f208d43e99f71231131a6aa83b51db42f5a997d"
local CAPTURE=1794951678
local MAX_AGE=21600
local SOURCE="SUPREME_ONLY"
local COUNT={ancient=15,godly=128,chroma=46}
local function num(n)
 return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end
local function validKey(k)
 return type(k)=="string" and #k>=1 and #k<=90 and
  k:match("^[A-Za-z0-9_]+$")~=nil
end
local function denied(reason)
 return {schema=SCHEMA,status="BLOCKED",reason=reason,
  valueSource=SOURCE,researchOnly=true,readOnly=true,clientOnly=true,
  realInventoryVerified=false,exactRawGameItemIdentityVerified=false,
  empiricalPartnerAcceptanceProbability=nil,
  empiricalRetradability="UNKNOWN",
  liveSourceAuthenticated=false,liveLossBudgetAuthorized=false,
  authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
  maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
  mayReportProfit=false}
end
local function validateSource(catalog,now,callerPin)
 if type(catalog)~="table" or
   catalog.schema~=SOURCE_SCHEMA or
   catalog.status~="SUPREME_ONLY_MEDIATED_PUBLIC_RESEARCH_NOT_LIVE" or
   catalog.valueSource~=SOURCE or
   catalog.sourceOrigin~="https://supremevalues.com/" or
   catalog.sourceTransport~="FIRECRAWL_MEDIATED_HTTPS_RESEARCH" or
   catalog.sourceCapturedUtc~="2026-11-17T21:41:18Z" or
   catalog.publisherUpdatedAt~="2026-11-15T11:59:41-05:00" or
   catalog.originalHistoricalCatalogGitBlob~=ORIGINAL_SUPREME_SHA or
   callerPin~=SOURCE_SHA or
   catalog.originalPublisherEditionUnchanged~=true or
   type(catalog.pageEvidence)~="table" or
   type(catalog.pageEvidence.home)~="table" or
   type(catalog.pageEvidence.ancient)~="table" or
   type(catalog.pageEvidence.godly)~="table" or
   type(catalog.pageEvidence.chroma)~="table" or
   catalog.sourceResearchOnly~=true or
   catalog.liveTradePricingAuthorized~=false or
   catalog.authorizesTrade~=false or
   catalog.authorizesOffer~=false or
   catalog.authorizesAccept~=false or
   catalog.mayUseForStrategyLearning~=false or
   catalog.mayReportProfit~=false or
   catalog.exactRobloxItemInstanceVerified~=false or
   catalog.publisherSigned~=false or
   type(catalog.rows)~="table" or #catalog.rows~=189 or
   not num(now) or now<CAPTURE or now>CAPTURE+MAX_AGE then
   return nil,"SUPREME_ONLY_SOURCE_MISSING_STALE_OR_WRONG_PUBLISHER" end
 local byKey,ids,counts={},{},{ancient=0,godly=0,chroma=0}
 for _,r in ipairs(catalog.rows) do
  if type(r)~="table" or not validKey(r.rawGameKeyCandidate) or
    byKey[r.rawGameKeyCandidate] or
    counts[r.category]==nil or
    type(r.officialName)~="string" or #r.officialName<1 or
    type(r.officialItemId)~="string" or #r.officialItemId<1 or
    not num(r.supremeListed) or r.supremeListed~=math.floor(r.supremeListed) or
    r.supremeListed<=0 or r.supremeListed>=10000000000 or
    not num(tonumber(r.supremeDemand)) or
    tonumber(r.supremeDemand)<0 or tonumber(r.supremeDemand)>11 or
    type(r.supremeStability)~="string" or
    #r.supremeStability<1 or #r.supremeStability>80 or
    r.outgoingGingerscopeProtected~=(r.rawGameKeyCandidate=="Gingerscope") then
   return nil,"SUPREME_ONLY_SOURCE_ROW_INVALID_NO_FALLBACK" end
  local scope=r.category..":"..r.officialItemId
  if ids[scope] then return nil,"SUPREME_ONLY_SOURCE_DUPLICATE_PUBLISHER_ID" end
  ids[scope]=true
  byKey[r.rawGameKeyCandidate]=r
  counts[r.category]+=1
 end
 for cat,quantity in pairs(COUNT) do
  if counts[cat]~=quantity or
     type(catalog.categories)~="table" or
     catalog.categories[cat]~=quantity then
    return nil,"SUPREME_ONLY_SOURCE_CATEGORY_CENSUS_MISMATCH" end
 end
 if byKey.Gingerscope==nil then
  return nil,"SUPREME_ONLY_GINGERSCOPE_TARGET_MISSING" end
 return byKey,nil
end
local function parseInventory(x,rows)
 if type(x)~="table" then return nil,"SUPREME_ONLY_OWNED_QUANTITIES_REQUIRED" end
 local count=0
 for id,n in pairs(x) do
  if not validKey(id) or rows[id]==nil or
     not num(n) or n~=math.floor(n) or n<1 or n>100000 then
   return nil,"SUPREME_ONLY_UNVERIFIED_OWNED_KEY_OR_STACK" end
  count+=1
 end
 if count==0 or count>189 then return nil,"SUPREME_ONLY_EMPTY_OWNERSHIP" end
 return x,nil
end
local function slots(arr,rows,side)
 if type(arr)~="table" or #arr<1 or #arr>4 then
  return nil,"SUPREME_ONLY_"..side.."_FOUR_PHYSICAL_SLOT_LIMIT" end
 local quantities={}
 for _,item in ipairs(arr) do
  if type(item)~="table" or
   type(item.id)~="string" or not validKey(item.id) or
   rows[item.id]==nil or quantities[item.id]~=nil or
   not num(item.quantity) or
   item.quantity~=math.floor(item.quantity) or
   item.quantity<1 or item.quantity>100000 then
   return nil,"SUPREME_ONLY_"..side.."_AMBIGUOUS_ITEM_OR_STACK" end
  for field in pairs(item) do
   if field~="id" and field~="quantity" then
    return nil,"SUPREME_ONLY_"..side.."_UNEXPECTED_PRICE_SOURCE" end
  end
  quantities[item.id]=item.quantity
 end
 return quantities,nil
end
local function total(group,rows)
 local sum=0
 for id,q in pairs(group) do sum+=rows[id].supremeListed*q end
 return sum
end
local function averageDemand(group,rows)
 local val=total(group,rows)
 if val==0 then return 0 end
 local weighted=0
 for id,q in pairs(group) do
  weighted+=rows[id].supremeListed*q*tonumber(rows[id].supremeDemand)
 end
 return weighted/val
end
local function concentration(group,rows)
 local highest=0
 local val=total(group,rows)
 if val==0 then return 0 end
 for id,q in pairs(group) do
  highest=math.max(highest,rows[id].supremeListed*q) end
 return math.floor(highest*10000/val)
end
-- Read-only source precheck before potentially invoking the ORIGINAL scanner RPC.
-- The caller's catalogPin is a research-side claim, NOT independent hash
-- verification on the live client. Do not promote this to publisher auth.
function M.sourceStatus(catalog,catalogPin,nowEpoch)
 local rows,why=validateSource(catalog,nowEpoch,catalogPin)
 if not rows then return denied(why) end
 return {schema=SCHEMA,status="SUPREME_ONLY_RESEARCH_SOURCE_CHECKED",
  valueSource=SOURCE,readOnly=true,clientOnly=true,researchOnly=true,
  publisherSignatureVerified=false,catalogBytesAuthenticatedOnClient=false,
  realInventoryVerified=false,authorizesTrade=false,
  authorizesOffer=false,authorizesAccept=false,
  mayUseForStrategyLearning=false,mayReportProfit=false}
end
function M.review(catalog,claimedCatalogSha,nowEpoch,owned,options)
 local rows,why=validateSource(catalog,nowEpoch,claimedCatalogSha)
 if not rows then return denied(why) end
 local own,err=parseInventory(owned,rows)
 if not own then return denied(err) end
 if type(options)~="table" or #options<1 or #options>12 then
  return denied("SUPREME_ONLY_ONE_TO_TWELVE_RESEARCH_OPTIONS_REQUIRED") end
 local seen,answers={},{}
 local portfolio=total(own,rows)
 for i,option in ipairs(options) do
  if type(option)~="table" or
    option.kind~="HYPOTHETICAL_RESEARCH_ONLY" or
    option.valueSource~=SOURCE then
   return denied("SUPREME_ONLY_NO_OTHER_VALUE_SOURCE") end
  for field in pairs(option) do
   if field~="kind" and field~="valueSource" and
      field~="give" and field~="receive" then
    return denied("SUPREME_ONLY_NO_OTHER_PRICE_COLUMNS") end
  end
  local give,gErr=slots(option.give,rows,"GIVE")
  local receive,rErr=slots(option.receive,rows,"RECEIVE")
  if not give or not receive then return denied(gErr or rErr) end
  if give.Gingerscope then return denied("SUPREME_ONLY_GINGERSCOPE_NEVER_OUTGOING") end
  local parts={}
  for k,q in pairs(give) do
   if (own[k] or 0)<q then return denied("SUPREME_ONLY_OWNED_COPY_SHORTFALL") end
   parts[#parts+1]="G:"..k..":"..q
  end
  for k,q in pairs(receive) do parts[#parts+1]="R:"..k..":"..q end
  table.sort(parts)
  local signature=table.concat(parts,"|")
  if seen[signature] then return denied("SUPREME_ONLY_DUPLICATE_ALTERNATIVE") end
  seen[signature]=true
  local after={}
  for k,q in pairs(own) do after[k]=q end
  for k,q in pairs(give) do
   after[k]-=q
   if after[k]==0 then after[k]=nil end
  end
  for k,q in pairs(receive) do
   after[k]=(after[k] or 0)+q
   if after[k]>100000 then return denied("SUPREME_ONLY_STACK_OVERFLOW") end
  end
  local ours=total(give,rows)
  local theirs=total(receive,rows)
  local delta=theirs-ours
  if total(after,rows)~=portfolio+delta then
   return denied("SUPREME_ONLY_SOURCE_VALUE_CONSERVATION_FAILED") end
  local stackRisk=false
  for _,group in ipairs({give,receive}) do
   for key,q in pairs(group) do
    if q>=5 and rows[key].supremeListed>1 then stackRisk=true end end
  end
  local cautious={}
  for key in pairs(receive) do
   local s=rows[key].supremeStability:lower():gsub("[^a-z]","")
   if s=="unsafe" or s=="decreasing" or
      s=="fluctuating" or s=="underpaidfor" then
    cautious[#cautious+1]=key end
  end
  table.sort(cautious)
  local status=delta<0 and "BLOCKED_UNAPPROVED_SUPREME_LOSS" or
     stackRisk and "BLOCKED_UNVERIFIED_STACK_PRICE" or
     "SUPREME_ONLY_PAPER_RESEARCH_NOT_EXECUTABLE"
  answers[#answers+1]={
   index=i,status=status,valueSource=SOURCE,
   incomingSupremeListedValue=theirs,
   outgoingSupremeListedValue=ours,
   supremeListedGain=delta,
   partnerSupremeListedGain=-delta,
   beforeSupremePortfolio=portfolio,
   hypotheticalAfterSupremePortfolio=total(after,rows),
   concentrationBeforeBasisPoints=concentration(own,rows),
   concentrationAfterBasisPoints=concentration(after,rows),
   demandIncoming=averageDemand(receive,rows),
   demandOutgoing=averageDemand(give,rows),
   incomingPublishedRiskKeys=cautious,
   unverifiedStackPrice=stackRisk,
   protectedGingerscopeNeverOutgoing=true,
   empiricalPartnerAcceptanceProbability=nil,
   empiricalRetradeLiquidity="UNKNOWN",
   tradeActionable=false,authorizesOffer=false,authorizesAccept=false,
   mayReportProfit=false}
 end
 return {
  schema=SCHEMA,status="SUPREME_ONLY_NATIVE_RESEARCH_NOT_EXECUTABLE",
  valueSource=SOURCE,researchOnly=true,readOnly=true,clientOnly=true,
  sourceCatalogGitBlob=SOURCE_SHA,
  sourceCaptureAgeSeconds=math.floor(nowEpoch-CAPTURE),
  reviewedHistoricalGameKeyCandidates=189,
  gingerscopeTargetSupremeValue=rows.Gingerscope.supremeListed,
  hypotheticalAlternatives=answers,
  exactRawGameItemIdentityVerified=false,realInventoryVerified=false,
  livePublisherAuthenticated=false,serverTradeSettlementProven=false,
  empiricalPartnerAcceptanceProbability=nil,empiricalRetradeLiquidity="UNKNOWN",
  authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
  maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
  mayReportProfit=false}
end
return M
