# PR240 — Supervised four-slot ABA shadow pre-send denial (Nov 11, 2026 ET)

**Status:** DRAFT, OFFLINE-ONLY candidate, **no physical iPad/Delta runtime deployment**, no PR merge, no final Accept.

## Proven history — do not repeat or erase

1. Original `pdiddler/supervised/supervised_four_slot_operator_plan.lua` and `supervised_p3_p4_handoff.lua` (merged PR199/200) already protect Gingerscope outbound, verify the original P3/P4 bound client lease, check the four PHYSICAL offer slots/stacks and reject a persistently different partner offer before the next item. That controller is **unchanged** in PR240. Original four-slot Luau regression suite remains intact.
2. PR237 passed real MAIN iPad one prior-approved auto item, ALT add→remove, and P3 resume (client-only), with its own nonprivate run nonce; [PR237 receipt](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/237#issuecomment-6811466319).
3. PR238 separately passed a pure shadow client ABA invalidator in original-source P3/P4 native mocks. A `PREPARED` hypothetical offer is irreversibly `STALE` after observed A→B→A or a client callback, without claiming server offer-revision authentication.
4. PR239 then passed a distinct actual MAIN iPad native test: the hypothetical shadow response was PREPARED, ALT add revoked it, ALT remove did **not** revive it, one original auto item only, P3 resumed; [unique sanitized receipt](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/239#issuecomment-6812110025). PR239 client-ABA evidence is **closed**, do not rerun it just to reconfirm.

## The new distinction addressed

A result of `shadowStillStaleAfterAltRemove=true` is informative, but does NOT by itself enforce rejection inside a multi-item sender. The old supervised plan checked only latest `bound.capture()` immediately before item 2; its GUI A→B→A test restores the same A snapshot and demonstrates it will send its second item without any inter-poll history. A new test-first PR240 CI **RED** on the original module showed the hypothetical absent shadow being ignored (reason `ONSCREEN_STEP_UNAVAILABLE` rather than the required ABA denial); after implementation, a separate regression explicitly demonstrates baseline snapshot-only sends 2 items after a B→A cycle with no observer attachment.

### Code changes on a separate draft candidate ONLY

- `pdiddler/supervised/supervised_four_slot_operator_plan_aba_draft.lua`: direct minimally changed fork of original 1–4 physically slotted supervised one-shot human-approved plan; old runtime source remains byte-identical `2d5212d5da84e6eabfb137b619128bc375a7ca05`.
- This draft's every multi-item call requires `opts.experimentalABAShadowRequired=true`, `opts.makeShadowWitness(bound)` and `opts.onShadowPrepared(witness, itemIndex)` — otherwise it BLOCKS before ANY offer. Single-item semantics and original caller are unchanged.
- After the previous approved item is actually client-visible, establish a new shadow lease against the **current** protected bound P3/P4 root. Two stable client reads must yield `PREPARED` with all source/settlement/Offer/Accept authority flags `false`.
- A separate external read-only observer may poll `witness.poll()` or conservatively call `witness.observeClientUpdateCallback()` while human-driven ALT interactions happen. The callback is NEVER represented as authenticated by the MM2 server.
- Prior to the NEXT item, guard `currentShadowFresh` checks in **three places**: (a) before the visible step, (b) after any yielding `opts.onBeforeItem` GUI instruction, and (c) inside the original protected `gate.checkOutbound` immediately before guarded remote dispatch. A revoked/replaced/malformed shadow cannot approve item 2. An attempted call to `io.offerItem` may be counted as an `offerAttempt` even if its internal guard denies the actual `OfferItem:FireServer`; distinguish attempted calls from confirmed physical sends.
- After item 2 is GUI-confirmed, the new draft builds a **fresh** prepared witness before item 3, and similarly item 4; expected own-side item changes would otherwise invalidate the earlier witness. A stale witness is never reset, reused or retried. `approval._consumed=true` and no final automatic Accept remain unchanged.
- All new output reasons are **static anonymous** `ABA_SHADOW_EXPLICIT_MODE_REQUIRED`, `ABA_SHADOW_REQUIRED_FOR_MULTI_ITEM`, `ABA_SHADOW_PREPARATION_FAILED`, `ABA_SHADOW_STALE_BEFORE_NEXT_OFFER` and existing guarded-remote denial; no item names, accounts, private inventory or session tokens leaked.

### Verification

Dedicated workflow `.github/workflows/gingerscope-p3-four-slot-aba-gate.yml` installs checksum pinned Lune and runs:
- `pdiddler/ci/p3_four_slot_aba_guard_real_mocks.luau`: actual frozen protected `TradeIO`, original P3/P4 bridge and shadow module against both the **original old** and **new guarded draft** four-slot modules. Cases include stable two/four-item offers, ALT add→remove after first, client-only callback invalidation without observed slot delta, stack/chroma/display/own-slot mutation, race after GUI stage before protected remote, absent/malformed/throwing shadow, mandatory observer attach, stale-on-attach, protected Gingerscope, no extra actual `FireServer`.
- `pdiddler/ci/supervised_four_slot_operator_plan_mocks.luau` original 172 assertions.
- `pdiddler/ci/p3_shadow_aba_offer_lease_mocks.luau` original 145 pure Luau assertions; `pdiddler/ci/p3_shadow_aba_native_bound_mocks.luau` original 91 real bound-source assertions.
- Ten `pdiddler.ci.test_p3_shadow_aba_integrity` Python tests with source hash checks and new `pdiddler/ci/check_p3_four_slot_aba_guard.py` compares the original and draft, checks mandatory denial at three boundaries, protects original source blobs, rejects new authority.
- Existing six general main workflows, including Luau compiler, Lune, Hypothesis replay, sanitized replay and style checks.

## Important unsolved boundaries / next phase

**This is only fail-closed when a change was actually observed or a client callback fired.** An A→B→A that occurs entirely between client polls without an observed callback can still evade detection. The external `onShadowPrepared` hook returning `true` is a registration acknowledgement, not proof of adequate live event coverage. There is **no new native iPad script or real observer attachment in PR240**. Do not suggest a real device test now. The next independent engineering issue would be a safe read-only, bounded P3/P4 observer hookup with explicit action-free watchdog and positive/negative tests for missed events, prior to any deployment authorization.

This does **not** provide a fresh lawful market source (PR236 still blocked), raw authenticated weapon mapping, practical independent demand/liquidity, trade attractiveness/decision-making, actual settled trade evidence, completed-trade Discord/learning, automatic multi-item planner approval or final Accept. **The long-term Gingerscope acquisition/growth strategy remains independent.** No fixed +15 rule, no forced highest-item opener, no outbound Gingerscope and no outside value-provider outreach.
