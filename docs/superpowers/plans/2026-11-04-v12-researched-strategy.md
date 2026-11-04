# V12 researched strategy implementation plan

> For agentic workers: execute the isolated tasks sequentially with regression verification and independent final review.

Goal: implement the supported research conclusions without disturbing tested runtime responsibilities.
Architecture: strictv8 owns the planner and one verified spending ledger; earlyv3 only proposes; P4v7 alone applies/verifies. Versioned immutable V12 entry retains all known-good pins.
Tech stack: pure Lua policies, Luau runtime, existing Python/Roblox boundary fixtures.
Spec: `docs/superpowers/specs/2026-11-04-v12-researched-strategy.md`.

## Global constraints

PR14 b923481 baseline immutable; Supreme+15; four copies; known exact identity; no personal goal; native final Accept/completion/Discord OFF; native-ready9s/2.5s guards unchanged.

## Review focus

- Equivalent edits must not replenish spending; genuine higher received value may enlarge only the bounded envelope.
- Failed/partial replacement and new initial quotes cannot escape the same ledger.
- Equal-stat candidates may differ in post-trade holdings; many identical items must not explode state count.
- Quote-region extension must never spend near the floor without the explicit small bound.
- Manual approvals, GUI lifetimes, readiness and expiry must retain the existing behavior.

## Task1: pure policy successors

Create `pdiddler4_supreme_policy_v8_PORTFOLIO_LEDGER.lua`, `pdiddler4_early_counter_policy_v3_TRADE_BUDGET.lua` and V12 policy tests.
- [x] Reproduce risk inversion,23/145 gap, equal-stat pruning, equivalent-edit spending and global-step resets as failing tests.
- [x] Add consistent weighted risk, bounded portfolio distinctions and equal-economics tie-breaks.
- [x] Add guarded initial region extension; unknown comparison metadata retains the old guarded behavior.
- [x] Implement one ledger/pending reservation with only verified commit; early policy consumes its provided allowance.
- [x] Run pure regressions and commit a passing checkpoint.

## Task2: one P4 execution path

Create `pdiddler4_balancer_SUPREME_v7_PORTFOLIO_LEDGER.lua`; exercise full production source through new V12 fixture runner.
- [x] Test cumulative edits, failed proposals, verified steps, recovery and initial/rebalance budget ownership before changing execution.
- [x] Reserve every voluntary proposed increase; commit only after exact readback/current+15 decision; cancel on failure.
- [x] Preserve all existing session/approval/readiness/empty/overall guards and API contracts.
- [x] Run old full regression suites plus new actual-P4 tests; commit passing checkpoint.

## Task3: immutable entry, evidence and publication

Create V12 loader/bootstrap/manifest/check runner and CI; retain frozen source hashes.
- [ ] Pin published module checkpoint before publishing loader, then pin loader before bootstrap.
- [ ] Verify local/remote blobs, all prior baseline files, compiler output and complete test commands.
- [ ] Save source ledger, conclusions, validation and precise remaining iPad tests.
- [ ] Open new draftPR based on PR14 branch; never merge automatically.
