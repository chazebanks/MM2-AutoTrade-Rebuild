-- pdiddler MANUAL ACCEPT + GAIN + WEBHOOK TEST STACK v7 AUTO CLAIM | plan-cache + post-trade claims
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
-- Webhook addition:
--   * read-only verified-trade telemetry bridge
--   * server-confirmed completion listener
--   * exact raw Weapons.Owned delta fallback
--   * Discord webhook delivery isolated from trading
--   * webhook URL is supplied only through ENV.PDIDDLER_DISCORD_WEBHOOK_URL
-- Manual-Accept test addition:\n--   * detects native local YourOffer.Accepted read-only\n--   * displays verified raw projected gain during the trade\n--   * completion/webhook authority remains unchanged\n-- FINAL ITEM-TRADE ACCEPT remains DISABLED.

local ENV=(getgenv and getgenv()) or _G

-- Compatibility with the shorter variable name used in earlier chat tests.
-- The secret remains runtime-only and is never committed.
if (type(ENV.PDIDDLER_DISCORD_WEBHOOK_URL)~="string"
        or ENV.PDIDDLER_DISCORD_WEBHOOK_URL=="")
    and type(ENV.PDIDDLER_DISCORD_WEBHOOK)=="string"
    and ENV.PDIDDLER_DISCORD_WEBHOOK~=""
then
    ENV.PDIDDLER_DISCORD_WEBHOOK_URL=ENV.PDIDDLER_DISCORD_WEBHOOK
end

ENV.PDIDDLER_OUTGOING_SESSION=(tonumber(ENV.PDIDDLER_OUTGOING_SESSION) or 0)+1
ENV.PDIDDLER_PART4_SESSION=(tonumber(ENV.PDIDDLER_PART4_SESSION) or 0)+1
ENV.PDIDDLER_WEBHOOK_SESSION=(tonumber(ENV.PDIDDLER_WEBHOOK_SESSION) or 0)+1
ENV.PDIDDLER_MANUAL_GAIN_SESSION=(tonumber(ENV.PDIDDLER_MANUAL_GAIN_SESSION) or 0)+1
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

local CLAIM_COMMIT="a3e5160b232226b5f105a8630eb2048c8d26a7aa"
local CLAIM_BASE="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..CLAIM_COMMIT.."/pdiddler/"

local scanner=loadModule(
    CLAIM_BASE.."pdiddler3_scanner_MODULE_v6_9_CLAIM_PAUSE.lua",
    "Scanner critical-phase + post-trade claim pause build"
)

local claimPolicy=loadModule(
    CLAIM_BASE.."pdiddler_post_trade_claim_policy_v1.lua",
    "Post-trade claim state machine"
)
local postTradeClaim=loadModule(
    CLAIM_BASE.."pdiddler_post_trade_claim_v1.lua",
    "Verified post-trade received-item auto-claimer"
)

local INTEGRATION_COMMIT="7809aa8c8d210d8005c223eb9fd3a6b3ea716ba5"
local BASE="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..INTEGRATION_COMMIT.."/pdiddler/"

local ADAPTIVE_COMMIT="78fa90b21c63bc8bed412076cf5f01c33b48d70f"
local ADAPTIVE_BASE="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..ADAPTIVE_COMMIT.."/pdiddler/"

local PART4_PERF_COMMIT="5b4a45fca2f6024bdf645b4ca68b09c0129406f0"
local PART4_PERF_BASE="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..PART4_PERF_COMMIT.."/pdiddler/"

