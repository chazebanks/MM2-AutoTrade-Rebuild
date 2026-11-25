# Gingerscope completion review

## Baseline

The public review starts at draft PR #323, branch `research/gingerscope-completion-sprint-nov25`, commit `bc467c1bfaff026b87e4b09979e1e9d581895bbc`. The immediate draft ancestors are #322 at `2b5706e738b052ae1c6c7db8759fc91b83aaf962`, #321 at `a3e923c1a9fa536350dfa8f83e334e46814a0282`, #320 at `386c28cfaf0cb748346bd445d7da11f4ce642a9b`, #319 at `bf9b0f236225e11b4b118eb47039296f9aae54d8` and #318 at `138c988403150b303516e380af1a62eb05886590`. Observed public main was `44268df1e3080b49aa9e586851867fd602a3ce1f`. The baseline has 13 successful PR workflows. Whole-system CI recorded 845 Python passes and one inherited skip, 126 intelligence passes and 61 native mock groups. [Draft PR](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/323) · [Baseline CI](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/45562295775)

The private V2 analyzer draft is stacked on the unmerged private ingress draft. The baseline analyzer passed eight synthetic tests. The private recovery checkpoint records exact private branch, revisions and workflow links. No V2 archive was present on private main at review.

The November 25 mandate and Supreme-only decision supersede older provider, timing and economic rules. The historical documents retain original observations. This review records present evidence and gaps. Runtime work involving Delta injection or automated access through MM2's internal interfaces is outside the implementation scope. Only the human-operated, offline analysis and evidence paths are candidates for changes here.

## Requirements matrix

