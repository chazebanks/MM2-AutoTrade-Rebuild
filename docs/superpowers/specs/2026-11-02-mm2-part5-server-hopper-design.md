# MM2 Part 5 — Server Hopper Design

Date: 2026-11-02
Status: Proposed — requires user approval before implementation
Target branch: `feature/mm2-server-hopper-design`

## Intent

Part 5 owns server exhaustion detection and server hopping after Part 3 has no remaining useful outgoing targets.

Part 1 remains the sole bot-server authority. Part 5 does not duplicate bot detection. Instead, Part 5 provides the recovery path when Part 1 rejects a newly joined server.

The primary objective is to keep the auto-trader moving through populated public MM2 servers without:
- hopping while useful work still exists,
- hopping before the scanner finishes,
- rejoining the current/recently visited server,
- getting stuck on a full target server,
- creating competing teleport attempts,
- or requiring manual script re-execution after every hop.

Delta's built-in Auto Execute is the authoritative script restart mechanism after teleport.

## Confirmed product behavior

### Exhaustion countdown

Normal server exhaustion starts only when Part 3 has no unprocessed tradable target.

The countdown is **45 seconds**.

A newly confirmed tradable player resets the countdown to a fresh 45 seconds.

A new ineligible/blacklisted player does **not** reset the countdown.

A new player whose inventory is still unknown/scanning does not reset the countdown, but Part 5 may not hop while classification is unresolved.

If unresolved scanning lasts beyond the 45-second deadline, the deadline remains expired and Part 5 proceeds to final verification as soon as scanner work settles.

### Mandatory final scan

When the 45-second deadline is reached, Part 5 performs one final authoritative server verification before hopping.

This verification must reuse the existing canonical Part 3 inventory scanner. Part 5 must not implement a second inventory parser/classifier.

The final verification:
1. prevents a new outgoing request from beginning while the hop decision is being finalized,
2. re-scans all current non-local players with the canonical scanner path,
3. waits for all scanner work to settle,
4. re-checks the current player set for joins that occurred during the final pass,
5. verifies that no unprocessed whitelisted/tradable target exists.

If an unprocessed tradable player is found, the hop is cancelled, the pre-hop lock is released, Part 3 resumes, and the next future exhaustion countdown begins fresh after work is exhausted again.

Previously processed players remain processed; discovering that a processed player is still eligible does not make them a new outgoing target.

### Server occupancy policy

Only public MM2 servers with these player counts are eligible:
1. **11/12** — preferred
2. **10/12** — fallback

Part 5 never intentionally selects 9/12 or lower.

If no eligible 11/12 or 10/12 server exists, Part 5 remains in the current exhausted server and refreshes the public server list every **5 seconds**.

If an eligible 10/12 server exists, Part 5 does not wait for an 11/12 server.

### Visited server policy

The current `game.JobId` is added to the visited set before any normal hop attempt.

Each candidate JobId is added to the visited/attempted set **before** its teleport call so a failed or full target is not immediately selected again.

Within the same auto-execute/teleport chain, visited JobIds are not intentionally revisited.

The visited set is persisted through Roblox client teleport settings using `TeleportService:SetTeleportSetting()` / `GetTeleportSetting()`.

This is session-scoped state. It is not stored in GitHub, DataStore, or a permanent executor file. If the user fully leaves the experience and later starts a new session without preserved teleport settings, the visited set may start fresh.

### Candidate discovery

Part 5 queries Roblox's public server browser for the current `game.PlaceId`.

The current documented Games API exposes public place-server listing endpoints.

Candidate filtering is local and deterministic by policy:
- public server,
- current place,
- actual reported occupancy is 11 or 10,
- reported max players is compatible with the requested 12-player MM2 target,
- JobId is non-empty,
- JobId is not current,
- JobId is not visited/attempted.

11-player candidates are ranked before 10-player candidates.

Within the same occupancy tier, candidate order may be randomized to reduce repeated contention for the same first server returned by the public list.

Part 5 may paginate the public-server response, but server-list work must be bounded per refresh cycle and recover from HTTP/JSON errors.

### Teleport execution and failure recovery

Because this is client/executor code, Part 5 uses the client-capable specific-instance teleport path rather than server-only `TeleportAsync()`.

