local P=dofile((arg and arg[1]) or 'pdiddler/pdiddler4_supreme_policy_v9_CONSISTENT_QUOTES.lua')
local rows={}
local profile={version='fixture',isFresh=function() return true end,get=function(page,id) return rows[page..':'..id] end}
local function item(id,value,demand,status)
 rows['godly:'..id]={page='godly',id=id,name=id,supremeValue=value,demand=demand,stability=status or 'Stable',verified=true}
 return {id=id,checkerId=id,page='godly',cat='Weapons',type='Knife',name=id,value=value,demand=demand,stability=status or 'Stable',qty=1}
end
local n=0
local function test(name,fn) fn();n=n+1;print('PASS '..name) end
test('unselected candidate cannot move first quote through tolerance drift',function()
 local a,b,c=item('A',60,5),item('B',59,5.2),item('C',58,5.4)
 local t=item('T',100,5.2);local market=P.bundleAssessment({t},'theirs',profile)
 local plans=assert(P.buildPlans({items={a,b,c}},market,profile,P))
 local with=P.selectInitialOffer(plans,100,market)
 local without=P.selectInitialOffer(assert(P.buildPlans({items={a,c}},market,profile,P)),100,market)
 assert(with.key==without.key,'unused candidate changed selection: '..with.rawTotal..' vs '..without.rawTotal)
 assert(with.rawTotal==58)
end)
test('candidate permutations preserve the exact selected quote',function()
 local a,b,c=item('A',60,5),item('B',59,5.2),item('C',58,5.4)
 local market=P.bundleAssessment({item('T',100,5.2)},'theirs',profile)
 local plans=assert(P.buildPlans({items={a,b,c}},market,profile,P))
 local expected=P.selectInitialOffer(plans,100,market)
 for _,order in ipairs({{3,2,1},{2,1,3},{1,3,2},{2,3,1},{3,1,2}}) do
  local q=P.selectInitialOffer({plans[order[1]],plans[order[2]],plans[order[3]]},100,market)
  assert(q.key==expected.key)
 end
end)
test('hard +15 and unknown prices remain independent of preference ordering',function()
 local mine=item('Mine',85,3);local t=item('T',100,3)
 local m=P.bundleAssessment({t},'theirs',profile)
 local plans=assert(P.buildPlans({items={mine}},m,profile,P));assert(P.selectInitialOffer(plans,100,m).rawProfit==15)
 rows['godly:Mine'].supremeValue=85.01
 assert(#assert(P.buildPlans({items={mine}},m,profile,P))==0)
 rows['godly:Mine'].supremeValue=nil
 local missing=P.reprice({items={mine}},profile);assert(missing.unpriced==1)
end)
test('source conditions are retained without equating Doing Well with volatility',function()
 local stable=item('S',50,3,'Stable');local well=item('W',50,3,'Doing Well');local fluct=item('F',50,3,'Fluctuating')
 local a=P.itemAssessment(stable,'ours',rows['godly:S'])
 local b=P.itemAssessment(well,'ours',rows['godly:W'])
 local c=P.itemAssessment(fluct,'ours',rows['godly:F'])
 assert(b.marketCondition=='Doing Well' and c.marketCondition=='Fluctuating')
 assert(b.volatility=='unknown' and c.volatility=='fluctuating' and a.volatility=='stable')
 -- Exact source-condition flags are not inferred resale loss probabilities.
 assert(b.riskPoints==0 and c.riskPoints==1 and b.riskMeaning=='fluctuating-or-underpaid-source-status')
end)
test('planner never offers the same canonical item already received',function()
 local a=item('A',30,3);local b=item('B',40,3);local t=item('T',100,3)
 local market=P.bundleAssessment({a,t},'theirs',profile)
 local plans=assert(P.buildPlans({items={a,b}},market,profile,P))
 assert(#plans>0)
 for _,plan in ipairs(plans) do for _,pick in ipairs(plan.picks) do assert(pick.checkerId~='A','mirrored item included') end end
end)
test('canonical aliases cannot evade the no matching items rule',function()
 local raw=item('Canonical',30,3);raw.id='our_raw';raw.checkerId='Canonical'
 local incoming={};for k,v in pairs(raw) do incoming[k]=v end;incoming.id='their_raw'
 local market=P.bundleAssessment({incoming,item('T',100,3)},'theirs',profile)
 local plans=assert(P.buildPlans({items={raw}},market,profile,P));assert(#plans==0)
end)
test('a profitable existing offer is invalid when either exact item overlaps',function()
 local a=item('A',30,3);local t=item('T',100,3)
 assert(not P.tradeDecision(P.bundleAssessment({a},'ours',profile),P.bundleAssessment({a,t},'theirs',profile)).ok)
end)
test('retained-inventory preference does not dispose of Doing Well as unstable',function()
 local stable=item('A',20,3,'Stable');local well=item('Z',20,3,'Doing Well')
 local market=P.bundleAssessment({item('Target',50,3)},'theirs',profile)
 local plans=assert(P.buildPlans({items={stable,well}},market,profile,P))
 local chosen=P.selectInitialOffer(plans,50,market)
 assert(chosen.picks[1].id=='A','Doing Well was treated as adverse exposure')
end)
print('TOTAL '..n..' V14 strategy tests')
