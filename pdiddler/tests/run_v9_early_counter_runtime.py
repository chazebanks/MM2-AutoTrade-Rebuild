"""Run the versioned V9 production Part 4 under the existing complete Luau runtime fixture."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[2]
luau=os.environ.get("LUAU_BIN") or shutil.which("luau")
compiler=os.environ.get("LUAU_COMPILE") or shutil.which("luau-compile")
assert luau and compiler,"official Luau runtime/compile required"
policy=(ROOT/"pdiddler/pdiddler4_supreme_policy_v5_NATIVE_READY.lua").read_text()
early=(ROOT/"pdiddler/pdiddler4_early_counter_policy_v1.lua").read_text()
p4=(ROOT/"pdiddler/pdiddler4_balancer_SUPREME_v4_EARLY_COUNTER.lua").read_text()
original=(ROOT/"pdiddler/tests/part4_runtime_test.lua").read_text()
fixture=original[:original.index("local function test(name,fn)")]
old='node("Container","Frame",ours); node("Container","Frame",theirs)'
assert old in fixture
fixture=fixture.replace(old,old+'; node("Accepted","Frame",ours,{Visible=false})')
old_start='function f:start() self.module=NEW_PART4(self); self.controller=self.module.run(self.scanner,self.profile,POLICY,POLICY,self.telemetry); return self.controller end'
assert old_start in fixture
new_start='''function f:start()
        self.module=NEW_PART4(self)
        self.nativeChecks=0
        self.nativeReadyEver=false
        local gate={read=function() self.nativeChecks=self.nativeChecks+1; return "unknown" end,
            step=function() return false end}
        self.controller=self.module.run(self.scanner,self.profile,
            self.policy or POLICY,self.policy or POLICY,self.telemetry,gate,self.early or EARLY)
        return self.controller
    end'''
fixture=fixture.replace(old_start,new_start)
extra=(ROOT/"pdiddler/tests/v9_early_counter_runtime_test.lua").read_text()
bundle='local POLICY=(function()\\n'+policy+'\\nend)()\\n'
bundle+='local EARLY=(function()\\n'+early+'\\nend)()\\n'
bundle+='local function NEW_PART4(f)\\n'
bundle+='local game,task=f.game,f.task\\n'
bundle+='local os={clock=function() return f.now+(f.clockOffset or 0) end}\\n'
bundle+='local function getgenv() return f.env end\\n'
bundle+='local function print() end\\n'
bundle+='local function warn() end\\n'
bundle+=p4+'\\nend\\n'+fixture+extra
with tempfile.TemporaryDirectory(prefix="pdiddler-v9-runtime-") as td:
    test_file=Path(td)/"v9_runtime.luau"
    test_file.write_text(bundle)
    subprocess.run([compiler,str(test_file)],stdout=subprocess.DEVNULL,check=True,cwd=ROOT)
    subprocess.run([luau,str(test_file)],cwd=ROOT,check=True)
print("PASS V9 actual P4 module compiles and runs in native Luau fixture")
