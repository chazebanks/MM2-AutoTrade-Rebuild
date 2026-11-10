# Stage92 — client-visible exact trade partner after one manually accepted request

## Prior native evidence

On November 9, 2026, the user ran Stage91 on original MM2 Delta main iPad targeting consenting alt `venossgaming90190`. Report: `CLIENT_PENDING_OBSERVED`, `ALTERNATIVE_EMBEDDED_CARD`, one physical Trade tap, exact local pending username, no TradeGUI opened during eight-second inspection. No offers, Accepts, Declines, hops; all market prices and server settlement assertions remain FALSE. Stage89 card failure resolved, Stage90 alternate-card layout observed on actual iPad.

## Distinct next question

Does a single manually armed outgoing request to the alt, followed by the **alt operator manually pressing Accept on the incoming request**, produce an original MM2 `TradeGUI(_Phone).Container.Trade.TheirOffer.Username` matching the same current target Roblox Player? **This is client-only trade-window/partner evidence. It does not prove server attestation, item ownership, offer identities, settlement or profit.** No need to rerun Stages 88–91 merely to re-prove the request.

## Isolation

This draft copies Stage91 exact-card / own+opponent Stage87 contact eligibility / one physical tap logic, changing only the post-tap observer to at most 30 seconds. It checks exact current Player/UserId, normalized `TheirOffer.Username` (with optional surrounding parentheses and leading @), exactly one visible trade GUI root; rejects wrong partner, duplicate GUI, absent/hidden username, changed job or target object; collects client-only pending and exact-GUI boolean counts. It **never** calls offer mutation, Accept, Decline, hop, Discord, pricing, profit or repeat taps. The alt manually accepts the *request only*, not item-trade final acceptance. Code and tests synthetic except real client device experiment; do not equate CI with native behavior.

## Evidence discipline

- `CLIENT_EXACT_PARTNER_TRADE_GUI_OBSERVED`: one exact visible partner header on main account in one original MM2 trade GUI; **NOT** authenticated request delivery or completed settlement.
- `CLIENT_PENDING_ONLY_NO_TRADE`: exact pending appeared but no bound trade GUI within window; not failure of request sending; ask whether alt accepted.
- `INCONCLUSIVE`: wrong, ambiguous or unverified trade GUI. Do not continue input.
- `UNCERTAIN`: no confirmed pending or job changed. **No retry same job.**

No offer/Accept authority is added. PR159, PR160, PR161 and this draft remain unmerged. Test exact pinned SHA and all six CI workflows before asking user for one new native run.
