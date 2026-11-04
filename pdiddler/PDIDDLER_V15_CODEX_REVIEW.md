# Codex handoff: V15 opponent-added negotiation (review REQUIRED before claiming live success)

## User-approved policy, exact meaning
- Objective: more frequent **smaller** profitable trades rather than aggressive maximum overpay.
- Strict immutable Supreme +15 *per completed trade* remains the hard floor.
- An *upward* offer change may be **considered only** if the other side's **net added value** since our last successfully verified/committed quote-increase anchor reaches **max(10 Supreme, 5% of that anchor value)**.
- Cumulative increments count: 200→205 is not eligible; 200→210 is eligible. A 200→200 same-value swap is ineligible. Remove/re-add cannot consume the same credited increase twice.
- The increase may use **at most 50%** of eligible newly added value, with a conservative **25% target**, subject to the original early allowance/trade-wide spending ledger, actual owned denominational combinations, accepted state, canonical no-matching-items rule, and physical offer readback. A threshold crossing **never forces** a giveaway.
- **Time passing by itself is not a reason to increase our offer.** The prior late +9-second increase path is deliberately replaced by waiting/declining with no candidate plans; existing MM2 accept/readiness gate and final wait remain.
- Removals or variants swapping may still require immediate **safety rebalancing downward or decline**. Do not block risk/correctness reactions just because the generosity threshold wasn't met.
- One decision per stable offer generation, one mutating owner, no unlimited retries; watermark advances only on actual P4 verified successful concession.
- Preserve V14 readiness, Tablet/friend clicks, bot classifier, player scan, outgoing request 15s timeout, P5 45s hop, four-copy limit, original trade ledger, versioned Supreme price expiry, native completion gates, and Discord credentials handling.
- V14 and previous draft branches remain unchanged. V15 is a separate immutable Delta entry.
- **Native automatic Accept/Confirm and completed-trade webhook remain OFF.** Do not enable or claim them without actual MM2/Delta native transaction evidence; their existing generic infrastructure is still preserved.

## Files / ownership
- `pdiddler4_early_counter_policy_v5_OPPONENT_ADDED.lua`: pure threshold, net addition, max spend and plan preference; no Roblox actions.
- `pdiddler4_balancer_SUPREME_v9_OPPONENT_ADDED.lua`: last-verified opponent-value anchor, P4 verified-commit watermark update, no autonomous late-value step.
- `pdiddler_FASTGATE_V6_INTEGRATED_TEST_v15_OPPONENT_ADDED.lua`: same V14 dependencies, with P4/early only replaced and a new integration key.
- `pdiddler_V15_TELEPORT_AUTOBOOT_v1.lua`: immutable single-job reentry; guard against active V14.
- `tests/v15_opponent_addition_test.lua`: pure policy behavioral regressions.
- `tests/v15_source_guard.py`: source-level invariants.
- `.github/workflows/pdiddler-v15-opponent-negotiation.yml`: original V14 regression suite + new v15 tests and compilation.

## Codex review / tests (do not rubber-stamp)

1. **Review the actual P4 call sequence**, not only pure policy: initial speculative opener, opponent-first start, initial verified safe quote, P4 anchor initialization, early quote reservation, exact post-mutation offer readback, ledger confirmation and watermark update. Especially check if the initial opener/first safe quote can miss setting the anchor or if recovery incorrectly sets it.
2. **Threshold cases:** 200→205→210; 200→200 swap including named variants; 200→190→200; 200→210 (reward)→200→210 (no second reward)→220 (eligible). 1,000→1,049 (not eligible),→1,050 (eligible), threshold rounding.
3. **Negotiate while opponent is active:** their stable positive addition during the MM2 6s cooldown, an edit while our physical replacement is yielding, back-to-back add/remove, unknown/stale price/quantity, no eligible denominator plan, mirrored item, and a partner leaving mid-mutation. Ensure no upward change on elapsed time, no unsafe quote, no double-concession.
4. **Willingness vs safety:** compare several safe item combinations and demand/stability ties, especially sparse inventories where a 25% lift is impossible. Should *consider* higher value after net additions, but skip when no safe combination exists.
5. **Accepted state:** while our side Accepted or ambiguous, no offer changes; changed opponent side after acceptance must invalidate approval. Completion/Discord must not be inferred from GUI closure.
6. **Legacy preservation:** all V14 baseline tests; native readiness large-tree/visible overlays; exact physical Tablet and Trade taps; bot/real evidence, 45s hopping, 15s request; stale Supreme refuses trading; no secret URL in queue.
7. **Live Delta manual observation** on low-value items: screenshot with `P4 EARLY COUNTER PROPOSED` only after a threshold-crossing positive delta, inspect final offered actual items; then verify no time-triggered sweeten and no second increase for same net value. Simulate removal, re-add, same-value swap, cancel, UI recreation and hop.
8. **Review known adjacent issue WITHOUT silently patching in this change:** P4 still immediately declines after a technically stable no-safe-plan offer; `NoPlanNegotiationGrace` was declared but not used. Flag as separate task, do not conflate with V15.
9. **Quantify real results** before calling strategy better: accepted requests, verified completed value gained per whole session-hour, failed/no-action attempts, mean time, net concessions, inventory exit quality. A +15 on paper is not a proven completed trade.
10. **Explicit status to user:** distinguish compile + fixtures versus actual iPad execution. Document any failed tests and exact corrected root cause. Do not claim final native acceptance or Discord is on.

## Delivery / no pretense
- This change has static source checks and new tests authored, but do not claim those tests or the real iPad flow passed until GitHub Actions / manual recordings prove it.
- Never use a moving `main` or branch URL for Delta. Test the versioned immutable wrapper in a clean MM2 JobId with old Auto Execute entries disabled.
- The Supreme snapshot's original hard expiry remains **2026-11-04 21:42:28 UTC**. Do not extend or bypass it; authorized verified refresh is a separate change.
