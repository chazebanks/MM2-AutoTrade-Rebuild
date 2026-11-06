# Direct key Stage 38 — bounded manual offer / UpdateTrade proximity diagnostic

**Status: experimental source pending GitHub CI and any device validation. Not a weapon ID resolver.**

## Evidence driving the change

First genuine PR76 native `UpdateTrade` result showed one top-level TABLE, 6 tables/14 entries, two opaque userdata leaves and status `INCOMPLETE`. Crucially the local window displayed **0 items on either side**, and the offer had not changed when the listener stopped after the first event. That receipt cannot be attributed to Batwing or any offered item.

## Narrow implementation

New `DIRECT_KEY_READONLY_OFFER_EVENT_CORRELATION_PROBE.lua` is a separate launcher, leaving the proven PR76 first-event script untouched. It reuses immutable existing Stage9 observer/contract modules and the PR76 type-only payload inspector. Nothing is installed into the production auto-trader.

The manual test must open an **initially empty** trade. After the script reaches the listening phase, the operator manually adds ONE inexpensive weapon to exactly ONE side. The script:

1. Binds the known player, visible trade root and a unique incoming `UpdateTrade.OnClientEvent`, with the same fail-closed checks as PR76.
2. Records **only bounded sanitized event shapes** and local receipt timestamps, not raw event argument tables, field names or weapon keys. It ignores an initial empty-trade event rather than stopping.
3. Polls the existing Stage9 GUI observer for **one** newly visible slot on one side and stable private offer signature for at least 150ms. No accept indicator permitted.
4. Waits through a bounded 1.5-second proximity window around the **first observed GUI change** to admit event-before-GUI and GUI-before-event orderings.
5. Reports a **temporal candidate** only with exactly ONE event in that window. Zero events => `NO_UPDATE_NEAR_SINGLE_OFFER_ADD`; multiple => `MULTIPLE_UPDATES_NEAR_SINGLE_OFFER_ADD`; additional offer mutation/reversion => fail closed; no allowed event within 30 seconds => incomplete. Every terminal path disconnects.
6. Never decodes ID semantics, calls a trade remote, adds/removes a weapon, presses Accept, reports completion, or triggers a webhook. The `temporalOfferEventCandidate` boolean is **only local proximity**, not authoritative causality. All raw-key, owner-side-slot-bound, identity, trade/Accept/completion/profit authority flags remain false.

Max 12 incoming receipts, 30-second attached window; first event argument inspection is via the existing 8-argument, depth4, 32-table, 128-entry bounded shape inspector. Reports expose fixed enums and counts only.

## Known limitations / evidence to seek

- Two independent events can occur near the same GUI mutation; their proximity does not prove either event caused it. The closest event is never arbitrarily selected when multiple candidates exist.
- If a game update arrives earlier/later than 1.5s from first visible mutation, the correct relationship may be missed. A non-match is **not proof** UpdateTrade cannot carry item information.
- GUI synchronization and event order remain client-only; no server session, player/side/slot raw key or event semantics are established.
- The original native payload has opaque userdata values. The current shape inspector remains correctly `INCOMPLETE` for unknown leaves even when the temporal candidate was observed.
- Identity resolution requires additional independent evidence of **raw key + owner/side + specific slot + current trade/session**, not a temporally adjacent event alone.

## Test boundaries

New dedicated native mock regression covers pre-offer unbound events, both arrival orders, ambiguous multiple events, no-event, far event, baseline already populated, partner/session invalidation, acceptance, cancellation, module load failure, cleanup and no outgoing remotes. This is simulated client behavior and does **not** prove a real `UpdateTrade`/Batwing correlation.

No native execution has been requested or performed for this code as of its initial PR. No auto-trade authority is enabled. PR76 is left untouched and still draft.
