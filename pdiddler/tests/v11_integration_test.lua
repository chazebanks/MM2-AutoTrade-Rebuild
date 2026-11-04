local F=dofile('pdiddler/tests/integration_fixture.lua')
local P=dofile('pdiddler/pdiddler4_supreme_policy_v7_VERIFIED_STEPS.lua')
local path='pdiddler/pdiddler_FASTGATE_V6_INTEGRATED_TEST_v11_VERIFIED_READINESS.lua'
local n=0
local function test(name,fn) fn();n=n+1;print('PASS '..name) end
local function fixture(options)
 local o=options or {};local f=F.new(o)
 f.world=f:node('Workspace','Workspace');f.services={Workspace=f.world}
 f.char=f:node('Character','Model',f.world);f.lp.Character=f.char
 f:node('Humanoid','Humanoid',f.char,{Health=100});f:node('HumanoidRootPart','BasePart',f.char)
 local function module(name)
  local file=assert(io.open('pdiddler/'..name));local src=file:read('*a');file:close()
  return assert(load(src,'@'..name,'t',f.scope))()
 end
 f.sources['pdiddler_readiness_v1.lua']=function() return module('pdiddler_readiness_v1.lua') end
 f.profile={liveReady=true,version='fixture',get=function(_,id) return {page='godly',id=id,name='A',supremeValue=100,demand=3,stability='Stable',verified=true} end,
 coverage=function() return {total=190} end,isFresh=function() return not f.expired end}
 f.scanner.getOwnInventory=function() return {items={{page='godly',cat='Weapons',type='Knife',id='raw_A',checkerId='7',name='A',value=999,qty=1}}} end
 f.scanner.isWhitelisted=function() return true end
 f.sources['pdiddler_supreme_snapshot_2026_11_03_ISSUE4.lua']=function() return f.profile end
 f.sources['pdiddler4_supreme_policy_v7_VERIFIED_STEPS.lua']=function() return P end
 f.sources['pdiddler4_accept_ui_gate_v1.lua']=function() return {read=function() end,step=function() end} end
 f.sources['pdiddler4_early_counter_policy_v2_BOUNDED_VALUE.lua']=function() return {choose=function() end} end
 f.sources['pdiddler1_fast_gate_TEST_v6_VALID_EVIDENCE.lua']=function()
  f.events[#f.events+1]={name='gate',at=f.now}
  local gen=(f.env.PDIDDLER_FAST_GATE_GEN or 0)+1;f.env.PDIDDLER_FAST_GATE_GEN=gen
  f.env.PDIDDLER_FAST_GATE_STOP=function() f.gateStopped=true end
  f.task.delay(10,function()
   local ids={};for _,p in ipairs(f.roster) do if p~=f.lp then ids[#ids+1]=tostring(p.UserId) end end;table.sort(ids)
   f.env.PDIDDLER_FAST_GATE_RESULT={state=o.gateState or 'PROCEED_UNVERIFIED',generation=o.staleGen and gen-1 or gen,
   evidenceVersion=6,jobId='job',elapsed=10,roster=table.concat(ids,','),automaticHopAllowed=false,appearanceScans=2,appearanceScore=70,total=9}
  end)
 end
 f.sources['pdiddler4_balancer_SUPREME_v6_VERIFIED_STEPS.lua']=function() return {run=function(scanner,profile,logic,planner,telemetry)
  assert(profile==f.profile and logic==P and planner==P and telemetry.build()==nil)
  f.tradingScanner=scanner;f.tradeTelemetry=telemetry;f.env.PDIDDLER_PART4_SESSION=1;return f.p4
 end} end
 f.sources['pdiddler3_outgoing_ROTATING_v16_EXACT_IDENTITY.lua']=function() return {run=function(scanner)
  assert(scanner==f.tradingScanner);f.events[#f.events+1]={name='outgoing',at=f.now}
  f.env.PDIDDLER_OUTGOING_SESSION=1;return f.out
 end} end
 return f
end
test('ready stack preserves repricing and launches one existing outgoing owner',function()
 local f=fixture();f:run(path);f:advance(20);assert(f.controller.stage=='TRADING');assert(#f.errors==0)
 assert(f:count('outgoing')==1);assert(f.tradingScanner.getOwnInventory().items[1].value==100)
 assert(f.scanner.getOwnInventory().items[1].value==999)
end)
test('visible Loading World blocks gate and scanner until it resolves',function()
 local f=fixture();local label=f:node('Status','TextLabel',f.pg,{Text='Loading World...'})
 f:run(path);f:advance(25);assert(f:count('gate')==0 and not f.scannerLoads)
 label.Visible=false;f:advance(40);assert(f.controller.stage=='TRADING' and f:count('p2')==1 and f:count('gate')==1)
end)
test('persistent Loading Character enters bounded hold without restarting selectors',function()
 local f=fixture();f:node('Status','TextLabel',f.pg,{Text='Loading Character'})
 f:run(path);f:advance(70);assert(f.controller.stage=='READINESS_HOLD')
 assert(f:count('p2')==1 and f:count('gate')==0 and not f.scannerLoads and f:count('hop')==0)
end)
test('character can arrive after selector without premature automation',function()
 local f=fixture();f.lp.Character=nil;f:run(path);f:advance(10);assert(f:count('gate')==0)
 f.lp.Character=f.char;f:advance(25);assert(f.controller.stage=='TRADING')
end)
test('bot branch preserves sole P5 transport owner',function()
 local f=fixture({gateState='BOT_PATTERN_FOR_REVIEW'});f:run(path);f:advance(20)
 assert(f:count('hop')==1 and not f.scannerLoads and f:count('outgoing')==0)
end)
test('wrong-generation bot result does not authorize a hop',function()
 local f=fixture({gateState='BOT_PATTERN_FOR_REVIEW',staleGen=true});f:run(path);f:advance(20)
 assert(f.controller.lastDecision=='PROCEED_UNVERIFIED' and f:count('hop')==0)
end)
test('unknown and animation-only evidence still permits trading without bot hop',function()
 local f=fixture({gateState='ANIMATION_CLUSTER_FOR_REVIEW'});f:run(path);f:advance(20)
 assert(f.controller.stage=='TRADING' and f:count('hop')==0)
end)
test('runtime loading fences whitelist copies while preserving eligibility records',function()
 local f=fixture();local p=f:addPlayer(2,'whitelist');f.white={p};f:run(path);f:advance(20)
 f:node('Status','TextLabel',f.pg,{Text='Loading World'});f:advance(21)
 assert(not f.tradingScanner.isAutomationReady() and #f.tradingScanner.getWhitelist()==0)
 assert(f.tradingScanner.getRecord(2).state=='automation-hold' and f.records[2].state=='whitelist')
 assert(f:count('hop')==0)
end)
test('brief runtime loading recovers without duplicate outgoing controller',function()
 local f=fixture();f:run(path);f:advance(20);f.lp.Character=nil;f:advance(22)
 f.lp.Character=f.char;f:advance(24);assert(f.controller.stage=='TRADING' and not f.outStopped)
 assert(f:count('outgoing')==1)
end)
test('persistent runtime loading stops new requests and hopping after bounded wait',function()
 local f=fixture();f:run(path);f:advance(20);f.lp.Character=nil;f:advance(38)
 assert(f.controller.stage=='READINESS_HOLD' and f.outStopped and f:count('hop')==0)
end)
test('uncertain accepted outcome synchronously stops outgoing and hopping',function()
 local f=fixture();f:run(path);f:advance(20);f.tradeTelemetry.holdOutcome('unconfirmed')
 assert(f.outStopped and f.hopperStopped and f.controller.stage=='OUTCOME_HOLD')
 f:advance(80);assert(f:count('hop')==0 and f.controller.completedTrades==nil)
end)
test('native acceptance and Discord cannot be enabled by legacy globals',function()
 local f=fixture();f.env.PDIDDLER_AUTO_ACCEPT=true;f.env.PDIDDLER_DISCORD_WEBHOOK_URL='not-sent'
 f:run(path);f:advance(20)
 assert(not f.controller.capabilities.autoAccept and not f.controller.capabilities.completion and not f.controller.capabilities.discord)
end)
test('expiry retains independent price hold and safe P4 close path',function()
 local f=fixture();f:run(path);f:advance(20);f.expired=true;f:advance(22)
 assert(f.controller.stage=='PRICE_HOLD' and f.outStopped and not f.p4Stopped and f:count('hop')==0)
end)
test('V11 refuses live V10 owner without replacing it',function()
 local f=fixture();local old={jobId='job',running=true};f.env.PDIDDLER_INTEGRATION_V10_BOUNDED_SELECTION=old
 assert(f:run(path)==old);f:advance(20);assert(f:count('p2')==0)
end)
print('TOTAL '..n..' V11 integration tests')
