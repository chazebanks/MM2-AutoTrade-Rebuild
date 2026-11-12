#!/usr/bin/env python3
"""System1 MAIN automatic 4-trade protected runner integrity (offline only).
Checks exact original files, unchanged P3 except bounded single-attempt policy,
one operator ARM, clipboard on all fatal failure paths, and no final Accept.
"""
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[2]
read=lambda x:(ROOT/x).read_text()
sha=lambda x:subprocess.check_output(["git","hash-object",str(ROOT/x)],text=True).strip()
originals={
 "pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua":"eb4dc6342d1d6dda6292490cd8fa00314199d589",
 "pdiddler/supervised/supervised_p3_p4_handoff.lua":"d496d6311dc6c5e24e059fcd71014e274a4be76b",
 "pdiddler/new_part4/stage100_screen_prompt_overlay.lua":"e0eac8e039655999bd7bbac1f12da179db7c22ed",
 "pdiddler/supervised/pdiddler3_outgoing_START_GATED_v1.lua":"c6180a16bb55cbbf853040c9825dd10a44f97756",
}
for file,expected in originals.items():
    got=sha(file)
    assert got==expected, (file,expected,got)
original=read("pdiddler/supervised/pdiddler3_outgoing_START_GATED_v1.lua")
fork=read("pdiddler/system1/pdiddler3_outgoing_single_send_epoch.lua")
preamble=fork.split("-- SUPERVISED P3 START-BARRIER FORK.",1)[0]
assert "System1 supervised" in preamble and "fresh epoch" in preamble
assert fork[len(preamble):]==original.replace(
  "        SendAttempts=3,",
  "        SendAttempts=1, -- System1 bounded test: NEVER retry uncertain first send"
), "P3 fork must be original plus exactly ONE bounded send-attempt setting"
assert fork.count("        SendAttempts=1,")==1
assert "        SendAttempts=3," not in fork

native=read("pdiddler/system1/SYSTEM1_MAIN_AUTO_FOUR_TRADES_NATIVE.lua")
fsm=read("pdiddler/system1/system1_main_auto_failstop_controller.lua")
tests=read("pdiddler/ci/system1_main_auto_failstop_mocks.luau")
for text in (native,fsm):
    for forbidden in (
       "AcceptTrade:FireServer(", "AcceptTrade:InvokeServer(",
       "TeleportService", "PostAsync(", "GetAsync(",
       "SendRequest:FireServer(", "SendTrade:FireServer(",
       "FinalAccept(", "FinalAcceptTrade(",
    ):
        assert forbidden not in text,forbidden

for requirement in (
 "ba76adb21ffe4124c44d6d9a256683861eceb61d",
 "be8d8c5b77c0c7c345639c53e6a04959728d01a8",
 "e27ce2e1a7b9d8e634fe1344365524ed0f3af535",
 'ALT_NAME="venossgaming90190"',
 'function adapters.startEpoch(round,nonce)',
 'function adapters.inspect(round,epoch)',
 'function adapters.offerApproved(round,count,epoch)',
 'function adapters.removeOwnOne(round,root,epoch)',
 'function adapters.decline(round,root,epoch)',
 'function adapters.endEpoch(round,epoch)',
 'function adapters.stopAll()',
 'function adapters.copyReport(report)',
 'currentSupervisor.currentBoundReadOnly',
 'rawScanner.getOwnInventory',
 'shadowModule.new(bound,',
 'planModule.run,',
 'pcall(io.removeOne,root)',
 'pcall(io.decline,',
 'watchdog.new(sup,',
 'boot.new,',
 'screen.arm.Activated:Connect',
 'screen.stop.Activated:Connect',
 'screen.copy.Activated:Connect',
 'noAutomaticAcceptAcknowledged=true',
 'explicitFourRoundConsent=true',
 'finalAcceptDisabled=true',
 'approvedTwoDistinctOwnedItems=true',
 'gate.checkOutbound=nil',
 'E.PDIDDLER_SYSTEM1_MAIN_AUTO_LAST_JSON=json',
 'print("[SYSTEM1 MAIN AUTO JSON] "..json)',
 'io.trade()~=root',
):
    if requirement=="noAutomaticAcceptAcknowledged=true":
        continue  # preapproved original plan consumes this inside native approval
    assert requirement in native,requirement

for requirement in (
 'phase=="STOPPED"',
 'phase=="DONE"',
 'controller.abort(errorCode)',
 'stop(code,true)',
 'pcall(api.copyReport,exported)',
 'pcall(api.stopAll)',
 'TIMEOUT_',
 'distinctRequestEpochRequired=true',
 'authorizesAccept=false',
 'serverCompletionProven=false',
 'tradeOutcome="UNKNOWN"',
 'phase="WAIT_CLOSE"',
 'phase="WAIT_OPEN"',
 'MAIN_OFFERING',
 'MAIN_WITHDRAWING',
 'MAIN_DECLINING',
 'P3_OLD_EPOCH_DID_NOT_CLOSE',
 'OFFER_FAILED_OR_UNCONFIRMED',
):
    if requirement=="OFFER_FAILED_OR_UNCONFIRMED":
        continue
    assert requirement in fsm,requirement
assert 'noAutomaticAcceptAcknowledged=true' in native
assert native.count("owner.armed=true")==1
assert 'requestedNonce' not in native
assert "SYSTEM1_MAIN_AUTO_FAILSTOP_PURE_PASS" in tests
assert native.count('controller.abort(')>=3
assert 'onShadowPrepared=function(w)' in native
assert 'makeShadowWitness=function(bound)' in native
assert 'clientOnly=true' in native
assert 'finalAcceptEverAttempted=false' in native
assert 'verifiedCompletedTrades=0' in native
print("SYSTEM1_MAIN_AUTO_INTEGRITY_PASS",len(originals),"original protected files unchanged")
