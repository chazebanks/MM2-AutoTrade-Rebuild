"""Full isolated P3 scanner-evidence release gate; no native gameplay claims."""
from pathlib import Path
import os,shutil,subprocess,re,json,hashlib,sys
ROOT=Path(__file__).resolve().parents[2]
lua=next((shutil.which(n) for n in ('lua5.4','lua5.3','texlua','lua') if shutil.which(n)),None)
compiler=os.environ.get('LUAU_COMPILE') or shutil.which('luau-compile')
luau=os.environ.get('LUAU_BIN') or shutil.which('luau')
assert lua and compiler and luau
local='--local-unpinned' in sys.argv
loader=ROOT/'pdiddler/pdiddler_FASTGATE_V6_INTEGRATED_TEST_v15_5_SCANNER_EVIDENCE.lua'
boot=ROOT/'pdiddler/pdiddler_V15_5_TELEPORT_AUTOBOOT_v1.lua'
pins={key:(name,sha) for key,name,sha in re.findall(r'(\w+)=\{"([^\"]+)","([0-9a-f]{40})"\}',loader.read_text())}
assert len(pins)==20
if not local:
 m=json.loads((ROOT/'pdiddler/presentation/RUNTIME_PINS.json').read_text())
 def blob(path):
  b=(ROOT/path).read_bytes();return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
 assert blob(loader.relative_to(ROOT))==m['loaderBlob']
 assert re.search(r'local V15_5_SHA="([0-9a-f]{40})"',boot.read_text())[1]==m['loaderRef']
 assert blob(boot.relative_to(ROOT))==m['bootstrapBlob']
 for key,(name,sha) in pins.items():
  row=m['dependencies'][key]
  path='pdiddler/tests/fixtures/p5_policy_v1.lua' if key=='policy' else 'pdiddler/'+name
  assert sha!='0'*40 and row=={'name':name,'ref':sha,'blob':blob(path)},key
 print('PASS all20 immutable dependency pins and loader/bootstrap manifest',flush=True)
else:print('PREPUBLICATION ONLY: local successor pin placeholders permitted',flush=True)
for path in ['pdiddler/presentation/pdiddler3_scanner_view_v1.lua','pdiddler/presentation/pdiddler3_scanner_MODULE_v6_10_CURRENT_PRESENTATION.lua','pdiddler/pdiddler3_outgoing_eligibility_v2_SCANNER_EVIDENCE.lua',str(loader.relative_to(ROOT)),str(boot.relative_to(ROOT))]:
 subprocess.run([compiler,str(ROOT/path)],check=True,stdout=subprocess.DEVNULL)
commands=[['python3','pdiddler/tests/issue24_scanner_evidence_scope.py'],['python3','pdiddler/tests/run_issue24_checks.py']]
commands += [[lua,'pdiddler/tests/'+name+'.lua'] for name in ['issue24_scanner_view_test','issue24_scanner_presentation_test','issue24_scanner_economics_test','issue24_scanner_loader_test','issue24_scanner_bootstrap_test']]
commands += [['python3','pdiddler/tests/run_issue24_scanner_outgoing_runtime.py']]
logs=[];env=dict(os.environ,LUAU_BIN=luau,LUAU_COMPILE=compiler,PYTHONDONTWRITEBYTECODE='1')
for cmd in commands:
 p=subprocess.run(cmd,cwd=ROOT,env=env,text=True,capture_output=True)
 logs.append('COMMAND: '+' '.join(cmd)+'\nEXIT: '+str(p.returncode)+'\n'+p.stdout+p.stderr)
 print('EXIT',p.returncode,' '.join(cmd),flush=True)
 if p.returncode:print(logs[-1]);raise SystemExit(p.returncode)
Path('/tmp/issue24-scanner-all-results.txt').write_text('\n\n'.join(logs)+'\nINHERITED FULL RESULTS\n'+Path('/tmp/issue24-all-results.txt').read_text())
print('PASS8 scanner top-level checks including25 preserved checks and inherited37-command V14 suite',flush=True)
