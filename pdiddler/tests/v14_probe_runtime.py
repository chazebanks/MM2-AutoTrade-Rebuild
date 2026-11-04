"""Run the unmodified observational probe in official Luau with offline boundaries."""
from pathlib import Path
import os,shutil,subprocess,sys,tempfile
ROOT=Path(__file__).resolve().parents[2]
version='v1' if '--baseline' in sys.argv else 'v2'
source=(ROOT/f'pdiddler/pdiddler_native_trade_probe_{version}.lua').read_text()
compiler=os.environ.get('LUAU_COMPILE') or shutil.which('luau-compile') or '/tmp/pdiddler-luau/luau-compile'
luau=os.environ.get('LUAU_BIN') or shutil.which('luau') or '/tmp/pdiddler-luau/luau'
subprocess.run([compiler,str(ROOT/f'pdiddler/pdiddler_native_trade_probe_{version}.lua')],check=True,stdout=subprocess.DEVNULL)
wrapper='''local function NEW_PROBE(f)
local game,task=f.game,f.task
local os={clock=function() return f.now end}
local function getgenv() return f.env end
local function typeof(v) return type(v)=="table" and v.ClassName and "Instance" or type(v) end
local function print(...) local out={...};f.printed[#f.printed+1]=table.concat(out," ") end
local warn=print
'''+source+'\nend\n'
bundle=wrapper+(ROOT/'pdiddler/tests/v14_probe_fixture.lua').read_text()+'\n'+(ROOT/'pdiddler/tests/v14_probe_test.lua').read_text()
with tempfile.TemporaryDirectory(prefix='pdiddler-probe-') as tmp:
    target=Path(tmp)/'probe_test.luau';target.write_text(bundle)
    result=subprocess.run([luau,str(target)],cwd=ROOT)
    raise SystemExit(result.returncode)
