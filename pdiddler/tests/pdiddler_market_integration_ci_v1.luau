-- GitHub Actions Luau 0.745 integration runner.
-- Pure modules only; no Roblox services/remotes/UI.
print("MM2 MARKET INTEGRATION CI")

do
    local M=require("../pdiddler4_market_logic_v1_TEST")
local pass=0
local function ok(cond,msg) assert(cond,msg or "assertion failed") end
local function eq(a,b,msg) assert(a==b,(msg or "eq").." expected="..tostring(b).." got="..tostring(a)) end
local function near(a,b,e,msg) assert(math.abs(a-b)<=e,(msg or "near").." expected="..tostring(b).." got="..tostring(a)) end
local function item(id,value,qty,page,name) return {page=page or "godly",id=tostring(id),name=name or tostring(id),value=value,qty=qty or 1} end
local function p(mm2,sup,demand,stability,verified) return {mm2Value=mm2,supremeValue=sup,demand=demand,stability=stability,profiled=true,verified=verified~=false} end
local profiles={
  ["godly:stable100"]=p(100,100,5,"Stable"),
  ["godly:stable120"]=p(120,120,5,"Stable"),
  ["godly:stable230"]=p(230,230,5,"Stable"),
  ["godly:stable270"]=p(270,270,5,"Stable"),
  ["godly:stable20"]=p(20,20,5,"Stable"),
  ["godly:stable105"]=p(105,105,5,"Stable"),
  ["godly:weak50a"]=p(50,50,1,"Underpaid For"),
  ["godly:weak50b"]=p(50,50,1,"Underpaid For"),
  ["godly:weak43"]=p(43,43,1,"Underpaid For"),
  ["godly:weak44"]=p(44,44,1,"Underpaid For"),
  ["godly:weak43b"]=p(43,43,1,"Underpaid For"),
  ["godly:strong98"]=p(98,98,8,"Doing Well"),
  ["godly:fluct120"]=p(120,120,5,"Fluctuating"),
  ["godly:strong70"]=p(70,70,8,"Doing Well"),
  ["godly:weak50"]=p(50,50,1,"Underpaid For"),
  ["ancient:1027"]=p(300,375,5,"Fluctuating"),
  ["chroma:1033"]=p(1800,1600,5,"Doing Well"),
  ["godly:tiny"]=p(5,7,5,"Stable"),
}
local function lookup(page,id) return profiles[tostring(page)..":"..tostring(id)] end
local function B(items,side,custom) return M.bundleAssessment(items,side,custom or lookup) end
local function D(ours,theirs) return M.tradeDecision(ours,theirs) end
local function case(n,fn) fn(); pass=pass+1; print("PASS case "..n) end

case(1,function()
  local ours=B({item("stable100",100)},"ours")
  local theirs=B({item("weak50a",50,2)},"theirs")
  local d=D(ours,theirs)
  eq(d.ok,false,"same raw weaker inventory rejected")
  ok(d.requiredProfit>15,"weak receive raises requirement")
end)

case(2,function()
  local ours=B({item("weak50a",50),item("weak50b",50)},"ours")
  local theirs=B({item("strong98",98)},"theirs")
  local d=D(ours,theirs)
  eq(d.ok,true,"controlled upgrade passes")
  eq(d.mode,"quality-upgrade","quality upgrade mode")
  ok(d.rawProfit<0 and -d.rawProfit<=3,"loss capped")
  ok(d.qualityGain>=2,"quality gain material")
end)

case(3,function()
  local ours=B({item("stable100",100)},"ours")
  local theirs=B({item("weak43",43),item("weak44",44),item("weak43b",43)},"theirs")
  local d=D(ours,theirs)
  eq(d.rawProfit,30,"raw +30")
  eq(d.kind,"BIG DOWNGRADE","big downgrade")
  ok(d.requiredProfit>30,"weak downgrade premium above 30")
  eq(d.ok,false,"marginal junk downgrade rejected")
end)

case(4,function()
  local o=B({item("1027",300,1,"ancient","Emberscythe")},"ours")
  local t=B({item("1027",300,1,"ancient","Emberscythe")},"theirs")
  eq(o.protectedTotal,375,"our Emberscythe high protection")
  eq(t.protectedTotal,300,"their Emberscythe low credit")
end)

