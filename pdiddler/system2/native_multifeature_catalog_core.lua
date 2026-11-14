-- System2 pure client-census classification: scoped research, never trading authority.
-- Consumes a read-only MM2 Weapons.Owned profile and Database.Sync metadata.
-- Only aggregate counts leave this module. No raw ID, item name, price or JobId.
local M={}
local SCHEMA="gingerscope-system2-native-multifeature-v1"
local DENIED={
    readOnly=true,clientOnly=true,
    serverInventoryAuthoritative=false,gameItemInstanceProven=false,
    sourceEditionAuthenticated=false,activeTradeSessionProven=false,
    offerRevisionAuthenticated=false,serverTradeRevisionProven=false,
    serverCompletionProven=false,measuredLiquidityVerified=false,
    authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
    mayReportProfit=false,maySendDiscordWebhook=false,
    mayUseForStrategyLearning=false,tradeOutcome="UNKNOWN",
    actualOffers=0,actualAccepts=0,actualDeclines=0,actualTeleports=0,
}
local function report(status,reason,fields)
    local r={schema=SCHEMA,status=status,reason=reason}
    for k,v in pairs(DENIED) do r[k]=v end
    if fields then for k,v in pairs(fields) do r[k]=v end end
    return r
end
local function goodNumber(n)
    return type(n)=="number" and n==n and n>=0 and n<math.huge
end
local function parseQty(q)
    if type(q)=="number" then
        if goodNumber(q) and q==math.floor(q) and q<=1000000 then return q end
    elseif type(q)=="string" and #q<=7 and q:match("^%d+$") then
        local v=tonumber(q)
        if v and v<=1000000 then return v end
    end
    return nil
end
local function profileOwned(x,depth)
    if type(x)~="table" or depth>4 then return nil end
    if type(x.Weapons)=="table" and type(x.Weapons.Owned)=="table" then
        return x.Weapons.Owned
    end
    for _,name in ipairs({"ProfileData","Profile","PlayerData","Data",
                          "Inventory","FullInventory"}) do
        local v=profileOwned(x[name],depth+1)
        if v then return v end
    end
    return nil
end
local function getMeta(sync,key)
    if type(sync)~="table" then return nil,"SYNC_UNAVAILABLE" end
    local weapons=sync.Weapons
    local items=sync.Item
    if type(weapons)~="table" and type(items)~="table" then
        return nil,"SYNC_UNAVAILABLE"
    end
    local a=type(weapons)=="table" and weapons[key] or nil
    local b=type(items)=="table" and items[key] or nil
    if a==nil and b==nil then return nil,"RAW_KEY_NOT_IN_SYNC" end
    if (a~=nil and type(a)~="table") or (b~=nil and type(b)~="table") then
        return nil,"MALFORMED_SYNC_ROW"
    end
    -- Reject mismatched duplicate rows instead of silent overwrite.
    if a~=nil and b~=nil and a~=b then
        for _,k in ipairs({"ItemName","Name","ItemType","Rarity","Chroma",
                           "EvoBaseID","EvoIndex","Tradable","CanTrade",
                           "Untradable","NonTradable"}) do
            if a[k]~=b[k] then return nil,"CONFLICTING_SYNC_ROWS" end
        end
    end
    return a or b,nil
end
local function classify(d)
    local name=d.ItemName or d.Name
    local kind=d.ItemType
    local rarity=d.Rarity
    if type(name)~="string" or type(kind)~="string" or
       type(rarity)~="string" or
       (d.Chroma~=nil and type(d.Chroma)~="boolean") then
        return nil,"MALFORMED_SYNC_ROW"
    end
    if name=="" or name=="???" or name:match("^%?%?%?$") then
        return "excludedPlaceholder"
    end
    if d.EvoBaseID~=nil or d.EvoIndex~=nil then
        return "excludedEvolution"
    end
    -- Original P3 scanner already honors these explicit game-side tradeability
    -- flags; classification must not silently count them as eligible.
    if d.Tradable==false or d.CanTrade==false or
       d.Untradable==true or d.NonTradable==true then
        return "excludedNontradable"
    end
    local k=string.lower(kind)
    local r=string.lower(rarity)
    if k~="gun" and k~="knife" then return "excludedOther" end
    if r~="ancient" and r~="godly" then return "excludedOrdinary" end
    if d.Chroma==true then
        return r=="ancient" and "chromaAncient" or "chromaGodly"
    end
    return r=="ancient" and "ancient" or "godly"
end
local CATEGORIES={
    "ancient","godly","chromaAncient","chromaGodly",
    "excludedOrdinary","excludedEvolution","excludedPlaceholder",
    "excludedNontradable","excludedOther","unmapped","malformed","conflicting",
}
local function counts()
    local r={}
    for _,k in ipairs(CATEGORIES) do r[k.."Keys"]=0;r[k.."Copies"]=0 end
    return r
