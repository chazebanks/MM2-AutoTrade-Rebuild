-- Re-run the complete current loader contract against the versioned successor.
local file=assert(io.open('pdiddler/tests/v11_integration_test.lua'))
local source=file:read('*a');file:close()
source=source:gsub('pdiddler4_supreme_policy_v7_VERIFIED_STEPS.lua','pdiddler4_supreme_policy_v8_PORTFOLIO_LEDGER.lua')
 :gsub('pdiddler4_balancer_SUPREME_v6_VERIFIED_STEPS.lua','pdiddler4_balancer_SUPREME_v7_PORTFOLIO_LEDGER.lua')
 :gsub('pdiddler4_early_counter_policy_v2_BOUNDED_VALUE.lua','pdiddler4_early_counter_policy_v3_TRADE_BUDGET.lua')
 :gsub('v11_VERIFIED_READINESS','v12_PORTFOLIO_LEDGER'):gsub('V11_VERIFIED_READINESS','V12_PORTFOLIO_LEDGER')
 :gsub('V11','V12')
source=source..[[
test('V12 refuses the preserved V11 integration before starting another owner',function()
 local f=fixture();local old={jobId='job',running=true};f.env.PDIDDLER_INTEGRATION_V11_VERIFIED_READINESS=old
 assert(f:run(path)==old);f:advance(25);assert(f:count('p2')==0 and f:count('outgoing')==0)
end)
print('TOTAL '..n..' V12 loader integration tests')
]]
assert(load(source,'v12-loader-contract','t',_G))()