case(5,function()
  local ours=B({item("stable100",100)},"ours")
  local stable=D(ours,B({item("stable120",120)},"theirs"))
  local fluct=D(ours,B({item("fluct120",120)},"theirs"))
  ok(fluct.requiredProfit>stable.requiredProfit,"fluctuating requires more compensation")
  ok(fluct.marketPremium>stable.marketPremium,"fluctuating premium positive")
end)

case(6,function()
  local d=D(B({item("stable230",230)},"ours"),B({item("stable270",270)},"theirs"))
  eq(d.ok,true,"moderate +40 remains safe")
  eq(d.rawProfit,40,"moderate profit preserved")
  eq(d.mode,"profit","profit mode")
end)

case(7,function()
  local d=D(B({item("stable20",20)},"ours"),B({item("stable105",105)},"theirs"))
  eq(d.ok,true,"extreme input safe")
  eq(d.rawProfit,85,"extreme raw profit")
  near(d.ratio,5.25,1e-9,"ratio exposed")
end)

case(8,function()
  local ours=B({item("stable100",100)},"ours")
  local first=D(ours,B({item("stable120",120)},"theirs"))
  local second=D(ours,B({item("stable105",105)},"theirs"))
  eq(first.ok,true,"first safe")
  eq(second.ok,false,"lower replacement recomputed and rejected")
  eq(second.rawProfit,5,"second uses new offer")
end)

case(9,function()
  local ours=B({item("stable100",100)},"ours")
  local missing=B({item("unknown120",120)},"theirs",function() return nil end)
  local d=D(ours,missing)
  eq(missing.confidence,false,"missing confidence false")
  eq(d.ok,true,"raw safety can still pass missing metadata")
  eq(d.mode,"profit","missing metadata cannot become quality upgrade")
  local weakOurs=B({item("weak50a",50),item("weak50b",50)},"ours")
  local missing98=B({item("unknown98",98)},"theirs",function() return nil end)
  local q=D(weakOurs,missing98)
  eq(q.ok,false,"missing metadata cannot earn upgrade exception")
end)

case(10,function()
  local ours=B({item("stable100",100)},"ours")
  local mixed=B({item("strong70",70),item("weak50",50)},"theirs")
  ok(mixed.riskPoints>0,"weak piece contributes risk")
  ok(mixed.exitScore<3,"bundle not represented by strong item only")
  local d=D(ours,mixed)
  ok(d.marketPremium>0,"mixed weak bundle carries premium")
end)

case(11,function()
  local ours=B({item("stable100",100)},"ours")
  local theirs=B({item("stable120",120)},"theirs")
  local d=D(ours,theirs)
  eq(d.ok,true,"ranking fixture decision safe")
  ok(type(d.qualityGain)=="number","decision exposes ranking quality data")
end)

case(12,function()
  local a=M.itemAssessment(item("tiny",5),"ours",profiles["godly:tiny"])
  eq(a.materialDisagreement,false,"5 vs 7 not material")
  eq(a.protectedUnitValue,5,"tiny pct disagreement no high protection")
end)

case(13,function()
  local ours=B({item("1033",1800,1,"chroma","Chroma Mortal")},"ours")
  local theirs=B({item("1033",1800,1,"chroma","Chroma Mortal")},"theirs")
  eq(ours.protectedTotal,1800,"ours higher supported stays 1800")
  eq(theirs.protectedTotal,1600,"theirs lower supported credited 1600")
  ok(ours.disputedCopies==1 and theirs.disputedCopies==1,"material dispute marked")
end)

case(14,function()
  local unknown=B({item("ambiguous",100)},"theirs",function() return nil end)
  eq(unknown.protectedTotal,100,"unknown identity baseline only")
  eq(unknown.unprofiledCopies,1,"unknown profile unavailable")
  eq(unknown.exitScore,0,"no guessed quality")
end)

assert(pass==14,"expected 14 cases, got "..tostring(pass))
print("PASS matrix 14/14")


local function plan(id,mode,rawTotal,rawProfit,exitScore,disputed,unprofiled,pickCount)
  local picks={}
  for i=1,(pickCount or 1) do picks[i]={page="godly",id=id..":"..i} end
  return {
    id=id,mode=mode,rawTotal=rawTotal,rawProfit=rawProfit,
    protectedProfit=rawProfit,givenExitScore=exitScore,
    disputedCopies=disputed or 0,unprofiledCopies=unprofiled or 0,picks=picks,
  }
