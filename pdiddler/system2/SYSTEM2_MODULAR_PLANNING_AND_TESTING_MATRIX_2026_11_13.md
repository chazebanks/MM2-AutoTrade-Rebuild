# Gingerscope System 2 — modular planning + testing program (started Nov 13–14, 2026)

**System 2 is the growth/strategy/decision-learning layer, not merely the inventory data plumbing.** The operator explicitly wants multiple independently tested functional parts, like System 1, before the end-to-end native testing phase. **Do not confuse completion of System 2 source parsing with a finished strategy.**

**Current research branch:** `research/system2-nov13-multipart-strategy-sim`, stacked on #254 → #253 → #252 → #251 → #250. All research PRs draft. `main`/protected existing P3/P4, original offering, Accept and Discord code unchanged.

## Component and test roadmap

| Stage | Functional subsystem | Tests that must pass before progressing | State |
|---|---|---|---|
| S2.1 | Publisher/catalog and immutable 189-price import | 199 discovery, 189 exact historical ID matches, independent 189-field first-party parity, no catalog exceptions promoted | **Offline verified** on drafts #250–252; new edition/expiry not production verified |
| S2.2 | Raw-key market lookup and own inventory observation | Exact raw key, Chroma, quantity stacks, aliases, client census, known exclusions, reject legacy October 31 prices, strict no-authority | **Offline verified** 122/122 tests in #254; real new client inventory witness not run |
| S2.3 | Bilateral trade scenario evaluation | 4 physical slots vs stacks, available copies, positive/zero/negative listed gain, range downside, upgrades/downgrades, incoming target, never offer owned Gingerscope outbound | **Implementation and adversarial synthetic testing started in this branch** |
| S2.4 | Counterparty attractiveness and resale desirability | Compare source demand/stability/ranges and inventory concentration; independently observed successful retrades, time-to-fill and partner refusals separately from posted offers; no invented probabilities | **Not implemented/verified**; no empirical liquidity/trade sample yet |
| S2.5 | Multi-step growth planning toward 16,000 Gingerscope | Compare compounding gains, upgrade/downgrade recycling, path quality/risk, opportunity cost, 4-slot constraints, target protection and alternative paths | **Not implemented/verified**; do not extrapolate single-trade scenario to multistep learning |
| S2.6 | Controlled loss policy and risk budget | Conservative no-loss alternatives first; explicit per-trade + cumulative budget, concrete verified quality improvement, source age, account and risk-stop gates | **Policy written**, but `pdiddler/strategy/growth_policy.json` expressly says `deploymentAuthorized=false`, **all numeric budgets NULL/unapproved** |
| S2.7 | Learning from observed outcomes | Record `ACCEPT`, `DECLINE`, `CANCEL`, `UNKNOWN` without conflating them with server settlement; immutable before/after item identity and verified completed trades only for realized profit labels; replay/reject spurious webhooks | **Not implemented/verified** |
| S2.8 | End-to-end supervised replay | Multiple sequential hypothetical trades, competing counterparty offers, two-sided revision changes, independent property tests, controlled fail/restart, source-version/JobId/partner changes | **Not implemented/verified** |
| S2.9 | Actual native iPad tests and deployment review | Current client inventory witness, read-only strategy previews, guarded P3/P4 offer tests, final settlement/Accept proof, repeated safe failures, explicit user authorization | **Not yet authorized**; no new native run or autonomous Accept |

## Working rules
1. One **distinct issue** at a time, but test every System 2 subsystem and test them *together* rather than stopping after a single inventory integration.
2. Reuse **original frozen Stage120** planner `future_portfolio_planner.py` Git blob `78948cdacd2a760db5b888fce242d598fc6f14b6` at `6ed48e084bd58fab38e3bf061ac36fb295ecf103`, and **corrected** PR182 guard `offer_snapshot_guard.py` blob `11db895622d053ddced4fba9666135bf97bd615b` at `94ecefee86fd36293dcac58d0c24d9f379e719e5`. Don't confuse original Stage120 synthetic tests with real market authority. The original PR106 planner has a **4 total-copy** enumeration limit even though corrected guard accepts stacks >4 across 4 physical slots.
3. Price numbers come solely from the immutable 189-item **operator export** through offline adapter, SHA256 `bb91b545637a0fe8d7dcceebef9070ee9a76210015bdc1737fd78f068acaeb4f`. Never commit private full export to public GitHub. The original `publisherVersion:null` remains unverified for live quoting.
4. Original `pdiddler/strategy/growth_policy.json` **forbids controlled-loss execution pending an independently validated and explicitly approved risk budget**. Positive hypothetical gain can be +5: old mandatory +15 and forced high-value first offer are superseded.
5. Supreme demand scores and stability labels are **descriptive** and cannot become measured resale liquidity or acceptance probability. The ability to calculate a paper value gain alone cannot prove a feasible or attractive trade.
6. Incoming Gingerscope can be evaluated, owned Gingerscope never leaves inventory. Trade-only events never authorize final Accept/Discord profit/learning unless separately proved completed.
7. No changes to the separate Matrix Hub PC Lua project in this repo.

## Current S2.3 new experiment
- `pdiddler/system2/trade_scenario_lab.py`: purely deterministic research comparison against the prior read-only client inventory shadow, exact 189 historical raw key candidates, own-copy counts, 0–4 outgoing and 1–4 incoming **physical slots**, arbitrary supported stack counts. Reports listed gain, worst/best value-range delta, preview-only before/after portfolio, category description, demand ordinal scores, target receiving and risk warnings.
- **Losses are never executable**: `OFFLINE_LOSS_SCENARIO_BLOCKED_POLICY`. All outputs remain research-only and explicitly deny trade, offer, Accept, settlement, Discord profit and training authority.
- `pdiddler/ci/test_trade_scenario_lab.py`: 33 adversarial/offline tests: +/-5, 2→1 upgrade, 1→2 downgrade, protected Gingerscope, zero outgoing gift, 4-vs-5 physical slots, 6-stack one physical slot, unknown/duplicate/insufficient ownership, source/shadow poisoning, no false demand→liquidity inferences, range caution.
- Dedicated new CI must rerun 33 plus previous **122** System2 tests and the original Stage120 **16** frozen-component tests, requiring actual immutable source fetches and no skips. Nominal **171 tests**. CI exact head must be checked before claiming pass.

## Stop conditions and next one stage
- No iPad activity until this scenario/Stage120 integration suite passes with actual original-source checks; any failure is investigated and documented, not hand-waved.
- After S2.3 passes, begin S2.4 attractiveness/desirability modeling with **evidence status separated from heuristic descriptions**; test high-listed-value low-demand traps, unstable risk, smaller profitable recycling, and negative-attractiveness upgrades. Keep empirical liquidity UNKNOWN until independently observed fills exist.
- Then S2.5 multi-step planner, and thereafter S2.6–S2.9. This document is the user's requested **actual multi-part planning/testing roadmap**, not a claim those later systems are already built.
