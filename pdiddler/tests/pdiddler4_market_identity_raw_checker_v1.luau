-- Part 4 raw-id / checker-id market identity regression
-- Pure Luau. Market metadata must use checkerId; executor picks must keep raw id.

local Planner=require("../pdiddler4_market_planner_v1_2_MARKET_IDENTITY")
local Logic=require("../pdiddler4_market_logic_v1_TEST")

local profiles={
    ["godly:481"]={
        page="godly",id="481",name="Iceblaster",
        mm2Value=35,supremeValue=33,demand=1,stability="Stable",
        profiled=true,verified=true,
    },
    ["ancient:1027"]={
        page="ancient",id="1027",name="Emberscythe",
        mm2Value=300,supremeValue=375,demand=3,stability="Stable",
        profiled=true,verified=true,
    },
}

local profile={
    get=function(page,id)
        return profiles[tostring(page)..":"..tostring(id)]
    end,
}

local function their(raw)
    return {
        rawTotal=raw,
        protectedTotal=raw,
        eligibleCopies=1,
        exitScore=0,
        riskPoints=0,
        confidence=true,
        materialDisagreementValue=0,
        disputedCopies=0,
        unprofiledCopies=0,
    }
end

do
    local plans,why=Planner.buildPlans(
        {items={{
            id="Iceblaster",
            checkerId="481",
            page="godly",
            name="Iceblaster",
            value=35,
            qty=1,
        }}},
        their(60),
        profile,
        Logic
    )

    assert(type(plans)=="table" and plans[1],tostring(why))
    local p=plans[1]
    assert(p.picks[1].id=="Iceblaster",
        "executor pick must preserve raw owned key")
    assert(p.picks[1].checkerId=="481",
        "plan must retain canonical market checker id")
    assert(p.unprofiledCopies==0,
        "checker-id profile must be recognized")
    assert(p.givenExitScore==-2,
        "Iceblaster demand/stability exit score must come from checker-id profile")
end

do
    local plans,why=Planner.buildPlans(
        {items={{
            id="Emberscythe",
            checkerId="1027",
            page="ancient",
            name="Emberscythe",
            value=300,
            qty=1,
        }}},
        their(500),
        profile,
        Logic
    )

    assert(type(plans)=="table" and plans[1],tostring(why))
    local p=plans[1]
    assert(p.picks[1].id=="Emberscythe")
    assert(p.picks[1].checkerId=="1027")
    assert(p.rawTotal==300)
    assert(p.protectedTotal==375,
        "OUR material Supreme disagreement must protect at 375")
    assert(p.disputedCopies==1)
    assert(p.unprofiledCopies==0)
end

print("PASS Part 4 raw/checker market identity regression")
