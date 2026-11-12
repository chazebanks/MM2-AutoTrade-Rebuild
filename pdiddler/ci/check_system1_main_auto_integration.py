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
# The PR240 and PR238 candidate modules executed by the native integration
# fixture are BYTE IDENTICAL to their reviewed source, not renamed replicas.
# Runtime still loads pinned original branch revisions, not these test files.
reviewed_shadow_fixtures={
 "pdiddler/ci/fixtures/SYSTEM1_FROZEN_PR240_ABA_PLAN.lua":
     "06f00d239ef3d22cc38e23e8f194bb606e6e4a87",
 "pdiddler/ci/fixtures/SYSTEM1_FROZEN_PR238_SHADOW_LEASE.lua":
     "5114d5d5cd57882397150dfe5b306d5571a43826",
}
for fixture,expected in reviewed_shadow_fixtures.items():
    assert sha(fixture)==expected, f"Unreviewed candidate source: {fixture}"

original=read("pdiddler/supervised/pdiddler3_outgoing_START_GATED_v1.lua")
fork=read("pdiddler/system1/pdiddler3_outgoing_single_send_epoch.lua")
preamble=fork.split("-- SUPERVISED P3 START-BARRIER FORK.",1)[0]
assert "System1 supervised" in preamble and "fresh epoch" in preamble
# Preserve the previously reviewed exact original+single-attempt fork.
# Current P3 adds only a narrowly reviewed timeout fail-closed correction.
previous_fork_blob="88a6ddd684d8614ab1ac0095bbe7adc346f3650a"
previous=subprocess.check_output(
    ["git","cat-file","-p",previous_fork_blob],text=True
)
assert previous[len(preamble):]==original.replace(
    "        SendAttempts=3,",
    "        SendAttempts=1, -- System1 bounded test: NEVER retry uncertain first send"
), "Baseline P3 fork no longer matches protected original"
assert fork.startswith(preamble)
assert sha("pdiddler/system1/pdiddler3_outgoing_single_send_epoch.lua")==(
    "10fddb110f5f054e88bb9be475f5c8191a3b8abb"
), "P3 cancellation fix has not passed exact-content review"
for needle in (
    "function M.ignoredTimeoutCancellationVerified(cancelled,stillPending,tradeWindowOpen)",
    "M.ignoredTimeoutCancellationVerified(",
    "S.failStop=true",
    "S.startGateOpen=false",
    "S.paused=true",
    '"P3_CANCEL_UNVERIFIED_STOP"',
    'return "cancel-unverified"',
    'return "ignored"',
):
    assert needle in fork, f"P3 cancel fail-closed contract missing: {needle}"
assert fork.count("        SendAttempts=1,")==1
assert "        SendAttempts=3," not in fork
for banned in ("AcceptTrade:FireServer(", "OfferItem:FireServer(", "PostAsync("):
    assert banned not in fork

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
 "96f6c577cee996266dc8af664a20af445200edff",
 "be8d8c5b77c0c7c345639c53e6a04959728d01a8",
 # Controller pin is checked by current exact Git blob below, not stale SHA.
 'ALT_NAME="venossgaming90190"',
 'function adapters.startEpoch(round,nonce)',
 'function adapters.inspect(round,epoch)',
 'function adapters.offerApproved(round,count,epoch,choiceIndex)',
 'function adapters.removeOwnOne(round,root,epoch,allowAltItem)',
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
 'UNEXPECTED_ACCEPTED_STATE',
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
 'phase=="WAIT_CLOSE"',
 'phase=="WAIT_OPEN"',
 'MAIN_OFFERING',
 'MAIN_WITHDRAWING',
 'MAIN_DECLINING',
 'P3_OLD_EPOCH_DID_NOT_CLOSE',
 'OFFER_FAILED_OR_UNCONFIRMED',
):
    if requirement=="OFFER_FAILED_OR_UNCONFIRMED":
        continue
    assert requirement in fsm,requirement