end
function M.assess(profile,sync,jobId,monotonicStart,monotonicEnd)
    if type(jobId)~="string" or not jobId:match("^[A-Za-z0-9_-]+$") or
       #jobId<8 or #jobId>100 or
       not goodNumber(monotonicStart) or not goodNumber(monotonicEnd) or
       monotonicEnd<monotonicStart or monotonicEnd-monotonicStart>15 then
        return report("BLOCKED","SESSION_OR_READ_AGE_INVALID")
    end
    local owned=profileOwned(profile,0)
    if not owned then
        return report("BLOCKED","OWN_WEAPONS_PROFILE_UNAVAILABLE")
    end
    local out=counts()
    local seen=0
    local keys=0
    local copies=0
    for rawKey,rawQty in pairs(owned) do
        seen+=1
        if seen>4000 then return report("BLOCKED","CENSUS_RAW_ENTRIES_LIMIT") end
        if type(rawKey)~="string" or #rawKey<1 or #rawKey>90 or
           not rawKey:match("^[A-Za-z0-9_]+$") then
            return report("BLOCKED","CENSUS_RAW_KEY_INVALID")
        end
        local q=parseQty(rawQty)
        if q==nil then return report("BLOCKED","CENSUS_QUANTITY_INVALID") end
        if q>0 then
            keys+=1;copies+=q
            if copies>4000000 then return report("BLOCKED","CENSUS_COPIES_LIMIT") end
            local meta,why=getMeta(sync,rawKey)
            local category
            if why=="RAW_KEY_NOT_IN_SYNC" or why=="SYNC_UNAVAILABLE" then
                category="unmapped"
            elseif why=="CONFLICTING_SYNC_ROWS" then
                category="conflicting"
            elseif why then
                category="malformed"
            else
                local kind,errorReason=classify(meta)
                category=kind or "malformed"
            end
            out[category.."Keys"]+=1
            out[category.."Copies"]+=q
        end
    end
    local accKeys=0
    local accCopies=0
    for _,k in ipairs(CATEGORIES) do
        accKeys+=out[k.."Keys"];accCopies+=out[k.."Copies"]
    end
    if accKeys~=keys or accCopies~=copies then
        return report("BLOCKED","CENSUS_BUCKET_RECONCILIATION_FAILED")
    end
    local eligibleKeys=out.ancientKeys+out.godlyKeys+
        out.chromaAncientKeys+out.chromaGodlyKeys
    local eligibleCopies=out.ancientCopies+out.godlyCopies+
        out.chromaAncientCopies+out.chromaGodlyCopies
    local unknownKeys=out.unmappedKeys+out.malformedKeys+out.conflictingKeys
    local unknownCopies=out.unmappedCopies+out.malformedCopies+out.conflictingCopies
    local excludedKeys=keys-eligibleKeys-unknownKeys
    local excludedCopies=copies-eligibleCopies-unknownCopies
    local coverage=(type(sync)=="table" and
        (type(sync.Weapons)=="table" or type(sync.Item)=="table"))
    local coverageStatus=coverage and "CLIENT_METADATA_COVERAGE_OBSERVED"
        or "INCONCLUSIVE_SYNC_UNAVAILABLE"
    local variantStatus=unknownKeys==0 and "CLIENT_VARIANTS_CLASSIFIED"
        or "PARTIAL_UNKNOWN_VARIANTS"
    return report("CLIENT_MULTI_FEATURE_REPORT","CLIENT_ONLY_NO_SERVER_OR_PUBLISHER_PROOF",{
        features={
            ownCensus={status="PASS_CLIENT_ONLY",keys=keys,copies=copies},
            metadata={status=coverageStatus,unmappedKeys=out.unmappedKeys,
                      conflictingKeys=out.conflictingKeys,malformedKeys=out.malformedKeys},
            classification={status=variantStatus,eligibleKeys=eligibleKeys,
                eligibleCopies=eligibleCopies,excludedKeys=excludedKeys,
                excludedCopies=excludedCopies,unknownKeys=unknownKeys,
                unknownCopies=unknownCopies,
                ancientKeys=out.ancientKeys,godlyKeys=out.godlyKeys,
                chromaAncientKeys=out.chromaAncientKeys,
                chromaGodlyKeys=out.chromaGodlyKeys},
            integrity={status="PASS_CLIENT_COUNTS_RECONCILED",
                bucketsReconciled=true,zeroCopyRowsIgnored=true},
            session={status="PASS_LOCAL_SAME_JOB_READ_WINDOW",
                observationDurationSeconds=monotonicEnd-monotonicStart,
                serverLeaseAuthenticated=false},
            publisher={status="NOT_TESTED_PUBLISHER_AUTHENTICATION_REQUIRED",
                currentVerifiedPriceSource=false},
        },
        -- Do NOT export item names, keys, fingerprint, JobId or catalog rows.
        inventoryRecordsExported=false,rawIdsExported=false,
        sessionIdentifiersExported=false,liveOfferRankingAuthorized=false,
    })
end
return M
