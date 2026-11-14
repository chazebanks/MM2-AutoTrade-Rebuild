-- System2 native own-inventory census witness: PURE client-only logic.
-- No Roblox APIs here. Never report raw keys, player names, JobId, values,
-- item identity proof, offer revision, trade completion or any action permit.
local M = {}
local SCHEMA = "gingerscope-system2-native-own-census-v1"
local function output(status, reason, extra)
    local r = {
        schema=SCHEMA, status=status, reason=reason, readOnly=true,
        clientOnly=true, nativeSourceAuthenticated=false,
        currentGameItemInstanceProven=false,
        serverInventoryAuthoritative=false,
        activeTradeSessionProven=false, offerRevisionAuthenticated=false,
        serverTradeRevisionProven=false, serverCompletionProven=false,
        authorizesTrade=false, authorizesOffer=false, authorizesAccept=false,
        mayReportProfit=false, maySendDiscordWebhook=false,
        mayUseForStrategyLearning=false, tradeOutcome="UNKNOWN",
        actualOffers=0, actualAccepts=0, actualDeclines=0,
        actualTeleports=0,
    }
    if extra then
        for k,v in pairs(extra) do r[k]=v end
    end
    return r
end
local function finite(n)
    return type(n)=="number" and n==n and n>=0 and n<math.huge
end
local function unwrap(data, depth)
    if type(data)~="table" or depth>4 then return nil end
    if type(data.Weapons)=="table" and
       type(data.Weapons.Owned)=="table" then return data end
    for _,key in ipairs({"ProfileData","Profile","PlayerData","Data",
                         "Inventory","FullInventory"}) do
        local p=unwrap(data[key],depth+1)
        if p then return p end
    end
    return nil
end
local function qtyNumber(raw)
    if type(raw)=="number" then
        if not finite(raw) or raw~=math.floor(raw) then return nil end
        return raw
    end
    if type(raw)=="string" and raw:match("^%d+$") and #raw<=7 then
        local n=tonumber(raw)
        if n and n==math.floor(n) then return n end
    end
    return nil
end
local function fingerprint(parts)
    -- Deliberately NON-cryptographic and never included in the public report.
    -- Equality is local-client census comparison, not proof of ownership.
    local h=5381
    for _,s in ipairs(parts) do
        for i=1,#s do
            h=(h*33+string.byte(s,i))%2147483647
        end
        h=(h*33+124)%2147483647
    end
    return h
end
function M.observe(profile, jobId, nowClock)
    if type(jobId)~="string" or not jobId:match("^[A-Za-z0-9_-]+$") or
       #jobId<8 or #jobId>100 or not finite(nowClock) then
        return nil,output("BLOCKED","CLIENT_JOB_OR_MONOTONIC_CLOCK_INVALID")
    end
    local resolved=unwrap(profile,0)
    if not resolved then
        return nil,output("BLOCKED","READ_ONLY_PROFILE_OR_OWNED_WEAPONS_MISSING")
    end
    local owned=resolved.Weapons.Owned
    local parts={}
    local distinct=0
    local scanned=0
    local total=0
    for key,rawQty in pairs(owned) do
        -- Count zero-quantity catalog entries too; otherwise a hostile
        -- oversized zero-only map could bypass the nonzero census bound.
        scanned+=1
        if scanned>4000 then
            return nil,output("BLOCKED","OWNED_CENSUS_BOUNDS_EXCEEDED")
        end
        if type(key)~="string" or #key<1 or #key>90 or
           not key:match("^[A-Za-z0-9_]+$") then
            return nil,output("BLOCKED","RAW_GAME_CENSUS_KEY_INVALID")
        end
        local q=qtyNumber(rawQty)
        if q==nil or q>1000000 then
            return nil,output("BLOCKED","RAW_GAME_CENSUS_QUANTITY_INVALID")
        end
        if q>0 then
            distinct+=1
            if distinct>4000 or total+q>4000000 then
                return nil,output("BLOCKED","OWNED_CENSUS_BOUNDS_EXCEEDED")
            end
            total+=q
            parts[#parts+1]=key..":"..tostring(q)
        end
    end
    table.sort(parts)
    -- The stamp must remain only in the client process. Do not copy/print.
    return {
        schema=SCHEMA, jobId=jobId, monotonic=nowClock,
        localFingerprint=fingerprint(parts), parts=parts,
        distinct=distinct, copies=total,
    },output("CLIENT_CENSUS_SNAPSHOT_ONLY",
        "FIRST_READ_ONLY_OWN_PROFILE_NO_GAME_OWNERSHIP_PROOF",
        {rawDistinctKeysObserved=distinct,rawCopiesObserved=total})
end
local function sameParts(a,b)
    if a.localFingerprint~=b.localFingerprint or #a.parts~=#b.parts then
        return false
    end
    for i=1,#a.parts do
        if a.parts[i]~=b.parts[i] then return false end
    end
    return true
end
function M.compare(a,b)
    if type(a)~="table" or type(b)~="table" or
       a.schema~=SCHEMA or b.schema~=SCHEMA or
       type(a.jobId)~="string" or type(b.jobId)~="string" or
       not finite(a.monotonic) or not finite(b.monotonic) or
       type(a.parts)~="table" or type(b.parts)~="table" or
       type(a.localFingerprint)~="number" or
       type(b.localFingerprint)~="number" then
        return output("BLOCKED","CLIENT_CENSUS_STAMP_INVALID")
    end
    if a.jobId~=b.jobId then
        return output("BLOCKED","CLIENT_GAME_JOB_CHANGED")
    end
    local dt=b.monotonic-a.monotonic
    if dt<2 or dt>60 then
        return output("BLOCKED","TWO_READS_TIMING_WINDOW_INVALID")
    end
    local equal=sameParts(a,b)
    return output(equal and "CLIENT_TWO_READS_STABLE" or
        "CLIENT_TWO_READS_DIFFERENT",
        equal and "LOCAL_CENSUS_EQUALITY_ONLY_NO_SERVER_PROOF" or
        "LOCAL_CENSUS_DIFFERENCE_REQUIRES_REVALIDATION",
        {clientCensusChanged=not equal,
         firstDistinctKeys=a.distinct,secondDistinctKeys=b.distinct,
         firstCopies=a.copies,secondCopies=b.copies,
         observationGapSeconds=dt,
         researchDecisionReusable=false})
end
return M
