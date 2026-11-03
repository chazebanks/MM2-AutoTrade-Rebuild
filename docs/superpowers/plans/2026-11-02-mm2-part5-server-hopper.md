# MM2 Part 5 Server Hopper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reliable Part 5 server hopper that waits for 45 seconds of true Part 3 exhaustion, performs one final canonical server scan, then moves only to unvisited 11/12 or 10/12 public MM2 servers with bounded failure recovery and Delta Auto Execute relaunch.

**Architecture:** Keep Part 1 as the sole bot classifier and Part 3 as the sole inventory/queue authority. Add a pure Part 5 policy module, minimal read-only/hold interfaces to new scanner/outgoing versions, and a runtime hopper that owns teleport persistence, server discovery, and one serialized hop state machine. Delta Auto Execute remains the only script re-execution mechanism.

**Tech Stack:** Luau, Roblox client services (`Players`, `TeleportService`, `HttpService`), executor `game:HttpGet`, GitHub Actions official Luau 0.745, Python static regression tests.

**Spec:** `docs/superpowers/specs/2026-11-02-mm2-part5-server-hopper-design.md`

## Global Constraints

- Normal exhaustion timeout is exactly **45 seconds**.
- Only a newly confirmed unprocessed tradable player resets the exhaustion timer.
- Unknown/scanning work blocks a hop but does not reset an already-running timer.
- A mandatory final canonical scanner pass occurs before every normal exhaustion hop.
- Candidate priority is **11/12 first, then 10/12**; never intentionally select 9/12 or lower.
- If no valid 11/12 or 10/12 target exists, refresh every **5 seconds**.
- Current and attempted/visited JobIds must not be selected again in the same teleport chain.
- Delta Auto Execute is authoritative; do not add `queue_on_teleport`.
- Part 1 remains the only bot-lobby classifier.
- Part 5 must re-hop after Part 1 rejects a bot lobby instead of allowing the automation chain to stop.
- Do not modify frozen/live-proven v7 files in place; create versioned successors.
- Final automated item-trade Accept remains disabled.
- No webhook credential may be committed.
- No detached `task.delay` may commit a hop from stale state.

## Review Focus

- A player joins at the 45-second boundary: final scan must include/await the join and cannot hop on stale membership.
- A deferred Part 3 target is cooling down: it is pending work, not exhaustion, so Part 5 must not start/commit a hop.
- Teleport call returns but no event arrives immediately: do not launch a competing candidate until explicit failure or the bounded no-evidence fallback.
- Public-server pagination contains duplicates/current/visited/full/lower-population entries: filtering must remain deterministic and safe.
- Bot rejection occurs before scanner/outgoing are loaded: early Part 5 bootstrap must still be able to re-hop without Part 3 dependencies.

---

### Task 1: Pure exhaustion and candidate-selection policy

**Files:**
- Create: `pdiddler/pdiddler5_server_hopper_policy_v1.lua`
- Create: `pdiddler/tests/pdiddler5_server_hopper_policy_v1.luau`
- Modify: `.github/workflows/mm2-market-integration-ci.yml`

**Interfaces:**
- Produces: `M.ExhaustionSeconds == 45`, `M.RefreshSeconds == 5`, `M.MaxPagesPerRefresh == 5`.
- Produces: `M.stepExhaustion(state, now, signals) -> nextState, action`.
- Produces: `M.rankCandidates(servers, currentJobId, visited) -> orderedCandidates`.
- `signals` fields: `queueExhausted:boolean`, `tradableAvailable:boolean`, `scannerPending:boolean`, `criticalBusy:boolean`.
- `action` is one of `"active"`, `"countdown"`, `"blocked"`, `"final-scan"`.

- [ ] **Step 1: Write failing Luau policy tests**

Cover:
- first true exhaustion starts at `now`,
- 44.99s remains countdown,
- 45.00s requests final scan,
- tradable availability clears/reset timer,
- scanner pending at/after deadline returns blocked but preserves original `since`,
- critical work resets exhaustion to active,
- 11-player candidates sort before 10-player candidates,
- 9-player/lower/full/wrong-max/current/visited/empty-id candidates are excluded,
- duplicate JobIds collapse to one candidate,
- input candidate tables are not mutated.

- [ ] **Step 2: Add the new branch and RED test to CI**

Add `feature/mm2-server-hopper-design` to workflow branch triggers and run:
`/tmp/luau/luau pdiddler/tests/pdiddler5_server_hopper_policy_v1.luau`.

Expected: FAIL because the policy module does not exist.

- [ ] **Step 3: Implement the minimal pure policy module**

Use no Roblox services and no global state. `stepExhaustion` owns only timer semantics; `rankCandidates` owns only eligibility/order.

- [ ] **Step 4: Run policy tests**

Expected: all policy tests PASS.

- [ ] **Step 5: Commit**

Commit message: `feat: add Part 5 hopper policy`.

---

### Task 2: Standalone Part 1 + Part 5 transport lab

