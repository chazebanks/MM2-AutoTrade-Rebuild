"""Run the full detector with Roblox boundaries and forbid all GUI work."""
from pathlib import Path
import os, shutil, subprocess, sys, tempfile
root=Path(__file__).resolve().parents[2]
path=root/(sys.argv[1] if len(sys.argv)>1 else 'pdiddler/pdiddler1_fast_gate_v7_HEADLESS.lua')
fixture=(root/'pdiddler/tests/fast_gate_runtime_fixture.lua').read_text().replace(
 'function lp:FindFirstChildOfClass() return nil end',
 'function lp:FindFirstChildOfClass() f.guiReads=(f.guiReads or 0)+1;return {} end')
header='''local function NEW_GATE(f)
local game,task=f.game,f.task
local os={clock=function() return f.now end}
local function getgenv() return f.env end
local function print() end
local Instance={new=function() f.guiCreates=(f.guiCreates or 0)+1;error('GUI creation forbidden') end}
'''
production=path.read_text().replace('local function finish(state,reason)', 'f.measurementRows=rows;f.readOverview=overview\nlocal function finish(state,reason)')
checks=(root/'pdiddler/tests/v11_fast_gate_runtime_test.lua').read_text()+'''
local f=gateFixture():start();f:advance(10.1)
assert((f.guiReads or 0)==0 and (f.guiCreates or 0)==0,'detector touched PlayerGui or created an overlay')
assert(f:result().state=='BOT_PATTERN_FOR_REVIEW' and f:result().evidenceVersion==6)
print('PASS headless detector never reads PlayerGui or creates GUI; evidence unchanged')
'''
luau=os.environ.get('LUAU_BIN') or shutil.which('luau')
compiler=os.environ.get('LUAU_COMPILE') or shutil.which('luau-compile')
assert luau and compiler
with tempfile.TemporaryDirectory(prefix='pdiddler-headless-') as td:
 p=Path(td)/'test.luau';p.write_text(header+production+'\nend\n'+fixture+checks)
 subprocess.run([compiler,str(p)],check=True,stdout=subprocess.DEVNULL)
 subprocess.run([luau,str(p)],check=True)
