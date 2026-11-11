# Gingerscope — real P3 → real protected P4, one separate human-approved physical item

## ACTUAL ORIGINAL MM2 iPad SUPERVISED DEVICE RESULT (2026-11-10 EST): **PASS**

Following merged PR216/217, user supplied **actual native** result: `p3ArmObservedClient=true`, `clientTradeWindowObserved=true`, `oneItemTapObservedClient=true`, `oneItemOfferStatus=CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED`, `offerAttemptsKnown=true`, `offerAttempts=1`, `clientVisibleAddedSlots=1`, `snapshotRejectReason=NONE`, `clientResumeObserved=true`, `lastObservedStatus=P3_ROTATING`, `status=STOPPED`, `reason=OPERATOR_STOPPED`, `serverCompletionProven=false`, `tradeOutcome=UNKNOWN`; every authorization/profit/Discord flag false. This finally **closes the previous NEW combined item picker → real P3 → guarded P4 one item → P3 resume client-only proof**, which the below original handoff had described as pending. Do not retest it solely to repeat earlier proof. The raw selected weapon ID and actual server-side transfer are NOT in the report. Preserve these limitations; do not call the client GUI slot a completed trade. [Full exact JSON in PR217 comment](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/217#issuecomment-6784585245).

The current correctly implemented user interaction remains three separate human actions: choose/confirm current weapon, ARM P3 request, then tap OFFER 1 ITEM after verified partner trade opens. A shift to automatically offering on trade-open requires a NEW distinct consent/safety and idempotence specification, not just this PASS. No auto Accept, server settlement, profit/market strategy, Discord, public unsupervised trade or obsolete +15. Later historical language saying 'not yet tested on iPad' documents the state *before* this user report; superseded by this section.


## Why this is the NEXT distinct milestone

The operator's previous original-MM2 MAIN iPad Delta result from merged PR214 conclusively established the narrow **client-side** milestones: explicit P3 ARM, the correct protected P4 client trade GUI opened, the P3 queue resumed after manual trade closure and later reported `P3_ROTATING`. Real two-distinct-slot manual placement from PR206 already passed earlier. **Do not repeat these completed tests.** Neither proof is server settlement, trade completion, authenticated ownership, a live value or permission for final Accept.

Merged PR215 `9138751b5a57415939ffa1618ac57811d7c8ec7b` adds a *revocable read-only* `controller.currentBoundReadOnly()` to the **real** P3→P4 coordinator. The previously tested four-slot controller knew how to safely use a manually selected, non-Gingerscope raw weapon key but the old native P3 runner never connected these actual components. This new integration addresses exactly that missing boundary while intentionally limiting the FIRST real integrated offer to ONE item.

## Scope / new sources

- `supervised_p3_startup_supervisor.lua` exposes `supervisor.currentBoundReadOnly()` only when real P3 is ARMED, same job/epoch, live watchdog and GUI, exact scanner/ALT and no other controller owner. It delegates to PR215 and does not expose the mutable coordinator.
- `supervised_p3_one_item_operator.lua` requires **separate physical tap** authorization; it spends consent *before* any yielding RPC; checks a current client `rawScanner.getOwnInventory()` (real MM2 `GetProfileData`), exact raw key/copy count/weapon type/Godly-Ancient-Chroma/display/variant, and uses the original `supervised_four_slot_operator_plan.lua` for EXACTLY ONE protected `OfferItem` attempt. No stale price or inventory-total value is used to decide. Rechecks unchanged revocable bound trade after the own-inventory read. Any rejected/unknown/late GUI update stops with no repeated physical send.
- `SUPERVISED_P3_ONE_ITEM_OFFER_NATIVE.lua` is a **NEW** pinned, iPad-facing purple mobile runner. The proven old PR214 P3-only runner is untouched. One panel has physically distinct **ARM P3** (request only), **OFFER 1 ITEM** (appears only after actual exact P4 trade GUI; shows approved current display and raw key), and **STOP / COPY**. It uses the prior collision-safe Stage100 viewport/trade geometry, original watchdog and exact ALT-only scanner proxy. No public rotation, automatic item offer after P3 ARM, final Accept, completed trade Discord, auto-hop or market decision logic.
- New actual Lune tests run real original P3 coordinator, guarded P4 TradeIO, four-slot planner, and native user-button wrapper with controlled fake gameplay/GUI. Negative cases include absent tap, wrong inventory, wrong raw/display/Chroma, protected Gingerscope, stale epoch, wrong ALT, existing Accept indicator, fullscreen/unsafe viewport, GUI label mismatch, RPC trade closure and no retry. Python source-integrity tests audit exact pins, protected assets, legacy strategy absence and unchanged PR214 native runner + protected TradeIO.

### Current verified review head and gate

Exact branch head with native and Python regressions passed **six GitHub Actions checks** (record final reviewed HEAD before merge), including the supervised original Lune job. Tests at commit `84fc72a76612919b752a6de1f64e7cab59758007`: focused operator **106 assertions**, new original-MM2 native **74 assertions**, Python **8 tests**, plus existing original P3+P4+four-slot integration suites. No changes to old `pdiddler4_balancer`, hardcoded +15 policy, old quote values, full offer strategy, auto final Accept, reporting, bot detector, scanner or legacy requester.

### Source pin preservation

The NEW runner SHA-pins the new supervisor to `af84b23173620b03e919187b08cd352c101ba4ea` and the config-frozen operator to `b124488a7a879b2d6a1bfb21401f497d7bfef677`. Python CI independently compares the **actual frozen Git commit bytes** to the currently tested module contents; the raw-key/display/Chroma selection cannot mutate between on-screen consent, current own-inventory read and physical OfferItem. It imports original already-merged PR215 coordinator by `9138751b5a57415939ffa1618ac57811d7c8ec7b` and protected four-slot planner by `27e061555321c6a87bdd835ce3d1ff557443a909`; other eight modules keep their original reviewed frozen pins. **Merge PR216 with a history-preserving merge commit rather than squash**, or else separately re-pin new modules to a surviving merged SHA before distributing a loader. Never provide live iPad loader from an unmerged branch or use the old PR212 launcher.

## NEW eventual native hardware test, distinct from completed work

Requires explicit operator selection of ONE currently owned, non-Gingerscope Ancient/Godly/Chroma Godly/Chroma Ancient weapon: exact game raw key, expected actual GUI display name, and boolean Chroma. Do not silently choose by value or assume an old item is still owned. Fresh original MM2 lobby, MAIN iPad Delta and consenting `venossgaming90190` in SAME server, ALT with at least one eligible item, NO old pdiddler/Stage probes, no trade already open. Prepare `PDIDDLER_SUPERVISED_P3_ONE_ITEM_NATIVE` with:
- `enableNativeSupervisor=true`, `finalAcceptMustRemainManual=true`, `altOnlyTest=true`, `targetName="venossgaming90190"`;
- `allowOneItemPilot=true`, `manualOfferOnly=true`, `noAutomaticAcceptAcknowledged=true`;
- `approvedRawKey="EXACT_OWNED_RAW_WEAPON_KEY"`, `approvedDisplayName="EXACT_VISIBLE_GUI_DISPLAY"`, `approvedChromaFlag=false` (true only for confirmed Chroma).

Execute only the exact **merged** source SHA-pinned `pdiddler/supervised/SUPERVISED_P3_ONE_ITEM_OFFER_NATIVE.lua`. Tap **ARM P3** on MAIN; ALT manually accepts the *request*; once the correctly bound P4 GUI appears, check the exact displayed approval line and physically tap **OFFER 1 ITEM**. The script independently rechecks ownership and protected P4 session before one physical `OfferItem` remote. MAIN visually checks the item appears as expected and then manually presses **Decline**; **NEVER press final Accept** on either account. Tap **STOP / COPY** and send sanitized report. If START/ARM/OFFER panel absent, rejected, stopped, stale, or appears over TradeGUI, do not stack or retry in the same server; send status or screenshot, no guessing.

Expected result on success: `oneItemTapObservedClient=true`, `oneItemOfferStatus=CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED`, `offerAttempts=1`, `clientVisibleAddedSlots=1`, P3 previously observed client bound, and **ALL completion/pricing/final-Accept/Discord flags false**. GUI display is still NOT authenticated server settlement. On failure the sanitized result must not claim a successful trade or silently retry an uncertain RPC.

## What this does NOT mean

There is no fresh validated Supreme/MM2Values price authorization, no full inventory economics, no seller-interest likelihood, no safe automatic final Accept, no authenticated completed trade transaction, and no Discord completed-trade learner. Gingerscope remains protected outbound. Old fixed +15 floor, automatic highest-value opener and sweetening are **superseded and prohibited**. The next work after native evidence is to diagnose only the actual reported failure (if any), then separately expand to 2–4 approved items / market-aware planner; do not start those before this first integrated boundary is genuinely verified.

## Future-conversation continuity

First read `pdiddler/GINGERSCOPE_NEXT_CONVERSATION_CANONICAL_2026_11_10.md` and `pdiddler/GINGERSCOPE_LATEST_CHECKPOINT.md`, then this file and all source/CI/native result. Preserve all previous stage failures and user-approved strategy scope. No repeated device tests for the old PR206 or PR214 proofs.
