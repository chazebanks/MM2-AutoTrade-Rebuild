# Stage64 — exact Stage63 native report audit and completion-vs-learner boundary

## Native result — verified source fields, not a server transaction

MAIN iPad in original MM2 produced a real Stage63 read-only result on Nov 8, 2026:

- One stable visible GUI and partner label, same-bound-window local evidence, `coreTerminal=true`, no unbound/discarded receipts, listener disconnected.
- `AcceptTrade.OnClientEvent` callbacks in the SAME observed window: at **14.3s**, first argument `BOOLEAN_FALSE` with 1 argument and no second; at **15.9s**, `BOOLEAN_TRUE` with 2 arguments, second is a table of bounded length 1. Both `WITHIN_BOUND_GUI_CLIENT_ONLY`, spaced **1.6s**.
- Stage59 pinned read-only core in this SAME run, one pre-trade own-inventory baseline, GUI close and TWO postclose own reads: `status=ELIGIBLE_DELTA_WITHOUT_RESULT_NAMED_RECEIPT`; `gainedEligibleCopies=1`, `lostEligibleCopies=0`, `changedEligibleTypes=1`, `rawWeaponInventoryChanged=true`, `partnerCacheAtBaseline=true`.
- Original Stage63 result: `status=CLIENT_ACCEPT_FLAG_PLUS_OWN_GAIN_SAME_WINDOW_UNATTRIBUTED`, `serverCompletionProven=false`, `eventSessionAssociationProven=false`, `causalTradeAttributionProven=false`, `exactWeaponIdentityConfirmed=false`, `mayUseForStrategyLearning=false`, `mayReportProfit=false`, `authorizesAccept=false`, `tradeOutcome=UNKNOWN`.
- Screenshot shows READY-stage purple Stage63 instructions beneath the legacy T4.4 eligibility scanner, with **outgoing paused because Supreme price data are expired/unavailable** and its total values **UNVERIFIED**. Do NOT interpret this pretest screenshot as a post-completion screenshot or bypass the market-data expiry gate.

Full real evidence preserved without player/weapon IDs in [PR115 native result](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/115#issuecomment-6730976215). This differs from Stage59's reciprocal ALT/MAIN client inventory reports and Stage61's argument-only report: **these were all distinct manual exchanges**. The Stage63 success-like outcome is correlated with Stage63 inventory delta without inventing a cross-trade join.

## Independent engineering audit of Stage63 draft

An audit after native evidence identified a hypothetical positive-label escalation bug **for FUTURE runs**: the original Stage63 `finish(status, reason)` could label a record positive if callbacks and a core result looked plausible *even when* it was called for an error status rather than normal core completion. The native report itself had no evidence of such an error. Patch in **same draft PR115** now demands `status=CLIENT_OBSERVER_FINISHED` with `reason=ONE_BOUND_WINDOW_FINISHED` and the exact safe terminal Stage32 status, `readOnly=true`, `tradeOutcome=UNKNOWN`, all core completion/Accept authority false. Corresponding fake-core source tests add impossible/malformed core statuses and injected authority flags. **No production or server game code touched**; user-used previous SHA remains pinned and unchanged. Exact patch CI result to be recorded.

## Stage64 strict offline classification

`scripts/stage64_same_window_client_evidence.py` checks the **original user-supplied Stage63 report schema**, all fields and types, no hidden user/weapon raw IDs, exact expected two callbacks, timing, stage boundary, terminated listener, core baseline + two consistent post-close reads and one gained eligible copy. Rejects any extra field or nested Stage59/Stage61 reports, out-of-order events, copied/pasted duplicates, wrong quantity/timing, no stable partner cache, false type booleans, forged server/learning/Accept flags or untrusted payload. Output never includes raw input text.

Only positive classification: **`CLIENT_SAME_WINDOW_ACCEPT_PLUS_OWN_GAIN_UNATTRIBUTED`**. It is a *purely observational, bounded local client correlation*. The evaluator can never emit an authenticated completion, realized profit, exact item identity, opposing actor decline, Discord automated policy-learning entry, or final Accept permission. Missing record or maliciously altered flags → `INCONCLUSIVE`. `clientTemporalCorrelationObserved=true` means the validated report fields satisfy this contract, not a second independent trustworthy report.

The offline tests use the EXACT privacy-safe native Stage63 fields from user, 1000 deterministic adversarial mutations (malformed/nan timestamp, duplicate/unbound event, wrong order, changed copy count, weird table shape, spoofed authority, extra payloads), plus all existing mainline intelligence tests. They do not contact Roblox or Discord.

## Practical next evidence/learner plan

Do not demand indefinite impossible cryptographically signed MM2 settlements. The project should distinguish:

1. **Authenticated settlement** — would require actual game/server-sourced transaction identity or independent strong readback; not established.
2. **HIGH-CONFIDENCE CLIENT-OBSERVED SUCCESS-LIKE** — a local `AcceptTrade(true, optional items)` correlated with pre/post own inventory and the same bound GUI, like Stage63. Can be archived as **provisional evidence with provenance**; insufficient for automatic final Accept or claiming a server-confirmed trade.
3. **OPPONENT DECLINE** — cannot be inferred just from `DeclineTrade` name (Stage31 reported both decline directions); require independently attributed actor/explicit GUI lifecycle. Own decline and timeout separate.
4. **Unknown, ambiguous, test-account or stale-price observations** — quarantine from learning.

**Only after** individual identity/offer revision attribution and idempotent per-transaction local logging are engineered, propose a *reviewed* offline learner using appropriately labeled high-confidence and negative outcomes. This is a **future policy proposal**, not an enabled model or permission to silently train on client claims. Market values must have current independent provenance; stale Supreme data remain untrusted. Avoid reintroducing the former +15 or forced-opener strategy rules.

**One next engineering problem after Stage64 CI:** determine whether an anonymized local equality check can correlate the `AcceptTrade(true, items)` row to the ONE changed eligible weapon key in the same window *without exporting private account/item data*; independently audit current observable payload types, historical `ItemPopupService` call shape and Stage58 key provenance first. No new manual test or weapon transfer until there is a concrete, tested probe for this distinct identity question.
