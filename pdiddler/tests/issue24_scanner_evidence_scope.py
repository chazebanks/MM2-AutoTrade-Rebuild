"""Preserve predecessor files, identity/scanning/remote paths and all final-send guards."""
from pathlib import Path
import hashlib,json
r=Path(__file__).resolve().parents[2]
for row in json.loads((r/'pdiddler/presentation/PRESERVED_SOURCES.json').read_text()):
 b=(r/row['path']).read_bytes();assert hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()==row['blob'],row['path']
print('PASS all368 PR25 predecessor files byte-identical')
old=(r/'pdiddler/reachability/pdiddler3_scanner_MODULE_v6_9_VERIFICATION_STATE.lua').read_text()
new=(r/'pdiddler/presentation/pdiddler3_scanner_MODULE_v6_10_CURRENT_PRESENTATION.lua').read_text()
def block(src,a,b):return src[src.index(a):src.index(b)]
for a,b in [('local function inventoryFromProfile(', 'local function fmtValue('),
 ('local function scanOne(', 'local function applyPlayerResult('),
 ('scheduleUnknownRetry = function(', '-- SCANNER API BRIDGE'),
 ('local OwnInventoryGate={', 'function ScannerAPI.restoreWhitelist(')]:
 # Retry-limit UI draw now uses the same presentation composer; retry/scan logic is otherwise exact.
 assert block(old,a,b)==block(new,a,b).replace('renderScannerResult(', 'guiSetPlayer('), 'raw inventory/scan/remote block changed: '+a
# Catalog identity mapping differs only in a diagnostic label about obsolete reference prices.
a='local function assetKey(';b='local function auditEligibleIdentityCollisions()'
normalize=lambda s:s.replace('log("IDENTITY MAP READY",count,"legacy mapping reference",VALUE_SNAPSHOT_UPDATED,"| displayed values use pinned Supreme")','log("VALUE SNAPSHOT READY",count,"rows | source update",VALUE_SNAPSHOT_UPDATED)')
assert block(old,a,b)==normalize(block(new,a,b))
print('PASS catalog/identity/parser/scanning/retry/owned remote logic preserved')
v1=(r/'pdiddler/pdiddler3_outgoing_eligibility_v1.lua').read_text()
v2=(r/'pdiddler/pdiddler3_outgoing_eligibility_v2_SCANNER_EVIDENCE.lua').read_text()
assert block(v1,'local fields=', ' function self:assess(p)')==block(v2,'local fields=', ' function self:assess(p)')
assert v1[v1.index(' function self:authorize(p)'):]==v2[v2.index(' function self:authorize(p)'):]
print('PASS own-read pacing, exact final authorization/prepare/validation and exhaustion clock unchanged')
loader=(r/'pdiddler/pdiddler_FASTGATE_V6_INTEGRATED_TEST_v15_5_SCANNER_EVIDENCE.lua').read_text()
assert 'approvedNativeContract=nil' in loader and 'autoAccept=false,completion=false,discord=false' in loader
assert 'I.rawScanner.setRequestState(p,state==' not in loader
assert 'module("scanner",240,true,{I.profile,I.strict,I.scannerView})' in loader
print('PASS current profile injected before scanner startup; economic UI never uses request channel; final Accept/Discord OFF')