Each teleport attempt is serialized under one authoritative HOPPING session/generation.

For each candidate:
1. persist visited state,
2. mark candidate attempted,
3. issue one protected specific-server teleport call,
4. observe `Player.OnTeleport`,
5. observe `TeleportService.TeleportInitFailed`,
6. never issue a second candidate while the current attempt is still genuinely in progress.

If the call throws immediately:
- record failure,
- move to the next candidate.

If Roblox reports `TeleportState.Failed` or `TeleportInitFailed` and the player remains in the current server:
- keep the failed JobId excluded,
- move to a different candidate.

If the target filled between discovery and join:
- treat it as an ordinary failed candidate,
- select another unvisited 11/12 or 10/12 server.

Part 5 does not repeatedly retry the same failed JobId.

If all currently discovered candidates fail, fetch a fresh server list after the normal 5-second refresh interval.

### Delta Auto Execute

Delta Auto Execute is the primary relaunch mechanism.

Part 5 does **not** add executor-specific `queue_on_teleport` logic in v1.

Reason:
- Delta already provides built-in auto execution,
- a second auto-execute path could start duplicate PDIDDLER stacks,
- no verified Delta queue API is required for the feature.

The user's Auto Execute text file should load the current integrated PDIDDLER stack.

### Arrival behavior

After a successful hop:
1. Delta Auto Execute relaunches the stack.
2. Part 5 bootstrap restores its persisted visited state.
3. Part 1 runs its existing known-good bot detector.
4. If Part 1 approves, normal Parts 2–4.5 and post-trade claim behavior start.
5. If Part 1 rejects the server as a bot lobby, the stack must **not** simply terminate.

For bot rejection, a minimal early Part 5 bootstrap immediately:
- adds the rejected current JobId to visited state,
- enters HOPPING,
- finds another 11/12 or 10/12 server,
- repeats until Part 1 approves a server.

Part 1 itself remains unchanged as the bot classifier.

## Integration architecture

### New Part 5 module

Proposed file:
`pdiddler/pdiddler5_server_hopper_v1.lua`

Responsibilities:
- restore/persist hop state,
- own the HOPPING session lock,
- fetch/filter/rank server candidates,
- execute one teleport at a time,
- recover from immediate and late teleport failures,
- provide an early bot-reject rehop entry point,
- attach the normal 45-second exhaustion controller after Part 3 is armed.

It must not:
- classify inventories,
- determine market values,
- send trades,
- modify Part 4 offers,
- accept/decline item trades,
- claim post-trade rewards,
- classify bot lobbies.

### Scanner integration

The canonical scanner needs one small public final-verification capability that reuses its existing internal `scanPlayerLive` / `scanOne` path.

Proposed new scanner API:
`ScannerAPI.finalRescanAll()`

Requirements:
- no second parser,
- scan current non-local players,
- respect scanner critical-activity gates,
- settle all canonical classifications,
- handle joins/leaves occurring during the pass,
- return a summary / completion result suitable for Part 5.

This should be implemented as a minimal extension of scanner v6.9, producing a new version rather than modifying the frozen file in place.

### Outgoing integration

Part 5 must not reverse-engineer Part 3's private queue state.

Outgoing should expose a small read-only status API from its existing authoritative state, likely through its returned controller.

Required information:
- whether an unprocessed whitelisted target currently exists,
- whether Part 3 has active request/trade work,
- whether a target is still maturing / deferred for retry,
- whether the queue is truly exhausted.

Part 5 uses this read-only status rather than maintaining duplicate processed-target logic.

The existing outgoing behavior remains unchanged.

A minimal pre-hop hold flag may be added so Part 3 cannot start a new outgoing request during the final scan/commit-to-hop window.

### Shared pre-hop lock

Proposed ENV session flag:
`PDIDDLER_HOP_PRECHECK_BUSY_SESSION`

Purpose:
- stop a new outgoing request from beginning after the 45-second deadline while final verification is underway,
- allow scanner verification to continue,
- release immediately if a tradable target appears,
- transition into HOPPING if final verification remains exhausted.

This is separate from:
`PDIDDLER_POST_TRADE_CLAIM_BUSY_SESSION`

No hop may begin while:
- an item trade is open,
- an outgoing request is active/pending,
- post-trade claim is busy,
- scanner classification is unresolved,
- final verification has discovered a tradable target.

