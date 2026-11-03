# MM2 P1 + P5 Observation Lab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a separate recording-friendly Part 1 + Part 5 observation lab that shows real hopper candidates, current-player avatar/action evidence, supports a manual `botted` false-negative marker, and waits 30 seconds on Part 1-approved servers before invoking the already-tested Part 5 transport.

**Architecture:** Keep the known-good Part 1 detector and existing Part 5 teleport transport pinned and unchanged. Add a pure observation policy, a read-only candidate observer that delegates filtering/ranking to the existing Part 5 policy, a GUI/monitor module, and a new standalone lab v2 that coordinates them. No Part 3/4/trading code is loaded.

**Tech Stack:** Luau, Roblox `Players`, `TextChatService`, `Humanoid`, `Players:GetUserThumbnailAsync`, `PlayerGui`, existing Part 5 policy/runtime, GitHub Actions official Luau compiler.

**Spec:** `docs/superpowers/specs/2026-11-03-mm2-p1-p5-observation-lab-design.md`

## Global Constraints

- Part 1 known-good bot detector remains unchanged.
- Existing Part 5 transport remains unchanged and is the only teleport owner.
- Part 1 BOT => immediate re-hop; no 30-second observation window.
- Part 1 APPROVED => 30-second observation window, then existing Part 5 `hopNow()`.
- Exact local chat message `botted` marks a manual false negative.
- Manual marking does not hop early and does not reset the countdown.
- Repeated `botted` messages in the same server dedupe.
- GUI candidate rows show real public servers ranked through the existing Part 5 policy: 11/12 before 10/12 only.
- Player action labels are observational only: Idle, Moving, Jumping, Freefall, Sitting, Dead, Character Loading.
- No inferred labels such as botting/farming/collecting.
- Avatar thumbnails are best-effort and never block hopping.
- No Part 3, Part 4, webhook, claim, market, offer, Accept, or Decline logic.
- Duplicate auto-execution must not stack GUI sessions, chat listeners, timers, or teleport owners.

## Review Focus

- TextChatService can deliver the local sender's message more than once; manual marker must dedupe.
- Player leaves while thumbnail/action row updates; UI update must tolerate stale/destroyed rows.
- Thumbnail retrieval yields/fails; countdown and hop must continue independently.
- Candidate HTTP request fails; GUI shows unavailable/empty state without blocking scheduled hop.
- Delta auto-exec duplicates the lab in the same JobId; new lab session must invalidate old observation callbacks while P5 controller reuse prevents duplicate teleports.

---

### Task 1: Pure observation policy

**Files:**
- Create: `pdiddler/pdiddler_p1_p5_observation_policy_v1.lua`
- Create: `pdiddler/tests/pdiddler_p1_p5_observation_policy_v1.luau`
- Modify: `.github/workflows/mm2-market-integration-ci.yml`

**Interfaces:**
- Produces: `M.ObservationSeconds == 30`
- Produces: `M.normalizeManualMessage(text) -> string`
- Produces: `M.markManual(state, text, remaining) -> nextState, changed`
- Produces: `M.actionLabel(snapshot) -> string`
- `snapshot`: `character:boolean`, `health:number|nil`, `sit:boolean`, `humanoidState:string|nil`, `moving:boolean`.

- [ ] Write RED Luau tests for exact `botted` normalization/dedupe, unchanged countdown metadata, and all allowed action labels.
- [ ] Run CI and confirm RED because policy module is missing.
- [ ] Implement minimal pure policy.
- [ ] Run CI and confirm GREEN.
- [ ] Commit: `feat: add P1 P5 observation policy`.

---

### Task 2: Read-only real candidate observer

**Files:**
- Create: `pdiddler/pdiddler5_server_candidate_observer_v1.lua`
- Create: `pdiddler/tests/pdiddler5_candidate_observer_contract_v1.py`
- Modify: `.github/workflows/mm2-market-integration-ci.yml`

