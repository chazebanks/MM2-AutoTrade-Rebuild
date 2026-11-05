# Stage 17 — Bilateral offer review (research-only)

**Status: draft, offline. Not deployed. No item placement, withdrawal, automated negotiation, Accept, trade-completion claim, or Discord reporting.** The current Pdiddler loader and old trading controller are unchanged.

## Why this stage exists

Stage 7's Python research studies counterparty-side value coverage, demand, stability, potential value concessions, and four-copy progression. Stage 16's pure Lua review independently evaluates risk and nominal/conservative gain **for us**. Neither module currently connects both views for the *same proposed exchange*. The Stage 16 candidate list also ranks our apparent gains without requiring a plausible reason for the opposite player to trade.

Stage 17 adds a **pure Lua wrapper**, `p4_dual_perspective.lua`, around Stage 16. This module does not replace Stage 7's bounded search, Stage 16's evaluator, or Stages 8–15 safety logic. It can review the same `context` and `proposal` objects accepted by Stage 16; a future adapter must translate Stage 7 candidates and verify their original provenance before use.

## Computation (for the same candidate)

1. Run Stage 16 on our giving/receiving bundles, preserving all source, identity, ownership, copy, and range checks.
2. Reverse **both** inventories and bundles and run Stage 16 again from the counterparty's perspective. Do not equate our higher demand acquisition with a demand improvement for the other player.
3. Report their listed-value surplus, exact-bundle coverage in basis points (10,000 = 100%), conservative price-range delta when known, ordinal demand relation, optional source-verified flippability relation, stability exposure, and number of copies and visible item types received.
4. Place results in review groups, never an auto-selected best offer:
   - `VALUE_CASE`: counterparty receives equal or greater **listed** value. It might still be unattractive due to weak demand, stacks, stability, or preferences.
   - `QUALITY_TRADEOFF`: counterparty forfeits listed value but gains on at least one verified ordinal quality dimension without known deterioration in another. An unknown resale proxy stays unknown. This is a hypothesis, **not** proof of willingness.
   - `UNPROVEN_SELLER_CASE`: counterparty gives more value with no nonconflicting quality reason demonstrated by the available source.
   - `BLOCKED`: Stage 16 contract fails; do not analyze unverified quantities, ID mappings, or stale market data as if confirmed.

The output deliberately has no acceptance probability, inferred human preference, conversion rate, realized spread, or liquidity measurement. Seller's exchanged assets are compared, **not** their complete inventory objectives, which remain unknown. No unilateral price-margin, coverage, or nominal-loss threshold is adopted as a policy. Any nominal loss for us is explicitly flagged and still requires separate strategy justification.

### Example (synthetic only)

Our item value 10,000 cents; opponent's item value 12,000 cents. Our nominal gain = 2,000 cents, seller's nominal shortfall = 2,000 cents, seller's listed-value coverage = 8,333 bps (83.33%). If the item we offer also has weaker demand/flippability, the result is `UNPROVEN_SELLER_CASE` even if Stage 16 classified the deal favorably **for us**. No acceptance inference is made.

## Testing

`lua5.4 pdiddler/new_part4/tests/test_p4_dual_perspective.lua pdiddler/new_part4`

Synthetic cases cover reversed demand, seller value/quality tradeoffs, our losses, stacked copy vs slot counts, exact source expiry, unknown ranges, missing resale evidence, ownership and ID ambiguity, non-mutation, malformed candidate arrays, finite review budgets, and forbidden native effects. CI also runs all inherited Stages 8–16 tests. Only claim a passing CI suite after checking its actual result.

## Release blockers and next separate issue

- Stage 7 remains a Python research producer and is **not** automatically bridged to this Lua module.
- Stage 16 source validity is only as credible as the caller-supplied evidence. The dated research market snapshot has expired and must not be silently refreshed.
- Cached opponent inventory lacks verifiable per-player scan timestamps and explicit counterparty preferences.
- Four physical **copies** (not just four visible trade slots) remain the conservative research limit, despite native proof that multiple copies can stack in one slot.
- The Godly/Vintage Laser guard is specific; other cross-tier name collisions may exist.
- No end-to-end native trade selection, real item placement/removal, safety verification, automatic acceptance, or confirmed completion exists for the replacement Part 4.

**Next focused task:** demonstrate a provenance-preserving adapter for generated candidates before considering any live strategy decisions. Do not turn this classification into an execution command.
