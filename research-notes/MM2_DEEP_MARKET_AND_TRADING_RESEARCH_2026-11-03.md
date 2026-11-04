# MM2 market and sustained-inventory-growth research

Research cutoff: **November 3, 2026**. This is a documentation-only follow-up to
[Issue #6](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/issues/6).
The complete Issue #4 checkpoint is preserved at
`4b5c6d9095d21643349cee32d43719e515e294d1`, draft PR #5. Nothing in this report
changes a runtime file, enables acceptance/reporting, or authorizes a merge.

This report describes the November 3 / Issue #4 baseline. Later engineering
work, including PRs #7–#12, is subject to separate current review. Its five-second
negotiation and twelve-second empty-window guidance does not override later
verified native cooldown evidence.

## Executive finding

The best-supported **candidate for supervised testing** is a conservative hybrid:
Approach C for discovery and negotiation, strict Supreme +15 as a prerequisite,
then a Pareto comparison of retained inventory, incoming demand/stability,
concentration, useful denominations and slot feasibility. Decline attractive
paper wins that increase unmeasured exit risk. Do not turn demand into cash,
infer a resale probability from posted interest, or sacrifice every available
surplus to improve an unmeasured chance of acceptance.

This is not proof of a globally optimal strategy. **No independently verified
completed-trade sample or unbiased attempt denominator was obtained.** Therefore
acceptance rates, realized liquidity, turnover and expected growth/hour remain
unknown. The strongest quantitative evidence here is a dated **publisher-price
dataset**, not execution data. The distinction changes what can be recommended.

## 1. What was actually researched

| Evidence | Coverage | What it establishes |
|---|---|---|
| Supreme primary category data | All 190 existing canonical rows: 16 Ancient, 128 Godly, 46 Chroma; 189 numeric and one Priceless | Published estimates, demand, rarity, stability, ranges, origin, event; not native tradability or sale prices |
| MM2Values category/card identity | 190/190 matched by category and checker ID; 166 weapon types corroborated through explicit Gun/Knife filters | Cross-list disagreement and partial type corroboration; not interchangeable scales |
| Primary item histories | Five items, **801** publisher event records; 30/60/90-calendar-day summaries | Changes in the published list; not all trades, daily volatility, order books or realizable bids |
| Primary extra features | Flippability/aliases on five inspected item pages | Publisher labels, with 185 missing rather than imputed |
| Sets | Seven named primary set observations | Published set totals/ranges; no guaranteed executable premium |
| Trading platforms | Neblio, Traderie, MM2 Trade Hub, Cosmic Values | Public offers, methodology, some price history; completed-trade access/proof insufficient |
| Social evidence reused | Nine YouTube transcripts, three indexed TikTok text/OCR records, twelve Reddit thread leads | Qualitative tactics and bias; old numerical quotes remain historical |
| New social work | Eleven targeted searches overall; three new video metadata records, two new timed English transcripts; additional Reddit/TikTok/platform discovery | Independent criticism, actual offer narration, freshness checks; no newly verified settlement |
| Public Discord | Supreme's public landing page and channel description | Trading channels exist; channel messages and trade proofs were not accessible in this session |

Every material number below can be traced to the
[190-row matrix](ELIGIBLE_ITEM_MARKET_MATRIX_2026-11-03.csv),
[machine-readable data](MARKET_DATA_2026-11-03.json),
[event histories](PUBLISHER_HISTORY_2026-11-03.json), and
[source ledger](RESEARCH_SOURCE_LEDGER.md). Source publication, observation and
history-event dates are separate fields. Missing data are blank/UNVERIFIED, not 0.

### Existing work reused, and what supersedes it

The archived [November 3 research](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/tree/docs/pdiddler-trading-research-2026-11-03/research-notes)
was read before new collection: synthesis, recommendations, YouTube, TikTok,
Reddit and source manifest; the separate audit and all-item comparison were also
reviewed. Its old instruction to preserve highest-first is **superseded** by
Issue #4's approved Approach C. Its statements that no opener/timer advantage was
empirically established still stand. Existing creator transcripts were reused,
not purchased again. The adaptive reference and PR #5 implementation were read
as code evidence, not as evidence of market profitability.

## 2. Market data, identity and source conflicts

### The actual operational universe

The matrix is **canonical mapping coverage**, not a declaration that every row is
currently tradable in a native inventory. Actual eligibility still needs game
metadata: tradable Weapons, Knife/Gun, approved Godly/Ancient and valid Chroma
variants, exact raw execution ID, owned quantity and current canonical price.
Native raw IDs are unavailable offline and remain blank. The matrix's weapon
type is MM2Values-filter membership, not a replacement for native metadata.
Twenty-four types could not be corroborated by those filtered pages; none was
guessed from item names. Chroma rarity class is preserved separately.

The source DOM contained **nine extra rows outside the 190 mapping**: seven
Chroma Fire pets under the Pets heading, and hidden Godly-page Batwing/Black Luger
rows displaying 1,000,000. They are quarantined in
[the unmatched-row file](UNMAPPED_SOURCE_ROWS_2026-11-03.json). Their existence
does not establish valid weapon prices. In particular, the normal Ancient
Batwing row must not be replaced by a same-name hidden Godly row. This is direct
evidence for section/class/visibility-aware parsing and exact category/ID joins,
not fuzzy name matching. [Primary Godly page](https://supremevalues.com/mm2/godlies)
[Primary Chroma page](https://supremevalues.com/mm2/chromas)

### Cross-list comparison

**118 of the 189 numerically comparable rows differ** between Supreme and
MM2Values in these captures. That is a cross-publisher comparison, distinct from
the older audit's 24 stale scanner-MM2Values entries. Difference is defined as
`MM2Values − Supreme`; percent uses Supreme as denominator. A 40% disagreement
on a five-point item is not a 40-point risk. Examine absolute and relative
differences together. Do not substitute MM2Values to make an otherwise losing
Supreme trade look profitable. [Supreme](https://supremevalues.com/mm2/godlies)
[MM2Values](https://mm2values.com/?p=godly)

| Item | Supreme | MM2Values | Supreme demand/status | Interpretation |
|---|---:|---:|---|---|
| Harvester | 250 | 250 | 3, Stable | Agreement is not proof of quick resale |
| Icepiercer | 160 | 165 | 3, Stable | +5 disagreement can consume a small margin |
| Embersickle | 90 | 100 | 2, Fluctuating; range85–100 | A +15 paper win may have less downside cushion |
| Traveler's Axe | 7,500 | 7,350 | 5, Underpaid For; range7,400–7,500 | High nominal value and demand do not remove exit friction |
| Evergun | 3,450 | 3,425 | 5, Stable | Useful comparison point, not a guaranteed bid |
| Candy | 80 | 90 | 1, Stable | Familiarity/set membership does not imply strong demand |
| Eternal | 7 | 10 | see matrix | +42.86% difference is only three absolute points |

Supreme's last global publication stamp is **2026-11-02 17:34:27 UTC**. The
new Ancient raw capture exposes it. Processed Godly/Chroma captures omit the
stamp; their timestamp is explicitly reused from the earlier same-day raw
captures, while their item rows were newly rechecked. MM2Values' publication
timestamp was unavailable in the processed captures; retrieval on November 3
does not establish its publication time. Those limitations are recorded per row.

A historical contradiction remains unresolved: Timesaver says MM2Values was
16,250 on October8, while Trade Hub's stored MM2Values series labels October8
as15,000 after a16,250 prior observation. These are different secondary records,
not primary archived MM2Values captures. The Supreme history is a different
scale and cannot adjudicate that discrepancy. The window calculations below
therefore use only the primary Supreme series, not a stitched mixed-source path.
[Commercial article](https://timesaver.gg/blog/mm2-gingerscope-value)
[Secondary archive](https://mm2tradehub.com/values/gingerscope)

### Ranges, flippability and false precision

Only 15 canonical rows publish numerical ranges in these captures. `[N/A]` means
no published range, not a zero range or guaranteed execution at base. Supreme's
guide defines base values and qualitative demand/stability separately. Its
flippability label is intended for experienced traders and explicitly involves
risk; it is not a resale percentage. The displayed “chance of rising” percentages
have no calibration sample or validated forecast horizon here and are excluded
from algorithmic probability estimates. [Supreme use guide](https://supremevalues.com/use)

Example using current source values: giving Beachy75 and receiving
Embersickle90 is nominal +15. At the latter's published low85 it is only +10,
before any unknown resale friction. The example demonstrates scenario risk,
**not** an available accepted trade. A conservative risk filter would reject or
hold that opportunity while preserving the absolute +15 base-value requirement.
[Godly values](https://supremevalues.com/mm2/godlies)

### Supply, events and sets

Origins distinguish old event rewards, shop bundles and unboxed items, but none
of these sources provides an audited circulating-supply census. Do not translate
rarity into number of copies. Duplicates, bot farming and historical duplication
are plausible supply risks; exact present supply and causation are unverified.
Colbe's March2025 explanation attributes falling values to these forces, but is
commentary, not a measured causal study or current price source.
[Colbe, 2:19–4:50](https://www.youtube.com/watch?v=C7ZPB-fj0GI&t=139s)

The inspected set prices currently equal component base sums in the examples:
Ever6,150 = Evergun3,450 + Evergreen2,700; Sakura2,310 = Sakura1,150 + Blossom1,160;
Candy112 = Candy80 + Sugar32; Ice98 = Icebreaker65 + Iceblaster33; Dark2,975 =
Darkshot1,500 + Darksword1,475. Dark's published range2,925–2,975 also equals
the two component lower/upper sums. A recognized set may improve a particular
counterparty's utility, but a universal extra set premium is unsupported.
Never add both component values and set value to the same offer total.
[Set source](https://supremevalues.com/mm2/sets)
[Set observations](SET_OBSERVATIONS_2026-11-03.json)

## 3. Actual trading evidence and its limits

### Published offers are not market-clearing trades

MM2 Trade Hub explicitly identifies its statistics as posted offers. Harvester's
page reports 202 offers, 258 requests and a median +36% asking premium from20
solo offers within a4,096-post rolling sample. Its Gingerscope page instead
shows a4,010-post sample,115 offered/26 requested, and a−47% ask from just6
solo offers, including implausibly weak requested-item combinations. These
different page samples are not synchronized or representative of the whole
market. The −47% figure is **not an obtainable discount**. Quality, complete
quantities, same-counterparty settlement, deduplication and verified execution
are missing. [Methodology](https://mm2tradehub.com/editorial-policy)
[Harvester](https://mm2tradehub.com/values/harvester)
[Gingerscope](https://mm2tradehub.com/values/gingerscope)

Neblio says its contributors review community-submitted completed trades. Its
Gingerscope page currently reports15,750, demand5/5, and34 value changes. The
“Completeds” tab was visible but individual completed records/proofs were not
successfully inspected: the read-only interaction attempt returned
`INVALID_ARGUMENT`. This is a tool limitation, **not proof that the tab requires
login or contains no records**. A platform's methodology claim does not establish
independent verification of every submitted trade. Its demand scale differs
from Supreme's. [Methodology](https://neblio.com/mm2/value-list/uniques)
[Correct item identity](https://neblio.com/mm2/value/Gingerscope/15365)

Traderie's current item page gives15,750/demand6, but its “Recent Trades” route
explicitly requires sign-in. The homepage's aggregate “successful trades” label
does not reveal an MM2-only sample, time period, proof standard or item-level
completion denominator. It cannot calibrate our bot's acceptance rate.
[Item](https://traderie.com/mm2/product/gingerscope-gun-2023)
[Gated recent records](https://traderie.com/mm2/product/gingerscope-gun-2023/recent)

Cosmic is linked as Supreme's trading partner, but partnership is not independent
price corroboration. Its accessible trade page returned generic text about fish
and aquatic specimens rather than useful MM2 trade records. That content was
rejected as evidence, not interpreted as a new MM2 mechanic.
[Public board](https://mm2.cosmicvalues.gg/trading)

### Creator footage and anecdotes

Breeze's August30,2026 video is useful **offer narration**: at about0:22–0:25 the
creator declines an inadequate offer; around1:07 he says the other person
accepted. The latter does not prove both native confirmations, inventory delta
or resale. The transcript later describes many offers and desire for a better
one. This is selected entertainment with creator/visibility effects, not a
random execution sample. Historical quoted item values are not November prices.
[Breeze, 0:22](https://www.youtube.com/watch?v=l_W7n_6Bnuw&t=22s)
[Breeze, 1:07](https://www.youtube.com/watch?v=l_W7n_6Bnuw&t=67s)

Reused Neblio/Maria/MrMoogma/Inspecter transcripts independently motivate demand,
compact upgrades and checking values, while disagreeing on server selection and
whether accepting a list-value loss is desirable. The loss-taking advice is
incompatible with +15 on every leg and remains excluded. Sudon's challenge uses
friends, gifts and fame. The three reused TikTok primary text records include
gifting and a personal common-knife collection; none demonstrates repeatable
anonymous +15-only trading. [Prior timestamped review](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/blob/docs/pdiddler-trading-research-2026-11-03/research-notes/youtube.md)
[TikTok formats/limitations](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/blob/docs/pdiddler-trading-research-2026-11-03/research-notes/tiktok.md)

New Reddit retrieval was again403 unsupported. New search hits and the twelve
reused leads discuss bad demand, duplication, sets and scams, but full comments,
screenshots and attribution remain unverified. There is no basis for a claim
of Reddit consensus. A newly discovered TikTok guide remains index-only; a paid
full-record lookup was not repeated because no new completion proof or price
calibration was likely to follow. Public Discord landing pages describe trading
channels, not their messages. No authenticated community access was claimed.
[Reddit access attempt](https://www.reddit.com/r/MurderMystery2/comments/1j6hpr1/what_happened_to_values/)
[Discord source](https://supremevalues.com/discord/)

### Consequence for liquidity claims

“Reliably moves,” “commands overpay” and “requires a discount” cannot be assigned
measured probabilities here. What is supportable is a **watchlist**: published
demand/status, source ranges and repeated qualitative concerns. The evidence
does not support a fixed demand-to-resale multiplier, universal knife premium,
universal Chroma discount, guaranteed seasonal rise, or a model trained on asks.
Scams, spam, content incentives, omitted rejected offers, repeated posters,
wish-list utility, bot supply and possible manipulated proofs all bias samples.

## 4. Thirty, sixty and ninety-day dynamics

The following figures use primary `_svPopup.history` numerical event records.
Cutoffs are August5, September4 and October4 through November3,2026, using
publisher calendar timestamps whose timezone is unspecified. At each cutoff,
the last prior publisher value is carried forward. This measures **list-price
change**, not daily transaction returns or calibrated volatility. Full series
and formulas are included; missing pre-release values are not filled with zero.
[Primary history pages](PUBLISHER_HISTORY_2026-11-03.json)

| Item | Last published value | 30d | 60d | 90d | Important qualifier |
|---|---:|---:|---:|---:|---|
| Gingerscope |15,750|+1.61%|−8.70%|−11.27%|30d minimum14,500; recovery does not erase earlier decline |
| Watergun |145|−6.45%|−25.64%|−42.00%|Currently Stable despite a large preceding list-price decline |
| Harvester |250|0%|0%|0%|No publisher changes since June17; unchanged list is not a liquid bid |
| Evergun |3,450|0%|0%|0%|No publisher changes since July7; source coverage may be incomplete |
| Embersickle |90|Unavailable|Unavailable|Unavailable|First recorded October19 at725; subsequent low85; launch-to-current−87.59% |

Watergun is a concrete warning against interpreting today's “Stable” as a
statement about the preceding90 days or a future guarantee. The Harvester and
Evergun records show why the displayed “last change” must not be labelled a
one-day or current-update return. The list can remain unchanged while buyers'
willingness changes; accessible offers do not establish the size of that gap.
[Watergun](https://supremevalues.com/mm2/godlies?item=Watergun)
[Harvester](https://supremevalues.com/mm2/ancients?item=Harvester)
[Evergun](https://supremevalues.com/mm2/godlies?item=Evergun)

The Embersickle series is evidence of a new-item repricing shock, not proof of
the cause or an annual Halloween return pattern. A “buy every Christmas item
before December” rule is unsupported: holiday interest, new supply, opportunity
cost and prior ownership all interact. No future event start date or guaranteed
rise/fall is asserted. [Embersickle](https://supremevalues.com/mm2/godlies?item=Embersickle)

## 5. Fair strategy comparison under identical constraints

This is a **synthetic feasibility comparison**, not a backtest. All six policies
receive the same inventory: A90/demand5, B60/demand3, C20/demand2, D10/demand1;
all Stable, one copy each, and an opponent offering T100/demand3/Stable after1s.
All identities/prices are known; at most4 total copies; all final offers need
+15. There are no donations, future quotes or hidden partner items. We compare
what a deterministic policy selects, not fabricated probabilities.

| Policy | Initial safe selected offer | Conditional gain before sweetening | Advantage | Failure/lockup risk |
|---|---|---:|---|---|
| A: PR3 highest-first/max-safe | Opens A90, then B60+C20=80 |+20|Large safe concession to the counterparty |Speculative opener; surrenders more surplus and changes retained denominations |
| B: Approach C | Observe; B60+D10=70 using initial margin band |+30|Keeps negotiating room; responds to an actual offer |Bands/two-step pacing are heuristics; may still surrender useful adds |
| C: pure conditional-profit preservation | D10 |+90|Maximum value retained conditional on settlement |Very weak financial appeal; acceptance unknown; may waste windows and lock capital |
| D: quality/exit-aware | B60 |+40|Single item with comparable published demand; no filler |Still only60% of their list total; no measured acceptance advantage |
| E: denomination/diversification reserve | B60 |+40|Keeps C20/D10 as matching denominations and A90 as an anchor |A reserve can prevent a trade another policy would complete |
| F: confidence-adaptive hybrid | D's candidate, then nondominated safe alternatives if needed |+40 initially|Separates eligibility, preservation and concessions |Requires trustworthy metadata; HOLD when confidence fails; no proven superiority |

The displayed D/E/F choice is one defined research policy, not a claim about
the current Issue #4 implementation. A's initial90 is not safe to accept against
100; its eventual80 is. A70 receives/gives ratio and an A80 ratio are financial
appeal measures, **not acceptance probabilities**. The policy comparison and
complete feasible subsets are reproducible in `STRATEGY_COMPARISON_FIXTURES.json`.

The table compares settlement **conditional on the first safe selected plan
being accepted before sweetening**. It is not a comparison of final concessions.
If T100 stays unchanged and unaccepted, current Approach C moves70→80 after its
five-second consideration, reducing conditional gain from30 to20; if no higher
safe plan exists, its subsequent final window ends in decline. All strategies
need the same observed response trace to compare eventual outcomes. In this
research no response trace or completion probability is assumed known.

The main tradeoff is `opportunities/hour × observed completion rate × gain per
verified completion`, further constrained by retained inventory and mark-to-list
changes. None of the first two inputs is estimated here. A fixed +15 is75% on
a20-value give,15% on100 and0.3% on5,000. It necessarily excludes many ordinary
small trades and loss-taking upgrades; this is a user constraint, not evidence
that the excluded opportunities are bad for every human trader.

### When each strategy wins or fails

- **A** may complete price-sensitive offers when concessions matter and capital
  preservation matters less. It fails on mismatched partner capacity, high-value
  exposure, slow attention and sellers who prefer a different inventory shape.
- **B** is a defensible operational baseline when counterparties respond during
  the observation window and native state is trustworthy. Its latency can miss
  impatient traders; its band objective must be compared with alternatives.
- **C** is useful for finding the preservation frontier, not always for sending
  its maximum-profit point. A huge theoretical gain with no settlement is not
  sustained growth.
- **D** limits exposure to published risk flags; its realized adverse-selection
  benefit is unmeasured when list quality contradicts face value.
  It fails when “high demand” is manipulated or lagging, or when it excludes a
  newly improving asset without evidence.
- **E** matters as holdings concentrate or useful adds disappear. Diversification
  can itself create too many low-value names; maintaining every set or a fixed
  allocation is not justified.
- **F** is the strongest research candidate because it makes those tradeoffs
  explicit and uses HOLD when evidence is insufficient. It is not a validated
  expected-return optimizer and must not learn from fake or selected completions.

All remain vulnerable to manipulated list prices; none fixes unsafe acceptance,
identity, quantity or completion handling. Four native slots create a packing
constraint, but do not prove arbitrary stacked quantities. Keep four-copy mode
until actual multi-copy add/remove/final-slot evidence is captured.

## 6. Smaller actionable watchlist

Ranked **within capital bands**, using published demand/stability first, then
capacity and cross-source uncertainty. This is a review list, not a hardcoded
buy list, native whitelist, guaranteed liquidity ranking or personal target.

| Band/rank | Candidate | Supreme / demand | Current reason to inspect | Counterargument |
|---|---|---|---|---|
| Modest1 |Harvester|250 /3|Stable; both lists agree; meaningful posted interest|Rarely Flippable; posted +36% is an ask, not a realized premium |
| Modest2 |Icepiercer|160 /3|Stable, usable denomination|MM2Values165 differs; no measured turnover |
| Medium1 |Sakura/Blossom|1,150/1,160 /5|Stable; compact set recognized by list|No automatic set bonus or verified overpay |
| Medium2 |Chroma Beachy/Sands|1,175/1,225 /5|Stable in current snapshot|Filtered type metadata missing; raw variant must be verified natively |
| Large1 |Alienbeam|1,900 /6|Stable with high published demand|Native type/source classification must be checked; no execution sample |
| Large2 |Evergreen/Evergun|2,700/3,450 /5|Stable; useful compact holdings|Past lack of list changes is not a reliable exit bid |

Risk-review rather than automatic intake: new Fluctuating Ember items; Underpaid
Traveler's Axe/Darkshot/Darksword; low-demand fillers; any source anomaly or
unmapped variant. Rarely Flippable is not a reason to inflate price or assume
an experienced player can always win. [Current matrix](ELIGIBLE_ITEM_MARKET_MATRIX_2026-11-03.csv)

## 7. Recommendations and falsifiability

### Current engineering pipeline audit

The inspected V5 loader pins P4/policy/profile at
`7ecd5b44b30f513a16061f0cb92476cb8cd2e6fa` and retains six other dependency
entries for startup/gate/scanner/outgoing/policy/transport, nine entries total.
The names refer to the published Issue #4 version, not an assumed newer runtime.

| Stage | Actual boundary and research implication |
|---|---|
|Source → resolver|Dated Supreme profile plus canonical category/checker identity; native raw ID separate. No research data file is loaded by V5. |
|Scanner → trading API|Frozen v6.8 scanner classification/whitelist remains MM2Values; loader reprices copied inventory into Supreme without replacing scanner code. Display figures must be labelled distinctly. |
|Offer parser|New P4 resolves actual slots against inventory, raw/name/Chroma/count proofs; hidden wrong-category website rows must not influence this identity path. |
|Planner|Adaptive policy uses bounded DP retaining demand/risk alternatives; initial ranking remains profit-band first. Proposed frontier/quality-first ordering is a separate experiment. |
|Mutation executor|One P4 applies/removes/reads back plans, with GUI/session/partner/generation fences, local approval handling and12/60s guards. Market theory does not replace these checks. |
|Native acceptance|Hard-disabled; the extra-second verification contract exists offline. Native control/cooldown sequence still unproved. |
|Completion → inventory|Offline verification requires correlated evidence, exact raw deltas and stable complete canonical valuation. No active native adapter is started. |
|Discord|Payload/outbox contract exists offline; native completion/persistence/delivery remain disabled. Posted offers cannot enter it as proof. |
|Next target → hopper|Outgoing JobId processed ledger preserves eligibility; P5 alone transports after45s exhaustion/final scan, with request/trade ownership guards. No personal objective affects this path. |

This mapping identifies the exact boundaries where proposed source/risk inputs
could enter a **new separately reviewed version**. It does not claim that market
research has completed the still-disabled native pipeline.

Prioritize evidence/identity and trustworthy outcome capture before optimizing
weights. Then compare nondominated safe plans, range downside and inventory
preservation against the current band-first selector. Log every eligible attempt
and missed safe opportunity; deduplicate outcomes and separate gifts/repricing.
Do not evaluate a policy on profits only among handpicked successful videos.

The [strategy specification](PDIDDLER_TRADING_STRATEGY_SPEC.md) gives exact
decision order, HOLD/DECLINE rules, experiments, fixtures and metrics. The
[implementation priorities](IMPLEMENTATION_PRIORITY.md) distinguish no-code
operational review, separately gated engineering, and actions not to automate.
The [personal roadmap](GINGERSCOPE_PERSONAL_ROADMAP.md) is external to the bot.

## 8. Access, rights and remaining uncertainty

Supreme's [terms](https://supremevalues.com/tos) restrict collecting/copying value
data for projects, including manual collection. No feed permission or license
was established. After reading them, no additional bulk item-popup/API crawl
was performed; 185 flippability fields remain missing. This research reuses the
existing repository mapping, reviews accessible category facts and a small set
of primary item histories, and stores factual tables/provenance rather than
third-party page bodies or complete transcripts. Existing repository copies do
not establish reuse permission. Obtain permission or an authorized feed before
production refresh/redistribution; this report does not provide legal clearance.

Historical series may have corrections/incomplete coverage; no independent
execution record validates their microstructure. Reddit was blocked; Discord
messages and Traderie recent trades were unavailable; Neblio proof navigation
could not be verified. New TikTok discovery remained index-only. A rejected
Neblio URL resolved to an unrelated pet: that record was discarded after checking
the item identity, and only the discovered `/Gingerscope/15365` record is used.
The empty/misleading pages are retained in the ledger as limitations, not silently
counted as market evidence. No verified current personal inventory was supplied;
the historical ~5k amount is never represented as current holdings.

Collection stopped after the requested subjects, all canonical rows and the
major contrary evidence were covered; additional repeated index searches would
not supply an unbiased execution dataset or overcome the documented access and
permission gaps. The result is a well-supported **testable strategy candidate**,
not fabricated proof of sustained profits.