end
local theirRankBundle={rawTotal=300}

local ranked=M.rankPlans({
  plan("quality","quality-upgrade",300,-2,-4,0,0,1),
  plan("profit","profit",280,20,0,0,0,1),
},theirRankBundle)
eq(ranked[1].id,"profit","profit ranks above quality-upgrade")

ranked=M.rankPlans({
  plan("lowOffer","profit",260,40,-5,0,0,1),
  plan("highOffer","profit",280,20,3,0,0,1),
},theirRankBundle)
eq(ranked[1].id,"highOffer","outside similarity window higher safe our raw first")

ranked=M.rankPlans({
  plan("strongGiven","profit",280,20,3,0,0,1),
  plan("weakGiven","profit",276,24,-3,0,0,1),
},theirRankBundle)
eq(ranked[1].id,"weakGiven","inside window give lower exit-quality inventory first")

ranked=M.rankPlans({
  plan("disputed","profit",280,20,0,1,0,1),
  plan("clean","profit",280,20,0,0,0,1),
},theirRankBundle)
eq(ranked[1].id,"clean","fewer disputed copies wins tie")

ranked=M.rankPlans({
  plan("unprofiled","profit",280,20,0,0,1,1),
  plan("profiled","profit",280,20,0,0,0,1),
},theirRankBundle)
eq(ranked[1].id,"profiled","fewer unprofiled copies wins tie")

ranked=M.rankPlans({
  plan("zeta","profit",280,20,0,0,0,4),
  plan("alpha","profit",280,20,0,0,0,1),
},theirRankBundle)
eq(ranked[1].id,"alpha","quantity alone does not improve rank; canonical tie-break wins")

local first=M.rankPlans({
  plan("beta","profit",280,20,0,0,0,2),
  plan("alpha","profit",280,20,0,0,0,2),
},theirRankBundle)
local second=M.rankPlans({
  plan("beta","profit",280,20,0,0,0,2),
  plan("alpha","profit",280,20,0,0,0,2),
},theirRankBundle)
eq(first[1].id,second[1].id,"ranking deterministic across repeated runs")
eq(first[1].id,"alpha","canonical ids final tie-break")

print("PASS ranking tests")

end

do
    local logic=require("../pdiddler4_market_logic_v1_TEST")
    local planner=require("../pdiddler4_market_planner_v1")
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

end

do
    local candidate=require("../pdiddler_market_profile_2026-11-02_v1_CANDIDATE")
    local validated=require("../pdiddler_market_profile_2026-11-02_v1_VALIDATED")
assert(type(validated)=="table","validated profile must return table")
assert(validated.liveReady==true,"validated profile must be liveReady=true")
assert(validated.validation and validated.validation.deltaMatrixPass==true,"Delta matrix validation metadata missing")

local function keyset(t)
  local out,n={},0
  for k in pairs(t) do out[k]=true n=n+1 end
  return out,n
end

local ck,cn=keyset(candidate.profiles)
local vk,vn=keyset(validated.profiles)
assert(cn==190 and vn==190,"expected 190 candidate and validated rows")
for k in pairs(ck) do assert(vk[k],"validated missing "..k) end
for k in pairs(vk) do assert(ck[k],"validated extra "..k) end

local fields={"page","id","name","mm2Value","supremeValue","supremeLabel","demand","stability","profiled","verified","disagreementPct"}
for k,c in pairs(candidate.profiles) do
  local v=assert(validated.profiles[k],"missing "..k)
  for _,field in ipairs(fields) do
    local a,b=c[field],v[field]
    if type(a)=="number" and type(b)=="number" then
      assert(math.abs(a-b)<1e-9,k.." field mismatch "..field)
    else
      assert(a==b,k.." field mismatch "..field.." candidate="..tostring(a).." validated="..tostring(b))
    end
  end
end

local c=validated.coverage()
assert(c.ancient==16 and c.chroma==46 and c.godly==128 and c.total==190,"validated coverage mismatch")
print("PASS validated profile promotion 190/190 exact")

end

print("PASS MM2 MARKET INTEGRATION CI")
