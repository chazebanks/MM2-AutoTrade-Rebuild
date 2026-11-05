"""ASCII Delta report and pure cached-replay gate; no native close behavior proved."""
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
MODULE = 'pdiddler/delta_ui/pdiddler_delta_ui_audit_v2_ASCII.lua'
BOOTSTRAP = 'pdiddler/pdiddler_V15_8_DELTA_UI_AUDIT_AUTOBOOT_v2.lua'
ENTRY = 'pdiddler/delta_ui/report_v2/DELTA_AUDIT_ENTRY.lua'
MANIFEST = 'pdiddler/delta_ui/report_v2/RUNTIME_PINS.json'


def blob(path):
    data = (ROOT / path).read_bytes()
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def main():
    local = '--local-unpinned' in sys.argv
    compiler = os.environ.get('LUAU_COMPILE') or shutil.which('luau-compile')
    luau = os.environ.get('LUAU_BIN') or shutil.which('luau')
    lua = next((shutil.which(name) for name in ('lua5.4', 'lua5.3', 'texlua', 'lua') if shutil.which(name)), None)
    assert compiler and luau and lua, 'Install Lua and official Luau 0.745 or set LUAU_BIN/LUAU_COMPILE'
    if local:
        print('PREPUBLICATION ONLY: audit entry may be absent; all trading/source pins remain immutable', flush=True)
    else:
        manifest = json.loads((ROOT / MANIFEST).read_text())
        assert manifest['moduleBlob'] == blob(MODULE)
        assert manifest['bootstrapBlob'] == blob(BOOTSTRAP)
        assert manifest['loaderRef'] == '3daded63893a9165ad6b2a65fcbbf507f1afc571'
        assert re.fullmatch(r'[0-9a-f]{40}', manifest['bootstrapRef']) and manifest['bootstrapRef'] != '0' * 40
        entry = (ROOT / ENTRY).read_text()
        assert ('/' + manifest['bootstrapRef'] + '/' + BOOTSTRAP) in entry
        assert 'PDIDDLER_V15_8_AUTOBOOT_URL' in entry
        assert manifest['entryBlob'] == blob(ENTRY)
        print('PASS immutable read-only audit module/bootstrap/entry manifest and original V15.8 loader pin', flush=True)
    paths = [MODULE, BOOTSTRAP]
    if (ROOT / ENTRY).is_file():
        paths.append(ENTRY)
    for name in paths:
        subprocess.run([compiler, str(ROOT / name)], check=True, stdout=subprocess.DEVNULL)
    print('PASS added audit module/bootstrap and any entry compile', flush=True)
    env = dict(os.environ, LUAU_BIN=luau, LUAU_COMPILE=compiler, PYTHONDONTWRITEBYTECODE='1')
    commands = [
        [sys.executable, 'pdiddler/tests/delta_ui_report_scope.py'],
        [sys.executable, 'pdiddler/tests/run_delta_ui_checks.py'],
        [lua, 'pdiddler/tests/delta_ui_audit_test.lua', MODULE],
        [lua, 'pdiddler/tests/delta_ui_report_test.lua'],
        [lua, 'pdiddler/tests/delta_ui_report_bootstrap_test.lua'],
        [sys.executable, 'pdiddler/tests/delta_ui_report_json_check.py'],
    ]
    logs = []
    report = Path(tempfile.gettempdir()) / 'delta-ui-report-all-results.txt'
    for index, command in enumerate(commands, 1):
        result = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True)
        logs.append('COMMAND: ' + ' '.join(command) + '\nEXIT: ' + str(result.returncode) + '\n' + result.stdout + result.stderr)
        report.write_text('\n\n'.join(logs))
        print(f'CHECK{index}/{len(commands)} exit={result.returncode}: ' + ' '.join(command), flush=True)
        if result.returncode:
            print(logs[-1], flush=True)
            raise SystemExit(result.returncode)
    inherited = Path(tempfile.gettempdir()) / 'delta-ui-all-results.txt'
    assert inherited.is_file(), 'parent gate did not produce its complete report'
    report.write_text(('READ-ONLY ASCII DELTA UI REPORT / CACHED REPLAY OFFLINE VERIFICATION — no native Exit identity/accessibility or close behavior proved\n'
                      + ('PREPUBLICATION entry permitted absent\n' if local else 'IMMUTABLE AUDIT ENTRY MANIFEST CHECKED\n')
                      + '\n\n'.join(logs) + '\n\nPRESERVED FULL OUTPUT\n' + inherited.read_text()))
    print(f'PASS 6 ASCII report/replay top-level checks including all pinned predecessor suites; {report}', flush=True)


if __name__ == '__main__':
    main()