local marketProfile=loadModule(
    BASE.."pdiddler_market_profile_2026-11-02_v1_VALIDATED.lua",
    "Validated market profile"
)
local marketLogicBase=loadModule(
    ADAPTIVE_BASE.."pdiddler4_market_logic_v2_ACCEPTANCE.lua",
    "Validated market decision engine v2 acceptance metadata"
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

-- Define the webhook integration base BEFORE any module uses it.
local WEBHOOK_COMMIT="30589f1bc60fc239c503ee6e7d8f5ace80b61287"
local WEBHOOK_BASE="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..WEBHOOK_COMMIT.."/pdiddler/"

local marketPlanner=loadModule(
    ADAPTIVE_BASE.."pdiddler4_market_planner_v1_3_ACCEPTANCE.lua",
    "Market-aware planner v1.3 bounded dual-variant acceptance"
)
local acceptancePolicy=loadModule(
    ADAPTIVE_BASE.."pdiddler4_acceptance_policy_v1.lua",
    "Adaptive opener + acceptance-aware ranking policy"
)

local tradeTelemetry=loadModule(
    WEBHOOK_BASE.."pdiddler_trade_telemetry_v1.lua",
    "Completed-trade telemetry builder"
)
local FIX_COMMIT="d802519ce4a4013a977f1c651597cd50332ed441"
local FIX_BASE="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..FIX_COMMIT.."/pdiddler/"

local webhookPayload=loadModule(
    FIX_BASE.."pdiddler_trade_webhook_payload_v2_INVENTORY.lua",
    "Discord completed-trade payload v2"
)
local completionLogic=loadModule(
    WEBHOOK_BASE.."pdiddler_trade_completion_logic_v1.lua",
    "Completed-trade verification logic"
)
local webhookSender=loadModule(
    WEBHOOK_BASE.."pdiddler_trade_webhook_sender_v1.lua",
    "Discord webhook sender"
)
local NO_PLAN_GRACE_COMMIT="837bf387e5cc75469b1e43a5e74be02c19a5f742"

local part4=loadModule(
    PART4_PERF_BASE.."pdiddler4_balancer_ROTATING_v2_5_1_ADAPTIVE_PLAN_CACHE.lua",
    "Part 4 v2.5.1 adaptive plan-cache performance build"
)
local completionLogger=loadModule(
    FIX_BASE.."pdiddler_trade_completion_logger_v2_INVENTORY.lua",
    "Verified completed-trade webhook logger v2"
)

local MANUAL_GAIN_COMMIT=FIX_COMMIT
local manualGainObserver=loadModule(
    FIX_BASE.."pdiddler_manual_accept_gain_observer_v2_IPAD.lua",
    "Manual Accept + projected gain observer v2"
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
    assert(type(acceptancePolicy)=="table","acceptance policy missing")
    assert(type(acceptancePolicy.selectOpener)=="function","acceptance selectOpener missing")
    assert(type(acceptancePolicy.rankSafePlans)=="function","acceptance rankSafePlans missing")
    assert(type(acceptancePolicy.sweetenStep)=="function","acceptance sweetenStep missing")
    assert(acceptancePolicy.OpenerObserveSeconds==2.5,"adaptive opener observation mismatch")
    assert(type(part4)=="table" and type(part4.run)=="function","Part 4 run missing")
    assert(type(tradeTelemetry)=="table" and type(tradeTelemetry.build)=="function",
        "trade telemetry missing")
    assert(type(webhookPayload)=="table" and type(webhookPayload.build)=="function",
        "webhook payload missing")
    assert(type(completionLogic)=="table"
        and type(completionLogic.expectedDelta)=="function",
        "completion logic missing")
    assert(type(webhookSender)=="table" and type(webhookSender.new)=="function",
        "webhook sender missing")
    assert(type(completionLogger)=="table" and type(completionLogger.run)=="function",
        "completion logger missing")
    assert(type(manualGainObserver)=="table" and type(manualGainObserver.run)=="function",
        "manual Accept/gain observer missing")

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

    -- Equal raw/protected collision: planner must preserve BOTH market
    -- variants; acceptance policy chooses the stronger counterparty bundle.
    local equalTheir=theirBundle({item("godly","preflight100b",100)})
    plans,why=marketPlanner.buildPlans(
        {items={
            item("godly","1028",80,1,"Embersickle"),
            item("godly","813",80,1,"Pearlshine"),
        }},
        equalTheir,
        marketProfile,
        marketLogic
    )
    assert(type(plans)=="table" and plans[1],
        "equal-state variant preflight failed: "..tostring(why))
    local seenWeak=false
    local seenStrong=false
    for _,p in ipairs(plans) do
        if p.rawTotal==80 and p.protectedTotal==80
            and p.picks and p.picks[1]
        then
            local id=tostring(p.picks[1].id)
            if id=="1028" then seenWeak=true end
            if id=="813" then seenStrong=true end
        end
    end
    assert(seenWeak and seenStrong,
        "planner must preserve weak and strong equal-state variants")

    local appealRanked,appealMeta=acceptancePolicy.rankSafePlans(
        plans,
        equalTheir,
        2
    )
    assert(appealRanked[1]
        and appealRanked[1].picks[1]
        and tostring(appealRanked[1].picks[1].id)=="813",
        "strong equal-state variant must win acceptance ranking")
    assert(appealMeta and appealMeta.bestTier,
        "acceptance ranking metadata missing")

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

    -- Raw/checker identity: market metadata must use checkerId while
    -- executor picks retain the raw Weapons.Owned key.
    plans,why=marketPlanner.buildPlans(
        {items={{
            id="Iceblaster",
            checkerId="481",
            page="godly",
            name="Iceblaster",
            value=35,
            qty=1,
        }}},
        theirBundle({item("godly","23",90,1,"Candy")}),
        marketProfile,
        marketLogic
    )
    assert(type(plans)=="table" and plans[1],
        "raw/checker identity preflight failed: "..tostring(why))
    assert(plans[1].picks[1].id=="Iceblaster"
        and plans[1].picks[1].checkerId=="481",
        "planner did not preserve raw/checker identity split")
    assert(plans[1].unprofiledCopies==0
        and plans[1].givenExitScore==-2,
        "Iceblaster market metadata was not resolved through checker id")

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

    -- Adaptive opener: unreachable highest item must not be forced.
    local opener,openerMeta=acceptancePolicy.selectOpener(
        {items={
            item("chroma","1033",1800,1,"Chroma Mortal"),
            item("godly","813",80,1,"Pearlshine"),
        }},
        {items={
            item("godly","preflight100c",100),
            item("godly","preflight60",60),
        }},
        marketProfile,
        marketLogic
    )
    assert(opener and tostring(opener.id)=="813",
        "adaptive opener must choose realistic reachable item")
    assert(openerMeta and openerMeta.partnerTop4Raw==160,
        "adaptive opener partner capacity mismatch")

    local sample=webhookPayload.build({
        traderName="preflight",
        gave={{name="A",id="A",qty=1,mm2Value=20,demand=5,liquidity=0,stability="Stable"}},
        received={{name="B",id="B",qty=1,mm2Value=35,demand=6,liquidity=1,stability="Stable"}},
        giveRaw=20,
        receiveRaw=35,
        rawGain=15,
        giveProtected=20,
        receiveProtected=35,
        protectedGain=15,
        id="preflight-trade-id",
        trackedInventoryTotal=1234,
        trackedInventoryVerification="verified-stable-delta-verified",
    },"preflight")
    assert(type(sample)=="table" and type(sample.embeds)=="table",
        "webhook payload preflight failed")

    print("[PDIDDLER TEST] MARKET + WEBHOOK PREFLIGHT PASS")
end

local okPreflight,preflightErr=pcall(preflight)
if not okPreflight then
    error("[PDIDDLER TEST] MARKET PREFLIGHT FAILED: "..tostring(preflightErr))
end

local OUTGOING_RECOVERY_COMMIT=CLAIM_COMMIT
local outgoing=loadModule(
    CLAIM_BASE.."pdiddler3_outgoing_ROTATING_v16_CLAIM_PAUSE.lua",
    "Part 3 bounded unproven-send recovery + post-trade claim pause build"
)

local ok4,p4Controller=pcall(function()
    return part4.run(
        scanner,
        marketProfile,
        marketLogic,
        marketPlanner,
        acceptancePolicy,
        tradeTelemetry
    )
end)
if not ok4 then
    error("[PDIDDLER TEST] Part 4 failed to arm: "..tostring(p4Controller))
end

local okClaim,claimController=pcall(function()
    return postTradeClaim.run(scanner,claimPolicy)
end)
if not okClaim then
    error("[PDIDDLER TEST] post-trade auto-claim failed to arm: "..tostring(claimController))
end

local okWebhook,webhookController=pcall(function()
    return completionLogger.run(
        p4Controller,
        webhookSender,
        webhookPayload,
        completionLogic,
        scanner
    )
end)
if not okWebhook then
    error("[PDIDDLER TEST] webhook logger failed to arm: "..tostring(webhookController))
end

local okManual,manualGainController=pcall(function()
    return manualGainObserver.run(p4Controller)
end)
if not okManual then
    error("[PDIDDLER TEST] manual Accept/gain observer failed to arm: "..tostring(manualGainController))
end

local okOut,outController=pcall(function()
    return outgoing.run(scanner)
end)
if not okOut then
    error("[PDIDDLER TEST] Part 3 failed: "..tostring(outController))
end

print("[PDIDDLER TEST] ADAPTIVE ACCEPTANCE v1 ACTIVE")
print("[PDIDDLER TEST] PLAN CACHE PERF ACTIVE | one full planner build per exact THEIR generation")
print("[PDIDDLER TEST] POST-TRADE AUTO CLAIM ACTIVE | verified completion -> physical Claim(n/total) taps")
print("[PDIDDLER TEST] scanner + outgoing pause while received-item claims are visible")
print("[PDIDDLER TEST] WEBHOOK LOGGER ACTIVE | verified completed trades only")
print("[PDIDDLER TEST] MANUAL ACCEPT OBSERVER ACTIVE | read-only | NO CLICK")
print("[PDIDDLER TEST] PROJECTED GAIN DISPLAY ACTIVE | compact iPad banner")
print("[PDIDDLER TEST] POST-TRADE TRACKED INVENTORY AUDIT ACTIVE | canonical scanner path")
print("[PDIDDLER TEST] WEBHOOK TRADE ID FIELD ACTIVE")
print(
    "[PDIDDLER TEST] webhook URL config",
    type(ENV.PDIDDLER_DISCORD_WEBHOOK_URL)=="string"
        and ENV.PDIDDLER_DISCORD_WEBHOOK_URL~=""
        and "PRESENT"
        or "MISSING"
)
print("[PDIDDLER TEST] repeated market bundle valuation cache active | max=64")
print("[PDIDDLER TEST] Rare/Uncommon zero-value items ignored by eligible plan verification")
print("[PDIDDLER TEST] stable resolved non-empty no-plan trades hold 5s before decline")
print("[PDIDDLER TEST] no-plan hold resets on every THEIR OFFER signature change")
print("[PDIDDLER TEST] validated 190-item market snapshot active")
print("[PDIDDLER TEST] Supreme/MM2 disagreement protection active")
print("[PDIDDLER TEST] demand/stability downgrade risk active")
print("[PDIDDLER TEST] bounded dual-variant planner active | safety + appeal extremes retained")
print("[PDIDDLER TEST] adaptive opener active | 2.5s THEIR-first observation")
print("[PDIDDLER TEST] acceptance-aware safe-plan ranking active")
print("[PDIDDLER TEST] bounded sweetening active | 5s + 10s | max 2 | safety floor authoritative")
print("[PDIDDLER TEST] appeal tier D safe plans may HOLD instead of forcing mutation")
print("[PDIDDLER TEST] canonical page:id offer identity active")
print("[PDIDDLER TEST] request ownership + scanner pause retained")
print("[PDIDDLER TEST] unproven tap recovery: 15s timeout -> 15s cooldown -> one retry")
print("[PDIDDLER TEST] proven pending/trade/decline evidence still blocks duplicate resend")
print("[PDIDDLER TEST] TX abort/recovery + 15s/60s timers retained")
print("[PDIDDLER TEST] moderate overpay holds; extreme guard retained")
print("[PDIDDLER TEST] FINAL ITEM-TRADE ACCEPT IS DISABLED")

return {
    scanner=scanner,
    outgoing=outController,
    part4=p4Controller,
    webhook=webhookController,
    manualGain=manualGainController,
    postTradeClaim=claimController,
    claimPolicy=claimPolicy,
    marketProfile=marketProfile,
    marketLogic=marketLogic,
    marketLogicBase=marketLogicBase,
    marketBundleCache=marketBundleCache,
    marketPlanner=marketPlanner,
    acceptancePolicy=acceptancePolicy,
    integrationCommit=INTEGRATION_COMMIT,
    adaptiveCommit=ADAPTIVE_COMMIT,
    part4PerfCommit=PART4_PERF_COMMIT,
    noPlanCommit=NO_PLAN_COMMIT,
    webhookCommit=WEBHOOK_COMMIT,
    manualGainCommit=MANUAL_GAIN_COMMIT,
    inventoryAuditCommit=FIX_COMMIT,
    noPlanGraceCommit=NO_PLAN_GRACE_COMMIT,
    outgoingRecoveryCommit=OUTGOING_RECOVERY_COMMIT,
    claimCommit=CLAIM_COMMIT,
}