| Area | Current evidence | Source and dependencies | Evidence or completion criterion |
|---|---|---|---|
| P1 boot, health, entry, classification, stop and duplicate ownership | IMPLEMENTED BUT UNTESTED as a complete current-candidate lifecycle | `loader.lua`, `core/health.lua`, `pdiddler1.lua`, versioned Part 1 files | Legacy entry/health components exist. Per-part historical evidence cannot certify the current complete startup/recovery sequence. Runtime integration is outside implementation scope. |
| P2 Tablet, join-friend Play, readiness | IMPLEMENTED BUT UNTESTED at this revision on the actual device | `pdiddler2.lua`, `pdiddler2_KNOWN_GOOD.lua`, historical P1–P3 stacks | Existing startup behavior has historical evidence. Current runtime availability and end-to-end initialization are unverified. |
| P3 inventory, unknown eligibility, contact/request lifecycle, player state, P3/P4 lease and return | NATIVE CLIENT VERIFIED for specific historical observations | Versioned `pdiddler3_scanner_*` and `pdiddler3_outgoing_*`, `supervised/supervised_p3_startup_supervisor.lua`, `supervised/supervised_real_p3_rotation_handoff.lua` | Protected succession and client census evidence exist. Exact authoritative counterparty inventory, unknown classification under every transition and compatibility across current runtime Parts remain unproven. |
| P4 two-sided observations, identity, stacks, revisions, manual acceptance, portfolio reconciliation | NATIVE CLIENT VERIFIED for specific historical observations | `new_part4/`, protected Stage101 and Stage119 handoffs, current C3/P4 research adapters | Observed GUI and client deltas support bounded claims. Session-bound server revision, authoritative item identities and independent settlement remain unproven. |
| P5 multitrade portfolio replay | OFFLINE VERIFIED | `system2/multitrade_growth_replay.py`, `system2/supreme_only_strategy_research.py`, `ci/test_multitrade_growth_replay.py` | The documented Part 5 is a simulation. It consumes explicitly supplied hypothetical alternatives. |
| P5 proposed operational session, disconnect and restart ownership | NOT IMPLEMENTED as a dedicated integrated Part | Legacy Part 1, P3/P4 coordination, `continuity/manager.py`, sanitized replay | Continuity records research progress. Protected local lease/replay evidence does not establish persistent game restart recovery. |
| P6 and other numbered references | OFFLINE VERIFIED for the reviewed tree | `continuity/NEXT_WORKPLAN_2026_11_11.json`, Part 5 roadmap, stage/title index | The historical workplan uses P1–P6 as phase labels for market, identity, strategy, feedback, shadow testing and release. P6 is planning and acceptance evidence. The reviewed source tree contains no separate P6 or higher operational Part entrypoint. |
| S2.1 current Supreme source, provenance, names, categories, demand, labels and ranges | OFFLINE VERIFIED for the reviewed edition | Nov 25 Supreme archive, `supreme_publisher_parity_2026_11_25.json`, `supreme_only_strategy_research.source_rows` | Direct recheck matched 189 valid priced weapons and 17 published range rows. The effective archive keeps its original expiry. An altered archive or parity receipt fails closed. |
| S2.2 inventory and portfolio accounting | INTEGRATED AND VERIFIED for manual holdings | `client_inventory_shadow.py`, `market_inventory_revision_gate.py`, `manual_portfolio_review.py`, Supreme rows | Exact publisher IDs, explicit unpriced copies, separate main and alt, combined wealth, eligible capacity and protection are verified offline. Actual native inventory authority remains open. |
| S2.3 bilateral economics and candidate generation | INTEGRATED AND VERIFIED for manual hypothetical stock | `manual_portfolio_review.py`, `supreme_only_strategy_research.py`, `supreme_only_bilateral_partner_friction_shadow.py`, legacy `counterparty_candidate_explorer.py` | The paper search covers zero to four copies in each of up to four physical slots and checks both evaluations. Larger total copy counts remain possible. Actual native stack behavior remains open. |
| S2.4 attractiveness and retradability | OFFLINE VERIFIED for hypothetical comparisons | Same Supreme evaluators, `attractiveness_evidence_lab.py` | Demand, both deltas, published stability and slot/copy burden remain separate. Empirical liquidity and actual acceptance require independently documented settled exchanges. |
| S2.5 growth, four-slot capacity, recycling and target protection | INTEGRATED AND VERIFIED for manually supplied paths | `manual_portfolio_review.py`, `supreme_only_strategy_research.review_paths`, `multitrade_growth_replay.py`, frozen Stage120 comparator | Successive paper balances are checked at each step. The report keeps total wealth, four-slot capacity, protected target copies and projected growth distinct. Multi-step paths are entered explicitly by the analyst. |
| S2.6 portfolio and listed loss risk | OFFLINE VERIFIED for policy and paper scenarios | `strategy/growth_policy.json`, `intelligence_lab/quality_loss_sensitivity.py`, manual range comparisons | Budgets remain null. Supported single-copy published ranges give bilateral endpoint sensitivity. Missing ranges and stack economics remain uncertain. Losing paths are excluded from feasible examples. |
| S2.7 learning and outcome attribution | OFFLINE VERIFIED for intake and abstention | `discord_v2_event_intake.py`, `private_v2_response_learning_gate.py`, `discord_shadow_engagement.py`, private analyzer | Request response, offer revisions, client indicators, cancels and unknown outcomes have separate evidence tiers. No verified settlement labels or stable distinct-player holdout. |
| S2.8 end-to-end intelligence | INTEGRATED AND VERIFIED for standalone analysis | `manual_portfolio_review.py`, `review_bilateral_batch`, `review_paths`, private aggregate analyzer | Standalone reports use one immutable edition and cross-check quantities and value deltas. The evidence pipeline abstains from real learning. Actual runtime and authenticated outcome integration remain open. |
| S2.9 native readiness and release | BLOCKED BY EXTERNAL DEPENDENCY | Historical C9 preview sources, source pin registry, `RELEASE_READINESS.json` | Separate offline mock successes, client reports, authoritative settlement and release approval. The original frozen host uses older source files. |
| Passive negotiation research | OFFLINE VERIFIED for controlled cases | `ci/test_system2_partner_intent_evidence_oracle.py`, passive intent handoff and existing tests | Targeted, unaddressed, ambiguous and unrelated language requires contextual evidence. A mention, silence or request decline does not establish intent. |
| Discord archive, persistence, privacy and reports | OFFLINE VERIFIED for synthetic transport and intake | Private `scripts/discord_v2_private_archive.py` and `scripts/private_v2_response_research.py`, public evidence gate | The private draft verifies duplicate and mutation checks, bounded atomic files, transport checks and aggregate-only responses. Recorded V2 evidence and independent game settlement remain absent. |
| Runtime interface, STOP/COPY, performance and recovery | NATIVE CLIENT VERIFIED for specific historical observations | On-screen policy, Stage116, Stage119, C9 GUI tests | Historical client checks and fixture results are evidence for individual behaviors. No new device observations or resource benchmarks in this candidate. |
| Legacy exclusion and permanent protection | OFFLINE VERIFIED for Supreme strategy research | Strategy playbook, growth policy, release and continuity gates | The manual workflow uses one Supreme archive, admits small paper gains and rejects outbound Gingerscope. Historical pricing and runtime rules remain archival evidence. |
| Development continuity and release evidence | OFFLINE VERIFIED for immutable anchors | `START_HERE.md`, `continuity/`, `RELEASE_READINESS.json` | Recovery references this matrix and active draft. Original anchors and the partial historical coverage classification remain available. |

