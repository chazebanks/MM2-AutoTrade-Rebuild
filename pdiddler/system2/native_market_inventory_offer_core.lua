-- S2.3 native read-only market/own inventory/offer witness integration.
-- Uses actual scanner.getOwnInventory() and a real client trade-window reader.
-- Source market keys are Stage83-derived candidates; never server instance proof.
-- No offer placement, trade requests, Accept, declines, teleport or webhooks.
local M={}
local MAX_ROWS=189
local MAX_AGE=21600 -- 6 hours since actual market-source retrieval
local MAX_OWN_AGE=30 -- require refresh of own census before each offer
local MAX_COPIES=1000000
local function validKey(k)
 return type(k)=="string" and #k>=1 and #k<=90 and
  k:match("^[A-Za-z0-9_]+$")~=nil
end
local function natural(n,allowZero)
 return type(n)=="number" and n==n and n~=math.huge and
  n==math.floor(n) and n>=(allowZero and 0 or 1) and n<=MAX_COPIES
end
local function canonical(s)
 if type(s)~="string" or #s<1 or #s>160 then return nil end
 local r=s:lower():gsub("[^%w]","")
 return #r>0 and r or nil
end
local function normalized(s,chromatic)
 local r=canonical(s)
 if chromatic and r and r:sub(1,6)=="chroma" then r=r:sub(7) end
 return r
end
local function fail(reason)
 return {status="BLOCKED",reason=reason,readOnly=true,clientOnly=true,
  itemInstancesVerified=false,serverOfferRevisionProven=false,
  serverCompletionProven=false,authorizesTrade=false,authorizesOffer=false,
  authorizesAccept=false,mayReportProfit=false,mayUseForStrategyLearning=false}
end
local function allowedTime(sec)
 return type(sec)=="number" and sec==sec and sec>1700000000 and
  sec<4102444800 and sec==math.floor(sec)
end
local function marketIndex(c)
 if type(c)~="table" or c.schema~="gingerscope-system2-exact-market-gamekey-crosswalk-v1"
  or c.status~="EXACT_HISTORICAL_GAMEKEY_MARKET_CROSSWALK"
  or c.matchedHistoricalGameKeys~=189 or type(c.items)~="table"
  or #c.items~=189 or c.actualGameIdentityRevalidatedNow~=false
  or c.actualCurrentOwnedInventoryVerified~=false
  or c.authorizesTrade~=false or c.authorizesAccept~=false
  or c.mayUseForLiveOffer~=false or c.historicalRegistryBlob~="40e2a0ff01b70b2d0181c62cae347a08da82bcb8"
  or type(c.crosswalkRowsSha256)~="string" or #c.crosswalkRowsSha256~=64
  then return nil,"SOURCE_CROSSWALK_CONTRACT_INVALID" end
 local byKey,byMarket={},{}
 local total=0
 local counts={ancient=0,godly=0,chroma=0}
 for _,row in ipairs(c.items) do
  total+=1
  if total>MAX_ROWS or type(row)~="table" or not validKey(row.rawGameKeyCandidate)
   or type(row.marketSlug)~="string" or #row.marketSlug<1
   or not counts[row.marketCategory]
   or (row.gameItemType~="Knife" and row.gameItemType~="Gun")
   or (row.gameRarity~="Ancient" and row.gameRarity~="Godly")
   or type(row.gameChroma)~="boolean" or
     row.gameChroma~=(row.marketCategory=="chroma")
   or type(row.expectedGameName)~="string"
   or type(row.outgoingGingerscopeProtected)~="boolean"
   or row.exactGameInstanceProven~=false
   or not natural(row.mm2Listed) and row.mm2Listed~=nil
   or not natural(row.supremeListed) and row.supremeListed~=nil
   or (row.mm2Listed==nil and row.supremeListed==nil)
   or byKey[row.rawGameKeyCandidate] or byMarket[row.marketCategory..":"..row.marketSlug]
   then return nil,"SOURCE_CROSSWALK_ROW_INVALID" end
  if row.rawGameKeyCandidate=="Gingerscope" and
   (row.outgoingGingerscopeProtected~=true or
    row.gameChroma~=false or row.gameRarity~="Ancient" or
    row.gameItemType~="Gun") then return nil,"SOURCE_TARGET_PROTECTION_INVALID" end
  if row.rawGameKeyCandidate~="Gingerscope" and row.outgoingGingerscopeProtected then
   return nil,"SOURCE_UNEXPECTED_PROTECTION" end
  counts[row.marketCategory]+=1
  byKey[row.rawGameKeyCandidate]=row
  byMarket[row.marketCategory..":"..row.marketSlug]=true
 end
 if total~=189 or counts.ancient~=15 or counts.godly~=128 or counts.chroma~=46 or
    type(c.categoryGameKeys)~="table" or byKey.Gingerscope==nil or
    c.categoryGameKeys.ancient~=15 or c.categoryGameKeys.godly~=128 or
    c.categoryGameKeys.chroma~=46 then
  return nil,"SOURCE_CROSSWALK_COVERAGE_INVALID"
 end
 return byKey,nil
