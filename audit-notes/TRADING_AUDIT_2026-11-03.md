# Trading audit — November 3, 2026

The trading system in the current V3 bot-integration loader is **not fully
correct at today's values**. This is a read-only audit: no runtime, frozen file,
loader pin, PR or trade was changed. Findings below apply to the actual V3 pins,
not every newer experimental trader in the repository.

## Scope and evidence

Current integration: V3 at `59b8d6ee6d476182633ed7d126565fd9bd74ef5a`.

- Scanner v6.8 at `3c48b49c1e750d91bfbf088fbc737185bddf39be`.
- Outgoing v15 at `9f0637b063c2f65cb1cf6fc1f6ce4ab08b5dda87`.
- P4 v2.3 EXTREME_GUARD at `41372d75f053cb125c12847188966a10d51d1f10`.

All 190 embedded price rows were compared against freshly retrieved MM2Values
category HTML using **category + exact item ID**, then cross-checked with the
exact image filename. Coverage: 16 Ancient, 46 Chroma, 128 Godly. There were no
missing/extra rows or image identity differences. Observation: November 3,
2026, approximately 19:36 UTC. Publication times below are the sources' labels.

Actual P4 and outgoing functions were also executed in isolated fixtures with
Roblox service/UI boundaries substituted. Reproductions demonstrate code behavior,
not a claim that each defect occurred in the user's live session.

## 1. High priority: 24 of 190 embedded prices are stale

