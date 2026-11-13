#!/usr/bin/env python3
"""Independent System1 multi-trade native GUI integrity, not live release proof."""
import re
import subprocess
from pathlib import Path

root=Path(__file__).resolve().parents[2]
pure=root/"pdiddler/system1/system1_multitrade_client_walkthrough.lua"
native=root/"pdiddler/system1/SYSTEM1_MULTITRADE_GUIDED_NATIVE.lua"
integration=root/"pdiddler/ci/system1_multitrade_native_original_mocks.luau"
tests=root/"pdiddler/ci/system1_multitrade_walkthrough_mocks.luau"
originals={
 "pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua":"eb4dc6342d1d6dda6292490cd8fa00314199d589",
 "pdiddler/supervised/supervised_p3_p4_handoff.lua":"d496d6311dc6c5e24e059fcd71014e274a4be76b",
 "pdiddler/new_part4/stage100_screen_prompt_overlay.lua":"e0eac8e039655999bd7bbac1f12da179db7c22ed",
}
for name,hash_expected in originals.items():
    file=root/name
    assert subprocess.check_output(
        ["git","hash-object",str(file)],text=True
    ).strip()==hash_expected, f"Original file changed: {name}"

s=native.read_text()
p=pure.read_text()
m=integration.read_text()
t=tests.read_text()
for f in (s,p,m,t):
    for forbidden in (
        "OfferItem:FireServer(", "AcceptTrade:FireServer(",
        "DeclineTrade:FireServer(", "SendRequest:FireServer(",
        "TeleportService", "PostAsync(", "Http:PostAsync(",
        "ClickButton(", "mouse1click(", "VirtualInputManager:Send",
    ):
        assert forbidden not in f, forbidden
for item in (
    "manualContactOnly=true", "p3RequestOriginAuthenticated=false",
    "serverCompletionProven=false", "authorizesOffer=false",
    "authorizesAccept=false", "mayUseForStrategyLearning=false",
    "tradeOutcome=\"UNKNOWN\"", "actualAcceptsByScript=0",
    "physicalOffersSentByScript=0", "p3AutomaticRequestsSent=0",
    "clientOnly=true", "actualDeclinesByScript=0",
    'ALT="venossgaming90190"', "MANUAL",
    "manualBound(root)", "bridge.bind", "geometry.choose",
    "ui.next.Activated:Connect", "ui.copy.Activated:Connect",
    "ui.stop.Activated:Connect",
):
    assert item in s, item
for token in (
    "R1_CLOSE", "R2_ALT_ADD","R2_ALT_REMOVE", "R3_MAIN_ADD",
    "R3_ALT_ADD", "R3_ALT_REMOVE", "R3_MAIN_REMOVE",
    "R4_MAIN_TWO", "R4_ALT_TWO", "R4_ALT_ONE",
    "R4_ALT_EMPTY","R4_MAIN_EMPTY","R4_CLOSE",
    'phase="REVIEW"', 'phase="WAIT_CLOSE_AFTER_FAIL"',
    'serverTradeRevisionProven=false',
    'rawItemIdsAuthenticated=false',
    'authorizesAccept=false',
    'maxWaitSeconds or 90',
):
    assert token in p,token
assert len(re.findall(r'\{phase="R[1-4]_',p))==15, "phase-count regression"
assert "61536126eec12707174d16319e757ab7829b4534" in s
assert "a3c209659942e8b45eec5da3555f7cfb83059c59" in s
assert "SYSTEM1_MULTITRADE_NATIVE_ORIGINAL_PASS" in m
assert "SYSTEM1_MULTITRADE_PURE_PASS" in t
print("SYSTEM1_MULTITRADE_SOURCE_SAFETY_PASS",len(originals),"unchanged protected originals")
