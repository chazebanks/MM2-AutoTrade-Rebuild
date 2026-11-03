"""Issue 4 tests: new source runs intact in the proven PR3 Roblox fixture."""
import os
import hashlib
import json
import re
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
def blob(path):
    data = (ROOT / path).read_bytes()
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
baseline = json.loads((ROOT / "pdiddler/tests/issue4_baseline_sources.json").read_text())
for entry in baseline:
    assert blob(entry["path"]) == entry["blob"], "Baseline changed: " + entry["path"]
print(f"PASS {len(baseline)} immutable PR3 baseline files", flush=True)
manifest = json.loads((ROOT / "pdiddler/tests/integration_sources_v5.json").read_text())
loader = (ROOT / "pdiddler/pdiddler_FASTGATE_V5_INTEGRATED_TEST_v5_ADAPTIVE.lua").read_text()
pins = {key:(name,ref) for key,name,ref in re.findall(r'(\w+)=\{"([^"]+)","([0-9a-f]{40})"\}', loader)}
assert set(pins) == {row["key"] for row in manifest}
for row in manifest:
    assert pins[row["key"]] == (Path(row["path"]).name,row["ref"])
    assert row["ref"] != "0"*40 and blob(row["local_path"]) == row["blob"]
print("PASS 9 V5 immutable dependency pins and blob hashes", flush=True)
lua = next((shutil.which(n) for n in ("lua5.4", "lua5.3", "texlua", "lua") if shutil.which(n)), None)
assert lua
subprocess.run([lua, "pdiddler/tests/issue4_policy_test.lua"], cwd=ROOT, check=True)
subprocess.run([lua, "pdiddler/tests/issue4_lifecycle_test.lua"], cwd=ROOT, check=True)
subprocess.run([lua, "pdiddler/tests/integration_v5_test.lua"], cwd=ROOT, check=True)
luau = os.environ.get("LUAU_BIN") or shutil.which("luau")
compiler = os.environ.get("LUAU_COMPILE") or shutil.which("luau-compile")
assert luau and compiler
policy = (ROOT / "pdiddler/pdiddler4_supreme_policy_v2_ADAPTIVE.lua").read_text()
p4 = (ROOT / "pdiddler/pdiddler4_balancer_SUPREME_v2_ADAPTIVE.lua").read_text()
original = (ROOT / "pdiddler/tests/part4_runtime_test.lua").read_text()
fixture = original[:original.index('local function test(name,fn)')]
fixture = fixture.replace('node("Container","Frame",ours); node("Container","Frame",theirs)', 'node("Container","Frame",ours); node("Container","Frame",theirs); node("Accepted","Frame",ours,{Visible=false})')
tests = (ROOT / "pdiddler/tests/issue4_runtime_test.lua").read_text()
bundle = "local POLICY=(function()\n" + policy + "\nend)()\n"
bundle += "local function NEW_PART4(f)\nlocal game,task=f.game,f.task\nlocal os={clock=function() return f.now+(f.clockOffset or 0) end}\nlocal function getgenv() return f.env end\nlocal function print() end\nlocal function warn() end\n" + p4 + "\nend\n" + fixture + tests
with tempfile.TemporaryDirectory(prefix="issue4-") as tmp:
    path = Path(tmp) / "runtime.lua"
    path.write_text(bundle)
    subprocess.run([luau, str(path)], cwd=ROOT, check=True)
for path in [*ROOT.glob("pdiddler/*_v2_ADAPTIVE.lua"),ROOT/"pdiddler/pdiddler_trade_verification_v1.lua",ROOT/"pdiddler/pdiddler_webhook_outbox_v2.lua",ROOT/"pdiddler/pdiddler_FASTGATE_V5_INTEGRATED_TEST_v5_ADAPTIVE.lua",ROOT/"pdiddler/pdiddler_supreme_snapshot_2026_11_03_ISSUE4.lua"]:
    subprocess.run([compiler, str(path)], stdout=subprocess.DEVNULL, check=True)
print("PASS issue4 native Luau compile")
