# Stage47 — Offline one-sided and overlapping-type post-trade reconciliation

## Trigger and verified native evidence
- Stage46 **REAL** iPad Delta `StartTrade` client callback recorded exactly two arguments `TABLE,STRING`: bounded root layout `LastOffer/Locked/Player1/Player2`, partner username exact, P2 local, both empty and neither Accepted, stable GUI, one listener disconnected. [PR85 live result and scope](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/85). This is **not a fresh trade session token**.
- Stage32 operator reported a real successful **one-sided Iceblaster transfer**, trusted sender offered Iceblaster, receiver had no offer, receiver kept Iceblaster. Stage32 client inventory gained +1 eligible with two post-close reads, but no named `CompleteTrade` or `EndTrade` callback; `tradeOutcome=UNKNOWN`. Stage33 separately observed StartTrade/UpdateTrade/two AcceptTrade receipts, GUI close and an informational Claim prompt, but zero named completion receipts; it did not observe a complete same-session item transfer.
- Official [Roblox RemoteEvent guidance](https://create.roblox.com/docs/scripting/events/remote) documents queued callbacks and *copied* transport tables. Matching two table objects by reference or event name is not proof of a transaction.

## Actual audited source defect
Previous offline `pdiddler/intelligence_lab/stage20_outcome_audit.py` explicitly rejected:
```python
if (not offer.trade_open or not offer.resolved or not ours or not theirs
    or set(ours) & set(theirs)):
    return _result('INCOMPLETE', 'offer-unresolved-or-empty', expected, observed)
```
This rejects all one-sided trades despite the known Iceblaster UX. It also rejects trades containing the same weapon **type** on both sides even when physical copy quantities differ and their net delta is measurable. Both are unsupported assumptions. This is an OFFLINE auditor bug, not a claim that the trading UI or server incorrectly handled a trade.

## Narrow Stage47 repair
Use the already-calculated `expected` **net eligible-copy delta**. Reject only a truly both-empty offer, unresolved offer GUI, and net-zero changes (e.g. identical copies 1-for-1), since unchanged inventory cannot independently distinguish a completed exchange from a cancellation. Permit one-sided sender or receiver offers, and same-type overlapping offers with **nonzero net delta**. Retain all independent safety gates unmodified: exact account/job/session/partner scope, two observed Accept flags, success UI claim, chronological ordered 3 scans, complete eligible source, independent two matching post-close reads and exact delta equality. These flags remain **FALSE** for all outcomes: `server_completion_proven`, `may_record_completed_trade`, `may_report_profit`, `authorizes_trade`, `authorizes_accept`.

Synthetic Python tests cover incoming one-sided gift, outgoing one-sided item loss, same-type overlapping net +/-1, zero-net and both-empty cases, hidden unrelated changes, missing acceptance, mere GUI close, conflicting scans and missing native coverage. Another 500 seeded scenarios across quantities 0..4 exercise the complete **real Python auditor** with full false-authority assertions.

## Boundaries and next action
No source to establish an authenticated MM2 completion session token was found in the recent native evidence or official Roblox API. A client-only `CLIENT_CORROBORATED` outcome is **not** `serverCompletionProven` or a completed-trade webhook. **No new iPad test is needed for this Stage47 source-level correction.** The Stage46 native question is finished. The next DISTINCT evidence gap remains exact per-item offer-to-inventory reconciliation in an independently controlled client window; old scanner only tracks eligible tiers and unconfirmed exact identity, so new completion/profit authority stays blocked. No trade rules, Gingerscope valuation, market prices, bot avoidance, mobile GUI, auto final Accept, or webhooks are changed.
