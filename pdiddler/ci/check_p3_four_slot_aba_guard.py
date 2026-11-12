#!/usr/bin/env python3
"""PR240 source-integrity checks for isolated, optional ABA-denial draft.

This is NOT a deployment gate. Live operator plan source stays unchanged;
only a separately named candidate receives extra fail-closed denial checks.
"""
from __future__ import annotations

import difflib
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
ORIG=ROOT/"pdiddler/supervised/supervised_four_slot_operator_plan.lua"
DRAFT=ROOT/"pdiddler/supervised/supervised_four_slot_operator_plan_aba_draft.lua"
BRIDGE=ROOT/"pdiddler/supervised/supervised_p3_p4_handoff.lua"
TRADEIO=ROOT/"pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua"
SHADOW=ROOT/"pdiddler/intelligence_lab/p3_shadow_aba_offer_lease.lua"

def blob(path:Path)->str:
    return subprocess.check_output(["git","hash-object",str(path)],text=True).strip()

assert blob(ORIG)=="2d5212d5da84e6eabfb137b619128bc375a7ca05"
assert blob(BRIDGE)=="d496d6311dc6c5e24e059fcd71014e274a4be76b"
assert blob(TRADEIO)=="eb4dc6342d1d6dda6292490cd8fa00314199d589"
assert blob(SHADOW)=="5114d5d5cd57882397150dfe5b306d5571a43826"

original=ORIG.read_text()
draft=DRAFT.read_text()
assert original!=draft
ratio=difflib.SequenceMatcher(a=original,b=draft,autojunk=False).ratio()
assert ratio>0.72, f"candidate diverged too far from immutable original: {ratio:.3f}"
for important in (
    'spentBindings[bound]=true',
    'approval._consumed=true',
    'approval.armed=false',
    'candidateAdded(expectedOwn,fresh.ours,approved)',
    'gate.checkOutbound=nil',
    'return report("CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED"',
    'PROTECTED_GINGERSCOPE_IN_OWN_OFFER',
):
    assert important in draft,important

for must in (
    'experimentalABAShadowRequired==true',
    'ABA_SHADOW_REQUIRED_FOR_MULTI_ITEM',
    'ABA_SHADOW_STALE_BEFORE_NEXT_OFFER',
    'ABA_SHADOW_PREPARATION_FAILED',
    'CLIENT_SNAPSHOT_SAME_SHADOW_ONLY_NEVER_SEND',
    'local function prepareShadow(bound,opts,itemIndex)',
    'opts.makeShadowWitness',
    'opts.onShadowPrepared',
    'pcall(w.recheckShadow)',
    'pcall(w.prepareShadow)',
    'shadowReceiptSafe(r,"PREPARED")',
    'currentShadowFresh(preparedWitness)',
    'local nextState=io.trade()==root and current(bound,expectedOwn,their)',
):
    assert must in draft,must
# Guard must not be a one-time check only: it checks before the GUI step,
# after the potentially yielding GUI step and inside guarded outbound dispatch.
assert draft.count('currentShadowFresh(preparedWitness)')==3
assert draft.index('onBeforeItem(itemIndex,#selected,#before.ours)') < draft.index(
    '  -- On-screen step may yield')
assert draft.index('  -- After the prior approved own-item placement') > draft.index(
    '  if not observed then')

for forbidden in (
    "AcceptTrade:FireServer(", "OfferItem:FireServer(", 
    "DeclineTrade:FireServer(", "SendRequest:FireServer(",
    "TeleportService", "PostAsync(", "GetProfileData:InvokeServer(",
    "setclipboard(", "JSONEncode(",
):
    assert forbidden not in draft, forbidden
assert 'authorizesAccept=false' in draft
assert 'serverCompletionProven=false' in draft
assert 'mayUseForStrategyLearning=false' in draft
assert 'tradeOutcome="UNKNOWN"' in draft

print("P3_FOUR_SLOT_ABA_DRAFT_INTEGRITY_PASS",f"preserved-string-similarity={ratio:.3f}")
