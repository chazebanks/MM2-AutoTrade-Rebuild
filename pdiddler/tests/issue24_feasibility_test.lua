-- Production feasibility and strict planner; historical fixtures never bypass the live freshness check.
local F=dofile('pdiddler/pdiddler3_feasibility_v1.lua')
local P=dofile('pdiddler/pdiddler4_supreme_policy_v9_CONSISTENT_QUOTES.lua')
local s=dofile('pdiddler/snapshots/pdiddler_supreme_snapshot_2026_11_04.lua')
local profile={};for k,v in pairs(s) do profile[k]=v end
profile.isFresh=function() return s.isFresh(s.observedAtEpoch) end
local n=0
local function test(name,fn) fn();n=n+1;print('PASS '..name) end
local function item(page,id,qty,raw)
 local r=assert(s.get(page,id));return {cat='Weapons',type='Knife',page=page,checkerId=id,id=raw or 'raw-'..page..id,name=r.name,qty=qty or 1,value=999999}
end
local function inv(...) return {items={...},unmapped=0,unpriced=0,badQty=0} end
local function state(ours,theirs,want,policy)
 local got,why,proof=F.evaluate(ours,theirs,profile,policy or P)
 assert(got==want,tostring(got)..' '..tostring(why));return why,proof
end
local function boundary()
 local custom={version='boundary',isFresh=function() return true end,get=function(_,id)
  return {verified=true,page='godly',id=id,name=id,supremeValue=id=='own' and 7 or tonumber(id),demand=1,stability='Stable'} end}
 local function row(id,qty,raw) return {cat='Weapons',type='Gun',page='godly',checkerId=id,id=raw or id,name=id,qty=qty or 1} end
 return custom,row
end

