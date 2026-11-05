"""Preserved complete production outgoing worker, wired to successor scanner-evidence coordinator."""
from pathlib import Path
original=Path(__file__).with_name('run_issue24_outgoing_runtime.py').read_text()
original=original.replace("'pdiddler3_outgoing_eligibility_v1.lua'", "'pdiddler3_outgoing_eligibility_v2_SCANNER_EVIDENCE.lua'")
exec(compile(original, str(Path(__file__)), 'exec'))
