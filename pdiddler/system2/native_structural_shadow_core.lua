-- System2 new read-only structural planning layer. Values/demand intentionally absent.
-- Calls the earlier frozen 189-key client auditor in the SAME local observation.
-- No output contains raw owned keys, target possession, prices, partners or JobId.
local M={}
local SCHEMA="gingerscope-system2-structural-shadow-batch-v1"
local FALSE={
 readOnly=true,clientOnly=true,simulationOnly=true,
 verifiedCurrentMarketPrice=false,publisherEditionAuthenticated=false,
 clientObservationServerAuthenticated=false,serverTradeRevisionProven=false,
 serverCompletionProven=false,measuredLiquidityVerified=false,
 partnerAppealVerified=false,physicalOfferExecutionProven=false,
 approvedLossBudget=false,unattendedOperationAuthorized=false,
 authorizesOffer=false,authorizesTrade=false,authorizesAccept=false,
 mayUseForStrategyLearning=false,mayReportProfit=false,
 maySendDiscordWebhook=false,tradeOutcome="UNKNOWN",
 actualOffers=0,actualAccepts=0,actualDeclines=0,actualTeleports=0,
 rawIdsExported=false,rawOwnedInventoryExported=false,
 protectedTargetOwnershipRevealed=false,sourcePricesExported=false,
}
local function out(status,why,features)
 local r={schema=SCHEMA,status=status,reason=why}
 for k,v in pairs(FALSE) do r[k]=v end
 if features then r.features=features end
 return r
end
local function natural(q)
 if type(q)=="number" and q==q and q>=0 and q<=1000000 and q==math.floor(q) then return q end
 if type(q)=="string" and #q<=7 and q:match("^%d+$") then
  local n=tonumber(q)
  if n and n<=1000000 then return n end
 end
 return nil
end
local function rawKey(k)
 return type(k)=="string" and #k>=1 and #k<=90 and k:match("^[A-Za-z0-9_]+$")~=nil
end
local function ownTable(p,depth)
 if type(p)~="table" or depth>4 then return nil end
 if type(p.Weapons)=="table" and type(p.Weapons.Owned)=="table" then return p.Weapons.Owned end
 for _,name in ipairs({"ProfileData","Profile","PlayerData","Data","Inventory","FullInventory"}) do
  local got=ownTable(p[name],depth+1)
  if got then return got end
 end
 return nil
end
local function metadata(sync,key)
 if type(sync)~="table" then return nil end
 local a=type(sync.Weapons)=="table" and sync.Weapons[key] or nil
 local b=type(sync.Item)=="table" and sync.Item[key] or nil
 if a==nil and b==nil then return nil end
 if (a~=nil and type(a)~="table") or (b~=nil and type(b)~="table") then return nil end
 if a and b and a~=b then
  for _,k in ipairs({"Name","ItemName","ItemType","Rarity","Chroma","Tradable",
                       "CanTrade","Untradable","NonTradable","EvoBaseID","EvoIndex"}) do
   if a[k]~=b[k] then return nil end
  end
 end
 return a or b
end
local function eligible(meta)
 if type(meta)~="table" then return false end
 local name=meta.ItemName or meta.Name
 local kind=meta.ItemType
 local rarity=meta.Rarity
 if type(name)~="string" or name=="" or name=="???" or
    type(kind)~="string" or type(rarity)~="string" or
    (meta.Chroma~=nil and type(meta.Chroma)~="boolean") or
    meta.EvoBaseID~=nil or meta.EvoIndex~=nil or meta.Tradable==false or
    meta.CanTrade==false or meta.Untradable==true or
    meta.NonTradable==true then return false end
 kind=kind:lower();rarity=rarity:lower()
 return (kind=="gun" or kind=="knife") and (rarity=="godly" or rarity=="ancient")
end
local function verifyAudit(a)
 if type(a)~="table" or
  a.schema~="gingerscope-system2-native-key-reconciliation-batch-v1" or
  a.status~="CLIENT_KEY_RECONCILIATION_BATCH" or
  a.readOnly~=true or a.clientOnly~=true or a.authorizesTrade~=false or
  a.authorizesOffer~=false or a.authorizesAccept~=false or
  a.currentMarketPriceAuthenticated~=false or a.publisherEditionBound~=false or
  a.actualOffers~=0 or a.actualAccepts~=0 or a.actualDeclines~=0 or
  a.actualTeleports~=0 or a.rawInventoryExported~=false or
  type(a.features)~="table" or
  type(a.features.ownedKeyMapping)~="table" or
  a.features.ownedKeyMapping.status~="HISTORICAL_KEY_CANDIDATES_MATCH_CLIENT_META" or
  a.features.ownedKeyMapping.keysOutsideHistoricalRegistry~=0 or
  a.features.ownedKeyMapping.structuralMismatchKeys~=0 or
  a.features.ownedKeyMapping.gameLabelDriftKeys~=0 or
  a.features.ownedKeyMapping.ownedUnresolvedMetaKeys~=0 or
  type(a.features.currentGameCatalog)~="table" or
  a.features.currentGameCatalog.status~="HISTORICAL_REGISTRY_CLIENT_META_PARITY" then
  return false
 end
 return true
