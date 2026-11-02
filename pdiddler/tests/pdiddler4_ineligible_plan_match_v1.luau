-- Regression test: non-eligible Rare/Uncommon items must not freeze
-- Part 4 plan verification.
--
-- The production bug this catches:
-- plan verification used every live count entry, including ineligible:* items,
-- while planner picks contain only eligible Ancient/Godly/Chroma items.

local Planner=require("../pdiddler4_market_planner_v1_1")

local plan={
    rawTotal=100,
    picks={
        {page="godly",id="wanted",qty=1},
    },
}

local liveWithRare={
    rawTotal=100,
    unresolved={},
    counts={
        ["godly:wanted"]=1,
        ["ineligible:rareKnife"]=1,
    },
}

assert(
    Planner.planMatches(plan,liveWithRare)==true,
    "ineligible Rare/Uncommon extra item must not block a valid eligible plan"
)

local liveWithTwoIneligible={
    rawTotal=100,
    unresolved={},
    counts={
        ["godly:wanted"]=1,
        ["ineligible:rareKnife"]=1,
        ["ineligible:uncommonGun"]=2,
    },
}

assert(
    Planner.planMatches(plan,liveWithTwoIneligible)==true,
    "any number of zero-value ineligible items must be ignored by plan verification"
)

local liveWithExtraEligible={
    rawTotal=120,
    unresolved={},
    counts={
        ["godly:wanted"]=1,
        ["godly:extra"]=1,
        ["ineligible:rareKnife"]=1,
    },
}

assert(
    Planner.planMatches(plan,liveWithExtraEligible)==false,
    "extra eligible item must still invalidate the plan"
)

local liveMissingEligible={
    rawTotal=0,
    unresolved={},
    counts={
        ["ineligible:rareKnife"]=1,
    },
}

assert(
    Planner.planMatches(plan,liveMissingEligible)==false,
    "missing planned eligible item must invalidate the plan"
)

local liveUnresolved={
    rawTotal=100,
    unresolved={{name="Mystery",reason="unresolved"}},
    counts={
        ["godly:wanted"]=1,
        ["ineligible:rareKnife"]=1,
    },
}

assert(
    Planner.planMatches(plan,liveUnresolved)==false,
    "unresolved live item must remain a hard verification failure"
)

print("PASS ineligible Rare/Uncommon items do not freeze plan verification")
