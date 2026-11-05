# Stage 5 — Gingerscope Inventory Growth Planner (OFFLINE ONLY)

**Scope:** research-only Python. This stacked development branch does **not** change the Delta loader, Roblox Lua/Luau runtime, live MM2 trade GUI, trading/acceptance policy, bot detector, server hopping, native verification, Discord/webhook, or Supreme snapshot expiration. **Do not auto-execute or merge the lab into production.**

## Why Stage 5 exists

Stage 4 evaluated a *single requested bundle* using a value-competitive and four-copy improvement ranking. That is not sufficient for the user's goal: accumulating a useful inventory capable of eventually trading for Gingerscope. A big listed profit on undesirable items may impair future trading; a valuable weapon split into many small items can reduce four-copy purchasing power. Also, Stage 4's closeness-first shortlist could hide profitable offers.

Stage 5 therefore adds:

- `offer_ranker.py`: a third `accumulation_offers` lane ranking **listed-value growth** within the explicitly configured review-coverage gate. The existing closeness and progression lanes, trade safety constraints and Stage 4 APIs remain intact.
- `growth_planner.py`: accepts priced, exact Supreme `(page, checkerId)` holdings for both sides and considers **verified hypothetical incoming targets** one at a time. Optional pair-bundle discovery or explicit 1–4-copy target bundles are supported. It composes existing Stage 4 rankings, then uses the unchanged Stage 1 evaluator for post-trade portfolio effects.
- Multiple independent review lanes: `wealth_candidates`, `four_copy_candidates`, `quality_candidates` and `caution_candidates`. None is a single "best trade" decision or an acceptance prediction.
- Visible category labels (`upgrade`, `downgrade`, `accumulate`, `quality-rotation`, `tradeoff`, `neutral`), with counts and value effects. Categories are descriptive, not automatic trade instructions.
- Flags for declining four-copy power, a worsening/mixed Supreme demand profile, instability, low-demand incoming weapons, declining stable-value share and extra copies from a downgrade. **Supreme demand is ordinal, not calibrated liquidity or willingness to accept.**
- Return fields for unpriced owned/partner copies and an explicit no-candidate reason. Complete inventory value is never claimed when lower tiers are unpriced.
- Hard controls: no nominal losses by default, no overlapping items exchanged both ways, no nonexistent inventory quantities, no stale/unknown market values, 1–4 physical weapon copies per side, bounded search with fail-closed errors rather than silent truncation. Stack mechanics remain unproven. Bounded result lists are *shortlists*, not exhaustive global optimization.

The 90% list-value coverage default is a **display/research heuristic**, not an acceptable-trade guarantee, probability model, minimum profit or proof of any player preference. Coverage and search budgets are configurable. Automatic value-losing concessions and real-world acceptance modeling are **not** implemented.

## Test results

```sh
cd pdiddler/intelligence_lab
python -m unittest discover -q
```

At time of implementation: **90/90 Python unit tests pass**, including the inherited tests and Stage 5's deterministic examples and randomized invariants. The tests use *synthetic opponent holdings*. They don't verify live trade control or consent.

A **private offline replay** of the user's confirmed 14 high-tier rows yields **4,548 nominal listed value** and **3,870 conservative four-copy capacity** under the November 4 Supreme snapshot. A **hypothetical, unobserved** counterparty-owned Chroma Mortal (1,600) produces eligible sample upgrade quotes. One example, four offered copies totaling 1,440, would add +160 listed value and +300 four-copy capacity. This is **not a witnessed trade, offer acceptance, or production recommendation**.

The user's full native inventory JSON, fingerprint, ID lists, and screenshots are **not committed** to this repository or these Stage 5 tests.

## Known boundaries / work remaining

1. The source-pinned November 4 Supreme snapshot expires **2026-11-05 21:55:32 UTC**. A genuinely new price publication requires an independently verified refresh; never extend the existing expiry without new evidence.
2. The laboratory does not yet receive current player-specific, same-session authoritative opponent inventories (`jobId`, `playerUserId`, `captured_at`, trade-window offer identity). Stage 2's runtime authority gate is not satisfied by the saved scanner export.
3. No validated trade outcome histories, acceptance-rate calibration, player preference data, or repeatable upgrade/downgrade fill evidence exist. A numerical profit is not evidence of a realistic offer.
4. The 90% research/display gate and bounded shortlist may exclude potential unusual trades. No Pareto-optimality guarantee is claimed.
5. An economic policy replacement in Luau requires a separately reviewed adapter and integration tests against the existing transaction controller. Do not activate a second competing strategy engine or remove production rules until a replacement has been proven.
