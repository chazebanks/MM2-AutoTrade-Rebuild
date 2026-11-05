"""Prove this capability-audit entry cannot change trading or send UI input."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[2]
MODULE = 'pdiddler/delta_ui/pdiddler_delta_ui_audit_v1.lua'
BOOTSTRAP = 'pdiddler/pdiddler_V15_8_DELTA_UI_AUDIT_AUTOBOOT_v1.lua'
BEGIN = '-- BEGIN PDIDDLER DELTA UI AUDIT MODULE\nlocal DELTA_UI_AUDIT=(function()\n'
END = '\nend)()\n-- END PDIDDLER DELTA UI AUDIT MODULE\n'
CALL_BEGIN = '-- BEGIN PDIDDLER DELTA UI AUDIT CALL\n'
CALL_END = '-- END PDIDDLER DELTA UI AUDIT CALL\n'


def read(path):
    return (ROOT / path).read_text()


def blob(path):
    data = (ROOT / path).read_bytes()
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def remove_block(source, start, end):
    assert source.count(start) == source.count(end) == 1, 'ambiguous audit marker'
    a = source.index(start)
    b = source.index(end, a + len(start))
    return source[:a] + source[b + len(end):], source[a + len(start):b]


preserved = json.loads(read('pdiddler/delta_ui/PRESERVED_SOURCES.json'))
assert len(preserved) == 455 and len({row['path'] for row in preserved}) == 455
for row in preserved:
    assert blob(row['path']) == row['blob'], 'predecessor modified: ' + row['path']
print('PASS all 455 PR31 predecessor files byte-identical: trader, strategy, source prices, bot/scanner/hop and V15.8 bootstrap')

module = read(MODULE)
bootstrap = read(BOOTSTRAP)
normalized, embedded = remove_block(bootstrap, BEGIN, END)
assert embedded.rstrip('\n') == module.rstrip('\n'), 'embedded audit differs from the actual tested module'
normalized, call = remove_block(normalized, CALL_BEGIN, CALL_END)
assert call.count('DELTA_UI_AUDIT.inspect') == 1 and 'pcall(DELTA_UI_AUDIT.inspect,{' in call, 'bootstrap must invoke the protected read-only audit exactly once'
assert 'HttpGet' not in call, 'audit invocation introduced another HTTP fetch'
normalized = normalized.replace('pdiddler_V15_8_DELTA_UI_AUDIT_AUTOBOOT_v1.lua', 'pdiddler_V15_8_TELEPORT_AUTOBOOT_v1.lua')
# Embedding introduces one formatting-only blank beside the BOOT_NAME line.
normalized = normalized.replace('local BOOT_NAME="pdiddler_V15_8_TELEPORT_AUTOBOOT_v1.lua"\n\n\n',
                                'local BOOT_NAME="pdiddler_V15_8_TELEPORT_AUTOBOOT_v1.lua"\n\n')
old = read('pdiddler/pdiddler_V15_8_TELEPORT_AUTOBOOT_v1.lua')
assert normalized.split('\n', 1)[1] == old.split('\n', 1)[1], 'bootstrap changed beyond audit blocks, BOOT_NAME and header'
assert 'local KEY="PDIDDLER_V15_8_TELEPORT_AUTOBOOT_v1"' in bootstrap
assert 'local URL_KEY="PDIDDLER_V15_8_AUTOBOOT_URL"' in bootstrap
assert 'local V15_8_SHA="3daded63893a9165ad6b2a65fcbbf507f1afc571"' in bootstrap
assert bootstrap.index(CALL_BEGIN) < bootstrap.index('    runPinned("pdiddler_native_trade_probe_v2.lua")')
assert bootstrap.count('    runPinned(') == 2, 'audit adds a source fetch or changes the two existing launches'
print('PASS actual module embedded exactly; original keys, loader SHA, guards, queue, transport and two launches unchanged')

# Strip comments and quoted string literals before checking executable tokens.
# Report wording may mention unsafe actions; executable audit code may not call them.
tokens = re.sub(r'--\[\[.*?\]\]|--[^\n]*', '', module + '\n' + call, flags=re.S)
tokens = re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', '""', tokens)
for pattern in [
    r'\b(?:FireServer|InvokeServer|HttpGet|HttpPost|RequestAsync|PostAsync|GetAsync)\s*\(',
    r'\b(?:SendMouseButtonEvent|SendTouchEvent|SendKeyEvent|CaptureController)\s*\(',
    r'\b(?:mouse1click|mouse1press|mouse1release|firesignal|firetouchinterest|sethiddenproperty|writefile|appendfile|setclipboard)\s*\(',
    r'[:.]\s*(?:Destroy|Activate|CaptureFocus|ReleaseFocus|SetAttribute|ClearAllChildren|Connect|WaitForChild)\s*\(',
    r'\.\s*(?:Visible|Enabled|Parent|DisplayOrder|Active)\s*=',
    r'\b(?:task\s*\.\s*(?:wait|delay|spawn)|wait|spawn|request|http_request)\s*\(',
    r'\bGetDescendants\s*\(',
]:
    assert not re.search(pattern, tokens), 'read-only audit has forbidden input/mutation/network/yield token: ' + pattern
assert 'actions=0' in module and 'closeSupported=false' in module
assert module.count('actions=0') == 1 and not re.search(r'\breport\s*\.\s*actions\s*=', tokens)
assert not re.search(r'\b(?:report\s*\.\s*)?closeSupported\s*=\s*true\b', tokens)
for status in re.findall(r'\breport\s*\.\s*status\s*=\s*"([^"\n]+)"', module):
    assert status in {'skipped', 'control-inaccessible', 'overlay-unavailable'}, 'audit claims a close result: ' + status
assert 'PDIDDLER_OUTGOING_SESSION' in module and 'PDIDDLER_PART4_SESSION' in module
print('PASS static zero-input/mutation/network/yield guard; capability result never claims native close support')
