"""Protect every prior file and prove only UI code changed in successor logic."""
from pathlib import Path
import hashlib,json,re
root=Path(__file__).resolve().parents[2]
for row in json.loads((root/'pdiddler/tests/gui_preserved_sources.json').read_text()):
 b=(root/row['path']).read_bytes()
 digest=hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
 assert digest==row['blob'],'existing file modified: '+row['path']
r=root/'pdiddler'
old=(r/'pdiddler_FASTGATE_V6_INTEGRATED_TEST_v15_1_CURRENT_PRICES.lua').read_text()
new=(r/'pdiddler_FASTGATE_V6_INTEGRATED_TEST_v15_2_GUI_STATUS.lua').read_text()
a=new.index('-- Startup-only display.');b=new.index('local function phase(stage,reason)',a)
new=new[:a]+new[b:]
new=new.replace('        display(stage,reason)\n','').replace('    createStartupGui()\n','')
new=new.replace('    destroyStartupGui() -- one-way handoff to the preserved scanner panel\n','')
new=new.replace('V15_2_GUI_STATUS','V15_1_CURRENT_PRICES')
new=new.replace(',"PDIDDLER_INTEGRATION_V15_1_CURRENT_PRICES"}', '}')
new=re.sub(r'gate=\{"pdiddler1_fast_gate_v7_HEADLESS.lua","[0-9a-f]{40}"\}',
 'gate={"pdiddler1_fast_gate_TEST_v6_VALID_EVIDENCE.lua","962dcafe2b5c535ed7c94293ebb812693404d4e7"}',new)
assert new==old,'non-GUI loader behavior changed'
old=(r/'pdiddler1_fast_gate_TEST_v6_VALID_EVIDENCE.lua').read_text()
new=(r/'pdiddler1_fast_gate_v7_HEADLESS.lua').read_text()
old=old.replace('-- PDIDDLER P1 FAST GATE V6 | measurement-focused 10-second test','-- PDIDDLER P1 FAST GATE V7 HEADLESS | V6 evidence and timing unchanged')
old=old.replace('local gui,label\n','')
a=old.index('local function status(message)');b=old.index('local function stop()',a);old=old[:a]+old[b:]
old=old.replace('    if gui then pcall(function() gui:Destroy() end) end\n','').replace('    status(summary)\n','')
a=old.index('        if label then\n');b=old.index('        task.wait(.035)',a);old=old[:a]+old[b:]
assert new==old,'non-visual detector behavior changed'
print('PASS every previous repository file unchanged; loader trading and detector evidence are unchanged')
