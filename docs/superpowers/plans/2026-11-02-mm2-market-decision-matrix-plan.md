# MM2 v2.6 Offline Market Decision Matrix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and validate a pure-Luau market-aware decision engine against the approved 14-case matrix without modifying the live v2.5 Part 4 trader.

**Architecture:** Keep the active scanner and v2.5 Part 4 untouched. Create a frozen candidate market-profile module keyed by canonical `page:id`, then a pure decision module with no GUI/remotes/Roblox-state dependencies. A standalone Delta-compatible matrix runner loads only those test modules and verifies the approved decisions. Live Part 4 integration is explicitly deferred until this plan passes.

**Tech Stack:** Luau, GitHub raw-module loading for the standalone test runner, existing v6.8 canonical scanner IDs/MM2Values snapshot, frozen Supreme/MM2Values market snapshot.

**Spec:** `docs/superpowers/specs/2026-11-02-mm2-market-aware-planner-design.md`

## Global Constraints

- Do not modify Parts 1-3.
- Do not modify `pdiddler/pdiddler4_balancer_ROTATING_v2_3_EXTREME_GUARD.lua`.
- Do not modify `pdiddler/pdiddler_EXTREME_GUARD_TEST_STACK_v2_5.lua`.
- Do not modify the frozen audit snapshot `pdiddler/pdiddler_market_snapshot_2026-11-02_AUDIT_v2_COMPLETE.lua`.
- Scanner identity, canonical ID/page, quantity, and MM2Values value remain authoritative.
- Supreme data is market context/cross-check only; never a second identity resolver.
- No live HTTP request inside an active trade.
- Never average MM2Values and Supreme.
- Missing/invalid market metadata must not default to Stable or receive positive quality credit.
- Existing raw profit floors remain minimums: Normal `max(15, 3%)`, Downgrade `max(20, 6%)`, Big Downgrade `max(30, 8%)`.
- Controlled quality-upgrade raw loss remains capped at 3%.
- FINAL ACCEPT remains disabled; this plan creates no trade executor code at all.
- No test may depend on MM2 GUI timing, remotes, PlayerGui, replication, or another player.

## Pinned Market Rules for the Offline Model

These values are implementation candidates to be validated by the matrix. If any matrix case proves them wrong, adjust the rule deliberately and document the reason before proceeding.

**Material source disagreement**
- Material only when BOTH:
  - absolute MM2Values/Supreme difference >= 25, and
  - percentage difference relative to MM2Values >= 5%.
- If material:
  - OUR protected unit value = `max(mm2Value, supremeValue)`
  - THEIR protected unit value = `min(mm2Value, supremeValue)`
- If not material, protected unit value = MM2Values baseline.
- If Supreme has no numeric value (for example a "Priceless" label), protected unit value remains MM2Values and numeric disagreement is unavailable.

**Demand score**
- demand <= 2: -2
- demand 3-4: -1
- demand 5: 0
- demand 6-7: +1
- demand >= 8: +2

**Stability score**
- Underpaid For: -2
- Fluctuating: -1
- Stable: 0
- Doing Well: +1
- Overpaid For: +2
- Unknown/unprofiled: 0, but confidence=false and positive upgrade credit is forbidden.

**Item exit score**
- `demandScore + stabilityScore - (materialDisagreement and 1 or 0)`
- Bundle exit score is MM2Values-value-weighted across eligible copies.
- Unprofiled items participate in raw value but mark bundle confidence=false.

**Downgrade risk points per received item**
- demand <=2: +2
- demand 3-4: +1
- Underpaid For: +2
- Fluctuating: +1
- material disagreement: +1
- unprofiled/invalid profile: +2
- Weighted bundle risk uses MM2Values value as the weight.
- Extra downgrade premium = `min(10%, weightedRiskPoints * 2%) * OUR protected value`.
- This premium may only increase the existing v2.5 raw floor, never reduce it.

**Controlled quality upgrade**
- Kind must be UPGRADE (we give more eligible copies than we receive).
- Raw MM2 loss <= 3% of OUR raw MM2 total.
- THEIR bundle must have verified profiles for all eligible copies.
- Neither side may contain a material list disagreement for this exception.
- THEIR exit score - OUR exit score >= 2.0.
- Protected-value profit must be >= 0.
- A real-profit plan with comparable-or-better exit quality wins over this exception.

**Plan ranking window**
- First reject every plan that fails hard safety.
- Real profit ranks above controlled quality-upgrade loss.
- Treat raw-profit differences as "similar" only inside:
  `min(25, max(5, THEIR raw MM2 total * 0.02))`.
