local root=os.getenv and (os.getenv("MM2_INTEGRATION_ROOT")) or "."

local logic=assert(dofile(root.."/pdiddler/pdiddler4_market_logic_v1_TEST.lua"))
local planner=assert(dofile(root.."/pdiddler/pdiddler4_market_planner_v1.lua"))

local function prof(mm2,sup,demand,stability)
    return {
        mm2Value=mm2,
        supremeValue=sup,
        demand=demand,
        stability=stability,
        profiled=true,
        verified=true,
    }
end

local profiles={
    ["godly:stable20"]=prof(20,20,5,"Stable"),
    ["godly:stable90"]=prof(90,90,5,"Stable"),
    ["godly:stable100"]=prof(100,100,5,"Stable"),
    ["godly:stable105"]=prof(105,105,5,"Stable"),
    ["godly:stable120"]=prof(120,120,5,"Stable"),
    ["godly:stable230"]=prof(230,230,5,"Stable"),
    ["godly:stable270"]=prof(270,270,5,"Stable"),
    ["godly:weak43"]=prof(43,43,1,"Underpaid For"),
    ["godly:weak44"]=prof(44,44,1,"Underpaid For"),
    ["godly:weak43b"]=prof(43,43,1,"Underpaid For"),
    ["godly:weak100"]=prof(100,100,1,"Underpaid For"),
    ["godly:strong100"]=prof(100,100,8,"Doing Well"),
    ["godly:stable300"]=prof(300,300,5,"Stable"),
    ["ancient:1027"]=prof(300,375,5,"Fluctuating"),
    ["godly:stable400"]=prof(400,400,5,"Stable"),
}

local profile={liveReady=true}
function profile.get(page,id)
    return profiles[tostring(page)..":"..tostring(id)]
end

local function item(page,id,value,qty,name)
    return {
        page=page or "godly",
        id=tostring(id),
        name=name or tostring(id),
        value=value,
        qty=qty or 1,
    }
end

local function bundle(items,side)
    return logic.bundleAssessment(items,side,profile)
end

local function plans(inv,theirItems)
    local their=bundle(theirItems,"theirs")
    local out,why=planner.buildPlans(inv,their,profile,logic)
    assert(type(out)=="table","planner failed: "..tostring(why))
    return out
end

-- Moderate +40: keep closest safe 230 plan.
local p=plans(
    {items={item("godly","stable230",230)}},
    {item("godly","stable270",270)}
)
assert(p[1] and p[1].rawTotal==230,"moderate 230->270 must keep 230 plan")
assert(p[1].rawProfit==40,"moderate plan profit must be +40")

-- Extreme fixture: 20 opening can move to 90 while preserving +15.
p=plans(
    {items={
        item("godly","stable20",20),
        item("godly","stable90",90),
    }},
    {item("godly","stable105",105)}
)
assert(p[1] and p[1].rawTotal==90,"105 offer should produce closest safe 90 plan")
assert(p[1].rawProfit==15,"90->105 target profit must be +15")

-- Weak +30 big downgrade is not enough.
p=plans(
    {items={item("godly","stable100",100)}},
    {
        item("godly","weak43",43),
        item("godly","weak44",44),
        item("godly","weak43b",43),
    }
)
assert(#p==0,"weak 100->130 downgrade must have no safe plan")

-- Equal raw/protected state must give away weaker OUR inventory.
p=plans(
    {items={
        item("godly","weak100",100),
        item("godly","strong100",100),
    }},
    {item("godly","stable120",120)}
)
assert(p[1] and p[1].picks[1].id=="weak100",
    "equal-value planner must prefer giving away weaker inventory")

-- Same raw but materially different protected values must survive as separate states.
p=plans(
    {items={
        item("godly","stable300",300),
        item("ancient","1027",300,1,"Emberscythe"),
    }},
    {item("godly","stable400",400)}
)
local seen={}
for _,plan in ipairs(p) do
    if plan.rawTotal==300 then
        seen[plan.protectedTotal]=true
    end
end
assert(seen[300] and seen[375],
    "same raw total with 300 vs 375 protected must remain distinct planner states")

print("PASS market planner integration fixtures")
