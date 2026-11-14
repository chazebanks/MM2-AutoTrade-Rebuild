# System 2 strategy-source semantics — independent market research audit (Nov 13, 2026)

## Prerequisites inspected
- All draft System2 research PRs #250→#259 (unmerged), `pdiddler/START_HERE.md`, `pdiddler/strategy/growth_policy.json` (no loss deployment/risk budget authorized), `pdiddler/intelligence_lab/STAGE121_SOURCE_TO_STRATEGY_HANDOFF.md`, Stage120 corrected physical slot guard, and Parts 3–5 current source + tests.
- Current canonical operator research snapshot is Nov13 calculator export (189 rows, SHA256 `bb91b545637a0fe8d7dcceebef9070ee9a76210015bdc1737fd78f068acaeb4f`), source `publisherVersion:null`, not a live authenticated publisher market feed. Raw JSON stays private.
- The data is user-collected community **Supreme Values** reference, not a creator-endorsed/official Roblox MM2 price guarantee; Supreme's own FAQ says there is no developer-authorized official MM2 list. Cite: https://supremevalues.com/faq

## Independent primary-source research
1. **Supreme calculator documentation** https://supremevalues.com/mm2/calculator
    - Explicitly: calculator trade breakdown Demand and Stability are **listed-value-weighted** across each side's items. A previous Part3 formula was **copy-count-weighted**, which incorrectly overweights low-value pieces.
    - Explicitly: stacking **5 or more of a single item with value above 1** yields a warning, because large stacks need not trade at simple integer multiples of their base value. Previous Part3 warning was only a generic `totalCopies>4` across unrelated items; thus it conflated physical-slot distinction with 5+ same-item nonlinear price uncertainty.
    - Four physical slots are tested in original Stage120, but quantity>4 and slots>4 are NOT equivalent. Stable listed prices are still not verified partner acceptance.
2. **Supreme official Use Guide** https://supremevalues.com/use
    - Value is **base value**, ranges are likely realized **intervals**, demand is an ordinal wanted signal, and price can depend on rarity, stability and retradability. 'Doing Well', 'Underpaid For', and 'Fluctuating' differ; prior audit PR259 corrected these categories.
    - `Flippability` is a separate labeled extra feature only visible for some items, not in the 189-record operator capture. **Do not fabricate it** or infer it from demand score alone.
3. **Independent third-party methodological cross-check** https://mm2index.com/methodology
    - Their self-described barter model parses **public trade posts** into hypothetical exchange equations and rejects vague listings. These posts are not individually authenticated **completed MM2 server settlements**. Any count of 'trades analysed' or 'offers posted' is at best an interest/quote proxy, NOT genuine fill-rate/realized liquidity proof. Never train acceptance rates from that alone.
4. **Current value lists may differ** (e.g. independent MM2Values or MM2Index); no consensus numeric price should silently replace the exact pinned Supreme reference. Differences are research-only source disagreements until separately authenticated, never a live-price override.

## Corrected implementation (research-only)
- `pdiddler/system2/trade_scenario_lab.py`: `demandValueWeightedMean = Σ(demand×listedValue×quantity) / Σ(listedValue×quantity)`; no empty-side division error. Additional `publisherStackPricingUncertainKeys` detects quantities >=5 for any **one same item worth >1**. `listedDeltaReliableForNegotiation=false` and `PUBLISHER_STACK_PRICE_NONLINEAR_UNVERIFIED` warning prevent misleading confident profit presentation. Listed-value arithmetic is preserved and explicitly NOT a realized trade price.
- `pdiddler/system2/attractiveness_evidence_lab.py`: value-weighted demand output, and any nonlinear-stack alternative gets status `PAPER_STACK_VALUE_UNCERTAIN`, documented warning, and **is excluded from normal attention ordering**. A large paper gain can never outrank a sounder path just because it includes stacked high-price items. No acceptance probability invented.
- `pdiddler/system2/multitrade_growth_replay.py`: propagates any 5+ same-item stack uncertainty through all hypothetical steps. Such a path is `OFFLINE_GROWTH_PATH_STACK_UNCERTAIN` and `growthPaperArithmeticReliableForNegotiation=false`. This **does not reject trade simulation**, just rejects a false claim that numeric listed gains are a reliable tradable growth path.
- New tests: Part3 +4 (value-weighted demand example +5/4 boundary and value1 threshold), Part4 +2 (stack profit excluded, four allowed), Part5 +2 (many copies spread across two 4-stacks vs one 20-stack). Focused full source-bound expected 230 tests (prior 222 +8). Review exact CI before claiming pass.

## Open gates — NOT solved here
- `pdiddler/strategy/growth_policy.json` risk budget remains all NULL and unapproved, all live trades + final Accept disabled.
- Real client identity, exact job/lease and session: not proven for this System2 pipeline. Source edition independently archived/authenticated through Stage111 not yet re-bound to Nov13 original operator capture.
- Learned attractiveness needs **actual observed partner declines/accepted/settled trades**, independent price/quality effects, and valid denominators. Posted offers or barter-post equations are not completed-trade acceptance observations.
- Original PR106 planner's four **total copies** limitation is not fixed by simulated support for stacked quantities.
- Parts4+5 still **do not form a genuine joint search/ranking optimizer**. That is a future distinct stage, after source and risk/evidence contracts.
- Original all-offer/accept/Discord/strategy-learning authority flags remain false; no production P3/P4/Delta edits, no hidden runtime changes.

**Status:** source-derived correction implementation staged on draft PR #260; no claim of CI passing until exact-head checks are complete.
