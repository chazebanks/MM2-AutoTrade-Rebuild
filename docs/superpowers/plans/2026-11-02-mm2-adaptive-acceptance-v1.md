# MM2 Adaptive Acceptance Trading v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace highest-value-first trading with a tested adaptive opener, acceptance-aware safe-plan ranking, bounded sweetening, and selective skip behavior while preserving every existing safety/completion guarantee.

**Architecture:** Keep the existing canonical scanner, market profile, market planner, transactional offer executor, manual-Accept observer, and completion webhook. Add one pure market-logic revision for explicit receive-side health metadata and one pure acceptance-policy module. Integrate those into a new versioned Part 4 state machine only after pure Luau tests are RED→GREEN.

**Tech Stack:** Luau 0.745, Roblox/Luau live runtime, GitHub Actions, existing MM2 canonical scanner/value profile.

**Spec:** `docs/superpowers/specs/2026-11-02-mm2-adaptive-acceptance-aware-trading-design.md`

## Global Constraints

- Final automated item-trade Accept remains disabled.
- Known-good/frozen artifacts are never edited.
- Eligible canonical item universe remains Godly / Ancient / Chroma only.
- Existing raw/protected safety gates remain authoritative.
- Appeal logic may rank or skip already-safe plans; it may never legalize an unsafe plan.
- No live HTTP market lookup occurs inside a trade.
- No guessed current-event status or guessed set premium is introduced.
- Every offer mutation remains session/generation bound and transaction verified.
- Accepted-empty remains immediate decline.
- Existing 15s empty timeout, 60s active-offer window, and 5s no-plan negotiation grace remain unless a test proves a conflict.
- Manual local Accepted state freezes voluntary opener/rebalance/sweetening mutations.
- Sweetening is bounded to two stages and never crosses the raw/protected safety floor.

## Review Focus

- THEIR OFFER appearing during the 2.5s opener observation must prevent a stale opener mutation.
- A partner whose four best eligible items cannot support a safe opener must not receive an absurd highest-value opener.
- A high raw-value but Underpaid-For receive bundle must not outrank a healthier safe bundle solely on sticker value.
- Sweetening state must reset on every THEIR OFFER signature change and stale stages must not mutate a newer generation.
- Manual local Accept must freeze voluntary offer mutation without breaking completion telemetry/webhook.

---

### Task 1: Pure market-health metadata and acceptance policy

**Files:**
- Create: `pdiddler/pdiddler4_market_logic_v2_ACCEPTANCE.lua`
- Create: `pdiddler/pdiddler4_acceptance_policy_v1.lua`
- Create: `pdiddler/tests/pdiddler4_acceptance_policy_v1.luau`

**Interfaces:**
- Consumes: canonical inventory items `{page,id,name,value,qty}`, validated profile `.get(page,id)`, existing market assessment semantics.
- Produces:
  - `marketLogic.bundleAssessment(items, side, profile)` with additional `underpaidCopies`, `underpaidValue`, `fluctuatingCopies`.
  - `policy.selectOpener(ownInv, partnerInv, profile, marketLogic) -> item|nil, meta`
  - `policy.appeal(plan, theirBundle) -> tier, meta`
  - `policy.rankSafePlans(plans, theirBundle, sweetenStep) -> rankedPlans, meta`
  - `policy.sweetenStep(elapsedSeconds) -> 0|1|2`

- [ ] **Step 1: Write failing pure Luau matrix**

Cover at minimum:
- THEIR affordability: unreachable highest item is not selected.
- realistic high-exit stable opener beats reachable weak/Underpaid opener.
- no reachable opener returns nil.
- safe plan with better `givenExitScore` outranks uglier plan in the same profit stage.
- counterparty-upgrade shape receives positive ordering preference.
- counterparty-downgrade shape is penalized when otherwise comparable.
- disputed/unprofiled plan cannot receive top appeal tier.
- receive bundle dominated by Underpaid-For value cannot receive positive quality credit.
- unsafe/reject plans are excluded.
- sweetening progression is 0 before 5s, 1 at 5–<10s, 2 at >=10s.
- stage 0 preserves up to two profit bands when available; stage 2 selects minimum safe band.
- deterministic ordering on identical inputs.

