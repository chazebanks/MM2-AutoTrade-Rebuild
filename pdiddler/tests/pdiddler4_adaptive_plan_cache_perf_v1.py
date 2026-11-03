from pathlib import Path

p=Path("pdiddler/pdiddler4_balancer_ROTATING_v2_5_1_ADAPTIVE_PLAN_CACHE.lua")
assert p.exists(), "adaptive plan-cache Part 4 build missing"
src=p.read_text()

required=[
    "cachedPlanSig",
    "cachedPlanGeneration",
    "cachedSafePlans",
    "cachedPlanWhy",
    "local function clearPlanCache",
    "local function safePlansForGeneration",
    "cachedPlanSig==theirEval.signature",
    "cachedPlanGeneration==offerGeneration",
    "marketPlans(ownInv,theirEval)",
    "safePlansForGeneration(theirEval)",
    "PLAN CACHE MISS",
]
for token in required:
    assert token in src, f"missing plan-cache performance token: {token}"

# The expensive planner must exist exactly once in the generation-cache helper.
assert src.count("marketPlans(ownInv,theirEval)") == 1, (
    "full market planner must be invoked from exactly one cache-miss site"
)

helper=src.index("local function safePlansForGeneration")
planner=src.index("marketPlans(ownInv,theirEval)",helper)
rank=src.index("ACCEPTANCE_POLICY.rankSafePlans")
assert helper < planner < rank, "safe plans must be cached before acceptance reranking"

# Empty/new signature paths must invalidate cached plans.
empty=src.index("if theirEval.slots==0 then")
sig=src.index("if theirEval.signature~=lastTheirSig then")
assert src.index("clearPlanCache()",empty) < sig, "empty THEIR offer must clear plan cache"
assert src.index("clearPlanCache()",sig) < rank, "new THEIR signature must clear plan cache"

# Sweetening must re-rank cached plans, not rebuild the planner.
sweet=src.index("local currentSweetenStep=ACCEPTANCE_POLICY.sweetenStep")
cached_get=src.index("safePlansForGeneration(theirEval)",sweet)
assert sweet < cached_get < rank
sweet_block=src[sweet:rank]
assert "marketPlans(ownInv,theirEval)" not in sweet_block, (
    "sweetening path must not rebuild full planner"
)

# No-plan grace must be able to loop while reusing cached empty plans.
no_plan=src.index("if #plans==0 then")
grace=src.index("held<C.NoPlanNegotiationGrace",no_plan)
assert no_plan < grace
assert "safePlansForGeneration(theirEval)" not in src[no_plan:grace], (
    "no-plan countdown itself must not invoke plan generation again"
)

# Existing safety/performance invariants remain.
for token in [
    "NoPlanNegotiationGrace=5.0",
    "EmptyTimeout=15.0",
    "ActiveOfferWindow=60.0",
    "LoopDelay=0.12",
    "RecoveryMaxAttemptsPerOffer=2",
    "ourAcceptedShown",
]:
    assert token in src, f"missing retained invariant: {token}"

for forbidden in [
    "AcceptTrade:FireServer",
    'physicalClick(button,"Accept',
    'physicalClick(button,"Confirm',
    "firesignal(",
    "task.delay(",
]:
    assert forbidden not in src, f"forbidden mutation/stale callback: {forbidden}"

print("PASS adaptive plan-cache lag regression")