## Ownership and dependency map

| Producer and owner | Interface | Consumer and compatibility evidence |
|---|---|---|
| P1 boot and P2 setup | Entry health and startup readiness | P3 startup gate. Legacy source and historical harnesses identify this sequence. No new live claim. |
| P3 scanner and request rotation | Client-observed inventory and one current request/session owner | Protected P4 boundary. Historical client receipts and offline mocks verify bounded transitions. |
| P4 trade observer | Two-sided client observation tied to session and offer revision | C3/P4 and C9 shadow adapters. The observer owns client observations. It has no authenticated settlement authority. |
| Supreme archive and source reader | Publisher edition, capture/expiry, immutable bytes and exact publisher identities | Standalone economic comparisons, fictional paths and manual inventory accounting. Publisher IDs are not proof of native item-instance identity. |
| Manual researcher | Two explicitly entered account holdings, hypothetical counterpart inventory and selected comparison scope | Offline paper report. The account records stay distinct. No game-side process consumes the report. |
| Portfolio and bilateral evaluators | Listed deltas, demand ordinals, known position concentration, physical slots and copy counts | Human review. Economic conservation is independently checked for both sides. Hypothetical results cannot create a transaction or a learning row. |
| Private V2 archive | Bounded, deduplicated client-reported envelopes with session/revision information | Private analyzer and public pure evidence gate. Only non-identifying aggregates return from the analyzer. |
| Evidence gate | Eligibility decision, denominators, exclusions, chronological digest holdout | Research review. No independently corroborated completed-trade source or real learner is established. |
| Continuity manager | Pinned project metadata, versioned research records, recoverable states | Future development and release review. Game inventory and session recovery are different responsibilities. |

## How to run the offline candidate

From the checkout, enter a local file named `portfolio.json` containing account holdings. The numbers below are synthetic. Use the exact case-sensitive category and publisher item ID from the archived catalog.

```json
{
  "accounts": {
    "main": {"godly:Fang": 1, "ancient:Harvester": 4},
    "alt": {"godly:Boneblade": 1}
  },
  "comparison": {
    "mainItemTypes": ["godly:Fang", "ancient:Harvester"],
    "counterpartyStock": {"godly:Boneblade": 1, "godly:Orange_Seer": 9}
  }
}
```

```sh
python3 -m pdiddler.system2.manual_portfolio_review portfolio.json --replay-at 2026-11-25T07:52:05Z
```

