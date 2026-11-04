"""Complete offline release gate. --local-unpinned is prepublication only."""
from pathlib import Path
import hashlib,json,os,re,shutil,subprocess,sys,tempfile
ROOT=Path(__file__).resolve().parents[2]
def blob(path):
 b=(ROOT/path).read_bytes();return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def main():
 local='--local-unpinned' in sys.argv
 baseline=json.loads((ROOT/'pdiddler/tests/v13_baseline_sources.json').read_text())
 for r in baseline:assert blob(r['path'])==r['blob'],'baseline modified: '+r['path']
 print(f'PASS all {len(baseline)} PR15 baseline files unchanged',flush=True)
 manifest=json.loads((ROOT/'pdiddler/tests/integration_sources_v14.json').read_text())
 loader=(ROOT/'pdiddler/pdiddler_FASTGATE_V6_INTEGRATED_TEST_v14_VERIFIED_WORKFLOW.lua').read_text()
 pins={k:(n,s) for k,n,s in re.findall(r'(\w+)=\{"([^\"]+)","([0-9a-f]{40})"\}',loader)}
 assert len(pins)==17 and set(pins)=={r['key'] for r in manifest}
 for r in manifest:
  assert pins[r['key']]==(Path(r['path']).name,r['ref'])
  assert blob(r['local_path'])==r['blob'],'dependency blob changed: '+r['path']
  assert local or r['ref']!='0'*40,'unpublished dependency: '+r['key']
 print('PASS 17 dependency blobs and manifest'+(' (LOCAL UNPUBLISHED refs allowed)' if local else ''),flush=True)
 luau=os.environ.get('LUAU_BIN') or shutil.which('luau');compiler=os.environ.get('LUAU_COMPILE') or shutil.which('luau-compile')
 lua=next((shutil.which(x) for x in ('lua5.4','lua5.3','texlua','lua') if shutil.which(x)),None)
 assert compiler and luau and lua
 env=dict(os.environ,LUAU_BIN=luau,LUAU_COMPILE=compiler,PYTHONDONTWRITEBYTECODE='1')
 protected={r['path'] for r in baseline}
 runtimes=[p for p in (ROOT/'pdiddler').glob('*.lua') if p.relative_to(ROOT).as_posix() not in protected]
 for p in runtimes:
  subprocess.run([compiler,str(p)],check=True,stdout=subprocess.DEVNULL)
  assert 'Gingerscope' not in p.read_text(),'personal objective in new runtime'
 print(f'PASS {len(runtimes)} added runtimes compile; no personal named objective',flush=True)
 commands=[['python3','pdiddler/tests/run_v12_checks.py']]
 commands += [[lua,'pdiddler/tests/'+n+'.lua'] for n in ['v13_readiness_test','v13_integration_test','v13_teleport_autoexec_test',
  'v14_strategy_test','v14_early_test','v14_transaction_test','v14_lifecycle_test','v14_outgoing_test','v14_retry_clock_test']]
 commands += [['python3','pdiddler/tests/'+n+'.py'] for n in ['run_v14_trading_runtime','run_v14_delivery','v14_probe_runtime']]
 commands += [[lua,'pdiddler/tests/'+n+'.lua'] for n in ['v14_integration_test','v14_teleport_autoexec_test']]
 commands += [[lua,'pdiddler/tests/v14_portfolio_oracle_test.lua']]
 logs=[]
 for i,cmd in enumerate(commands,1):
  r=subprocess.run(cmd,cwd=ROOT,env=env,text=True,capture_output=True)
  logs.append('COMMAND: '+' '.join(cmd)+'\nEXIT: '+str(r.returncode)+'\n'+r.stdout+r.stderr)
  print(f'CHECK{i}/{len(commands)} exit={r.returncode}: '+' '.join(cmd),flush=True)
  if r.returncode:print(logs[-1]);raise SystemExit(r.returncode)
 report=Path(tempfile.gettempdir())/'pdiddler-v14-results.txt'
 legacy=Path(tempfile.gettempdir())/'pdiddler-v12-results.txt'
 report.write_text('V14 OFFLINE VERIFICATION — native MM2/Delta NOT executed\n'
  +('PREPUBLICATION refs permitted\n' if local else 'IMMUTABLE RELEASE MANIFEST CHECKED\n')
  +f'Protected PR15 files:{len(baseline)}; dependencies:17; added compiled runtimes:{len(runtimes)}\n\n'
  +'\n'.join(logs)+'\nPRESERVED FULL OUTPUT\n'+legacy.read_text())
 print(f'PASS {22+len(commands)-1} leaf verification commands; full output {report}',flush=True)
if __name__=='__main__':main()
