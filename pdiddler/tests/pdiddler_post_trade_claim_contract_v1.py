from pathlib import Path

policy=Path("pdiddler/pdiddler_post_trade_claim_policy_v1.lua")
runtime=Path("pdiddler/pdiddler_post_trade_claim_v1.lua")
scanner=Path("pdiddler/pdiddler3_scanner_MODULE_v6_9_CLAIM_PAUSE.lua")
outgoing=Path("pdiddler/pdiddler3_outgoing_ROTATING_v16_CLAIM_PAUSE.lua")
stack=Path("pdiddler/pdiddler_MANUAL_ACCEPT_GAIN_WEBHOOK_TEST_STACK_v7_AUTO_CLAIM.lua")

for p in [policy,runtime,scanner,outgoing,stack]:
    assert p.exists(), f"missing post-trade claim artifact: {p}"

r=runtime.read_text()
s=scanner.read_text()
o=outgoing.read_text()
st=stack.read_text()

# Runtime arms from the same authoritative completion event as webhook logic.
for token in [
    "AcceptTrade.OnClientEvent:Connect",
    "complete~=true",
    "PDIDDLER_POST_TRADE_CLAIM_BUSY_SESSION",
    "claimStatusOwner",
    "releaseStatusOwner",
    "findClaimButton",
    "VIM:SendMouseButtonEvent",
    "AUTO CLAIM START",
    "AUTO CLAIM TAP",
    "AUTO CLAIM COMPLETE",
    "AUTO CLAIM TIMEOUT",
]:
    assert token in r, f"claim runtime missing {token}"

assert "AcceptTrade:FireServer" not in r
assert "DeclineTrade" not in r
assert "OfferItem" not in r
assert "firesignal(" not in r
assert ":Activate()" not in r

# Claim busy must pause BOTH scanner RPC background work and outgoing rotation.
assert "PDIDDLER_POST_TRADE_CLAIM_BUSY_SESSION" in s
assert 'return true,"post-trade-claim"' in s

busy=o.index("PDIDDLER_POST_TRADE_CLAIM_BUSY_SESSION")
paused=o.index("if S.paused then")
assert busy < paused, "claim pause must run before normal trade-close resume"
assert "POST-TRADE CLAIM PAUSE" in o
assert "POST-TRADE CLAIM RELEASE" in o

# Stack order: claim observer must be armed before webhook/outgoing can race past it.
part4=st.index("part4.run(")
claimer=st.index("postTradeClaim.run(")
logger=st.index("completionLogger.run(")
out=st.index("outgoing.run(scanner)")
assert part4 < claimer < logger < out

for token in [
    "pdiddler_post_trade_claim_policy_v1.lua",
    "pdiddler_post_trade_claim_v1.lua",
    "pdiddler3_scanner_MODULE_v6_9_CLAIM_PAUSE.lua",
    "pdiddler3_outgoing_ROTATING_v16_CLAIM_PAUSE.lua",
    "pdiddler4_balancer_ROTATING_v2_5_1_ADAPTIVE_PLAN_CACHE.lua",
    "FINAL ITEM-TRADE ACCEPT IS DISABLED",
]:
    assert token in st, f"v7 stack missing {token}"

assert "discord.com/api/webhooks/" not in st
assert "AcceptTrade:FireServer" not in st

print("PASS post-trade auto-claim integration contract")
