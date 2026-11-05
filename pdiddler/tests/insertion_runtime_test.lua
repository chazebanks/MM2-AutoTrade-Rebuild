-- Whole production controller and unchanged policy10/early5. Real-value cases
-- use the actual pinned source at its observation epoch, never refreshed values.
local passed,failed=0,0
local function test(name,fn)
 if JOBID_INVESTIGATION and name~='inherited JobId-only mutation has no direct standalone P4 fence' then return end
 local ok,why=pcall(fn)
 if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(why)) end
end
local function copy(t) local out={};for k,v in pairs(t or {}) do out[k]=v end;return out end
local function pickSignature(plan)
 local out={}
 for _,p in ipairs(plan.picks) do out[#out+1]=table.concat({tostring(p.page),tostring(p.id),tostring(p.checkerId),tostring(p.value),tostring(p.qty)},':') end
 return table.concat(out,'|')
end
local function tracked(f,freeze)
 f.selectedPlans={};f.reservations={};f.commits={}
 f.policy=copy(POLICY)
 f.policy.selectInitialOffer=function(...)
  local p,why,meta=POLICY.selectInitialOffer(...)
  if p then
   f.selectedPlans[#f.selectedPlans+1]={plan=p,key=p.key,signature=pickSignature(p),total=p.rawTotal,profit=p.rawProfit,meta=copy(meta)}
   if freeze then
    for _,pick in ipairs(p.picks) do if not table.isfrozen(pick) then table.freeze(pick) end end
    if not table.isfrozen(p.picks) then table.freeze(p.picks) end
   end
  end
  return p,why,meta
 end
 f.policy.reserveOffer=function(state,stage,sig,plan,current,received,now)
  local ok,why=POLICY.reserveOffer(state,stage,sig,plan,current,received,now)
  if ok then f.reservations[#f.reservations+1]={stage=stage,plan=plan,current=current,received=received,at=now} end
  return ok,why
 end
 f.policy.confirmConcession=function(state,sig,plan,live,now)
  local ok=POLICY.confirmConcession(state,sig,plan,live,now)
  if ok then f.commits[#f.commits+1]={at=now,plan=plan,live=live,ledger=copy(state.ledger)} end
  return ok
 end
 return f
end
local function actual(f,checkerId,kind,qty)
 local r=assert(SOURCE.get('godly',tostring(checkerId)))
 local it=f:item(r.name,r.supremeValue,qty)
 it.checkerId=tostring(checkerId);it.type=kind
 return it
end
local function realTrade(freeze)
 local f=fixture();f.profile=copy(SOURCE)
 f.profile.isFresh=function() return SOURCE.isFresh(SOURCE.observedAtEpoch) end
 f.own.items={actual(f,27,'Knife'),actual(f,481,'Gun'),actual(f,1032,'Knife',2)}
 f.partnerInv.items={actual(f,728,'Gun'),actual(f,1031,'Knife')}
 tracked(f,freeze);f:setTheir(f.partnerInv.items)
 return f
end
local function nativeIds(f)
 local out={};for _,event in ipairs(f.offerEvents) do out[#out+1]=event.id end
 return table.concat(out,',')
end
local function assertImmutableSelections(f)
 for _,selected in ipairs(f.selectedPlans) do
  eq(selected.plan.key,selected.key);eq(pickSignature(selected.plan),selected.signature)
  eq(selected.plan.rawTotal,selected.total);eq(selected.plan.rawProfit,selected.profit)
 end
end
local function assertInitialLedger(f,total,received)
 eq(#f.commits,1)
 local c=f.commits[1];eq(c.live.rawTotal,total)
 eq(c.ledger.anchorTotal,total);eq(c.ledger.lastVerifiedTotal,total)
 eq(c.ledger.maxReceived,received);eq(c.ledger.earlySpent,0);eq(c.ledger.lateSpent,0)
end

test('real380 quote keeps selected310 plan but inserts Immortal twice then Ice then Bone',function()
 local f=realTrade(true);local prefixes={}
 f.onOffer=function() prefixes[#prefixes+1]=f:total() end
 f:start();f:advance(4)
 local s=assert(f.selectedPlans[1],'production selector did not return an initial quote')
 eq(s.total,310);eq(s.profit,70)
 assert(math.abs(s.meta.targetProfit-70.5)<1e-6,'source strategy target changed')
 eq(#prefixes,4)
 for i,expected in ipairs({135,270,303,310}) do
  eq(prefixes[i],expected);assert(prefixes[i]>0 and 380-prefixes[i]>=15,'positive native prefix crossed profit floor')
 end
 local facts=POLICY.strategyFacts(s.plan,POLICY.bundleAssessment(f.partnerInv.items,'theirs',f.profile))
 assert(math.abs(facts.targetProfit-70.5)<1e-6,'execution reordering changed preferred profit')
 eq(s.plan.picks[1].name,'Boneblade');eq(s.plan.picks[1].qty,1)
 eq(s.plan.picks[2].name,'Iceblaster');eq(s.plan.picks[2].qty,1)
 eq(s.plan.picks[3].name,'Immortal');eq(s.plan.picks[3].qty,2)
 eq(nativeIds(f),'Immortal,Immortal,Iceblaster,Boneblade')
 eq(f:total(),310);eq(380-f:total(),70);eq(#f.offerEvents,4);eq(#f.removeEvents,0)
 assertImmutableSelections(f);assertInitialLedger(f,310,380)
 eq(f.declines,0);eq(f.accepts,0);eq(f.lifecycle.state.completed,0)
end)

local function synthetic(ownRows,theirValues,freeze)
 local f=fixture();f.own.items={};f.partnerInv.items={}
 for _,r in ipairs(ownRows) do f.own.items[#f.own.items+1]=f:item(r[1],r[2],r[3]) end
 for i,value in ipairs(theirValues) do f.partnerInv.items[i]=f:item('Their'..i,value) end
 tracked(f,freeze);f:setTheir({f.partnerInv.items[1]})
 return f
end

test('contribution200 from two100 copies precedes a single150 unit',function()
 local f=synthetic({{'Hundred',100,2},{'OneFifty',150,1}},{400},true)
 f:start();f:advance(4)
 local s=assert(f.selectedPlans[1]);eq(s.total,350);eq(s.profit,50)
 eq(s.plan.picks[1].value,100);eq(s.plan.picks[1].qty,2);eq(s.plan.picks[2].value,150)
 eq(nativeIds(f),'Hundred,Hundred,OneFifty')
 assertImmutableSelections(f);assertInitialLedger(f,350,400);eq(f.declines,0);eq(f.accepts,0)
end)

test('equal contributions preserve original selected-row order',function()
 local f=synthetic({{'A_Hundred',100,2},{'Z_TwoHundred',200,1}},{470},true)
 f:start();f:advance(4)
 local s=assert(f.selectedPlans[1]);eq(s.total,400)
 eq(s.plan.picks[1].value*s.plan.picks[1].qty,200)
 eq(s.plan.picks[2].value*s.plan.picks[2].qty,200)
 eq(nativeIds(f),'A_Hundred,A_Hundred,Z_TwoHundred')
 assertImmutableSelections(f);assertInitialLedger(f,400,470);eq(f.declines,0);eq(f.accepts,0)
end)

test('execution reordering retains reservation plan identity and zero initial concession spend',function()
 local f=realTrade(true);f:start();f:advance(4)
 local selected=assert(f.selectedPlans[1]);eq(#f.reservations,1)
 eq(f.reservations[1].plan,selected.plan);eq(f.reservations[1].stage,'initial')
 eq(f.reservations[1].current,0);eq(f.reservations[1].received,380)
 eq(f.commits[1].plan,selected.plan);assertInitialLedger(f,310,380)
 assertImmutableSelections(f);eq(f.accepts,0);eq(f.lifecycle.state.completed,0)
end)

test('delayed native slot acknowledgement cannot verify an invisible310 offer',function()
 local f=realTrade(true);f.delayOwnRender=true
 f.onOffer=function()
  if #f.offerEvents==1 then
   f.delayedAt=f.now
   f.task.spawn(function() f.task.wait(.9);f.delayOwnRender=false;f:render('YourOffer',f.ourPicks);f.ackAt=f.now end)
  end
 end
 f:start();f:advance(1.8)
 eq(nativeIds(f),'Immortal,Immortal,Iceblaster,Boneblade')
 eq(#f.commits,0);eq(f.controller.state.webhookCandidate,nil)
 f:advance(4);eq(f:total(),310);assertInitialLedger(f,310,380)
 assert(f.commits[1].at>=assert(f.ackAt),'plan committed before actual slot acknowledgement')
 assertImmutableSelections(f);eq(f.declines,0);eq(f.accepts,0)
end)

for _,failure in ipairs({'first large copy','second large copy','missing large acknowledgement'}) do
 test(failure..' cannot become a verified310 quote or completion',function()
  local f=realTrade(true);local largeCalls=0
  if failure=='missing large acknowledgement' then
   f.ignoreOffer=function(id) return id=='Immortal' and f.offers==1 end
  else
   f.failOffer=function(id)
    if id=='Immortal' then largeCalls=largeCalls+1;return largeCalls==(failure=='first large copy' and 1 or 2) end
    return false
   end
  end
  f:start();f:advance(8)
  eq(f.offerEvents[1].id,'Immortal')
  eq(#f.commits,0);eq(f.controller.state.webhookCandidate,nil)
  assert(f.declines<=1,'failed insertion started competing decline paths')
  eq(f.accepts,0);eq(f.lifecycle.state.completed,0);assertImmutableSelections(f)
  if failure=='first large copy' then eq(#f.offerEvents,1)
  elseif failure=='second large copy' then eq(#f.offerEvents,2)
  else eq(#f.offerEvents,4) end
 end)
end

test('opponent removal after first large copy stops the unsafe duplicate insertion',function()
 local f=realTrade(true);local changed=nil
 f.onOffer=function()
  if not changed then changed=f.now;f:setTheir({f.partnerInv.items[2]}) end
 end
 f:start();f:advance(4)
 eq(nativeIds(f),'Immortal');eq(#f.commits,0)
 local decline=assert(f.declineEvents[1],'unsafe135/135 quote was not declined')
 assert(decline.at-changed<.65,'unsafe large copy waited for voluntary debounce')
 eq(f.declines,1);eq(f.accepts,0);eq(f.lifecycle.state.completed,0);assertImmutableSelections(f)
end)

for _,acceptance in ipairs({'local true','local unknown','partner true'}) do
 test(acceptance..' after first large copy forbids another insertion',function()
  local f=realTrade(true);local changed=false
  f.onOffer=function()
   if not changed then
    changed=true
    if acceptance=='local true' then f.root.children.YourOffer.children.Accepted.Visible=true
    elseif acceptance=='local unknown' then f.root.children.YourOffer.children.Accepted=nil
    else f.accepted.Visible=true end
   end
  end
  f:start();f:advance(4)
  eq(nativeIds(f),'Immortal');eq(#f.commits,0);eq(f.controller.state.webhookCandidate,nil)
  eq(f.accepts,0);eq(f.lifecycle.state.completed,0)
  assert(f.declines<=1,'acceptance race started multiple decline paths')
  if acceptance=='local true' then assert(f.controller.state.blocked,'observed acceptance lost transaction ownership') end
  assertImmutableSelections(f)
 end)
end

test('late large slot after opponent change cannot resume the abandoned310 transaction',function()
 local f=realTrade(true);f.delayOwnRender=true;local changed=nil;local acknowledged=nil
 f.onOffer=function()
  if #f.offerEvents==1 then
   f.task.spawn(function()
    f.task.wait(.03);changed=f.now;f:setTheir({f.partnerInv.items[2]})
    f.task.wait(.22);f.delayOwnRender=false;f:render('YourOffer',f.ourPicks);acknowledged=f.now
   end)
  end
 end
 f:start();f:advance(1.8)
 eq(nativeIds(f),'Immortal');eq(#f.commits,0)
 local action=f.declineEvents[1] or f.removeEvents[1]
 assert(action,'late unsafe slot acknowledgement was left exposed')
 assert(action.at-acknowledged<.24,'late unsafe slot was not protected on the next observation')
 assert(f.declines==1 or f:total()==0,'late unsafe slot retained positive exposure')
 eq(f.accepts,0);eq(f.lifecycle.state.completed,0)
 local abandoned=f.selectedPlans[1].plan
 f:advance(5)
 for _,committed in ipairs(f.commits) do assert(committed.plan~=abandoned,'stale310 reservation committed after opponent change') end
 assertImmutableSelections(f)
end)

test('later replacement removes last cheap filler then protects remaining large exposure',function()
 local f=synthetic({{'Bone',7,1},{'Ice',33,1},{'Immortal',135,2},{'Replacement',335,1}},{245,135,100},true)
 f.rows['godly:Their2'].stability='Fluctuating'
 f:setTheir({f.partnerInv.items[1],f.partnerInv.items[2]})
 f:start();f:advance(4);eq(f:total(),310);eq(#f.commits,1)
 eq(nativeIds(f),'Immortal,Immortal,Ice,Bone')
 f.offerEvents={};f.removeEvents={};f.mouseDownEvents={};local changed=nil;local removedValue=nil
 f.onRemove=function()
  if not changed then removedValue=310-f:total();changed=f.now;f:setTheir({f.partnerInv.items[3]}) end
 end
 f:setTheir({f.partnerInv.items[1],f.partnerInv.items[2],f.partnerInv.items[3]});f:advance(f.now+4)
 eq(removedValue,7)
 local decline=assert(f.declineEvents[1],'unsafe remainder after cheap removal was not declined')
 assert(decline.at-changed<.65,'unsafe remaining large contribution waited for planning')
 eq(#f.removeEvents,1);eq(#f.offerEvents,0);eq(#f.commits,1);eq(f.declines,1)
 eq(f.reservations[#f.reservations].plan.rawTotal,335)
 eq(f.reservations[#f.reservations].stage,'early')
 eq(f.commits[1].ledger.earlySpent,0);eq(f.accepts,0);eq(f.lifecycle.state.completed,0)
 assertImmutableSelections(f)
end)

local malformed={
 {'missing value',function(p) p.value=nil end},
 {'numeric string value',function(p) p.value='7' end},
 {'zero value',function(p) p.value=0 end},
 {'negative value',function(p) p.value=-7 end},
 {'NaN value',function(p) p.value=0/0 end},
 {'infinite value',function(p) p.value=math.huge end},
 {'missing quantity',function(p) p.qty=nil end},
 {'numeric string quantity',function(p) p.qty='1' end},
 {'zero quantity',function(p) p.qty=0 end},
 {'fractional quantity',function(p) p.qty=1.5 end},
 {'infinite quantity',function(p) p.qty=math.huge end},
 {'overflow contribution',function(p) p.value=1e308;p.qty=2 end},
}
for _,case in ipairs(malformed) do
 test('invalid selected-row '..case[1]..' aborts before native mutation',function()
  local f=realTrade(false);local choose=f.policy.selectInitialOffer
  f.policy.selectInitialOffer=function(...)
   local plan,why,meta=choose(...)
   if plan then case[2](plan.picks[1]) end
   return plan,why,meta
  end
  f:start();f:advance(4)
  eq(#f.offerEvents,0);eq(#f.mouseDownEvents,0);eq(#f.removeEvents,0);eq(#f.commits,0)
  eq(f.accepts,0);eq(f.lifecycle.state.completed,0);eq(f.controller.state.webhookCandidate,nil)
 end)
end

local function afterFirstLarge(label,change)
 local f=realTrade(true);local changed=false
 f.onOffer=function()
  if not changed then
   changed=true;eq(f:total(),135);change(f)
  end
 end
 f:start();f:advance(4)
 assert(changed,'first large physical insertion was not reached: '..label)
 eq(nativeIds(f),'Immortal');eq(#f.commits,0)
 eq(f.controller.state.webhookCandidate,nil);eq(f.accepts,0);eq(f.lifecycle.state.completed,0)
 assertImmutableSelections(f)
 return f
end

test('changed exact partner username or UserId proof stops after the first large copy',function()
 for _,proof in ipairs({'username','UserId'}) do
  afterFirstLarge(proof,function(f)
   if proof=='username' then f.root.children.TheirOffer.children.Username.Text='@Different_User'
   else
    local players=f.game:GetService('Players')
    local original=players.GetPlayerByUserId
    players.GetPlayerByUserId=function(self,id)
     if id==f.target.UserId then return nil end
     return original(self,id)
    end
   end
  end)
 end
end)

test('inherited JobId-only mutation has no direct standalone P4 fence',function()
 local f=realTrade(true);local mutation=nil
 f.onOffer=function()
  if not mutation and f.offerEvents[#f.offerEvents].id=='Immortal' then
   mutation={at=f.now,index=#f.offerEvents,oldJob=f.game.JobId,root=f.root,session=f.env.PDIDDLER_PART4_SESSION}
   f.game.JobId='different-job'
  end
 end
 f:start();f:advance(4)
 assert(mutation,'first large physical copy was not reached')
 print('JOBID INVESTIGATION controller='..f.controller.kind..' changed-after-send='..mutation.index..' later-sends='..(#f.offerEvents-mutation.index)..' sequence='..nativeIds(f)..' final-value='..f:total()..' commits='..#f.commits..' completed='..f.lifecycle.state.completed)
 if JOBID_INVESTIGATION then
  eq(#f.offerEvents,mutation.index) -- Intentional RED: asks for a direct fence absent in both predecessors.
  return
 end
 eq(#f.offerEvents,4);eq(f:total(),310);assertInitialLedger(f,310,380)
 eq(f.root,mutation.root);eq(f.env.PDIDDLER_PART4_SESSION,mutation.session)
 eq(f.controller.jobId,mutation.oldJob);assert(f.game.JobId~=mutation.oldJob)
 eq(f.declines,0);eq(f.accepts,0);eq(f.lifecycle.state.completed,0)
 assertImmutableSelections(f)
end)

test('JobId change with an invalidated owner or native root stops after first large copy',function()
 for _,invalidation in ipairs({'owner','root'}) do
  afterFirstLarge('JobId plus '..invalidation,function(f)
   f.game.JobId='different-job'
   if invalidation=='owner' then f.env.PDIDDLER_PART4_SESSION=999
   else f.root.Visible=false end
  end)
 end
end)

test('expired source profile stops after the first large copy',function()
 afterFirstLarge('profile expiry',function(f) f.profile.isFresh=function() return false end end)
end)

test('partner closing native window stops after the first large copy',function()
 afterFirstLarge('native close',function(f) f.root.Visible=false end)
end)

test('controller stop or stale transaction session stops after the first large copy',function()
 for _,ownerChange in ipairs({'controller stop','stale session'}) do
  afterFirstLarge(ownerChange,function(f)
   if ownerChange=='controller stop' then f.controller.stop()
   else f.env.PDIDDLER_PART4_SESSION=999 end
  end)
 end
end)

print('RESULT '..passed..' passed; '..failed..' failed');assert(failed==0,'Value-first full controller runtime failures')
