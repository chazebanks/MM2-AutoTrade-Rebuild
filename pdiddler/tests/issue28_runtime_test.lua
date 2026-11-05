-- Whole production P4v10 + selected real policy. Controlled verified fixture
-- prices exercise policy behavior; they are not a Supreme catalog refresh.
local passed,failed=0,0
local function test(name,fn)
 local ok,why=pcall(fn)
 if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(why)) end
end
local function prepared(ownValues,theirValues)
 local f=fixture();f.own.items={};f.partnerInv.items={}
 for i,value in ipairs(ownValues) do f.own.items[i]=f:item('Our'..i,value) end
 for i,value in ipairs(theirValues) do f.partnerInv.items[i]=f:item('Their'..i,value) end
 f.policy={};for key,value in pairs(POLICY) do f.policy[key]=value end
 local realPlans=POLICY.buildPlans
 f.policy.buildPlans=function(...)
  f.plannerEvents[#f.plannerEvents+1]={at=f.now,total=f:total()}
  return realPlans(...)
 end
 return f
end
local function clearActions(f)
 f.removeEvents={};f.declineEvents={};f.offerEvents={};f.plannerEvents={};f.mouseDownEvents={}
end
local function stableExisting(ownValues,theirValues)
 local f=prepared(ownValues,theirValues)
 -- This override establishes a specific previously quoted offer; the actual
 -- controller, price verification, planner, ledger and mutation paths run.
 f.policy.selectOpener=function() return f.own.items[1],'fixture-existing-quote' end
 f:start();f:advance(3.4);eq(f:total(),ownValues[1])
 f:setTheir({f.partnerInv.items[1]});f:advance(7)
 eq(f:total(),ownValues[1]);eq(f.declines,0);clearActions(f)
 return f
end

for _,case in ipairs({
 {received=35,given=18,profit=17},
 {received=60,given=35,profit=25,cheap=18},
 {received=100,given=75,profit=25,cheap=18},
 {received=200,given=170,profit=30,cheap=18},
 {received=500,given=425,profit=75,cheap=18},
 {received=1295,given=1100,profit=195,cheap=18},
}) do
 test('opponent-first '..case.received..' selects the available size-aware neutral quote',function()
  local values={case.given};if case.cheap then values[#values+1]=case.cheap end
  local f=prepared(values,{case.received})
  if case.received==100 then f.own.items[1].type='Gun' end
  f:setTheir({f.partnerInv.items[1]});f:start();f:advance(4)
  eq(f:total(),case.given);eq(case.received-f:total(),case.profit)
  eq(f.declines,0);eq(f.accepts,0);eq(#f.offerEvents,1);eq(#f.removeEvents,0)
  assert(case.received-f:total()>=15,'initial strategy crossed the hard profit floor')
  f:advance(7);eq(f:total(),case.given);eq(#f.offerEvents,1);eq(#f.removeEvents,0)
  eq(f.lifecycle.state.completed,0)
 end)
end

test('actual opener chooses owned18 over40 against likely single42 reply',function()
 local f=prepared({40,18},{42,18})
 f:start();f:advance(3.4)
 eq(f:total(),18);eq(#f.offerEvents,1);eq(#f.removeEvents,0);eq(f.declines,0)
 f:setTheir({f.partnerInv.items[1]});f:advance(7)
 eq(f:total(),18);eq(42-f:total(),24);eq(#f.offerEvents,1);eq(#f.removeEvents,0)
 eq(f.accepts,0);eq(f.lifecycle.state.completed,0)
end)

test('safe25 against42 remains25 after addition to60 without an authorized denomination',function()
 local f=stableExisting({25,23,18,40},{42,18})
 f:setTheir({f.partnerInv.items[1],f.partnerInv.items[2]});f:advance(f.now+4)
 eq(f:total(),25);eq(60-f:total(),35)
 eq(#f.offerEvents,0);eq(#f.removeEvents,0);eq(f.declines,0);eq(f.accepts,0)
 f:advance(f.now+6);eq(f:total(),25);eq(#f.offerEvents,0);eq(#f.removeEvents,0)
end)

test('plus5 plus5 plus33 preserves cumulative thresholds and exact quarter-value concessions',function()
 local f=stableExisting({100,102.5,110.75,125},{200,205,210,243,210,243})
 f:setTheir({f.partnerInv.items[2]});f:advance(f.now+4)
 eq(f:total(),100);eq(#f.offerEvents,0);eq(#f.removeEvents,0)
 f:setTheir({f.partnerInv.items[3]});f:advance(f.now+4)
 eq(f:total(),102.5);eq(#f.offerEvents,1);eq(#f.removeEvents,1)
 eq(102.5-100,10*.25);assert(102.5-100<=10*.50)
 f:setTheir({f.partnerInv.items[4]});f:advance(f.now+4)
 eq(f:total(),110.75);eq(#f.offerEvents,2);eq(#f.removeEvents,2)
 eq(110.75-102.5,33*.25);assert(110.75-102.5<=33*.50)
 f:setTheir({f.partnerInv.items[5]});f:advance(f.now+4);eq(f:total(),110.75)
 f:setTheir({f.partnerInv.items[6]});f:advance(f.now+4);eq(f:total(),110.75)
 local offers,removes=#f.offerEvents,#f.removeEvents
 local same=f:item('SameValueSwap',243);f.partnerInv.items[#f.partnerInv.items+1]=same
 f:setTheir({same});f:advance(f.now+4);eq(f:total(),110.75)
 f:advance(f.now+5);eq(f:total(),110.75)
 eq(#f.offerEvents,offers);eq(#f.removeEvents,removes);eq(f.declines,0);eq(f.accepts,0)
end)

test('unsafe opponent removal still withdraws immediately before selecting a lower quote',function()
 local f=stableExisting({100,102.5,110.75,18},{200,210,243,125})
 f:setTheir({f.partnerInv.items[2]});f:advance(f.now+4);eq(f:total(),102.5)
 f:setTheir({f.partnerInv.items[3]});f:advance(f.now+4);eq(f:total(),110.75)
 clearActions(f);local changed=f.now
 f:setTheir({f.partnerInv.items[4]});f:advance(changed+.64)
 local remove=f.removeEvents[1];local decline=f.declineEvents[1]
 assert(remove or decline,'strategy delayed protection until voluntary planning debounce')
 local action=remove or decline
 assert(action.at-changed<.65,'unsafe quote remained offered through debounce')
 if not decline then
  eq(f:total(),0);f:advance(changed+4)
  assert(f:total()>0 and 125-f:total()>=15,'downward quote did not restore the hard floor')
 end
 eq(f.accepts,0);eq(f.lifecycle.state.completed,0)
end)

test('neutral incoming100 selects75 when equally desirable55 is also available',function()
 local f=prepared({75,55},{100})
 f:setTheir({f.partnerInv.items[1]});f:start();f:advance(4)
 eq(f:total(),75);eq(100-f:total(),25)
 eq(#f.offerEvents,1);eq(#f.removeEvents,0);eq(f.declines,0);eq(f.accepts,0)
end)

test('source-verified incoming fluctuation increases the chosen initial margin',function()
 local f=prepared({75,55},{100})
 f.rows['godly:Their1'].stability='Fluctuating'
 f:setTheir({f.partnerInv.items[1]});f:start();f:advance(4)
 eq(f:total(),55);eq(100-f:total(),45)
 eq(#f.offerEvents,1);eq(#f.removeEvents,0);eq(f.declines,0);eq(f.accepts,0)
end)

test('giving materially stronger demand preserves the disclosed reserve margin',function()
 local f=prepared({75,55},{100})
 f.rows['godly:Our1'].demand=6;f.rows['godly:Our2'].demand=6
 f.rows['godly:Their1'].demand=1
 f:setTheir({f.partnerInv.items[1]});f:start();f:advance(4)
 eq(f:total(),55);eq(100-f:total(),45)
 eq(#f.offerEvents,1);eq(#f.removeEvents,0);eq(f.declines,0);eq(f.accepts,0)
end)

test('missing source demand cannot produce a verified initial economic quote',function()
 local f=prepared({75,55,18},{100})
 f.rows['godly:Their1'].demand=nil
 f:setTheir({f.partnerInv.items[1]});f:start();f:advance(4)
 eq(f:total(),0);eq(#f.offerEvents,0);eq(#f.removeEvents,0)
 eq(f.controller.state.webhookCandidate,nil);eq(f.accepts,0);eq(f.lifecycle.state.completed,0)
 assert(f.declines<=1,'unknown source metadata started conflicting decline paths')
end)

print('RESULT '..passed..' passed; '..failed..' failed');assert(failed==0,'Issue28 actual strategy runtime failures')
