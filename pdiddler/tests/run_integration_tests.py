"""Run issue-1 isolated tests and check immutable dependency source integrity."""
import hashlib
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
manifest = json.loads((ROOT / "pdiddler/tests/integration_sources_v3.json").read_text())
source = (ROOT / "pdiddler/pdiddler_FASTGATE_V5_INTEGRATED_TEST_v3.lua").read_text()
for entry in manifest:
    data = (ROOT / entry["local_path"]).read_bytes()
    digest = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
    assert digest == entry["blob"], f"Source changed: {entry['local_path']}"
    pin = re.search(r"\b" + entry["key"] + r'=\{"([^"]+)","([0-9a-f]{40})"\}', source)
    assert pin and pin.groups() == (Path(entry["path"]).name, entry["ref"]), f"Pin mismatch: {entry['key']}"
print(f"PASS {len(manifest)} immutable dependency pins and Git blob hashes", flush=True)

runtime = next((shutil.which(name) for name in ("lua5.4", "lua5.3", "texlua", "lua") if shutil.which(name)), None)
if runtime is None:
    raise SystemExit("Install Lua 5.3/5.4 or texlua to run the isolated tests.")
for test in ("integration_v3_test.lua", "hopper_v2_test.lua"):
    subprocess.run([runtime, f"pdiddler/tests/{test}"], cwd=ROOT, check=True)

compiler = next((shutil.which(name) for name in ("luac5.4", "luac5.3", "texluac", "luac") if shutil.which(name)), None)
if compiler is None:
    raise SystemExit("Tests passed, but install luac or texluac for the syntax check.")
files = ["pdiddler/pdiddler_FASTGATE_V5_INTEGRATED_TEST_v3.lua", "pdiddler/pdiddler5_server_hopper_v2.lua"]
files += [str(p.relative_to(ROOT)) for p in (ROOT / "pdiddler/tests").rglob("*.lua")]
for path in files:
    subprocess.run([compiler, "-p", path], cwd=ROOT, check=True)
print("PASS syntax checks for both new runtime files and all isolated Lua tests")