end
local function findMeta(sync,key)
 if type(sync)~="table" then return nil,"CLIENT_SYNC_UNAVAILABLE" end
 local w=type(sync.Weapons)=="table" and sync.Weapons[key] or nil
 local i=type(sync.Item)=="table" and sync.Item[key] or nil
 if w==nil and i==nil then return nil,"CLIENT_RAW_KEY_ABSENT" end
 if (w and type(w)~="table") or (i and type(i)~="table") then
  return nil,"CLIENT_GAME_META_MALFORMED" end
 if w and i then
  for _,field in ipairs({"ItemName","Name","ItemType","Rarity","Chroma","Tradable",
     "CanTrade","NonTradable","Untradable","EvoBaseID","EvoIndex"}) do
   if w[field]~=i[field] then return nil,"CLIENT_META_SOURCES_CONFLICT" end
  end
 end
 return w or i,nil
end
local function validMeta(sync,key,row)
 local d,why=findMeta(sync,key)
 if not d then return false,why end
 local name=d.ItemName or d.Name
 if (not normalized(name,row.gameChroma) or
     normalized(name,row.gameChroma)~=normalized(row.expectedGameName,false)
     or d.ItemType~=row.gameItemType or d.Rarity~=row.gameRarity
     or (d.Chroma==true)~=row.gameChroma
     or d.Tradable==false or d.CanTrade==false or
     d.NonTradable==true or d.Untradable==true or
     d.EvoIndex~=nil or d.EvoBaseID~=nil) then
  return false,"CLIENT_GAME_META_IDENTITY_OR_ELIGIBILITY_CHANGED"
 end
 return true,nil
