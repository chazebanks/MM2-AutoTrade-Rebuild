"""Issue24 full offline gate. Native MM2/Delta execution is never claimed."""
from pathlib import Path
import hashlib,json,os,re,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
local='--local-unpinned' in sys.argv
compiler=os.environ.get('LUAU_COMPILE') or shutil.which('luau-compile')
luau=os.environ.get('LUAU_BIN') or shutil.which('luau')
lua=next((shutil.which(n) for n in ('lua5.4','lua5.3','texlua','lua') if shutil.which(n)),None)
assert compiler and luau and lua,'Install Lua and official Luau0.745 first'
def blob(path):
 b=(ROOT/path).read_bytes();return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
baseline=json.loads((ROOT/'pdiddler/tests/issue24_preserved_sources.json').read_text())
for r in baseline:assert blob(r['path'])==r['blob'],'predecessor modified: '+r['path']
print(f'PASS all {len(baseline)} V15.3 predecessor files byte-identical',flush=True)
loader=(ROOT/'pdiddler/pdiddler_FASTGATE_V6_INTEGRATED_TEST_v15_4_REACHABLE.lua').read_text()
pins={k:(n,s) for k,n,s in re.findall(r'(\w+)=\{"([^\"]+)","([0-9a-f]{40})"\}',loader)}
assert len(pins)==19
boot=(ROOT/'pdiddler/pdiddler_V15_4_TELEPORT_AUTOBOOT_v1.lua').read_text()
boot_pin=re.search(r'local V15_4_SHA="([0-9a-f]{40})"',boot)[1]
if local:
 print('PREPUBLICATION: zero pins permitted for local tests only',flush=True)
else:
 manifest=json.loads((ROOT/'pdiddler/reachability/RUNTIME_PINS.json').read_text())
 assert boot_pin==manifest['loaderRef'] and boot_pin!='0'*40
 for key,(name,ref) in pins.items():
  r=manifest['dependencies'][key]
  path='pdiddler/tests/fixtures/p5_policy_v1.lua' if key=='policy' else 'pdiddler/'+name
  assert ref==r['ref'] and name==r['name'] and ref!='0'*40 and blob(path)==r['blob'],key
 assert blob('pdiddler/pdiddler_FASTGATE_V6_INTEGRATED_TEST_v15_4_REACHABLE.lua')==manifest['loaderBlob']
 print('PASS 19 immutable dependency pins and loader manifest',flush=True)
env=dict(os.environ,LUAU_BIN=luau,LUAU_COMPILE=compiler,PYTHONDONTWRITEBYTECODE='1')
subprocess.run([compiler,str(ROOT/'pdiddler/reachability/pdiddler3_scanner_MODULE_v6_9_VERIFICATION_STATE.lua')],check=True,stdout=subprocess.DEVNULL)
commands=[['python3','pdiddler/tests/run_v14_checks.py']]
commands += [['python3','pdiddler/tests/'+n+'.py'] for n in ['run_issue19_runtime','run_issue24_outgoing_runtime','v15_source_guard','check_issue19_baseline','check_price_refresh_scope','check_v15_2_headless_scope','check_gui_scope','run_headless_gate','issue24_scanner_scope']]
commands += [['python3','-m','unittest','discover','-s','pdiddler/tests','-p','test_refresh_supreme_snapshot.py']]
commands += [[lua,'pdiddler/tests/'+n+'.lua'] for n in ['v15_opponent_addition_test','issue19_integration_test','issue19_bootstrap_test','current_snapshot_test','current_price_integration_test','current_price_bootstrap_test','gui_integration_test','gui_bootstrap_test','issue24_scanner_state_test','issue24_feasibility_test','issue24_eligibility_test','issue24_outgoing_test','issue24_loader_test','issue24_bootstrap_test']]
logs=[]
for cmd in commands:
 r=subprocess.run(cmd,cwd=ROOT,env=env,text=True,capture_output=True)
 logs.append('COMMAND: '+' '.join(cmd)+'\nEXIT: '+str(r.returncode)+'\n'+r.stdout+r.stderr)
 print(f'EXIT {r.returncode}: '+' '.join(cmd),flush=True)
 if r.returncode:print(logs[-1]);raise SystemExit(r.returncode)
report=Path('/tmp/issue24-all-results.txt');report.write_text('\n\n'.join(logs))
print(f'PASS {len(commands)} top-level checks including inherited37-command V14 suite; {report}',flush=True)
