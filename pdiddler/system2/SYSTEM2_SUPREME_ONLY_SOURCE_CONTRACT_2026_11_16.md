# Gingerscope System 2 — sole market valuation source: Supreme Values

**Operator decision, November 16, 2026. Supersedes ALL prior hybrid/dual-price strategy recommendations.** Applies to the new System 2 growth/planning code and any future native C3/C4/C9 integration. This does NOT authorize autonomous trading, live Accept, loss budget, or a new iPad run.

## Single source

1. **All listed-value math must come from Supreme Values exclusively:** what we give, what we receive, portfolio concentration, hypothetical profitability, upgrading/downgrading, Gingerscope 16,000 snapshot target, quality weighting, paper-loss research and four-slot/stack analysis.
2. Only **Supreme's own published** demand and stability labels may influence descriptive research warnings. A descriptive label is not measured future partner demand, trade fill, actual liquidity, or a verified retrade.
3. **No MM2Values importer, feed, pricing fallback, baseline, max/min against another list, hybrid blend, or cross-list price-protection formula.** If Supreme data or one required price is missing/stale/ambiguous, fail closed. A player mentioning another list in chat cannot silently change the sole canonical valuation.
4. Item identity is independent of the public listing: game-client raw item-instance authenticity/variant/quantity and source-to-key mapping remain a separate protected dependency. Gingerscope must never be offered outbound.
5. Respect four physical slots, variable stacked quantities and unverified nonlinear copy pricing; do not infer final settlement or trade permission from research.

## What changed in this draft

- NEW dedicated source `pdiddler/system2/supreme_only_189_research_catalog.json`: **189 historical raw-key candidates with solely Supreme fields** (15 Ancient / 128 Godly / 46 Chroma). Created from actual publisher-origin Nov 16 capture, pinned Git blob, no mixed publisher columns. It is not a current game inventory or a live quote stream.
- NEW strategy evaluator `pdiddler/system2/supreme_only_strategy_research.py`, pinned only to that Supreme-only source: computes hypothetical outgoing/incoming value, after-inventory, demand, concentration, warnings; rejects another valueSource, any extra price fields, protected target outbound, missing keys, stale data, invalid items or stacks, and unauthorized losses. **Never executes an offer, Accept, completion webhook or strategy learning.**
- Retired from THIS development branch: the recent first-party MM2Values collector, source fixture, two-source join, historical dual-price reconciler and their focused CI tests/workflows. Their past source snapshots/results remain in earlier Git history and previous draft PRs **for audit only, not runtime**.
- Old v2.x `pdiddler/pdiddler4_market_v1.lua`, November 2 Hybrid Market-Aware Planner specification, and original `native_bilateral_attractiveness_shadow.lua` / `native_c9_growth_first_preview.lua` use dual-price fields. They are **LEGACY, NOT AUTHORIZED FOR THE NEW SUPREME-ONLY EXECUTION PATH**. Do not load or copy their source into the replacement planner. They remain untouched for historical regression provenance and are not proof the new strategy is wired to on-device MM2.
- Any next native C3/C4/C9 adapter must load only the Supreme-only schema and rerun native regression tests, including exact lease, revision, partner binding and source age. The existing immutable older Delta loaders MUST NOT be presented as new Supreme-only loaders.

## Strict research limitations

The current Supreme receipt was retrieved **2026-11-16 04:36:35.765 UTC**, publisher edition **2026-11-15 11:59:41 EST** via **Firecrawl mediated public HTTPS**, not signed/publisher-certified. A source capture expires six hours after its exact retrieval; do not restamp. It may be used at its true historical evaluation clock to verify code, NOT to claim fresh live prices after expiry. Later truly new captures need independent evidence and a new immutable pin.

`pdiddler/strategy/growth_policy.json` still explicitly has all numeric live loss budget limits null/unapproved. No prior percentage like 3% or old blanket +15 is an approved strategy rule.

**Completion condition for this issue:** exact-key and Supreme-only source gates tested offline with real source bytes, all inherited CI green; only then mark **Supreme-only research valuation implemented**. Live P3/P4 native integration and autonomous trading are distinctly NOT complete.
