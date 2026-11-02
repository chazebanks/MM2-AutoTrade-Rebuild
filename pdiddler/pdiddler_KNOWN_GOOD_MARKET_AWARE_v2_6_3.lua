-- pdiddler MARKET-AWARE TEST STACK v2.6.3 PERF + INELIGIBLE + NO-PLAN DECLINE
--
-- New in v2.6:
--   * validated 190-item MM2Values + Supreme market profile
--   * material cross-source disagreement protection
--   * demand/stability-aware downgrade premium
--   * controlled <=3% quality-upgrade exception
--   * deterministic market-aware candidate ranking
--   * canonical page:id identity in Part 4 signatures/counts
--   * existing v2.5 transaction/recovery/timer behavior retained
--   * FINAL ITEM-TRADE ACCEPT DISABLED
--
-- Changes from v2.6:
--   * repeated identical market bundle assessments are cached (bounded 64 entries)
--   * Rare/Uncommon/non-eligible items remain value 0 but no longer invalidate
--     an otherwise-correct eligible plan verification
--   * ineligible items STILL remain in the offer signature so add/remove changes
--     invalidate stale transactions correctly
--   * stable + resolved + non-empty THEIR OFFER with zero safe 1-4 plans
--     immediately declines and returns to Part 3 rotation
--   * empty offers still keep the 15s rule; unresolved items still HOLD safely
-- This is a TEST BUILD. Do not freeze as known-good until recording review.

local ENV=(getgenv and getgenv()) or _G

ENV.PDIDDLER_OUTGOING_SESSION=(tonumber(ENV.PDIDDLER_OUTGOING_SESSION) or 0)+1
ENV.PDIDDLER_PART4_SESSION=(tonumber(ENV.PDIDDLER_PART4_SESSION) or 0)+1
ENV.PDIDDLER_OUTGOING_BUSY_SESSION=nil
ENV.PDIDDLER_STATUS_OWNER=nil

local function loadModule(url,label)
    local ok,src=pcall(function()
        return game:HttpGet(url,true)
    end)

    if not ok or type(src)~="string" or src=="" then
        error("[PDIDDLER TEST] "..tostring(label).." HTTP failed: "..tostring(src))
    end

    local fn,err=loadstring(src)
    if not fn then
        error("[PDIDDLER TEST] "..tostring(label).." compile failed: "..tostring(err))
    end

    local okRun,result=pcall(fn)
    if not okRun then
        error("[PDIDDLER TEST] "..tostring(label).." init failed: "..tostring(result))
    end

    return result
end

local p1=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/af4a646aa751571bace8eeb2b305ba16cebcad2f/pdiddler/pdiddler1_KNOWN_GOOD.lua",
    "Part 1"
)
local ok1,res1=pcall(p1.run)
if not ok1 then error("[PDIDDLER TEST] Part 1 run failed: "..tostring(res1)) end
if res1~=true then warn("[PDIDDLER TEST] Part 1 blocked this server"); return false end

local p2=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/b097c1862db4cff7394d6a5e6764d34191df3283/pdiddler/pdiddler2_KNOWN_GOOD.lua",
    "Part 2"
)
local ok2,res2=pcall(p2.run)
if not ok2 then error("[PDIDDLER TEST] Part 2 run failed: "..tostring(res2)) end
if res2~=true then warn("[PDIDDLER TEST] Part 2 failed"); return false end

local scanner=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/3c48b49c1e750d91bfbf088fbc737185bddf39be/pdiddler/pdiddler3_scanner_MODULE_v6_8_CRITICAL_PAUSE.lua",
    "Scanner critical-phase pause build"
)

local INTEGRATION_COMMIT="7809aa8c8d210d8005c223eb9fd3a6b3ea716ba5"
local BASE="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..INTEGRATION_COMMIT.."/pdiddler/"

local marketProfile=loadModule(
    BASE.."pdiddler_market_profile_2026-11-02_v1_VALIDATED.lua",
    "Validated market profile"
)
local marketLogicBase=loadModule(
    BASE.."pdiddler4_market_logic_v1_TEST.lua",
    "Validated market decision engine"
)

local marketBundleCache=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/03dd37b0f3d49700a38c55d7f7d15e83de077911/pdiddler/pdiddler4_market_bundle_cache_v1.lua",
    "Market bundle performance cache"
)

local marketLogic=marketBundleCache.wrap(
    marketProfile,
    marketLogicBase,
    64
)
local NO_PLAN_COMMIT="d124a56c9e28810cd7726aff88fc891d925f0683"
local NO_PLAN_BASE="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..NO_PLAN_COMMIT.."/pdiddler/"

