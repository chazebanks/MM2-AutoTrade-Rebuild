-- Pure policy regressions. Optional paths permit an explicit V7/V2 RED run.
local P=dofile(arg[1] or 'pdiddler/pdiddler4_supreme_policy_v8_PORTFOLIO_LEDGER.lua')
local E=dofile(arg[2] or 'pdiddler/pdiddler4_early_counter_policy_v3_TRADE_BUDGET.lua')
local passed,failed=0,0
local function test(name,fn) local ok,e=pcall(fn);if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(e)) end end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function close(a,b) assert(math.abs(a-b)<1e-6,tostring(a)..' ~= '..tostring(b)) end
local function fixture()
 local rows={};local profile={get=function(page,id) return rows[page..':'..id] end,isFresh=function() return true end}
 local function item(id,value,demand,status,qty)
  rows['godly:'..id]={page='godly',id=id,name=id,supremeValue=value,demand=demand or 1,stability=status or 'Stable',verified=true}
  return {page='godly',id=id,checkerId=id,name=id,value=value,qty=qty or 1,cat='Weapons',type='Knife'}
 end
 local function market(items,side) return P.bundleAssessment(items,side or 'ours',profile) end
 local function plans(items,their) return P.buildPlans({items=items,unmapped=0,unpriced=0,badQty=0},market(their,'theirs'),profile,P) end
 return item,market,plans,profile
end
local function live(plan) local counts={};for _,x in ipairs(plan.picks) do counts[x.page..':'..x.id]=(counts[x.page..':'..x.id] or 0)+x.qty end;return {rawTotal=plan.rawTotal,unresolved={},counts=counts} end
local function quote(id,value,received) return {ok=true,key=id,rawTotal=value,rawProfit=received-value,units=1,givenExitScore=1,givenRisk=0,picks={{page='godly',id=id,qty=1}}} end
local function ledger() assert(type(P.observeQuote)=='function','verified trade ledger missing');return {} end