- Inside that window, prefer giving away the lower-exit-quality OUR bundle, preserving stronger future inventory.
- Outside that window, preserve v2.5 behavior: prefer the highest safe OUR raw offer (closest acceptable profitable offer).
- Fewer disputed/unprofiled pieces break otherwise-equal ties.

## Review Focus

1. A malformed profile with strings/nil numeric fields must fall back to canonical MM2 raw safety and never throw.
2. Duplicate copies of one canonical item must weight quantity correctly without creating duplicate identity keys.
3. A bundle with zero MM2 raw value must avoid division-by-zero and cannot qualify for positive quality credit.
4. Supreme value present but demand/status missing must be treated as incomplete confidence, not fully verified quality.
5. Material disagreement must be side-aware: the same item must protect OUR side high and THEIR side low.

---

### Task 1: Create the candidate market profile module and coverage audit

**Files:**
- Create: `pdiddler/pdiddler_market_profile_2026-11-02_v1_CANDIDATE.lua`
- Create: `pdiddler/tests/pdiddler_market_profile_audit_v1.lua`
- Reference only: `pdiddler/pdiddler_market_snapshot_2026-11-02_AUDIT_v2_COMPLETE.lua`
- Reference only: `pdiddler/pdiddler3_scanner_MODULE_v6_8_CRITICAL_PAUSE.lua`

**Interfaces:**
- Produces `profile.get(page: string, id: string) -> table? `
- Produces `profile.coverage() -> {ancient:number, chroma:number, godly:number, total:number}`
- Produces immutable-by-convention profile records with `page,id,name,mm2Value,supremeValue,supremeLabel,demand,stability,profiled,verified,disagreementPct`.
- The module has `liveReady=false` throughout this plan.

- [ ] **Step 1: Write the failing coverage audit**
  - Assert exact counts 16 Ancient, 46 Chroma, 128 Godly, 190 total.
  - Assert 190 unique `page:id` keys.
  - Assert every candidate MM2 value equals the active v6.8 scanner MM2 value.
  - Assert known mappings: Ancient 1027 = Emberscythe 300/375; Chroma 1033 = Chroma Mortal 1800/1600; Godly 23 = Candy 90/80.
  - Assert no duplicate canonical key.
  - Assert `liveReady == false`.

- [ ] **Step 2: Verify the audit cannot pass before the candidate module exists**
  - Run the audit through a temporary Delta loader that attempts to load the missing candidate raw file.
  - Expected: explicit module-load failure, not a false PASS.

- [ ] **Step 3: Create the candidate profile module**
  - Copy the verified 190 records from the frozen audit snapshot without changing the frozen file.
  - Add exact `get` and `coverage` interfaces.
  - Preserve source timestamps.
  - Keep `liveReady=false`.

- [ ] **Step 4: Run the coverage audit**
  - Expected: all coverage/identity/value assertions PASS.
  - If a row fails, fix the candidate copy only after comparing scanner + frozen audit snapshot; never silently normalize a mismatch.

- [ ] **Step 5: Commit**
  - Commit message: `test: add complete candidate market profile audit`

### Task 2: Build the pure market evaluator with TDD

**Files:**
- Create: `pdiddler/pdiddler4_market_logic_v1_TEST.lua`
- Modify: `pdiddler/tests/pdiddler_market_profile_audit_v1.lua` only if a malformed-profile fixture needs reusable construction.

**Interfaces:**
- Consumes `profile.get(page,id)`.
- Produces:
  - `M.materialDisagreement(mm2Value, supremeValue) -> boolean, absDiff, pctDiff`
  - `M.itemAssessment(item, side, profileRecord) -> assessment`
  - `M.bundleAssessment(items, side, profileLookup) -> assessment`
- `side` is exactly `"ours"` or `"theirs"`.
- An item input is `{page:string,id:string,name:string,value:number,qty:number}`.
- A bundle assessment exposes at least:
  `rawTotal, protectedTotal, eligibleCopies, exitScore, riskPoints, confidence, materialDisagreementValue, unprofiledCopies`.

- [ ] **Step 1: Write failing evaluator tests**
  - 300 vs 375 => material=true.
  - 5 vs 7 => material=false because abs difference <25.
  - Chroma Mortal 1800 vs 1600 => material=true.
  - Emberscythe on OUR side => protected 375.
  - Emberscythe on THEIR side => protected 300.
  - Missing profile => protected baseline MM2, confidence=false, no positive status/demand score.
  - Malformed profile => same safe fallback, no exception.
  - Duplicate qty=2 => totals/weighting exactly doubled.
  - Zero raw bundle => exitScore safe default 0 and confidence=false/neutral; no division error.
  - Supreme numeric value with missing demand/status => confidence=false.