local marketPlanner=loadModule(
    NO_PLAN_BASE.."pdiddler4_market_planner_v1_1.lua",
    "Market-aware planner v1.1 ineligible-safe verifier"
)
local part4=loadModule(
    NO_PLAN_BASE.."pdiddler4_balancer_ROTATING_v2_4_2_NO_PLAN_DECLINE.lua",
    "Part 4 market-aware no-plan immediate decline"
)

local function item(page,id,value,qty,name)
    return {
        page=tostring(page or "godly"),
        id=tostring(id),
        name=tostring(name or id),
        value=tonumber(value) or 0,
        qty=tonumber(qty) or 1,
    }
end

local function preflight()
    assert(type(marketProfile)=="table","market profile table missing")
    assert(marketProfile.liveReady==true,"market profile is not liveReady")
    assert(type(marketProfile.get)=="function","marketProfile.get missing")
    assert(type(marketProfile.coverage)=="function","marketProfile.coverage missing")
    assert(type(marketLogic)=="table","market logic table missing")
    assert(type(marketLogic.itemAssessment)=="function","market itemAssessment missing")
    assert(type(marketLogic.bundleAssessment)=="function","market bundleAssessment missing")
    assert(type(marketLogic.tradeDecision)=="function","market tradeDecision missing")
    assert(type(marketLogic.rankPlans)=="function","market rankPlans missing")
    assert(type(marketPlanner)=="table" and type(marketPlanner.buildPlans)=="function",
        "market planner buildPlans missing")
    assert(type(marketPlanner.planMatches)=="function",
        "market planner planMatches missing")
    assert(type(part4)=="table" and type(part4.run)=="function","Part 4 run missing")

    local coverage=marketProfile.coverage()
    assert(
        type(coverage)=="table"
        and tonumber(coverage.ancient)==16
        and tonumber(coverage.chroma)==46
        and tonumber(coverage.godly)==128
        and tonumber(coverage.total)==190,
        "market profile coverage mismatch"
    )

    local ember=assert(marketProfile.get("ancient","1027"),"Emberscythe profile missing")
    assert(ember.mm2Value==300 and ember.supremeValue==375,
        "Emberscythe 300/375 mapping mismatch")

    local mortal=assert(marketProfile.get("chroma","1033"),"Chroma Mortal profile missing")
    assert(mortal.mm2Value==1800 and mortal.supremeValue==1600,
        "Chroma Mortal 1800/1600 mapping mismatch")

    local emberAssess=marketLogic.itemAssessment(
        item("ancient","1027",300,1,"Emberscythe"),
        "ours",
        ember
    )
    assert(
        emberAssess.materialDisagreement==true
        and emberAssess.protectedUnitValue==375,
        "OUR Emberscythe protection mismatch"
    )

    local function theirBundle(items)
        return marketLogic.bundleAssessment(items,"theirs",marketProfile)
    end

    -- Moderate overpay: closest safe 230 offer should remain the top plan.
    local plans,why=marketPlanner.buildPlans(
        {items={item("godly","preflight230",230)}},
        theirBundle({item("godly","preflight270",270)}),
        marketProfile,
        marketLogic
    )
    assert(type(plans)=="table" and plans[1],
        "moderate preflight planner failed: "..tostring(why))
    assert(plans[1].rawTotal==230 and plans[1].rawProfit==40,
        "moderate +40 hold planner mismatch")

    -- Extreme case: 20 opening + 90 available vs 105 should choose 90 (+15).
    plans,why=marketPlanner.buildPlans(
        {items={
            item("godly","preflight20",20),
            item("godly","preflight90",90),
        }},
        theirBundle({item("godly","preflight105",105)}),
        marketProfile,
        marketLogic
    )
    assert(type(plans)=="table" and plans[1],
        "extreme preflight planner failed: "..tostring(why))
    assert(plans[1].rawTotal==90 and plans[1].rawProfit==15,
        "extreme 20/105 -> 90 target mismatch")

    -- Three unprofiled weak/uncertain pieces at raw +30 must not pass a
    -- BIG DOWNGRADE; missing metadata must not be safer than known data.
    plans,why=marketPlanner.buildPlans(
        {items={item("godly","preflight100",100)}},
        theirBundle({
            item("godly","preflight43a",43),
            item("godly","preflight44",44),
            item("godly","preflight43b",43),
        }),
        marketProfile,
        marketLogic
    )
    assert(type(plans)=="table" and #plans==0,
        "uncertain +30 big downgrade should have no safe plan: "..tostring(why))

    -- Equal raw/protected values: give away the weaker-exit item first.
    -- Embersickle exit score is weaker than Pearlshine in the validated snapshot.
    plans,why=marketPlanner.buildPlans(
        {items={
            item("godly","1028",80,1,"Embersickle"),
            item("godly","813",80,1,"Pearlshine"),
        }},
        theirBundle({item("godly","preflight100b",100)}),
        marketProfile,
        marketLogic
    )
    assert(type(plans)=="table" and plans[1],
        "equal-state rank preflight failed: "..tostring(why))
    assert(plans[1].picks[1] and tostring(plans[1].picks[1].id)=="1028",
        "planner should give weaker Embersickle before Pearlshine at equal raw/protected value")

    -- Equal raw value with different protected value must survive as two states.
    plans,why=marketPlanner.buildPlans(
        {items={
            item("godly","preflight300",300),
            item("ancient","1027",300,1,"Emberscythe"),
        }},
        theirBundle({item("godly","preflight400",400)}),
        marketProfile,
        marketLogic
    )
    assert(type(plans)=="table","protected-state preflight failed: "..tostring(why))
    local seen={}
    for _,plan in ipairs(plans) do
        if plan.rawTotal==300 then
            seen[plan.protectedTotal]=true
        end
    end
    assert(seen[300] and seen[375],
        "300 raw / 300 vs 375 protected planner states were collapsed")

    -- Rare/Uncommon regression: extra non-eligible zero-value items must not
    -- prevent verification of the eligible plan.
    local verifyPlan={
        rawTotal=100,
        picks={{page="godly",id="verify100",qty=1}},
    }
    local verifyLive={
        rawTotal=100,
        unresolved={},
        counts={
            ["godly:verify100"]=1,
            ["ineligible:rareKnife"]=1,
            ["ineligible:uncommonGun"]=1,
        },
    }
    assert(marketPlanner.planMatches(verifyPlan,verifyLive)==true,
        "ineligible Rare/Uncommon item still blocks plan verification")

    verifyLive.counts["godly:extraEligible"]=1
    verifyLive.rawTotal=120
    assert(marketPlanner.planMatches(verifyPlan,verifyLive)==false,
        "extra eligible item must still invalidate plan verification")

    print("[PDIDDLER TEST] MARKET PREFLIGHT PASS | profile 190/190 | planner + ineligible verifier fixtures PASS")
