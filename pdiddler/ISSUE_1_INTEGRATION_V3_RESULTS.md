# Issue #1 — isolated integration V3

The reported failure was **staying in a bot server**, not a reported console
exception. No recording or detector result for that run was supplied. The
following is a reproduced integration failure that explains that behavior when
V5 produces a corroborated bot verdict; it is not proof of the verdict produced
in the user's particular run. The detector's false-negative rate remains unknown.

## Reproduced cause

V1 `pendingUiVisible()` looks under
`MainGUI.Lobby.Leaderboard.OverlayMenu.TradeRequest` (lines 93–100).
The documented tablet hierarchy and the working outgoing module instead use
`MainGUI.Lobby.Leaderboard.Container.OverlayMenu.TradeRequest`.

With that real hierarchy, V1 cannot find the request frame and returns `true`
for unknown UI. Even a strong `BOT_PATTERN_FOR_REVIEW` then takes
`BOT VERDICT HELD`, returns without invoking P5, and leaves its integration lock
running. Its exhaustion path is blocked by the same lookup. The isolated fixture
reproduces **zero hops on a corroborated bot** in V1 and **one P5 hop with no
scanner/trading startup** in V3. Active requests and trades still block hopping.

V2 was also inspected. It removed the pending-UI check from bot rejection rather
than repairing the path, and retained that path in its exhaustion monitor. V3
repairs the path and keeps both request/trade protections.

## Other confirmed source defects addressed

- V1 bounds HTTP fetch only. Compilation execution, P2 `run()`, scanner's full
  initial server scan, and subsequent startup can yield without a watchdog.
  Scanner exposes its API only after its initial scan; a long pause is not
  necessarily an error. V3 permits a bounded 240-second scanner initialization,
  with explicit phase diagnostics, and never retries side-effecting execution.
- Fetching the gate consumes V1's observation deadline. V3 downloads first,
  then allows V5's ten-second sampling window with 0.5-second scheduler grace.
  V5 can wait two seconds for its GUI before returning nil; launch has a
  three-second bound inside the observation budget. Unknown/unavailable detector
  outcomes permit trading without declaring the server normal.
- A nil return is valid for V5. V3 distinguishes execution success from the
  module return value. It clears the result slot, checks exact new generation,
  job, evidence version, elapsed time and unchanged roster, then fences late
  callbacks. It does not invent a generation field in the frozen result.
- V1's async bootstrap is unprotected, and errors leave `running=true`. V2
  releases that lock even after partial initialization. V3 catches errors,
  stops owned trading controllers, and keeps a dirty-server lock whenever a
  scanner/P5 may already have installed background work. Rejoin for that retry.
- Busy/unknown UI previously reset exhaustion. V3 resets only for eligible
  traders; scanner work, requests, trades and unknown UI block the hop. Missing
  player records block the scanner's delayed join window. The two-second final
  recheck observes eligibility and processed changes throughout.
- P5 V1 loops indefinitely on discovery failures and after Started without
  completion. V2 bounds discovery and attempts, correlates failure targets, and
  holds on ambiguous/no-progress outcomes. An unattributed late failure cannot
  trigger a competing teleport. Transport safety is checked again immediately
  before the actual teleport, after yielding server discovery. Outgoing/P4 are
  quiesced at that boundary. Candidate ranking stays **11/12, then 10/12**.
- Frozen scanner/outgoing/P4 cache PlayerGui. V3 tolerates temporary absence of
  the same GUI, but fails closed and stops workers if that instance is replaced.
  It does not pretend a monitor lookup repairs workers' stale GUI references.

## Preserved sources and references

All original repository files are preserved. V1/V2, frozen Parts 1/2,
scanner/value tables, outgoing ownership, P4 planner/executor and final-Accept
behavior are not modified. The actual current P4 is the handoff's later
v2.3 EXTREME GUARD (section 29), not the superseded section-14 v2.1 build.

Every runtime dependency is pinned to a full immutable commit. P2, gate, scanner,
outgoing and P4 paths were fetched successfully at their exact pins; the existing
V1 scanner/P4/outgoing refs were valid, not missing-file failures. Original P5
policy is fetched from `3be1c15f435389ff518cf3a4594b34efc08e84de`.
New transport V2 is pinned at `a20e96fff663e42e50bf668d5be5c7b148a70b9e`.
See `tests/integration_sources_v3.json` for refs and verified Git blob hashes.
The policy fixture is a byte-identical copy, allowing offline tests on this
branch without fetching the separate P5 branch.

