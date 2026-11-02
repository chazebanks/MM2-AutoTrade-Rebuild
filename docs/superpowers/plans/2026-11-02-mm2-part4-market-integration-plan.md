# MM2 v2.6 Part 4 Market-Aware Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate the validated market profile and decision engine into a new Part 4 planner while preserving all known-good v2.5 execution, recovery, timing, and ownership behavior.

**Architecture:** The combined v2.6 stack injects a promoted 190-item market profile and the validated pure market engine into a new Part 4 via `part4.run(scanner, marketProfile, marketLogic)`. Part 4 keeps all MM2 UI/executor code from v2.3, removes the old multiplier market layer, and delegates market assessment, decisions, and final plan ordering to the validated market engine.

**Tech Stack:** Luau/Roblox, Delta iPad executor, GitHub-pinned raw modules, existing v6.8 scanner, outgoing v15, validated pure market engine.

**Spec:** `docs/superpowers/specs/2026-11-02-mm2-part4-market-integration-design.md`

## Global Constraints

- Never modify Parts 1-3 known-good files.
- Never overwrite `pdiddler4_balancer_ROTATING_v2_3_EXTREME_GUARD.lua`.
- Never overwrite `pdiddler_EXTREME_GUARD_TEST_STACK_v2_5.lua`.
- Scanner canonical page/id/MM2Values remains identity/value authority.
- Market profile lookup is exact `page:id`; no fuzzy fallback.
- No live market HTTP during a trade.
- There must be one market planner authority; old `MARKET_QUALITY`/multiplier logic is removed from the new Part 4.
- Preserve opening one highest-value eligible item.
- Preserve accepted-empty immediate decline.
- Preserve 15s empty and 60s Case 3 timers.
- Preserve transaction generation, signature invalidation, TX ABORT, remove verification, bounded retry, recovery and protected hold.
- Preserve EXTREME thresholds: ratio 2.0, flat 50, required multiple 2.5, minimum upward step 5.
- FINAL ITEM-TRADE ACCEPT remains disabled.
- The first v2.6 stack is a test build, not a frozen final build.

## Review Focus

1. Eligible resolved item lacks a profile: it must become unprofiled/neutral, never fake Stable, and must not break signature/executor logic.
2. Ineligible visible slots must stay raw zero and must not poison market confidence or eligible-copy counts.
3. Same raw total but different protected value must remain separate DP states so source disagreement cannot discard a safer plan.
4. Same raw/protected state with different inventory quality must deterministically keep the weaker OUR inventory for giving away.
5. Market dependency failure must fail Part 4 arm before any item is offered.

---

### Task 1: Promote the validated market profile without changing rows

**Files:**
- Create: `pdiddler/tests/pdiddler_market_profile_promotion_v1.lua`
- Create: `pdiddler/pdiddler_market_profile_2026-11-02_v1_VALIDATED.lua`

**Interfaces:**
- Produces `marketProfile.get(page,id)`.
- Produces `marketProfile.coverage()`.
- `liveReady=true`.
- Same 190 row fields/values as candidate.

- [ ] Write failing promotion test comparing all candidate profile rows and metadata fields that affect decisions.
- [ ] Run RED with validated profile missing.
- [ ] Create validated profile by exact candidate copy plus validation metadata and `liveReady=true`.
- [ ] Run GREEN: 190/190 identical decision rows; no missing/extra/duplicates.
- [ ] Commit: `feat: promote validated MM2 market profile`.

### Task 2: Create market-aware Part 4 dependency boundary and side assessment

**Files:**
- Create: `pdiddler/pdiddler4_balancer_ROTATING_v2_4_MARKET_AWARE.lua`
- Create: `pdiddler/tests/pdiddler4_market_integration_static_v1.lua`

**Interfaces:**
- `M.run(scanner, marketProfile, marketLogic)`.
- `evaluateSide` retains raw/signature/count behavior and adds `out.market`.
- Current market decision wrapper returns validated engine result plus compatibility fields for EXTREME/logging.

- [ ] Write RED static/integration assertions:
  - new file absent,
  - old `MARKET_QUALITY`/exactQuality logic must not remain,
  - dependency assertions required,
  - `evaluateSide` must use exact page/id market bundle,
  - no AcceptTrade/final Accept.