test('guarded quote extension bridges23 to145 against235 with known matching demand',function()
 local it,m,plans=fixture();local t={it('T',235,3)};local ps=plans({it('Small',23,1),it('Match',145,3)},t)
 local chosen=P.selectInitialOffer(ps,235,m(t,'theirs'));eq(chosen.rawTotal,145);eq(chosen.rawProfit,90)
end)
test('unknown incoming comparison retains legacy60percent ceiling',function()
 local it,m,plans=fixture();local t={it('T',235,3)};local ps=plans({it('Small',23,1),it('Match',145,3)},t)
 eq(P.selectInitialOffer(ps,235).rawTotal,23)
end)
test('extension never crosses its bounded region or15floor',function()
 local low=quote('low',23,235);local tooFar=quote('far',170,235);tooFar.givenExitScore=3
 local t={confidence=true,rawTotal=235,exitScore=3,riskPoints=0}
 eq(P.selectInitialOffer({low,tooFar},235,t),low)
end)
test('all comparisons retain independent15cents floor',function()
 assert(not P.tradeDecision({rawTotal=100,confidence=true},{rawTotal=114.99,confidence=true}).ok)
 assert(P.tradeDecision({rawTotal=100,confidence=true},{rawTotal=115,confidence=true}).ok)
end)
test('planner risk is value weighted',function()
 local it,m,plans=fixture();local a=it('Unstable',90,3,'Fluctuating');local b=it('Stable',10,3);local t={it('T',120,3)}
 local ps=plans({a,b},t);local found;for _,p in ipairs(ps) do if p.rawTotal==100 then found=p end end
 assert(found);close(found.givenRisk,.9)
end)
test('equal given statistics preserve distinct post-trade concentration',function()
 local it,m,plans=fixture();local own={it('A',33,1,'Stable',1),it('B',33,1,'Stable',3)};local t={it('T',65)}
 local ps=plans(own,t);eq(#ps,2);local chosen=P.selectInitialOffer(ps,65,m(t,'theirs'))
 eq(chosen.picks[1].id,'B');assert(chosen.portfolio.known);close(chosen.portfolio.concentration,(33*33+66*66+65*65)/(164*164))
end)
test('fifty interchangeable equal-stat items merge without exhausting budget',function()
 local it,m,plans=fixture();local own={};for i=1,50 do own[i]=it(string.format('A%02d',i),10,1) end
 local ps,why=plans(own,{it('T',100,1)});assert(why~='planner-state-budget');eq(#ps,4)
end)
test('missing incoming items marks portfolio facts unknown',function()
 local it,m,plans,profile=fixture();local ps=P.buildPlans({items={it('A',10)}},{confidence=true,rawTotal=50,exitScore=1},profile,P)
 assert(#ps>0 and ps[1].portfolio and ps[1].portfolio.known==false)
end)
test('planner retains demand-threshold shapes at equal weighted demand',function()
 local it,m,plans=fixture();local ps=plans({it('A',10,1),it('B',10,5),it('C',10,3,'Stable',2)},{it('T',50,3)})
 local n=0;for _,p in ipairs(ps) do if p.rawTotal==20 and p.givenExitScore==3 then n=n+1 end end;assert(n>=2)
end)
test('planner remains explicitly bounded',function()
 local it,m,plans,profile=fixture();local own={it('A',10),it('B',20)}
 local ps,why=P.buildPlans({items=own},m({it('T',100)},'theirs'),profile,P,1);eq(#ps,0);eq(why,'planner-state-budget')
end)
test('first verified safe quote initializes one anchor and failed quotes do not',function()
 local s=ledger();assert(not P.observeQuote(s,100,110,0));assert(not s.ledger)
 assert(P.observeQuote(s,7,101,1));eq(s.ledger.anchorTotal,7)
 local ok,why=P.observeQuote(s,38,101,2);assert(not ok);eq(why,'uncommitted-own-quote')
 eq(s.ledger.anchorTotal,7);eq(s.ledger.lastVerifiedTotal,7)
end)
test('equal edits do not replenish committed early spending',function()
 local s=ledger();P.observeQuote(s,7,101,0);close(P.earlyAllowance(s,7,101),31.6)
 local p=quote('38',38,101);assert(P.reserveOffer(s,'early','one',p,7,101,1));eq(s.ledger.earlySpent,0)
 assert(P.confirmConcession(s,'one',p,live(p),2));close(s.ledger.earlySpent,31)
 P.observeQuote(s,38,101,3);close(P.earlyAllowance(s,38,101),.6)
 assert(not P.reserveOffer(s,'early','two',quote('54',54,101),38,101,4))
end)
test('genuine larger received value enlarges only bounded remaining envelope',function()
 local s=ledger();P.observeQuote(s,7,101,0);local p=quote('38',38,101)
 P.reserveOffer(s,'early','a',p,7,101,1);P.confirmConcession(s,'a',p,live(p),2)
 P.observeQuote(s,38,200,3);close(P.earlyAllowance(s,38,200),9)
 P.observeQuote(s,38,101,4);eq(s.ledger.maxReceived,200);close(P.earlyAllowance(s,38,101),.6)
 assert(not P.reserveOffer(s,"early","removed-high-value",quote("47",47,101),38,101,5))
end)
test('unverified reservation cannot spend and exact pending owns confirmation',function()
 local s=ledger();P.observeQuote(s,50,100,0);local p=quote('58',58,100)
 assert(P.reserveOffer(s,'early','a',p,50,100,1));eq(s.ledger.earlySpent,0)
 assert(not P.confirmConcession(s,'wrong',p,live(p),2));eq(s.ledger.earlySpent,0)
 local wrong=live(p);wrong.counts={};assert(not P.confirmConcession(s,'a',p,wrong,2))
 P.cancelConcession(s);eq(s.ledger.earlySpent,0)
end)
test('recovery restoration is free but cannot create a larger fresh quote',function()
 local s=ledger();P.observeQuote(s,38,101,0);local restore=quote('38',38,101)
 assert(P.reserveOffer(s,'initial','a',restore,0,101,1));assert(P.confirmConcession(s,'a',restore,live(restore),2));eq(s.ledger.earlySpent,0)
 local tooLarge=quote('70',70,101);assert(not P.reserveOffer(s,'rebalance','a',tooLarge,0,101,3))
end)
test('first initial baseline commits only exact verified safe plan',function()
 local s=ledger();local p=quote('60',60,100);assert(P.reserveOffer(s,'initial','a',p,0,100,0));assert(not s.ledger)
 assert(P.confirmConcession(s,'a',p,live(p),1));eq(s.ledger.anchorTotal,60);eq(s.ledger.earlySpent,0)
 assert(not P.confirmConcession(s,'a',p,live(p),2))
end)
test('safe decreases do not refund spent early allowance',function()
 local s=ledger();P.observeQuote(s,7,101,0);local p=quote('38',38,101);P.reserveOffer(s,'early','a',p,7,101,1);P.confirmConcession(s,'a',p,live(p),2)
 local lower=quote('20',20,101);assert(P.reserveOffer(s,'rebalance','b',lower,38,101,3));assert(P.confirmConcession(s,'b',lower,live(lower),4));eq(s.ledger.earlySpent,31)
end)
test('two verified late steps survive exact opponent signature changes',function()
 local s=ledger();P.observeQuote(s,50,100,0);local p=quote('58',58,100)
 P.negotiate(s,'a',50,{p},0,false,true,100);eq(P.negotiate(s,'a',50,{p},10,false,true,100),'improve');eq(s.steps,0)
 assert(P.reserveOffer(s,'late','a',p,50,100,10));assert(P.confirmConcession(s,'a',p,live(p),11));eq(s.steps,1)
 local q=quote('63',63,100);P.negotiate(s,'b',58,{q},12,false,true,100);eq(s.steps,1)
 eq(P.negotiate(s,'b',58,{q},22,false,true,100),'improve');assert(P.confirmConcession(s,'b',q,live(q),23));eq(s.steps,2)
 P.negotiate(s,'c',63,{quote('68',68,100)},24,false,true,100);eq(s.steps,2);eq(P.negotiate(s,'c',63,{},34,false,true,100),'final-wait')
end)
test('early policy requires strict remaining allowance and caps proposal by it',function()
 local it,m,plans=fixture();local own={it('A',7),it('B',38),it('C',54)};local t={it('T',101)};local ps=plans(own,t)
 local cur={rawTotal=7,market=m({own[1]}),counts={['godly:A']=1},unresolved={}};local their={rawTotal=101,market=m(t,'theirs'),unresolved={}}
 eq(E.choose({},'a',cur,their,ps,{accepted=false,localAccepted=false}),'hold')
 eq(E.choose({},'a',cur,their,ps,{accepted=false,localAccepted=false,earlyRemaining=0}),'keep')
 local action,p=E.choose({},'a',cur,their,ps,{accepted=false,localAccepted=false,earlyRemaining=31.6});eq(action,'counter');eq(p.rawTotal,38)
end)
test('unsafe opener can reserve its first safe reducing rebalance',function()
 local s=ledger();local p=quote('safe',60,100)
 assert(P.reserveOffer(s,'rebalance','first',p,100,100,1));assert(not s.ledger)
 assert(P.confirmConcession(s,'first',p,live(p),2));eq(s.ledger.anchorTotal,60);eq(s.ledger.earlySpent,0)
 assert(not P.reserveOffer({},'rebalance','first',quote('increase',80,100),50,100,1))
end)
test('portfolio tie-break order cannot create a comparison cycle',function()
 local function plan(key,squares,compact)
  local thresholds={};for i=1,11 do thresholds[i]=0 end
  return {key=key,portfolio={known=true,total=30000,squares=squares,compact4=compact,unstableValue=0,demandThresholds=thresholds}}
 end
 local a,b,c=plan('Z',9000000,10000),plan('M',10000000,10000),plan('N',12000000,11000)
 local function before(x,y) local result=P.portfolioBetter(x,y);if result~=nil then return result end;return x.key<y.key end
 assert(not (before(a,b) and before(b,c) and before(c,a)),'nontransitive portfolio comparison')
end)
test('cancelled signature cannot reserve again until a new offer generation',function()
 local s=ledger();P.observeQuote(s,50,100,0);local p=quote('58',58,100)
 assert(P.reserveOffer(s,'rebalance','a',p,50,100,1));P.cancelConcession(s)
 assert(not P.reserveOffer(s,'rebalance','a',p,50,100,2),'cancelled generation re-reserved')
 assert(P.reserveOffer(s,'rebalance','b',p,50,100,3));eq(s.ledger.earlySpent,0);eq(s.steps,0)
 assert(not P.confirmConcession(s,'a',p,live(p),4));assert(P.confirmConcession(s,'b',p,live(p),4))
end)
test('unsupported price precision returns a controlled planner result',function()
 local it,m,plans=fixture();local ps,why=plans({it('A',1.001)},{it('T',100)})
 eq(#ps,0);eq(why,'unsupported-price-precision')
end)
test('uncommitted actual quote cannot silently establish a free spending reference',function()
 local s=ledger();P.observeQuote(s,7,101,0);local p=quote('38',38,101)
 assert(P.reserveOffer(s,'early','a',p,7,101,1));P.cancelConcession(s)
 local ok,why=P.observeQuote(s,38,200,2);assert(not ok);eq(why,'uncommitted-own-quote')
 eq(s.ledger.lastVerifiedTotal,7);eq(s.ledger.maxReceived,101);eq(s.ledger.earlySpent,0)
 assert(not P.reserveOffer(s,'early','b',quote('54',54,101),38,101,3))
 assert(not P.reserveOffer(s,'rebalance','b',quote('54',54,101),38,101,3))
 eq(P.negotiate(s,'b',38,{quote('54',54,101)},30,false,true,101),'unverified-hold')
 eq(s.ledger.lastVerifiedTotal,7);eq(s.ledger.earlySpent,0)
end)
test('confirmed quote may subsequently be observed without spending again',function()
 local s=ledger();P.observeQuote(s,7,101,0);local p=quote('38',38,101)
 assert(P.reserveOffer(s,'early','a',p,7,101,1));assert(P.confirmConcession(s,'a',p,live(p),2))
 assert(P.observeQuote(s,38,101,3));eq(s.ledger.lastVerifiedTotal,38);eq(s.ledger.earlySpent,31)
end)
test('late wait acceptance freeze and final window remain unchanged',function()
 local s=ledger();P.observeQuote(s,50,100,0);local p=quote('58',58,100)
 eq(P.negotiate(s,'a',50,{p},0,false,false,100),'accept-not-ready');eq(P.negotiate(s,'a',50,{p},9,true,true,100),'hold')
 eq(P.negotiate(s,'a',50,{p},10,false,true,100),'wait');eq(P.negotiate(s,'a',50,{},19,false,true,100),'final-wait');eq(P.negotiate(s,'a',50,{},24,false,true,100),'decline')
end)
test('quote ownership mismatch is visible even after their value falls below safety',function()
 local s=ledger();P.observeQuote(s,7,101,0)
 local ok,why=P.observeQuote(s,38,45,1);assert(not ok);eq(why,'uncommitted-own-quote');eq(s.ledger.lastVerifiedTotal,7)
 local legitimate,reason=P.observeQuote(s,7,20,2);assert(not legitimate);eq(reason,'unsafe-observed-quote')
end)
-- Exhaustive small-inventory oracle computes post-trade holdings independently.
local function portfolioFeature(units,cost,demand,risk,holdings)
 local total,squares,unstable,distinct,top=0,0,0,0,{}
 local thresholds={};for i=1,11 do thresholds[i]=0 end
 for _,x in pairs(holdings) do if x.qty>0 then
  local unit=math.floor(x.value*100+.5);local value=unit*x.qty
  total=total+value;squares=squares+value*value;distinct=distinct+1
  if x.stability~='Stable' then unstable=unstable+value end
  for i=1,11 do if x.demand>=i then thresholds[i]=thresholds[i]+value end end
  for i=1,x.qty do top[#top+1]=unit end
 end end
 table.sort(top,function(a,b) return a>b end)
 local compact=0;for i=1,math.min(4,#top) do compact=compact+top[i] end
 local key={units,cost,demand,risk,total,squares,compact,distinct,unstable}
 for i=1,11 do key[#key+1]=thresholds[i] end
 for i=1,math.min(8-units,#top) do key[#key+1]=top[i] end
 for i,v in ipairs(key) do key[i]=string.format('%.0f',v) end
 return table.concat(key,':')
end
local function exhaustiveFeatures(own,incoming,received)
 local expected={};local chosen={}
 local function enumerate(index,units,cost,demand,risk)
  if index>#own then
   if units==0 or received*100-cost<1500 then return end
   local holdings={}
   local function add(x,qty)
    local key=x.page..':'..(x.checkerId or x.id);local old=holdings[key]
    if not old then old={qty=0,value=x.value,demand=x.demand,stability=x.stability};holdings[key]=old end
    old.qty=old.qty+qty
   end
   for i,x in ipairs(own) do add(x,x.qty-(chosen[i] or 0)) end
   for _,x in ipairs(incoming) do add(x,x.qty) end
   expected[portfolioFeature(units,cost,demand,risk,holdings)]=true
   return
  end
  local x=own[index];local value=math.floor(x.value*100+.5)
  for qty=0,math.min(x.qty,4-units) do
   chosen[index]=qty
   enumerate(index+1,units+qty,cost+qty*value,demand+qty*value*x.demand,
    risk+(x.stability=='Stable' and 0 or qty*value))
  end
 end
 enumerate(1,0,0,0,0);return expected
end
local function actualFeature(plan)
 local f=plan.portfolio
 local key={plan.units,plan.rawTotal*100,plan.givenExitScore*plan.rawTotal*100,
  plan.givenRisk*plan.rawTotal*100,f.total,f.squares,f.compact4,f.distinct,f.unstableValue}
 for i=1,11 do key[#key+1]=f.demandThresholds[i] end
 for _,value in ipairs(f.topValues or {}) do key[#key+1]=value end
 for i,v in ipairs(key) do key[i]=string.format('%.0f',v) end
 return table.concat(key,':')
end
local function pricedFixture(rows)
 local it,m,plans,profile=fixture();local own={}
 for _,row in ipairs(rows) do local x=it(row[1],row[2],row[4],row[5],row[3]);x.demand=row[4];x.stability=row[5];own[#own+1]=x end
 local target=it('T',100,2,'Stable');target.demand=2;target.stability='Stable'
 return own,{target},m,plans,profile,it
end
test('grouped planner preserves the compact120 C plus F triple plan',function()
 local own,incoming,m,plans=pricedFixture({{'A',4,1,3,'Fluctuating'},{'B',6,2,3,'Stable'},
  {'C',8,2,1,'Fluctuating'},{'D',5,2,2,'Stable'},{'E',3,2,3,'Stable'},{'F',4,3,3,'Stable'}})
 local ps=plans(own,incoming);local found=false
 for _,plan in ipairs(ps) do
  if plan.units==4 and plan.rawTotal==20 and math.abs(plan.givenExitScore-2.2)<1e-7
   and math.abs(plan.givenRisk-.4)<1e-7 and plan.portfolio.compact4==12000 then found=true end
 end
 assert(found,'legal compact120 plan was merged into compact119 continuation')
end)
test('bounded exhaustive oracle retains all feasible final feature states',function()
 local seed=20261104
 local function random(n) seed=(seed*48271)%2147483647;return 1+seed%n end
 for case=1,1500 do
  local rows={}
  for i=1,2+random(4) do rows[#rows+1]={string.char(64+i),1+random(9),random(3),random(3),random(2)==1 and 'Stable' or 'Fluctuating'} end
  local own,incoming,m,plans,profile=pricedFixture(rows)
  if case%3==0 then
   local copy={};for k,v in pairs(own[1]) do copy[k]=v end;copy.qty=1;incoming[#incoming+1]=copy
  end
  local received=m(incoming,'theirs').rawTotal
  local expected=exhaustiveFeatures(own,incoming,received)
  local ps,why=plans(own,incoming);assert(why~='planner-state-budget','small oracle fixture exceeded budget')
  local actual={};for _,plan in ipairs(ps) do assert(plan.rawProfit>=15);actual[actualFeature(plan)]=true end
  for key in pairs(expected) do assert(actual[key],'oracle case '..case..' lost feasible feature state '..key) end
  for key in pairs(actual) do assert(expected[key],'oracle case '..case..' invented feature state '..key) end
 end
end)
test('valid distinct raw rows sharing canonical prices retain exact availability',function()
 local it,m,plans,profile=fixture();local a=it('A',10,1,'Stable')
 local alias={};for k,v in pairs(a) do alias[k]=v end;alias.id='other-raw-id'
 local ps,why=P.buildPlans({items={a,alias}},m({it('T',100)},'theirs'),profile,P)
 eq(why,nil);eq(#ps,3);local first,second=false,false
 for _,plan in ipairs(ps) do
  assert(plan.portfolio.known==false)
  for _,pick in ipairs(plan.picks) do assert(pick.qty==1);if pick.id=='A' then first=true elseif pick.id=='other-raw-id' then second=true else error('invented raw action') end end
 end
 assert(first and second)
 local bad=P.buildPlans({items={a,a}},m({it('T',100)},'theirs'),profile,P);eq(#bad,0)
end)
print(string.format('RESULT %d passed, %d failed',passed,failed));assert(failed==0,'V12 pure policy failures')
