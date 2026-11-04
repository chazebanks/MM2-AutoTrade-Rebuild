"""Reproduce V11 verification; native MM2/Delta gameplay is outside this runner."""
import hashlib,json,os,re,shutil,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def blob(path):
 data=(ROOT/path).read_bytes()
 return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
def main():
 baseline=json.loads((ROOT/'pdiddler/tests/v11_baseline_sources.json').read_text())
 for row in baseline: assert blob(row['path'])==row['blob'],'baseline changed: '+row['path']
 print(f'PASS {len(baseline)} latest PR12 baseline files byte-identical',flush=True)
 manifest=json.loads((ROOT/'pdiddler/tests/integration_sources_v11.json').read_text())
 source=(ROOT/'pdiddler/pdiddler_FASTGATE_V6_INTEGRATED_TEST_v11_VERIFIED_READINESS.lua').read_text()
 pins={key:(name,sha) for key,name,sha in re.findall(r'(\w+)=\{"([^\"]+)","([0-9a-f]{40})"\}',source)}
 assert len(pins)==12 and set(pins)=={r['key'] for r in manifest}
 for row in manifest:
  assert pins[row['key']]==(Path(row['path']).name,row['ref'])
  assert blob(row['local_path'])==row['blob'],'pinned source changed: '+row['path']
 print('PASS all12 immutable V11 dependencies match recorded Git blobs',flush=True)
 compiler=os.environ.get('LUAU_COMPILE') or shutil.which('luau-compile')
 luau=os.environ.get('LUAU_BIN') or shutil.which('luau')
 lua=next((shutil.which(n) for n in ('lua5.4','lua5.3','texlua','lua') if shutil.which(n)),None)
 assert compiler and luau and lua,'Lua and official Luau0.745 tools required'
 env=dict(os.environ,LUAU_BIN=luau,LUAU_COMPILE=compiler,PYTHONDONTWRITEBYTECODE='1')
 sources=['pdiddler4_supreme_policy_v7_VERIFIED_STEPS.lua','pdiddler4_balancer_SUPREME_v6_VERIFIED_STEPS.lua',
 'pdiddler1_fast_gate_TEST_v6_VALID_EVIDENCE.lua','pdiddler_readiness_v1.lua',
 'pdiddler_FASTGATE_V6_INTEGRATED_TEST_v11_VERIFIED_READINESS.lua','pdiddler_V11_TELEPORT_AUTOBOOT_v1.lua']
 for name in sources: subprocess.run([compiler,str(ROOT/'pdiddler'/name)],check=True,stdout=subprocess.DEVNULL)
 print('PASS six new complete runtime sources compile with official Luau',flush=True)
 commands=[['python3','pdiddler/tests/run_integration_tests.py'],['python3','pdiddler/tests/run_trading_tests.py'],
 ['python3','-m','unittest','discover','-s','pdiddler/tests','-p','test_refresh_supreme_snapshot.py'],
 ['python3','pdiddler/tests/run_issue4_tests.py']]
 commands += [[lua,'pdiddler/tests/'+name+'.lua'] for name in ['v6_final_wait_policy_test','v7_delayed_sweeten_policy_test',
 'v8_visible_accept_gate_test','v9_early_counter_policy_test','v10_recording_offer_selection_test','v10_teleport_autoexec_test',
 'v11_verified_negotiation_test','v11_readiness_test','v11_integration_test','v11_teleport_autoexec_test']]
 commands += [['python3','pdiddler/tests/'+name+'.py'] for name in ['run_v10_bounded_runtime','run_v11_trading_runtime','run_v11_fast_gate']]
 report=[]
 for i,cmd in enumerate(commands,1):
  result=subprocess.run(cmd,cwd=ROOT,env=env,capture_output=True,text=True)
  text='COMMAND: '+' '.join(cmd)+'\nEXIT: '+str(result.returncode)+'\n'+result.stdout+result.stderr
  report.append(text)
  print(f'CHECK {i}/{len(commands)} exit={result.returncode}: '+ ' '.join(cmd),flush=True)
  if result.returncode:
   print(text);raise SystemExit(result.returncode)
 out=Path(os.environ.get('PDIDDLER_V11_REPORT',str(Path(tempfile.gettempdir())/'pdiddler-v11-results.txt')))
 out.write_text('PDIDDLER V11 OFFLINE VERIFICATION\nNative MM2/Delta gameplay: NOT EXECUTED\n'
 +f'Frozen latest-baseline blobs: {len(baseline)}\nImmutable module pins:12\nOfficial Luau sources compiled:6\n\n'+'\n'.join(report))
 print(f'PASS {len(commands)} verification commands; full output: {out}',flush=True)
if __name__=='__main__':main()
