"""Prove V15.2 changes only UI display, exact pins and predecessor locks.

Run from repository root; this deliberately compares entire source files.
"""
from pathlib import Path
from difflib import unified_diff

ROOT=Path("pdiddler")
def read(name):
    return (ROOT / name).read_text(encoding="utf-8")
def replace_once(s,old,new):
    assert s.count(old)==1, f"expected one occurrence, found {s.count(old)}: {old[:70]!r}"
    return s.replace(old,new,1)
def identical(name,expected,actual):
    if expected!=actual:
        diff="".join(list(unified_diff(expected.splitlines(True),actual.splitlines(True),
                fromfile="expected-"+name,tofile="actual-"+name))[:120])
        raise AssertionError(f"unexpected change in {name}:\n{diff}")
    print("PASS exact isolated transform",name)

old=read("pdiddler1_fast_gate_TEST_v6_VALID_EVIDENCE.lua")
new=read("pdiddler1_fast_gate_v7_HEADLESS.lua")
expected=replace_once(old,
    "-- PDIDDLER P1 FAST GATE V6 | measurement-focused 10-second test",
    "-- PDIDDLER P1 FAST GATE V7 HEADLESS | SAME measurement-focused 10-second gate, no overlay")
expected=replace_once(expected,"local gui,label\n","")
a=expected.index("local function status(message)")
b=expected.index("-- Frozen Part1 scoring function")
expected=expected[:a]+'''-- Headless: preserve status telemetry in the developer console and shared state.
-- Do not create or mutate GUI. Keep generation and lifecycle ownership intact.
local function status(_message) end
local function stop()
    alive=false
end
E.PDIDDLER_FAST_GATE_STOP=stop

'''+expected[b:]
expected=replace_once(expected,'''        if label then
            local m=overview()
            status(string.format(
                "PDIDDLER FAST GATE V6 | SAMPLING %.1f/10s\\n"
                .."players=%d movement coverage=%d | missing=%d partial=%d\\n"
                .."ticks=%d | avatar scans=%d/2 | no hop / trade",
                now-t0,m.total,m.eligible,m.absent,m.oneWindow,samples,#appearance))
        end
''',"")
identical("gate",expected,new)
assert 'Instance.new(' not in new and 'FindFirstChildOfClass("PlayerGui")' not in new
assert 'E.PDIDDLER_FAST_GATE_RESULT={' in new
assert 'evidenceVersion=6,generation=gen' in new
assert 'local END_AT=t0+10' in new
assert 'print("[P1 FAST V5] "..summary:gsub' in new
print("PASS no bot overlay; full result/console/ten-second scoring preserved")

old=read("pdiddler_FASTGATE_V6_INTEGRATED_TEST_v15_1_CURRENT_PRICES.lua")
new=read("pdiddler_INTEGRATED_v15_2_HEADLESS_GATE.lua")
expected=replace_once(old,
    "-- V15 supervised workflow. Opponent-net-addition-only negotiation; V14 transaction and reporting adapters preserved.",
    "-- V15.2 headless gate: V15.1 verified prices and V15 negotiation preserved; only Part 1 overlay removed.")
expected=expected.replace("PDIDDLER_INTEGRATION_V15_1_CURRENT_PRICES",
    "PDIDDLER_INTEGRATION_V15_2_HEADLESS_GATE")
expected=expected.replace("[PDIDDLER V15_1_CURRENT_PRICES]","[PDIDDLER V15_2_HEADLESS_GATE]")
expected=replace_once(expected,
    '"PDIDDLER_INTEGRATION_V15_OPPONENT_ADDED"}) do',
    '"PDIDDLER_INTEGRATION_V15_OPPONENT_ADDED","PDIDDLER_INTEGRATION_V15_1_CURRENT_PRICES"}) do')
expected=replace_once(expected,
    'gate={"pdiddler1_fast_gate_TEST_v6_VALID_EVIDENCE.lua","962dcafe2b5c535ed7c94293ebb812693404d4e7"}',
    'gate={"pdiddler1_fast_gate_v7_HEADLESS.lua","1bcc13d857489376ee57eae42ee34de33323bbeb"}')
expected=replace_once(expected,
    '"Opponent-added-only increases (+10 or 5%); no timed sweetening | Supreme +15 | V14 transaction owner preserved | Accept/Discord OFF | gate="',
    '"Opponent-added-only increases (+10 or 5%); no timed sweetening | Supreme +15 | HEADLESS BOT GATE | Accept/Discord OFF | gate="')
identical("loader",expected,new)
assert 'profile={"snapshots/pdiddler_supreme_snapshot_2026_11_04.lua","11537dfd47f8df72aec7aeba9ecaffdfc5c879d4"}' in new
assert 'p4={"pdiddler4_balancer_SUPREME_v9_OPPONENT_ADDED.lua","54c9ff4b999f67b2a257be10747c32916051bdd4"}' in new
assert 'local approvedNativeContract=nil' in new
print("PASS current prices, negotiation, loading, bot/hop, manual Accept and Discord gates unchanged")

old=read("pdiddler_V15_1_TELEPORT_AUTOBOOT_v1.lua")
new=read("pdiddler_V15_2_TELEPORT_AUTOBOOT_v1.lua")
expected=old.replace("V15_1","V15_2")
expected=replace_once(expected,
    'local V15_2_SHA="672f1ef4472d78eca55047356edb8b52520295c2"',
    'local V15_2_SHA="612d18cd5351ac2e75989b57bb47351d8072948f"')
expected=replace_once(expected,
    'for _,key in ipairs({"PDIDDLER_V15_TELEPORT_AUTOBOOT_v1"',
    'for _,key in ipairs({"PDIDDLER_V15_1_TELEPORT_AUTOBOOT_v1","PDIDDLER_INTEGRATION_V15_1_CURRENT_PRICES","PDIDDLER_V15_TELEPORT_AUTOBOOT_v1"')
expected=replace_once(expected,
    'runPinned("pdiddler_FASTGATE_V6_INTEGRATED_TEST_v15_1_CURRENT_PRICES.lua")',
    'runPinned("pdiddler_INTEGRATED_v15_2_HEADLESS_GATE.lua")')
expected=replace_once(expected,
    "-- Transport-only wrapper. V15_2 pricing/trading/bot checks/hopping are untouched.",
    "-- Transport-only wrapper. Same V15.1 prices, negotiation, bot scoring and hopping; gate panel removed.")
identical("wrapper",expected,new)
assert 'game.PlaceId~=142823291' in new
assert 'PDIDDLER_V15_1_AUTOBOOT_URL' not in new
assert 'PDIDDLER_INTEGRATION_V15_1_CURRENT_PRICES' in new
print("PASS unique auto-entry and legacy owner refusal, no duplicated gate")
print("PASS V15.2 headless-only scope")