- [ ] **Step 2: Run test before production modules exist**

Run in CI: `/tmp/luau/luau pdiddler/tests/pdiddler4_acceptance_policy_v1.luau`

Expected: FAIL because new modules are missing.

- [ ] **Step 3: Implement minimal pure modules**

`pdiddler4_market_logic_v2_ACCEPTANCE.lua` must preserve v1 trade-decision thresholds and only add explicit health metadata required by policy.

`pdiddler4_acceptance_policy_v1.lua` rules:
- opener observation default exported as `OpenerObserveSeconds=2.5`;
- opener feasibility requires `candidateRaw + max(15, candidateProtected*0.03) <= partnerTop4Raw`;
- opener requires confident, non-disputed metadata and cannot be `Underpaid For`;
- opener ranking: higher exit score, lower risk, smaller distance to partner max-single raw, then canonical key;
- appeal uses discrete A/B/C/D tiers, not a single opaque score;
- plans with disputed/unprofiled copies are capped below A;
- receive-side Underpaid-For exposure prevents positive quality credit;
- profit bands reuse `min(25,max(5,theirRaw*0.02))`;
- stage target is two bands above minimum when available, then one, then minimum;
- if target band is absent choose nearest lower existing band, then nearest higher;
- within selected band prefer higher appeal tier/quality delta, counterparty-upgrade shape, fewer disputed/unprofiled copies, fewer OUR slots, deterministic key.

- [ ] **Step 4: Run pure matrix**

Expected: PASS all acceptance-policy cases.

- [ ] **Step 5: Run existing market integration suite**

Expected: existing v1 suite still PASS unchanged.

- [ ] **Step 6: Commit Task 1**

Commit message: `Add pure adaptive opener and acceptance policy`

---

### Task 2: Integrate adaptive opener and bounded sweetening into new Part 4

**Files:**
- Create: `pdiddler/pdiddler4_balancer_ROTATING_v2_5_ADAPTIVE_ACCEPTANCE.lua`
- Create: `pdiddler/tests/pdiddler4_adaptive_part4_contract_v1.py`

**Interfaces:**
- Consumes: scanner, market profile v1 validated, market logic v2, market planner v1_2, acceptance policy v1, trade telemetry.
- Produces: same Part 4 controller contract as v2.4.5, plus diagnostic state for opener/appeal/sweetening; no final Accept action.

- [ ] **Step 1: Write failing static/integration contract**

Assert:
- new `M.run` accepts acceptance policy dependency;
- `OpenerObserveSeconds` is used before any forced opener;
- no call to `highestOwn` remains in the opening path;
- THEIR non-empty offer during observation skips opener;
- policy `selectOpener` drives forced opener;
- opener re-reads THEIR OFFER immediately before mutation;
- no-plausible-opener path remains empty and enters normal loop;
- sweetening generation stores THEIR signature + timestamp;
- `policy.sweetenStep` and `policy.rankSafePlans` drive plan choice;
- signature change resets sweetening generation;
- manual local Accepted visibility enters mutation freeze;
- recovery/rebalance ownership blocks sweetening;
- accepted-empty immediate path remains before no-plan grace;
- no-plan grace remains 5s;
- empty timeout 15s and active window 60s remain;
- no `AcceptTrade:FireServer`, physical Accept, Confirm, or firesignal.

- [ ] **Step 2: Run contract against missing new Part 4**

Expected: FAIL because new Part 4 file is missing.

- [ ] **Step 3: Implement new Part 4 from v2.4.5**

Minimal behavior changes only:
1. replace immediate highest-value opener with 2.5s observation;
2. if THEIR resolved/non-empty offer appears, skip opener;
3. otherwise call `selectOpener`; if nil, remain empty;
4. preserve original 15s empty timer from trade-session start;
5. after stable THEIR OFFER, generate safe plans with existing planner;
6. pass safe plans through acceptance policy for current sweetening step;
7. if only appeal-D safe plans exist, hold for THEIR change rather than forcing mutation, bounded by existing negotiation/outer-window exits;
8. reset sweetening clock on every THEIR signature change;
9. at ~5s and ~10s unchanged offer, allow one lower profit band each;
10. local manual Accepted state freezes voluntary mutations until MM2 clears it or trade closes;
11. retain transaction serial/generation validation before and after mutations;
12. preserve webhook candidate invalidation rules and completion observer compatibility.

