# Pdiddler V15.7 strategy

This build chooses verified initial offers closer to a size/source-quality preference and preserves comparable useful knives. The working Issue 27 safety controller and addition-only concession policy remain in place. This is quote selection; no acceptance-rate improvement or completed inventory gain has been established by offline tests.

## What changes

The old first-quote preference normally capped our offer at 60% of the opponent's value. A neutral received 100 could therefore produce a 40-value margin even when an owned 75-value offer could give us +25. The new policy can choose 75 while preserving the hard +15 floor.

Speculative openers now require a verified single-item reply that supports +15 and has a different canonical identity. Against Batwing 42/Luger 18, Chroma Laser 40 has no qualifying single reply; owned Plasmabeam 18 does. If only a combination can support a trade, the bot waits for the opponent to offer first. This does not guarantee their chosen first item is the witness.

Existing safe quotes remain under P4's current hold behavior. A preferred initial margin does not authorize increasing a quote later. The threshold `max(10, 5% of the last verified rewarded anchor)`, approximate 25% target, 50% cap, trade-wide budget, and no-time-based-generosity rule remain unchanged. Those limits can legitimately leave a later offer far above the preferred profit.

## Transparent preferences

Let `R` be the verified received total, `Dg`/`Dr` the value-weighted given/received Supreme demand, and `Qg`/`Qr` the given/received value share marked `Fluctuating` or `Underpaid For`.

```text
base profit       = max(15, min(25, 0.25R), 0.15R)
demand premium    = R * min(0.20, 0.05 * max(0, Dg - Dr - 1))
stability premium = 0.10R * Qr
preferred profit  = base + demand premium + stability premium
soft reserve      = 15 + demand premium + 0.10R * max(0, Qr - Qg)
```

With neutral matching quality, base targets for received 35, 60, 100, 200, 500, 1295 are 15, 15, 25, 30, 75, 194.25. The large-trade percentage uses **received value** as its denominator. Source-quality premiums may raise a particular candidate's target.

These are disclosed strategy constants. Demand is an ordinal source rating, not a probability or a monetary resale forecast. No measured liquidity data is available. Neither premium alters the Supreme quote, and neither replaces the mandatory +15 verified/protected profit requirement.

The selector first prefers a met soft reserve, then a smaller target-distance band of width `max(5, min(25, 0.02R))`. Within one band it prefers offered demand at least `max(1, Dr-1)` and given instability at most `Qr+0.25`, then exact target distance, retained-inventory facts, and net useful knives. Remaining ties use deterministic value/quality/copy/identity ordering. This bounds the influence of a small rating difference on the margin distance; it does not claim measured opponent preferences.

If every available quote misses the soft reserve, the smallest verified safe giveaway remains the fallback. It may have only +15 profit. The metadata says `soft-quality-reserve-unmet`; a missing comparison says `source-quality-comparison-unavailable`. A soft reserve is a preference, not a second mandatory profit floor. Large margins also remain possible when no owned 1–4-copy alternative is closer to the target.

## Knives and retained inventory

A useful knife is a verified eligible Knife with demand at least 1 and a status other than `Fluctuating`/`Underpaid For`. This is a conservative category, not a liquidity claim. Net useful knives equals received useful knives minus given useful knives. Guns remain fully eligible.

Count matters only after the preceding economics, quality, and retained-inventory comparisons tie. For example, equally priced/rated knife and gun giveaways can favor giving the gun and retaining the knife. It cannot favor more poor-quality items over better value or demand. Planner states retain the useful-knife count so such alternatives survive deduplication; the existing four-copy and 50,000-state limits remain.

The policy can compare our bundles against the opponent's current offered bundle. It does not choose a different opponent or make them offer a different set. The 100→three useful knives 125 and 100→low-demand knife 140 cases are separate declared opportunities, not alternatives the bot can force within one trade.

## Concrete owned comparisons

The following are outputs of the actual production policy using current snapshot prices and an explicitly declared owned fixture: Plasmabeam 18, Boneblade 7, Iceblaster 33, Pearl 75, Borealis 135, Flowerwood 235, Rainbow 400, and Harvester 250. These holdings are test inputs, **not a claim about the user's live inventory**. Canonical overlap, quantities, and four-copy restrictions are enforced in every candidate.