**Files:**
- Create: `pdiddler/pdiddler5_server_hopper_v1.lua`
- Create: `pdiddler/tests/pdiddler5_server_hopper_contract_v1.py`
- Create: `pdiddler/tests/pdiddler_P1_P5_SERVER_HOP_LIVE_LAB_v1.lua`
- Modify: `.github/workflows/mm2-market-integration-ci.yml`

**Interfaces:**
- Consumes: Part 5 policy module from Task 1.
- Produces: `M.bootstrap(policy) -> hopperController`.
- `hopperController:handleBotRejected(reason) -> boolean` starts immediate re-hop mode.
- `hopperController:hopNow(reason) -> boolean` invokes the same production server-discovery/teleport transport path without claiming Part 3 exhaustion.
- `hopperController:stop()` invalidates the current Part 5 session.
- Teleport setting key: `"PDIDDLER_P5_STATE_V1"`.
- ENV owners: `PDIDDLER_PART5_SESSION`, `PDIDDLER_HOPPING_SESSION`.
- Server list: `https://games.roblox.com/v1/games/<PlaceId>/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100[&cursor=...]`.
- Maximum pages per refresh: policy `MaxPagesPerRefresh == 5`.
- No-candidate refresh: policy `RefreshSeconds == 5`.
- No-evidence fallback after a protected teleport call: 12 seconds if still in the source JobId and no success/failure evidence arrived.

- [ ] **Step 1: Write failing Part 5 runtime/static contract**

Assert persistence, candidate exclusion, public-server parsing/pagination, 11/12→10/12 ranking consumption, serialized teleport attempts, `OnTeleport`, `TeleportInitFailed`, specific-instance teleport, no queue-on-teleport, no trade remotes, no `task.delay`.

- [ ] **Step 2: Verify RED**

Expected: FAIL because runtime does not exist.

- [ ] **Step 3: Implement transport-only Part 5 runtime**

Implement:
- restore/persist visited state,
- fetch/filter candidate pages,
- serialized candidate attempts,
- immediate/late failure recovery,
- bot-reject re-hop entry,
- `hopNow(reason)` for the lab and later production controller.

Do **not** add scanner/outgoing dependencies yet.

- [ ] **Step 4: Create P1+P5 live lab**

Lab sequence:
1. load Part 5 policy/runtime,
2. bootstrap Part 5,
3. run known-good Part 1,
4. if bot -> `handleBotRejected("part1-bot-rejected")`,
5. if approved -> print LAB marker and wait exactly 45 seconds,
6. call `hopNow("p1-p5-lab-45s")`.

The 45-second LAB timer is explicitly test-only and does not claim the server is trade-exhausted.

- [ ] **Step 5: Compile + run contract tests**

Expected: PASS.

- [ ] **Step 6: Commit**

Commit message: `feat: add standalone Part 1 + Part 5 hopper lab`.

---

### Task 3: Live-prove standalone hopper before production integration

**Files:**
- No production integration changes.
- Modify handoff only after recording evidence.

- [ ] **Step 1: Run the P1+P5 lab through Delta Auto Execute**

Validate at least:
- approved server waits 45s then searches,
- chooses 11/12 when available,
- uses 10/12 when no valid 11/12 is available,
- failed/full candidate advances to another candidate,
- visited/current JobId is not selected,
- no target -> 5s refresh,
- bot server after teleport -> Part 1 rejects -> immediate re-hop,
- successful arrival auto-executes the lab again.

- [ ] **Step 2: Analyze full recording for races/errors**

Do not mark Part 5 transport live-proven from logs alone if the actual teleport/relaunch sequence is not visible.

- [ ] **Step 3: Only after live proof, freeze the transport core**

Record exact commit as known-good transport baseline.

- [ ] **Step 4: If the standalone lab fails, fix only transport/lifecycle behavior**

Do not touch scanner/outgoing/trading code.

---

### Task 4: Canonical final-rescan scanner interface

**Files:**
- Create from v6.9: `pdiddler/pdiddler3_scanner_MODULE_v6_10_HOP_FINAL_SCAN.lua`
- Create: `pdiddler/tests/pdiddler5_scanner_final_scan_contract_v1.py`
- Modify: `.github/workflows/mm2-market-integration-ci.yml`

**Interfaces:**
- Existing scanner APIs remain behavior-compatible.
- Produces: `ScannerAPI.finalRescanAll() -> result`.
- `result` fields: `ok:boolean`, `reason:string|nil`, `generation:number`, `tracked:number`, `whitelist:number`, `blacklist:number`, `unknown:number`.
- Internal `Live.membershipGeneration:number` increments on non-local `PlayerAdded` and `PlayerRemoving`.
- `finalRescanAll()` reuses `scanPlayerLive` / `scanOne`; no second parser.

- [ ] **Step 1: Write failing scanner contract**
- [ ] **Step 2: Verify RED**
- [ ] **Step 3: Implement scanner v6.10 with bounded stable passes**
- [ ] **Step 4: Compile and run old claim + new scanner contracts**
- [ ] **Step 5: Commit** `feat: add canonical final server rescan`

