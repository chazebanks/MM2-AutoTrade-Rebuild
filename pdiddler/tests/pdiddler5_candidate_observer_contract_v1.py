from pathlib import Path

p=Path("pdiddler/pdiddler5_server_candidate_observer_v1.lua")
assert p.exists(), "candidate observer missing"
s=p.read_text()

required=[
    "function M.new(policy)",
    "function observer:refresh(currentJobId,visited)",
    "game:HttpGet",
    "HttpService:JSONDecode",
    "HttpService:UrlEncode",
    "games.roblox.com/v1/games/",
    "/servers/Public",
    "nextPageCursor",
    "policy.MaxPagesPerRefresh",
    "policy.rankCandidates(all,currentJobId,visited)",
    "return {",
    "candidates=ranked",
]
for token in required:
    assert token in s, f"candidate observer missing {token}"

for forbidden in [
    "TeleportService",
    "TeleportToPlaceInstance",
    "SetTeleportSetting",
    "GetTeleportSetting",
    "PDIDDLER_HOPPING_SESSION",
    "task.spawn",
    "AcceptTrade",
    "OfferItem",
]:
    assert forbidden not in s, f"candidate observer must be read-only: {forbidden}"

print("PASS Part 5 candidate observer contract")
