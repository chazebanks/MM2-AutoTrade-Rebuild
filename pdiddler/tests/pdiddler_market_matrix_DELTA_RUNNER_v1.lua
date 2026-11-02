-- MM2 v2.6 market matrix TARGET-RUNTIME TEST ONLY
-- No trades, remotes, GUI mutation, server hopping, or final Accept.

local function loadPinned(url,label)
  local ok,src=pcall(function() return game:HttpGet(url,true) end)
  assert(ok and type(src)=="string" and #src>0,label.." HTTP failed: "..tostring(src))
  local fn,err=loadstring(src)
  assert(fn,label.." compile failed: "..tostring(err))
  local okRun,res=pcall(fn)
  assert(okRun,label.." runtime failed: "..tostring(res))
  assert(type(res)=="table",label.." did not return a table")
  return res
end

local profile=loadPinned(
  "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/7ec3398582d565d423bdb00ac66d7ad6f26ad06e/pdiddler/pdiddler_market_profile_2026-11-02_v1_CANDIDATE.lua",
  "market profile"
)
local M=loadPinned(
  "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/aca1dc23a1cbda074faf9c00b039fd212a0830b4/pdiddler/pdiddler4_market_logic_v1_TEST.lua",
  "market logic"
)

assert(profile.liveReady==false,"candidate profile must remain liveReady=false")
local c=profile.coverage()
assert(c.ancient==16 and c.chroma==46 and c.godly==128 and c.total==190,"profile coverage mismatch")
local n,seen=0,{}
for key,row in pairs(profile.profiles) do
  assert(not seen[key],"duplicate profile key "..tostring(key))
  seen[key]=true
  n=n+1
  assert(key==tostring(row.page)..":"..tostring(row.id),"canonical key mismatch "..tostring(key))
end
assert(n==190,"expected 190 unique profiles, got "..tostring(n))
local ember=assert(profile.get("ancient","1027"),"missing Emberscythe")
assert(ember.mm2Value==300 and ember.supremeValue==375,"Emberscythe mapping mismatch")
local mortal=assert(profile.get("chroma","1033"),"missing Chroma Mortal")
assert(mortal.mm2Value==1800 and mortal.supremeValue==1600,"Chroma Mortal mapping mismatch")
print("PASS target profile audit 190/190")

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
