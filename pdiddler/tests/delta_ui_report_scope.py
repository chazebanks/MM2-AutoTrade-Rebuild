"""Guard ASCII-only reporting and pure cached replay without changing trading."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[2]
MODULE = 'pdiddler/delta_ui/pdiddler_delta_ui_audit_v2_ASCII.lua'
BOOTSTRAP = 'pdiddler/pdiddler_V15_8_DELTA_UI_AUDIT_AUTOBOOT_v2.lua'
BEGIN = '-- BEGIN PDIDDLER DELTA UI AUDIT MODULE\nlocal DELTA_UI_AUDIT=(function()\n'
END = '\nend)()\n-- END PDIDDLER DELTA UI AUDIT MODULE\n'
CALL_BEGIN = '-- BEGIN PDIDDLER DELTA UI AUDIT CALL\n'
CALL_END = '-- END PDIDDLER DELTA UI AUDIT CALL\n'
FORMAT_BEGIN = '-- BEGIN PDIDDLER DELTA UI ASCII FORMATTER\n'
FORMAT_END = '-- END PDIDDLER DELTA UI ASCII FORMATTER\n'
EMITTER_BEGIN = '-- BEGIN PDIDDLER DELTA UI TRACE EMITTER\n'
EMITTER_END = '-- END PDIDDLER DELTA UI TRACE EMITTER\n'
REPLAY_BEGIN = '-- BEGIN PDIDDLER DELTA UI CACHED REPLAY\n'
REPLAY_END = '-- END PDIDDLER DELTA UI CACHED REPLAY\n'


def read(path):
    return (ROOT / path).read_text()


def blob(path):
    data = (ROOT / path).read_bytes()
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def remove_block(source, begin, end):
    assert source.count(begin) == source.count(end) == 1, 'ambiguous report marker: ' + begin
    a = source.index(begin)
    b = source.index(end, a + len(begin))
    line = source.rfind('\n', 0, a) + 1
    start = line if not source[line:a].strip() else a
    return source[:start] + source[b + len(end):], source[a + len(begin):b]


def tokens(source):
    source = re.sub(r'--\[\[.*?\]\]|--[^\n]*', '', source, flags=re.S)
    return re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', '""', source)


preserved = json.loads(read('pdiddler/delta_ui/report_v2/PRESERVED_SOURCES.json'))
assert len(preserved) == 474 and len({row['path'] for row in preserved}) == 474
for row in preserved:
    assert blob(row['path']) == row['blob'], 'predecessor modified: ' + row['path']
print('PASS all 474 PR33 predecessor files unchanged, including all trading/source pins and the first audit entry')

old_module = read('pdiddler/delta_ui/pdiddler_delta_ui_audit_v1.lua')
module = read(MODULE)
normalized_module, formatter = remove_block(module, FORMAT_BEGIN, FORMAT_END)
name_start = normalized_module.index('local function name(value)')
path_start = normalized_module.index('local function path(node)', name_start)
old_name_start = old_module.index('local function name(value)')
old_path_start = old_module.index('local function path(node)', old_name_start)
normalized_module = normalized_module[:name_start] + old_module[old_name_start:old_path_start] + normalized_module[path_start:]
normalized_module = normalized_module.replace('local CACHE="PDIDDLER_DELTA_UI_AUDIT_V2"', 'local CACHE="PDIDDLER_DELTA_UI_AUDIT_V1"')
assert normalized_module.split('\n', 1)[1] == old_module.split('\n', 1)[1], 'inspection changed beyond cache key, byte-safe names and new formatter'
assert formatter.count('function M.format(') == 1, 'missing sole pure formatting API'
print('PASS native inspection, ownership guards, read budgets and closeUnsupported contract unchanged beyond V2 cache and byte-safe names')

bootstrap = read(BOOTSTRAP)
old_bootstrap = read('pdiddler/pdiddler_V15_8_DELTA_UI_AUDIT_AUTOBOOT_v1.lua')
normalized, embedded = remove_block(bootstrap, BEGIN, END)
old_normalized, old_embedded = remove_block(old_bootstrap, BEGIN, END)
assert embedded.rstrip('\n') == module.rstrip('\n'), 'embedded V2 differs from the tested actual module'
assert old_embedded.rstrip('\n') == old_module.rstrip('\n')
normalized, call = remove_block(normalized, CALL_BEGIN, CALL_END)
old_normalized, _ = remove_block(old_normalized, CALL_BEGIN, CALL_END)
normalized, emitter = remove_block(normalized, EMITTER_BEGIN, EMITTER_END)
normalized, replay = remove_block(normalized, REPLAY_BEGIN, REPLAY_END)
normalized = normalized.replace('pdiddler_V15_8_DELTA_UI_AUDIT_AUTOBOOT_v2.lua', 'pdiddler_V15_8_DELTA_UI_AUDIT_AUTOBOOT_v1.lua')
assert normalized.split('\n', 1)[1] == old_normalized.split('\n', 1)[1], 'bootstrap changed beyond marked reporting/replay blocks, name and header'
assert 'local KEY="PDIDDLER_V15_8_TELEPORT_AUTOBOOT_v1"' in bootstrap
assert 'local URL_KEY="PDIDDLER_V15_8_AUTOBOOT_URL"' in bootstrap
assert 'local V15_8_SHA="3daded63893a9165ad6b2a65fcbbf507f1afc571"' in bootstrap
assert bootstrap.count('    runPinned(') == 2
assert call.count('DELTA_UI_AUDIT.inspect') == 1
assert bootstrap.index(EMITTER_BEGIN) < bootstrap.index('local old=ENV[KEY]')
assert bootstrap.index(REPLAY_BEGIN) < bootstrap.index('    return old')
assert 'PDIDDLER_DELTA_UI_TRACE_V2' in emitter
print('PASS original bootstrap owner keys, queue, transport and two launches unchanged; replay precedes only the existing-owner return')

audit_tokens = tokens(module + '\n' + call + '\n' + emitter + '\n' + replay)
for pattern in [
    r'\b(?:FireServer|InvokeServer|HttpGet|HttpPost|RequestAsync|PostAsync|GetAsync|JSONEncode)\s*\(',
    r'\b(?:SendMouseButtonEvent|SendTouchEvent|SendKeyEvent|CaptureController)\s*\(',
    r'\b(?:mouse1click|mouse1press|mouse1release|firesignal|firetouchinterest|sethiddenproperty|writefile|appendfile|setclipboard)\s*\(',
    r'[:.]\s*(?:Destroy|Activate|CaptureFocus|ReleaseFocus|SetAttribute|ClearAllChildren|Connect|WaitForChild)\s*\(',
    r'\.\s*(?:Visible|Enabled|Parent|DisplayOrder|Active)\s*=',
    r'\b(?:task\s*\.\s*(?:wait|delay|spawn)|wait|spawn|request|http_request)\s*\(',
    r'\bGetDescendants\s*\(',
]:
    assert not re.search(pattern, audit_tokens), 'report/replay has an input/mutation/native-JSON/network/yield call: ' + pattern
for pure in (formatter, emitter, replay):
    pure_tokens = tokens(pure)
    assert not re.search(r'\b(?:inspect|GetService|GetChildren|GetDescendants|GetAttribute|runPinned)\b', pure_tokens), 'pure formatter/emitter/replay references a UI scan or module launch'
    assert not re.search(r'\b(?:queue_on_teleport|queueonteleport|queue_on_tp|queueontp|queueteleport|queue_for_teleport)\b', pure_tokens), 'report replay changes the teleport queue'
without_comments = re.sub(r'--\[\[.*?\]\]|--[^\n]*', '', module + '\n' + call + '\n' + emitter + '\n' + replay, flags=re.S)
assert not re.search(r'\b(?:GetService|FindService)\s*\(\s*[\'"]HttpService[\'"]\s*\)', without_comments), 'native JSON service dependency was retained'
assert 'closeSupported=false' in module and 'actions=0' in module
assert not re.search(r'\bcloseSupported\s*=\s*true\b', audit_tokens)
assert not re.search(r'\breport\s*\.\s*actions\s*=', audit_tokens)
print('PASS pure ASCII formatting/cached replay: no UI scan/input/mutation/network/yield/new queue, no native JSON and no automatic-close claim')
