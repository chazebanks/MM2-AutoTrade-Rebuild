# System2 research checkpoint — explicit counterparty limited shortlist candidate enumeration

## Why this stage exists
Latest user direction emphasizes **real strategic decisions, attractiveness, eventual Gingerscope acquisition**, not repeated 189-value parsing or unbounded toy outcomes. Previous S2.3/4/5 can *score or replay a hypothesized trade*, but can invent any arbitrarily favorable incoming item without evidence that a counterparty has it.

Original historical PR106 `future_portfolio_planner.py` at commit `6ed48e084bd58fab38e3bf061ac36fb295ecf103` / blob `78948cdacd2a760db5b888fce242d598fc6f14b6` was genuinely inspected. It:
- Enumerates at most five distinct types/side and **four total copies**, two copies/type, not four physical slots with arbitrary stacks;
- Requires input `identityLinkEvidence=INDEPENDENT_EXACT` and **numeric liquidity (1–10)**;
- Ranks by paper profit, demand, **caller-supplied numerical liquidity** and concentration; no genuine observed fill rates are present in the Nov13 browser JSON;
- Is explicitly synthetic/offline and does not prove actual counterpart account ownership/consent/settlement.
**Conclusion:** A direct adapter feeding fake liquidity or claiming current checker game identities would be unsafe and violate the original research contracts. Do not fabricate those fields.

## New separate bounded pre-planner experiment
- `pdiddler/system2/counterparty_candidate_explorer.py`: pure research function `explore(mapped, shadow, request, evaluated_at_utc=...)` with **explicit own shortlist AND explicit counterparty shortlist**. Counterparty must be `SYNTHETIC_UNVERIFIED_COUNTERPARTY` with `ownershipProof=UNKNOWN`. No outcome is ever `counterpartyOwnsAnyItemProven=true`.
- Max four distinct weapon keys in each shortlist (caller must choose, never silently truncate huge inventories), deterministic per-item quantity variants `1,2,whole stack` when held, max four **physical slots** per side, no more than 100000 comparison pairs. Counterpart key must exist in prior pinned research set, Gingerscope outgoing never permitted.
- Enforces no unapproved listed-value loss, rejects receiving an item not explicitly in the opponent shortlist, excludes any >=5-stack of an item worth >1 because Supreme calculator says base prices need not scale linearly. Unknown items/invalid quantities or fake server-proof claims block.
- Only generates **synthetic research previews**, capped (max 20) in deterministic **non-ranked** order. Each positive listed gain notes counterparty would be *giving more listed value*, whose willingness is UNPROVEN, not a probable accept. Actual partner interest/liquidity/time-to-trade stay UNKNOWN.
- Integrated with `pdiddler/system2/sealed_decision_source.py` via `COUNTERPARTY_OPTIONS` mode, which reads original private operator bytes and pinned original Stage83 every time, hashes all 189 mapped records against immutable seal before hypothetically generating candidates. Direct `explore` still research-only and accepts untrusted input objects; **use sealed mode for actual archived price integrity tests**.
- 23 synthetic/negative tests of own and counterpart stock, Gingerscope protection, fake source/proof, stacked copy warning, listing-only negative gain, supplied shortlist limits, stale inventory, physical 4-slot counts; +2 sealed gateway integration tests. Dedicated original source-bound CI includes **275 tests** (250 inherited +25 new). Verify exact run before claiming passed.

## Research sources and limitations
- Supreme calculator https://supremevalues.com/mm2/calculator (value-weighted demand, 5+ identical stack warnings, and four physical slots in calculator).
- Supreme usage guide https://supremevalues.com/use (value, demand, rarity, range, stability, flippability distinct).
- MM2Index methodology https://mm2index.com/methodology (its named "trade" dataset comes from public **posts** parsed as offer equations, not independently authenticated game **settlements**; do not fabricate acceptance or realized liquidity).
- Original `pdiddler/strategy/growth_policy.json`: controlled loss, automatic offers, automatic final accept **not authorized**. The 189 Nov13 snapshot has `publisherVersion:null` and lacks native server item identity evidence.
- **This is not a global optimal strategy planner, not native partner inventory discovery, not empirical attractiveness, not unattended MM2 trading.** Pre-selection of actual own and opponent shortlist and true offer attractiveness are distinct future issues. Old original PR106 remains frozen, reused as reference and source-pinned inherited Stage120 regressions rather than invoked with invented liquidity.

## Next distinct substage
Offline **multi-step option search** based on *explicit independent partner scope for each step* and fully bounded branch/fallback planning, with evidence risk and **no accepted-trade probability**. Need source freshness/client witness and actual partner inventory evidence before any live proposals. Keep all original P3/P4/Delta untouched. Research PR stack remains drafts, not main.
