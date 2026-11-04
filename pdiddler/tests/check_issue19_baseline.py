"""Protect every file in V14 PR17, not just the older PR15 baseline."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[2]
rows=json.loads((root/'pdiddler/tests/issue19_v14_baseline.json').read_text())
for row in rows:
 b=(root/row['path']).read_bytes()
 assert hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()==row['blob'],row['path']
print(f'PASS all {len(rows)} V14 files byte-identical')