The scanner hardcodes `2026-10-31 12:31:12 EST` at line 684. It does not refresh
MM2Values at runtime. [MM2Values](https://mm2values.com/) now reports
**11/03/2026 02:09:46pm EST**. Of the 190 rows, **166 match and 24 differ**.

Source pages: [Ancient](https://mm2values.com/?p=ancient),
[Godly](https://mm2values.com/?p=godly),
[Chroma](https://mm2values.com/?p=chroma).

| Item | Embedded | Published |
|---|---:|---:|
| Gingerscope | 15,250 | 15,750 |
| Travelers Axe | 7,700 | 7,350 |
| Vampires Axe | 1,375 | 1,425 |
| Emberbow | 325 | 350 |
| Emberscythe | 300 | 350 |
| Alienbeam | 1,850 | 1,900 |
| Raygun | 1,825 | 1,875 |
| Darkshot | 1,550 | 1,500 |
| Darksword | 1,525 | 1,475 |
| Soul | 625 | 615 |
| Spirit | 615 | 605 |
| Xenoshot | 440 | 425 |
| Xenoknife | 435 | 420 |
| WaterGun | 150 | 140 |
| Icecream | 155 | 140 |
| Embersickle | 80 | 100 |
| Beachy | 80 | 75 |
| Sands | 80 | 75 |
| Chroma Snow Dagger | 2,400 | 2,350 |
| Chroma WaterGun | 2,350 | 2,300 |
| Chroma Icecream | 1,875 | 1,850 |
| Chroma Embersickle | 1,100 | 1,250 |
| Chroma Sands | 1,325 | 1,225 |
| Chroma Beachy | 1,275 | 1,175 |

Names above follow the published page. Machine-readable differences are in
`value_changes.csv`; all published rows and exact IDs are in
`mm2values_comparison.json`. Retrieved source provenance is in
`source_manifest.json`; original sources are linked rather than mirrored.

### Actual planner consequences

The actual `buildPlans` function in P4 (lines 849–958), with its real quality
rules, produces these candidates:

| Give | Receive | Planner's old-price profit | Current MM2Values difference |
|---|---|---:|---:|
| Chroma Embersickle | Chroma Beachy | +175 | **−75** |
| Emberscythe | Icepiercer + Icecream | +20 | **−45** |

For example, Chroma Embersickle is stored at 1,100 and Chroma Beachy at 1,275;
today they are 1,250 and 1,175. The planner labels that plan `mode="profit"`.
These are list-value differences, not guaranteed real-market sale prices.
Final Accept is disabled: this defect drives offers and displayed profit rather
than automatically completing these trades.

## 2. High priority: current integration uses an older trading continuation

V3 retains the original issue integration's P4 v2.3 pin. It does **not** load
the later validated 190-item market profile, market-aware planner, later no-plan
handling, or adaptive/manual-completion work.

Repository `main` handoff stops at section 37. The
[later continuation handoff](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/blob/6543f67eca8737fefa1fb8d80e649d2d87739095/pdiddler/CHATGPT_HANDOFF.md)
continues through section 65. This matters when deciding what is actually
running; newer files existing in another branch does not activate them in V3.

- Section 54 explicitly freezes market-aware v2.6.3 at
  `9d66b5e69afa867c3b97589138290caeb664b350`, with live duplicate-removal and
  earlier trading evidence.
- Section 56 then identifies a **raw owned ID versus checker ID bug in that
  frozen baseline**, which could silently bypass market metadata. New planner
  v1.2 and P4 v2.4.4 fix the identity split without modifying the frozen artifact.
- The identity-corrected nonadaptive manual v4 continuation has reviewed live
  evidence, including ordinary request/rotation and a verified 140→380 trade.
  Some no-plan/retry paths remain unexercised.
- Latest adaptive v6 adds behavior/performance changes whose live validation
  remains pending. It should not be selected merely because its version is higher.

Do not blindly swap to the older frozen v2.6.3 file either. A separate integration
should select the intended identity-corrected continuation, retain all frozen
artifacts, and refresh/validate its scanner and market-profile snapshots together.
The later stacks use the same pinned scanner, so their existence does not make
these 24 canonical prices current.

## 3. Confirmed identity and lifecycle gaps in loaded P4

All references in this section are to
`pdiddler4_balancer_ROTATING_v2_3_EXTREME_GUARD.lua`.

- **Wrong partner lookup (lines 152–161):** `findPartner` accepts either a
  normalized username or DisplayName, in player enumeration order. A player
  named `WrongUser` with DisplayName `ActualUser` is selected ahead of the real
  username `ActualUser`. Removing punctuation also confuses `Actual_User` with
  `ActualUser`. Actual function calls reproduced both cases. This can select the
  wrong partner inventory/whitelist record.
- **Opening after a stale session (lines 1376, 1423–1425):** own-inventory refresh
  yields; the opening OfferItem call does not then revalidate session, partner,
  original trade root, or empty offer. A coroutine fixture stopped the session
  and changed the partner during that refresh: one opening remote still fired.
  Whether this race occurs under Roblox scheduling needs live evidence.
- **Transaction partner binding (lines 976–1002):** transaction validation checks
  session and opponent-offer signature, but not whether the current trade root
  and live partner are still the captured trade. An identical signature alone
  does not establish identity. This is a source-confirmed gap, not a reproduced
  live partner switch.
- **Contradictory item IDs (lines 343–364):** entry resolution uses `idMatch OR
  nameMatch`. A nonempty but different live item ID can still resolve using the
  same display name. A direct function fixture confirms it. Normal MM2 UI
  occurrence of conflicting IDs remains unproven.

## 4. Confirmed market-quality limitations

P4's market-quality table is a small static November 2 subset. `exactQuality`
(lines 322–339) labels an item with no profile **verified Stable**. An isolated
100→98 consolidation qualifies as a quality upgrade using this assumed metadata.
This can authorize a raw loss without positive evidence of received-item quality.

Known profiles are also stale: Vampires Axe is marked Doing Well (+3%) in code,
but the current MM2Values page and Supreme Ancient page mark it Stable.
Emberbow/Emberscythe are marked Underpaid For (−8%) in code, but current pages
mark them Fluctuating. Code quality multipliers are strategy assumptions, not
published numeric values or guaranteed liquidity measurements.

[MM2Values' own guide](https://mm2values.com/?p=tradeguide) explains why value,
demand, stability and ranges are distinct. A correct price sum alone does not
prove an offer is realistically obtainable or easy to trade onward.

## 5. Confirmed outgoing UI and card-verification bugs

References: `pdiddler3_outgoing_ROTATING_v15_UNCERTAIN_OWNER.lua`.

- **Hidden phone UI masks active tablet UI:** `leaderboardRoot` (lines 219–226)
  selects an existing phone root even if hidden. `exactRequestFrame` (816–835)
  does the same for requests; incoming/pending helpers return early from that
  hidden frame (983–1026, 1160–1187). Four actual-helper fixtures demonstrate
  that desktop-only target/request detection works, then stops working when an
  inactive phone tree is added. This depends on both trees being retained; the
  user's screenshot does not establish their actual live hierarchy. Fixing V3's
  monitor does not repair these separate frozen outgoing helpers.
- **Partial username accepted in compatibility fallback:** `cardMatchesPlayer`
  uses substring checks (427, 435). A visible card for `Alice123` passes as target
  `Alice` in the actual extracted function. The fallback at line 715 trusts this
  result. The exact popup path is better constrained; the defect concerns its
  compatibility fallback. No wrong-person request is claimed from a live run.
- **Session ledger limit:** `processed` is recreated whenever outgoing `run()`
  starts. The queue normally protects a target after one successful tap, including
  missing pending UI, but the module alone does not retain that ledger across
  manual reruns. V3's duplicate/dirty-session guards are therefore significant.

## What the loaded code does correctly

- Final item-trade Accept remains disabled; the loaded P4 contains no final
  AcceptTrade or AcceptRequest operation.
- The scanner requires matching complete inventory fingerprints before
  whitelist/blacklist classification: two reads normally, three for truly empty
  inventories. Incomplete/unmapped/malformed quantities remain Unknown.
- Canonical value resolution uses category/type/aliases and rejects ambiguity.
  The 190-row price comparison found exact source identity coverage.
- P4 rejects incomplete/unpriced own inventory before its opening offer.
- Normal, downgrade and big-downgrade minimums match the documented rules:
  max(15,3%), max(20,6%), max(30,8%). The quality-upgrade exception caps raw loss
  at 3%, although its metadata assumptions need correction as above.
- Actual extreme-guard calls hold 8→25 and 230→270, and flag 8→60/95/130 as
  extreme. Moderate overpay is not automatically given back.
- The 15-second empty-offer rule includes a final reread. The 60-second timer
  begins at the first nonempty offer and is not restarted by offer changes.
- Transaction generation/signature checks, recovery and exact count verification
  are present. These do not replace the missing identity/lifecycle checks above.

## Verification and limits

The seven current dependency pins/blob hashes still match. The existing isolated
V3 suite remains green: **44 integration + 14 transport tests**, plus syntax
checks. That suite validates bootstrap/hop behavior; it is not a certificate for
the trading algorithms. Separate audit fixtures exercised the actual trading
functions; their outputs are saved in `reproduction_results.txt`.

No Delta session was controlled and no trade was sent or accepted during this
audit. Published values are list estimates and can change. Snapshot comparison
is complete for the 190 embedded rows, not all rarities/collectibles in MM2.
Supreme was consulted only as secondary Ancient-market context, not silently
substituted for the project's canonical MM2Values numbers.

Recommended next work: create a separate trader-correction build that aligns
the intended identity-corrected module baseline, refreshes dated price/profile
data, and fixes request/partner identity guards with regressions. Keep frozen
modules and final-Accept lock intact. Do not fold these untested trading changes
into the loader while the user is testing bot avoidance.
