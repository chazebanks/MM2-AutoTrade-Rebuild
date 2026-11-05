"""Issue27 offline release gate. --local-unpinned is prepublication only."""
from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
LOADER = 'pdiddler/pdiddler_INTEGRATED_v15_6_IMMEDIATE_SAFETY.lua'
BOOTSTRAP = 'pdiddler/pdiddler_V15_6_TELEPORT_AUTOBOOT_v1.lua'
MANIFEST = 'pdiddler/safety27/RUNTIME_PINS.json'


def blob(path):
    data = (ROOT / path).read_bytes()
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def main():
    local = '--local-unpinned' in sys.argv
    compiler = os.environ.get('LUAU_COMPILE') or shutil.which('luau-compile')
    luau = os.environ.get('LUAU_BIN') or shutil.which('luau')
    lua = next((shutil.which(name) for name in ('lua5.4', 'lua5.3', 'texlua', 'lua') if shutil.which(name)), None)
    assert compiler and luau and lua, 'Install Lua and official Luau0.745 or set LUAU_BIN/LUAU_COMPILE'
    loader = (ROOT / LOADER).read_text()
    bootstrap = (ROOT / BOOTSTRAP).read_text()
    pins = {key: (name, ref) for key, name, ref in re.findall(r'(\w+)=\{"([^\"]+)","([0-9a-f]{40})"\}', loader)}
    assert len(pins) == 20
    bootstrap_loader_ref = re.search(r'local V15_6_SHA="([0-9a-f]{40})"', bootstrap)[1]
    if local:
        assert all(ref != '0' * 40 for key, (_, ref) in pins.items() if key != 'p4')
        print('PREPUBLICATION ONLY: successor P4/loader pin placeholders permitted; no native execution claimed', flush=True)
    else:
        assert (ROOT / MANIFEST).is_file(), 'Missing immutable runtime manifest; use --local-unpinned only before publication'
        manifest = json.loads((ROOT / MANIFEST).read_text())
        assert manifest['loaderRef'] == bootstrap_loader_ref != '0' * 40
        assert manifest['loaderBlob'] == blob(LOADER)
        assert manifest['bootstrapBlob'] == blob(BOOTSTRAP)
        assert set(manifest['dependencies']) == set(pins)
        for key, (name, ref) in pins.items():
            path = 'pdiddler/tests/fixtures/p5_policy_v1.lua' if key == 'policy' else 'pdiddler/' + name
            assert ref != '0' * 40 and manifest['dependencies'][key] == {
                'name': name, 'ref': ref, 'blob': blob(path)}, 'pin/blob mismatch: ' + key
        print('PASS20 immutable dependency pins and exact loader/bootstrap manifest', flush=True)
    # Later isolated successors may add files while inheriting this gate.
    runtimes = [ROOT / name for name in [
        'pdiddler/pdiddler4_balancer_SUPREME_v10_IMMEDIATE_SAFETY.lua', LOADER, BOOTSTRAP]]
    for path in runtimes:
        assert path.is_file(), 'missing Issue27 runtime: ' + str(path)
        subprocess.run([compiler, str(path)], check=True, stdout=subprocess.DEVNULL)
    print('PASS all3 Issue27 root Lua runtimes compile', flush=True)
    env = dict(os.environ, LUAU_BIN=luau, LUAU_COMPILE=compiler, PYTHONDONTWRITEBYTECODE='1')
    commands = [
        [sys.executable, 'pdiddler/tests/issue27_scope.py'],
        [sys.executable, 'pdiddler/tests/run_issue24_scanner_checks.py'],
        [sys.executable, 'pdiddler/tests/run_issue27_runtime.py'],
        [sys.executable, 'pdiddler/tests/run_issue27_runtime.py', '--inherited'],
        [lua, 'pdiddler/tests/issue27_loader_test.lua'],
        [lua, 'pdiddler/tests/issue27_bootstrap_test.lua'],
    ]
    logs = []
    report = Path(tempfile.gettempdir()) / 'issue27-all-results.txt'
    for index, command in enumerate(commands, 1):
        result = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True)
        logs.append('COMMAND: ' + ' '.join(command) + '\nEXIT: ' + str(result.returncode) + '\n' + result.stdout + result.stderr)
        report.write_text('\n\n'.join(logs))
        print(f'CHECK{index}/{len(commands)} exit={result.returncode}: ' + ' '.join(command), flush=True)
        if result.returncode:
            print(logs[-1], flush=True)
            raise SystemExit(result.returncode)
    inherited = Path(tempfile.gettempdir()) / 'issue24-scanner-all-results.txt'
    assert inherited.is_file(), 'parent gate did not produce its complete report'
    report.write_text(('ISSUE27 OFFLINE VERIFICATION — native MM2/Delta NOT executed\n'
                      + ('PREPUBLICATION refs permitted\n' if local else 'IMMUTABLE RELEASE MANIFEST CHECKED\n')
                      + '\n\n'.join(logs) + '\n\nPRESERVED FULL OUTPUT\n' + inherited.read_text()))
    print(f'PASS6 Issue27 top-level checks including full pinned predecessor suites; {report}', flush=True)


if __name__ == '__main__':
    main()