end
local function fixture(slotsOut,slotsIn,mark)
 if type(slotsOut)~="table" or type(slotsIn)~="table" then return "BLOCKED" end
 if #slotsOut>4 or #slotsIn>4 or #slotsOut<1 or #slotsIn<1 then return "FOUR_SLOT_INVALID" end
 local seenOut,seenIn={},{},0
 local valueOut,valueIn=0,0
 local hasNonlinear=false
 for _,side in ipairs({{slotsOut,seenOut},{slotsIn,seenIn}}) do
  for _,r in ipairs(side[1]) do
   if type(r)~="table" or type(r.id)~="string" or #r.id<1 or
      type(r.qty)~="number" or r.qty~=math.floor(r.qty) or
      r.qty<1 or r.qty>10000 or type(r.val)~="number" or
      r.val~=r.val or r.val<=0 or r.val>1000000 or
      side[2][r.id] then return "INVALID_SYNTHETIC_SLOT" end
   side[2][r.id]=true
   if side[1]==slotsOut and r.id=="Gingerscope" then return "TARGET_PROTECTED" end
   if r.qty>=5 and r.val>1 then hasNonlinear=true end
   if side[1]==slotsOut then valueOut+=r.qty*r.val else valueIn+=r.qty*r.val end
  end
 end
 if valueIn<valueOut then return "UNAPPROVED_LOSS" end
 if hasNonlinear then return "STACK_PRICE_UNVERIFIED" end
 local shape=#slotsIn<#slotsOut and "UPGRADE" or
             (#slotsIn>#slotsOut and "DOWNGRADE" or "SIDEGRADE")
 return shape
end
function M.syntheticTests()
 local a={id="SYNTH_A",qty=1,val=100}
 local b={id="SYNTH_B",qty=1,val=100}
 local c={id="SYNTH_C",qty=1,val=205}
 local d={id="SYNTH_D",qty=1,val=102}
 local e={id="SYNTH_E",qty=1,val=104}
 local tests={
  upgrade=fixture({a,b},{c}),
  downgrade=fixture({c},{a,b}),
  sidegrade=fixture({a},{d}),
  loss=fixture({c},{a}),
  fiveSlot=fixture({a,b,c,d,e},{c}),
  duplicate=fixture({a,a},{c}),
  targetOutgoing=fixture({{id="Gingerscope",qty=1,val=1}},{c}),
  nonlinearStack=fixture({a},{{id="SYNTH_F",qty=5,val=30}}),
 }
 local expected={
  upgrade="UPGRADE",downgrade="UNAPPROVED_LOSS",
  sidegrade="SIDEGRADE",loss="UNAPPROVED_LOSS",
  fiveSlot="FOUR_SLOT_INVALID",duplicate="INVALID_SYNTHETIC_SLOT",
  targetOutgoing="TARGET_PROTECTED",nonlinearStack="STACK_PRICE_UNVERIFIED",
 }
 -- A downgrade with outgoing value 205 and two incoming 200 is a loss:
 -- it MUST be blocked, not re-labeled as a profitable downgrade.
 local passed=0
 for k,value in pairs(tests) do
  if value~=expected[k] then return {status="BLOCKED_SYNTHETIC_REGRESSION",failedCase=k} end
  passed+=1
 end
 return {status="PURE_SYNTHETIC_SCENARIOS_PASSED",cases=passed,
         upgradesAndDowngradesAreNotTradeRecommendations=true,
         estimatedAcceptanceProbabilityAvailable=false}
end
function M.assess(profile,sync,registry,jobId,started,ended,audit)
 if type(jobId)~="string" or #jobId<8 or #jobId>100 or
  not jobId:match("^[A-Za-z0-9_-]+$") or
  type(started)~="number" or type(ended)~="number" or
  started~=started or ended~=ended or started<0 or ended<started or
  ended-started>15 then
   return out("BLOCKED","LOCAL_SESSION_OR_READ_WINDOW_INVALID")
 end
 if not verifyAudit(audit) then return out("BLOCKED","PRIOR_NATIVE_KEY_AUDIT_INCOMPLETE_OR_MUTATED") end
 if type(registry)~="table" or
   registry.schema~="gingerscope-stage83-public-slug-registry-v1" or
   registry.publisherExpiryUtc~="2026-11-09T15:56:07Z" or
   registry.currentPricesVerified~=false or
   registry.authorizesTrade~=false or registry.authorizesAccept~=false or
   type(registry.entries)~="table" then
  return out("BLOCKED","EXPIRED_REGISTRY_CONTRACT_CHANGED")
 end
 local owned=ownTable(profile,0)
 if not owned then return out("BLOCKED","OWNED_CLIENT_PROFILE_MISSING") end
 local distinct,copyCount=0,0
 local bucket={one=0,twoToFour=0,fiveOrMore=0}
 local nonTarget={}
 local allEligibleKeys,allEligibleCopies=0,0
 local inspectCount=0
 for k,v in pairs(owned) do
  inspectCount+=1
  if inspectCount>4000 then return out("BLOCKED","CENSUS_INPUT_TOO_LARGE") end
  if not rawKey(k) then return out("BLOCKED","RAW_OWNED_KEY_INVALID") end
  local qty=natural(v)
  if qty==nil then return out("BLOCKED","OWNED_STACK_QUANTITY_INVALID") end
  if qty>0 then
   distinct+=1;copyCount+=qty
   if copyCount>4000000 then return out("BLOCKED","COPY_COUNT_LIMIT") end
   local meta=metadata(sync,k)
   if meta and eligible(meta) then
    allEligibleKeys+=1;allEligibleCopies+=qty
    if k~="Gingerscope" then
     if type(registry.entries[k])~="table" then return out("BLOCKED","ELIGIBLE_KEY_NOT_IN_EXPIRED_PUBLIC_REGISTRY") end
     nonTarget[#nonTarget+1]=qty
     if qty==1 then bucket.one+=1
     elseif qty<=4 then bucket.twoToFour+=1
     else bucket.fiveOrMore+=1 end
    end
   end
  end
 end
 local om=audit.features.ownedKeyMapping
 if allEligibleKeys~=om.eligibleRawKeys or
    allEligibleCopies~=om.eligibleRawCopies then
  return out("BLOCKED","CENSUS_OR_ELIGIBILITY_CHANGED_INSIDE_SAME_READ")
 end
 table.sort(nonTarget,function(a,b)return a>b end)
 local fourCopies=0
 for i=1,math.min(4,#nonTarget) do fourCopies+=nonTarget[i] end
 local check=M.syntheticTests()
 if check.status~="PURE_SYNTHETIC_SCENARIOS_PASSED" then
  return out("BLOCKED","SYNTHETIC_SCENARIOS_FAILED")
 end
 local fourSlotReady=#nonTarget>=4
 return out("CLIENT_STRUCTURAL_SHADOW_REPORT",
   "OWNED_CLIENT_STRUCTURAL_CAPACITY_ONLY_HISTORICAL_PRICES_NOT_ADMISSIBLE",{
  physicalSlots={
   status="CLIENT_NONPRICE_LAYOUT_CAPACITY_OBSERVED",
   atLeastOneNonTargetSlot=#nonTarget>=1,
   atLeastTwoNonTargetSlots=#nonTarget>=2,
   atLeastThreeNonTargetSlots=#nonTarget>=3,
   atLeastFourNonTargetSlots=fourSlotReady,
   maximumSlotLimit=4,
   fourSlotTemplatesAreNotExecutableOffers=true,
   independentCounterpartyInterestVerified=false},
  stackConstraints={
   status="CLIENT_STACK_LAYOUT_CAPACITY_OBSERVED",
   singletonNonTargetKeys=bucket.one,
   nonTargetKeysWithTwoToFourCopies=bucket.twoToFour,
   nonTargetKeysWithFivePlusCopies=bucket.fiveOrMore,
   topFourKeyCopyCountUpperBound=fourCopies,
   nonlinearFivePlusRequiresIndependentPricing=bucket.fiveOrMore>0,
   aggregateDoesNotProveStackOfferControls=true},
  syntheticBilateralModels=check,
  protectedTarget={
   status="GIVERS_NEVER_INCLUDE_GINGERSCOPE",
   targetOwnershipRevealed=false,
   selectedRealOutgoingItems=0,
   mayOfferTarget=false},
  quoteProvenance={
   status="HISTORICAL_KEYS_ONLY_NO_CURRENT_PRICE",
   frozenRegistryExpired=true,
   liveValueDeltaCalculated=false,marketLiquidity="UNKNOWN",
   approvedValueLossBudget=false,allowsNegotiationOrExecution=false},
  freshness={
   status="PASS_LOCAL_SAME_READ_CONTEXT_ONLY",
   observationDurationSeconds=ended-started,
   serverBoundSessionOrRevisionProven=false,
   priorObservationMayBeReusedForOffer=false},
  integration={
   status="RESEARCH_ONLY_GATES_HELD",
   originalPlannerMutated=false,
   sharedIdentityProofAppliedOnlyToThisRead=true,
   readinessForLiveOffer=false,
   nextHardwareRequiredForPricing=false},
 })
end
return M
