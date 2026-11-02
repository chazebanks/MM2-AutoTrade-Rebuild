# MM2 AutoTrade v2.6 Market-Aware Planner — Design

**Date:** 2026-11-02

## Intent

Improve Part 4's trade-decision quality without destabilizing the proven v2.5 request, scanner, transaction, recovery, timing, and verification behavior.

The planner should judge not only paper value, but whether a trade leaves us with inventory that is easier or harder to retrade.

## Goals

- Keep the active scanner's canonical item identity and MM2Values value authoritative for item resolution.
- Use the complete 190-item market snapshot as a secondary market profile keyed by canonical `page:id`.
- Use Supreme as the primary market-context source for demand/status and as a cross-check for current market valuation.
- Detect material MM2Values/Supreme disagreement instead of averaging the two lists.
- Preserve hard protection against our overpay.
- Allow only small, controlled raw-value loss when consolidating into materially better market inventory.
- Require extra compensation when downgrading into weaker, lower-demand, unstable, or materially disputed inventory.
- Prefer the strategically better exit inventory when multiple safe plans have similar raw profit.
- Preserve v2.5 moderate-profit holds and EXTREME GUARD behavior.
- Keep FINAL ACCEPT disabled.

## Non-goals

- No live HTTP request inside an active trade.
- No second item-identity resolver.
- No changes to Parts 1-3.
- No changes to Part 4's transaction executor, remove/apply verification, recovery, timers, or session generation.
- No dynamic machine-learned prediction.
- No automatic averaging of value lists.
- No profile guess for an unknown item.

## Anti-goals

The redesign is a failure if it:
- makes a paper-profit trade safer-looking just because metadata is missing,
- gives away an opponent's moderate overpay unnecessarily,
- lets demand/status override raw-value safety,
- treats many weak pieces as automatically better because there are more items,
- lets low-value percentage disagreement dominate decisions when the absolute difference is trivial,
- causes executor/recovery regressions while changing planner logic.

## Approaches considered

### A. Supreme-first scoring

Use Supreme as the main trade value and treat MM2Values as a light sanity check.

**Rejected:** simple, but too dependent on a single list and would replace a scanner/value pipeline that is already proven.

### B. Strict conservative dual-source

For every item, value ours at the higher list value and theirs at the lower list value.

**Rejected as the default:** very safe, but too conservative for tiny low-tier disagreements and likely to reject many normal profitable trades.

### C. Hybrid market-aware planner — SELECTED

Keep MM2Values as the scanner's canonical baseline, use Supreme for demand/status and market context, and invoke conservative cross-source protection only when disagreement is materially significant.

This is the chosen design.

## Data model

The market snapshot remains separate from the scanner and is keyed only by the scanner's canonical `page:id`.

Each profile may contain:
- `mm2Value`
- `supremeValue`
- `demand`
- `stability`
- `disagreementPct`
- snapshot/source timestamps
- `profiled` / `verified`

The scanner remains authoritative for:
- exact identity
- canonical id
- page
- quantity
- baseline MM2Values value

Missing market metadata must be represented as unprofiled/unknown. It must never silently become Stable.

## Decision model

The planner should keep separate concepts instead of one opaque score.

For each side compute:
1. **Raw MM2 value** — scanner baseline.
2. **Cross-source safety value** — only when disagreement is materially significant.
3. **Demand/exit-quality signal** — based on Supreme demand.
4. **Stability/risk signal** — Stable / Doing Well / Overpaid For / Fluctuating / Underpaid For.
5. **Profile confidence** — whether the item has verified current metadata.

### Cross-source disagreement

Do not average MM2Values and Supreme.

A disagreement is only "material" when both:
- the percentage difference is meaningful, and
- the absolute value difference can materially affect the trade.

The exact thresholds are implementation parameters and must be pinned by offline tests before live use.

When disagreement is material:
- protect OUR item using the higher supported valuation,
- protect THEIR item using the lower supported valuation.

Tiny disagreements such as 5 vs 7 must not dominate a trade solely because the percentage is large.

### Profit floors

Existing v2.5 floors remain the starting hard minimums:
- Normal: `max(15, 3%)`
- Downgrade: `max(20, 6%)`
- Big downgrade: `max(30, 8%)`

The market-aware layer may increase the required premium for weak received inventory. It may not reduce these raw floors.

### Controlled quality upgrade

A quality-upgrade exception may allow at most the existing ~3% raw loss when:
- OUR side is consolidating more eligible copies into fewer received copies,
- the received inventory is materially better in demand/liquidity/stability,
- the received profile is verified,
- disagreement does not make the upgrade uncertain,
- the conservative safety calculation does not create an overpay,
- no profitable plan with comparable market quality exists.

Missing metadata cannot earn positive quality-upgrade credit.

### Downgrade quality

