# P3 shadow client ABA offer-mutation lease (Nov 11, 2026 ET)

**NEW issue only: prepared-response invalidation across offer changes that return to the same appearance.** This is a **read-only offline research stage**, not deployed MM2 automation. It does NOT implement real trade planning, approve placements, modify an active controller, provide fresh market prices, or enable final Accept.

## Confirmed previous work and distinct gap

- PR218 (merged) and PR237 (draft, operator's real native result saved in [PR237 receipt](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/237#issuecomment-6811466319)) have **already proven** one user-preapproved protected MAIN auto placement and ALT add→remove observed by the corrected five-step purple guide with exactly one scripted offer attempt. Do not rerun those just to prove add/remove again.
- Existing ORIGINAL protected P3/P4 bridge `pdiddler/supervised/supervised_p3_p4_handoff.lua` checks root, partner, active P3, acceptance flags, physical slots, stacks/Chroma and both side signatures across one capture; it explicitly returns `offerRevisionAuthenticated=false`.
- Existing `pdiddler/supervised/supervised_four_slot_operator_plan.lua` (merged PR199/200) **already** rechecks both sides before every individually approved item and stops after a *persistent* partner mutation. Its original Luau tests specifically assert `PARTNER_OFFER_REVISION_OR_SLOT_CHANGED` and no second send.
- Existing Stage120 `stage120_corrected_guard_preview.py` verifies a research synthetic plan against a fresh candidate snapshot, rejects changed/stale sessions or market, and never authorizes live trades. It is NOT an event-history recorder.
- **Distinct ABA gap:** if the opposite offer goes A→B→A between a preview and a later check, a final-state-only signature comparison matches A. Catching that requires an **observed intermediate mutation or callback** and an irreversible invalidation marker, not simply re-reading the same snapshot.

## Implemented (all offline/shadow, original protected code unchanged)

- `pdiddler/intelligence_lab/p3_shadow_aba_offer_lease.lua` is a pure Lua state machine. It reads a supplied existing **protected client P3/P4 bound.capture**, accepts two stable CLIENT snapshots, and marks a **hypothetical** response `PREPARED`. After an observed change in **either side** (physical slot, quantity, label, Chroma, item candidate ID), it changes to terminal `STALE`. A subsequent return to the original snapshot cannot revive the old prepared response. Changes to root/partner/P3 paused state, malformed callback/snapshot, accepted-state uncertainty or manual stop also mark stale.
- `observeClientUpdateCallback()` can conservatively invalidate a prepared shadow response immediately even when a client GUI has not changed, but it does **not** authenticate the callback's session or server origin. A callback never establishes a valid offer or grants permission.
- `recheckShadow()` returns only `CLIENT_SNAPSHOT_SAME_SHADOW_ONLY_NEVER_SEND`, `REPLAN_REQUIRED`, or other nonauthoritative status. It has **no OfferItem / Accept / Decline / remote / web request / price / Discord integration**.
- The full hypothetical internal fingerprint is kept in memory and **never included in the output**: the result exports only static anonymous reasons, bounded counts of observed changes and all safety authority flags false.
- `pdiddler/ci/p3_shadow_aba_offer_lease_mocks.luau` exercises pure adversarial flows; `pdiddler/ci/p3_shadow_aba_native_bound_mocks.luau` instantiates actual existing `supervised_p3_p4_handoff.lua` + `pdiddler4_tradeio_supervised_v2.lua` in Lune fake Roblox and verifies A→B→A, stacked quantity, same-slot label swap, bad Amount, P3 epoch/ALT/accept/root changes, no remotes. Python source-integrity regression pins all three immutable original code blobs and denies new privileges. A dedicated workflow reruns original four-slot guard and auto one-shot tests.

**Limit of proof:** Polling cannot detect an A→B→A change that occurs **entirely between samples** with no callback observed. This is not a server-signed revision counter or proof that a hypothetical plan is economically sound. Even when `status=PREPARED`, **authorizesOffer=false**, **authorizesAccept=false**, **serverCompletionProven=false**, **verifiedMarketQuote=false**, and **tradeOutcome=UNKNOWN**. Before using this for a future actual trading controller, a separate real-client read-only adapter would need to attach a reliable bounded observer/callback, quarantine missed/stale events and gain its own physical device test; only then could a separately authorized planner ask for a new snapshot. We are not there yet.

## Operator next action

**None for this offline stage.** Do not run the existing PR237 loader merely to reobserve ALT add/remove; it already passed. Do not tell the operator that the shadow lease is deployed, or ask for a device test without a separately reviewed native adapter and exact-head passing CI. No external market-data provider was contacted or sent project information.

**Project continuity:** PR237 remains client-guide test success, PR236 P1 lawful market-source research still blocked, latest P1 account-learnable completed settlement rows **zero**. No old +15 floor, mandatory highest-value opener, or automatic final Accept.
