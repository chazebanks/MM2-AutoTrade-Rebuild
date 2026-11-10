# Sanitized temporal event replay — offline research only

This is a deterministic CLIENT observation state model, not an MM2 client,
authenticated server session, trade settlement validator or Discord learner.
It must not be confused with the existing Stage67 strict client report auditor
(PR120) or Stage68 client GUID shadow deduplicator (PR121).

## November 10 Stage115 — post-close CLIENT readback evidence classification (not trade completion)

**Scope:** main-based [PR193](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/193), offline and read-only. Stage114 already **MERGED** the Stage112/113 fixes into main via PR192; Stage115 works on that actual merged source, not a stale stacked research draft.

**Problem:** The actual prior `scripts/replay_trade_events.py` counted every `INVENTORY_DELTA` received after client window `CLOSE` as `postCloseDeltaObservations`. The label means readback observation count, **not transferred copies**; crucially it included `gained=0,lost=0`, identical repeated readbacks with different event IDs, and mutually inconsistent snapshots. A downstream ledger could incorrectly interpret multiple observations as multiple successful transfers. A client `ACCEPT_TRUE` callback/closed GUI/postclose own-inventory change is never an authenticated settlement.

**Test FIRST** at exact SHA `77937aba7033673ce2f52d2098958b89cd3bcd46`: nine new original-engine cases cover zero-change after CLOSE, positive changed readback after both local accepted sides plus client callback, repeated identical readbacks from distinct event IDs, conflicting after-close snapshots, pre-CLOSE delta with `ACCEPT_TRUE`, CLOSE-only, new-session isolation and late old-session deltas, exact repeated event ID, and rejection of injected fake operator/server/profit verification fields. CI RED/GREEN verification must be recorded after GitHub Actions finishes; absence of a run is NOT a pass.

**Implementation** at branch commit `ce479b32e1c4228c236664fbecc3844816f06f11` adds:
- `clientEvidenceTier`: `NO_TERMINAL_CLIENT_EVIDENCE`, `CLIENT_WINDOW_CLOSED_ONLY`, `CLIENT_POSTCLOSE_NO_CHANGE`, `CLIENT_POSTCLOSE_CHANGE_UNATTRIBUTED`, or `CLIENT_POSTCLOSE_READBACKS_CONFLICT`. These are mutually exclusive **client-observation descriptors**, not a trust ranking or probability of a successful exchange. An active/new distinct client session clears any prior closed session tier.
- `postCloseUnchangedReadbacks` vs `postCloseChangedReadbacks`: observation counts, not cumulative item movements. A `(0,0)` readback is explicitly NOT an observed change.
- `postCloseReadbackRepeats`: new/different delivery IDs whose exact `(gained,lost)` pair has already appeared since the latest CLOSED client session; never treat them as additional trades.
- `postCloseDistinctReadbackPatterns`: number of distinct **patterns for the latest closed client session**, reset on another CLOSE or new OPEN. A second different pair makes the tier `CLIENT_POSTCLOSE_READBACKS_CONFLICT`, even if a later observation matches an earlier one.
- `operatorCorroborationProven=false` added to the constant denied-authority fields. Strict input schema rejects an operator/verified/completed/profit claim supplied inside untrusted client observations. Human-confirmed trial trades from earlier stages remain **historical corroboration only** and are not synthesized into a new authenticated operator receipt.
- Existing `postCloseDeltaObservations` continues to count observations for backward compatibility, NOT transfers; `clientInventoryDeltaObservations` retains its prior diagnostic semantics. Exact event-ID duplicates are filtered first; Stage112 client session re-open guard and Stage113 distinct accepted-side counters are unchanged.

**Non-negotiable authority boundary:** All paths preserve `tradeOutcome=UNKNOWN`, `serverCompletionProven=false`, `serverTransactionIdAuthenticated=false`, `eventSessionAssociationProven=false`, `exactWeaponIdentityConfirmed=false`, `mayRecordCompletedTrade=false`, `mayReportProfit=false`, `mayUseForStrategyLearning=false`, `authorizesTrade=false`, `authorizesAccept=false`, and Discord webhook unsent. No raw item keys, usernames, partner IDs or inventory payloads are exported. This cannot prove current MM2 server settlement, so it does **not** enable automatic final Accept or a completed-trade/profit webhook.

