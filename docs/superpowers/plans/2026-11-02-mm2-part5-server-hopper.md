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

### Task 2: Canonical final-rescan scanner interface

**Files:**
- Create from v6.9: `pdiddler/pdiddler3_scanner_MODULE_v6_10_HOP_FINAL_SCAN.lua`
- Create: `pdiddler/tests/pdiddler5_scanner_final_scan_contract_v1.py`
- Modify: `.github/workflows/mm2-market-integration-ci.yml`

**Interfaces:**
- Existing scanner APIs remain byte-for-behavior compatible.
- Produces: `ScannerAPI.finalRescanAll() -> result`.
- `result` fields: `ok:boolean`, `reason:string|nil`, `generation:number`, `tracked:number`, `whitelist:number`, `blacklist:number`, `unknown:number`.
- Internal `Live.membershipGeneration:number` increments on non-local `PlayerAdded` and `PlayerRemoving`.
- `finalRescanAll()` must reuse `scanPlayerLive` / `scanOne`; it must not add a second inventory parser.

- [ ] **Step 1: Write failing scanner contract test**

Assert:
- v6.10 exists,
- `finalRescanAll` exists,
- it calls the canonical `scanPlayerLive` path,
- membership generation is incremented by both join and leave handlers,
- stable completion requires unchanged generation and no `Live.scanning` / unknown pending work,
- the file contains no duplicate `Weapons.Owned` parser/classifier implementation added for Part 5,
- all v6.9 claim-pause tokens remain present.

- [ ] **Step 2: Run contract test to verify RED**

Expected: FAIL because v6.10 does not exist.

- [ ] **Step 3: Implement scanner v6.10**

Copy v6.9, preserve existing behavior, add only:
- membership generation tracking,
- `finalRescanAll()`,
- bounded internal stable-pass attempts (3 passes); if membership keeps changing, return `ok=false, reason="membership-changing"` rather than claiming clear.

The caller may retry later; scanner must never manufacture a clear result from unstable membership.

- [ ] **Step 4: Compile v6.10 and run old claim + new scanner contracts**

Expected: PASS, including existing post-trade claim integration guards.

- [ ] **Step 5: Commit**

Commit message: `feat: add canonical final server rescan`.

---

### Task 3: Part 3 hop-status and pre-hop hold integration

**Files:**
- Create from v16: `pdiddler/pdiddler3_outgoing_ROTATING_v17_HOP_STATUS.lua`
- Create: `pdiddler/tests/pdiddler5_outgoing_hop_status_contract_v1.py`
- Modify: `.github/workflows/mm2-market-integration-ci.yml`

**Interfaces:**
- Returned outgoing controller adds `getHopSnapshot() -> snapshot`.
- `snapshot` fields: `session:number`, `hasUnprocessed:boolean`, `hasDeferred:boolean`, `activeRequest:boolean`, `tradePaused:boolean`, `uncertain:boolean`, `queueExhausted:boolean`.
- Outgoing reads `ENV.PDIDDLER_HOP_PRECHECK_BUSY_SESSION` before choosing a new target and yields while it is owned by current Part 5.
- Part 5 owns the flag; outgoing never clears another subsystem's ownership.

- [ ] **Step 1: Write failing outgoing contract**

Assert:
- v17 exists,
- `getHopSnapshot` derives `hasUnprocessed` using existing `nextTarget()`,
- derives deferred work using existing `soonestMaturing()`,
- active/paused/uncertain state comes from existing `S`,
- pre-hop hold check occurs before `nextTarget()` in the main queue loop,
- claim pause remains before normal trade-close resume,
- existing unproven-request bounded retry tokens remain,
- no Accept/Confirm automation is added.

- [ ] **Step 2: Verify RED**

Expected: FAIL because v17 does not exist.

- [ ] **Step 3: Implement minimal v17 extension**

Do not alter request timing, physical click behavior, processed semantics, claim pause, or uncertain-send recovery.

- [ ] **Step 4: Compile and run outgoing old/new regressions**

Expected: existing Part 3 regression + new Part 5 status contract PASS.

- [ ] **Step 5: Commit**

Commit message: `feat: expose safe Part 3 hop status`.

---

### Task 4: Part 5 runtime hopper

**Files:**
- Create: `pdiddler/pdiddler5_server_hopper_v1.lua`
- Create: `pdiddler/tests/pdiddler5_server_hopper_contract_v1.py`
- Modify: `.github/workflows/mm2-market-integration-ci.yml`

