from pathlib import Path

p=Path("pdiddler/pdiddler_p1_p5_observation_gui_v1.lua")
assert p.exists(), "observation GUI module missing"
s=p.read_text()

required=[
    'GUI_NAME="PDIDDLER_P1_P5_OBSERVATION_GUI"',
    "function M.new(config)",
    "function controller:start()",
    "function controller:setBotRehop()",
    "function controller:markManualBotted(remaining)",
    "function controller:destroy()",
    "Players:GetUserThumbnailAsync",
    "Enum.ThumbnailType.HeadShot",
    "Enum.ThumbnailSize.Size100x100",
    "policy.actionLabel",
    "hum:GetState().Name",
    "hum.MoveDirection.Magnitude",
    "TextChatService.SendingMessage:Connect",
    "LP.Chatted:Connect",
    "candidateObserver:refresh",
    "CANDIDATE_REFRESH_SECONDS=5",
    "ACTION_REFRESH_SECONDS=0.5",
    "MAX_CANDIDATES=5",
    "UserInputService",
    "InputChanged",
    "Snapshot captured",
]
for token in required:
    assert token in s, f"GUI missing {token}"

for forbidden in [
    "TeleportToPlaceInstance",
    "TeleportService",
    "AcceptTrade",
    "DeclineTrade",
    "OfferItem",
    "discord.com/api/webhooks/",
    "task.delay(",
    "botting",
    "farming",
    "collecting",
]:
    assert forbidden not in s, f"GUI contains forbidden behavior/token: {forbidden}"

assert s.count("manualBotted") >= 2, "manual marker state must be explicit/deduped"
assert "sessionAlive()" in s, "old callbacks must be session gated"

print("PASS P1 P5 observation GUI contract")
