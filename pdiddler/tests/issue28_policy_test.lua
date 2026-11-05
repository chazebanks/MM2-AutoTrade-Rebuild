-- Complete production policy; exact-value scenarios below use explicitly synthetic
-- verified price fixtures. Real-value comparisons use the pinned November4 source.
local P=dofile(arg[1] or 'pdiddler/pdiddler4_supreme_policy_v10_INVENTORY_GROWTH.lua')
local passed,failed=0,0
local function test(label,fn)
 local ok,why=pcall(fn)
 if ok then passed=passed+1;print('PASS '..label) else failed=failed+1;print('FAIL '..label..': '..tostring(why)) end
end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function close(a,b) assert(math.abs(a-b)<1e-6,tostring(a)..' ~= '..tostring(b)) end
local function inventory(items) return {items=items,unmapped=0,unpriced=0,badQty=0} end
local function fixture()
 local rows={};local profile={version='explicit-synthetic-price-fixture',get=function(page,id) return rows[page..':'..id] end,isFresh=function() return true end}
 local function item(id,value,demand,stability,qty,kind,page)
  page=page or 'godly';rows[page..':'..id]={page=page,id=id,name=id,supremeValue=value,demand=demand or 3,stability=stability or 'Stable',verified=true}
  return {page=page,id='raw_'..id,checkerId=id,name=id,value=999999,qty=qty or 1,cat='Weapons',type=kind or 'Knife'}
 end
 local function market(items) return P.bundleAssessment(items,'theirs',profile) end
 local function plans(own,their) return P.buildPlans(inventory(own),market(their),profile,P) end
 return item,market,plans,profile
end
local source=dofile('pdiddler/snapshots/pdiddler_supreme_snapshot_2026_11_04.lua')
local current={};for k,v in pairs(source) do current[k]=v end
current.isFresh=function() return source.isFresh(source.observedAtEpoch) end
local function real(page,id,kind,qty)
 local r=assert(source.get(page,tostring(id)))
 return {page=page,id='actual_'..page..'_'..id,checkerId=tostring(id),name=r.name,value=999999,qty=qty or 1,cat='Weapons',type=kind or 'Knife'}
end
local function select(own,their,profile)
 profile=profile or current
 local m=P.bundleAssessment(their,'theirs',profile)
 local ps,why=P.buildPlans(inventory(own),m,profile,P)
 local chosen,reason,meta=P.selectInitialOffer(ps,m.rawTotal,m)
 return chosen,ps,m,reason,meta,why
end
local function physical(ps,own,their)
 local quantities={};for _,it in ipairs(own) do quantities[it.page..':'..it.id]=it.qty end
 local incoming={};for _,it in ipairs(their) do incoming[it.page..':'..it.checkerId]=true end
 for _,p in ipairs(ps) do
  assert(p.ok and p.rawProfit>=15 and p.protectedProfit>=15 and p.units>=1 and p.units<=4)
  local copies=0
  for _,it in ipairs(p.picks) do
   assert(it.qty>=1 and it.qty<=assert(quantities[it.page..':'..it.id]),'invented ownership')
   assert(not incoming[it.page..':'..it.checkerId],'canonical mirror')
   copies=copies+it.qty
  end
  eq(copies,p.units)
 end
end

test('low-mid initial quote can approach +25 beyond obsolete sixty-percent ceiling',function()
 local it,m,plans=fixture();local their={it('Their100',100)}
 local ps=plans({it('Small40',40),it('Attractive75',75)},their)
 local selected=assert(P.selectInitialOffer(ps,100,m(their)))
 eq(selected.rawTotal,75);eq(selected.rawProfit,25)
end)

test('size preference uses practical15to25 on small trades and proportional high-value gains',function()
 assert(type(P.profitPreference)=='function','transparent profit preference metadata missing')
 for _,pair in ipairs({{35,15},{60,15},{100,25},{200,30},{500,75},{1295,194.25}}) do
  local preference=P.profitPreference(pair[1],{confidence=true,rawTotal=pair[1],exitScore=3,riskPoints=0},{givenExitScore=3,givenRisk=0})
  close(preference.targetProfit,pair[2]);eq(preference.verifiedMarket,true)
  close(preference.reserveFloor,15)
 end
end)

