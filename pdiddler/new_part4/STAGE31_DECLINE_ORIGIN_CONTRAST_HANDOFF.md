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
- **Second trial:** the partner was instructed to manually decline while the user did not touch Decline or Accept. The user's second live client report contains a `DeclineTrade` receipt at **6.031s** while the window was still open. The partner action is a *declared experimental condition*, not authenticated by the diagnostic.

It requires the native Stage30 schema, bounded/valid remote catalog, closed GUI, finished post-close grace, neither side accepting, and no partner departure. The pair is reduced to **sets of client-observed event names only**—not raw arguments, timings, or account identities.

Possible offline results:
- `SHARED_DECLINE_NAMED_RECEIPT_NO_ACTOR_PROOF`: both client runs observed `DeclineTrade`. This is evidence that the name alone **cannot distinguish the declared initiators** in these two observations. It is not proof either run ended via an authenticated decline.
- `INCONCLUSIVE_DIFFERENT_CLIENT_RECEIPTS`: the event names differ or one is absent. This does **not** establish that a name identifies the initiating player; distinct UI timing, signal delivery and game states can cause differing observations.
- Invalid/incomplete context is rejected as `InvalidEvidence`, not interpreted as a new outcome.

Every returned record explicitly retains `initiator_proven=false`, `decline_proven=false`, `server_completion_proven=false`, `may_record_completed_trade=false`, `may_report_profit=false`, and `authorizes_accept=false`.

`intelligence_lab/test_stage31_decline_signal_contrast.py` includes the two *actual anonymized client trace facts* (local-close 12.575s; partner-close trial 6.031s), plus synthetic negative cases. Neither native report cryptographically attests the initiator, partner identity, or server outcome.

## Native contrast result and checkpoint

**Stage31's requested partner-close trial was returned by the user.** The user supplied an anonymized Stage30 report with these observations:

- Identical set of **16 discovered trade RemoteEvent names** in both runs.
- **Stage30 local-close:** one `DeclineTrade` inbound signal while the trade GUI was open at **12.575 seconds**.
- **Stage31 partner-close trial:** one `DeclineTrade` inbound signal while the trade GUI was open at **6.031 seconds**.
- In both runs: `CLOSED_WITH_CLIENT_SIGNAL_CENSUS`, `CLOSED_UNKNOWN`, neither Accept indicator observed, no partner departure, no post-close receipts, `serverCompletionProven=false`, `tradeOutcome=UNKNOWN`.

The pair classifies as `SHARED_DECLINE_NAMED_RECEIPT_NO_ACTOR_PROOF`. Under the declared conditions that different players initiated closure, **the `DeclineTrade` event name alone fails to distinguish the initiator**. Time differences are incidental, not actor evidence. The comparison provides no authenticated decline or success conclusion.

This particular two-scenario experiment is **finished**. No need to rerun either decline test unless a later regression changes its result. Continue with a distinct evidence boundary if moving to a later stage. Do not enable automatic final Accept or completed-trade/profit webhooks.

## Crucial limitation

A comparison of two manually labeled trials cannot *authenticate* an action's source. Even if the partner test shows a different named event, it would be premature to create a classifier; additional controlled scenarios and transaction-correlated server evidence would be needed. A positive `CompleteTrade` receipt still cannot be promoted to completed-trade authority.

**Stage31 checkpoint:** Native comparison received for both requested test conditions; keep them as client observations and preserve the no-actor, no-completion authority boundary.