test('current-clock snapshot freshness is independently verified',function()
 assert(s.isFresh(), 'expired snapshot: no live testing')
end)
test('own-read validation requires current complete canonically priced data',function()
 local priced,why=F.validateInventory(inv(item('godly','27')),profile,P)
 assert(priced and not why and priced.total==7)
 local partial=inv(item('godly','27'));partial.unmapped=1
 assert(not F.validateInventory(partial,profile,P))
 partial=inv(item('godly','27'));partial.unpriced=1
 assert(not F.validateInventory(partial,profile,P))
 assert(not F.validateInventory({},profile,P))
 assert(not F.validateInventory(inv(item('ancient','1')),profile,P))
 assert(not F.validateInventory(inv(item('godly','27')),profile,{}))
 local empty=F.validateInventory(inv(),profile,P);assert(empty and #empty.items==0)
 local old=profile.isFresh;profile.isFresh=function() return false end
 assert(not F.validateInventory(inv(item('godly','27')),profile,P));profile.isFresh=old
end)
test('actual Seer3 is unreachable against Boneblade7',function()
 local why=state(inv(item('godly','27')),inv(item('godly','889')),'unprofitable');assert(why=='profit-unreachable')
end)
test('Batwing42 Luger18 yields a strict-planner-verified owned witness',function()
 local ours=inv(item('godly','27'));local theirs=inv(item('ancient','3'),item('godly','39'))
 local _,proof=state(ours,theirs,'reachable')
 assert(proof.ourValue==7 and proof.theirValue==60 and proof.profit==53 and proof.ownItem.qty==1)
 local plans=P.buildPlans(ours,P.bundleAssessment(proof.theirItems,'theirs',profile),profile);assert(#plans>0)
 assert(#proof.theirItems==2 and proof.theirItems[1].qty==1 and proof.theirItems[2].qty==1)
 assert(ours.items[1].value==999999 and theirs.items[1].qty==1,'caller inventory mutated')
end)
test('exact +15 is reachable but +14.99 is not',function()
 local custom,row=boundary()
 assert(F.evaluate(inv(row('own')),inv(row('22')),custom,P)=='reachable')
 assert(F.evaluate(inv(row('own')),inv(row('21.99')),custom,P)=='unprofitable')
end)
test('matching identities cannot manufacture profit and ownership alone does not exclude a feasible subset',function()
 state(inv(item('godly','27')),inv(item('godly','27',10,'other-raw')),'unprofitable')
 state(inv(item('godly','27')),inv(item('godly','27',10),item('godly','39')),'unprofitable')
 local _,proof=state(inv(item('godly','27')),inv(item('godly','27',10),item('ancient','3')),'reachable')
 assert(#proof.theirItems==1 and proof.theirItems[1].page=='ancient' and proof.theirValue==42)
end)
test('Chroma and normal variants remain separate',function()
 state(inv(item('godly','27')),inv(item('chroma','16')),'reachable')
end)
test('full quantity upper bound prevents false unprofitable verdicts when stacking is unproved',function()
 state(inv(item('chroma','16')),inv(item('godly','27',100)),'unknown')
 state(inv(item('godly','27')),inv(item('godly','889',10)),'unknown')
 state(inv(item('godly','27')),inv(item('godly','39',2)),'unknown')
 state(inv(item('godly','27')),inv(item('godly','39',1)),'unprofitable')
 state(inv(item('godly','27')),inv(item('godly','889',7)),'unprofitable') -- Full inventory21 cannot pay22.
end)
test('witness uses at most four distinct available raw rows with quantity one',function()
 local custom,row=boundary()
 local theirs=inv(row('6',1,'a'),row('6',1,'b'),row('6',1,'c'),row('6',1,'d'),row('6',1,'e'))
 local status,_,proof=F.evaluate(inv(row('own')),theirs,custom,P)
 assert(status=='reachable' and proof.theirValue==24 and #proof.theirItems==4)
 local seen={};for _,it in ipairs(proof.theirItems) do assert(it.qty==1 and not seen[it.id]);seen[it.id]=true end
 local noWitness=inv(row('5',1,'a'),row('5',1,'b'),row('5',1,'c'),row('5',1,'d'),row('5',1,'e'))
 assert(F.evaluate(inv(row('own')),noWitness,custom,P)=='unknown') -- total25 possible, supported four slots total20.
end)
test('missing empty malformed partial unpriced and unverified data do not prove unprofitability',function()
 for _,field in ipairs({'unmapped','unpriced','badQty'}) do
  local partial=inv(item('godly','889'));partial[field]=1
  state(inv(item('godly','27')),partial,'unknown')
  state(partial,inv(item('ancient','3')),'unknown')
  partial=inv(item('godly','889'));partial[field]=nil
  state(inv(item('godly','27')),partial,'unknown')
  partial=inv(item('godly','889'));partial[field]=0/0
  state(inv(item('godly','27')),partial,'unknown')
 end
 state(nil,inv(item('godly','889')),'unknown');state(inv(),inv(item('godly','889')),'unknown')
 state(inv(item('godly','27')),nil,'unknown');state(inv(item('godly','27')),{},'unknown')
 local malformed=inv();malformed.items={[2]=item('godly','889')};state(inv(item('godly','27')),malformed,'unknown')
 malformed=inv();malformed.items={bad=item('godly','889')};state(inv(item('godly','27')),malformed,'unknown')
 local bad=item('godly','889');bad.qty=0/0;state(inv(item('godly','27')),inv(bad),'unknown')
 bad=item('godly','889');bad.qty=0;state(inv(item('godly','27')),inv(bad),'unknown')
 bad=item('godly','889');bad.name='Chroma Seer';state(inv(item('godly','27')),inv(bad),'unknown')
 bad=item('godly','889');bad.cat='Pets';state(inv(item('godly','27')),inv(bad),'unknown')
 state(inv(item('godly','27')),inv(item('ancient','1')),'unknown') -- Priceless remains unpriced.
 state(inv(item('godly','27')),inv(item('godly','889'),item('godly','889')),'unknown')
end)
test('precision and overflowing quantity totals cannot be trusted as an impossibility proof',function()
 local custom,row=boundary()
 assert(F.evaluate(inv(row('own')),inv(row('21.999')),custom,P)=='unknown')
 assert(F.evaluate(inv(row('own')),inv(row('22',1e16)),custom,P)=='unknown')
end)
test('profile expiry or unreadable profile is a hold despite cached values',function()
 local old=profile.isFresh;profile.isFresh=function() return false end
 state(inv(item('godly','27')),inv(item('ancient','3')),'unknown')
 profile.isFresh=function() error('profile unavailable') end
 state(inv(item('godly','27')),inv(item('ancient','3')),'unknown');profile.isFresh=old
 local bad={isFresh=function() return true end,get=function() error('unavailable') end}
 assert(F.evaluate(inv(item('godly','27')),inv(item('ancient','3')),bad,P)=='unknown')
end)
test('planner absence budget failure or empty results remain unknown rather than unprofitable',function()
 local fake={};for k,v in pairs(P) do fake[k]=v end
 fake.buildPlans=function() return {},'planner-state-budget' end
 state(inv(item('godly','27')),inv(item('ancient','3')),'unknown',fake)
 fake.buildPlans=function() return {},nil end
 state(inv(item('godly','27')),inv(item('ancient','3')),'unknown',fake)
 fake.buildPlans=function() error('planner unavailable') end
 state(inv(item('godly','27')),inv(item('ancient','3')),'unknown',fake)
end)
test('empty authoritative opponent inventory is unprofitable but no owned item is a hold',function()
 state(inv(item('godly','27')),inv(),'unprofitable');state(inv(),inv(item('ancient','3')),'unknown')
end)
print('TOTAL '..n..' feasibility tests')