Omit `--replay-at` to use the current clock. The default archive expires November 25 at 7:09:59 a.m. New York time. A captured edition can be reviewed historically at a labeled replay time. The parity receipt records four actual HTTPS response hashes from 2:52 a.m. New York time, exclusions and ranges. The recheck leaves the earlier pinned archive and its expiration intact. The response bodies are outside the branch. [Supreme Values](https://supremevalues.com/)

`comparison` is optional. It enumerates an explicit shortlist and displays examples closest to listed parity and examples with the largest listed gain by physical shape and target inclusion. The paper shortlist is bounded to four copies of one item in one slot. The slot limit is four distinct item types per side. Capacity uses the known portion of one account. Unknown holdings remain unpriced and are excluded from compared bundles. Aggregate holdings span both accounts only for portfolio accounting.

An optional `growthPaths` array accepts two to twelve distinct paths, each containing two to eight steps. Every step has `give`, `receive` and `counterpartyStock` objects shaped like the holdings above. The reviewer supplies fictional counterpart holdings for each step. The evaluator rejects account shortfalls, unapproved losses and cycles before reporting an ending balance.

## Six independent measurements

| Dimension | Verified report and evidence limit |
|---|---|
| Listed inventory wealth | Separate main and alt balances and a combined known total. Incomplete valuation leaves the total unknown. Internal movements preserve aggregate value and do not establish realized growth. |
| Practical purchasing power | Single-copy and conservatively capped-stack four-slot listed capacity for each account. Counterparty preferences, actual settlement and unpriced assets remain unobserved. |
| Inventory market quality | Published demand and stability, largest known position share, and price-range sensitivity where available. The publisher treats these as descriptive indicators. [Supreme use guide](https://supremevalues.com/use) |
| Progress toward Gingerscope | Edition-specific target amount, owned protected copies, and separate four-slot gap. Existing target copies remain excluded from outbound packages while portfolio growth can continue. |
| Bilateral attractiveness | Independently conserved listed deltas, both sides' published demand and stability, physical burden and copy burden. A trade-board acceptance measures a response on that board. The board does not observe in-game settlement. [Trade-board methodology](https://mm2.rocks/methodology) |
| Reliability and inventory protection | Immutable market and range source receipts, source-clock checks, separate account ledgers, and unknown outcomes when corroboration is missing. |

## Evidence corrections and remaining gates

- Direct publisher HTML uses two item-cell formats. Chroma cards can show an abbreviated heading while providing the full exact item name in the item control. The parity check compared the publisher IDs and full names and excluded one priceless Ancient, two hidden Godly cards and seven Chroma pets.
- Legacy arithmetic could juxtapose total wealth and target price without describing whether the value fit in four slots. The manual report calculates both capacities and retains the account and protected-target distinctions. It checks both listed deltas, rejects economic disagreement and reports unavailable price-range estimates as unknown.
- Private analysis and ingress originally accepted duplicate JSON fields. The reviewed private changes reject duplicate fields and symlinked or non-regular archives, enforce a bounded read, deduplicate exact replays before the unique-record cap, and reject settlement or model signals that contradict the evidence gate. The private tests use fabricated input only.
- Passive negotiation retains source attribution and revision context. An indirect or unaddressed remark, a quoted item name, sarcasm, an unrelated public exchange or a changed preference needs context. Existing tests cover bounded attribution, variant mentions, replay and revisions. There are no independently labeled reliability estimates for ambiguous or sarcastic messages.
- The full software, supervised runtime and release milestones remain open. Independent two-sided exact transaction evidence and an applicable supported runtime are indispensable for those claims. Real learning requires verified offer-level and outcome labels, distinct-player and temporal controls and a credible evaluation set. Null loss budgets provide no permission to accept listed losses.

## Regression evidence and rollback

The standalone Python tests include source tampering, expiry and future timestamps, exact variants, unpriced inventory, separate accounts, a protected outbound target, stack and slot cases, bilateral conservation, contradictory component results, multi-step reconciliation and price-range gaps. The focused local regression passed 248 tests, including 20 new manual cases and the inherited Hypothesis replay. The full four-by-four shortlist check examined 389,376 pairs and exercised upgrade, downgrade and sidegrade examples. A real Lune 0.11.1 smoke run loaded the inherited pure health and historical fixture modules. That fixture's prices are outside the Supreme candidate.

Both private offline preflight workflows passed on the reviewed private draft. A local combined private run passed 26 tests. The absence of V2 receipts still produces no learning. The original November 11 documentation scope assertion passes against its immutable original implementation at `8a5ab3073f850b1fa2eb40184a2fbf72d61856c4`. The current sprint's separate source diff check enforces its small offline allowlist.

The baseline `bc467c1bfaff026b87e4b09979e1e9d581895bbc` is the rollback reference for this standalone research change. The strategy evaluator, bilateral comparator, source archive, manual entrypoint and new source receipt have blob anchors in `continuity/manifest.json`. Use the following draft and checks for exact-head verification. [PR #323](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/323) · [Public Actions](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions)
