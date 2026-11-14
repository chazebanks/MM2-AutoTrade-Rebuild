-- System2 next multi-feature: historical publisher GAME-KEY candidate vs
-- live client catalog+own profile, never current values, offers or settlement.
-- Stage83 is a PUBLIC, EXPIRED, separately Git-blob pinned 189-row registry.
local M={}
local SCHEMA="gingerscope-system2-native-key-reconciliation-batch-v1"
local DENIED={
 readOnly=true,clientOnly=true,historicalRegistryOnly=true,
 currentMarketPriceAuthenticated=false,publisherEditionBound=false,
 gameItemInstanceProven=false,serverInventoryAuthoritative=false,
 observedTransferabilityProven=false,serverTradeRevisionProven=false,
 serverCompletionProven=false,marketLiquidityVerified=false,
 authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
 mayReportProfit=false,maySendDiscordWebhook=false,
 mayUseForStrategyLearning=false,tradeOutcome="UNKNOWN",
 actualOffers=0,actualAccepts=0,actualDeclines=0,actualTeleports=0,
 rawIdsExported=false,rawInventoryExported=false,jobIdExported=false,
 outgoingCandidateProduced=false,
}
local function report(status,reason,features)
 local t={schema=SCHEMA,status=status,reason=reason}
 for k,v in pairs(DENIED) do t[k]=v end
 if features then t.features=features end
 return t
end
local function validClock(n)
 return type(n)=="number" and n==n and n>=0 and n<math.huge
end
local function validKey(k)
 return type(k)=="string" and #k>=1 and #k<=90 and
     k:match("^[A-Za-z0-9_]+$")~=nil
end
local function parseQty(v)
 if type(v)=="number" and validClock(v) and v==math.floor(v) and v<=1000000 then
     return v
 end
 if type(v)=="string" and #v<=7 and v:match("^%d+$") then
     local q=tonumber(v)
     if q and q<=1000000 then return q end
 end
 return nil
end
local function ownedTable(p,depth)
 if type(p)~="table" or depth>4 then return nil end
 if type(p.Weapons)=="table" and type(p.Weapons.Owned)=="table" then
     return p.Weapons.Owned
 end
 for _,k in ipairs({"ProfileData","Profile","PlayerData","Data",
                    "Inventory","FullInventory"}) do
     local n=ownedTable(p[k],depth+1)
     if n then return n end
 end
 return nil
end
local function norm(s,chroma)
 if type(s)~="string" then return nil end
 s=s:lower():gsub("^%s+",""):gsub("%s+$",""):gsub("%s+"," ")
 if chroma and s:sub(1,7)=="chroma " then s=s:sub(8) end
 return s
end
local function registryValidate(r)
 if type(r)~="table" or r.schema~="gingerscope-stage83-public-slug-registry-v1" or
     r.publisherUtc~="2026-11-06T15:56:07Z" or
     r.publisherExpiryUtc~="2026-11-09T15:56:07Z" or
     r.currentPricesVerified~=false or r.authenticatedOwnedInventory~=false or
     r.authorizesTrade~=false or r.authorizesAccept~=false or
     r.mayUseForStrategyLearning~=false or type(r.entries)~="table" then
     return nil,"HISTORICAL_REGISTRY_MANIFEST_INVALID"
 end
 local n=0
 local c={ancient=0,godly=0,chroma=0}
 for key,row in pairs(r.entries) do
     n+=1
     if n>189 or not validKey(key) or type(row)~="table" or #row~=6 or
         type(row[1])~="string" or #row[1]<1 or #row[1]>128 or
         (row[2]~="Gun" and row[2]~="Knife") or
         (row[3]~="Godly" and row[3]~="Ancient") or
         type(row[4])~="boolean" or
         not c[row[5]] or
         type(row[6])~="string" or #row[6]<1 or #row[6]>100 or
         (row[4] and row[5]~="chroma") or
         ((not row[4]) and row[5]=="chroma") or
         (not row[4] and (row[5]~=(row[3]=="Ancient" and "ancient" or "godly"))) then
         return nil,"HISTORICAL_REGISTRY_ROW_INVALID"
     end
     c[row[5]]+=1
 end
 if n~=189 or c.ancient~=15 or c.godly~=128 or c.chroma~=46 or
     not r.entries.Gingerscope or r.entries.Gingerscope[2]~="Gun" or
     r.entries.Gingerscope[3]~="Ancient" or
     r.entries.Gingerscope[4]~=false then
     return nil,"HISTORICAL_REGISTRY_COVERAGE_INVALID"
 end
 return r.entries,nil