## State machine

```text
ACTIVE
  |
  | no unprocessed tradable target
  v
EXHAUSTED_COUNTDOWN (45s)
  |  |  new confirmed tradable target
  |  -> ACTIVE / reset future countdown
  |
  | scanner temporarily unresolved
  | -> timer may continue, hop blocked
  |
  v
FINAL_SCAN
  |  |  tradable target found
  |  -> ACTIVE
  |
  v
HOPPING
  |
  v
FETCH_SERVERS
  |  |  none 11/12 or 10/12
  |  -> wait 5s -> FETCH_SERVERS
  |
  v
ATTEMPT_11
  |  |  failed/full -> next candidate
  |
  v
ATTEMPT_10
  |  |  failed/full -> next candidate
  |
  v
TELEPORTING
  |
  v
DELTA AUTO EXEC
  |
  v
RESTORE VISITED
  |
  v
PART 1 BOT CHECK
  |  |  BOT -> HOPPING immediately
  |
  -> APPROVED -> normal stack
```

## Timer semantics

The 45-second countdown measures time since true outgoing exhaustion.

Temporary unresolved scanner work from a new ineligible player does not grant another 45 seconds.

A confirmed new unprocessed tradable player invalidates the exhaustion period.

If that player is subsequently processed and the queue becomes exhausted again, a new 45-second countdown starts.

The countdown must be session/generation owned so an old timer cannot hop after new work appeared.

No detached `task.delay` callback may be allowed to commit a hop based on stale state.

## Failure and race cases

### New player joins at 44.9 seconds

- PlayerAdded starts canonical scanning.
- Hop cannot commit while scanning is unresolved.
- If eligible/unprocessed -> cancel exhaustion.
- If blacklisted -> deadline remains effectively reached, then final verification continues.

### New player joins during final scan

The final scan observes a player-set generation change and includes/awaits the new player's classification before the hop decision.

### Trade opens during countdown

Countdown cannot commit while active work exists.

If the trade resulted from a new tradable target, exhaustion is invalidated.

### Claim popup is active

No hop.

Post-trade claim retains priority until claim release.

### Server API request fails

Do not hop randomly.
Keep current server.
Use bounded HTTP retry/backoff.
Return to 5-second discovery cadence after failure handling.

### Candidate becomes 12/12/full

Do not retry same JobId.
Select next 11/12 or 10/12 candidate.

### Every preferred candidate was already visited

Stay in current exhausted server and refresh until a genuinely new 11/12 or 10/12 JobId appears.

### Teleport starts, then late failure leaves player behind

Use `OnTeleport` / `TeleportInitFailed` evidence.
Release current attempt only after failure is observed.
Exclude failed JobId and continue.

### Duplicate script execution after teleport

v1 intentionally relies only on Delta Auto Execute.
Existing PDIDDLER session IDs continue invalidating old local callbacks.
Part 5 additionally owns a hop session/generation so duplicate hopper loops cannot issue competing teleports.

## Diagnostics

Keep diagnostics concise.

Expected high-signal logs:

```text
[PDIDDLER P5] EXHAUSTED | hop in 45s
[PDIDDLER P5] TRADABLE JOIN | countdown reset | <player>
[PDIDDLER P5] FINAL SCAN START
[PDIDDLER P5] FINAL SCAN CANCEL | tradable target <player>
[PDIDDLER P5] FINAL SCAN CLEAR | no targets
[PDIDDLER P5] SERVERS | 11/12=<n> | 10/12=<n> | visited=<n>
[PDIDDLER P5] HOP ATTEMPT | 11/12 | <jobId-short>
[PDIDDLER P5] HOP FAILED | <reason> | trying next
[PDIDDLER P5] NO TARGET SERVERS | refresh in 5s
[PDIDDLER P5] BOT SERVER REJECTED | re-hopping
```

No per-frame/poll spam.

## Testing strategy

Implementation must be TDD-first.

Pure-policy tests should cover:
- 45-second timer semantics,
- ineligible join does not reset,
- unresolved join blocks commit but does not reset,
- eligible join resets,
- 11 before 10,
- never choose 9 or lower,
- current/visited exclusion,
- attempted-before-teleport exclusion,
- failed candidate advances,
- no candidates -> 5-second refresh,
- bot rejection -> immediate hopper path.