**Interfaces:**
- Consumes injected Part 5 policy.
- Produces: `M.new(policy) -> observer`
- Produces: `observer:refresh() -> {candidates, error}`
- Uses the same public server endpoint shape and pagination as P5 transport.
- Delegates all valid-candidate filtering/order to `policy.rankCandidates(...)`.
- Read-only: no TeleportService, no visited-state mutation.

- [ ] Write RED contract.
- [ ] Confirm RED.
- [ ] Implement observer with bounded pages and URL-encoded cursor.
- [ ] Compile/run contracts GREEN.
- [ ] Commit: `feat: add read-only hopper candidate observer`.

---

### Task 3: Recording GUI + player monitor

**Files:**
- Create: `pdiddler/pdiddler_p1_p5_observation_gui_v1.lua`
- Create: `pdiddler/tests/pdiddler_p1_p5_observation_gui_contract_v1.py`
- Modify: `.github/workflows/mm2-market-integration-ci.yml`

**Interfaces:**
- Consumes observation policy + candidate observer.
- Produces: `M.new(config) -> guiController`
- Config includes `sessionAlive()`, `part1Status`, `deadline`, `onManualBotted(snapshot)`.
- Produces methods: `start()`, `setBotRehop()`, `markManualBotted(remaining)`, `destroy()`.
- GUI name: `PDIDDLER_P1_P5_OBSERVATION_GUI`.
- Player thumbnails use `Players:GetUserThumbnailAsync(...HeadShot, Size100x100)`.
- Action polling interval: 0.5 seconds.
- Candidate refresh interval: 5 seconds.
- Candidate display rows bounded to 5.
- Uses current TextChatService local-send event plus legacy `LP.Chatted` fallback, deduped by policy/session.

- [ ] Write RED GUI static contract for lifecycle, thumbnail API, allowed action source, chat compatibility, intervals, bounded rows, and no teleport/trade code.
- [ ] Confirm RED.
- [ ] Implement GUI/monitor.
- [ ] Compile + contract GREEN.
- [ ] Commit: `feat: add P1 P5 observation GUI`.

---

### Task 4: Standalone observation lab v2

**Files:**
- Create: `pdiddler/tests/pdiddler_P1_P5_OBSERVATION_LIVE_LAB_v2.lua`
- Create: `pdiddler/tests/pdiddler_p1_p5_observation_lab_v2_contract.py`
- Modify: `.github/workflows/mm2-market-integration-ci.yml`

**Interfaces:**
- Pins known-good Part 1 commit.
- Pins existing tested Part 5 transport commit `fa288984552e95fc13be01ec9c9b58bf7c9fb914`.
- Loads new policy/observer/GUI from a single observation-lab commit pin.
- Bootstrap P5 before Part 1.
- BOT => GUI brief bot state + `handleBotRejected()`.
- APPROVED => create GUI, run exactly 30-second observation window, then `hopper:hopNow("p1-p5-observation-30s")`.
- Manual `botted` only changes evidence state; it never invokes hop or changes deadline.

- [ ] Write RED integration contract.
- [ ] Confirm RED.
- [ ] Implement v2 lab.
- [ ] Compile + all Part 5/observation contracts GREEN.
- [ ] Commit: `test: add P1 P5 observation live lab v2`.

---

### Task 5: Final verification + loader + handoff

**Files:**
- Modify: `pdiddler/CHATGPT_HANDOFF.md`
- Create user-facing loader text outside repo after final pinned commit.

- [ ] Fresh full CI run: all existing regressions, Part 5 policy, standalone transport contract, observation policy, candidate observer, GUI contract, lab v2 contract, and compilation all PASS.
- [ ] Static safety review confirms original Part 1 and P5 transport files were not modified.
- [ ] Confirm no Part 3/4/trade/webhook/final-Accept tokens in v2 lab.
- [ ] Update handoff with exact commit/run and live-recording gate.
- [ ] Create Delta Auto Execute `.txt` loader pinned to final lab commit.
- [ ] Stop before full PDIDDLER integration; await recording evidence.
