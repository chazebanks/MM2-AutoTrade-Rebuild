# Supervised trading — first real execution blocker: outgoing Gingerscope protection

**Status:** Separate safe fork, NOT wired into live loader. Original known-good modules unchanged. No iPad execution yet.

## Confirmed unsafe legacy path

Read original `pdiddler/pdiddler_PART4_BALANCER_TEST_v1.lua` on main and the exact immutable modules it loads. The old launcher loads a scanner whose embedded value snapshot is labeled **October 31, 2026** and Part4 market demand/stability `pdiddler4_market_v1.lua` sourced **November 2, 2026**. It then runs the Part3 outgoing queue and Part4 controller. Pinned controller `pdiddler4_controller_v1_3.lua` automatically opens by choosing the highest nominal-value item from own inventory. Its `highestOwn` function does NOT exclude the raw key `Gingerscope`. On an actual open trade it executes `io.offerItem(highest)`; rebalance plans also invoke `io.offerItem(it)`.

The **actual original trade IO** `pdiddler/pdiddler4_tradeio_v1.lua`, Git blob `0c12285438ee66166aa89086c891f697a33338fc`, directly calls `OfferItem:FireServer(item.id,"Weapons")` without any protected-asset check, versioned fresh market gate or operator-specific authorization. No final Accept is present in that old module, but OFFERING a protected asset is itself an unacceptable failure. **DO NOT launch the frozen old Part4 balancer to test supervised trading.** Its old +15 threshold is also superseded by the newer Gingerscope strategy; no old mandatory +15 policy should return.

## The first repair, at the physical mutation boundary

[PR195](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/195) adds `pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua` as a copy of the ORIGINAL I/O (not a replacement of the known-good file). It keeps the original `A.offerItem` API for later controller integration but changes the dispatch boundary:

- If `item.id`, `item.rawKey`, `item.key`, `item.itemId`, `item.name` or `item.identity` identifies Gingerscope (including normalizations), reject `PROTECTED_GINGERSCOPE_OUTGOING` **before** calling the Roblox `OfferItem` remote. This deliberately favors false rejection over giving away a possibly protected item.
- Reject malformed raw game IDs/metadata. Require the original live `TradeGUI` root to exist and be visible.
- Require `supervisedGate.checkOutbound(item, tradeInstance)` to exist and return strict Boolean `true`; WITHOUT this gate (including if the old controller uses only `new(scanner)`) the OfferItem mutation is **DEFAULT LOCKED**. This callback is only a local safety hook, NOT authentication of server, market price or owner inventory. A future supervised controller must validate operator intent, exact target, latest market source, current offer revision and outbound identity within the hook before any approval.
- Re-check raw key and protected-asset metadata after the hook returns; if the policy mutates an originally innocuous item into Gingerscope or any different key, reject. Re-check original visible trade root after the hook before sending an item.
- The original `OfferItem:FireServer(rawId,"Weapons")` occurs only AFTER all guards, and never supports final `AcceptTrade` or user item export. Explicit no-approval and error statuses are local diagnostics.
- This is NOT executable proof of a fresh Supreme market, full trade flow, offer rebalancing, safe auto-final Accept or settled profit. It is only one necessary safety barrier at the actual physical mutation function.

## Verification

`pdiddler/ci/supervised_offer_remote_gate_tests.luau` executes the **actual supervised I/O fork** under mocked Roblox `OfferItem`, `TradeGUI` and PlayerGui via official Lune. Cases cover raw protected Gingerscope, misleading alternate visible name, alternate rawKey, Chroma, malicious `identity`, invalid item fields, absent approval gate, callback failures/false/string/numeric approvals, invisible trade, post-approval closed trade, and malicious gate mutation swapping the raw key to a different weapon or revealing Gingerscope. Also checks exactly one permitted ordinary offer fires exactly one `OfferItem` to category Weapons. The original known-good source is Git-blob asserted byte-identical by CI.

Workflow `.github/workflows/gingerscope-supervised-offer-remote-gate.yml` is read-only and cannot send actual Roblox remote actions or trade items. **Record only actually observed GitHub CI results** in the review; if workflows are missing, keep the PR unmerged and verification INCONCLUSIVE. Test-first here means tests were committed BEFORE the fork, not that an actual red Action was observed.

## Follow-on order (do not implement all at once)

1. Complete this actual offer-mutation protection and CI.
2. In a separate change, copy the pinned controller into a **supervised** controller, make highest-item opener and rebalance skip protected Gingerscope, implement the required fresh price/offer/partner authorization hook. The current old price source MUST block offer execution, not silently supply profitability.
3. Establish ONE consenting partner request with a deterministic verified card, open a trade and evaluate offers. Only then allow a controlled, user-supervised nonprotected offer. **Final Accept is performed manually by the user**; no unattended final Accept, completed-trade webhook or realized-profit report.
4. Keep acquiring and protecting Gingerscope as long-term strategy; avoid revisiting complete Stage106 client-only proof or decorative diagnostics.

No new iPad test needed until the supervised controller is actually integrated, rather than running a standalone protected mutation library.
