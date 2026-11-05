# Issue 28 — attainable initial quotes and retained inventory

Base: independently verified safety PR [#29](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/29), head `1d1130b6517ce5656fdd8e5dfe025a8eb780e054`. This follows Issue 27; its controller remains unchanged. Scope comes from [Issue 28](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/issues/28).

## Actual source findings

- The pinned policy 9 first-quote selector prefers offers within `min(received - 15, received * 0.60)`, with demand/risk ranking and a bounded comparable-quality extension. Its smallest-safe fallback can produce a very large margin. A 60% giveaway ceiling is a policy choice, not a measured acceptance model; it cannot generally express +15–35 profit on received values above 87.5.
- `rankPlans` separately uses bands relative to the minimum feasible profit. P4 does not blindly use that first candidate for every initial offer: it calls `selectInitialOffer`. Changing ranking alone would miss the actual first-quote path.
- The old opener checks the opponent's top-four-copy total, then favors demand/stability and proximity to their largest item. That can choose an opener 40 against Batwing 42 even though that single reply cannot support +15. Eligible total inventory does not prove a stable single-item reply exists.
- P4 v10 already retains a safe existing offer unless the unchanged addition-only policy authorizes a concession. The old video's proposed 25-to 23 replacement is not a reason to rewrite this working controller.
- Equal economic/portfolio planner states can merge a knife and a gun before ranking. Adding a count preference only after planning would lose some relevant choices.

## Chosen scope and alternatives

Change one pure strategy policy, plus its loader/bootstrap pins and tests. Keep P4 v10, early policy 5, valuation, hard feasibility, transaction verification, and the concession ledger unchanged.

Keeping the 60% first-quote preference preserves the mismatch. Changing the 25% concession target, 50% cap, or rewarded-anchor threshold would change separately agreed safeguards and is outside this work. Searching different opponents or asking them for a specific received bundle would require P3/negotiation work; this policy ranks our offers against the opponent's actual current offer.

The selected approach replaces the initial price preference with disclosed size/source-quality heuristics, requires an actual single-item opener witness, and adds a bounded useful-knife tie break. It does not predict acceptance or liquidity.

## Rules

For verified received total `R`, given/received value-weighted demand `Dg`/`Dr`, and given/received fluctuating-or-underpaid value share `Qg`/`Qr`:

```text
base = max(15, min(25, 0.25R), 0.15R)
demandPremium = R * min(0.20, 0.05 * max(0, Dg - Dr - 1))
riskPremium = 0.10R * Qr
preferredProfit = base + demandPremium + riskPremium
softReserve = 15 + demandPremium + 0.10R * max(0, Qr - Qg)
distanceBandWidth = max(5, min(25, 0.02R))
```

The mandatory verified/protected profit remains +15. The soft reserve and preferred profit do not change Supreme prices. Demand is ordinal; its premium is capped at 20% of received value. These constants are explicit policy heuristics, not calibrated resale discounts or completion probabilities.

Initial selection orders feasible plans by: soft reserve met; lower absolute target-distance band; offered demand/risk appeal within that band; exact target distance; existing retained-inventory comparison; net useful knives; deterministic economic/quality/copy/identity ties. A small source-demand difference cannot prefer a quote hundreds of value farther from the target. If no plan meets the soft reserve, or source-quality comparison is unavailable, retain the smallest verified safe giveaway and report the fallback honestly.

A useful knife means an eligible, verified Knife with demand at least 1 and a status other than `Fluctuating`/`Underpaid For`. The net count is received useful knives minus given useful knives. It is a secondary tie break; it cannot override the preceding economic, quality, or retained-inventory distinctions. Guns remain eligible. Preserve this descriptor in the planner state key so equivalent-price knife/gun choices are not prematurely merged; retain the 50,000-state cap and four-copy bound.

An opener must be owned and have at least one verified nonmatching canonical single-item reply worth opener +15 or more. Among those candidates, retain demand/stability priority and compare profit-preference distance. If only a multi-item reply works, wait for the opponent's offer instead of speculating. This witness does not predict which item they will offer.

## Review corrections and regression evidence

- A fixed minimum target 25 would choose Boneblade 7 over Plasmabeam 18 against the actual Chroma Swirly Gun 35; all three have demand 1/Stable. The adopted smaller-trade base retains 18/+17.
- An uncapped ordinal-demand premium could reach 50% of received value. It is now bounded at 20%, and diagnostics distinguish a soft-reserve miss from a missing source-quality comparison.
- Global appeal-tier priority initially chose 451/+844 in the declared real-price 1295 fixture, despite an owned stable four-copy 960/+335 alternative only 22.75 from target 312.25. The actual policy regression failed 451 versus 960 before the distance-band fix. Appeal priority is now bounded to one 5–25-value target-distance band. This does not imply the user's live inventory contains 960.
- With only Immortal×2+Mortal actually available in the separate 405 fixture, the best available 405/+890 remains valid. Do not fabricate a 1260 offer or force a fixed +35 margin at every tier.

## Verification and release

- [x] Inspect exact Issue 28 and pinned policy 9/P4 v10/early 5 after the independent safety PR.
- [x] Reproduce baseline initial-quote/opener/knife-state mismatches against actual production policy/controller code.
- [x] Add policy 10 with the stated preferences and bounded state descriptor; preserve P4 v10 and agreed concession safeguards.
- [x] Add real-price and explicitly synthetic comparisons, including the reviewed low-value and 1295 regressions.
- [x] Verify 30 policy tests, 14 strategy controller tests, 44 unchanged safety tests, and 15 unchanged economic-controller tests.
- [x] Verify 22 successor loader and 36 successor bootstrap cases.
- [x] Complete the release gate, preservation/hash audit, and immutable dependency publication.
- [ ] Publish a separate unmerged draft PR and state the remaining native tests.

Release evidence belongs beside this file in the build/results/pin artifacts. Native A/B protocol and limitations are in [README.md](README.md). No P1/P2/P3/P5 behavior, scanner UI, price source/expiry, Common-item classification, native final Accept, or completed-trade Discord delivery is enabled or changed.
