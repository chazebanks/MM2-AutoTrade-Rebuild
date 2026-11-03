# Pdiddler Fast Gate V5 → Trading/P5 Integration — test checkpoint

Date: 2026-11-03. New file: `pdiddler_FASTGATE_V5_INTEGRATED_TEST_v1.lua`.

## Verified source interfaces
- Fast Gate V5 publishes `getgenv().PDIDDLER_FAST_GATE_RESULT` with `state`, `jobId`, `evidenceVersion=5`, `appearanceScans`, `appearanceScore`, `total`, `automaticHopAllowed=false`. It does **not** publish a per-result generation, so the integrated launcher clears the result slot and checks the monotonic gate generation changed.
- P2: frozen `run()` physically selects tablet, prior to detection.
- P3 outgoing: `run(scanner)` returns `session,state,stop`, with `state.processed`, `active`, `paused`, `uncertainOutgoing`. Sender sets `PDIDDLER_OUTGOING_BUSY_SESSION`.
- P3 scanner: `getWhitelist()`, `hasPendingWork()` and record APIs, with its own periodic rescan. **No public force-rescan method**.
- P4: `run(scanner)` returns `session,state,stop` and `state.active`; claims `PDIDDLER_STATUS_OWNER=P4` while handling a trade.
- P5 on `feature/mm2-server-hopper-design`: `bootstrap(policy)`, `controller:handleBotRejected(reason)`, `controller:hopNow(reason)`, `controller:isAlive()`, and `controller.state.hopping`.

## One-owner sequence
1. Initialize the existing P5 transport (no teleport yet).
2. Select Tablet using the frozen Part 2.
3. Execute the tested standalone Fast Gate V5. Its diagnostic `automaticHopAllowed=false` remains unchanged.
4. If the result is a fresh, two-scan, >=60-score `BOT_PATTERN_FOR_REVIEW`, Part 5 is the **only** teleport owner. Parts 3/4 never start in that branch.
5. For all unknown, insufficient-coverage, animation-only and timeout outcomes, start the frozen/scoped Part 3 scanner, Part 4 and Part 3 outgoing stack. Do not treat these outcomes as evidence of a normal server.
6. Once the queue is processed and no work/request/trade is owned, start a 45-second idle countdown. At timeout wait another 2 seconds and recheck the exposed scanner records/roster/request/trade state; stop if any changed. Only P5 can hop.

## Important limitations
- **This is a runtime test stack, not a validated live release.** No Delta execution performed.
- The final 45-second verification is a **scanner-state review**, not a forced fresh inventory RPC. Changing scanner internals to add one was intentionally deferred to protect the known-good module.
- The status of incoming and pending request UI is checked conservatively; unavailable UI blocks a hop.
- The standalone V5 classifier has only one labeled positive and one labeled negative success so far. Do not generalize its true positive/false positive rates.
- Bot rejection initiates real P5 teleports; run only when ready for server switches. P5 public server list and teleport APIs might be unavailable/restricted in a given executor.
- Delta auto-execute is required to rerun this one entrypoint after teleports; the integration deliberately does not inject a separate queue-on-teleport subsystem.
- Previously frozen files are not overwritten. Existing P4 final trade Accept remains disabled.
- Stop-on-error can leave successfully loaded scanner display/task loops active; do not reexecute the integration repeatedly in the same server after a partial initialization failure without rejoining.
- P5's transport loop has its own longer-running server-fetch and teleport recovery logic; this integration does not alter it.

## Live tests
- First run with no current trade: confirm P2 -> 10s Fast Gate -> one of `BOT SERVER: P5 OWNS HOP` or `TRADING ACTIVE`.
- On a normal server, verify Part 3 sends requests, Part 4 trade window opens, and no 45s hop occurs while request/trade is active.
- On a confirmed bot server with two strong appearance scans, verify P3/P4 never start and only P5 hops.
- After traders are exhausted, wait 45s and verify countdown resets on new trader or scanner activity.
- Confirm real final-Accept behavior remains unchanged (disabled).
