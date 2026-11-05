"""Guard the isolated Issue27 successor and every predecessor file."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[2]


def blob(path):
    data = (ROOT / path).read_bytes()
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def read(path):
    return (ROOT / path).read_text()


def block(source, start, end):
    return source[source.index(start):source.index(end)]


preserved = json.loads(read('pdiddler/safety27/PRESERVED_SOURCES.json'))
assert len(preserved) == 390, 'unexpected predecessor manifest size'
assert len({row['path'] for row in preserved}) == len(preserved), 'duplicate predecessor path'
for row in preserved:
    assert blob(row['path']) == row['blob'], 'predecessor modified: ' + row['path']
print('PASS all390 PR26 predecessor files byte-identical')

old_p4 = read('pdiddler/pdiddler4_balancer_SUPREME_v9_OPPONENT_ADDED.lua')
new_p4 = read('pdiddler/pdiddler4_balancer_SUPREME_v10_IMMEDIATE_SAFETY.lua')
for start, end in [
    ('local function readSide(', 'local function fullShownName('),
    ('local function resolveEntry(', 'local function yourOfferContains('),
    ('local function tradeDecision(', 'local function marketPlans('),
    ('local function marketPlans(', 'local function txValidate('),
]:
    assert block(old_p4, start, end) == block(new_p4, start, end), 'protected P4 block changed: ' + start
old_config = block(old_p4, 'local C={', 'local function')
new_config = block(new_p4, 'local C={', 'local function')
assert old_config == new_config.replace('    EmergencyClearVerifyTimeout=0.24,\n', '')
assert new_p4.rstrip().endswith('return M'), 'test boundary getter leaked into production'
print('PASS canonical resolution, strict valuation/quantity, +15 decision, planner and inherited timer constants preserved')

old_loader = read('pdiddler/pdiddler_FASTGATE_V6_INTEGRATED_TEST_v15_5_SCANNER_EVIDENCE.lua')
new_loader = read('pdiddler/pdiddler_INTEGRATED_v15_6_IMMEDIATE_SAFETY.lua')
pin_pattern = r'(\w+)=\{"([^\"]+)","([0-9a-f]{40})"\}'
old_pins = {key: (name, ref) for key, name, ref in re.findall(pin_pattern, old_loader)}
new_pins = {key: (name, ref) for key, name, ref in re.findall(pin_pattern, new_loader)}
assert len(old_pins) == len(new_pins) == 20 and set(old_pins) == set(new_pins)
for key in old_pins:
    if key != 'p4':
        assert new_pins[key] == old_pins[key], 'unrelated dependency changed: ' + key
assert new_pins['p4'][0] == 'pdiddler4_balancer_SUPREME_v10_IMMEDIATE_SAFETY.lua'
normalized = new_loader.replace(',"PDIDDLER_INTEGRATION_V15_5_SCANNER_EVIDENCE"', '')
normalized = normalized.replace('V15_6_IMMEDIATE_SAFETY', 'V15_5_SCANNER_EVIDENCE')
normalized = normalized.replace('V15_6', 'V15_5').replace('V15.6', 'V15.5')
normalized = normalized.replace('p4={"' + new_pins['p4'][0] + '","' + new_pins['p4'][1] + '"}',
                                'p4={"' + old_pins['p4'][0] + '","' + old_pins['p4'][1] + '"}')
assert normalized == old_loader, 'loader changed beyond version, owner guard and isolated P4 pin'
assert 'approvedNativeContract=nil' in new_loader
assert 'autoAccept=false,completion=false,discord=false' in new_loader
print('PASS19 unchanged dependencies, isolated P4 selection and final native Accept/completion/Discord OFF')

old_boot = read('pdiddler/pdiddler_V15_5_TELEPORT_AUTOBOOT_v1.lua')
new_boot = read('pdiddler/pdiddler_V15_6_TELEPORT_AUTOBOOT_v1.lua')
old_sha = re.search(r'local V15_5_SHA="([0-9a-f]{40})"', old_boot)[1]
new_sha = re.search(r'local V15_6_SHA="([0-9a-f]{40})"', new_boot)[1]
normalized = new_boot.replace('"PDIDDLER_V15_5_TELEPORT_AUTOBOOT_v1","PDIDDLER_INTEGRATION_V15_5_SCANNER_EVIDENCE",', '')
normalized = normalized.replace('pdiddler_INTEGRATED_v15_6_IMMEDIATE_SAFETY.lua',
                                'pdiddler_FASTGATE_V6_INTEGRATED_TEST_v15_5_SCANNER_EVIDENCE.lua')
normalized = normalized.replace('V15_6', 'V15_5').replace(new_sha, old_sha)
assert normalized == old_boot, 'bootstrap changed beyond version, owner guard and isolated loader pin'
print('PASS Delta teleport queue/transport logic unchanged; prior V15.5 owner refused')
