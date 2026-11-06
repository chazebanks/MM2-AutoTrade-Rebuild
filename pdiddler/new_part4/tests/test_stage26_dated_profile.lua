-- Stage 26: verified dated Supreme Lua profile, no live Roblox API.
-- Asserts real expiration and that stale source denies repricing/eligibility.
local dir = arg[1] or "pdiddler/new_part4"
local S = assert(dofile(dir.."/../snapshots/pdiddler_supreme_snapshot_2026_11_06.lua"))
local Repricer = assert(loadfile(dir.."/P4_REPRICE_ONLY.lua"))()
local Eligibility = assert(loadfile(dir.."/P3_ELIGIBILITY_NO_LEGACY_PROFIT.lua"))()
local assertions = 0
local function check(name, fn)
    local ok, err = pcall(fn)
    if not ok then error(name..": "..tostring(err)) end
    assertions = assertions + 1
end

check("promoted profile retains original source publication and new retrieval", function()
    assert(S.sourceTimestamp == "2026-11-04T17:27:12Z")
    assert(S.supremeUpdated == "2026-11-04T17:27:12Z")
    assert(S.observedAt == "2026-11-06T00:47:22Z")
    assert(S.observedAtEpoch == 1793926042)
    assert(S.expiresAt == "2026-11-07T00:47:22Z")
    assert(S.expiresAtEpoch == 1794012442)
    assert(S.version == "supreme-2026-11-06-96f1f6e43707")
end)

check("190 exact eligible and only one unpriced", function()
    local coverage=S.coverage()
    assert(S.liveReady==true and coverage.total==190)
    assert(coverage.ancient==16 and coverage.chroma==46 and coverage.godly==128)
    assert(coverage.finite==189 and coverage.unpriced==1)
    assert(S.get("ancient","1").supremeValue==nil)
    assert(S.get("godly","garbage")==nil)
end)

check("Gingerscope is exactly priced and canonical", function()
    local g=assert(S.get("ancient","771"))
    assert(g.page=="ancient" and g.id=="771" and g.name=="Gingerscope")
    assert(g.supremeValue==16000 and g.demand==5)
    assert(g.stability=="Stable" and g.verified==true)
    assert(g.provenance and g.provenance.sha256)
end)

check("fixed expiry NEVER rolls forward at process startup", function()
    assert(S.isFresh(S.observedAtEpoch-1)==false)
    assert(S.isFresh(S.observedAtEpoch)==true)
    assert(S.isFresh(S.expiresAtEpoch-1)==true)
    assert(S.isFresh(S.expiresAtEpoch)==false)
    assert(S.isFresh(S.expiresAtEpoch+86400)==false)
    assert(S.expiresAtEpoch-S.observedAtEpoch==86400)
end)

local inv = {fingerprint="synthetic-owned",
    unmapped=0,unpriced=0,badQty=0,
    items={{id="Gingerscope",page="ancient",checkerId="771",
        name="Gingerscope",cat="Weapons",type="Gun",
        qty=1,value=1}}}
local function at(epoch)
    return setmetatable({
       isFresh=function() return S.isFresh(epoch) end
    },{__index=S})
end

check("current source correctly reprices owned canonical item", function()
    local priced,why=Repricer.reprice(inv,at(S.observedAtEpoch+10))
    assert(why==nil and priced.value==16000 and priced.total==16000)
    assert(priced.items[1].checkerId=="771")
    assert(priced.items[1].value==16000)
    assert(inv.items[1].value==1) -- no source/inventory mutation
end)

check("exact expiry denies repricing and outgoing discovery", function()
    local stale=at(S.expiresAtEpoch)
    local priced,reason=Repricer.reprice(inv,stale)
    assert(type(priced)=="table" and reason=="supreme-profile-stale")
    local state,why=Eligibility.evaluate(inv,inv,stale,Repricer)
    assert(state=="unknown" and why=="source-expired")
end)

check("post-expiry source also cannot authorize an outgoing request", function()
    local old=at(S.expiresAtEpoch+100)
    local state=Eligibility.evaluate(inv,inv,old,Repricer)
    assert(state=="unknown")
    assert(Repricer.tradeDecision==nil)
    assert(Repricer.buildPlans==nil)
end)

print("PASS",assertions,"Stage26 exact-date market source and fail-closed expiry")