---

### Task 5: Part 3 hop-status and pre-hop hold integration

**Files:**
- Create from v16: `pdiddler/pdiddler3_outgoing_ROTATING_v17_HOP_STATUS.lua`
- Create: `pdiddler/tests/pdiddler5_outgoing_hop_status_contract_v1.py`
- Modify: `.github/workflows/mm2-market-integration-ci.yml`

**Interfaces:**
- Adds `getHopSnapshot()` with unprocessed/deferred/active/paused/uncertain/exhausted state.
- Reads `PDIDDLER_HOP_PRECHECK_BUSY_SESSION` before selecting a new target.

- [ ] **Step 1: Write failing outgoing contract**
- [ ] **Step 2: Verify RED**
- [ ] **Step 3: Implement minimal v17 extension**
- [ ] **Step 4: Compile and run old/new Part 3 regressions**
- [ ] **Step 5: Commit** `feat: expose safe Part 3 hop status`

---

### Task 6: Production exhaustion controller on the live-proven transport

**Files:**
- Extend only the new Part 5 module version after standalone transport is frozen, or create `pdiddler5_server_hopper_v2_EXHAUSTION.lua`.
- Create: `pdiddler/tests/pdiddler5_exhaustion_integration_contract_v1.py`.

**Interfaces:**
- Consumes scanner v6.10 + outgoing v17.
- Adds `attach(scanner,outgoingController)`.
- Uses policy 45-second timer and mandatory final scan.
- Uses the already live-proven `hopNow()` transport path for actual hopping.

- [ ] **Step 1: RED integration contract**
- [ ] **Step 2: Implement exhaustion/final-scan controller only**
- [ ] **Step 3: Verify no transport behavior changed**
- [ ] **Step 4: Commit** `feat: add Part 5 production exhaustion controller`

---

### Task 7: Integrate Part 5 into full v8 stack only after standalone proof

**Files:**
- Create from v7: `pdiddler/pdiddler_MANUAL_ACCEPT_GAIN_WEBHOOK_TEST_STACK_v8_SERVER_HOP.lua`
- Create: `pdiddler/tests/pdiddler5_stack_integration_contract_v1.py`

- [ ] **Step 1: RED v8 integration contract**
- [ ] **Step 2: Wire early Part 5 bootstrap before Part 1**
- [ ] **Step 3: Preserve Part 4 -> claimer -> logger -> manual observer -> outgoing order**
- [ ] **Step 4: Attach production exhaustion controller after outgoing exists**
- [ ] **Step 5: Compile + run all regressions**
- [ ] **Step 6: Commit** `feat: wire live-proven Part 5 into v8 stack`

---

### Task 8: Full branch verification and integrated live validation



**Files:**
- Modify: `pdiddler/CHATGPT_HANDOFF.md`
- Modify: `.github/workflows/mm2-market-integration-ci.yml`
- No secret-bearing launcher committed.

**Interfaces:**
- CI must compile all new Luau artifacts and execute every existing regression plus all Part 5 tests.
- Handoff records exact commit pins, CI run, known limitations, and live validation protocol.

- [ ] **Step 1: Run full GitHub Actions workflow on the Part 5 branch**

Required PASS:
- all prior market/cache/webhook/adaptive/claim/Part 3 tests,
- Part 5 policy tests,
- scanner final-scan contract,
- outgoing hop-status contract,
- runtime hopper contract,
- v8 integration contract,
- official Luau compilation for every new file.

- [ ] **Step 2: Static safety review**

Verify across all new/changed runtime files:
- no automated item-trade Accept/Confirm,
- no new inventory parser outside scanner,
- no duplicate bot classifier,
- no `queue_on_teleport`,
- no webhook URL,
- no `task.delay`,
- only Part 5 invokes teleport,
- only one pre-hop/hopping owner.

- [ ] **Step 3: Update handoff**

Document:
- design/plan paths,
- exact module names,
- commit pins,
- CI run/conclusion,
- Delta Auto Execute requirement,
- live-test scenarios.

- [ ] **Step 4: Prepare controlled live validation**

Expected visible behavior:
```text
[PDIDDLER P5] EXHAUSTED | hop in 45s
[PDIDDLER P5] FINAL SCAN START
[PDIDDLER P5] FINAL SCAN CLEAR | no targets
[PDIDDLER P5] SERVERS | 11/12=N | 10/12=N | visited=N
[PDIDDLER P5] HOP ATTEMPT | 11/12 or 10/12 | <short JobId>
```

Live validation must cover:
- normal 45s exhaustion hop,
- eligible join resets/cancels,
- ineligible join does not reset,
- target fills/fails -> different target,
- no preferred server -> 5s refresh,
- Part 1 bot rejection -> immediate re-hop,
- Delta Auto Execute restarts stack,
- same JobId is not reselected,
- existing trading/claim behavior remains intact.

- [ ] **Step 5: Do not mark Part 5 live-proven until recording evidence confirms the above**

Commit message: `docs: hand off Part 5 server hopper validation`.
