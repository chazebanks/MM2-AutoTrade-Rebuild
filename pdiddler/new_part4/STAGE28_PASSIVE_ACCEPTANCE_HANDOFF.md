# Stage 28 — Passive native acceptance and close-state evidence

**Status:** Draft, offline-tested passive observation. No automated Accept, Decline, OfferItem, trade requests, hopping, or Discord completed-trade events.

## Starting evidence

Stage 27 was confirmed in a real iPad/Delta test: a low-value item (Supreme 3) was placed and later removed. Both actions were verified from separate native GUI captures. The report contained `addVerified=true`, `removeVerified=true`, `status=DONE`, `serverCompletionProven=false`, and `authorizesAccept=false`. That is evidence of a **controlled client-GUI transaction**, not of a completed MM2 trade.

## What Stage 28 actually adds

**Reuses, does not replace:**

- The existing **Stage 9** native trade-window observer and pure item/acceptance normalization. The same current trade root, player/job/session, item slots and scanner identities remain required.
- The existing **Stage 20** Python outcome auditor. It already refuses to equate an accepted icon, a closed window, or two client inventory readbacks with server-confirmed trade completion. Stage 28 does not mint a completed-trade event.
- The Stage 25 scanner-only boot for inventory metadata; no trading controller or duplicate inventory scanner.

**New modules:**

- `p4_stage28_accept_timeline.lua` records native accepted-indicator observations as `NEITHER`, `OURS_ONLY`, `THEIRS_ONLY`, `BOTH_ACCEPTED_PENDING`, `BOTH_ACCEPTED_STABLE`, and `ACCEPT_UNKNOWN`. Two different observations with unchanged, fully resolved weapon identities and at least 150 ms separation are required for a **client** `BOTH_ACCEPTED_STABLE` flag. This is still not a completed-trade flag.
- **MM2 accepts one-sided offers:** at least one weapon must be offered across both sides, but either individual side may be empty. An eligible single-sided trade must not be classified as unresolved simply because the other side is empty. If an offered item really changes after Accept, the timeline records `offerMutationAfterAccept=true`; accepted indicators seen with *zero total weapons* or unresolvable evidence instead set a separate `acceptedWithUnresolvedOffer=true` flag. Neither is trade completion proof.
- A trade GUI disappearing produces `CLOSED_UNKNOWN`. If the observer changes job, partner scope, or GUI root, it produces `INVALID`, not a normal closure.
- `STAGE28_PASSIVE_DELTA_PROBE.lua` is a one-paste passive read-only Delta monitor. It starts the existing scanner-only boot if absent, watches **one** manual trade after it is opened, records Accept/offer/close evidence, and copies **anonymized JSON** to the clipboard when the trade closes or its bounded observation time ends. No panel overlays, no buttons, no trade remotes, no native acceptance.

## Safe device test

1. Rejoin MM2 to clear the prior Stage 27 session. Select Tablet manually.
2. Execute Stage 28's passive probe **before** opening a trade.
3. Open a manual trade with a trusted participant. Have the other player offer at least one eligible weapon, while **your side remains empty**. Only the other player presses Accept. Stage 28 should record `THEIRS_ONLY`, not `UNRESOLVED`, once identities are resolved. **You do not press Accept.**
4. Close or decline that manual trade yourself, without accepting. The probe automatically copies a report starting `[GINGERSCOPE STAGE28 ANONYMIZED]`. Send only the JSON to the project chat.
5. Rejoin to clear the scanner's persistent listeners.

If the partner does not press Accept, the probe can still record `NEITHER` and `CLOSED_UNKNOWN`. **Do not initiate a completed trade for this test.**

The probe records no account identifiers, player names, partner IDs, or item IDs in its JSON. The original scanner GUI and other Roblox console messages may still show in-game names; share only the Stage28 JSON.

## Native evidence from the user's Stage28 session

The first iPad Stage28 report contained `observations=174`, `theirAcceptIndicatorEverVisible=true`, `ourAcceptIndicatorEverVisible=false`, and `status=CLOSED_UNKNOWN`. It also contained `offerMutationAfterAccept=true`, and 32 recent `UNRESOLVED` events. The user independently confirmed MM2 only requires one total offered weapon for Accept; the obsolete timeline required both sides to have a weapon and marked valid partner-only acceptance as invalid. **The mutation flag in that report is therefore not evidence an item was actually changed.**

The correction accepts one-sided offers and splits accepted indicators on truly invalid/unresolved offers from a physically observed post-Accept signature mutation. The source pin in the passive Delta probe was updated to the corrected pure timeline. An explicit 174-poll regression reproduces the user's observation without a false mutation, while retaining `CLOSED_UNKNOWN` and `mayRecordCompletedTrade=false`. The native post-fix behavior requires separate device verification if tested again.

## Accuracy boundaries

- Stage 28 does not need a **fresh price** for observing native Accept indicators, and deliberately passes `marketFresh=false` to Stage9. It cannot calculate quotes or issue trade actions. However, stale scanner identity records may prevent fully resolved offer certification; that yields `UNRESOLVED`, not fabricated acceptance proof.
- Native Stage9's `Accepted` GUI visibility is **only a client indicator**; Roblox's server state is not independently authenticated.
- `CLOSED_UNKNOWN` is NOT success. Even if both Accept icons were visible, the previous Stage20 auditor must still obtain separate, properly scoped source-backed before/after inventory evidence for any **client-level corroboration**. The existing outcome auditor expressly keeps `server_completion_proven=false`, `may_record_completed_trade=false`, and `may_report_profit=false`.
- The current staged Gingerscope trader has **no automatic final Accept**. Do not enable it or a completed-trade webhook based on this stage.

## Tests

- `new_part4/tests/test_stage28_accept_timeline.lua`: pure accepted-indicator, empty-offer, offer-mutation, timeout, wrong-session and closure state machine.
- `new_part4/tests/test_stage28_native_accept_integration.lua`: the actual Stage9 observer against a synthetic Roblox GUI, including manual Accept icon changes, same-session closure, and server-job change.
- `intelligence_lab/test_stage28_acceptance_boundary.py`: Python-first source regression, Lua subprocess tests, compile-only Delta probe and a direct assertion against Stage20 showing a closed-window outcome is `INCOMPLETE` even when both accepted and before/after inventories look consistent.
- Full inherited Stage 8–27 Lua and Python tests run in the same GitHub Actions workflow.

**Next checkpoint:** Review the anonymized Stage28 iPad output before introducing any Accept action. A successful synthetic acceptance/closure test is not a substitute for on-device observation.
