# Stage67 — native Stage66 private raw-key matching and replay quarantine

## Actual evidence; don't invent two trades

The user pasted the **same Stage66 report twice**, both containing exactly the same fields, values, callback timings and inventory delta: `AcceptTrade(false)` +12.0s; `AcceptTrade(true, TABLE_1)` +14.2s, at GUI closure; received item row element types `string, number, string`, private raw callback string key equals the **only +1 raw Weapons.Owned key**, two postclose inventory readbacks, stable local GUI/partner label and clean listener disconnect. The Stage66 output has no source **observation nonce**, authenticated session/transaction ID or counterparty confirmation for that particular run. Consequently these two identical pasted blobs are **one user-submitted observation** and are **not evidence of two independent trades**. This is a manual interpretation of the chat's context, not a general method that can distinguish two legitimate but coincidentally identical sessions.

The report's `status=CLIENT_RAW_RECEIPT_EQUALS_OWN_GAIN_UNATTRIBUTED`, not `COMPLETE`. Its all-false server, exact identity, profit, strategy learner, auto Accept, completed/rejected notification flags remain trustworthy *only as client statements*; never use caller-provided flags to self-upgrade provenance. Human confirmation of a prior Stage63 Claim Weapon completion applies to the **earlier Stage63 test**, not automatically to Stage66.

**Discord learner intention:** Eventually improve market strategy using properly sourced completed and rejected actual trades. Historical imported webhook claims remain unverified and `venossgaming90190` is the user's test ALT, excluded from market learning. These duplicate Stage66 test reports are not eligible completed/declined examples or demand/rejection labels. Stage31 previously showed `DeclineTrade` does not independently identify which actor declined. Do not train on an ambiguous cancel, expired pricing or artificial test-alts.

## Stage67 implementation

`scripts/stage67_native_private_raw_client_evidence.py` is an OFFLINE-only strict validator of **one Stage66 report**, with an allowlist of every field in the genuine native JSON. It demands the correct schema, the exact false→true callback order within five seconds, permitted close-phase, one row of type `string,number,string`, private raw-key equality positive, full baseline, two postclose own readbacks and exactly +1 eligible copy; no discarded/unbound callback, stable local trade GUI, clean listener disconnect, and every source server/trade/profit/learner authority flag FALSE. It rejects extra fields, player names, item raw keys, schema substitutions, cross-session imported Stage59/61/63 records, malformed timing/counters or injected caller-declared server verification.

Positive classification: `CLIENT_PRIVATE_RAW_KEY_EQUALITY_UNATTRIBUTED` (client local observed pattern only). **Every output**, including a positive one, has:
- `recordDeduplicationPossible=false`, `sourceRunNonceObserved=false`, `distinctTradeObserved=false`, `independentCounterpartyWitnessObserved=false`, `operatorConfirmedThisRun=false`.
- All `serverCompletionProven`, `serverTransactionIdAuthenticated`, `exactWeaponIdentityConfirmed`, `mayRecordCompletedTrade`, `mayRecordRejectedTrade`, `mayReportProfit`, `mayUseForStrategyLearning`, `discordMarketLearningEligible`, `authorizesAccept` and `authorizesTrade` FALSE; `tradeOutcome=UNKNOWN`.
- No raw input fields, inventory keys, timestamps, player names or payloads forwarded.

No automatic completed trade counter increments, no Discord post, no economy calculation, no policy update and no runtime integration. It can't prove how many distinct observations occurred when two blobs have matching contents; by design it refuses to count either as another transaction.

**Tests:** Actual user-provided Stage66 JSON shape recreated with anonymized fields, 1200 seeded corruptions (events, timing, quantities, stale readbacks, injected private data, false auth, value relabeling), a repeated-paste rejection of multi-record input and preservation of no-authority output. GitHub Actions runs the focused validator and all inherited intelligence tests. This validates the code contract, not live Roblox behavior.

## Adjacent Stage66 future privacy fix

Draft [PR118](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/118) now wipes raw `Weapons.Owned` snapshots retained under `getgenv()` and the one private callback item row from memory after every terminal or failed observation. Exact-head [CI run 42558230170](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42558230170) passed 8 focused real Lua tests and 99 inherited Python tests. **These edits affect future draft runs only**, not the user's immutable pinned Stage66 native observation, and no evidence suggests raw keys were externally leaked.

## Next engineering question, without manual test for now

For safely counting actual completed/rejected trades, create a **unique client-produced run/observation ID** at collector startup and enforce durable idempotent local/Discord ingestion, while retaining the crucial separation between CLIENT report ID and authenticated game SERVER settlement ID. A run nonce distinguishes repeated copies of *one* report but **does not** establish that the game server completed a trade. Additionally a future negative-event probe must identify `OPPONENT_DECLINE` vs `OUR_DECLINE` vs `TIMEOUT` with actor/session attribution; raw `DeclineTrade` event name is insufficient. The Discord learner must keep market-training eligibility gated independently of client idempotence and test ALT exclusion.

No new user action is required to recognize the Stage66 callback/raw-key pattern or to run the offline Stage67 validator.