- [ ] Run RED.
- [ ] Copy v2.3 into new file and make only dependency/evaluateSide/decision-layer edits.
- [ ] Run GREEN static assertions.
- [ ] Commit: `feat: inject validated market engine into Part 4`.

### Task 3: Replace planner DP and ranking with market-aware state

**Files:**
- Modify: `pdiddler/pdiddler4_balancer_ROTATING_v2_4_MARKET_AWARE.lua`
- Create: `pdiddler/tests/pdiddler4_market_planner_integration_v1.lua`

**Interfaces:**
- `makeUnits` carries page/id/raw/protected/exit/dispute/confidence metadata.
- DP key separates raw and protected totals.
- Equal state keeps lower OUR exit score, then fewer disputed/unprofiled, then canonical key.
- Passing candidates use `marketLogic.tradeDecision`.
- Final ordering uses `marketLogic.rankPlans`.

- [ ] Write failing pure planner fixtures for:
  - 230 -> 270 moderate hold,
  - 20 -> 105 extreme-compatible plan availability,
  - Emberscythe protected OUR value,
  - weak +30 downgrade rejected,
  - equal raw/protected candidate gives away weaker inventory,
  - material disagreement preserves distinct protected state.
- [ ] Run RED.
- [ ] Implement minimal market-aware unit/DP/buildPlans logic.
- [ ] Run GREEN and re-run validated 14/14 market matrix.
- [ ] Commit: `feat: add market-aware Part 4 planner`.

### Task 4: Adapt EXTREME/logging compatibility without changing behavior

**Files:**
- Modify: `pdiddler/pdiddler4_balancer_ROTATING_v2_4_MARKET_AWARE.lua`
- Modify: `pdiddler/tests/pdiddler4_market_planner_integration_v1.lua`

**Interfaces:**
- EXTREME uses raw profit + protected profit with the existing thresholds.
- Moderate +40 remains a hold.
- 20 -> 105 remains extreme eligible.
- New planner must only raise OUR offer if the higher plan is safe and improves the excessive gap by >=5.
- Logs use PROTECTED/MARKET terminology.

- [ ] Write RED compatibility assertions for moderate/extreme boundary behavior.
- [ ] Run RED if compatibility fields/log expectations are missing.
- [ ] Make minimal EXTREME/log changes.
- [ ] Run GREEN.
- [ ] Commit: `feat: preserve extreme guard with market safety`.

### Task 5: Static regression guard for untouched executor behavior

**Files:**
- Modify: `pdiddler/tests/pdiddler4_market_integration_static_v1.lua`

**Interfaces:**
- Compares critical v2.3 executor/timer signatures/constants to v2.4.

- [ ] Add assertions that new Part 4 retains:
  - exact timer constants,
  - `txValidate`,
  - `waitForOurOfferMutation`,
  - `clearOurOffer`,
  - `applyPlan`,
  - one bounded remove retry markers,
  - recovery max attempts,
  - accepted-empty behavior,
  - 60s boundary,
  - no final Accept.
- [ ] Run GREEN.
- [ ] Review diff and ensure changes are confined to market/planner/log interface regions plus run signature.
- [ ] Commit: `test: guard v2.5 executor behavior in market Part 4`.

### Task 6: Build pinned v2.6 stack and pre-live verification

**Files:**
- Create: `pdiddler/pdiddler_MARKET_AWARE_TEST_STACK_v2_6.lua`
- Create: `pdiddler/MARKET_PART4_INTEGRATION_RESULTS_v1.md`
- Modify: `pdiddler/CHATGPT_HANDOFF.md`

**Interfaces:**
- Stack pins unchanged P1/P2/scanner/outgoing commits.
- Stack pins validated profile, validated market engine, and new Part 4 exact commits.
- Calls `part4.run(scanner, marketProfile, marketLogic)`.

- [ ] Build stack only after prior tests pass.
- [ ] Static scan stack/Part 4 for final Accept.
- [ ] Compile/load all pure modules in local Lua where possible.
- [ ] Re-run profile promotion test, 14/14 market matrix, ranking tests, planner integration tests, and static regression guard.
- [ ] Record exact commits and unresolved target-runtime uncertainties.
- [ ] Update handoff.
- [ ] Commit: `docs: prepare v2.6 market-aware live test`.

## Stop Condition

Stop after producing the pinned v2.6 test loader. Do not freeze v2.6 as known-good until the user provides an iPad recording and it is reviewed for both successes and regressions.