## Changed files (additions only)

- `pdiddler_FASTGATE_V5_INTEGRATED_TEST_v3.lua`: one bootstrap/monitor.
- `pdiddler5_server_hopper_v2.lua`: one bounded transport owner.
- `tests/integration_fixture.lua`: deterministic scheduler and external boundaries.
- `tests/integration_v3_test.lua`: 37 bootstrap/monitor regression cases.
- `tests/hopper_v2_test.lua`: 14 actual transport/policy regression cases.
- `tests/fixtures/p5_policy_v1.lua`: unchanged original policy test dependency.
- `tests/integration_sources_v3.json`: immutable dependency integrity manifest.
- `tests/run_integration_tests.py`: local suite/syntax/source-integrity runner.
- This report and `../docs/superpowers/plans/2026-11-03-issue-1-integration-fix.md`.

## Verification

From the repository root:

```sh
python3 pdiddler/tests/run_integration_tests.py
```

Result: **37 integration + 14 transport tests passed**, seven dependency pins
and blob hashes matched, and all new Lua files passed syntax checks. Tests run
under texlua (Lua 5.3); Lua 5.3/5.4 plus luac also work. New runtime code uses
Lua/Luau-compatible syntax. Tests replace Roblox/executor boundaries; they do not
prove live networking, UI replication, classifier accuracy, or real teleports.
The branch had no existing unattended test suite; its old `test_runner.lua`
requires Delta and was not run headlessly. No value-refresh workflow was run.

The final assertions were also run against the original V1 scripts and failed
as expected. Baseline adapters translate only V1's few `+=`/`continue` constructs
in memory; the original source files are unchanged.

An independent read-only review found GUI-cache replacement, final-recheck
eligibility, unattributed late teleport failure, and gate-launch timing issues.
Each received a failing regression followed by a passing fix. A returned P4
controller is also stopped if GUI replacement occurs during its initialization.
Additional tests protect delayed discovery safety and outgoing quiescence.

Local Git network access failed because the managed proxy was unavailable.
Sources and publication used the connected GitHub API. The local checkout is
an explicitly reconstructed source snapshot, not a claim of a full Git clone;
publication builds on the complete original GitHub tree and adds only new paths.

## Delta test and remaining uncertainties

Use the single immutable V3 loader supplied in the PR, from a **fresh join**.
Disable older auto-execute loaders; enable only that same V3 loader after
teleport. V3 does not inject another queue-on-teleport owner. Roblox normally
creates a new client/VM on teleport; visited state uses P5's serialized teleport
setting. Actual Delta auto-execute and setting persistence remain live-only tests.

Expected flow: WAIT_GAME → TABLET → GATE → either HOPPING for corroborated bot
evidence, or INITIALIZE scanner → TRADING. FETCH/INITIALIZE phases name modules.
BOT_HOLD names the actual blocking UI. ERROR includes a reason and whether a
rejoin is required. Inspect `getgenv().PDIDDLER_INTEGRATION_V3` for current state.

Only the V5 two-positive-scan bot verdict, score ≥60, and at least six observed
players authorize rejection. Partial/animation evidence and unknown results
never authorize bot hops. Test one confirmed bot and one normal server first.
No final Accept is introduced, and the existing outgoing module is the only
trade-request sender.

Unknown/missing UI remains conservative: after a corroborated verdict it is
rechecked for 15 seconds, then stops with the blocking reason. Full PlayerGui
replacement, dirty initialization and ambiguous teleport require rejoining.
A 35-second progress timeout reports HOLD and retains hop ownership rather than
guessing the teleport failed; without progress the ambiguity bound is 12 seconds.
Discovery is at most two passes of five pages (14 seconds per HTTP call), with
five seconds between passes and at most six explicit-failure candidate attempts.
Permissions/HTTP, actual GUI paths across MM2 updates, task.cancel behavior,
Delta scheduling, bot classification and real teleport completion are unverified.
V3 requires `task.cancel` and fails before module startup if it is unavailable.

The final exhaustion review reads authoritative scanner records and pending
work; it is **not a forced fresh inventory scan** (no public API exists).
The scanner has no stop API, so partial init may leave display/background reads
until rejoin, but V3 will not install duplicate controllers on a dirty server.
Cooperative watchdogs cannot preempt a CPU-bound/non-yielding executor call.

Next step: review the PR, then run the single loader on a fresh Delta session
and observe its phase/reason on the confirmed bot server. Do not merge on the
basis of offline tests alone. No automatic merge is requested or enabled.