test('source-condition risk raises a high-value profit preference without changing Supreme totals',function()
 assert(type(P.profitPreference)=='function','transparent profit preference metadata missing')
 local stable=P.profitPreference(500,{confidence=true,rawTotal=500,exitScore=3,riskPoints=0},{givenExitScore=3,givenRisk=0})
 local exposed=P.profitPreference(500,{confidence=true,rawTotal=500,exitScore=3,riskPoints=1},{givenExitScore=3,givenRisk=0})
 close(stable.targetProfit,75);close(exposed.targetProfit,125);close(exposed.reserveFloor,65)
 local unknown=P.profitPreference(500,nil,{givenExitScore=3,givenRisk=0})
 eq(unknown.verifiedMarket,false)
end)

test('real Batwing42 reply prefers stable owned18 opener over unsafe40',function()
 local own={real('chroma',8,'Gun'),real('godly',572,'Gun')}
 local their={real('ancient',3,'Knife'),real('godly',39,'Gun')}
 local chosen=assert(P.selectOpener(inventory(own),inventory(their),current))
 eq(chosen.checkerId,'572');eq(chosen.value,18)
end)

local cases={
 {35,{real('chroma',527,'Gun')}},
 {60,{real('ancient',3),real('godly',39,'Gun')}},
 {100,{real('godly',23),real('godly',472,'Gun')}},
 {200,{real('godly',859),real('godly',512)}},
 {500,{real('ancient',526,'Gun'),real('godly',955,'Gun')}},
 {1295,{real('godly',833,'Gun'),real('godly',832),real('godly',23),real('godly',20,'Gun')}},
}
for _,case in ipairs(cases) do
 test('real source comparison '..case[1]..' enumerates only physically owned safe combinations',function()
  local own={real('godly',572,'Gun'),real('godly',27),real('godly',481,'Gun'),real('godly',812),real('godly',859),real('godly',794),real('godly',714),real('ancient',526,'Gun')}
  local before={};for i,it in ipairs(own) do before[i]={value=it.value,qty=it.qty} end
  local chosen,ps,m=select(own,case[2]);eq(m.rawTotal,case[1]);assert(chosen and #ps>0)
  physical(ps,own,case[2]);assert(chosen.rawProfit>=15)
  for i,it in ipairs(own) do eq(it.value,before[i].value);eq(it.qty,before[i].qty) end
  if P.strategyFacts then
   local facts=P.strategyFacts(chosen,m)
   close(facts.targetDistance,math.abs(chosen.rawProfit-facts.targetProfit))
   print('COMPARE real received='..m.rawTotal..' owned-give='..chosen.rawTotal..' verified-profit='..chosen.rawProfit..' target='..facts.targetProfit..' distance='..facts.targetDistance..' candidates='..#ps)
  else
   print('COMPARE real received='..m.rawTotal..' owned-give='..chosen.rawTotal..' verified-profit='..chosen.rawProfit..' candidates='..#ps)
  end
 end)
end

test('real1295 receipt cannot fabricate1260 when actual owned maximum is405',function()
 local own={real('godly',1032,'Knife',2),real('godly',1031)}
 local their=cases[#cases][2]
 local chosen,ps,m=select(own,their);eq(m.rawTotal,1295);assert(chosen)
 for _,p in ipairs(ps) do assert(p.rawTotal<=405 and p.units<=3) end
 eq(chosen.rawTotal,405);eq(chosen.rawProfit,890);physical(ps,own,their)
end)

test('exact100 knife can gain three useful125 knives without fabricated quantities',function()
 local it,m,plans=fixture();local own={it('Our100',100,3)}
 local their={it('Received45',45,3),it('Received42',42,3),it('Received38',38,3)}
 local ps=plans(own,their);eq(#ps,1);local chosen=assert(P.selectInitialOffer(ps,125,m(their)))
 eq(chosen.rawTotal,100);eq(chosen.rawProfit,25);eq(chosen.units,1);physical(ps,own,their)
 local got=m(their);eq(got.eligibleCopies,3);close(got.exitScore,3);eq(got.riskPoints,0)
 assert(type(P.strategyFacts)=='function','bounded useful-knife diagnostics missing')
 local facts=P.strategyFacts(chosen,got);eq(facts.netUsefulKnives,2);eq(facts.reserveMet,true)
end)

test('low demand140 receipt remains visibly poorer quality despite greater numeric gain',function()
 local it,m,plans=fixture();local own={it('Our100',100,3)};local their={it('LowDemand140',140,1,'Underpaid For')}
 local ps=plans(own,their);local got=m(their);local chosen=assert(P.selectInitialOffer(ps,140,got))
 eq(chosen.rawProfit,40);close(got.exitScore,1);eq(got.riskPoints,1)
 local decision=P.tradeDecision(m(own),got);assert(decision.ok);eq(decision.rawProfit,40);eq(decision.qualityGain,-2)
end)

test('two100 knives may consolidate to one desirable130 item with strict net gain',function()
 local it,m,plans=fixture();local own={it('Our50A',50,2),it('Our50B',50,2)};local their={it('Desirable130',130,5)}
 local ps=plans(own,their);local combined
 for _,p in ipairs(ps) do if p.rawTotal==100 then combined=p end end
 assert(combined);eq(combined.rawProfit,30);eq(combined.units,2)
 assert(P.tradeDecision({rawTotal=100,confidence=true,exitScore=2},m(their)).ok)
 eq(m(their).eligibleCopies,1);eq(m(their).exitScore,5)
 assert(type(P.strategyFacts)=='function','bounded useful-knife diagnostics missing')
 eq(P.strategyFacts(combined,m(their)).netUsefulKnives,-1)
end)

test('low-demand numerical140 gain cannot outrank preserving valuable100 quality',function()
 local it,m,plans=fixture();local own={it('Valuable100',100,8),it('Useful80',80,3)}
 local their={it('LowDemand140',140,1,'Stable')};local ps=plans(own,their)
 local chosen=assert(P.selectInitialOffer(ps,140,m(their)));eq(chosen.rawTotal,80);eq(chosen.rawProfit,60)
 local valuable
 for _,plan in ipairs(ps) do if plan.rawTotal==100 then valuable=plan end end
 assert(valuable);local facts=P.strategyFacts(valuable,m(their))
 close(facts.reserveFloor,43);eq(facts.reserveMet,false)
end)

test('multiple low-demand knives do not justify donating a high-tier stable asset',function()
 local it,m,plans=fixture();local own={it('HighTier1000',1000,8),it('Tradable800',800,1,'Stable',1,'Gun')}
 local their={it('LowA',360,1),it('LowB',350,1),it('LowC',350,1)}
 local ps=plans(own,their);local chosen=assert(P.selectInitialOffer(ps,1060,m(their)))
 eq(chosen.rawTotal,800);eq(chosen.rawProfit,260)
 local expensive;for _,p in ipairs(ps) do if p.rawTotal==1000 then expensive=p end end
 assert(expensive and P.strategyFacts(expensive,m(their)).reserveMet==false)
end)

test('economic and quality ties can preserve one knife by giving an equivalent gun',function()
 local it,m,plans=fixture();local knife=it('AKnife',100,3);local gun=it('ZGun',100,3,'Stable',1,'Gun')
 local their={it('Receive45',45,3),it('Receive42',42,3),it('Receive38',38,3)}
 local ps=plans({knife,gun},their);eq(#ps,2)
 local chosen=assert(P.selectInitialOffer(ps,125,m(their)));eq(chosen.picks[1].type,'Gun')
 eq(P.strategyFacts(chosen,m(their)).netUsefulKnives,3)
 local reverse=plans({gun,knife},their);eq(assert(P.selectInitialOffer(reverse,125,m(their))).key,chosen.key)
end)

test('useful knife count cannot overrule a better attainable value margin',function()
 local it,m,plans=fixture();local their={it('Receive45',45,3),it('Receive42',42,3),it('Receive38',38,3)}
 local ps=plans({it('Knife100',100,3),it('Gun105',105,3,'Stable',1,'Gun')},their)
 local chosen=assert(P.selectInitialOffer(ps,125,m(their)));eq(chosen.rawTotal,100);eq(chosen.rawProfit,25)
end)

test('useful knife count cannot override preservation of stronger demand inventory',function()
 local it,m,plans=fixture();local their={it('Receive45',45,3),it('Receive42',42,3),it('Receive38',38,3)}
 local ps=plans({it('APreciousGun',100,8,'Stable',1,'Gun'),it('ZKnife',100,3)},their)
 local chosen=assert(P.selectInitialOffer(ps,125,m(their)));eq(chosen.picks[1].type,'Knife');eq(chosen.givenExitScore,3)
end)

test('unavailable near-target combinations fall back safely without inventing inventory',function()
 local it,m,plans=fixture();local own={it('Only40',40,3)};local their={it('Their100',100,3)}
 local ps=plans(own,their);local chosen=assert(P.selectInitialOffer(ps,100,m(their)))
 eq(chosen.rawTotal,40);eq(chosen.rawProfit,60);eq(#chosen.picks,1)
 local none=plans({it('Unaffordable90',90,3)},their);eq(#none,0);eq(P.selectInitialOffer(none,100,m(their)),nil)
end)

test('extreme ordinal demand gaps cannot consume more than twenty percent of received value',function()
 assert(type(P.profitPreference)=='function','transparent profit preference metadata missing')
 for _,received in ipairs({35,100,500,1295}) do
  local facts=P.profitPreference(received,{confidence=true,rawTotal=received,exitScore=0,riskPoints=0},{givenExitScore=11,givenRisk=0})
  eq(facts.verifiedMarket,true);close(facts.demandPremium,received*.20)
  assert(facts.demandPremium<=received*.20+1e-7,'uncapped ordinal demand premium')
 end
end)

test('only available quote reports a soft quality fallback without pretending the reserve passed',function()
 local it,m,plans=fixture();local own={it('OnlyValuable100',100,8)};local their={it('LowDemand140',140,1,'Stable')}
 local ps=plans(own,their);local chosen,why=P.selectInitialOffer(ps,140,m(their))
 assert(chosen);eq(chosen.rawTotal,100);eq(chosen.rawProfit,40)
 eq(why,'conservative-smallest-verified-fallback')
 local facts=P.strategyFacts(chosen,m(their));eq(facts.reserveMet,false);close(facts.reserveFloor,43)
 assert(chosen.rawProfit>=15 and chosen.protectedProfit>=15)
end)

test('missing source-quality comparison preserves the smallest verified safe giveaway',function()
 local it,m,plans=fixture();local own={it('Small40',40,3),it('NearTarget75',75,3)};local their={it('Their100',100,3)}
 local ps=plans(own,their);local chosen,why=P.selectInitialOffer(ps,100,nil)
 eq(chosen.rawTotal,40);eq(chosen.rawProfit,60);eq(why,'conservative-smallest-verified-fallback')
 eq(P.strategyFacts(chosen,nil),nil)
 local preference=P.profitPreference(100,nil,chosen);eq(preference.verifiedMarket,false)
end)

test('nonfinite or invalid market metadata never claims a verified preference',function()
 for _,bad in ipairs({0/0,math.huge,-math.huge}) do
  eq(P.profitPreference(bad,{confidence=true,rawTotal=100,exitScore=3,riskPoints=0},{givenExitScore=3,givenRisk=0}),nil)
  for _,field in ipairs({'rawTotal','exitScore','riskPoints'}) do
   local theirs={confidence=true,rawTotal=100,exitScore=3,riskPoints=0};theirs[field]=bad
   local preference=P.profitPreference(100,theirs,{givenExitScore=3,givenRisk=0})
   eq(preference.verifiedMarket,false);eq(preference.reserveFloor,15)
  end
  for _,field in ipairs({'givenExitScore','givenRisk'}) do
   local plan={givenExitScore=3,givenRisk=0};plan[field]=bad
   eq(P.profitPreference(100,{confidence=true,rawTotal=100,exitScore=3,riskPoints=0},plan).verifiedMarket,false)
  end
  eq(P.strategyFacts({rawTotal=75,rawProfit=bad},nil),nil)
  eq(P.strategyFacts({rawTotal=bad,rawProfit=25},nil),nil)
 end
 for _,risk in ipairs({-.01,1.01}) do
  eq(P.profitPreference(100,{confidence=true,rawTotal=100,exitScore=3,riskPoints=risk},{givenExitScore=3,givenRisk=0}).verifiedMarket,false)
 end
end)

test('real35 Chroma Swirly Gun chooses useful Plasmabeam18 over Boneblade7',function()
 local own={real('godly',572,'Gun'),real('godly',27)};local their={real('chroma',527,'Gun')}
 local chosen,ps,m=select(own,their);eq(chosen.rawTotal,18);eq(chosen.rawProfit,17)
 close(P.strategyFacts(chosen,m).targetProfit,15);physical(ps,own,their)
end)

test('hard plus15 floor survives desirability and item count preferences',function()
 local it,m=fixture();local own={it('Our100',100,1)}
 local their={it('PopularA',38,8),it('PopularB',38,8),it('PopularC',38.99,8)}
 assert(not P.tradeDecision(m(own),m(their)).ok)
 local precise={it('Precise115',115,8)};assert(P.tradeDecision(m(own),m(precise)).ok)
end)

test('normal and chroma price identities remain distinct while canonical mirrors are excluded',function()
 local it,m,plans=fixture();local normal=it('Shared',30,3,'Stable',2,'Gun','godly');local chroma=it('Shared',35,3,'Stable',1,'Gun','chroma')
 local their={it('Shared',30,3,'Stable',1,'Gun','godly'),it('Extra',70)}
 local ps=plans({normal,chroma},their);assert(#ps>0)
 for _,p in ipairs(ps) do for _,pick in ipairs(p.picks) do eq(pick.page,'chroma') end end
end)

test('duplicate owned copies stay bounded by actual quantity and four physical copies',function()
 local it,m,plans=fixture();local own={it('Duplicate10',10,3,'Stable',7)};local their={it('Their100',100)}
 local ps=plans(own,their);assert(#ps>0)
 for _,p in ipairs(ps) do assert(p.units<=4 and p.picks[1].qty<=4) end
 physical(ps,own,their)
end)

test('expired source and unknown or Priceless identities produce no safe plans',function()
 local own={real('godly',27)};local their={real('chroma',527,'Gun')};local stale={};for k,v in pairs(current) do stale[k]=v end
 stale.isFresh=function() return false end
 eq(#P.buildPlans(inventory(own),P.bundleAssessment(their,'theirs',current),stale,P),0)
 local unknown={page='godly',id='missing',checkerId='missing',name='Missing',qty=1,cat='Weapons',type='Knife'}
 eq(#P.buildPlans(inventory({unknown}),P.bundleAssessment(their,'theirs',current),current,P),0)
 eq(#P.buildPlans(inventory({real('ancient',1)}),P.bundleAssessment(their,'theirs',current),current,P),0)
end)

test('real1295 demand threshold cannot outweigh a near-target owned960 quote by509 value',function()
 local own={real('godly',572,'Gun'),real('godly',27),real('godly',481,'Gun'),real('godly',812),real('godly',859),real('godly',794),real('godly',714),real('ancient',526,'Gun')}
 local their={real('godly',833,'Gun'),real('godly',832),real('godly',23),real('godly',20,'Gun')}
 local chosen,ps,m=select(own,their);eq(m.rawTotal,1295)
 local near,larger
 for _,plan in ipairs(ps) do
  if plan.rawTotal==960 then near=plan elseif plan.rawTotal==1020 then larger=plan end
 end
 assert(near and larger,'actual owned four-copy alternatives were lost')
 physical(ps,own,their);eq(near.units,4);eq(larger.units,4)
 local nearFacts=P.strategyFacts(near,m)
 close(nearFacts.targetProfit,312.25);close(nearFacts.targetDistance,22.75);eq(nearFacts.reserveMet,true)
 eq(nearFacts.appealTier,2) -- demand3.26 misses the binary3.6448 threshold despite stable items
 eq(chosen.rawTotal,960);eq(chosen.rawProfit,335)
 local facts=P.strategyFacts(chosen,m)
 eq(facts.targetDistanceBand,0);close(facts.targetDistanceBandWidth,25)
end)

print('RESULT '..passed..' passed; '..failed..' failed')
assert(failed==0,'Issue28 production policy failures')
