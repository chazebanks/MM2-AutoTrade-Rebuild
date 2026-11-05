"""Guard the isolated strategy policy and all 407 PR29 predecessor files."""
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


def block(source, start, end):
    return source[source.index(start):source.index(end)]


preserved = json.loads(read('pdiddler/strategy28/PRESERVED_SOURCES.json'))
assert len(preserved) == 407 and len({row['path'] for row in preserved}) == 407
for row in preserved:
    assert blob(row['path']) == row['blob'], 'predecessor modified: ' + row['path']
print('PASS all 407 PR29 predecessor files byte-identical, including the complete P4v10 controller')

old = read('pdiddler/pdiddler4_supreme_policy_v9_CONSISTENT_QUOTES.lua')
new = read('pdiddler/pdiddler4_supreme_policy_v10_INVENTORY_GROWTH.lua')
assert block(old, 'local function finite(', 'local function assetKey(') == block(new, 'local function finite(', 'local function assetKey(')
assert block(old, 'function P.sharedItem(', 'function P.rankPlans(') == block(new, 'function P.sharedItem(', 'function P.rankPlans(')
assert old[old.index('function P.selectLateConcession('):] == new[new.index('function P.selectLateConcession('):]
assert block(old, 'function P.planMatches(', '-- First reply') == block(new, 'function P.planMatches(', '-- Transparent initial')
print('PASS quantity, source repricing, canonical identities, strict +15 decision, portfolio facts, plan verification and entire concession ledger unchanged')

rank = block(new, 'function P.rankPlans(', 'function P.selectOpener(')
rank = rank.replace('''        if a.netUsefulKnives~=nil and b.netUsefulKnives~=nil and a.netUsefulKnives~=b.netUsefulKnives then
            return a.netUsefulKnives>b.netUsefulKnives
        end
''', '')
assert rank == block(old, 'function P.rankPlans(', 'function P.selectOpener('), 'rank changed beyond final knife tie break'
dp = block(new, 'function P.buildPlans(', 'function P.planMatches(')
for current, previous in [
    ('risk=0,knives=0,key=""', 'risk=0,key=""'),
    ('                        local knives=pack.knives+(usefulKnife(it) and qty or 0)\n', ''),
    ('risk,facts.key,knives}', 'risk,facts.key}'),
    ('risk=risk,knives=knives,key=key', 'risk=risk,key=key'),
    ('''key=pack.key,portfolio=pack.portfolio,
                    netUsefulKnives=context.known and (usefulKnives(theirs.items)-pack.knives) or nil}''',
     'key=pack.key,portfolio=pack.portfolio}'),
]:
    assert current in dp, 'missing expected additive DP field: ' + current
    dp = dp.replace(current, previous)
assert dp == block(old, 'function P.buildPlans(', 'function P.planMatches('), 'planner changed beyond additive knife count/key/metadata'
print('PASS exact owned-combination DP preserved; only bounded knife count, state-key distinction and plan metadata added')

old_loader = read('pdiddler/pdiddler_INTEGRATED_v15_6_IMMEDIATE_SAFETY.lua')
new_loader = read('pdiddler/pdiddler_INTEGRATED_v15_7_INVENTORY_GROWTH.lua')
pattern = r'(\w+)=\{"([^\"]+)","([0-9a-f]{40})"\}'
old_pins = {key: (name, ref) for key, name, ref in re.findall(pattern, old_loader)}
new_pins = {key: (name, ref) for key, name, ref in re.findall(pattern, new_loader)}
assert len(old_pins) == len(new_pins) == 20 and set(old_pins) == set(new_pins)
for key in old_pins:
    if key != 'strict':
        assert new_pins[key] == old_pins[key], 'unrelated dependency changed: ' + key
assert new_pins['strict'][0] == 'pdiddler4_supreme_policy_v10_INVENTORY_GROWTH.lua'
normalized = new_loader.replace(',"PDIDDLER_INTEGRATION_V15_6_IMMEDIATE_SAFETY"', '')
normalized = normalized.replace('V15_7_INVENTORY_GROWTH', 'V15_6_IMMEDIATE_SAFETY')
normalized = normalized.replace('V15_7', 'V15_6').replace('V15.7', 'V15.6')
normalized = normalized.replace('strict={"' + new_pins['strict'][0] + '","' + new_pins['strict'][1] + '"}',
                                'strict={"' + old_pins['strict'][0] + '","' + old_pins['strict'][1] + '"}')
assert normalized == old_loader, 'loader changed beyond version, owner guard and isolated policy pin'
assert 'approvedNativeContract=nil' in new_loader
assert 'autoAccept=false,completion=false,discord=false' in new_loader
print('PASS 19 unchanged dependency pins, identical P4 selection and final native Accept/completion/Discord OFF')

old_boot = read('pdiddler/pdiddler_V15_6_TELEPORT_AUTOBOOT_v1.lua')
new_boot = read('pdiddler/pdiddler_V15_7_TELEPORT_AUTOBOOT_v1.lua')
old_ref = re.search(r'local V15_6_SHA="([0-9a-f]{40})"', old_boot)[1]
new_ref = re.search(r'local V15_7_SHA="([0-9a-f]{40})"', new_boot)[1]
normalized = new_boot.replace('"PDIDDLER_V15_6_TELEPORT_AUTOBOOT_v1","PDIDDLER_INTEGRATION_V15_6_IMMEDIATE_SAFETY",', '')
normalized = normalized.replace('pdiddler_INTEGRATED_v15_7_INVENTORY_GROWTH.lua', 'pdiddler_INTEGRATED_v15_6_IMMEDIATE_SAFETY.lua')
normalized = normalized.replace('V15_7', 'V15_6').replace(new_ref, old_ref)
assert normalized == old_boot, 'bootstrap changed beyond version, owner guard and isolated loader pin'
print('PASS Delta teleport queue/transport unchanged; predecessor V15.6 owner refused')
