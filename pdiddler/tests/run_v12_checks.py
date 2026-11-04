"""Reproduce the V12 offline release checks; native gameplay is a separate gate."""
from pathlib import Path
import hashlib,json,os,re,shutil,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
def blob(path):
 d=(ROOT/path).read_bytes();return hashlib.sha1(b'blob '+str(len(d)).encode()+b'\0'+d).hexdigest()
def main():
 baseline=json.loads((ROOT/'pdiddler/tests/v12_baseline_sources.json').read_text())
 for row in baseline: assert blob(row['path'])==row['blob'],'baseline changed: '+row['path']
 print(f'PASS all{len(baseline)} PR14 baseline blobs unchanged',flush=True)
 manifest=json.loads((ROOT/'pdiddler/tests/integration_sources_v12.json').read_text())
 text=(ROOT/'pdiddler/pdiddler_FASTGATE_V6_INTEGRATED_TEST_v12_PORTFOLIO_LEDGER.lua').read_text()
 pins={k:(n,s) for k,n,s in re.findall(r'(\w+)=\{"([^\"]+)","([0-9a-f]{40})"\}',text)}
 assert len(pins)==12 and set(pins)=={x['key'] for x in manifest}
 for row in manifest:
  assert pins[row['key']]==(Path(row['path']).name,row['ref'])
  assert blob(row['local_path'])==row['blob'],'pin changed: '+row['path']
 print('PASS12 immutable dependencies and exact Git blobs',flush=True)
 compiler=os.environ.get('LUAU_COMPILE') or shutil.which('luau-compile');luau=os.environ.get('LUAU_BIN') or shutil.which('luau')
 lua=next((shutil.which(n) for n in ('lua5.4','lua5.3','texlua','lua') if shutil.which(n)),None)
 assert compiler and luau and lua,'official Luau0.745 and Lua required'
 env=dict(os.environ,LUAU_BIN=luau,LUAU_COMPILE=compiler,PYTHONDONTWRITEBYTECODE='1')
 sources=['pdiddler4_supreme_policy_v8_PORTFOLIO_LEDGER.lua','pdiddler4_early_counter_policy_v3_TRADE_BUDGET.lua',
 'pdiddler4_balancer_SUPREME_v7_PORTFOLIO_LEDGER.lua','pdiddler_FASTGATE_V6_INTEGRATED_TEST_v12_PORTFOLIO_LEDGER.lua','pdiddler_V12_TELEPORT_AUTOBOOT_v1.lua']
 for name in sources:
  source=ROOT/'pdiddler'/name
  assert 'Gingerscope' not in source.read_text(),'personal objective in runtime'
  subprocess.run([compiler,str(source)],check=True,stdout=subprocess.DEVNULL)
 print('PASS five new runtime sources compile; no personal named objective',flush=True)
 commands=[['python3','pdiddler/tests/run_v11_checks.py'],[lua,'pdiddler/tests/v12_portfolio_ledger_policy_test.lua'],
 [lua,'pdiddler/tests/v11_verified_negotiation_test.lua','pdiddler/pdiddler4_supreme_policy_v8_PORTFOLIO_LEDGER.lua'],
 ['python3','pdiddler/tests/run_v12_trading_runtime.py'],[lua,'pdiddler/tests/v12_integration_test.lua'],[lua,'pdiddler/tests/v12_teleport_autoexec_test.lua']]
 logs=[]
 for i,cmd in enumerate(commands,1):
  r=subprocess.run(cmd,cwd=ROOT,env=env,text=True,capture_output=True)
  logs.append('COMMAND: '+' '.join(cmd)+'\nEXIT: '+str(r.returncode)+'\n'+r.stdout+r.stderr)
  print(f'CHECK{i}/{len(commands)} exit={r.returncode}: '+' '.join(cmd),flush=True)
  if r.returncode:print(logs[-1]);raise SystemExit(r.returncode)
 legacy=Path(tempfile.gettempdir())/'pdiddler-v11-results.txt'
 report=Path(tempfile.gettempdir())/'pdiddler-v12-results.txt'
 report.write_text('V12 OFFLINE VERIFICATION; native MM2/Delta NOT executed\n'+f'Protected baseline:{len(baseline)} blobs; immutable dependencies:12; new compiled runtimes:5\n\n'+'\n'.join(logs)+'\nFULL PRESERVED SUITE OUTPUT\n'+legacy.read_text())
 print('PASS22 verification commands (17 preserved +5 current), report '+str(report),flush=True)
if __name__=='__main__':main()
