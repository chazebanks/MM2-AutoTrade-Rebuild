# System2 independent QA — Supreme stability label semantics

## Confirmed problem in Part4 before fix
Original `pdiddler/system2/attractiveness_evidence_lab.py` penalized **every** received label other than exact `Stable` with `NON_STABLE_PUBLISHER_STABILITY_LABEL`. This blended fundamentally different official Supreme classifications and incorrectly treated favorable **Doing Well** like unpredictable **Fluctuating**. The heuristic warning count influences `researchAttentionIndices` (even though that output is explicitly NOT a trade ranking).

## Independent first-party meaning
Official value-list guide: [Supreme Values — Use Guide](https://supremevalues.com/use) distinguishes:
- `Doing Well`: generally favorable, unlikely to drop, potential rise;
- `Underpaid For`: frequently trades for LESS than listed value;
- `Fluctuating`: inconsistent underpay/base/overpay, unpredictable;
- `Stable`: generally little change.
It also defines Rising, Overpaid For, Improving, Receding, Decreasing and Unsafe. The guide expressly warns that labels are **majority historical descriptions, not universal behavior or a trade fill-rate guarantee**.

The user's **actual pinned 189-row Nov13 export** (SHA256 `bb91b545637a0fe8d7dcceebef9070ee9a76210015bdc1737fd78f068acaeb4f`) was independently counted locally: `Stable:169`, `Fluctuating:8`, `Underpaid For:9`, `Doing Well:3`. Thus original generic non-Stable penalty affected **20** real weapons, including the **3** Doing Well items that should not be lumped into a negative instability bucket.

## Narrow repair
- Preserve original labels unchanged. Replace generic non-Stable warning with explicit descriptive cautions: `PUBLISHER_FLUCTUATING_RANGE_UNCERTAINTY`, `PUBLISHER_FREQUENT_UNDERPAYS`, `PUBLISHER_DECREASING_RISK`, `PUBLISHER_UNSAFE_WARNING`, `PUBLISHER_RECEDING_LABEL`.
- Favorable `Doing Well`, `Rising`, `Overpaid For`, `Improving` and neutral `Stable` do **not** inherit a generic penalty merely because the source label differs from Stable. This is **not** evidence of actual acceptance odds or guaranteed profit. Unrecognized future publisher labels block offline comparison until independently reviewed, rather than being silently interpreted as safe.
- New tests assert Doing Well is not categorized as instability, Underpaid For is specifically an underpay caution, and unfamiliar labels fail closed; inherited Fluctuating test now expects its explicit caution. Expected total: **222 focused offline tests** (219 inherited +3).
- Still research only: actual partner appeal, independently observed retrade fills, live source authority, client identity and settled trade remain UNKNOWN. All trade/Offer/Accept, Discord, learning and actual-profit authority flags remain false.
- Stacked on separate audited freshness fix PR #258, which already passed 219/219 tests and 8/8 workflows. Verify exact-head new CI before claiming this new patch green.

This is one separate issue; no changes to P3/P4/Delta, original Stage120 frozen source or original 189-value export.
