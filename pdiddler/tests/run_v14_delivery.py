"""Compile and execute the offline journal/Discord boundaries with official Luau.

Modules are bundled byte-for-byte because the Luau CLI has no dofile(). All HTTP,
JSON, filesystem, and timing boundaries remain injected fixtures. --baseline
selects the preserved outbox v2 to reproduce its missing durability/retry defects.
"""
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
compiler = os.environ.get("LUAU_COMPILE") or shutil.which("luau-compile")
luau = os.environ.get("LUAU_BIN") or shutil.which("luau")
assert compiler and luau, "Set LUAU_BIN and LUAU_COMPILE to official Luau 0.745 binaries"
test_path = ROOT / "pdiddler/tests/v14_delivery_test.lua"
source = test_path.read_text()
modules = (
    ("J", "pdiddler_runtime_journal_v1.lua"),
    ("T", "pdiddler_discord_transport_v1.lua"),
    ("O", "pdiddler_webhook_outbox_v3.lua"),
)
for variable, filename in modules:
    actual = "pdiddler_webhook_outbox_v2.lua" if variable == "O" and "--baseline" in sys.argv else filename
    path = ROOT / "pdiddler" / actual
    subprocess.run([compiler, str(path)], check=True, stdout=subprocess.DEVNULL)
    statement = f"local {variable}=dofile('pdiddler/{filename}')"
    assert source.count(statement) == 1, "Module boundary changed"
    source = source.replace(statement, f"local {variable}=(function()\n{path.read_text()}\nend)()")
subprocess.run([compiler, str(test_path)], check=True, stdout=subprocess.DEVNULL)
with tempfile.TemporaryDirectory(prefix="pdiddler-v14-delivery-") as folder:
    bundle = Path(folder) / "delivery.luau"
    bundle.write_text(source)
    subprocess.run([compiler, str(bundle)], check=True, stdout=subprocess.DEVNULL)
    result = subprocess.run([luau, str(bundle)], cwd=ROOT)
    sys.exit(result.returncode)