- [ ] **Step 2: Verify the new tests fail**
  - Expected: missing module/functions.

- [ ] **Step 3: Implement the minimal evaluator**
  - Implement only the pinned formulas in this plan.
  - Do not include trade classification, plan ranking, remotes, GUI code, timers, or network calls.

- [ ] **Step 4: Run evaluator tests**
  - Expected: every Task 2 assertion PASS.

- [ ] **Step 5: Commit**
  - Commit message: `feat: add pure market assessment model`

### Task 3: Implement trade-decision rules against the approved matrix

**Files:**
- Modify: `pdiddler/pdiddler4_market_logic_v1_TEST.lua`
- Create: `pdiddler/tests/pdiddler4_market_logic_matrix_v1.lua`

**Interfaces:**
- Produces:
  - `M.requiredProfit(ourBundle, theirBundle) -> required:number, kind:string, baseRequired:number, marketPremium:number`
  - `M.tradeDecision(ourBundle, theirBundle) -> decision`
- `decision` exposes:
  `ok,kind,mode,rawProfit,protectedProfit,requiredProfit,baseRequired,marketPremium,qualityGain,reason`.

- [ ] **Step 1: Write the 14 approved matrix cases as failing assertions**
  - Case 1: same raw / weaker THEIR exit quality => reject.
  - Case 2: 2-item weak OUR 100 -> 1-item verified stronger THEIR 98-100 => only pass as `quality-upgrade` when all upgrade conditions hold.
  - Case 3: stable OUR 100 -> three weak/Underpaid THEIR pieces totaling 130 => reject marginal +30 because market premium raises requirement above 30.
  - Case 4: Emberscythe list disagreement => OUR protected 375, THEIR protected 300.
  - Case 5: equal raw Stable vs Fluctuating Ember-family received item => Fluctuating trade requires more compensation / cannot receive positive upgrade preference.
  - Case 6: OUR 230 vs THEIR 270 otherwise safe => `ok=true`, normal profitable hold candidate.
  - Case 7: OUR 20 vs THEIR 105 => `ok=true`; expose enough decision data for existing EXTREME GUARD to classify later. Do not implement executor behavior here.
  - Case 8: first decision safe, replacement THEIR bundle lower => second decision recomputed independently and may fail/reduce; no cached decision state.
  - Case 9: missing metadata => raw safety works; confidence=false; no quality-upgrade exception.
  - Case 10: strong+weak mixed bundle => weighted risk includes the weak pieces; strong item cannot erase risk.
  - Case 11: equal/similar raw candidate inputs expose ranking data for Task 4.
  - Case 12: 5 vs 7 source difference => no material-disagreement penalty.
  - Case 13: Chroma Mortal 1800 vs 1600 => material protection applied.
  - Case 14: unknown/ambiguous market identity => canonical MM2 baseline only; no guessed profile.

- [ ] **Step 2: Verify the matrix fails on missing decision functions**
  - Expected: explicit function/assertion failures, not test-runner crash.

- [ ] **Step 3: Implement `requiredProfit`**
  - Preserve existing copy-count classification for NORMAL / DOWNGRADE / BIG DOWNGRADE / UPGRADE.
  - Compute base floor from OUR protected value.
  - Apply extra market premium only when receiving more/weaker inventory as defined above.
  - Never lower the base floor.

- [ ] **Step 4: Implement `tradeDecision`**
  - Require both raw MM2 safety and protected-value safety for normal profit.
  - Implement the controlled quality-upgrade exception exactly as pinned above.
  - Return explicit failure reasons such as `raw-underpay`, `protected-underpay`, `weak-downgrade-premium`, `upgrade-confidence`, or `upgrade-quality-insufficient`.

- [ ] **Step 5: Run all 14 matrix cases**
  - Expected: 14/14 PASS with no network/UI/remotes.

- [ ] **Step 6: Commit**
  - Commit message: `feat: validate market-aware trade decisions`

### Task 4: Add deterministic candidate-plan ranking tests

**Files:**
- Modify: `pdiddler/pdiddler4_market_logic_v1_TEST.lua`
- Modify: `pdiddler/tests/pdiddler4_market_logic_matrix_v1.lua`

**Interfaces:**
- Produces:
  - `M.rankPlans(plans, theirBundle) -> sortedPlans`
