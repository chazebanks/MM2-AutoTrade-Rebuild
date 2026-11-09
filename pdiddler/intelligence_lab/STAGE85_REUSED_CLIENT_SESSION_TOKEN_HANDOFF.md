# Stage 85 — Reused client session token rejection in actual offline trade-event replay

**2026-11-09. Narrow root cause:** Existing merged `scripts/replay_trade_events.py` de-duplicated event IDs but did **not** remember previously opened sanitized trade *session tokens*. `OPEN(s_main)` → `CLOSE(s_main)` → another `OPEN(s_main)` with a **different event ID** silently reset the replay as if a new trade window started. A delayed `ACCEPT_TRUE`, `END_TRADE` or post-close `INVENTORY_DELTA` labelled with `s_main` could then be counted in that new client's window. These are still never settlement-authoritative, but the misleading timeline would impede real debugging and future strategy-integration tests.

## One patch — no new framework, no live auto trading

The real existing merged replay module now remembers each *opened* client session token during the current, sanitized local replay. A second `OPEN` for the same token (whether after CLOSE or while still active) returns **`status=QUARANTINED` / `reason=REUSED_CLIENT_SESSION_TOKEN`**, with all trade/Accept, settlement, rejection, realized profit and Discord-learning authority FALSE. An EXACT redelivery of the *same* event ID and identical content remains idempotent because it is deduplicated first. A genuinely *different* new client-session token remains valid; delayed callback from the prior session is still excluded from the new one.

The change does **not** claim client-supplied IDs prove actor identity, real session association, server completion, a true trade transaction or a profit. Client nonce, fake event IDs and sanitized local session tokens are all untrusted. This is a reproducible **offline logical collision**, not a claim that the actual user's MM2 client ever reused a token.

## Regression requirements

The pre-existing `pdiddler/intelligence_lab/test_trade_event_replay.py` now adds:
- CLOSED same-token reopen with new event ID (ambiguous delayed callback and copy delta) → QUARANTINED.
- ACTIVE same-token reopen with new event ID → QUARANTINED.
- EXACT duplicate prior OPEN event ID/payload → no new session, still idempotent.
- Distinct `s_old`/ `s_new` after close → valid client replay, old delayed callback and inventory delta ignored.
- 400 seeded active/closed reuse cases always quarantine; no authority fields or raw IDs output.

Existing 13 base behavioral regressions, 500 random safe interleavings, the real Hypothesis properties/state-machine and full offline intelligence suite must all pass at exact PR head; if any fails, fix the root cause without skipping/weakening tests. Don't merge until reviewed. This PR modifies only the **actual replay Python engine, its existing tests, and this handoff**; no Gingerscope game Lua, trading/offer actions, pricing, bot avoider, clipboard probe or Discord integration is touched.

## Pragmatic next step once green

The user's goal is a working Gingerscope inventory-growth trader, not perpetual historical-proof research. After Stage85, begin **one integrated no-trade execution simulator** for the existing *real* Part 3 / Part 4 transition: load a verified eligible opponent → choose a safe opener or wait for theirs → receive an offer revision → compute a four-slot candidate plan against a frozen test market fixture → invalidate on mutation → manual final acceptance **only**. Require checks for desirability, demand, four slots, duplicate copies and cancellation; do not reintroduce obsolete blanket +15 profit. The terminal evidence replay remains a diagnostic feeding `UNKNOWN` until a separate authenticated source proves settlement. Do not pretend the replay model alone tests Roblox native UI or server remote behavior.

**No iPad/ALT transfer test for Stage85.** All live offers, automatic final acceptance, profit claims, and Discord learning remain disabled; earlier verified Stage83 69/69 historical reference coverage and Stage84 Nov9 190-row fresh-at-capture price research are not affected.