end
local function parseAmount(s)
 if type(s)~="string" or #s>20 then return nil end
 if s=="" then return 1 end -- original Stage9: empty Amount node means x1
 s=s:gsub("^%s+",""):gsub("%s+$","")
 s=s:gsub("^[xX]%s*","")
 if s:sub(1,#"×")=="×" then s=s:sub(#"×"+1):gsub("^%s+","") end
 if #s==0 or #s>7 or not s:match("^%d+$") then return nil end
 local q=tonumber(s)
 return natural(q) and q or nil
end
local function side(slots,byKey,sync,isOwn,own,resolver,catalog)
 if type(slots)~="table" or #slots>4 then return nil,"PHYSICAL_SLOT_COUNT_INVALID" end
 local out,seenSlots,seenKeys={}, {}, {}
 local mm2,supreme=0,0
 local hasSupreme=true
 local namesOnly=0
 for _,x in ipairs(slots) do
  if type(x)~="table" or not natural(x.slot) or x.slot>4 or seenSlots[x.slot]
   or (x.rawId~=nil and not validKey(x.rawId))
   or type(x.label)~="string" or type(x.chromaTag)~="boolean" then
   return nil,"SLOT_INDEX_OR_EXACT_RAW_ID_INVALID" end
  seenSlots[x.slot]=true
  local id,qty,clientClass=x.rawId,parseAmount(x.amountText),"EXACT_RAW_ATTRIBUTE_CLIENT"
  if not qty then return nil,"OFFER_STACK_QUANTITY_UNVERIFIED" end
  if id==nil then
   if type(resolver)~="table" or type(resolver.resolve)~="function" or
     type(catalog)~="table" then return nil,"GUI_RAW_KEY_ABSENT_NO_BOUND_CATALOG" end
   local keyCandidate,parsedQty,reason=resolver.resolve(catalog,
     {label=x.label,amountText=x.amountText,chromaTag=x.chromaTag,rawAttrs={}},
     parseAmount)
   if not keyCandidate then return nil,"NAME_CANDIDATE_"..tostring(reason) end
   if parsedQty~=qty then return nil,"NAME_CANDIDATE_QUANTITY_CONFLICT" end
   id=keyCandidate
   namesOnly+=1
   clientClass="UNVERIFIED_NAME_ONLY_GAME_CATALOG_CANDIDATE"
  elseif x.rawIdObserved~=true then
   return nil,"RAW_ATTRIBUTE_EVIDENCE_FLAG_ABSENT"
  end
  local r=byKey[id]
  if not r then return nil,"OFFERED_WEAPON_NOT_IN_CURRENT_CROSSWALK" end
  local labelShowsChroma=type(x.label)=="string" and
    x.label:lower():match("^%s*chroma%s+")~=nil
  local variantSeen=x.chromaTag or labelShowsChroma
  if (r.gameChroma~=variantSeen or
      normalized(x.label,r.gameChroma)~=normalized(r.expectedGameName,false)) then
   return nil,"OFFER_RAW_KEY_LABEL_OR_CHROMA_CONFLICT" end
  local ok,why=validMeta(sync,id,r)
  if not ok then return nil,why end
  if seenKeys[id] then return nil,"DUPLICATE_RAW_KEY_IN_PHYSICAL_SLOTS" end
  seenKeys[id]=true
  if isOwn and (r.outgoingGingerscopeProtected or not own[id] or
      qty>own[id]) then return nil,"OUTGOING_TARGET_OR_QUANTITY_INVALID" end
  mm2+=qty*(r.mm2Listed or 0)
  if r.supremeListed then supreme+=qty*r.supremeListed else hasSupreme=false end
  out[#out+1]={slot=x.slot,id=id,quantity=qty,clientIdentityEvidence=clientClass}
 end
 table.sort(out,function(a,b)return a.slot<b.slot end)
 return {items=out,mm2Listed=mm2,
   supremeListed=hasSupreme and supreme or nil,physicalSlots=#out,
   clientNameOnlyCandidates=namesOnly,
   allRawAttributesObserved=namesOnly==0},nil
end
local function signature(a,b)
 local x={}
 for _,z in ipairs({a,b}) do
  for _,item in ipairs(z.items) do
   x[#x+1]=tostring(item.slot)..":"..item.id..":"..tostring(item.quantity)
  end
  x[#x+1]="|"
 end
 return table.concat(x,";")
end
function M.new(deps)
 if type(deps)~="table" or type(deps.scannerApi)~="table"
  or type(deps.scannerApi.getOwnInventory)~="function"
  or type(deps.captureOffer)~="function" or type(deps.sync)~="table"
  or type(deps.utcNow)~="function" or type(deps.monoNow)~="function"
  or type(deps.jobId)~="string" or #deps.jobId<8
  or type(deps.leaseId)~="string" or #deps.leaseId<8
  or type(deps.partnerUserId)~="number" or
   deps.partnerUserId~=math.floor(deps.partnerUserId) or deps.partnerUserId<=0
  then return nil,"NATIVE_BRIDGE_DEPENDENCIES_INVALID" end
 local idx,why=marketIndex(deps.crosswalk)
 if not idx then return nil,why end
 local catalog=nil
 if deps.nameResolver~=nil then
  if type(deps.nameResolver)~="table" or
   type(deps.nameResolver.buildCatalog)~="function" or
   type(deps.nameResolver.resolve)~="function" then
   return nil,"NAME_CANDIDATE_RESOLVER_INVALID" end
  local catalogWhy
  catalog,catalogWhy=deps.nameResolver.buildCatalog(deps.sync)
  if not catalog then return nil,catalogWhy end
 end
 local obj={own=nil,ownAt=nil,lastSignature=nil,revision=0,
    market=deps.crosswalk,byKey=idx,jobId=deps.jobId,leaseId=deps.leaseId}
 function obj:checkClock()
  local ok,at=pcall(deps.utcNow)
  if not ok or not allowedTime(at) or not allowedTime(deps.sourceRetrievedEpoch)
   or at<deps.sourceRetrievedEpoch or at-deps.sourceRetrievedEpoch>MAX_AGE then
   return nil,"SOURCE_CROSSWALK_EXPIRED_OR_UNVERIFIED"
  end
  return at,nil
 end
 function obj:refreshOwn()
  local utc,err=self:checkClock()
  if not utc then return fail(err) end
  local start=deps.monoNow()
  local ok,inventory,why=pcall(deps.scannerApi.getOwnInventory)
  local ended=deps.monoNow()
  if not ok or inventory==nil then return fail("SCANNER_GET_OWN_INVENTORY_FAILED") end
  if type(start)~="number" or start~=start or start==math.huge or start<0 then
   return fail("OWN_CENSUS_CLOCK_INVALID") end
  if type(ended)~="number" or ended<start or ended-start>10 then
   return fail("OWN_CENSUS_TOO_SLOW_OR_CLOCK_INVALID") end
  if (type(inventory)~="table" or type(inventory.items)~="table"
     or type(inventory.seen)~="table" or inventory.unmapped~=0
     or inventory.badQty~=0 or type(inventory.fingerprint)~="string"
     or type(inventory.rawOwned)~="number") then
   return fail("SCANNER_OWN_CENSUS_MALFORMED") end
  -- Existing scanner.total, scanner.value, checkerId are STALE Oct31: ignore.
  local all,sum,rawCounts={},0,{}
  for _,s in ipairs(inventory.seen) do
   if type(s)~="string" then return fail("OWN_RAW_FINGERPRINT_INVALID") end
   all[#all+1]=s
   local id,q=s:match("^(.-)x(%d+)$")
   local n=tonumber(q)
   if not validKey(id) or not natural(n) then return fail("OWN_RAW_FINGERPRINT_INVALID") end
   if rawCounts[id]~=nil then return fail("DUPLICATE_RAW_IN_OWN_FINGERPRINT") end
   rawCounts[id]=n
   sum+=n
  end
  table.sort(all)
  if table.concat(all,"|")~=inventory.fingerprint or sum~=inventory.rawOwned then
   return fail("OWN_RAW_CENSUS_FINGERPRINT_MISMATCH") end
  local owned,listed,pricesHaveFullSupreme,supreme,keys,copies={},0,true,0,0,0
  for _,it in ipairs(inventory.items) do
   if type(it)~="table" or not validKey(it.id) or not natural(it.qty) or
      it.cat~="Weapons" or type(it.name)~="string" or owned[it.id] then
    return fail("ELIGIBLE_SCANNER_ROW_INVALID") end
   local row=self.byKey[it.id]
   if not row then return fail("OWN_ELIGIBLE_KEY_NOT_IN_CURRENT_MARKET") end
   local page=row.marketCategory
   if it.page~=page or it.type~=row.gameItemType or
      normalized(it.name,row.gameChroma)~=normalized(row.expectedGameName,false) then
    return fail("OWN_SCANNER_NAME_RARITY_OR_CHROMA_CONFLICT") end
   local okMeta,whyMeta=validMeta(deps.sync,it.id,row)
   if not okMeta then return fail(whyMeta) end
   -- A matching scanner row must appear in the all-owned raw fingerprint.
   local lookup=it.id.."x"..tostring(it.qty)
   local matched=false
   for _,v in ipairs(all) do if v==lookup then matched=true;break end end
   if not matched then return fail("OWN_SCANNER_QUANTITY_NOT_IN_RAW_CENSUS") end
   owned[it.id]=it.qty
   keys+=1;copies+=it.qty
   listed+=it.qty*(row.mm2Listed or 0)
   if row.supremeListed then supreme+=it.qty*row.supremeListed else pricesHaveFullSupreme=false end
  end
  -- Reconcile the other direction: no eligible raw key in the actual
  -- all-owned fingerprint may be silently omitted by scanner.items.
  for rawId,qty in pairs(rawCounts) do
   local sourceMeta,metaWhy=findMeta(deps.sync,rawId)
   if not sourceMeta then return fail(metaWhy) end
   local eligible=sourceMeta.ItemType=="Gun" or sourceMeta.ItemType=="Knife"
   eligible=eligible and
     (sourceMeta.Rarity=="Ancient" or sourceMeta.Rarity=="Godly")
   eligible=eligible and sourceMeta.Tradable~=false and
     sourceMeta.CanTrade~=false and sourceMeta.Untradable~=true and
     sourceMeta.NonTradable~=true and sourceMeta.EvoIndex==nil and
     sourceMeta.EvoBaseID==nil
   if eligible then
    if not self.byKey[rawId] then
     return fail("NEW_OWN_ELIGIBLE_ITEM_MISSING_CURRENT_MARKET")
    end
    if owned[rawId]~=qty then return fail("SCANNER_ELIGIBLE_ROW_OMITTED") end
   elseif owned[rawId]~=nil then
    return fail("SCANNER_INCLUDED_UNTRADABLE_ROW")
   end
  end
  self.own=owned
  self.ownAt=ended
  self.lastSignature=nil
  self.revision=0
  return {status="READONLY_OWN_MARKET_BOUND",matchedEligibleKeys=keys,
    matchedEligibleCopies=copies,mm2ListedSubtotal=listed,
    supremeListedSubtotal=pricesHaveFullSupreme and supreme or nil,
    scannerLegacyPriceIgnored=true,clientOnly=true,readOnly=true,
    authorizesOffer=false,authorizesAccept=false,
    currentMarketObserved=true,
    serverInventoryAuthoritative=false}
 end
 function obj:observe()
  local utc,err=self:checkClock()
  if not utc then return fail(err) end
  local now=deps.monoNow()
  if not self.own or type(now)~="number" or
   type(self.ownAt)~="number" or now<self.ownAt or now-self.ownAt>MAX_OWN_AGE then
   return fail("OWN_CENSUS_EXPIRED_REFRESH_REQUIRED") end
  local ok,frame=pcall(deps.captureOffer)
  if not ok or type(frame)~="table" then
   return fail("ORIGINAL_GAME_GUI_CAPTURE_UNAVAILABLE") end
  if frame.status=="BLOCKED" and type(frame.reason)=="string" then
   return fail("GUI_CAPTURE_"..frame.reason)
  end
  if frame.clientOnly~=true or frame.tradeOpen~=true or
      frame.jobId~=deps.jobId or frame.tradeLeaseId~=deps.leaseId or
      frame.partnerUserId~=deps.partnerUserId or
      frame.contextOK~=true or frame.rootBound~=true or
      frame.doubleReadStable~=true or type(frame.ourAccepted)~="boolean" or
      type(frame.theirAccepted)~="boolean" then
   return fail("OFFER_SESSION_PARTNER_OR_ROOT_UNVERIFIED") end
  local our,whyOur=side(frame.ourSlots,self.byKey,deps.sync,true,self.own,deps.nameResolver,catalog)
  if not our then return fail("OUR_"..whyOur) end
  local their,whyTheir=side(frame.theirSlots,self.byKey,deps.sync,false,self.own,deps.nameResolver,catalog)
  if not their then return fail("THEIR_"..whyTheir) end
  local sig=signature(our,their)..";accept:"..tostring(frame.ourAccepted)..":"..tostring(frame.theirAccepted)..";gui:"..tostring(frame.clientRawCaptureSignature)
  local changed=self.lastSignature~=nil and sig~=self.lastSignature
  if self.lastSignature~=sig then self.revision+=1;self.lastSignature=sig end
  return {status=changed and "CLIENT_OFFER_CHANGED_PREVIEW_INVALIDATED"
    or "CLIENT_OFFER_OBSERVATION_READONLY",
    clientRevision=self.revision,priorPreviewInvalidated=changed,
    ourAccepted=frame.ourAccepted,theirAccepted=frame.theirAccepted,
    our=our,their=their,
    mm2ListedDelta=their.mm2Listed-our.mm2Listed,
    supremeListedDelta=our.supremeListed~=nil and
      their.supremeListed~=nil and their.supremeListed-our.supremeListed or nil,
    ownedCensusAgeSeconds=now-self.ownAt,
    sourceAgeSeconds=utc-deps.sourceRetrievedEpoch,
    clientOnly=true,readOnly=true,offerObservedViaClientGUI=true,
    serverOfferRevisionProven=false,serverCompletionProven=false,
    counterpartyInventoryProven=false,marketLiquidityMeasured=false,
    exactRawAttributesBothSidesObserved=our.allRawAttributesObserved and their.allRawAttributesObserved,
    nameOnlyCatalogCandidateCount=our.clientNameOnlyCandidates+their.clientNameOnlyCandidates,
    verifiedGameItemInstances=false,
    authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
    mayReportProfit=false,mayUseForStrategyLearning=false,
    tradeOutcome="UNKNOWN"}
 end
 -- Local-only handoff. This contains PRIVATE owner holdings and must NEVER
 -- be sent to Discord, GitHub logs/artifacts, or stored in a public repo.
 function obj:researchContext()
  local offer=self:observe()
  if type(offer)~="table" or (offer.status~="CLIENT_OFFER_OBSERVATION_READONLY" and
      offer.status~="CLIENT_OFFER_CHANGED_PREVIEW_INVALIDATED") then
   return fail("FRESH_CLIENT_OFFER_REQUIRED")
  end
  if type(self.own)~="table" or type(self.ownAt)~="number" then
   return fail("FRESH_OWN_CENSUS_REQUIRED")
  end
  local copy={}
  for id,qty in pairs(self.own) do copy[id]=qty end
  return {schema="gingerscope-system2-local-bilateral-context-v1",
   status="LOCAL_READONLY_MARKET_OFFER_CONTEXT",
   ownCounts=copy,offer=offer,
   crosswalkRowsSha256=self.market.crosswalkRowsSha256,
   sourceRetrievedUtc=self.market.sourceRetrievedUtc,
   clientOnly=true,readOnly=true,clientOfferRevision=offer.clientRevision,
   marketSourceVerifiedForLiveTrade=false,
   counterpartyWillingnessVerified=false,serverTradeRevisionProven=false,
   authorizesOffer=false,authorizesAccept=false,mayReportProfit=false}
 end
 return obj,nil
end
return M
