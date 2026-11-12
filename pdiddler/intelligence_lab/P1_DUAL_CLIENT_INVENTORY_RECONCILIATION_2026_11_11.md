# P1 — Synthetic two-sided inventory readback reconciliation (Nov 11, 2026)

**Scope: OFFLINE RESEARCH, no MM2 device test, no live collector, no personal data.**

## Previous exact work inspected

- Merged Stage 115 [sanitized client temporal replay](../../scripts/replay_trade_events.py) already distinguishes post-close unchanged, changed, repeat and conflicting **single-client** readbacks. Its `gained/lost` fields are counts of observed item changes, not authenticated server transfers; it does not know weapon keys.
- Merged Stage 119 original P3/P4 iPad [native handoff](../supervised/STAGE119_P3_REPLACEMENT_HANDOFF.md) observed two client callbacks / GUI quantity transitions and a changed `LastOffer` on the iPad but explicitly could not prove authenticated session association, item instance, transaction causality or server settlement.
- Existing source-free [P1 identifiability feasibility](P1_INDEPENDENT_EVIDENCE_FEASIBILITY_2026_11_11.md) has 0 independently verified real settlement rows and must not infer true fair values from merely posted offers. This new step does **not** duplicate its equation-rank calculations.
- Existing private event-save under `pdiddler/continuity/manager.py` only permits narrow sanitized client counters and does **not** prove settlement or save inventories.

## Distinct new question

**Could TWO client inventory readbacks, each captured before the same supposed offer and after each client's local trade-window closure, numerically reconcile against the offered item quantities on BOTH sides?**

The new **synthetic-only** `p1_dual_client_inventory_reconciliation.py` checks exactly this narrow mathematical question. Inputs have strict anonymous `TEST_` keys, fictitious `TEST_SESSION_` tokens and a `HYPOTHETICAL_ONLY` mode. Live weapon keys, player identifiers, purported server receipts, partner names, Discord webhooks and private inventory data are refused. It has **no Roblox, Delta, network, source feed or device integration**.

- Requires exactly one client witness per side, identical synthetic session token and offer revision, *local* before / window-close / after ordering, and source `CLIENT_SNAPSHOT`.
- Uses immutable per-witness before/after **counts**, not observations summed across callbacks. Tests four physical offer slots independently from stacked quantity (which can exceed four copies).
- Checks pre-snapshot ownership for the offered quantities, exact net quantity change on each side, and zero unmatched inventory changes. A missing counterpart item, one-sided readback, stale revision, repeated same-side witness, implausible quantity or a second unrelated item movement fails closed.
- Does **not** compare absolute timestamps between devices (their clocks need not be synchronized). A common caller-supplied session token does not authenticate true Roblox session correspondence.
- Equal net same-item exchange is explicitly `INCONCLUSIVE_NO_NET_EFFECT`; a symmetric before/after snapshot could hide a trade, replay, delayed update or separate inventory transaction. Numeric conservation never proves causal attribution.
- Protected `TEST_GINGERSCOPE` cannot be offered outgoing even in mocks.

The strongest possible output `CLIENT_BILATERAL_DELTAS_MATCH_SYNTHETIC` means only **two synthetic client-count vectors match arithmetic predictions**. It does **NOT** establish that these were independent parties, an exact server-bound trade, unique weapon instances, no other inventory operations, fresh authoritative MM2 raw item IDs, server settlement, true price, acceptance probability or liquidity. Even a perfect match could be fabricated from the same source, timed around another action, or collected with unsynchronized client reads.

All outputs keep `tradeOutcome=UNKNOWN`, `realVerifiedCompletedTrades=0`, `serverCompletionProven=false`, `observedTransferAttributedToTrade=false`, `clientWitnessIndependenceProven=false`, `mayRecordCompletedTrade=false`, `authorizesAccept=false`, `authorizesTrade=false`, `mayUseForStrategyLearning=false`, `mayReportProfit=false`, `maySendDiscordWebhook=false`, `marketPrices=null`, `mayAdvanceP2=false`. No actual source gate is loosened.

## Deliverables and next meaningful constraint

- Code: `pdiddler/intelligence_lab/p1_dual_client_inventory_reconciliation.py`
- Tests: `pdiddler/ci/test_p1_dual_client_inventory_reconciliation.py`
- CI: only append offline synthetic tests to existing PR #236 P1 rights research workflow. No live market network call, Stage 119 rerun, production Lua, deployed offer/Accept or private output.
- Test cases cover matching bilateral quantities, mismatches, gifts, overlapping same-item swaps, four physical slots versus stacks, unrelated deltas, duplicate keys, stale sessions/revisions, missing side, protected Gingerscope, local clocks, injection, and unsupported live/settled evidence.

**NEXT REAL BLOCKER:** We still cannot authenticate two independent snapshots to the exact server-side MM2 transaction without a trustworthy source-issued receipt or other independently corroborated authoritative evidence. Don't create such a receipt by naming a client field `serverValidated`. Any future actual device capture or private evidence implementation must be separately reviewed and authorized. Existing 50 private webhook records remain 30 test exclusions +17 unverified +3 quarantined, **zero completed settlement training labels**.

**Provider confidentiality:** Do not contact outside value-list providers, send emails or disclose the codebase. No new data-source acquisition is required for this purely offline check.
