"""V11 production source in the existing complete V10 Roblox boundary fixture."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
original=(ROOT/"pdiddler/tests/run_v10_bounded_runtime.py").read_text()
source=original.replace("pdiddler4_supreme_policy_v6_BOUNDED_CONCESSION.lua","pdiddler4_supreme_policy_v7_VERIFIED_STEPS.lua").replace("pdiddler4_balancer_SUPREME_v5_BOUNDED_SELECTION.lua","pdiddler4_balancer_SUPREME_v6_VERIFIED_STEPS.lua")
source=source.replace('bundle+=p4+\'\\nend\\n\'+fixture+extra','bundle+=p4+\'\\nend\\n\'+fixture+extra+(ROOT/"pdiddler/tests/v11_trading_runtime_test.lua").read_text()')
source=source.replace("local gate={read=function()", "local gate=self.gate or {read=function()")
source=source.replace("PASS V10 actual P4 module", "PASS V11 actual P4 module")
exec(compile(source,"v11_runtime_runner","exec"),{"__file__":str(Path(__file__).resolve())})
