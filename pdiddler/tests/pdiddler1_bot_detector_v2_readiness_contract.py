from pathlib import Path

v1=Path("pdiddler/pdiddler1_KNOWN_GOOD.lua")
v2=Path("pdiddler/pdiddler1_BOT_DETECTOR_v2_READINESS.lua")

assert v1.exists(), "known-good Part 1 missing"
assert v2.exists(), "Part 1 v2 readiness detector missing"

s=v2.read_text()
old=v1.read_text()

required=[
    "BotAvatarReadyRatio = 0.80",
    "BotAvatarReadyRetries = 4",
    "BotAvatarReadyRetryDelay = 0.75",
    "local function avatarDataReady(report)",
    "math.ceil(report.total * C.BotAvatarReadyRatio)",
    "readinessRetries < C.BotAvatarReadyRetries",
    "task.wait(C.BotAvatarReadyRetryDelay)",
    'printScan("READINESS RETRY "..tostring(readinessRetries), first)',
    "AVATAR DATA INCOMPLETE",
    "return {run = runBotGate}",
]
for token in required:
    assert token in s, f"Part 1 v2 missing {token}"

# The readiness loop must occur before a below-threshold first scan can approve.
loop_i=s.index("readinessRetries < C.BotAvatarReadyRetries")
approve_i=s.index("if not first.bot then")
assert loop_i < approve_i, "readiness gate must run before first-scan approval"

# Keep the known-good artifact frozen; v2 must be a separate implementation.
for token in [
    "BotAvatarReadyRatio",
    "BotAvatarReadyRetries",
    "BotAvatarReadyRetryDelay",
]:
    assert token not in old, f"known-good Part 1 was modified with v2 token {token}"

# This fix is intentionally readiness-only. Do not silently stack new behavior/level guesses.
for forbidden in [
    "leaderstats",
    "MoveDirection",
    "stationaryRatio",
    "stuckRatio",
    "TeleportService",
    "OfferItem",
    "AcceptTrade",
]:
    assert forbidden not in s, f"v2 readiness fix contains unrelated/invented logic: {forbidden}"

print("PASS Part 1 v2 avatar-readiness contract")