If we are giving one/fewer strong liquid pieces for more pieces, the required profit should increase when the received bundle is:
- lower demand,
- Underpaid For,
- Fluctuating / recently unstable,
- materially disputed across lists,
- mixed with weak exit-quality items.

Item count by itself is not a quality benefit.

### Candidate ranking

Among plans that pass hard safety:
1. prefer real profit over controlled quality-upgrade loss,
2. prefer better strategic exit quality when raw profit is similar,
3. otherwise prefer the highest safe OUR raw offer that preserves the required profit,
4. prefer fewer weaker/disputed pieces when equivalent,
5. never let quality ranking override a hard safety failure.

## v2.5 behavior that must remain unchanged

- initial offer is exactly one highest-value eligible own item,
- accepted-empty immediate decline,
- 15s pre-offer empty timeout,
- authoritative 60s Case 3 timer,
- opponent changes start a new planning generation,
- TX ABORT on opponent-offer mutation,
- bounded recovery after our partial mutation,
- exact quantity/signature verification,
- moderate profitable hold,
- EXTREME GUARD only on genuinely extreme one-sided profit,
- no duplicate final actions,
- FINAL ACCEPT disabled.

## Offline decision matrix

The new market-aware decision functions must be tested before any live Part 4 integration.

### Case 1 — Same raw value, different exit quality
OUR stable/liquid 100 vs THEIR weak/underpaid 100.
Expected: reject/underpay; equal raw value is not a strategic win.

### Case 2 — Controlled quality upgrade
OUR two weaker items totaling 100 vs THEIR one clearly stronger verified item at 98-100.
Expected: may pass only if raw loss is <=3%, market quality improvement is material, and disagreement risk is acceptable.

### Case 3 — Profitable downgrade into weak pieces
OUR stable 100 vs THEIR three weak/underpaid pieces totaling 130.
Expected: do not automatically accept +30; weak exit quality must raise the required premium enough to reject marginal junk downgrades.

### Case 4 — Material list disagreement
Use a real profile such as Emberscythe (MM2 300, Supreme 375).
Expected: OUR-side protection uses the higher supported value when material; THEIR-side credit uses the lower supported value.

### Case 5 — Falling / unstable event item
Trade into Ember-family Fluctuating inventory.
Expected: require more compensation than an equally valued Stable item.

### Case 6 — Moderate opponent overpay
OUR 230 vs THEIR 270, otherwise acceptable.
Expected: hold profit; do not "normalize" away a normal +40 win.

### Case 7 — Extreme opponent overpay
OUR 20 vs THEIR 105.
Expected: EXTREME GUARD remains eligible to replan upward while preserving a safe profit.

### Case 8 — Opponent decreases offer after hold
Current plan was safe, then THEIR OFFER drops.
Expected: old hold invalidates; planner recomputes from the new generation and reduces/replaces our offer if needed.

### Case 9 — Missing metadata
An otherwise eligible item lacks a market profile.
Expected: raw MM2 safety still works, but item is unprofiled; it cannot receive Stable/positive-quality credit.

### Case 10 — Mixed bundle
THEIR OFFER contains one strong liquid item plus weak/disputed pieces.
Expected: aggregate quality must reflect the whole bundle; one strong item must not hide junk risk.

### Case 11 — Equal-raw candidate plans
Two OUR plans create the same/similar raw profit, but one leaves/gives better strategic inventory.
Expected: choose the plan that preserves better future tradeability without violating raw safety.

### Case 12 — Low-tier percentage disagreement
Example 5 vs 7.
Expected: no heavy uncertainty penalty solely from 40% percentage difference when absolute difference is only 2.

### Case 13 — High-value absolute disagreement
Example Chroma Mortal 1800 vs 1600.
Expected: material uncertainty protection applies.

### Case 14 — Unknown/ambiguous identity
Market profile cannot be safely matched to the canonical scanner item.
Expected: do not guess; use scanner baseline only and mark market profile unavailable.

## Failure and recovery expectations

Market-data failure must fail closed at the planner layer, not the executor layer:
- missing profile => conservative baseline, no positive quality credit,
- stale snapshot => no live scrape during trade; treat quality data as lower-confidence,
- malformed profile => ignore profile and use canonical raw-value safety,
- planner exception => no offer mutation from that decision,
- executor behavior remains unchanged.

## Snapshot policy

The complete audit snapshot:
`pdiddler/pdiddler_market_snapshot_2026-11-02_AUDIT_v2_COMPLETE.lua`

must remain frozen as evidence.

A live planner should consume a separately versioned market module only after the matrix passes.

## Success criteria

Before creating a live v2.6 test stack:
- all 190 snapshot keys remain unique and mapped to canonical scanner ids,
- no market profile may alter identity resolution,
- all decision-matrix cases have explicit expected outcomes,
- all tests pass,
- v2.5 regression cases continue to pass,
- no executor/recovery/timer/final-Accept code changes are required.
