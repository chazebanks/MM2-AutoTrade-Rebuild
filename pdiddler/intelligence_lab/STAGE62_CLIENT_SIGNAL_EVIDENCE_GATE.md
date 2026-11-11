# Stage62 — strict client-event evidence gate, NOT a completed-trade learner

## One issue
A real Stage61 MAIN/iPad report captured exactly two inbound `AcceptTrade` client callbacks in one observed trade GUI:
- `+21.1s` first arg `BOOLEAN_FALSE`, `argCount=1`, no second argument.
- `+21.4s` first arg `BOOLEAN_TRUE`, `argCount=2`, second `TABLE` of bounded length **1**.
- Observed unique stable GUI then closure; zero unbound and zero discarded receipts; listener disconnect count 1.
- `historicalClientFlagHypothesisCompatible=true`, but `eventSessionAssociationProven=false`, `serverCompletionProven=false`, `tradeOutcome=UNKNOWN`.

Original full anonymized user report was supplied in ChatGPT on Nov 8, 2026; evidence is in [draft PR113 user-report comment](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/113#issuecomment-6730366663). Treat it as current-client evidence for the **argument-shape** hypothesis, not proof that the operator completed or received an item on this precise Stage61 run. No source fields identify item, partner or server job.

## Independent source hierarchy

1. **Real 2026 user Stage61 client callback observation** confirms the false→true, then GUI closure *shape*.
2. **Historical reverse-engineered 2026-or-earlier? v1456 MM2 TradeModule client**, [source](https://github.com/tlredz/decompiledGames/blob/0552a0f3502217a1cf89df66be9bd0f153e47fa4/murder-mystery-2/v1456/ReplicatedStorage/Modules/TradeModule.lua), handles `AcceptTrade.OnClientEvent(flag, items)`: `flag` truthy clears trade GUI and optional received-item popup; falsy shows the partner Accepted UI. This is NOT first-party MM2 server documentation and cannot authenticate settlement.
3. **Stage59 previous different trade**: independent ALT lost 1 and MAIN gained 1 eligible copy with operator confirmation, [PR104](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/104#issuecomment-6729086953). Crucially **this was NOT Stage61's trade**; its inventory delta cannot be merged with Stage61's callback. Both are useful separately, NOT one joined server-attested event.
4. Official Roblox [RemoteEvent docs](https://create.roblox.com/docs/scripting/events/remote) confirm server-to-client transport and argument delivery; do NOT define MM2 final trade semantics or a server transaction identifier. A RemoteFunction named `GetTradeStatus` was found by Stage60, but archived client scripts use it as a **current live trade/request UI state**; not confirmed settlement history.

## New safety gate

`scripts/stage62_client_accept_evidence.py` is a deliberately independent, offline **one-report-only classifier**. It:
- Accepts strictly the original Stage61 schema and allowlisted, type-correct fields with the non-authority flags all false; rejects missing/extra keys (including externally supplied Stage59 receipts, usernames, secret payloads, or alleged verification flags), malformed enums and counter/flag contradictions.
- Requires a stable GUI, closure, exactly one connected listener disconnected, no truncated/discarded or unbound callbacks and exactly TWO ordered scoped callbacks in that GUI: one `BOOLEAN_FALSE` with one argument and no second, then one `BOOLEAN_TRUE` with a two-argument bounded TABLE sequence length 1–16, within five seconds.
- Enforces monotonic finite timestamps and exact self-reported counters/historical compatibility; preserves raw item-name/privacy by never emitting original user input, table contents or message metadata.
- Returns only `CLIENT_FALSE_TRUE_CALLBACK_WITH_TABLE_UNATTRIBUTED` when it passes (otherwise `INCONCLUSIVE`). Despite the output's `clientSuccessLikeSignalObserved=true`, all server settlement, item identity, trade causality, session binding, opponent rejection, realized profit, offer acceptance authority, Discord learning eligibility, and automated final Accept **ALWAYS FALSE**; `tradeOutcome=UNKNOWN`.
- Does **not** join with Stage59 data even if client event times or user-provided labels seem compatible; these events occurred in different tests. Merely passing a `stage59` key makes the report fail the allowlist. Caller-provided `verified` or `serverCompletionProven=true` is always rejected.

### No retrospective proofs or learner self-training
A customer who is happy and a client GUI that closes may be evidence of a successful *manual* experience, but neither a client event name nor received table shape provides a strong, uniquely transaction-linked record for automated economics. No completed-trade Discord webhook, rejection labeling, automatic learning, realized profit or auto Accept can be authorized from the Stage61 data alone. The learner can eventually archive lower-confidence hypotheses **separately** while only verified tagged outcomes train policy, and must preserve `OPPONENT_DECLINE` vs `OUR_DECLINE` vs `TIMEOUT` distinctions. Stage31 showed the same `DeclineTrade` client event on both decline directions, with no actor proof.

## Tests and next scope

`pdiddler/intelligence_lab/test_stage62_client_accept_evidence.py` contains the privacy-safe synthetic recreation of the **actual native-shaped** Stage61 result and comprehensive regressions: truncated/missing evidence, swapped callback order, wrong GUI phase, removed listener, stale/out-of-order/NaN timing, malformed arguments, poisoned/fake Stage59 joins, faked authority fields and 1000 deterministic corruptions. The workflow `.github/workflows/mm2-stage62-client-evidence-gate.yml` runs both focused and inherited intelligence suites on PR head.

**NEXT:** No additional manual input needed to classify the already received Stage61 report. The next separate engineering objective is a *one-lifecycle* Stage61-like event plus Stage29/Stage59-like three-read inventory and exact offer-revision correlation in one trade, without combining old reports. A new live observation would be required **only after** a standalone read-only probe is implemented and its exact-head CI passes, ideally during a naturally voluntary, low-value manual exchange. No user test should be requested before that preparation or if it repeats older Stage59 evidence without a new cause-specific proof goal.
