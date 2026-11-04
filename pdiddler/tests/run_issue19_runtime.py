"""Run successor production modules with the preserved Roblox boundary fixture."""
from pathlib import Path
import os,shutil,subprocess,tempfile,sys
ROOT=Path(__file__).resolve().parents[2]
baseline='--baseline' in sys.argv
policy='pdiddler4_supreme_policy_v8_PORTFOLIO_LEDGER.lua' if baseline else 'pdiddler4_supreme_policy_v9_CONSISTENT_QUOTES.lua'
early='pdiddler4_early_counter_policy_v3_TRADE_BUDGET.lua' if baseline else 'pdiddler4_early_counter_policy_v5_OPPONENT_ADDED.lua'
p4='pdiddler4_balancer_SUPREME_v7_PORTFOLIO_LEDGER.lua' if baseline else 'pdiddler4_balancer_SUPREME_v9_OPPONENT_ADDED.lua'
original=(ROOT/'pdiddler/tests/part4_runtime_test.lua').read_text()
fixture=original[:original.index('local function test(name,fn)')]
old='node("Container","Frame",ours); node("Container","Frame",theirs)'
fixture=fixture.replace(old,old+'; node("Accepted","Frame",ours,{Visible=false})')
old='function f:start() self.module=NEW_PART4(self); self.controller=self.module.run(self.scanner,self.profile,POLICY,POLICY,self.telemetry); return self.controller end'
new='''function f:start()
 self.profile.version="fixture-prices"
 self.lifecycle=LIFE.new({native=self.native,verifier=self.verifier,policy=self.policy or POLICY,outbox=self.outbox,jobId=self.game.JobId,profile=self.profile,now=function() return self.now end,
  onHold=function(reason) if self.telemetry.holdOutcome then self.telemetry.holdOutcome(reason) end end})
 self.telemetry.lifecycle=self.lifecycle
 self.module=NEW_PART4(self)
 local gate=self.gate or {read=function() return "unknown" end,step=function() return false end}
 self.controller=self.module.run(self.scanner,self.profile,self.policy or POLICY,self.policy or POLICY,self.telemetry,gate,self.early or EARLY)
 return self.controller
end'''
assert old in fixture;fixture=fixture.replace(old,new)
def read(name):return (ROOT/'pdiddler'/name).read_text()
bundle='local POLICY=(function()\n'+read(policy)+'\nend)()\nlocal EARLY=(function()\n'+read(early)+'\nend)()\n'
bundle+='local VERIFICATION=(function()\n'+read('pdiddler_trade_verification_v2.lua')+'\nend)()\nlocal OUTBOX=(function()\n'+read('pdiddler_webhook_outbox_v3.lua')+'\nend)()\n'
bundle+='local LIFE=(function()\n'+read('pdiddler_trade_lifecycle_v1.lua')+'\nend)()\n'
bundle+='local function NEW_PART4(f)\nlocal game,task=f.game,f.task\nlocal os={clock=function() return f.now end}\nlocal function getgenv() return f.env end\nlocal function print() end\nlocal function warn() end\n'
bundle+=read(p4)+'\nend\n'+fixture+(ROOT/'pdiddler/tests/issue19_runtime_test.lua').read_text()
compiler=os.environ.get('LUAU_COMPILE') or shutil.which('luau-compile')
luau=os.environ.get('LUAU_BIN') or shutil.which('luau')
assert compiler and luau
with tempfile.TemporaryDirectory(prefix='pdiddler-v14-runtime-') as td:
 p=Path(td)/'runtime.luau';p.write_text(bundle)
 subprocess.run([compiler,str(p)],check=True,stdout=subprocess.DEVNULL)
 subprocess.run([luau,str(p)],check=True,cwd=ROOT)
