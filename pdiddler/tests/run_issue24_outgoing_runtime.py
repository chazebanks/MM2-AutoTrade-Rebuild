"""Execute the complete outgoing controller with real scanner parsing and economic evidence.

Only Roblox GUI/input, remote data, and scheduler boundaries are fixtures. --baseline
loads the preserved v17 controller to reproduce its actual Seer3 request.
"""
from pathlib import Path
import os, shutil, subprocess, sys, tempfile
ROOT = Path(__file__).resolve().parents[2]
def read(name):
    return (ROOT / 'pdiddler' / name).read_text()
def module(label, name):
    return f'local {label}=(function()\n{read(name)}\nend)()\n'
source = read('pdiddler3_scanner_MODULE_v6_8_CRITICAL_PAUSE.lua')
def span(a, b):
    return source[source.index(a):source.index(b)]
parser = (span('local function norm(x)', 'log("START")')
          + span('local function assetKey(x)', 'local function auditEligibleIdentityCollisions()')
          + span('local function inventoryFromProfile(prof)', 'local function unwrapProfile('))
parser = ('local function NEW_PARSER(catalog)\nlocal Meta={}\n'
          'local Sync={Weapons=catalog,Item=catalog}\nlocal function log() end\n'
          + parser + '\nreturn inventoryFromProfile\nend\n')
fixture_source = read('tests/outgoing_v16_test.lua')
nodes = fixture_source[fixture_source.index('local function node('):fixture_source.index('local helpers=')]
nodes = nodes.replace('local function fixture()', 'local function boundaryFixture()')
controller = ('pdiddler3_outgoing_ROTATING_v17_TRANSACTION_LEASE.lua' if '--baseline' in sys.argv
              else 'pdiddler3_outgoing_ROTATING_v18_REACHABLE.lua')
bundle = module('POLICY', 'pdiddler4_supreme_policy_v9_CONSISTENT_QUOTES.lua')
bundle += module('FEASIBILITY', 'pdiddler3_feasibility_v1.lua')
bundle += module('ELIGIBILITY', 'pdiddler3_outgoing_eligibility_v1.lua')
bundle += module('SNAPSHOT', 'snapshots/pdiddler_supreme_snapshot_2026_11_04.lua')
bundle += parser + nodes
bundle += '''local function NEW_OUTGOING(f)
local game,task=f.game,f.task
local os={clock=function() return f.now end}
local function getgenv() return f.env end
local function log(...) local parts={...};for i,v in ipairs(parts) do parts[i]=tostring(v) end;f.logs[#f.logs+1]=table.concat(parts,' ') end
local print,warn=log,log
'''
bundle += read(controller) + '\nend\n'
bundle += read('tests/issue24_outgoing_runtime_test.lua')
compiler = os.environ.get('LUAU_COMPILE') or shutil.which('luau-compile')
luau = os.environ.get('LUAU_BIN') or shutil.which('luau')
assert compiler and luau, 'Official Luau compiler and runtime required'
with tempfile.TemporaryDirectory(prefix='pdiddler-issue24-outgoing-') as td:
    path = Path(td) / 'runtime.luau'
    path.write_text(bundle)
    subprocess.run([compiler, str(path)], check=True, stdout=subprocess.DEVNULL)
    subprocess.run([luau, str(path)], check=True, cwd=ROOT)