end
local function getMeta(sync,key)
 if type(sync)~="table" then return nil,"SYNC_ABSENT" end
 local a=type(sync.Weapons)=="table" and sync.Weapons[key] or nil
 local b=type(sync.Item)=="table" and sync.Item[key] or nil
 if a==nil and b==nil then return nil,"KEY_ABSENT" end
 if (a~=nil and type(a)~="table") or (b~=nil and type(b)~="table") then
     return nil,"META_MALFORMED"
 end
 if a and b and a~=b then
     for _,field in ipairs({"ItemName","Name","ItemType","Rarity","Chroma",
                            "Tradable","CanTrade","Untradable","NonTradable",
                            "EvoBaseID","EvoIndex"}) do
         if a[field]~=b[field] then return nil,"META_CONFLICT" end
     end
 end
 local d=a or b
 if type(d.ItemName or d.Name)~="string" or
    type(d.ItemType)~="string" or type(d.Rarity)~="string" or
    (d.Chroma~=nil and type(d.Chroma)~="boolean") then
     return nil,"META_MALFORMED"
 end
 return d,nil
end
local function eligible(d)
 if not d then return false end
 local name=d.ItemName or d.Name
 if name=="" or name=="???" or d.EvoBaseID~=nil or d.EvoIndex~=nil or
     d.Tradable==false or d.CanTrade==false or
     d.Untradable==true or d.NonTradable==true then return false end
 local k=d.ItemType:lower()
 local r=d.Rarity:lower()
 return (k=="gun" or k=="knife") and (r=="ancient" or r=="godly")
end
local function inspect(d,row)
 if not d then return "metadataMissing" end
 if not eligible(d) then return "explicitlyIneligible" end
 local chroma=d.Chroma==true
 if d.ItemType:lower()~=row[2]:lower() or
    d.Rarity:lower()~=row[3]:lower() or chroma~=row[4] then
     return "structuralMismatch"
 end
 if norm(d.ItemName or d.Name,chroma)~=norm(row[1],false) then
     return "labelDrift"
 end
 return "exactMatch"
end
local function emptyMetrics()
 return {
   exactMatchKeys=0,exactMatchCopies=0,structuralMismatchKeys=0,
   labelDriftKeys=0,eligibleOutsideRegistryKeys=0,
   eligibleOutsideRegistryCopies=0,matchedHistoricalKeys=0,
   matchedHistoricalCopies=0,metadataInvalidOwnedKeys=0,
   eligibleRawKeys=0,eligibleRawCopies=0,eligibleStackedKeys=0,
   eligibleCopiesBeyondFirst=0,eligibleOverFourCopiesKeys=0,
   maxEligibleCopiesPerKey=0,rawKeys=0,rawCopies=0,
 }
end
local function addMetric(t,key,amt)
 t[key]=(t[key] or 0)+(amt or 1)
