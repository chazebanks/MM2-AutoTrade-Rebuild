# Sanitized temporal event replay — offline research only

This is a deterministic CLIENT observation state model, not an MM2 client,
authenticated server session, trade settlement validator or Discord learner.
It must not be confused with the existing Stage67 strict client report auditor
(PR120) or Stage68 client GUID shadow deduplicator (PR121).

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
