# Gingerscope Intelligence — Stage 7: Bounded Seller-Side Offer Research

**Status:** offline, side-effect-free Python laboratory. **Not an auto-trader; no live transaction authority.** Stacks on the read-only Stage 6 opponent-observation bridge.

## Why this stage exists

Stage 4 finds value-competitive and four-copy progression packages. Stage 5 studies inventory growth. Stage 6 supplies anonymized *cached* opponent holdings, **without proof of when each opponent was last scanned**. None of those proves which package an actual holder prefers or will accept. The current live V15.8 trading engine is not modified.

Supreme's own [Use Guide](https://www.supremevalues.com/use) distinguishes base value, demand, stability and rarity, and its [trade calculator](https://www.supremevalues.com/mm2/calculator) presents value-weighted demand/stability and warns that stacks do not always trade at simple multiples. We lack matched outcome data and source rarity in our frozen catalogue; no artificial acceptance probability, liquidity score, or cardinal probability-weighted utility is invented.

## Implementation

`negotiation_research.py` exposes `study_counteroffers(own, opponent, receive, catalog, now, ...)`. It enumerates **all 1–4 physical-copy outgoing packages** from catalog-verified exact checker IDs, subject to a finite search budget that **errors on exhaustion**. It refuses unowned requested quantities, wrong identities, stale source data, unknown or untradable items, and quotes that break four physical-copy limits.

The stage offers **four independent review lists** (no automatic single best choice):

1. `value_matched`: minimum absolute base-value gap, then qualitative cautions, then fewer copies.
2. `bounded_concessions`: seller-favorable nominal overpays, only when source quality and our four-copy progression justify studying a cost.
3. `four_copy_growth`: highest conservative four-copy purchasing-power gain, clearly distinguishing nominal losses.
4. `accumulating`: positive listed-value gain; *not* treated as evidence of counterparty acceptance.

The review includes `seller_surplus` (our offered base value minus requested base value), source-ordinal demand-distribution relation for the seller's hypothetical exchange, seller's stability-share change, copy count, our wealth delta, our four-copy delta, and explicit warnings. Multiple lower-demand or fluctuating offered weapons are flagged rather than given a made-up desirability score. Results are `offline-human-review-only` with `native_ready=false` permanently.

### Nominal-loss rules (experimental, adjustable)

A nominal loss is shown only if:
- all requested items have a **verified price**, **source demand >= 2** and **stable / doing_well / overpaid** status;
- our conservative **four-copy purchasing power increases** strictly;
- the concession is at most `min(5% of the requested listed value, 20 value units)` by default;
- all ownership, market-expiry, distinct item, and 1–4 physical-copy checks pass.

The 5%, 20 and minimum-90%-coverage defaults are **research thresholds**, not community-derived success rates, trading requirements, or permission to auto-offer. Displaying a seller-favorable nominal overpay does **not** imply the other player prefers our lower-demand bundle.

For a hypothetical Harvester (250) target, the default maximum nominal loss is 12.50. Example four-copy packages include 233 (we gain 17), 251 (we lose 1), or 258 (we lose 8), depending on inventory. A 270-value two-item package is outside the default study cap. Results remain hypothetical even though a cached opponent was observed holding a Harvester.

## Tests and local replay

```sh
cd pdiddler/intelligence_lab
python -m unittest discover -q
```

Stage 7 adds **19 contract tests** to the inherited 103: bounded nominal loss, four-copy progression conditions, demand/stability gates, value/coverage caps, source expiry, strict quantity and checker IDs, no silent budget truncation, deterministic order, no mutable inputs, and seeded scenario fuzzing. Total: **122 tests** in the local laboratory.

Tests use a **synthetic portfolio, not the user's full inventory**; user identity, full raw inventory JSON, opponent fingerprint and session/job IDs are **not committed**. User-provided observations are used only for local research and explanatory examples.

## Release blockers

- **No authoritative opponent inventory age.** `snapshotAtEpoch` is export time, NOT per-player successful scan time; cached holdings may already have changed.
- **No verified trade results or preference evidence.** Neither ordinal demand nor value surplus predicts acceptance.
- Supreme source snapshot expires **2026-11-05T21:55:32Z**. Do not reuse beyond expiry or extend its timestamp without a new verified source snapshot.
- Source rarity, item ranges, non-high-tier collectibles and stack-slot mechanics are not fully modeled. A source-verified trade is still not equivalent to a completed trade.
- Existing Part 4, P1–P5, Delta loader, bot avoidance, acceptance, hopping and Discord paths are **unchanged**. No merger/autoexecution without a separate native adapter and regression review.