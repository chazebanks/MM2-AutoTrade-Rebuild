-- Complete inherited loader contract with real V2 readiness at the fixture boundary.
local file=assert(io.open('pdiddler/tests/v11_integration_test.lua'))
local source=file:read('*a');file:close()
source=source:gsub('pdiddler4_supreme_policy_v7_VERIFIED_STEPS.lua','pdiddler4_supreme_policy_v9_CONSISTENT_QUOTES.lua')
 :gsub('pdiddler4_balancer_SUPREME_v6_VERIFIED_STEPS.lua','pdiddler4_balancer_SUPREME_v9_OPPONENT_ADDED.lua')
 :gsub('pdiddler4_early_counter_policy_v2_BOUNDED_VALUE.lua','pdiddler4_early_counter_policy_v5_OPPONENT_ADDED.lua')
 :gsub('v11_VERIFIED_READINESS','v15_OPPONENT_ADDED'):gsub('V11_VERIFIED_READINESS','V15_OPPONENT_ADDED')
 :gsub('V11','V15'):gsub('pdiddler_readiness_v1.lua','pdiddler_readiness_v2_VISIBLE_SCAN.lua')
 :gsub('tests/integration_fixture.lua','tests/v13_readiness_fixture.lua')
source=source:gsub('pdiddler3_outgoing_ROTATING_v16_EXACT_IDENTITY.lua','pdiddler3_outgoing_ROTATING_v17_TRANSACTION_LEASE.lua')
local point=' return f\nend\ntest('
local setup=[=[
 for _,name in ipairs({'pdiddler_trade_lifecycle_v1.lua','pdiddler_trade_verification_v2.lua','pdiddler_webhook_outbox_v3.lua','pdiddler_runtime_journal_v1.lua','pdiddler_discord_transport_v1.lua'}) do
  local filename=name
  f.sources[filename]=function() return module(filename) end
 end
 return f
end
test(]=]
local start=assert(source:find(point,1,true));source=source:sub(1,start-1)..setup..source:sub(start+#point)
source=source..[[
for _,key in ipairs({'PDIDDLER_INTEGRATION_V11_VERIFIED_READINESS','PDIDDLER_INTEGRATION_V12_PORTFOLIO_LEDGER','PDIDDLER_INTEGRATION_V13_VISIBLE_READINESS'}) do
 test('legacy integration '..key..' prevents a competing V13 owner',function()
  local f=fixture();local old={jobId='job',running=true};f.env[key]=old
  assert(f:run(path)==old);f:advance(25);assert(f:count('p2')==0 and f:count('outgoing')==0)
 end)
end
local function inventory(f)
 local frame=f:node('Inventory','Frame',f.pg,{Visible=false})
 for i=1,10000 do f:node('Template'..i,'TextLabel',frame,{Text='Loading World'}) end
 frame.forbidChildren=true;return frame
end
test('large hidden native GUI reaches gate and the existing trading owner exactly once',function()
 local f=fixture();inventory(f);f:run(path);f:advance(20)
 assert(f.controller.stage=='TRADING' and #f.errors==0)
 assert(f:count('p2')==1 and f:count('gate')==1 and f:count('outgoing')==1)
 assert(f.controller.readinessState.loadingInspection.visited<100)
 f:advance(25);assert(f:count('outgoing')==1)
end)
test('real loading alongside large hidden inventory still fences all automation',function()
 local f=fixture();inventory(f);local label=f:node('ZStatus','TextLabel',f.pg,{Text='Loading World'})
 f:run(path);f:advance(20)
 assert(f:count('p2')==1 and f:count('gate')==0 and not f.scannerLoads)
 label.Visible=false;f:advance(35)
 assert(f.controller.stage=='TRADING' and f:count('outgoing')==1 and #f.errors==0)
end)
test('incoming request alongside large hidden inventory still blocks bot hopping',function()
 local f=fixture({gateState='BOT_PATTERN_FOR_REVIEW'});inventory(f);f.nodes.ReceivingRequest.Visible=true
 f:run(path);f:advance(20)
 assert(f.controller.stage=='BOT_HOLD' and f:count('hop')==0 and not f.scannerLoads)
 f.nodes.ReceivingRequest.Visible=false;f:advance(24)
 assert(f:count('hop')==1 and #f.errors==0)
end)
test('transaction lease fences outgoing copies and hopping after GUI close',function()
 local f=fixture();local p=f:addPlayer(2,'whitelist');f.white={p};f:run(path);f:advance(20)
 local life=f.controller.lifecycle
 assert(life:begin({id='tx',job='job',epoch=1,partner=2,root={},gui=f.pg,version='fixture'}))
 assert(f.tradingScanner.hasActiveTradeLifecycle() and #f.tradingScanner.getWhitelist()==0)
 assert(f.tradingScanner.getRecord(2).state=='whitelist')
 f:advance(80);assert(f:count('hop')==0)
 life:close('tx','normal-unaccepted-close');assert(#f.tradingScanner.getWhitelist()==1)
end)
test('no runtime flags turn a quote into an evidenced native completion contract',function()
 local f=fixture();f.env.PDIDDLER_AUTO_ACCEPT=true;f.env.PDIDDLER_NATIVE_VERIFIED=true
 f:run(path);f:advance(20)
 assert(not f.controller.capabilities.autoAccept and not f.controller.capabilities.completion and not f.controller.capabilities.discord)
 assert(f.controller.lifecycle.blocker=='native-contract-unverified')
end)
print('TOTAL '..n..' V14 loader integration tests')
]]
assert(load(source,'v13-loader-contract','t',_G))()
