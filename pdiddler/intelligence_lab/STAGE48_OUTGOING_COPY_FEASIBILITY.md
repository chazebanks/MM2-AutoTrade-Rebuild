# Stage48 — Audit pretrade outgoing-copy feasibility before client reconciliation

## Actual defect exposed by Stage47 overlapping-type support
After Stage47 allowed legitimate trades where both sides exchange distinct physical copies of the same eligible item type, the offline Stage20 auditor checked only the **net** per-type inventory delta. For example, own pre-count A×1, our offer A×3, partner offer A×4, post-count A×2 yields mathematically matching +1 net — **but our offer A×3 was impossible from pre-owned A×1**. This is a *logic deficiency in the offline auditor*, not an observed MM2 transaction or live Delta failure.

## Narrow correction
In `pdiddler/intelligence_lab/stage20_outcome_audit.py`, after all existing client scope/time/Accept/closure and three independent inventory-readback checks (including matching two after reads), but before declaring equal net delta corroborated, require for each `(item,qty)` offered by **our account**:

```python
qty <= complete_before_snapshot.get(item, 0)
```

If false, return `INCONSISTENT: outgoing-copies-exceed-pretrade-ownership`. Never credit incoming copies as if they were available *before* sending our offer. Do not reject one-sided receiving when our offer is empty. Keep same-type exchanges valid when sufficient pre-owned copies exist and net change is nonzero; retain Stage47's both-empty and net-zero `INCOMPLETE` gates. There is no evidence of the *partner's* pretrade inventory in this offline auditor, so it does **not** prove they really owned what they offered.

This protects only **copy-count feasibility within the normalized eligible checker-ID representation**. It does not establish that the GUI's raw offer key corresponds to that checker ID, that same-type copies are distinct instance IDs, that a client snapshot is complete beyond eligible items, that the `StartTrade` event is session-authenticated, or that a trade completed.

## Verification protocol
Regressions exercise deliberately impossible but net-matching examples, missing pre-owned type, one-sided over-offer, correct full-stock transfer, empty receive-side offer, scope precedence, incomplete native input, disagreeing postscans, multi-type hidden overspend, net-zero refusal; **750 seeded client-only quantity scenarios** across 0–10 offered/received and 1–10 pre-owned, including 164 impossible-outgoing and 421 positive feasible cases with fixed RNG seed `481107`. The existing Python full suite, including actual Stage45/46 Lua subprocess tests, runs in targeted GitHub Actions; logs and exact head must be checked before accepting the fix.

**All outcome authority remains FALSE**: `server_completion_proven`, `may_record_completed_trade`, `may_report_profit`, `authorizes_trade`, `authorizes_accept`; status `CLIENT_CORROBORATED` means only client evidence consistency, never authenticated server settlement.

## What this does not change
No native Delta script, remote call, scanner, browser, economic strategy, item swap, bot avoidance, automatic Accept, Discord webhook, completed-trade ledger or transaction attribution. No new manual trade needed. Stage46 successfully established only a client StartTrade initial table and exact partner username; no reason to repeat it.

## Next outstanding separate question, after this repair
Find a **read-only and independently verifiable** mapping between the raw `UpdateTrade` offer weapon key and the full own-inventory checker-ID rows. Stage29 normalizes `page:checkerId:checker-id` from scanner data; Stage43/44 recognized a raw `Sync` weapon key but did **not** prove the raw string belongs to a unique item instance or to a specific settled session. Without an identity bridge, type-level copy reconciliation is still hypothesis-grade and cannot authorize any real trade action or completed-profit report. Never substitute a display name for a raw key.
