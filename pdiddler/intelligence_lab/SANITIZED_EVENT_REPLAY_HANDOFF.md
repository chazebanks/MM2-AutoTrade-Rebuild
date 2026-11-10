# Sanitized temporal event replay — offline research only

This is a deterministic CLIENT observation state model, not an MM2 client,
authenticated server session, trade settlement validator or Discord learner.
It must not be confused with the existing Stage67 strict client report auditor
(PR120) or Stage68 client GUID shadow deduplicator (PR121).

## November 10 Stage112: session-token reuse quarantine — TESTED

[Stage112 DRAFT PR190](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/190) identifies a previously untested **sanitized client session-token reuse** defect in the ORIGINAL `scripts/replay_trade_events.py`. The event `id` deduper only rejects repeated/conﬂicting event IDs; a DIFFERENT `OPEN` event ID with the SAME `session` could reset the client's replay `revision=0` and observed accept flags as if a fresh trade opened. This applied after an active OPEN, after CLOSE plus an untrusted inventory delta, and after another session had superseded the first. It permitted client evidence to be incorrectly associated with a purported new session. This bug affected simulated evidence counters, **not** real Roblox server state or final Accept, which were already denied.

**TDD RED evidence:** New focused tests added first on test-only exact SHA `f2e2f40e9561b83d8a5ad6425822669a478a0fbf`. [Actions run #42838194339](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42838194339) FAILED precisely THREE distinct session-token reuse cases; replay incorrectly returned `CLIENT_REPLAY_ONLY`, and in one case showed `activeSession=true`, `currentRevision=1` for the reused closed session. A TRUE duplicate event ID for an OPEN stayed idempotent, as required.

**Minimal corrected original engine:** Track `opened_sessions: set[str]` in **one sanitized replay trace**, and on any new/distinct-ID `OPEN`, if the session has ever been opened, immediately return `QUARANTINED / REUSED_CLIENT_SESSION_TOKEN`, before resetting revision or acceptance. Exact duplicate event IDs are still de-duplicated before this guard. New unique sessions still replace the active client state as before, and stale callbacks for superseded sessions still count as cross-session. No change to the external event schema, client source privacy constraints, quoted market data, or proof/authority flags. No extra game APIs or Lua production changes.

**GREEN evidence:** Corrected source+tests SHA `4b9bac8952be38993eb5a8d2a80ae340fc15553f`; all **FIVE** actual main-based GitHub workflows PASS (original sanitized replay [#42838321462](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42838321462), Hypothesis properties, official Luau, Lune, Selene/StyLua). Original replay passed **17/17 focused tests**, including 500 seeded safe interleavings; broad offline intelligence suite **112/112 tests PASS**. No native iPad test required. If this handoff changes branch SHA, revalidate all exact-head CI before merging.

**Evidence boundary:** Sanitized client `OPEN`, `CLOSE`, `OFFER`, `ACCEPT`, `CALLBACK` and `INVENTORY_DELTA` describe client observations, never server-signed trade transaction IDs or authenticated completed settlement. `tradeOutcome=UNKNOWN`, `serverCompletionProven=false`, `eventSessionAssociationProven=false`, `mayRecordCompletedTrade=false`, `mayReportProfit=false`, `authorizesTrade=false`, `authorizesAccept=false`, and Discord/market learner disabled. Prior successful Stage106 original iPad 1+1 client raw-key↔GUI candidate consistency does not override this bound. User's test ALT remains excluded from market learner. No old Stage97/99/100/103/106 native test should be repeated for this offline-only fix.

## Implementation
Python engine: scripts/replay_trade_events.py
Actual tests: pdiddler/intelligence_lab/test_trade_event_replay.py
GitHub Actions: .github/workflows/gingerscope-sanitized-event-replay.yml

The strict schema requires exactly:
- schema: gingerscope-sanitized-client-events-v1
- sourceKind: SYNTHETIC_OFFLINE_TEST or SANITIZED_CLIENT_OBSERVATION
- clientRunNonce: a canonical UUID-like client-local identifier, never server proof
- events: 1–256 ordered, sanitized client event descriptors

Each event must have a short artificial ID, session token, monotone arrival
timestamp in milliseconds, kind, and the exact fields allowed for its kind:
OPEN, CLOSE, OFFER(side/revision/signature), ACCEPT(side/revision),
CALLBACK(signal), INVENTORY_DELTA(gained/lost eligible copy counts).

Never feed player usernames/IDs, JobIds, raw item keys, identifiable inventory
names, webhook data, account credentials, original unsanitized client receipts,
or raw trade payloads into this model. It quarantines unexpected keys, malformed
types, invalid timestamps, contradictory duplicate event IDs and revision reuse;
it never echoes source identifiers. Synthetic offer signatures must be neutral
test tokens such as bundle_a, not original item identifiers.

A changed offer revision invalidates client acceptance observations. A delayed
callback from the wrong session is excluded. Identical duplicate event IDs
are idempotent. A postclose inventory delta is recorded solely as an observed
client delta, not an attributable transfer. An unqualified DeclineTrade
signal cannot establish which player rejected an offer.

ALL return paths: tradeOutcome UNKNOWN; server settlement, profit, completed
trade recording, rejected trade learning, Discord webhook and automatic
trade/Accept permissions FALSE. Tests include 13 named checks, 500 seeded
interleavings, and the inherited mainline intelligence suite. The engine is
not wired to the production trade controller or to Delta. A future controller
parity test will be a separate reviewed issue and cannot assume replay-model
success implies game compatibility.
