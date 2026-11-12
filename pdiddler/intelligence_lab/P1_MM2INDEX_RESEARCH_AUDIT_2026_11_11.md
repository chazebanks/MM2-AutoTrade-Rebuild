# P1 independent MM2 Index dataset audit — 2026-11-11

**Status: VALIDATED PUBLIC SCHEMA, FAILED FRESHNESS; RESEARCH ONLY.** This is NOT a replacement Supreme snapshot, item-ID crosswalk, approved live price list, or measured settlement/liquidity dataset. Original P1 first-party Supreme task remains blocked on source rights/access.

## Public source and license

- Publisher's dataset: [MM2 Index JSON](https://mm2index.com/api/values.json); [methodology](https://mm2index.com/methodology); [About](https://mm2index.com/about). Inspecting the endpoint on Nov 11, 2026 via two independent reading surfaces (direct web JSON and a third-party Firecrawl fetch) showed `200 application/json` and the SAME publisher `meta.updated=2026-10-12T00:42:14.608268+00:00`. This is **not** a 2026-11-11 publisher revision. The third-party fetch is not a first-party response-byte SHA archival proof.
- Publisher declares `meta.license="CC BY 4.0 — attribution to mm2index.com appreciated"`. The [actual license](https://creativecommons.org/licenses/by/4.0/) requires appropriate credit, license link and indication of changes, despite "appreciated" in the publisher's text. Provider's claimed ability to grant rights to every underlying item name/image, and all other relevant permissions, have not been independently proven. Do not import images (different CC BY-SA claim) or `usd_resale` into market value decisions.
- Explicit attribution if reusing this dataset: **"Values data from MM2 Index (https://mm2index.com), licensed CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/). Changes: [state any modifications]. Not affiliated with or endorsed by MM2 Index."**
- Provider's own [method](https://mm2index.com/methodology) turns **public player trade posts and quoted desired exchanges** into equations, filters duplicates, uses an anchor, then independently compares self-reported quote signals / real-money resale ranks. The stated 24,401 equations and an individual item's observations are **not proven in-game server-completed exchanges**, acceptance rates, time-to-retrade or verified seller appeal. Provider discloses an association with an MM2 item-selling site. The attribution, method and conflicts travel with any research data.

## Actual JSON audit (observed November 11)

| Published category (exact provider `tier`) | Count |
|---|---:|
| Ancient (individual) | 13 |
| Godly (individual) | 76 |
| Chroma (39 total; 4 sets excluded) | 35 individual |
| **Plausible target-tier individual weapons, based on publisher categories** | **124** |
| Other published: sets | 39 ordinary `Set` entries plus 4 Chroma sets in the Chroma category |
| Other published: Unranked | 19; **DO NOT auto-upcast to Godly or Ancient** |
| Other published: Unique / Legendary / Rare / Uncommon | 1 / 2 / 3 / 1 |
| All published rows | 193 |
| Withheld rows (unpublished, category unknown) | 421 |
| Total item universe according to provider | 614 |

The **193 / 614 = 31.43%** number is the provider's *all-item publishing rate*, **not** the fraction of all eligible Godly/Ancient/Chroma weapons covered: the 421 withheld rows have no category breakdown in this published JSON. Four excluded Chroma sets were `chroma:sunrise_set`, `chroma:blizzard_set`, `chroma:sweet_set`, `chroma:beachy_set`. A set value is **not** one individual outgoing weapon slot.

Among the **124** listed individual potential target-tier weapons, confidence labels are:
- Ancient: 12 high, 1 medium
- Godly: 52 high, 24 medium
- Chroma: 20 high, 15 medium

Total eligible label distribution = **84 high / 40 medium**. Labels are publisher's own confidence in its price estimate, not quantified probabilities of successful trading. Keys were unique (193 of 193), slugs unique (193 of 193), positive numeric values in all published rows, and Chroma tier flags internally consistent in this retrieved snapshot. **These checks do not prove accurate MM2 internal raw IDs or completeness.**

**Gingerscope research row (Oct 12):** `key=gingerscope`, `tier=Ancient`, `value=15475`, `confidence=high`, `observations=862`, `derivation=chain+quote`. Its value is not a current Supreme price and observations are not server settlement evidence. Never auto-offer Gingerscope outbound. Treat "Chroma" as a separate provider tier; **this JSON alone does not prove the base Ancient-vs-Godly taxonomy or in-game raw weapon key**. Example of dangerous uncertainty: `Unranked` contains keys such as `everset`; do not infer that this must be Godly/Ancient based on the name or value.

**Freshness:** publisher age on November 11 is about **30.97 days**, exceeding a conservative **7-day OFFLINE RESEARCH SCREEN**. The seven-day cap is a test screening threshold, **not** an approved live-quote refresh interval. Re-fetching the same Oct 12 data cannot change its underlying publication date or unblock the market.

## Code/tests and limits

- Pure, local-file-only parser: `pdiddler/ci/p1_mm2index_research_audit.py` with `audit(payload, observed_utc=...)`. It **never performs HTTP** or updates production prices and always denies all source, trading, final Accept, settlement, webhook, reporting and learning authority even with a hypothetical fresh dataset.
- Offline Python tests: `pdiddler/ci/test_p1_mm2index_research_audit.py` covering 15 cases: expired/future/source clocks, missing permissions/license, schema and counts, mixed tiers, Chroma sets, duplicate keys/slugs, missing target, wrong target tier, invalid values/NaN, observation claims, unknown rank and no-network CI. Tests use **synthetic fixtures**, not a fabricated claim of server settlement or a proof that Python fetched the live dataset.
- Source rights remain `BLOCKED` in `pdiddler/ci/p1_source_rights_gate.py`. Test and CI success do not promote a market quote. No in-repo live API polling, new dataset snapshot, trader changes, strategy integration, or P2 authorization are made.

## The next ONE P1 criterion

Find a **genuinely recent, independently usable provider revision with transparent reuse conditions**, then evaluate offline the actual data against current Roblox item identity evidence and separately document value-model differences (not a direct Supreme numeric merge). Alternatively, obtain permission/approved first-party Supreme delivery. Until then keep source and all live authorities false, PR draft, P2 blocked.
