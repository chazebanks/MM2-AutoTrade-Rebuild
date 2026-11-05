-- Actual V15.4 loader + pricing/planner/eligibility; Roblox UI/remotes/transport are boundaries.
local Base=dofile('pdiddler/tests/v13_readiness_fixture.lua')
local Gui=dofile('pdiddler/tests/gui_boundary_fixture.lua')
local parse=dofile('pdiddler/tests/issue24_scanner_fixture.lua')({
 Seer={ItemName='Seer',Rarity='Godly',ItemType='Knife'},
 Boneblade={ItemName='Boneblade',Rarity='Godly',ItemType='Knife'},
 Batwing={ItemName='Batwing',Rarity='Ancient',ItemType='Knife'},
 Luger={ItemName='Luger',Rarity='Godly',ItemType='Gun'},
})
local path=arg[1] or 'pdiddler/pdiddler_FASTGATE_V6_INTEGRATED_TEST_v15_4_REACHABLE.lua'
local passed,failed=0,0
local function test(name,fn)
 local ok,why=pcall(fn)
 if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(why)) end
end
local function fixture(options)
 local o=options or {};local f=Base.new(o);Gui.attach(f)
 f.world=f:node('Workspace','Workspace');f.services={Workspace=f.world}
 f.char=f:node('Character','Model',f.world);f.lp.Character=f.char
 f:node('Humanoid','Humanoid',f.char,{Health=100});f:node('HumanoidRootPart','BasePart',f.char)
 function f.players:GetPlayerByUserId(uid)
  for _,p in ipairs(f.roster) do if p.UserId==uid and p.Parent==f.players then return p end end
 end
 local function module(name)
  local file=assert(io.open('pdiddler/'..name));local src=file:read('*a');file:close()
  return assert(load(src,'@'..name,'t',f.scope))()
 end
 local snapshot=dofile('pdiddler/snapshots/pdiddler_supreme_snapshot_2026_11_04.lua')
 f.profile={};for k,v in pairs(snapshot) do f.profile[k]=v end
 f.profile.isFresh=function() return not f.expired and snapshot.isFresh(snapshot.observedAtEpoch) end
 f.ownOwned={Boneblade=1};f.ownReads=0;f.scans={};f.retryScheduled={};f.rows={}
 f.scanner.getOwnInventory=function()
  f.ownReads=f.ownReads+1
  if f.ownReadHook then f.ownReadHook() end
  if f.ownUnavailable then return nil,'fixture-own-unavailable' end
  return parse({Weapons={Owned=f.ownOwned}})
 end
 f.scanner.isWhitelisted=function(uid) local r=f.records[tonumber(uid)];return r and r.state=='whitelist' or false end
 f.scanner.getVerificationState=function(uid)
  return {player=f.players:GetPlayerByUserId(tonumber(uid)),record=f.records[tonumber(uid)],
   scanning=f.scans[tonumber(uid)]==true,retryScheduled=f.retryScheduled[tonumber(uid)]==true}
 end
 f.scanner.setRequestState=function(p,state,reason) f.rows[p.UserId]={state=state,reason=reason} end
 f.scanner.getStatusOwner=function() return f.env.PDIDDLER_STATUS_OWNER end
 function f:setInventory(p,owned,state)
  self.records[p.UserId]={player=p,state=state or 'whitelist',inv=owned and parse({Weapons={Owned=owned}}) or nil}
  local white={};for _,other in ipairs(self.roster) do
   local r=self.records[other.UserId];if r and r.state=='whitelist' then white[#white+1]=other end
  end;self.white=white
 end
 function f:target(id,owned,state)
  local p=self:addPlayer(id);self:setInventory(p,owned,state);return p
 end
 local names={'pdiddler_readiness_v2_VISIBLE_SCAN.lua','pdiddler4_supreme_policy_v9_CONSISTENT_QUOTES.lua',
  'pdiddler_trade_lifecycle_v1.lua','pdiddler_trade_verification_v2.lua','pdiddler_webhook_outbox_v3.lua',
  'pdiddler_runtime_journal_v1.lua','pdiddler_discord_transport_v1.lua',
  'pdiddler3_feasibility_v1.lua','pdiddler3_outgoing_eligibility_v1.lua'}
 for _,name in ipairs(names) do local filename=name;f.sources[filename]=function() return module(filename) end end
 f.sources['pdiddler_supreme_snapshot_2026_11_04.lua']=function() return f.profile end
 f.sources['pdiddler4_accept_ui_gate_v1.lua']=function() return {read=function() end,step=function() end} end
 f.sources['pdiddler4_early_counter_policy_v5_OPPONENT_ADDED.lua']=function() return {choose=function() end} end
 f.sources['pdiddler1_fast_gate_v7_HEADLESS.lua']=function()
  f.events[#f.events+1]={name='gate',at=f.now}
  local generation=(f.env.PDIDDLER_FAST_GATE_GEN or 0)+1;f.env.PDIDDLER_FAST_GATE_GEN=generation
  f.env.PDIDDLER_FAST_GATE_STOP=function() end
  f.task.delay(10,function()
   local ids={};for _,p in ipairs(f.roster) do if p~=f.lp then ids[#ids+1]=tostring(p.UserId) end end;table.sort(ids)
   f.env.PDIDDLER_FAST_GATE_RESULT={state=o.gateState or 'PROCEED_UNVERIFIED',generation=generation,
    evidenceVersion=6,jobId=f.game.JobId,elapsed=10,roster=table.concat(ids,','),automaticHopAllowed=false,
    appearanceScans=2,appearanceScore=70,total=9}
  end)
 end
 local scannerBoundary=f.sources['pdiddler3_scanner_MODULE_v6_8_CRITICAL_PAUSE.lua']
 f.sources['pdiddler3_scanner_MODULE_v6_9_VERIFICATION_STATE.lua']=scannerBoundary
 f.sources['pdiddler4_balancer_SUPREME_v9_OPPONENT_ADDED.lua']=function() return {run=function(scanner,profile,strict,planner,telemetry)
  f.tradingScanner=scanner;f.tradeTelemetry=telemetry
  f.env.PDIDDLER_PART4_SESSION=1;return f.p4
 end} end
 local function outgoing()
  return {run=function(scanner)
   f.tradingScanner=scanner;f.events[#f.events+1]={name='outgoing',at=f.now}
   f.env.PDIDDLER_OUTGOING_SESSION=1;f.env.PDIDDLER_OUTGOING_CONTROLLER=f.out
   return f.out
  end}
 end
 f.sources['pdiddler3_outgoing_ROTATING_v17_TRANSACTION_LEASE.lua']=outgoing
 f.sources['pdiddler3_outgoing_ROTATING_v18_REACHABLE.lua']=outgoing
 function f:check() assert(#self.errors==0,table.concat(self.errors,'; '));assert(self.controller and not self.controller.error,tostring(self.controller and self.controller.error)) end
 return f
end

test('Seer3 exhausts the server without an outgoing availability blocker',function()
 local f=fixture();local p=f:target(2,{Seer=1});f:run(path);f:advance(20);f:check()
 f:advance(56);assert(f:count('hop')==0,'hopped before45 exhausted seconds')
 f:advance(65);f:check();assert(f:count('hop')==1,'unreachable player blocked exhaustion')
 assert(f.records[p.UserId].state=='whitelist' and not f.out.state.processed[p.UserId])
end)
test('concrete Batwing42 Luger18 offer remains available and blocks hopping',function()
 local f=fixture();local p=f:target(2,{Batwing=1,Luger=1});f:run(path);f:advance(100);f:check()
 assert(f:count('hop')==0)
 local a=f.controller.eligibility:assess(p);assert(a.state=='reachable')
 assert(f.controller.capabilities.autoAccept==false and f.controller.capabilities.discord==false)
end)
test('unknown expires30 second verification allowance but never becomes unprofitable',function()
 local f=fixture();local p=f:target(2,nil,'unknown');f.pending=true;f.retryScheduled[2]=true
 f:run(path);f:advance(40);f:check();assert(f:count('hop')==0)
 f:advance(60);local a=f.controller.eligibility and f.controller.eligibility:assess(p)
 f:advance(80);assert(f:count('hop')==0,'hopped before verification30 plus exhaustion45')
 f:advance(95);f:check();assert(f:count('hop')==1,'pending retry blocked hop indefinitely')
 assert(a and a.state=='unknown' and a.reason=='verification-unavailable')
 assert(not f.out.state.processed[p.UserId])
end)
test('unresolved fingerprint churn cannot restart verification allowance',function()
 local f=fixture();local p=f:target(2,nil,'unknown');f.pending=true;f:run(path)
 for t=20,80,10 do
  f:advance(t);f:setInventory(p,{Seer=1});f.records[2].inv.unmapped=1
 end
 f:advance(95);f:check();assert(f:count('hop')==1)
end)
test('unknown gaining authoritative reachable inventory cancels exhaustion',function()
 local f=fixture();local p=f:target(2,nil,'unknown');f:run(path);f:advance(75)
 f:setInventory(p,{Batwing=1});f:advance(140);f:check()
 assert(f:count('hop')==0 and f.controller.eligibility:assess(p).state=='reachable')
end)
test('processed player with unknown inventory or an active rescan cannot block hopping',function()
 local f=fixture();f:target(2,nil,'unknown');f.pending=true;f.scans[2]=true
 f.out.state.processed[2]='ignored';f:run(path);f:advance(65);f:check();assert(f:count('hop')==1)
end)
test('identical own cache loss and recovery does not rediscover a reachable player',function()
 local f=fixture();local p=f:target(2,{Batwing=1});f:run(path);f:advance(20);f:check()
 local e=f.controller.eligibility;e:queue({p},{})
 e:invalidate();assert(e:assess(p).state=='unknown')
 assert(e:refresh(true));local q=e:queue({p},{})
 assert(q.available and not q.discovered,'same cache recovery counted as new reachability')
end)
test('price expiry cannot age into hopping permission',function()
 local f=fixture();f:target(2,nil,'unknown');f:run(path);f:advance(20);f.expired=true
 f:advance(150);assert(f:count('hop')==0 and f.controller.stage=='PRICE_HOLD' and f.outStopped)
end)
test('native loading hold cannot age into hopping permission',function()
 local f=fixture();f:target(2,nil,'unknown');f:run(path);f:advance(20)
 f:node('Status','TextLabel',f.pg,{Text='Loading World'});f:advance(150)
 assert(f:count('hop')==0 and f.controller.stage=='READINESS_HOLD')
end)
test('transaction ownership cannot age into hopping permission',function()
 local f=fixture();f:target(2,nil,'unknown');f:run(path);f:advance(20)
 local life=f.controller.lifecycle
 assert(life:begin({id='held',job='job',epoch=1,partner=2,root={},gui=f.pg,version=f.profile.version}))
 f:advance(150);f:check();assert(f:count('hop')==0)
end)
test('final transport recheck rejects a newly reachable target',function()
 local f=fixture();local p=f:target(2,{Seer=1});f:run(path);f:advance(20);f:check()
 f:setInventory(p,{Batwing=1});local ok=f.canTeleport()
 assert(not ok and f:count('hop')==0 and not f.outStopped,'transport ignored newly reachable inventory')
end)
test('scanner rows distinguish reachable unprofitable and unknown with reasons',function()
 for _,row in ipairs({{{Batwing=1},'whitelist','reachable'},{{Seer=1},'unavailable','unprofitable'},{nil,'unknown','unknown'}}) do
  local f=fixture();local p=f:target(2,row[1],row[1] and 'whitelist' or 'unknown');f:run(path);f:advance(20);f:check()
  assert(f.rows[2] and f.rows[2].state==row[2],tostring(f.rows[2] and f.rows[2].state))
  assert(f.rows[2].reason:find('Outgoing: '..row[3],1,true) and f.rows[2].reason:find(' | ',1,true))
 end
end)
test('V15.3 owner prevents competing successor controllers or startup UI',function()
 local f=fixture();local old={jobId='job',running=true};f.env.PDIDDLER_INTEGRATION_V15_3_GUI_STATUS=old
 assert(f:run(path)==old);f:advance(30);assert(f:count('p2')==0 and #f.guiCreated==0)
end)
test('same-job execution keeps one startup and trading owner',function()
 local f=fixture();f:target(2,{Batwing=1});local owner=f:run(path);f:advance(20)
 assert(f:run(path)==owner);f:advance(25);f:check()
 assert(f:count('p2')==1 and f:count('gate')==1 and f:count('outgoing')==1 and not f:startupPanel())
end)
assert(failed==0,tostring(failed)..' loader cases failed')
print('TOTAL '..passed..' actual successor loader integration tests')
