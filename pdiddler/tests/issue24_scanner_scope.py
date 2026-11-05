"""The successor scanner adds only a read-only evidence bridge."""
from pathlib import Path
root = Path(__file__).resolve().parents[2]
old = (root / 'pdiddler/pdiddler3_scanner_MODULE_v6_8_CRITICAL_PAUSE.lua').read_bytes()
new = (root / 'pdiddler/reachability/pdiddler3_scanner_MODULE_v6_9_VERIFICATION_STATE.lua').read_bytes()
start = new.index(b'-- Read-only evidence for outgoing feasibility;')
end = new.index(b'function ScannerAPI.isWhitelisted(userId)', start)
assert new[:start] + new[end:] == old, 'scanner behavior outside additive evidence API changed'
print('PASS scanner GUI, parsing, scanning/retry and critical-pause code byte-identical')
