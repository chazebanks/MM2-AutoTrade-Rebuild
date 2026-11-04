"""Protect every prior file and prove only UI code changed in successor logic."""
from pathlib import Path
import hashlib,json,re
root=Path(__file__).resolve().parents[2]
for row in json.loads((root/'pdiddler/tests/gui_preserved_sources.json').read_text()):
 b=(root/row['path']).read_bytes()
 digest=hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
 assert digest==row['blob'],'existing file modified: '+row['path']
r=root/'pdiddler'
old=(r/'pdiddler_INTEGRATED_v15_2_HEADLESS_GATE.lua').read_text()
new=(r/'pdiddler_FASTGATE_V6_INTEGRATED_TEST_v15_3_GUI_STATUS.lua').read_text()
a=new.index('-- Startup-only display.');b=new.index('local function phase(stage,reason)',a)
new=new[:a]+new[b:]
new=new.replace('        display(stage,reason)\n','').replace('    createStartupGui()\n','')
new=new.replace('    destroyStartupGui() -- one-way handoff to the preserved scanner panel\n','')
new=new.replace('V15_3_GUI_STATUS','V15_2_HEADLESS_GATE')
new=new.replace(',"PDIDDLER_INTEGRATION_V15_2_HEADLESS_GATE"}', '}')
assert new==old,'non-GUI loader behavior changed'
print('PASS every previous repository file unchanged; startup-only loader delta and preserved headless detector')