| Received value | Chosen given | Verified quote profit | Candidate-specific target | Distance | Safe candidates |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 35 | 18 | +17 | 15 | 2 | 2 |
| 60 | 40 | +20 | 15 | 5 | 5 |
| 100 | 75 | +25 | 25 | 0 | 9 |
| 200 | 133 | +67 | 30 | 37 | 15 |
| 500 | 425 | +75 | 75 | 0 | 66 |
| 1295 | 960 | +335 | 312.25 | 22.75 | 162 |

The 200 fixture cannot use its owned Borealis against an opponent also offering Borealis; it cannot invent a 170-value bundle. The 1295 receipt includes 1180 value marked `Underpaid For`, so the stability premium is 118 and its target is 312.25. Its 960-value choice consists of Pearl 75+Flowerwood 235+Harvester 250+Rainbow 400. A preliminary global demand-tier preference wrongly chose 451/+844 despite that feasible alternative; the distance-band regression prevents that rating cliff.

That 960-value choice has net useful knives−2 under the stated category: count is deliberately secondary to the earlier economics/quality comparisons. It is not a promise that every trade increases knife count. The declared 100→three stable knives 125 case gains two useful knives; the two-knives 100→one desirable item 130 case can justify a lower count.

In the separate restricted inventory containing only Immortal×2+Mortal, all available eligible value is 405. Against 1295 the selector retains 405/+890. A1260-value giveaway for +35 is unavailable, and this strategy does not fabricate it. Source-based risk preferences also do not require sabotaging a genuine large-margin opportunity.

These are theoretical verified quotes, not completed trades. Exact test fixtures, complete candidate enumeration, and before/after failures are in the Issue 28 test/evidence files. Exact 100/125/140/130 examples use labeled synthetic verified fixtures; they are not additions to the Supreme catalog.

## Verification boundaries

The targeted suites cover 30 pure policy cases, 14 whole-P4 strategy cases, 44 unchanged immediate-safety cases, 15 unchanged economic-controller cases, 22 successor loader cases, and 36 successor bootstrap cases. The release gate also runs inherited suites and checks predecessor bytes and immutable pins. Passing them establishes the tested decisions and action ordering, not native MM2/Delta behavior.

P4 v10 still protects 405/115 before voluntary debounce, can withdraw a verified single copy before restoring 18/33, and preserves transaction/acceptance history. The fixed +15 rule, canonical identity, actual quantities, reservation ownership, rewarded anchor, native readiness, incoming/outgoing ownership, and hopping gates retain their existing protections. Automatic final Accept and completed-trade Discord delivery remain disabled. Common-item resolution and authoritative completion remain separate tasks.

The snapshot remains `supreme-2026-11-04-97613e277b36`, expiring **2026-11-05 21:55:32 UTC**. The live loader must block new work at expiry. Historical-clock overrides in isolated source tests never extend live freshness; a later native trial requires genuinely refreshed source data.

## Native A/B protocol

1. Compare the immutable V15.6 safety baseline with this build using a clean rejoin and exactly one Delta Auto Execute entry per trial. Preserve the same Supreme snapshot while fresh. Record build SHA, session start/end, server, verified starting eligible inventory, and any independent inventory changes.
2. Alternate comparable fixed-duration sessions rather than judging a single favorable offer. Include startup, requests, waiting, trading, and hopping in actual session time. Record inventory/opponent differences; this observational comparison cannot remove all server/player variation.
3. For each opportunity, record the verified items/quantities, given/received totals, quoted profit, demand/status, initial target/distance and fallback reason when available, native offer mutations, cooldown resets, request outcome, and elapsed time. Count an opened or ignored request separately from a completed trade.
4. Check real 35→18 and single 42-reply openers; confirm a safe 25 offer stays 25 after their total becomes 60; observe cumulative additions/removals and immediate Issue 27 protection. Measure actual client/server removal/decline timing and confirm single-copy quantity UI. Do not infer atomic protection from fixture timestamps.
5. Label window closure or a proposal as unconfirmed. A native Claim panel is useful evidence, but realized value/profit requires authoritative before/after inventory counts matching the exact give/receive quantities, valued with the same fresh canonical profile. Exclude unconfirmed outcomes from completed-trade profit and session-value/hour claims.
6. Compare confirmed net eligible value, confirmed completions, wall-clock profit/hour, quality of received/retained inventory, and mutations per opened trade. Until authoritative completion evidence exists, report quote and timing observations only. Retain logs without private webhook credentials.

Immutable release references and preservation evidence belong in this directory's build/results/pin artifacts. Use only the single final pinned entry supplied for the published draft build; this document introduces no competing execution snippet.
