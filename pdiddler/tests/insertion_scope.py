"""Guard physical insertion order without changing V15.7 economics or owners."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text()


def blob(path):
    data = (ROOT / path).read_bytes()
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


preserved = json.loads(read('pdiddler/insertion/PRESERVED_SOURCES.json'))
assert len(preserved) == 431 and len({row['path'] for row in preserved}) == 431
for row in preserved:
    assert blob(row['path']) == row['blob'], 'predecessor modified: ' + row['path']
print('PASS all 431 PR30 predecessor files byte-identical, including policy10, scanner, bot gate and hopping')

old = read('pdiddler/pdiddler4_balancer_SUPREME_v10_IMMEDIATE_SAFETY.lua')
new = read('pdiddler/pdiddler4_balancer_SUPREME_v11_VALUE_FIRST.lua')
helper_start = new.index('-- Planner picks stay immutable: reservations and final verification still own\n')
apply_start = new.index('local function applyPlan(', helper_start)
assert new.count('local function orderedExecutionPicks(plan)') == 1
normalized = new[:helper_start] + new[apply_start:]
preflight = '''    local ordered,orderWhy=orderedExecutionPicks(plan)
    if not ordered then return false,orderWhy,false end
'''
assert normalized.count(preflight) == 1, 'unexpected execution-order preflight ownership'
normalized = normalized.replace(preflight, '')
call = '''for _,entry in ipairs(ordered) do
        local p=entry.pick'''
assert normalized.count(call) == 1, 'unexpected execution-order call ownership'
normalized = normalized.replace(call, 'for _,p in ipairs(plan.picks) do')
normalized = normalized.replace('supreme-v11-value-first', 'supreme-v10-immediate-safety')
assert normalized.split('\n', 1)[1] == old.split('\n', 1)[1], 'P4 changed beyond copied insertion order, version header and controller kind'
assert new.rstrip().endswith('return M'), 'test-only getter leaked into production'
print('PASS entire P4 outside the insertion-order helper/call is unchanged: immediate safety, acceptance, mutation verification and concession ownership')

old_loader = read('pdiddler/pdiddler_INTEGRATED_v15_7_INVENTORY_GROWTH.lua')
new_loader = read('pdiddler/pdiddler_INTEGRATED_v15_8_VALUE_FIRST.lua')
pattern = r'(\w+)=\{"([^\"]+)","([0-9a-f]{40})"\}'
old_pins = {key: (name, ref) for key, name, ref in re.findall(pattern, old_loader)}
new_pins = {key: (name, ref) for key, name, ref in re.findall(pattern, new_loader)}
assert len(old_pins) == len(new_pins) == 20 and set(old_pins) == set(new_pins)
for key in old_pins:
    if key != 'p4':
        assert new_pins[key] == old_pins[key], 'unrelated dependency changed: ' + key
assert new_pins['p4'][0] == 'pdiddler4_balancer_SUPREME_v11_VALUE_FIRST.lua'
normalized = new_loader.replace(',"PDIDDLER_INTEGRATION_V15_7_INVENTORY_GROWTH"', '')
normalized = normalized.replace('V15_8_VALUE_FIRST', 'V15_7_INVENTORY_GROWTH')
normalized = normalized.replace('V15_8', 'V15_7').replace('V15.8', 'V15.7')
normalized = normalized.replace('p4={"' + new_pins['p4'][0] + '","' + new_pins['p4'][1] + '"}',
                                'p4={"' + old_pins['p4'][0] + '","' + old_pins['p4'][1] + '"}')
assert normalized == old_loader, 'loader changed beyond version, predecessor guard and P4 pin'
assert 'approvedNativeContract=nil' in new_loader
assert 'autoAccept=false,completion=false,discord=false' in new_loader
print('PASS 19 unchanged dependencies, identical policy10 selection and final native Accept/completion/Discord OFF')

old_boot = read('pdiddler/pdiddler_V15_7_TELEPORT_AUTOBOOT_v1.lua')
new_boot = read('pdiddler/pdiddler_V15_8_TELEPORT_AUTOBOOT_v1.lua')
old_ref = re.search(r'local V15_7_SHA="([0-9a-f]{40})"', old_boot)[1]
new_ref = re.search(r'local V15_8_SHA="([0-9a-f]{40})"', new_boot)[1]
normalized = new_boot.replace('"PDIDDLER_V15_7_TELEPORT_AUTOBOOT_v1","PDIDDLER_INTEGRATION_V15_7_INVENTORY_GROWTH",', '')
normalized = normalized.replace('pdiddler_INTEGRATED_v15_8_VALUE_FIRST.lua', 'pdiddler_INTEGRATED_v15_7_INVENTORY_GROWTH.lua')
normalized = normalized.replace('V15_8', 'V15_7').replace(new_ref, old_ref)
assert normalized == old_boot, 'bootstrap changed beyond version, predecessor guard and isolated loader pin'
print('PASS Delta teleport transport and queue logic unchanged; predecessor V15.7 owner refused')
