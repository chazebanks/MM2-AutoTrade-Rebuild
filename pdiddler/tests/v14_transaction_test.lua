local L=dofile('pdiddler/pdiddler_trade_lifecycle_v1.lua')
local n=0
local function test(name,fn) fn();n=n+1;print('PASS '..name) end
local function fixture(approved)
 local f={now=0,clicks=0,holds=0}
 f.profile={version='p',isFresh=function() return true end}
 f.native={approved=approved==true,evidenceId='OFFLINE-FIXTURE-ONLY',placeId=142823291,
  acceptControlVerified=true,completionVerified=true,inventoryVerified=true,
  read=function() return {stage='accept',ready=true,control='button'} end,
  readInventory=function(c) return {id=c.id,job=c.job,epoch=c.epoch,complete=true,counts={A=1},version='p',items={}} end,
  classifyCompletion=function(e) return e end,bind=function(fn) f.event=fn;return {Disconnect=function() end} end}

 f.verifier={reconcile=function() return nil,'fixture-no-completed-delta' end}
 f.l=L.new({verifier=f.verifier,policy={},jobId='job',now=function() return f.now end,profile=f.profile,native=f.native,
  onHold=function() f.holds=f.holds+1 end})
 f.context={id='tx',job='job',epoch=1,partner=2,root={},gui={},version='p',isCurrent=function() return true end}
 assert(f.l:begin(f.context))
 f.proof={id='tx',job='job',epoch=1,partner=2,root=f.context.root,gui=f.context.gui,version='p',
  ourSig='a',theirSig='b',plannedOurSig='a',valuedTheirSig='b',ourTotal=100,theirTotal=115,
  identitiesVerified=true,quantitiesVerified=true,changing=false,ourAccepted=false,theirAccepted=false}
 function f:click() self.clicks=self.clicks+1;return true end
 return f
end
test('missing native evidence cannot be enabled by a requested flag',function()
 local f=fixture(false);local ok,why=f.l:consider(f.proof,function() return f:click() end)
 assert(not ok and why=='native-contract-unverified' and f.clicks==0)
end)
test('first acceptance requires an uninterrupted extra second and acts once',function()
 local f=fixture(true);assert(not f.l:consider(f.proof,function() return f:click() end))
 f.now=.99;assert(not f.l:consider(f.proof,function() return f:click() end))
 f.now=1;assert(f.l:consider(f.proof,function() return f:click() end));assert(f.clicks==1)
 f.now=3;assert(not f.l:consider(f.proof,function() return f:click() end));assert(f.clicks==1)
end)
test('changed offer restarts eligibility before any native click',function()
 local f=fixture(true);f.l:consider(f.proof,function() return f:click() end)
 f.now=2;f.proof.theirSig='c';f.proof.valuedTheirSig='c'
 assert(not f.l:consider(f.proof,function() return f:click() end));assert(f.clicks==0)
 f.now=3;assert(f.l:consider(f.proof,function() return f:click() end))
end)
test('unsafe unknown mismatched and expired proofs never authorize',function()
 for _,mutate in ipairs({function(p) p.theirTotal=114.99 end,function(p) p.identitiesVerified=false end,
  function(p) p.plannedOurSig='wrong' end,function(p) p.partner=99 end,function(p) p.changing=true end}) do
  local f=fixture(true);mutate(f.proof);f.l:consider(f.proof,function() return f:click() end)
  f.now=5;assert(not f.l:consider(f.proof,function() return f:click() end));assert(f.clicks==0)
 end
 local f=fixture(true);f.profile.isFresh=function() return false end
 assert(not f.l:consider(f.proof,function() return f:click() end))
end)
test('read-control yield cannot authorize a stale proof',function()
 local f=fixture(true);f.native.read=function() f.proof.theirSig='changed';return {stage='accept',ready=true,control='button'} end
 f.l:consider(f.proof,function() return f:click() end);f.now=2
 assert(not f.l:consider(f.proof,function() return f:click() end));assert(f.clicks==0)
end)
test('uncertain click outcome is consumed and blocks subsequent work',function()
 local f=fixture(true);f.l:consider(f.proof,function() return false end);f.now=1
 assert(not f.l:consider(f.proof,function() error('ack lost') end));assert(not f.l:canStartWork())
 assert(f.l.state.phase=='unconfirmed' and f.holds==1)
end)
test('accepted close retains lease while unaccepted close preserves rotation',function()
 local f=fixture(false);f.l:accepted('tx');f.l:close('tx','window-closed')
 assert(not f.l:canStartWork() and f.l.state.phase=='unconfirmed')
 local g=fixture(false);g.l:close('tx','window-closed');assert(g.l:canStartWork())
 assert(g.l.state.completed==0)
end)
test('old transaction callbacks cannot close the new transaction',function()
 local f=fixture(false);f.l:close('tx','declined');local c={}
 for k,v in pairs(f.context) do c[k]=v end;c.id='new';c.epoch=2
 assert(f.l:begin(c));assert(not f.l:close('tx','stale-close'));assert(f.l.state.active.id=='new')
end)
test('open quote can never be sent as a completed report',function()
 local f=fixture(false);assert(not f.l:settle({kind='verified-offer'},{}));assert(f.l.state.completed==0)
end)
test('uncaught proof reader error cannot perform or repeat a native action',function()
 local f=fixture(true);local ok,why=f.l:consider(f.proof,function() return f:click() end,function() error('stale UI') end)
 assert(not ok and why=='proof-read-failed' and f.clicks==0)
end)
test('only correlated completed event and two stable raw reads release ownership',function()
 local f=fixture(true);local queued=0
 f.verifier.reconcile=function(t,e,after)
  assert(t.beforeComplete and t.before.A==1 and e.id==t.id and after.stableReads>=2)
  return {id=t.id,kind='completed-trade',verified=true,rawInventoryVerified=true,provenance='exact-raw-delta-v2'}
 end
 f.l:consider(f.proof,function() return f:click() end);f.now=1;f.l:consider(f.proof,function() return f:click() end)
 f.l:close('tx','closed');assert(not f.l:canStartWork())
 f.event({kind='completed',id='old',job='job',epoch=1,partner=2,ourSig='a',theirSig='b'})
 f.now=1.5;assert(not f.l:poll());assert(f.l.state.completed==0)
 f.event({kind='completed',id='tx',job='job',epoch=1,partner=2,ourSig='a',theirSig='b'})
 assert(not f.l:poll());assert(f.l.state.completed==0)
 f.now=2.1;assert(f.l:poll());assert(f.l:canStartWork() and f.l.state.completed==1)
 assert(not f.l:poll());assert(f.l.state.completed==1)
end)
test('close observation and terminal counters are idempotent',function()
 local f=fixture(true);f.l:accepted('tx');f.l:close('tx','close');f.l:close('tx','duplicate')
 assert(f.l.state.closed==1)
end)
test('verified completion survives unavailable reporting and is counted once',function()
 local f=fixture(true);local completed={id='tx',kind='completed-trade',verified=true}
 local after={complete=true,counts={B=1}}
 f.verifier.reconcile=function() return completed end
 f.l=L.new({jobId='job',profile=f.profile,policy={},verifier=f.verifier,native=f.native,
  now=function() return f.now end,outbox={enqueue=function() return false,'disabled' end}})
 assert(f.l:begin(f.context));f.l:accepted('tx')
 f.l:settle({kind='completed'},after)
 assert(f.l.state.completed==1 and f.l.state.lastReport==completed and f.l.state.inventory==after)
 f.l:settle({kind='completed'},after);assert(f.l.state.completed==1)
end)
print('TOTAL '..n..' transaction lifecycle tests')