**Validation VERIFIED:** Source, 9 new focused test cases, original 500 seeded cases, original Hypothesis property invariants and dedicated workflow all passed at code+tests+workflow exact SHA `184edc5629923a9c6026b64df4fe1354b0f8765c`. **SIX/SIX GitHub Actions SUCCESS**: dedicated Stage115 source-only offline [run 42845947500](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42845947500) ran **31/31 focused Python tests, 4 Hypothesis test groups and 126/126 full offline intelligence tests**, explicitly printed `STAGE115_NO_TRADE_OR_SETTLEMENT_AUTHORITY_PASS`; existing sanitized event replay [run 42845947784](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42845947784) independently ran **31/31 focused + 126/126 full suite**, official Luau CLI [42845947519](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42845947519), Lune [42845947319](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42845947319), Selene/StyLua [42845947738](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42845947738), and standalone Hypothesis property [42845947415](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42845947415) all SUCCESS. The original 9 tests-first SHA `77937aba7033673ce2f52d2098958b89cd3bcd46` did not produce a visible CI run; it is NOT described as measured RED. Static inspection showed the old engine lacked the new evidence tier/counters. **Recheck all exact-head workflows after this documentation-only edit** before merge. Do NOT request a new iPad Stage106/Stage66 native test for this offline Python evidence-classification feature. Keep Gingerscope outgoing protected and the mandatory old +15 rule retired.

## November 10 Stage113 — distinct side/revision acceptance vs repeated client callback

**New [DRAFT PR191](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/191)** is stacked on Stage112 [PR190](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/190); NO production Roblox Lua, trade client, prices or webhook changes. The actual original `scripts/replay_trade_events.py` already de-duplicated EXACT event-ID copies and preserved `accepted` as a side set for each revision, but *incorrectly incremented `clientAcceptObservations` once for every newly ID'd ACCEPT event*. Therefore `ACCEPT(OURS, rev1)` twice could produce a count of TWO independent acceptances when only ONE client side was observed. It cannot prove the other side accepted or that the server settled the transfer.

**Test-first REAL RED:** Added five focused cases on original Stage112 engine at SHA `f14eb151d600b3e7ff58dbcd092fe0136850ad21`; [focused failed run 42840119556](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42840119556) reported **3 assertion failures +2 missing-field errors**. Cases cover two newly ID'd OUR accepts same revision; OUR repeat + THEIR once + AcceptTrue/CLOSE/postclose delta; new offer invalidates and permits distinct per-revision accepts; exact duplicated event ID stays idempotent; late acceptance from superseded client session excluded.

**Minimal correction** to the original engine: `clientAcceptObservations` now counts a side at most once per active offer revision; `repeatClientAcceptObservations` counts extra distinct-ID accepts for an already accepted side at that revision; `currentRevisionAcceptedSides` reports **0, 1 or 2** of the currently observed client sides (zero after CLOSE/invalidation), without returning side identifiers. A new offer resets accepted sides; a repeat in a *new* revision counts as a new logical observed acceptance. Existing Stage112 reopened-session-token quarantine, duplicated delivery-ID handling, sanitized schema and all server authority denial flags remain unchanged. Do not mistake observed sides for server-attested participants.

**Corrected original-source SHA `fd27f7f65bfba88f4d4f2b5f9dd8857bcb6a4970`: FIVE/FIVE mainline CI SUCCESS**, original sanitized replay [run 42840275162](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42840275162) **22/22 focused tests** + **117/117 full intelligence suite**; official Luau CLI, Lune, Selene/StyLua and Hypothesis property CI also PASS. Tests include existing 500 seeded interleavings and source event validation. This handoff edit itself changes the exact branch HEAD; recheck all CI on final HEAD before considering the stage fully reviewed.

**Evidence boundary unchanged:** In MM2 a client callback can be delivered more than once and the same player can provide repeated local GUI-state observations. No independent authenticated trade session, unique weapon instance, server result ID, both-sided settlement, current price or realized profit has been proven. `tradeOutcome=UNKNOWN`, all trading/Accept/profit/Discord/strategy-learner authorization stays FALSE. No fresh user iPad test required. Stage106 native client offered-key candidate consistency and Stage112 session reuse fix are complete independent milestones; do not repeat old tests.

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