end

local okPreflight,preflightErr=pcall(preflight)
if not okPreflight then
    error("[PDIDDLER TEST] MARKET PREFLIGHT FAILED: "..tostring(preflightErr))
end

local outgoing=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/9f0637b063c2f65cb1cf6fc1f6ce4ab08b5dda87/pdiddler/pdiddler3_outgoing_ROTATING_v15_UNCERTAIN_OWNER.lua",
    "Part 3 authoritative outgoing ownership build"
)

local ok4,p4Controller=pcall(function()
    return part4.run(
        scanner,
        marketProfile,
        marketLogic,
        marketPlanner
    )
end)
if not ok4 then
    error("[PDIDDLER TEST] Part 4 failed to arm: "..tostring(p4Controller))
end

local okOut,outController=pcall(function()
    return outgoing.run(scanner)
end)
if not okOut then
    error("[PDIDDLER TEST] Part 3 failed: "..tostring(outController))
end

print("[PDIDDLER TEST] MARKET-AWARE v2.6.3 PERF + INELIGIBLE + NO-PLAN DECLINE ACTIVE")
print("[PDIDDLER TEST] repeated market bundle valuation cache active | max=64")
print("[PDIDDLER TEST] Rare/Uncommon zero-value items ignored by eligible plan verification")
print("[PDIDDLER TEST] stable resolved non-empty no-plan trades decline immediately")
print("[PDIDDLER TEST] validated 190-item market snapshot active")
print("[PDIDDLER TEST] Supreme/MM2 disagreement protection active")
print("[PDIDDLER TEST] demand/stability downgrade risk active")
print("[PDIDDLER TEST] deterministic market planner active")
print("[PDIDDLER TEST] canonical page:id offer identity active")
print("[PDIDDLER TEST] request ownership + scanner pause retained")
print("[PDIDDLER TEST] TX abort/recovery + 15s/60s timers retained")
print("[PDIDDLER TEST] moderate overpay holds; extreme guard retained")
print("[PDIDDLER TEST] FINAL ITEM-TRADE ACCEPT IS DISABLED")

return {
    scanner=scanner,
    outgoing=outController,
    part4=p4Controller,
    marketProfile=marketProfile,
    marketLogic=marketLogic,
    marketLogicBase=marketLogicBase,
    marketBundleCache=marketBundleCache,
    marketPlanner=marketPlanner,
    integrationCommit=INTEGRATION_COMMIT,
    noPlanCommit=NO_PLAN_COMMIT,
}