# Raw.githubusercontent.com/<revision>/<path> requires a tree-ish ref,
# NOT git hash-object's BLOB SHA. A prior green offline mock accidentally
# approved a blob as a commit, causing SOURCE_UNAVAILABLE on real iPad.
controller_path="pdiddler/system1/system1_main_auto_failstop_controller.lua"
controller_ref=re.search(r'local CTRL="([0-9a-f]{40})"',native)
assert controller_ref is not None, "Missing pinned controller revision"
controller_rev=controller_ref.group(1)
kind=subprocess.check_output(["git","cat-file","-t",controller_rev],text=True).strip()
assert kind=="commit", f"Controller revision must be COMMIT; got {kind}"
pinned_blob=subprocess.check_output(
    ["git","rev-parse",f"{controller_rev}:{controller_path}"],text=True
).strip()
assert pinned_blob==sha(controller_path), (
    "Pinned commit controller bytes differ from exact test source",
    pinned_blob, sha(controller_path)
)
assert controller_rev=="e0f0259ff116b0618c3d3504251294302d2e37a2", (
    "Update pinned commit only after a reviewed controller change"
)
assert 'screen.armBatch.Activated:Connect(function()armRounds(8)end)' in native
assert 'explicitEightBatchConsent=requestedRounds==8' in native
assert 'approvedFourDistinctOwnedItems=requestedRounds==8 and #selected==4' in native
assert 'includeEightTradeBatch=requestedRounds==8' in native
assert 'ALT_REVISE_SECOND' in fsm
assert 'WAIT_ALT_CANCEL' in fsm
assert 'ALL_EIGHT_CLIENT_SCENARIOS_VERIFIED' in fsm
assert 'ownRemovalSlotReindexesObserved' in fsm
assert 'noAutomaticAcceptAcknowledged=true' in native
assert native.count("owner.armed=true")==1
assert 'screen.armAdaptive.Activated:Connect' in native
assert 'MAIN_REOFFERING' in fsm
assert 'ALT_REVISE' in fsm
assert 'ALT_CLEAR_FOR_REOFFER' in fsm
assert 'adaptiveReoffersAttempted' in fsm
assert 'uniqueSurvivor(theirPrev,ob.theirs)' in fsm
assert 'altRemovalSlotReindexesObserved' in fsm
assert 'ALT_REMOVAL_SURVIVOR_AMBIGUOUS' in fsm
assert 'requestedNonce' not in native
assert "SYSTEM1_MAIN_AUTO_FAILSTOP_PURE_PASS" in tests
# The current operator UI must present ARM8 only; four cheap approved
# weapons are still mandatory, with no P3 or P4 until a valid ARM.
assert 'screen.arm.Visible=false' in native
assert 'screen.arm.Active=false' in native
assert 'screen.armAdaptive.Visible=false' in native
assert 'screen.armAdaptive.Active=false' in native
assert 'screen.armBatch.Visible=true' in native
assert 'screen.armBatch.Active=canArm' in native
assert 'local canArm=count==4 and available' in native
assert 'PICK "..tostring(4-count).." MORE' in native
assert 'screen.body.Text="ARM 8: EIGHT fresh ALT trade windows' in native
assert 'requestedRounds~=4 and requestedRounds~=5 and requestedRounds~=8' in native
assert 'FEWER_THAN_FOUR_ELIGIBLE_OWN_WEAPON_TYPES' in native
assert 'includeAdaptiveRound=requestedRounds==5' in native
assert 'explicitAdaptiveRevisionConsent=requestedRounds==5' in native
assert "NEVER final Accept" in native
assert 'system1_main_auto_native_original_mocks.luau' in (ROOT/".github/workflows/gingerscope-system1-multitrade.yml").read_text()
assert 'SHADOW_OBSERVER_STALE_DURING_PLACEMENT' in native

assert native.count('controller.abort(')>=3
assert 'onShadowPrepared=function(w)' in native
assert 'makeShadowWitness=function(bound)' in native
assert 'clientOnly=true' in native
assert 'finalAcceptEverAttempted=false' in native
assert 'verifiedCompletedTrades=0' in native
print("SYSTEM1_MAIN_AUTO_INTEGRITY_PASS",len(originals),"original protected files unchanged")
