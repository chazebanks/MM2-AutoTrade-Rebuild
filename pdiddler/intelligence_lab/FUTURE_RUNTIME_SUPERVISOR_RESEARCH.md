# Future MM2 runtime supervisor — OFFLINE event/state contract

**Status:** isolated, not merged, not connected to live MM2. Implements safe state transitions in pure Lua, with no Roblox, executor, HTTP, file, remote-event, Discord, webhook, trading, Accept, or teleport actions.

## Why this future part is worth preparing now

Previously working MM2 UI actions regressed around **Loading Character / Loading World**, trade GUI readiness, request button clicking, bot detection, and trade rotation. Incorrectly reusing a trade session after world changes or combining multiple overlapping async loops can cause lost requests, stale offers, or unwanted hops. This module provides a single future **authoritative state coordinator** that can be tested without entering MM2.

It does NOT attempt to click the tablet, detect bots, trade, switch servers, compute values, or verify trade settlement. Those will be separate adapter layers needing actual device observations. The coordinator is an offline contract specifying when such actions would remain blocked.

## States and events

Initial state: WAIT_WORLD. WORLD_READY with current job ID -> WAIT_UI_STABLE. Two stable, identical GUI fingerprints at least **1,500ms** apart -> SCANNING. A verified scan completion -> READY. TARGET_REVIEW -> TARGET_REVIEW; external request observation -> REQUEST_PENDING; exactly bound trade GUI, partner and server -> IN_TRADE.

Every OFFER_CHANGED increases monotonic offerRevision and explicitly invalidates older trade-plan proposals. TRADE_CLOSED produces **OUTCOME_UNKNOWN**, never a success. CONTINUE_ROTATION returns to READY only after client window closure.

HOP_REVIEW is possible from READY only with explicit not-in-combat evidence and a matching job. After an uninterrupted 30-second research-only countdown, HOP_ELIGIBLE may suggest reevaluating a server hop; it **cannot teleport**. Entering combat resets cooldown. Missing combat state, active trade, pending request or stale server job always blocks hop eligibility.

UI_LOST invalidates candidate, trade and scanner readiness, and returns to WAIT_UI_STABLE. WORLD_LOADING and SERVER_CHANGED invalidate the entire prior session, increment **epoch**, clear old offers/requests, and return to WAIT_WORLD. Every asynchronous event (including world events) must include the **current epoch**. Late callbacks from earlier world/server epochs cannot resume or settle a stale trade.

STOP ends this instance permanently; a fresh supervisor instance is necessary to resume. Unsupported or fabricated RESULT_VERIFIED events have no authority.

## Permanent output guardrails

Every result fixes authorizesTrade=false, authorizesAccept=false, mayRecordCompletedTrade=false, mayReportProfit=false, serverCompletionProven=false, tradeOutcome=UNKNOWN. canHopAsSuggestion is **only an offline advisory boolean**, not a teleport permission, and is true only while HOP_ELIGIBLE and confirmed not in combat.

No dynamic import, arbitrary code evaluation, hidden new threads, timing sleep, memory of visited servers or external platform access. A future adapter must prove the UI fingerprint, verified scanner, exact trade-session binding and result protocol independently.

## Testing and integration boundaries

- Native Lua5.4: named behavior checks for loading, 1500ms UI stability, stale callback epochs, request and partner matching, trade offer revisions, UNKNOWN outcomes, combat/hop cooldown and STOP.
- **5,000 deterministic event fuzz steps** stress the transition model. Python runs actual Lua and statically excludes prohibited side effects.
- No manual in-game testing required.
- Later integration must be **explicit and isolated**. Existing Stage59 passive observer, Stage52 market updater and Stage53–58 ID crosswalk must not be displaced by this experimental state controller. In particular it does not imply any production auto-accept readiness.

**Separate roadmap items:** real tablet/leaderboard UI adapter; snapshot-guided offer replanner; bot-server classification based on observed movement/animations rather than weak heuristics; safe server-hop deduplication; offline Discord-completed-trade report formatting once settlement proofs are available.
