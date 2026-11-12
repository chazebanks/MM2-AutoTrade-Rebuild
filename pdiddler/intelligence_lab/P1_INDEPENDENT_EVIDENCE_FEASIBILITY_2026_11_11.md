# P1 source-free first-party market observations — identifiability feasibility
**November 11, 2026; research-only, no trader or real observation input**

## Decision and reason

The operator does **not want any outside value-list publisher contacted or informed about Project Gingerscope**. Do not send a message, email, Discord DM, API-key application, scraping request or repository link to Supreme Values, BloxSwaps, RBLXValue, or similar publishers, unless the operator explicitly changes this instruction.

The existing public value-list investigation in PR236 established that we should not assume a current copyright/reuse permission from publicly viewable Supreme-derived lists. This does not mean no method exists to *learn a new independent relative-value model* through the bot's own lawful, consent-based MM2 trade observations. It means an external price authority cannot be silently replaced with stale third-party data.

A critical flaw in the naive "just learn values from our own offers" plan is **identifiability**. A posted, suggested, declined or client-observed offer is not an executed trade. Even real executed barter exchanges do *not* mathematically prove that the parties' item bundles had equal fair market value; each side values bundles differently. Very sparse actual exchanges also leave many items disconnected or underdetermined, and all inferred values have arbitrary scale without an independent anchor. Claimed demand, "high" confidence and USD resale listings are not acceptance probabilities or verified fills.

We tested the following exact **structural question only**:

> If hypothetical bundles had linear exchange-value equality, and **one entirely arbitrary test reference item were fixed to unit 1**, do the available hypothetical equations have sufficient independent rank to determine every other synthetic relative item value?

This question is necessary but **not sufficient** for market price modeling. No full-rank synthetic fixture licenses a live quote or proves real equality.

## New offline feasibility module

- Code: `pdiddler/intelligence_lab/p1_independent_market_feasibility.py`.
- Tests: `pdiddler/ci/test_p1_independent_market_feasibility.py` (17 mock cases).
- All inputs are **HYPOTHETICAL_ONLY**, IDs must start `TEST_`; no live player name, Roblox internal key, inventory, webhook, Discord or observed trade can be submitted. One event may have up to **four physical slots per side**, while stacked quantities greater than four are permitted. Duplicate slots/events and invalid quantities are rejected. This is a synthetic exercise, not a feed/parser or proof extractor.
- Uses exact rational Gaussian elimination to report constraint rank, rank after setting one arbitrary test reference item to 1, and which synthetic relative keys remain underdetermined.
- Outputs **no numeric price estimates**. It always states `realVerifiedSettlementCount=0`, `absoluteMarketScaleIdentifiable=false`, `barterEqualityAssumptionUnproven=true`, `tradeOutcome=UNKNOWN`, `priceEstimates=null`, `mayAdvanceP2=false` and all production/trade/Accept/learning authorizations false.

## Synthetic examples and what they reveal

| Hypothetical evidence | What structurally follows with arbitrary anchor A | What does **not** follow |
|---|---|---|
| No event | Zero constraints, no current independent market model | No measured demand, value or liquidity |
| A swapped for B | One relative constraint and A-unit reference is enough to locate B *under equality hypothesis* | Absolute market price or fair value of B |
| A↔B, B↔C, 2C↔D | Three independent constraints plus arbitrary A-unit reference imply four relative quantities under assumed exact linear equalities | Whether actual buyers would accept any of these swaps |
| A↔B, C↔D | The C-D subgraph is disconnected from the A anchored subgraph | Prices for C or D in A units |
| 2A↔B+C | One equation cannot separately identify B and C | Attribution of a bundle's market premium to either item |
| Same A↔B recorded twice | Duplicated evidence adds no independent equation | Greater coverage or accuracy |

**Consequences for Gingerscope:** even with a huge hypothetical transaction count, value learning needs different combinations that form a connected, informative system. We currently have **0 proven real completed trades**, so none of this can update market prices today. Part3/Part4 Stage119 remains client-only and outcome UNKNOWN; existing 50 webhook rows are not independent settlement proof (30 tests, 17 unverified, 3 quarantined). Do not relabel them to generate training data.

## Clean future path with no third-party outreach

1. A separate future private, consent-based evidence mechanism must independently corroborate actual in-game settlement, exact account/session/revision, both parties' item keys and stacked quantities. This is **not** implemented or approved here.
2. Build a **private-only, source-signed dataset** with explicit incomplete/unknown outcomes and evidence quality. No publication of usernames, inventories, IDs or user logs in this public repo; no unverified Discord claims.
3. When enough independently settled, diverse barter rows exist, use a noisy robust inequality/utility model rather than pretend every swap is exactly fair. Independently test it on time-separated held-out confirmed fills and real rejection denominators; identify market regime shifts and selection bias.
4. Ask the operator separately before developing or activating live evidence collection; current workplan remains **P1 blocked**, price source independent and no live trade actions.

**No publisher outreach made. No API credentials, web scraping, direct MM2 device activity, live Lua changes, price file edits, real-trade proof, market-data admission, unattended trade, automated final Accept or webhook learning has been authorized.**