- [ ] **Step 4: Compile new Part 4 and run contract**

Expected: PASS.

- [ ] **Step 5: Run all existing Part 4 regression guards**

Expected: no known-good file changes; all existing guards PASS.

- [ ] **Step 6: Commit Task 2**

Commit message: `Integrate adaptive acceptance strategy into Part 4`

---

### Task 3: Build runnable test stack and CI gate

**Files:**
- Create: `pdiddler/pdiddler_MANUAL_ACCEPT_GAIN_WEBHOOK_TEST_STACK_v5_ADAPTIVE.lua`
- Modify: `.github/workflows/mm2-market-integration-ci.yml`

**Interfaces:**
- Consumes: TDD-verified Part 3 unproven-send build, market logic v2, acceptance policy v1, planner v1_2, Part 4 v2.5, existing observer/logger/webhook modules.
- Produces: one pinned runnable Delta stack with final automated Accept disabled.

- [ ] **Step 1: Write failing CI wiring guard**

Assert stack pins/loads:
- market logic v2,
- acceptance policy v1,
- Part 4 v2.5,
- existing manual gain observer v2,
- completion logger v2,
- webhook payload v2,
- TDD Part 3 outgoing recovery.

Assert:
- completion logger arms after Part 4 and before outgoing rotation;
- webhook URL remains external;
- no embedded Discord credential;
- final automated Accept remains disabled.

- [ ] **Step 2: Run CI before stack exists**

Expected: FAIL at new wiring guard.

- [ ] **Step 3: Create v5 stack and wire CI compile/tests**

Keep launcher thin; no strategy logic in launcher.

- [ ] **Step 4: Run full GitHub Actions suite**

Expected: every old regression plus new pure policy, Part 4 contract, and stack guard PASS.

- [ ] **Step 5: Commit Task 3**

Commit message: `Add adaptive acceptance live test stack`

---

### Task 4: Final branch review, live-test checklist, and handoff

**Files:**
- Modify: `pdiddler/CHATGPT_HANDOFF.md`
- Create: `docs/superpowers/reviews/2026-11-02-mm2-adaptive-acceptance-v1-review.md`

**Interfaces:**
- Consumes: complete implementation branch and CI results.
- Produces: documented review findings, explicit live-test checklist, exact pinned launcher SHA.

- [ ] **Step 1: Review the complete diff against spec**

Check:
- no known-good mutation,
- no duplicate ranking/market logic paths,
- no stale sweetener callback,
- no hidden Accept/Confirm path,
- no new unbounded retry,
- no current-event/set guesses,
- no raw/checker identity regression,
- no webhook credential leak.

- [ ] **Step 2: Add any Important/Critical finding as a failing regression first**

Expected: RED before each fix, GREEN after.

- [ ] **Step 3: Run fresh full CI after review fixes**

Expected: SUCCESS with zero failing steps.

- [ ] **Step 4: Document live validation sequence**

Recording must verify:
1. THEY offer within 2.5s -> no opener.
2. THEY stay empty -> realistic opener, not unreachable highest item.
3. no realistic opener -> remain empty safely.
4. two safe plans -> healthier counterparty plan selected.
5. unchanged offer -> bounded sweeten at ~5s and ~10s only.
6. THEIR change during sweeten -> old generation invalidated.
7. manual Accept -> mutation freeze.
8. completed trade -> exactly one webhook + inventory verification + Trade ID.
9. unchanged no-safe-plan -> existing 5s grace decline still works.
10. unproven outgoing request -> existing Part 3 bounded retry remains intact.

- [ ] **Step 5: Update handoff with exact commits/run IDs and remaining live-only uncertainties**

- [ ] **Step 6: Commit Task 4**

Commit message: `Review and document adaptive acceptance v1`
