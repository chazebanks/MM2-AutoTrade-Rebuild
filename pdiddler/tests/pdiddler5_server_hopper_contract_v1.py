from pathlib import Path

runtime=Path("pdiddler/pdiddler5_server_hopper_v1.lua")
lab=Path("pdiddler/tests/pdiddler_P1_P5_SERVER_HOP_LIVE_LAB_v1.lua")

assert runtime.exists(), "Part 5 runtime missing"
assert lab.exists(), "standalone Part 1 + Part 5 live lab missing"

r=runtime.read_text()
l=lab.read_text()

required_runtime=[
    "PDIDDLER_P5_STATE_V1",
    "PDIDDLER_PART5_SESSION",
    "PDIDDLER_HOPPING_SESSION",
    "GetTeleportSetting",
    "SetTeleportSetting",
    "JSONEncode",
    "JSONDecode",
    "game:HttpGet",
    "games.roblox.com/v1/games/",
    "/servers/Public",
    "nextPageCursor",
    "UrlEncode",
    "policy.rankCandidates",
    "TeleportToPlaceInstance",
    "LP.OnTeleport:Connect",
    "TeleportService.TeleportInitFailed:Connect",
    "Enum.TeleportState.Failed",
    "function controller:hopNow",
    "function controller:handleBotRejected",
    "HOP ATTEMPT",
    "HOP FAILED",
    "NO TARGET SERVERS",
]
for token in required_runtime:
    assert token in r, f"runtime missing {token}"

for forbidden in [
    "queue_on_teleport",
    "queueonteleport",
    "syn.queue",
    "writefile(",
    "readfile(",
    "AcceptTrade",
    "DeclineTrade",
    "OfferItem",
    "task.delay(",
    "discord.com/api/webhooks/",
    "discordapp.com/api/webhooks/",
]:
    assert forbidden not in r, f"runtime contains forbidden token: {forbidden}"

mark=r.index("markVisited(jobId)")
persist=r.index("persistState()",mark)
teleport=r.index("TeleportToPlaceInstance",persist)
assert mark < persist < teleport, "candidate must be visited+persistent before teleport"

required_lab=[
    "P1 + P5 SERVER HOP LIVE LAB",
    "pdiddler1_KNOWN_GOOD.lua",
    "pdiddler5_server_hopper_policy_v1.lua",
    "pdiddler5_server_hopper_v1.lua",
    "part5.bootstrap(policy)",
    "pcall(p1.run)",
    'handleBotRejected("part1-bot-rejected")',
    "LAB COUNTDOWN",
    "45",
    'hopNow("p1-p5-lab-45s")',
]
for token in required_lab:
    assert token in l, f"lab missing {token}"

bootstrap=l.index("part5.bootstrap(policy)")
part1=l.index("pcall(p1.run)")
assert bootstrap < part1, "Part 5 bootstrap must exist before Part 1 can reject a bot server"

for forbidden in [
    "pdiddler3_",
    "pdiddler4_",
    "AcceptTrade",
    "OfferItem",
    "DeclineTrade",
    "PDIDDLER_DISCORD_WEBHOOK",
]:
    assert forbidden not in l, f"standalone lab must remain P1+P5 only: {forbidden}"

print("PASS standalone Part 1 + Part 5 hopper contract")
