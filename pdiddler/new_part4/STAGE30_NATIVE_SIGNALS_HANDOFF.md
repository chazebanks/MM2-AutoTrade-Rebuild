# Stage 30 — Read-only native client trade-signal census

**Status:** Draft. A client-delivered RemoteEvent or GUI closure is never a server-authenticated trade result.

## Established evidence before Stage 30

- Stage 27 native iPad/Delta: manually controlled one-item ADD followed by REMOVE, both verified in separate Stage9 GUI observations.
- Stage 28 native iPad/Delta: partner-only Accept was observed on a legitimate **one-sided offer**. GUI then closed; result correctly `CLOSED_UNKNOWN`, no completed-trade authority. One-sided parsing false positive was fixed.
- Stage 29 native iPad/Delta: one own-inventory baseline plus **two post-close own-inventory reads** agreed, with no eligible delta and no raw weapon fingerprint change. Status `NO_ELIGIBLE_DELTA_OBSERVED` still says `tradeOutcome=UNKNOWN`, not 'declined'.
- Older `pdiddler_trade_lifecycle_v1.lua` expects a **native event adapter** with authenticated partner/session identities and verified final controls, but the code doesn't supply or validate such an adapter. It would be incorrect to wire an arbitrary `CompletedEvent` name to that adapter or to re-enable auto Accept.
- The public MM2 wiki documents glitches where both players press Accept but the trade never completes. Thus GUI acceptance alone is not a reliable completion indicator. Roblox's RemoteEvent mechanism delivers client/server messages, but a listener receipt is not itself an authenticated transaction proof.

## Stage30 specific question

Can a normal iPad/Delta client **observe a distinct, named, trade-related inbound RemoteEvent** when a manual trade is closed, or a partner departure in the same bound session? This stage **does not** attempt to determine whether the server settled or declined a trade. It inventories candidate signal names and temporal receipts without reading their payloads.

## New files

- `new_part4/p4_stage30_client_signal_census.lua`: pure session-bound, bounded client signal ledger. Catalog permits up to 32 unique safe remote names; stores 24 individual receipt observations and total count, plus whether the bound partner's departure was observed. Signals are labeled `WHILE_OPEN` or `AFTER_CLOSE`; never mapped to a `completed`, `declined` or `disconnected` trade result. No remote payload, item name, user ID, player name or job ID is reported.
- `new_part4/STAGE30_READONLY_CLIENT_SIGNALS_DELTA.lua`: one-paste, read-only Delta script. Reuses the verified Stage25 scanner-only boot, Stage9 GUI observer and Stage28 acceptance timeline. For one manually opened trade, subscribes only to **RemoteEvent.OnClientEvent** on descendants of `ReplicatedStorage.Trade`, and to the bound partner's `Players.PlayerRemoving`. The callback takes **zero arguments**; payloads are neither captured nor inspected. The probe never fires remotes or clicks any trade control.
- `new_part4/tests/test_stage30_client_signal_census.lua`: boundary tests for ambiguous event names, event timing, before/after close, empty census, partner departure, invalid session, event replay, event count limits and **no completion authority**.
- `intelligence_lab/test_stage30_client_signal_probe.py`: source-level no-action, no-payload and exact-loader-pin checks; executes the real Lua test and compiles the complete Delta launcher.

The original Stage29 ledger and all active trading code remain untouched. No code creates a webhook or completed-trade record.

## Native test: one manually closed trade

1. Rejoin MM2 to clear Stage29 listeners. Select Tablet and run the Stage30 launcher **before manually opening a trade**.
2. Let the existing scanner complete the normal player scan; manually open a trade with a trusted player. Do NOT click Accept. You do not need to place a weapon or have the other player press Accept.
3. When the console prints `[GINGERSCOPE STAGE30] TRADE BOUND`, manually decline/close the trade **within 30 seconds**. The script does not click Decline itself.
4. The probe observes an additional bounded ~2 seconds for delayed client messages, disconnects its own RemoteEvent and player-removal listeners, and prints/copies an anonymized JSON record beginning `[GINGERSCOPE STAGE30 ANONYMIZED]`.
5. Send only the JSON. Rejoin to clear the scanner's long-lived listeners.

If `catalogRemoteEvents=0` or `signalReceipts=0`, that proves only the probe saw no matching inbound events during this session. It does not prove MM2 has no transaction-success/decline mechanism; those may live elsewhere or have a different transport.

**Important:** A `CompletedEvent`, `DeclineTrade`, or similarly named inbound event (even with timing near closure) would still only be an **unverified client-side candidate**. A real success/decline classification would require a separately researched, session/partner-bound server result contract and corroborating inventory evidence. Final Accept, profit, and Discord completion stay disabled.

## Accuracy and privacy

- Outputs sanitized remote names only (not event argument values), capped at 32 catalog entries and 24 event observations. The names are game-developer-defined identifiers, not generated user handles.
- The event subscription itself cannot authenticate an event's causal relationship to a transaction. It is an observational experiment, not a server audit.
- If a different trade window opens during the post-close period, the probe stops and refuses to reuse the old session.
- Source prices are irrelevant to this read-only experiment, and Stage30 deliberately passes `marketFresh=false` to Stage9. No automatic trading permissions are derived.
- Synthetic Lua/CI tests do not substitute for the first live Delta signal census.

## References

- Roblox Creator Hub, Remote events and callbacks: https://create.roblox.com/docs/scripting/events/remote
- MM2 Wiki, Trading: https://mm2wiki.org/wiki/trading/
