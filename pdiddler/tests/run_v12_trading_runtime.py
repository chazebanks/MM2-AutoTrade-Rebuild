"""Run V12 actual sources under the complete proven V11 boundary fixture."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]
source=(ROOT/'pdiddler/tests/run_v10_bounded_runtime.py').read_text()
policy='pdiddler4_supreme_policy_v8_PORTFOLIO_LEDGER.lua'
p4='pdiddler4_balancer_SUPREME_v7_PORTFOLIO_LEDGER.lua'
early='pdiddler4_early_counter_policy_v3_TRADE_BUDGET.lua'
if '--baseline' in sys.argv:
 policy='pdiddler4_supreme_policy_v7_VERIFIED_STEPS.lua';p4='pdiddler4_balancer_SUPREME_v6_VERIFIED_STEPS.lua';early='pdiddler4_early_counter_policy_v2_BOUNDED_VALUE.lua'
source=source.replace('pdiddler4_supreme_policy_v6_BOUNDED_CONCESSION.lua',policy).replace('pdiddler4_balancer_SUPREME_v5_BOUNDED_SELECTION.lua',p4).replace('pdiddler4_early_counter_policy_v2_BOUNDED_VALUE.lua',early)
old="bundle+=p4+'\\nend\\n'+fixture+extra"
new=old+"+(ROOT/'pdiddler/tests/v11_trading_runtime_test.lua').read_text()+(ROOT/'pdiddler/tests/v12_trading_runtime_test.lua').read_text()"
assert old in source
source=source.replace(old,new).replace('local gate={read=function()','local gate=self.gate or {read=function()').replace('PASS V10 actual P4 module','PASS V12 actual P4 module')
exec(compile(source,'v12_runtime_runner','exec'),{'__file__':str(Path(__file__).resolve())})
