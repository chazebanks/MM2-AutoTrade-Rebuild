print("MM2 ACCEPTANCE PLANNER TEST")

local logic=require("../pdiddler4_market_logic_v2_ACCEPTANCE")
local planner=require("../pdiddler4_market_planner_v1_3_ACCEPTANCE")

local function prof(mm2,sup,demand,stability)
    return {
        mm2Value=mm2,
        supremeValue=sup,
        supremeLabel=tostring(sup),
        demand=demand,
        stability=stability,
        profiled=true,
        verified=true,
    }
end

local profiles={
    ["godly:weak100"]=prof(100,100,1,"Underpaid For"),
    ["godly:strong100"]=prof(100,100,8,"Doing Well"),
    ["godly:stable120"]=prof(120,120,5,"Stable"),
    ["godly:stable98"]=prof(98,98,5,"Stable"),
}
local profile={liveReady=true}
function profile.get(page,id)
    return profiles[tostring(page)..":"..tostring(id)]
end

local function item(id,value,qty)
    return {
        page="godly",
        id=id,
        checkerId=id,
        name=id,
        value=value,
        qty=qty or 1,
    }
end

local their=logic.bundleAssessment({
    item("stable120",120),
},"theirs",profile)

local plans,why=planner.buildPlans({
    items={
        item("weak100",100),
        item("strong100",100),
    }
},their,profile,logic)
assert(type(plans)=="table","planner failed: "..tostring(why))

local seenWeak=false
local seenStrong=false
for _,plan in ipairs(plans) do
    if plan.rawTotal==100 and plan.protectedTotal==100 then
        local id=plan.picks and plan.picks[1] and plan.picks[1].id
        if id=="weak100" then seenWeak=true end
        if id=="strong100" then seenStrong=true end
    end
end

assert(seenWeak,"planner must preserve low-exit same-value variant for safety/quality-upgrade behavior")
assert(seenStrong,"planner must preserve high-exit same-value variant for counterparty appeal")

-- The variant bound must stay small: at most two same raw/protected/slot
-- packs for this collision, not combinatorial retention.
local count=0
for _,plan in ipairs(plans) do
    if plan.rawTotal==100 and plan.protectedTotal==100 and plan.units==1 then
        count+=1
    end
end
assert(count<=2,"same-state retention must remain bounded to two variants")

print("PASS acceptance planner dual-variant retention")
