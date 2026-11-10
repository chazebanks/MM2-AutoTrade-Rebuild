# Stage93 — Original Stage9 Part4 observer connected after native Stage92 request→exact trade

## Evidence and scope

User's native Stage92 result (Nov 9, 2026): `CLIENT_EXACT_PARTNER_TRADE_GUI_OBSERVED`, `requestTapCount=1`, `clientPendingExactTargetObserved=true`, `exactPartnerTradeGuiObserved=true`, `wrongPartnerTradeGuiObserved=false`, `elapsedSeconds=13`, no scripted offers/Accepts/Declines/teleports. This **establishes the client-visible contact/request/partner UI path**; it does NOT prove server-attested transaction, price or authenticated raw item identity. Do not rerun Stages89–92 just for the old path.

**NEW DISTINCT problem:** The actual archived Stage9 `p4_native_observer.lua` and `p4_observer_contract.lua` need to consume a trade that originated from the newly verified Part3 request boundary. Their value/identity resolution is NOT trustworthy without fully verified checker IDs and pricing. Stage93 therefore passes `ownInventory=nil`, `opponentInventory=nil`, and `marketFresh=false`; it interprets only GUI-signature and visible-slot-count changes as unpriced client observations.

## Technical implementation

Draft PR163 stacked on PR162. `STAGE93_P4_OFFER_OBSERVER_BRIDGE.lua` extends the verified one-target Stage92 script: exactly one manually armed physical Trade request; alt voluntarily accepts **incoming request**; exact partner visible trade header and one GUI root; *then* binds **original SHA-pinned Stage9 native observer and contract** for a bounded 20-second read-only offer-change window. The alt manually adds one harmless low-value item to THEIR OFFER; Stage93 reports whether its normalized GUI signature/slot count changed, and whether OUR OFFER stayed unchanged. The script does not add/remove any item, press Accept or Decline, send a webhook, hop or retry a request. Wrong/missing/ambiguous partner/root, lost player, incomplete native snapshot or unexpected changes on our side become INCONCLUSIVE. It exports no names, raw IDs, source prices or inventory.

`CLIENT_P4_GUI_OFFER_MUTATION_OBSERVED` means an **on-screen GUI offer difference** only, not item identity, API/remote proof, profit or settlement. The underlying original Stage9 normalized `contextOK` is expected to be false because the market and numeric checker IDs remain unverified; do not override this or promote flags to true.

## Next test after CI

Run exact pinned loader on NEW original MM2 server in Delta main iPad with consenting alt `venossgaming90190`. No older scripts. Manually open alt player card after executing. Alt manually accepts the incoming request, then **manually adds one expendable item to THEIR offer** and keeps trade window open. Do not press final Accept, or change main account offer. One aggregate `[GINGERSCOPE STAGE93 SINGLE REQUEST]` result. Observe, no user-facing transaction/price authority. Stop on no evidence or any uncertainty. Keep PR as DRAFT/unmerged until native result.
