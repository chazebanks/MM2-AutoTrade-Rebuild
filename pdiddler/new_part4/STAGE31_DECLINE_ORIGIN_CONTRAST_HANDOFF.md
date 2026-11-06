# Stage 31 — Local-vs-partner decline signal contrast

**Status: independent, read-only contrast; no native action controls.** This stage intentionally **reuses the already-proven Stage30 Delta script byte-for-byte** and adds an offline comparison, not a second Roblox listener stack.

## Evidence and source contract

The Stage30 live iPad/Delta run was a **manual local decline**. Its anonymized native report listed 16 trade RemoteEvents and exactly one inbound `DeclineTrade` receipt while the bound GUI was open (elapsed 12.575s). The window subsequently closed `CLOSED_UNKNOWN`. Neither side had accepted, and the partner had not departed.

Roblox's official API reference states `RemoteEvent.OnClientEvent` receives a server-to-client `FireClient` or `FireAllClients` invocation. The event's **name** and delivery **do not authenticate who initiated the decline**, whether the event was broadcast to multiple players, or whether the server settled the trade. The server may send the same name for local and remote actions. We therefore need a contrasting, operator-controlled trial.

- Official RemoteEvent reference: https://create.roblox.com/docs/scripting/events/remote
- Original Stage30 source (immutable and already live tested): `84edfff652bcc3614092214fdd155efd9101be30/pdiddler/new_part4/STAGE30_READONLY_CLIENT_SIGNALS_DELTA.lua`
- Prior Stage30 PR: https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/69

## New offline logic

`intelligence_lab/stage31_decline_signal_contrast.py` compares two anonymized Stage30 reports with declared experimental conditions:
- **First trial:** the user manually declined (already observed).
- **Second trial:** the **trade partner** manually declines while the user does not touch Decline or Accept (still needs native testing).

It requires the native Stage30 schema, bounded/valid remote catalog, closed GUI, finished post-close grace, neither side accepting, and no partner departure. The pair is reduced to **sets of client-observed event names only**—not raw arguments, timings, or account identities.

Possible offline results:
- `SHARED_DECLINE_NAMED_RECEIPT_NO_ACTOR_PROOF`: both client runs observed `DeclineTrade`. This is evidence that the name alone **cannot distinguish the declared initiators** in these two observations. It is not proof either run ended via an authenticated decline.
- `INCONCLUSIVE_DIFFERENT_CLIENT_RECEIPTS`: the event names differ or one is absent. This does **not** establish that a name identifies the initiating player; distinct UI timing, signal delivery and game states can cause differing observations.
- Invalid/incomplete context is rejected as `InvalidEvidence`, not interpreted as a new outcome.

Every returned record explicitly retains `initiator_proven=false`, `decline_proven=false`, `server_completion_proven=false`, `may_record_completed_trade=false`, `may_report_profit=false`, and `authorizes_accept=false`.

`intelligence_lab/test_stage31_decline_signal_contrast.py` includes 14 synthetic cases plus the real native Stage30 **local-decline baseline facts**. Synthetic partner reports in tests are not genuine native observations.

## ONE next iPad experiment

1. **Rejoin MM2** to clear Stage30's long-lived scanner and client listeners, select Tablet, and run the exact Stage30 one-paste Delta launcher linked above **before opening a trade**. There is no reason to replace tested observer logic.
2. Let the scanner finish and manually open a trade with a trusted partner. Neither player needs to offer a weapon and **neither player presses Accept**.
3. When it prints `[GINGERSCOPE STAGE30] TRADE BOUND`, **do not tap Decline or close the window yourself**. Ask the *partner* to click Decline on their client within 30 seconds. The partner should remain connected to the same MM2 server.
4. The existing observer watches the GUI closure plus about two seconds of inbound client events. It copies and prints anonymized `GINGERSCOPE STAGE30 ANONYMIZED` JSON; send that JSON and say **"partner clicked Decline"** as a self-reported experimental condition.
5. If you accidentally press Decline or Accept, or the partner leaves/rejoins, the test no longer matches its condition; report the deviation rather than treating it as verified. Rejoin after testing.

**No weapon exchange, final Accept, automated requests, active Part4, webhook, or profit computation is required or permitted by Stage31.**

## Crucial limitation

A comparison of two manually labeled trials cannot *authenticate* an action's source. Even if the partner test shows a different named event, it would be premature to create a classifier; additional controlled scenarios and transaction-correlated server evidence would be needed. A positive `CompleteTrade` receipt still cannot be promoted to completed-trade authority.

This stage is ready only for a controlled **partner-initiated manual decline** test after CI. Do not re-run the already completed local-decline trial.