Integration/static tests should cover:
- Part 1 remains the bot classifier,
- final scan reuses scanner API,
- no duplicate inventory parser,
- one HOPPING owner,
- no hop during claim/trade/outgoing/scanner work,
- no `queue_on_teleport` dependency,
- v7 final Accept remains disabled,
- existing Part 1–4.5 regressions still pass.

Live validation should deliberately test:
1. exhausted server -> 45s -> final scan -> hop,
2. ineligible join during countdown -> timer not reset,
3. eligible join during countdown -> timer reset/cancel,
4. target 11/12 fills before join -> automatically tries another preferred server,
5. no 11/12 or 10/12 -> remains and refreshes,
6. bot lobby arrival -> immediate re-hop,
7. successful arrival -> Delta auto-exec -> normal stack resumes,
8. never rejoins a visited JobId in the same chain.

## Approaches considered

### Approach A — Delta Auto Execute + Roblox teleport settings
**Selected.**

Pros:
- smallest executor-specific surface,
- no duplicate execution path,
- native client teleport-state persistence,
- clear ownership boundaries.

### Approach B — Delta Auto Execute + queue-on-teleport fallback
Rejected for v1 because a second auto-execution mechanism can double-launch the stack and relies on unverified Delta-specific API behavior.

### Approach C — executor-file persistence and script-managed re-execution
Rejected because it adds unnecessary executor-specific storage and duplicate lifecycle logic when Delta Auto Execute + teleport settings already satisfy the requirement.

## External API assumptions verified during design

Roblox Creator Hub currently documents:
- `TeleportService:SetTeleportSetting()` and `GetTeleportSetting()` as client-side settings preserved across teleports within the same game,
- `TeleportService.TeleportInitFailed`,
- `Player.OnTeleport`,
- `TeleportToPlaceInstance()` as the specific-running-instance client-capable legacy path,
- public Games API place-server listing endpoints under `games.roblox.com`.

Implementation must still handle all external API calls as fallible.

## Non-goals

Part 5 does not:
- automate the final item-trade Accept,
- change market strategy,
- alter bot classification rules,
- trade processed players again,
- select 9/12 or lower servers,
- randomly teleport without a verified server candidate,
- permanently store visited server history across unrelated user sessions.

## Approval gate

No production code should be written until this design is approved.


## Standalone validation gate before full PDIDDLER integration

Part 5 must **not** be wired into the full PDIDDLER stack immediately.

The first live artifact is a dedicated **Part 1 + Part 5 server-hopper lab**. Its purpose is to validate the transport/lifecycle layer independently from trading.

The standalone lab validates:
- Part 1 remains the bot-lobby authority.
- Approved lobby -> Part 5 test exhaustion countdown -> server discovery.
- 11/12 preferred over 10/12.
- 10/12 used when no valid 11/12 exists.
- 9/12 and lower never intentionally selected.
- current JobId excluded.
- attempted/visited JobIds persist across the teleport chain.
- failed/full candidate moves to a different candidate.
- no preferred candidate -> 5-second refresh.
- Part 1 bot rejection after arrival -> immediate Part 5 re-hop.
- Delta Auto Execute relaunches the lab after successful teleport.
- no duplicate hopper loops/teleports.

The standalone lab does **not** claim to validate true Part 3 exhaustion, tradable-player resets, or the mandatory final canonical inventory scan. Those require scanner/outgoing integration and happen only after the transport layer is live-proven.

### Standalone lab exhaustion source

Because Part 3 is intentionally absent, the lab uses a clearly test-only exhaustion driver:
- after Part 1 approves the current server, start a 45-second LAB countdown,
- no inventory/tradeability claim is made,
- at the deadline, invoke the same Part 5 server-selection/teleport transport path that production will use.

This keeps production hopper transport identical while avoiding a fake/duplicate inventory scanner in the lab.

Proposed lab file:
`pdiddler/tests/pdiddler_P1_P5_SERVER_HOP_LIVE_LAB_v1.lua`

Only after the P1+P5 lab is live-proven should scanner v6.10, outgoing v17, and the integrated v8 stack be built/wired for production exhaustion behavior.