- Each plan must provide:
  `mode,rawTotal,rawProfit,protectedProfit,givenExitScore,disputedCopies,unprofiledCopies,picks`.

- [ ] **Step 1: Write failing ranking assertions**
  - Profit plan beats quality-upgrade plan.
  - Outside the similarity window, higher safe OUR raw offer ranks first.
  - Inside the similarity window, plan giving away lower-exit-quality OUR inventory ranks first.
  - Equal plans prefer fewer disputed copies.
  - Then fewer unprofiled copies.
  - Quantity alone never improves rank.
  - Deterministic final tie-break uses canonical pick IDs, so repeated runs produce identical ordering.

- [ ] **Step 2: Verify ranking tests fail**
  - Expected: missing `rankPlans`.

- [ ] **Step 3: Implement ranking**
  - Use exactly the similarity window formula in Global Constraints.
  - No random tie-breakers and no table-iteration-order dependence.

- [ ] **Step 4: Run full matrix plus ranking suite**
  - Expected: all previous cases remain PASS and ranking assertions PASS.

- [ ] **Step 5: Commit**
  - Commit message: `feat: add deterministic market-aware plan ranking`

### Task 5: Verification, evidence, and handoff update

**Files:**
- Create: `pdiddler/MARKET_MATRIX_RESULTS_v1.md`
- Modify: `pdiddler/CHATGPT_HANDOFF.md`
- Do not create or modify a live Part 4 integration file in this task.

**Interfaces:**
- Consumes the candidate profile, pure market logic, and test runner.
- Produces a permanent evidence record of matrix outcomes and exact commits.

- [ ] **Step 1: Run the complete standalone test runner from a fresh session**
  - Use the committed raw URLs for the exact candidate-profile and market-logic revisions, not mutable `main` URLs for the final evidence run.
  - Expected: profile audit PASS, evaluator tests PASS, 14/14 matrix PASS, ranking tests PASS.

- [ ] **Step 2: Re-run the highest-risk cases individually**
  - Material disagreement: Emberscythe and Chroma Mortal.
  - Weak +30 downgrade.
  - Missing/malformed profile.
  - Controlled <=3% upgrade.
  - Moderate +40 opponent overpay.
  - Low-tier 5 vs 7 disagreement.
  - Expected: exact same decisions as full run.

- [ ] **Step 3: Static regression review**
  - Confirm no changes to Parts 1-3.
  - Confirm no changes to current v2.5 Part 4/test stack.
  - Confirm candidate profile still `liveReady=false`.
  - Confirm no `AcceptTrade`, final Accept click, GUI/remotes, or network code exists in the pure market module.
  - Confirm no fuzzy identity lookup exists.
  - Confirm all profile lookup keys are canonical `page:id`.

- [ ] **Step 4: Write `MARKET_MATRIX_RESULTS_v1.md`**
  - Record each case input, expected result, actual result, PASS/FAIL, market snapshot timestamps, and exact GitHub commit IDs.
  - Clearly state any rule that was adjusted during TDD and why.

- [ ] **Step 5: Update `CHATGPT_HANDOFF.md`**
  - Record the final offline-model commit, test-runner commit, matrix result, unresolved assumptions, and the explicit statement:
    `LIVE PART 4 INTEGRATION HAS NOT STARTED.`

- [ ] **Step 6: Commit**
  - Commit message: `docs: record market matrix verification`

## Stop Condition

Stop after Task 5 even if every test passes.

Do **not** wire the market module into v2.5 in this plan.

The next project step must be a separate integration design/plan that:
- diffs the passing pure functions against the exact v2.5 planner extension points,
- preserves executor/recovery/timer behavior,
- creates a new Part 4 version file instead of overwriting v2.5,
- keeps FINAL ACCEPT disabled,
- runs v2.5 regression cases before any live public-server test.

## Self-Review

- **Spec coverage:** All 14 approved matrix cases are explicitly assigned to Task 3; ranking behavior is pinned in Task 4; missing/malformed/stale-quality conditions are covered; live integration is intentionally excluded per the design's matrix-first requirement.
- **Step scan:** Every implementation step names an exact function/interface or assertion target. No task asks the implementer to invent a second identity/value system.
- **Type consistency:** `profile.get` feeds `itemAssessment/bundleAssessment`; those feed `requiredProfit/tradeDecision`; plan records feed `rankPlans`.
- **Review Focus:** All five listed failure classes have explicit Task 2 or Task 4 tests.
- **Proportion:** This plan specifies decisions and test contracts, not function bodies. The live executor is excluded to avoid mixing planner validation with integration risk.
