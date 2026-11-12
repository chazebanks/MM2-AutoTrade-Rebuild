# PR239 — P3 shadow ABA native next-test handoff (Nov 11, 2026 Eastern)

**Current status:** draft; exact-head CI must be green before handing operator an iPad command; native device test NOT performed. This is a new tested capability, not a request to repeat PR237 without additional evidence.

## Context and distinctive success condition

The user has already provided a **real, unique** ALT add→remove client test result for draft PR237: [nonce b82a14bf...](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/237#issuecomment-6811466319) with `altAddClientObserved=true`, `altRemoveClientObserved=true`, `offerAttempts=1`; this closes client guide + one-shot nonrepeat. PR238 separately developed the pure **shadow-only offer-lease** and passed original protected P3/P4 native Luau mock integration plus Python. PR239 now tests **a different claim**: *after a prepared hypothetical response exists, does ALT add revoke it and does ALT remove fail to revive it?* Existing PR199 physical-slot plan rejects a changed offer still visible at a checkpoint; it does not track observed historical A→B→A with no callback/sequence memory.

## Protected code chain and intent

PR239 is stacked on actual PR237 branch, not merged main. Its new picker `SUPERVISED_P3_SHADOW_ABA_PICKER.lua` is a fork of the ALREADY TESTED human-owned one-shot picker and immutably pins **new** native runner `b16fb1c03e6123fe6b25346f2619ca6fa0fb4d90`. It requires exact consenting ALT, selected safe currently-owned inexpensive non-Gingerscope item, separate human **AUTHORIZE 1 AUTO OFFER** and **ARM P3**. Previous PR218/PR237 picker, native runner, P3/P4 coordinator, protected IO and one-shot gate remain Git-blob identical.

New runner `SUPERVISED_P3_SHADOW_ABA_NATIVE.lua` uses the PR237 protected ALT on-screen guide, plus immutable source `pdiddler/intelligence_lab/p3_shadow_aba_offer_lease.lua` from verified PR238 head `e2e768e15a12dd9fffaf721519db79aa3bcaec7d`. It calls `supervisor.currentBoundReadOnly()` from the protected frozen PR215 P3/P4 supervisor; the shadow observer itself has **no** offer, Accept, decline, prices or actual trade authority.

1. MAIN selects one current cheap eligible owned nonprotected item, physically AUTHORIZE 1 AUTO OFFER then ARM P3. Exact consenting ALT manually accepts the incoming **request** only.
2. MAIN automatically places exactly the one prior-approved item via the unchanged PR218 safeguarded one-shot, original P4 sees one own slot. No final Accept.
3. **Before showing ALT ADD**, shadow client P3/P4 read-only lease must capture at least TWO stable client snapshots and mark the hypothetical response PREPARED. If this fails, **do not ask ALT to change anything**; STOP/COPY. No unseen "shadow prepared" promise.
4. **3/5 ALT ADD**: ALT manually adds ONE cheap expendable weapon to its visible offer. Main shadow polls the actual bound protected offer, marks prepared shadow **STALE on the first observed change** (no second actual MAIN item offer). Native record `shadowInvalidatedOnAltAdd=true` only if current protected client snapshot genuinely shows one ALT physical slot at the change, not merely after a timer.
5. **4/5 ALT REMOVE**: ALT manually removes that weapon. Existing PR237 guide requires two stable client reads confirming ALT slot zero. Shadow recheck must **remain STALE** after offer returns to same appearance as when prepared; `shadowStillStaleAfterAltRemove=true` only after both GUI phases and shadow terminal state.
6. **5/5 MAIN DECLINE**: MAIN manually declines then STOP/COPY; share sanitized JSON. No one presses final trade Accept; never request genuine inventory transfer.

### Distinct versioned report

`schema=gingerscope-p3-shadow-aba-native-v1`, nonprivate unique `runNonce`, `shadowPreparedClient`, `shadowInvalidatedOnAltAdd`, `shadowStillStaleAfterAltRemove`, `shadowObservedGuiMutationCount`, `shadowExperimentBlocked` and ALT count flags, single actual `offerAttempts=1`. All source/strategy/trade/settlement authority remains false and `tradeOutcome=UNKNOWN`.

**Threat model:** this only catches *client-observed* changes between polls or a future trusted-to-fail-closed client callback; changes entirely between polls with no event observed remain undetectable. LastOffer/UpdateTrade still cannot be promoted to a server-authenticated per-trade revision. This probe does NOT itself solve general multi-item rebalancing and does not authorize deployment.

### Abort / test discipline

Fresh original MM2 main iPad Delta job, consenting ALT `venossgaming90190` already present and able to offer one cheap expendable item, NO other pdiddler scripts. The GUI uses original collision-safe Stage100 overlay and STOP/COPY. If shadow prep is BLOCKED, screen panel overlaps controls, wrong partner or any unexpected outcome, STOP / COPY, no retry in same server. Return ONE new JSON; do not collect item names or account IDs. Avoid repeating closed Stage119, PR218 and PR237 basic tests merely for a progress metric.

**Release:** no native device instructions before exact-head Python/native Lune mock and all relevant workflow runs pass. The PR remains DRAFT/UNMERGED, and the separate P1 research PR236 remains blocked by market source rights/freshness independently. No outside provider contact.