**Interfaces:**
- Consumes: Part 5 policy module.
- Produces: `M.bootstrap(policy) -> hopperController`.
- `hopperController:handleBotRejected(reason) -> boolean` starts immediate re-hop mode without scanner/outgoing.
- `hopperController:attach(scanner, outgoingController) -> boolean` arms the normal exhaustion controller exactly once.
- `hopperController:stop()` invalidates the current Part 5 session.
- Teleport setting key: `"PDIDDLER_P5_STATE_V1"`.
- ENV owners: `PDIDDLER_PART5_SESSION`, `PDIDDLER_HOP_PRECHECK_BUSY_SESSION`, `PDIDDLER_HOPPING_SESSION`.
- Server list: `https://games.roblox.com/v1/games/<PlaceId>/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100[&cursor=...]`.
- Maximum pages per refresh: policy `MaxPagesPerRefresh == 5`.
- No-candidate refresh: policy `RefreshSeconds == 5`.
- No-evidence fallback after a protected teleport call: **12 seconds**, only when no `OnTeleport` state and no `TeleportInitFailed` arrived and `game.JobId` is still the source server.

- [ ] **Step 1: Write failing runtime/static contract**

Assert:
- runtime exists and requires injected policy,
- uses `GetTeleportSetting` / `SetTeleportSetting`,
- current JobId is persisted before normal hopping,
- candidate JobId is persisted as attempted before teleport call,
- uses `game:HttpGet` + `HttpService:JSONDecode`,
- parses `data` and `nextPageCursor`,
- URL-encodes cursor,
- uses specific-instance client teleport path `TeleportToPlaceInstance(game.PlaceId, jobId, LP)`,
- listens to both `LP.OnTeleport` and `TeleportService.TeleportInitFailed`,
- handles `Enum.TeleportState.Failed`,
- never launches two attempt workers for one Part 5 session,
- no `queue_on_teleport`, `syn.queue_on_teleport`, or executor file persistence,
- no `task.delay`,
- no trade remotes / final Accept logic.

- [ ] **Step 2: Verify RED**

Expected: FAIL because runtime does not exist.

- [ ] **Step 3: Implement bootstrap/persistence/server discovery**

Restore plain-value teleport state defensively. Reject malformed persisted entries instead of trusting them. Add current/attempted JobIds before selection/attempt.

Fetch up to five public-server pages per refresh. On HTTP/JSON failure, keep the current server and return to the 5-second discovery cadence.

- [ ] **Step 4: Implement serialized teleport attempt state**

One current candidate at a time:
- protected call,
- observe `OnTeleport`,
- observe `TeleportInitFailed`,
- explicit failure -> next candidate,
- no event after 12s while still in source JobId -> fail candidate,
- Started/WaitingForServer/InProgress -> never issue a competing target unless an explicit failure later returns control.

- [ ] **Step 5: Implement normal exhaustion controller**

Poll the outgoing snapshot and scanner pending state without console spam.
At policy `"final-scan"`:
1. claim pre-hop hold,
2. re-check critical conditions,
3. call `scanner.finalRescanAll()`,
4. re-read outgoing snapshot,
5. if a tradable/unprocessed target exists, release hold and reset,
6. if scanner remains unstable/pending, retain safe hold and retry verification,
7. if clear, transition to HOPPING.

- [ ] **Step 6: Run compile + contract tests**

Expected: PASS.

- [ ] **Step 7: Commit**

Commit message: `feat: add Part 5 server hopper runtime`.

---

### Task 5: Integrate early bot-rehop bootstrap and normal Part 5 into v8 stack

**Files:**
- Create from v7: `pdiddler/pdiddler_MANUAL_ACCEPT_GAIN_WEBHOOK_TEST_STACK_v8_SERVER_HOP.lua`
- Create: `pdiddler/tests/pdiddler5_stack_integration_contract_v1.py`
- Modify: `.github/workflows/mm2-market-integration-ci.yml`

**Interfaces:**
- Stack loads Part 5 policy/runtime before running Part 1.
- Stack calls `local hopper=part5.bootstrap(hopperPolicy)` before Part 1.
- If Part 1 rejects the lobby: call `hopper:handleBotRejected("part1-bot-rejected")` and stop loading Parts 2–4.
- Approved lobby continues v7 setup with scanner v6.10 and outgoing v17.
- After `outgoing.run(scanner)` returns its controller, call `hopper:attach(scanner,outgoingController)`.
- Part 4/claim/logger/manual observer arm order remains unchanged relative to outgoing.

- [ ] **Step 1: Write failing v8 integration contract**

Assert:
- bootstrap occurs before Part 1 run,
- bot rejection routes to Part 5 rather than plain `return false`,
- Part 2 still runs only after Part 1 approval,
- scanner v6.10 and outgoing v17 are used,
- Part 4 -> claimer -> completion logger -> manual observer -> outgoing ordering is preserved,
- hopper attach occurs only after outgoing controller exists,
- final Accept remains disabled,
- webhook secret remains runtime-only,
- no queue-on-teleport fallback is present.

- [ ] **Step 2: Verify RED**

Expected: FAIL because v8 stack does not exist.

- [ ] **Step 3: Implement v8 wiring only**

Do not alter market, planner, webhook, Part 4, claim, or manual observer logic.

- [ ] **Step 4: Compile v8 + run all existing and Part 5 regressions**

Expected: PASS.

- [ ] **Step 5: Commit**

Commit message: `feat: wire Part 5 server hopping into v8 stack`.

---

### Task 6: Full branch verification, handoff, and live-test launcher

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