end
function M.assess(profile,sync,registry,jobId,started,ended)
 if type(jobId)~="string" or not jobId:match("^[A-Za-z0-9_-]+$") or
    #jobId<8 or #jobId>100 or not validClock(started) or
    not validClock(ended) or ended<started or ended-started>15 then
     return report("BLOCKED","LOCAL_SESSION_CLOCK_INVALID")
 end
 local entries,regErr=registryValidate(registry)
 if not entries then return report("BLOCKED",regErr) end
 local owned=ownedTable(profile,0)
 if not owned then return report("BLOCKED","OWN_WEAPONS_PROFILE_MISSING") end
 if type(sync)~="table" or (type(sync.Weapons)~="table" and
    type(sync.Item)~="table") then
     return report("INCONCLUSIVE","LIVE_GAME_SYNC_UNAVAILABLE")
 end
 -- Full historical game-key membership check, distinct from own inventory.
 local catalog={historicalRows=189,sourceKind="EXPIRED_PUBLIC_REGISTRY",
     keysPresent=0,keysMissing=0,metadataMalformed=0,metadataConflict=0,
     exactMatch=0,structuralMismatch=0,labelDrift=0,explicitlyIneligible=0}
 local registryOutcome={}
 for key,row in pairs(entries) do
     local meta,why=getMeta(sync,key)
     if why=="KEY_ABSENT" then
         catalog.keysMissing+=1;registryOutcome[key]="metadataMissing"
     else
         catalog.keysPresent+=1
         if why=="META_MALFORMED" then catalog.metadataMalformed+=1 end
         if why=="META_CONFLICT" then catalog.metadataConflict+=1 end
         local outcome=why and "metadataMissing" or inspect(meta,row)
         registryOutcome[key]=outcome
         if catalog[outcome]~=nil then catalog[outcome]+=1 end
     end
 end
 if catalog.keysPresent+catalog.keysMissing~=189 then
     return report("BLOCKED","REGISTRY_FULL_CATALOG_SUM_MISMATCH")
 end
 -- Own exact raw-key membership, never copy keys or counts per weapon.
 local m=emptyMetrics()
 local seen=0
 for key,value in pairs(owned) do
     seen+=1
     if seen>4000 then return report("BLOCKED","OWNED_RAW_ENTRY_CAP") end
     if not validKey(key) then return report("BLOCKED","OWNED_RAW_KEY_INVALID") end
     local q=parseQty(value)
     if q==nil then return report("BLOCKED","OWNED_QUANTITY_INVALID") end
     if q>0 then
         m.rawKeys+=1;m.rawCopies+=q
         if m.rawCopies>4000000 then return report("BLOCKED","OWNED_COPIES_CAP") end
         local meta,why=getMeta(sync,key)
         if why=="META_MALFORMED" or why=="META_CONFLICT" or
            why=="KEY_ABSENT" then m.metadataInvalidOwnedKeys+=1 end
         if not why and eligible(meta) then
             m.eligibleRawKeys+=1;m.eligibleRawCopies+=q
             m.maxEligibleCopiesPerKey=math.max(m.maxEligibleCopiesPerKey,q)
             if q>1 then
                 m.eligibleStackedKeys+=1
                 m.eligibleCopiesBeyondFirst+=(q-1)
             end
             if q>4 then m.eligibleOverFourCopiesKeys+=1 end
             local row=entries[key]
             if row==nil then
                 addMetric(m,"eligibleOutsideRegistryKeys")
                 addMetric(m,"eligibleOutsideRegistryCopies",q)
             else
                 addMetric(m,"matchedHistoricalKeys")
                 addMetric(m,"matchedHistoricalCopies",q)
                 local state=registryOutcome[key]
                 if state=="exactMatch" then
                     addMetric(m,"exactMatchKeys")
                     addMetric(m,"exactMatchCopies",q)
                 elseif state=="labelDrift" then
                     addMetric(m,"labelDriftKeys")
                 else
                     addMetric(m,"structuralMismatchKeys")
                 end
             end
         end
     end
 end
 if m.matchedHistoricalKeys+m.eligibleOutsideRegistryKeys~=m.eligibleRawKeys
     or m.matchedHistoricalCopies+m.eligibleOutsideRegistryCopies~=m.eligibleRawCopies
     or m.exactMatchKeys+m.labelDriftKeys+m.structuralMismatchKeys~=m.matchedHistoricalKeys
     or m.maxEligibleCopiesPerKey>m.eligibleRawCopies then
     return report("BLOCKED","OWNED_MARKET_KEY_BUCKET_SUM_INVALID")
 end
 local sourcePotential=m.eligibleOutsideRegistryKeys==0 and
     m.structuralMismatchKeys==0 and m.labelDriftKeys==0 and
     m.metadataInvalidOwnedKeys==0
 local catalogStatus=(catalog.keysMissing==0 and catalog.metadataMalformed==0 and
     catalog.metadataConflict==0 and catalog.structuralMismatch==0 and
     catalog.labelDrift==0 and catalog.explicitlyIneligible==0) and
     "HISTORICAL_REGISTRY_CLIENT_META_PARITY" or "PARTIAL_HISTORICAL_GAME_CATALOG_DRIFT"
 return report("CLIENT_KEY_RECONCILIATION_BATCH",
    "HISTORICAL_SOURCE_ONLY_NOT_CURRENT_MARKET_OR_ITEM_AUTHORITY",{
     historicalSource={
       status="EXPIRED_NO_PUBLISHER_EDITION_AUTH",
       registryRows=189,originalRegistryPinnedExternally=true,
       publisherVersionAuthenticated=false,currentQuoteAdmissible=false},
     currentGameCatalog={
       status=catalogStatus,rowsInspected=189,keysPresent=catalog.keysPresent,
       keysMissing=catalog.keysMissing,metadataMalformed=catalog.metadataMalformed,
       metadataConflict=catalog.metadataConflict,structuralMismatch=catalog.structuralMismatch,
       labelDrift=catalog.labelDrift,explicitlyIneligible=catalog.explicitlyIneligible,
       exactMatch=catalog.exactMatch},
     ownedKeyMapping={
       status=sourcePotential and "HISTORICAL_KEY_CANDIDATES_MATCH_CLIENT_META" or
           "PARTIAL_HISTORICAL_KEY_OR_METADATA_DRIFT",
       eligibleRawKeys=m.eligibleRawKeys,
       eligibleRawCopies=m.eligibleRawCopies,
       keysInHistoricalRegistry=m.matchedHistoricalKeys,
       copiesInHistoricalRegistry=m.matchedHistoricalCopies,
       keysOutsideHistoricalRegistry=m.eligibleOutsideRegistryKeys,
       copiesOutsideHistoricalRegistry=m.eligibleOutsideRegistryCopies,
       exactMetaNameTypeKeys=m.exactMatchKeys,
       exactMetaNameTypeCopies=m.exactMatchCopies,
       gameLabelDriftKeys=m.labelDriftKeys,
       structuralMismatchKeys=m.structuralMismatchKeys,
       ownedUnresolvedMetaKeys=m.metadataInvalidOwnedKeys,
       allowsListedValue=false},
     stackConcentration={
       status="READONLY_STACK_COUNTS_NO_OFFER_FEASIBILITY",
       eligibleStackedKeys=m.eligibleStackedKeys,
       copiesBeyondFirst=m.eligibleCopiesBeyondFirst,
       keysWithOverFourCopies=m.eligibleOverFourCopiesKeys,
       maxCopiesPerEligibleKey=m.maxEligibleCopiesPerKey,
       maxDistinctOfferSlotsAssumed=4,physicalSlotFeasibilityProven=false},
     targetProtection={
       status="PROTECTED_TARGET_NEVER_OUTGOING",
       targetInRegistry=true,generatedCandidateCount=0,
       targetOwnershipRevealed=false,mayOfferTarget=false},
     localSession={
       status="PASS_LOCAL_READ_WINDOW_ONLY",
       durationSeconds=ended-started,serverSessionAuthenticated=false},
 })
end
return M
