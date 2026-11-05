-- Actual production P4 and policy; fixture hooks observe native action boundaries.
local passed,failed=0,0
local function test(name,fn)
 local ok,why=pcall(fn)
 if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(why)) end
end
local function setup(values,received,ownedQty,configure)
 local f=fixture();f.own.items={};f.partnerInv.items={}
 for i,v in ipairs(values) do f.own.items[i]=f:item('Our'..i,v,ownedQty and ownedQty[i]) end
 for i,v in ipairs(received) do f.partnerInv.items[i]=f:item('Their'..i,v) end
 f.policy={};for k,v in pairs(POLICY) do f.policy[k]=v end
 f.policy.selectOpener=function() return f.own.items[1],'fixture' end
 local realPlans=POLICY.buildPlans
 f.policy.buildPlans=function(...)
  f.plannerEvents[#f.plannerEvents+1]={at=f.now,total=f:total()}
  return realPlans(...)
 end
 if configure then configure(f) end
 f:start();f:advance(3.4);eq(f:total(),values[1])
 f:setTheir({f.partnerInv.items[1]});f:advance(7)
 eq(f:total(),values[1]);eq(f.declines,0)
 f.removeEvents={};f.declineEvents={};f.offerEvents={};f.plannerEvents={};f.mouseDownEvents={}
 return f
end
local function first(events,why) assert(events[1],why);return events[1] end
local function urgent(event,changed,limit)
 assert(event.at-changed<limit,string.format('action latency %.3fs exceeds %.3fs',event.at-changed,limit))
end
local function noPlannerBefore(f,event)
 for _,p in ipairs(f.plannerEvents) do assert(p.at>event.at,'planner ran before urgent native action') end
end

test('405/1295 to405/115 declines before debounce without planner',function()
 local f=setup({135,100,15},{1295,115},{3,1,1})
 -- The actual displayed quote is three verified copies, totaling405.
 f.ourPicks={{id='Our1',name='Our1',value=135,qty=3}};f:render('YourOffer',f.ourPicks);eq(f:total(),405)
 local changed=f.now;f:setTheir({f.partnerInv.items[2]});f:advance(changed+.64)
 local e=first(f.declineEvents,'unsafe405-value displayed stack remained live throughout debounce')
 urgent(e,changed,.65);noPlannerBefore(f,e);eq(f.declines,1);eq(#f.removeEvents,0);eq(f.accepts,0)
end)

test('33/101 to33/33 clears before debounce then restores exact +15 quote',function()
 local f=setup({33,18,7},{101,33})
 local changed=f.now;f:setTheir({f.partnerInv.items[2]});f:advance(changed+.64)
 local e=first(f.removeEvents,'unsafe single-copy quote remained live throughout debounce')
 urgent(e,changed,.24);noPlannerBefore(f,e);eq(f.declines,0);eq(f:total(),0)
 f:advance(changed+4);eq(f:total(),18);eq(33-f:total(),15);eq(f.declines,0);eq(f.accepts,0)
end)

test('multiple visible slots decline without attempting a multi-step clear',function()
 local f=setup({300,105,18},{1295,115})
 f.ourPicks={{id='Our1',name='Our1',value=300,qty=1},{id='Our2',name='Our2',value=105,qty=1}}
 f:render('YourOffer',f.ourPicks)
 local changed=f.now;f:setTheir({f.partnerInv.items[2]});f:advance(changed+.64)
 local e=first(f.declineEvents,'unsafe multiple-slot quote was not declined')
 urgent(e,changed,.65);noPlannerBefore(f,e);eq(f.declines,1);eq(#f.removeEvents,0)
end)

test('stacked offered quantity declines without clicking native stack removal',function()
 local f=setup({55,18},{150,40},{2,1})
 f.ourPicks={{id='Our1',name='Our1',value=55,qty=2}};f:render('YourOffer',f.ourPicks)
 local changed=f.now;f:setTheir({f.partnerInv.items[2]});f:advance(changed+.64)
 local e=first(f.declineEvents,'unsafe offered stack was not declined')
 urgent(e,changed,.65);noPlannerBefore(f,e);eq(f.declines,1);eq(#f.removeEvents,0)
end)

for _,mode in ipairs({'local accepted','local unknown','partner accepted'}) do
 test(mode..' unsafe quote declines before debounce without any remove',function()
  local f=setup({33,18},{101,33})
  if mode=='local accepted' then f.root.children.YourOffer.children.Accepted.Visible=true
  elseif mode=='local unknown' then f.root.children.YourOffer.children.Accepted=nil
  else f.accepted.Visible=true end
  local changed=f.now;f:setTheir({f.partnerInv.items[2]});f:advance(changed+.64)
  local e=first(f.declineEvents,'unsafe acceptance state held the unsafe quote')
  urgent(e,changed,.65);noPlannerBefore(f,e);eq(f.declines,1);eq(#f.removeEvents,0);eq(f.accepts,0)
 end)
end

test('failed emergency remove gets one click and bounded decline without planner',function()
 local f=setup({33,18},{101,33});f.ignoreRemove=true
 local changed=f.now;f:setTheir({f.partnerInv.items[2]});f:advance(changed+.64)
 local e=first(f.declineEvents,'unverified emergency remove did not decline within debounce')
 urgent(e,changed,.65);noPlannerBefore(f,e);eq(#f.removeEvents,1);eq(f.declines,1)
 assert(e.at-f.removeEvents[1].at<=.24+.00001,'emergency verification exceeded .24s')
 f:advance(changed+4);eq(#f.removeEvents,1);eq(f.declines,1);eq(#f.offerEvents,0)
end)

test('missing emergency remove button declines immediately without planner',function()
 local f=setup({33,18},{101,33})
 f.root.children.YourOffer.children.Container.children.NewItem1.children.Container.children.ActionButton=nil
 local changed=f.now;f:setTheir({f.partnerInv.items[2]});f:advance(changed+.64)
 local e=first(f.declineEvents,'missing removal control held unsafe quote')
 urgent(e,changed,.65);noPlannerBefore(f,e);eq(#f.removeEvents,0);eq(f.declines,1)
end)

test('initial speculative opener keeps the original twelve-second empty grace',function()
 local f=fixture();f:start();f:advance(11.9)
 eq(f.declines,0);eq(#f.removeEvents,0);assert(f:total()>0)
 f:advance(12.7);eq(f.declines,1);eq(f.accepts,0)
end)

test('removing last item after verified safe quote withdraws urgently and remains bounded',function()
 local f=setup({33,18},{101,33})
 local changed=f.now;f:setTheir({});f:advance(changed+.64)
 local e=f.declineEvents[1] or f.removeEvents[1]
 assert(e,'verified-safe quote remained offered after opponent removed everything')
 urgent(e,changed,.65);noPlannerBefore(f,e)
 assert(f.declines==1 or f:total()==0,'empty opponent retained our positive exposure')
 f:advance(changed+12.9);eq(f.declines,1);eq(f.accepts,0)
end)

test('safe low-value quote stays unchanged before and after debounce',function()
 local f=setup({18,7},{33,35})
 local changed=f.now;f:setTheir({f.partnerInv.items[2]});f:advance(changed+.64)
 eq(f:total(),18);eq(#f.removeEvents,0);eq(#f.offerEvents,0);eq(f.declines,0)
 f:advance(changed+3);eq(f:total(),18);eq(#f.removeEvents,0);eq(f.declines,0)
end)

test('safe qualifying addition cannot mutate before the original stability interval',function()
 local f=setup({100,105,110},{200,220})
 local changed=f.now;f:setTheir({f.partnerInv.items[2]});f:advance(changed+.64)
 eq(f:total(),100);eq(#f.removeEvents,0);eq(#f.offerEvents,0);eq(f.declines,0)
 f:advance(changed+4);eq(f:total(),105);eq(f.declines,0);eq(f.accepts,0)
end)

test('unknown Common remains unresolved hold and invalidates prior verified candidate',function()
 local f=setup({33,18},{101,33})
 assert(f.controller.state.webhookCandidate,'missing initial verified quote candidate')
 local common={id='CommonInternal',name='Doge',value=999999,qty=1}
 local changed=f.now;f:setTheir({f.partnerInv.items[2],common});f:advance(changed+.64)
 eq(f.controller.state.webhookCandidate,nil);eq(f:total(),33)
 eq(#f.removeEvents,0);eq(#f.offerEvents,0);eq(f.declines,0)
 f:advance(changed+3);eq(f:total(),33);eq(f.declines,0);eq(f.accepts,0)
 assert(f.controller.state.webhookCandidate==nil,'unknown Common produced a verified quote')
end)

test('malformed opponent quantity holds without assigning a zero-valued economic proof',function()
 local f=setup({33,18},{101,33})
 local amount=f.root.children.TheirOffer.children.Container.children.NewItem1.children.Container.children.Amount
 amount.Text='x???';local changed=f.now;f:advance(changed+2)
 eq(f:total(),33);eq(#f.removeEvents,0);eq(f.declines,0);eq(f.controller.state.webhookCandidate,nil)
end)

test('missing opponent offer layout is unknown and cannot start a fake empty timer',function()
 local f=setup({33,18},{101,33})
 f.root.children.TheirOffer.children.Container=nil;local changed=f.now
 f:advance(changed+.64);eq(f.controller.state.webhookCandidate,nil)
 eq(#f.removeEvents,0);eq(#f.offerEvents,0)
 if f.declines==1 then urgent(first(f.declineEvents,'missing layout safety decline missing'),changed,.65)
 else f:advance(changed+13);eq(f.declines,0) end
 f:advance(changed+65);eq(f.declines,1);eq(f.accepts,0)
end)

test('unknown own internal identity declines before debounce',function()
 local f=setup({33,18},{101,33})
 f.root.children.YourOffer.children.Container.children.NewItem1.attributes.ItemId='UnmappedOwn'
 local changed=f.now;f:advance(changed+.64)
 local e=first(f.declineEvents,'unknown own identity was left exposed')
 urgent(e,changed,.65);noPlannerBefore(f,e);eq(f.declines,1);eq(f.accepts,0)
end)

for _,rawChange in ipairs({'internal ID','chroma flag','malformed raw quantity'}) do
 test(rawChange..' change invalidates verified approval before debounce',function()
  local f=setup({33,18},{101,33})
  assert(f.controller.state.webhookCandidate,'missing initial verified quote candidate')
  local slot=f.root.children.TheirOffer.children.Container.children.NewItem1
  if rawChange=='internal ID' then slot.attributes.ItemId='UnmappedPartner'
  elseif rawChange=='chroma flag' then local tags=node('Tags','Frame',slot);node('Chroma','Frame',tags,{Visible=true})
  else slot.children.Container.children.Amount.Text='x???' end
  local changed=f.now;f:advance(changed+.64)
  eq(f.controller.state.webhookCandidate,nil);eq(f:total(),33)
  eq(#f.removeEvents,0);eq(#f.offerEvents,0);eq(f.accepts,0)
 end)
end

test('valid raw quantity formatting during replacement preserves one normal reward',function()
 local f=setup({100,105,110},{200,220})
 local changed=false
 f.onRemove=function()
  if not changed then changed=true
   f.root.children.TheirOffer.children.Container.children.NewItem1.children.Container.children.Amount.Text='1'
  end
 end
 f:setTheir({f.partnerInv.items[2]});f:advance(f.now+5)
 assert(changed,'replacement never reached native removal')
 eq(f:total(),105);eq(f.declines,0);eq(f.accepts,0)
 eq(#f.removeEvents,1);eq(#f.offerEvents,1);eq(f.offerEvents[1].id,'Our2')
end)

test('unsafe partial insertion declines before adding the remaining plan item',function()
 local f=setup({100,60,45},{200,220,30})
 local changed=nil
 f.onOffer=function()
  if not changed then changed=f.now;f:setTheir({f.partnerInv.items[3]}) end
 end
 f:setTheir({f.partnerInv.items[2]});f:advance(f.now+5)
 assert(changed,'actual combination planner never inserted first replacement item')
 local e=first(f.declineEvents,'unsafe partial insertion did not decline')
 urgent(e,changed,.65);eq(#f.offerEvents,1);eq(f.declines,1);eq(f.accepts,0)
end)

test('unsafe change at post-insert yield declines with one action path',function()
 local f=setup({100,105,110},{200,220,50})
 local changed=nil
 f.onWait=function(dt)
  if not changed and dt==.15 and f:total()==105 then
   changed=f.now;f:setTheir({f.partnerInv.items[3]})
  end
 end
 f:setTheir({f.partnerInv.items[2]});f:advance(f.now+5)
 assert(changed,'actual insertion yield was not reached')
 local e=first(f.declineEvents,'unsafe post-insert quote did not decline')
 urgent(e,changed,.65);eq(#f.offerEvents,1);eq(f.declines,1);eq(f.accepts,0)
end)

test('safe-empty change during post-remove yield retains original recovery behavior',function()
 local f=setup({100,105,110},{200,220,200})
 local changed=false
 f.onWait=function(dt)
  if not changed and dt==.08 and f:total()==0 then changed=true;f:setTheir({f.partnerInv.items[3]}) end
 end
 f:setTheir({f.partnerInv.items[2]});f:advance(f.now+5)
 assert(changed,'actual post-remove yield was not reached')
 eq(f:total(),100);eq(f.declines,0);eq(f.accepts,0)
end)

test('opponent removal during mouse-down permits only the in-flight withdrawal',function()
 local f=setup({100,105,30},{200,220,50})
 local changed=nil
 f.onMouseDown=function()
  if not changed then changed=f.now;f:setTheir({f.partnerInv.items[3]}) end
 end
 f:setTheir({f.partnerInv.items[2]});f:advance(f.now+5)
 assert(changed,'actual native mouse-down was not reached')
 local e=f.declineEvents[1] or f.removeEvents[1]
 assert(e,'unsafe quote remained after native mouse-down yield')
 urgent(e,changed,.65)
 assert(f.declines==1 or f:total()<=35,'post-yield controller retained an unsafe physical quote')
 eq(f.accepts,0)
end)

test('unsafe removal during failed normal-remove verification declines without retry',function()
 local f=setup({100,105,110},{200,220,50});f.ignoreRemove=true
 local changed=nil
 f.onWait=function(dt)
  if not changed and dt==.06 and #f.removeEvents>0 then
   changed=f.now;f:setTheir({f.partnerInv.items[3]})
  end
 end
 f:setTheir({f.partnerInv.items[2]});f:advance(f.now+5)
 assert(changed,'actual removal verification yield was not reached')
 local e=first(f.declineEvents,'unsafe failed normal remove remained live')
 urgent(e,changed,.65);eq(#f.removeEvents,1);eq(#f.offerEvents,0);eq(f.declines,1);eq(f.accepts,0)
end)

test('own identity becomes unknown during post-insert yield and declines once',function()
 local f=setup({100,105,110},{200,220})
 local changed=nil
 f.onWait=function(dt)
  if not changed and dt==.15 and f:total()==105 then
   changed=f.now
   f.root.children.YourOffer.children.Container.children.NewItem1.attributes.ItemId='WrongInsertedId'
  end
 end
 f:setTheir({f.partnerInv.items[2]});f:advance(f.now+5)
 assert(changed,'actual post-insert verification was not reached')
 local e=first(f.declineEvents,'unverified physical insertion did not decline')
 urgent(e,changed,.65);eq(#f.offerEvents,1);eq(f.declines,1);eq(f.accepts,0)
end)

test('urgent decline acknowledgement uncertainty never sends another decline path',function()
 local f=setup({33,18},{101,33});f.ignoreDecline=true;f.accepted.Visible=true
 local changed=f.now;f:setTheir({f.partnerInv.items[2]});f:advance(changed+4)
 local e=first(f.declineEvents,'urgent decline remote was never sent')
 urgent(e,changed,.65);eq(f.declines,1);eq(#f.removeEvents,0);eq(#f.offerEvents,0)
 assert(f.controller.state.blocked,'uncertain decline did not stop transaction ownership')
 eq(f.lifecycle.state.completed,0);eq(f.accepts,0)
end)

test('missing own offer layout cannot be interpreted as an empty offer to refill',function()
 local f=setup({33,18},{101,33})
 f.root.children.YourOffer.children.Container=nil;local changed=f.now
 f:advance(changed+2);eq(#f.offerEvents,0);eq(#f.removeEvents,0)
 eq(f.controller.state.webhookCandidate,nil);eq(f.lifecycle.state.completed,0);eq(f.accepts,0)
end)

test('unsafe UI acknowledgement at final verification yield declines before committing plan',function()
 local f=setup({100,105,110},{200,220,50})
 local delayed=false;local changed=nil
 -- Model a sent OfferItem whose native slot rendering arrives during final verification.
 f.onOffer=function()
  if not delayed then delayed=true;f.root.children.YourOffer.children.Container.children={} end
 end
 f.onWait=function(dt)
  if delayed and not changed and dt==.08 and f:total()==105 then
   changed=f.now;f:render('YourOffer',f.ourPicks);f:setTheir({f.partnerInv.items[3]})
  end
 end
 f:setTheir({f.partnerInv.items[2]});f:advance(f.now+5)
 assert(changed,'actual final slot-verification yield was not reached')
 local e=first(f.declineEvents,'unsafe final verification quote did not decline')
 urgent(e,changed,.65);eq(#f.offerEvents,1);eq(f.declines,1);eq(f.accepts,0)
 eq(f.controller.state.webhookCandidate,nil)
end)

test('one offered copy clears even when we own several copies',function()
 local f=setup({33,18},{101,33},{3,1})
 local changed=f.now;f:setTheir({f.partnerInv.items[2]});f:advance(changed+.64)
 local e=first(f.removeEvents,'single offered copy was treated as an uncertain stack')
 urgent(e,changed,.24);noPlannerBefore(f,e);eq(f:total(),0);eq(f.declines,0)
 f:advance(changed+4);eq(f:total(),18);eq(f.declines,0);eq(f.accepts,0)
end)

test('valid quantity formatting alone causes no physical reset or new concession',function()
 local f=setup({100,105,110},{200,220})
 local slot=f.root.children.TheirOffer.children.Container.children.NewItem1
 slot.children.Container.children.Amount.Text='1'
 f:advance(f.now+3);eq(f:total(),100);eq(#f.removeEvents,0);eq(#f.offerEvents,0);eq(f.declines,0)
 f:setTheir({f.partnerInv.items[2]});f:advance(f.now+4);eq(f:total(),105)
 eq(#f.removeEvents,1);eq(#f.offerEvents,1);eq(f.accepts,0)
end)

test('malformed quantity during a replacement aborts while our empty side stays safe',function()
 local f=setup({100,105,110},{200,220})
 local changed=false
 f.onRemove=function()
  if not changed then changed=true
   f.root.children.TheirOffer.children.Container.children.NewItem1.children.Container.children.Amount.Text='x???'
  end
 end
 f:setTheir({f.partnerInv.items[2]});f:advance(f.now+4)
 assert(changed,'actual replacement remove was not reached')
 eq(f:total(),0);eq(#f.offerEvents,0);eq(f.declines,0);eq(f.accepts,0)
 eq(f.controller.state.webhookCandidate,nil)
end)

test('stable quote validation is independent of optional telemetry snapshots',function()
 local f=setup({18,7},{35,40},nil,function(x) x.telemetry.build=function() return nil end end)
 local bound=assert(f.boundRead(),'actual transaction boundary unavailable')
 eq(bound.quoteInvalidated,false)
 local active=assert(f.lifecycle.state.active,'actual lifecycle ownership unavailable')
 active.readyKey='previous-quote-readiness';active.readySince=f.now-10
 local changed=f.now;f:setTheir({f.partnerInv.items[2]});f:advance(changed+.2)
 eq(f.boundRead(),bound);eq(bound.quoteInvalidated,true)
 eq(active.readyKey,nil);eq(active.readySince,nil)
 f:advance(changed+.64);eq(bound.quoteInvalidated,true);eq(#f.removeEvents,0);eq(#f.offerEvents,0)
 f:advance(changed+2);eq(bound.quoteInvalidated,false)
 eq(f:total(),18);eq(f.declines,0);eq(f.accepts,0)
end)

test('failed emergency withdrawal uses one total .24s deadline from mouse-down',function()
 local f=setup({33,18},{101,33});f.ignoreRemove=true
 local changed=f.now;f:setTheir({f.partnerInv.items[2]});f:advance(changed+.64)
 local click=first(f.mouseDownEvents,'emergency withdrawal did not begin')
 local decline=first(f.declineEvents,'failed emergency withdrawal did not decline')
 local elapsed=decline.at-click.at
 assert(elapsed<=.24+.000001,string.format('total emergency deadline %.3fs exceeded .240s',elapsed))
 eq(#f.mouseDownEvents,1);eq(#f.removeEvents,1);eq(f.declines,1)
 noPlannerBefore(f,decline);eq(#f.offerEvents,0);eq(f.accepts,0)
end)

for _,quantityProof in ipairs({'missing Amount','nontext Amount'}) do
 test(quantityProof..' cannot authorize an emergency single-copy withdrawal',function()
  local f=setup({33,18},{101,33})
  local box=f.root.children.YourOffer.children.Container.children.NewItem1.children.Container
  if quantityProof=='missing Amount' then box.children.Amount=nil
  else box.children.Amount.ClassName='Frame' end
  local changed=f.now;f:setTheir({f.partnerInv.items[2]});f:advance(changed+.64)
  local e=first(f.declineEvents,'unverified own live quantity did not decline')
  urgent(e,changed,.65);noPlannerBefore(f,e)
  eq(#f.mouseDownEvents,0);eq(#f.removeEvents,0);eq(#f.offerEvents,0)
  eq(f.declines,1);eq(f.accepts,0);eq(f.lifecycle.state.completed,0)
 end)
end

for _,acceptance in ipairs({'accepted','unknown'}) do
 test('unchanged unresolved Common plus local '..acceptance..' declines immediately',function()
  local f=setup({33,18},{101,33})
  local common={id='UnknownCommonInternal',name='Doge',value=999999,qty=1}
  f:setTheir({f.partnerInv.items[1],common});f:advance(f.now+2)
  eq(f.root.children.YourOffer.children.Accepted.Visible,false)
  eq(f:total(),33);eq(f.declines,0);eq(#f.removeEvents,0);eq(#f.offerEvents,0)
  eq(f.controller.state.webhookCandidate,nil)
  local bound=assert(f.boundRead(),'actual transaction boundary unavailable')
  local rawBefore=bound.safetyRawSig
  if acceptance=='accepted' then f.root.children.YourOffer.children.Accepted.Visible=true
  else f.root.children.YourOffer.children.Accepted=nil end
  local changed=f.now;f:advance(changed+.64)
  local e=first(f.declineEvents,'unchanged unresolved offer held a local '..acceptance..' state')
  urgent(e,changed,.65);noPlannerBefore(f,e)
  eq(bound.safetyRawSig,rawBefore);eq(f.declines,1)
  eq(#f.mouseDownEvents,0);eq(#f.removeEvents,0);eq(#f.offerEvents,0)
  eq(f.accepts,0);eq(f.lifecycle.state.completed,0)
 end)
end

test('first mirrored reply cannot turn emergency clear into an unanchored increase',function()
 local f=fixture();f.own.items={f:item('Opener',7),f:item('Replacement',20),f:item('LargeReplacement',100)}
 f.partnerInv.items={f:item('TheirLarge',200),f:item('Opener',7)}
 f.policy={};for k,v in pairs(POLICY) do f.policy[k]=v end
 f.policy.selectOpener=function() return f.own.items[1],'fixture' end
 f:start();f:advance(3.4);eq(f:total(),7)
 f:setTheir(f.partnerInv.items);f:advance(f.now+5)
 assert(f:total()<=7 or f.declines==1,'unanchored emergency restoration increased7 to'..tostring(f:total()))
 eq(f.accepts,0);eq(f.lifecycle.state.completed,0)
end)

test('unanchored positive subfloor reply cannot erase withdrawn ceiling when opponent changes again',function()
 local f=fixture();f.own.items={f:item('Opener',33),f:item('LowReplacement',18),f:item('LargeReplacement',100)}
 f.partnerInv.items={f:item('TheirFirst',42),f:item('TheirNext',200)}
 f.policy={};for k,v in pairs(POLICY) do f.policy[k]=v end
 f.policy.selectOpener=function() return f.own.items[1],'fixture' end
 f:start();f:advance(3.4);eq(f:total(),33)
 f:setTheir({f.partnerInv.items[1]});f:advance(f.now+.64)
 -- In v9 the old33 is still present; in v10 the urgent withdrawal is already verified.
 -- Neither physical state grants an economic anchor for a greater giveaway.
 f:setTheir({f.partnerInv.items[2]});f:advance(f.now+5)
 assert(f:total()<=33 or f.declines==1,'changed opponent bypassed withdrawn33 ceiling with'..tostring(f:total()))
 eq(f.accepts,0);eq(f.lifecycle.state.completed,0)
end)

for _,earlyFailure in ipairs({'missing layout','unresolved own identity','expired profile'}) do
 test('local accepted '..earlyFailure..' preserves acceptance history before safety early exit',function()
  local f=setup({33,18},{101,33})
  -- Polling must preserve observed acceptance even when an event callback has not run.
  f.root.children.YourOffer.children.Accepted.Visible=true
  if earlyFailure=='missing layout' then f.root.children.YourOffer.children.Container=nil
  elseif earlyFailure=='unresolved own identity' then
   f.root.children.YourOffer.children.Container.children.NewItem1.attributes.ItemId='UnmappedOwnAfterAcceptance'
  else f.profile.isFresh=function() return false end end
  f:advance(f.now+1)
  eq(f.declines,1);eq(#f.removeEvents,0);eq(#f.offerEvents,0);eq(f.accepts,0)
  assert(f.controller.state.blocked,'observed local acceptance was forgotten on '..earlyFailure)
  eq(f.lifecycle.state.phase,'unconfirmed');eq(f.lifecycle.state.completed,0)
 end)
end

print('RESULT '..passed..' passed; '..failed..' failed');assert(failed==0,'Issue27 production runtime failures')
