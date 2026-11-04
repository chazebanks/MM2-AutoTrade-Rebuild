"""Exercise the complete production gate with mocked Roblox/scheduler boundaries."""
from pathlib import Path
import os,shutil,subprocess,tempfile,sys
ROOT=Path(__file__).resolve().parents[2]
gate=ROOT/(sys.argv[1] if len(sys.argv)>1 else 'pdiddler/pdiddler1_fast_gate_TEST_v6_VALID_EVIDENCE.lua')
fixture=(ROOT/'pdiddler/tests/fast_gate_runtime_fixture.lua').read_text()
src='local function NEW_GATE(f)\nlocal game,task=f.game,f.task\nlocal os={clock=function() return f.now end}\nlocal function getgenv() return f.env end\nlocal function print() end\n'+gate.read_text().replace('local function finish(state,reason)', 'f.measurementRows=rows;f.readOverview=overview\nlocal function finish(state,reason)')+'\nend\n'+fixture+(ROOT/'pdiddler/tests/v11_fast_gate_runtime_test.lua').read_text()
luau=os.environ.get('LUAU_BIN') or shutil.which('luau');compiler=os.environ.get('LUAU_COMPILE') or shutil.which('luau-compile')
assert luau and compiler,'official Luau required'
with tempfile.TemporaryDirectory(prefix='pdiddler-gate-') as td:
 path=Path(td)/'gate.luau';path.write_text(src)
 subprocess.run([compiler,str(path)],check=True,stdout=subprocess.DEVNULL)
 subprocess.run([luau,str(path)],check=True)
