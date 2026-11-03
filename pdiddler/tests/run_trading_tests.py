"""Run new trading fixtures and compile complete runtime source with official Luau.

Set LUAU_BIN and LUAU_COMPILE to locally installed official Luau 0.745 binaries.
Production source is bundled byte-for-byte inside a factory; only Roblox services,
inventory/network boundaries and the scheduler are simulated.
"""
import os
import hashlib
import json
import re
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
manifest = json.loads((ROOT / "pdiddler/tests/integration_sources_v4.json").read_text())
loader = (ROOT / "pdiddler/pdiddler_FASTGATE_V5_INTEGRATED_TEST_v4_SUPREME.lua").read_text()
pins = {key: (filename, ref) for key, filename, ref in re.findall(r'(\w+)=\{"([^"]+)","([0-9a-f]{40})"\}', loader)}
assert set(pins) == {entry["key"] for entry in manifest}, "V4 pin manifest incomplete"
for entry in manifest:
    data = (ROOT / entry["local_path"]).read_bytes()
    digest = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
    assert digest == entry["blob"], f"Source changed: {entry['local_path']}"
    assert pins[entry["key"]] == (Path(entry["path"]).name, entry["ref"])
    assert entry["ref"] != "0" * 40, "Unpublished dependency"
print(f"PASS {len(manifest)} V4 immutable pins and source hashes", flush=True)
lua = next((shutil.which(n) for n in ("lua5.4", "lua5.3", "texlua", "lua") if shutil.which(n)), None)
assert lua, "Install Lua 5.3/5.4 or texlua"
for test in ("supreme_policy_test.lua", "part4_supreme_guard_test.lua", "outgoing_v16_test.lua", "integration_v4_test.lua"):
    subprocess.run([lua, "pdiddler/tests/" + test], cwd=ROOT, check=True)
luau = os.environ.get("LUAU_BIN") or shutil.which("luau")
compiler = os.environ.get("LUAU_COMPILE") or shutil.which("luau-compile")
assert luau and compiler, "Install official Luau; set LUAU_BIN and LUAU_COMPILE"
policy = (ROOT / "pdiddler/pdiddler4_supreme_policy_v1.lua").read_text()
p4 = (ROOT / "pdiddler/pdiddler4_balancer_SUPREME_v1_TEST.lua").read_text()
fixture = (ROOT / "pdiddler/tests/part4_runtime_test.lua").read_text()
bundle = "local POLICY=(function()\n" + policy + "\nend)()\n"
bundle += "local function NEW_PART4(f)\nlocal game,task=f.game,f.task\nlocal os={clock=function() return f.now+(f.clockOffset or 0) end}\nlocal function getgenv() return f.env end\nlocal function print() end\nlocal function warn() end\n" + p4 + "\nend\n" + fixture
with tempfile.TemporaryDirectory(prefix="pdiddler-tests-") as tmp:
    path = Path(tmp) / "part4_runtime.lua"
    path.write_text(bundle)
    subprocess.run([luau, str(path)], cwd=ROOT, check=True)
for path in sorted((ROOT / "pdiddler").glob("*.lua")):
    if path.name in {"pdiddler4_supreme_policy_v1.lua", "pdiddler4_balancer_SUPREME_v1_TEST.lua", "pdiddler3_outgoing_ROTATING_v16_EXACT_IDENTITY.lua", "pdiddler_FASTGATE_V5_INTEGRATED_TEST_v4_SUPREME.lua"} or path.name.startswith("pdiddler_supreme_snapshot_"):
        subprocess.run([compiler, str(path)], stdout=subprocess.DEVNULL, check=True)
print("PASS complete new runtime syntax with official Luau")
