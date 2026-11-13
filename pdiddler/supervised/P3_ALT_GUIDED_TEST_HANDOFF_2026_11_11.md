# P3 after-auto-offer ALT add/remove — corrected first native test handoff (2026-11-11)

**Status: DRAFT, awaiting exact-head CI and first independent physical iPad result.** This is distinct from the closed original PR218 auto-placement test and the closed Stage119 empty-MAIN LastOffer witness. Never claim either as proof of this combined test.

## Why needed

The operator reported: "**The instructions skipped the alt part**", and confirmed the ALT added nothing. The previous assistant had told the user to perform ALT ADD→REMOVE but supplied the unchanged PR218 loader. Its actual in-game UI was **1/2 ARM P3 → 2/2 AUTO OFFER → MAIN Decline**. The re-pasted JSON was exactly the original Nov10 PR218 receipt, not independent evidence for a new ALT test. **Operator did not fail the ALT test; test loader and prompt were wrong.**

## Corrected contract — separate new script, original code frozen

- Main-original `SUPERVISED_P3_ONE_ITEM_AUTO_OFFER_NATIVE.lua` and `SUPERVISED_P3_ONE_ITEM_AUTO_OWNED_PICKER.lua` are Git-blob identical to prior merged PR218 and must NOT be edited.
- New `SUPERVISED_P3_AUTO_ALT_GUIDED_PICKER.lua` is a fork of the tested owned current-item picker with explicit `altMutationGuidedReadOnlyTest=true`, one current owned eligible, nonprotected weapon, exact consenting ALT `venossgaming90190`, separate physical **AUTHORIZE 1 AUTO OFFER** tap. It immutably pins new native runner commit `45b9c3b98c918fa5bdf4e7bf17e5018925d86740`, not branch HEAD.
- New `SUPERVISED_P3_ONE_ITEM_AUTO_ALT_GUIDED_NATIVE.lua` forks only the tested protected P3 ARM + one-shot P4 operator, preserves original immutable source pins (P3 scanner/outgoing/supervisor/watchdog; protected P4 IO; P3/P4 bridge; original geometry; original one-shot gate), and imports new pure `supervised_p3_postoffer_alt_guide.lua` at pinned commit `2f4478ed23743060bb3bd3a56daad47dc59f494e`. **No new trade remote, final Accept, script Decline or server hop.**
- The new purple panel is collision-checked against actual TradeGUI via the original Stage100 geometry helper and offers **STOP / COPY** throughout. On any unavailable/unsafe layout, fail closed rather than cover controls.
- The new report has schema `gingerscope-p3-one-item-alt-guided-native-v1` and generates a random nonprivate `runNonce` via Roblox HttpService GUID. This detects replayed reports but does not authenticate game trade identities or server settlement.

## Required screen flow (the previous test skipped steps 3 and 4)

1. **1/5 MAIN ARM P3**: after prior picker authorization and exact ALT in a fresh original MM2 server, MAIN physically taps ARM. ALT accepts only the **incoming REQUEST**, not final trade Accept.
2. **2/5 MAIN AUTO OFFER**: original strict one-shot auto operator may place exactly one selected, current-owned, cheap weapon. Wait for `offerAttempts=1` and actual one client-visible own slot. Neither user taps final Accept.
3. **3/5 ALT ADD ONE WEAPON**: purple MAIN panel explicitly tells ALT to manually ADD one cheap weapon. Panel does NOT advance if ALT does nothing. Under existing protected P3/P4 coordinator, watch `physicalOwnSlots=1`, `physicalTheirSlots` change 0→1 with two consecutive matching observed GUI samples. Unknown, extra/moved main item, wrong session or closing trade => inconclusive.
4. **4/5 ALT REMOVE SAME WEAPON**: ALT manually removes that one item; panel advances after two consecutive `physicalTheirSlots=0` snapshots. This proves **only GUI count transitions**; exact added/removed item instance and independent server trade revision are not authenticated.
5. **5/5 MAIN MANUALLY DECLINE**: only after both client slot transitions, MAIN manually Declines and taps STOP/COPY. If step 5 does not appear, STOP/COPY and send inconclusive JSON—do not continue or retry same job.

**No one presses final trade Accept.** This tests one-shot non-repeat under *observed opponent client GUI mutations*; it does NOT prove live strategy, acceptance, settlement, profitability or the ability to automatically decline, and none of those are approved.

## Adversarial regression & rollout gate

- Pure Lune mock `pdiddler/ci/supervised_p3_postoffer_alt_guide_mocks.luau`: zero before placement; no skip on untouched ALT; two samples each for add and remove; current GUI root loss, reopened session, altered main offer, extra ALT slots, stop, expired step and protected no-trading output all fail closed.
- Full real-source-native mock `pdiddler/ci/supervised_p3_postoffer_alt_guided_native_mocks.luau` instantiates original guarded IO, P3/P4 coordinator/bridge/supervisor plus new fork, mocks one physical one-shot OfferItem, then adds/removes `TheirOffer.Container.NewItem1`, checks real nonoverlapping purple title **3/5, 4/5, 5/5**, report flags and no second offer. Reuses old negative-path fixtures and original frozen one-shot native tests.
- Dedicated workflow `.github/workflows/gingerscope-p3-alt-guided-test.yml` verifies original picker/native Git blobs unchanged, new runner has no direct trade/Accept/Decline/hop/Discord calls, and all existing inherited checks. **No device loader released until ALL exact-head focused CI and baseline workflows pass.**
- Source-free P1 PR236 remains separate, draft and unmerged. Nothing here resolves its publisher rights/source freshness, settlement or strategy training blockers. No contacts with outside value-list publishers.

## Device receipt expectations

`runNonce` differs across runs, `altAddClientObserved` and `altRemoveClientObserved` are each **true only if observed**; `altSequenceClientComplete=true` only after both. `offerAttemptsKnown=true`, `offerAttempts=1`, `clientVisibleAddedSlots=1` on original protected placement. `authorizesAccept=false`, `serverCompletionProven=false`, `tradeOutcome=UNKNOWN` always. Physical test is NOT claimed before operator returns its new JSON.

**Next action after green CI:** operator runs the new *correct* frozen picker ONCE in a fresh original-MM2 server with consenting ALT, follows on-screen steps. No new action if test ends blocked; inspect anonymized reason.
