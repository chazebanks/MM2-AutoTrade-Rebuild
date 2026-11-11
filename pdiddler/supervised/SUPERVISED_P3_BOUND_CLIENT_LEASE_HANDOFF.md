# Gingerscope — supervised P3 to P4 read-only candidate interface

## Confirmed native evidence (original MM2 iPad/Delta, November 10, 2026)

Operator supplied actual merged PR214 client-only STOP/COPY JSON:

```json
{"p3ArmObservedClient":true,"serverCompletionProven":false,"mayReportProfit":false,"clientTradeWindowObserved":true,"reason":"OPERATOR_STOPPED","tradeOutcome":"UNKNOWN","authorizesAccept":false,"authorizesOffer":false,"clientResumeObserved":true,"status":"STOPPED","lastObservedStatus":"P3_ROTATING","schema":"gingerscope-p3-native-rotation-status-v1","maySendDiscordWebhook":false}
```

This **closes the client-side P3 ARM -> original P4 GUI observed -> closed-trade resume** milestone, as reported in the merged [PR214](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/214#issuecomment-6783554150). Do not repeat the same manual P3 test just to reconfirm it. It does **not** authenticate a server-delivered request or trading settlement, item ownership, true identity by server nonce, profit, or pricing; `tradeOutcome=UNKNOWN` is correct.

## One new issue isolated in this branch

Before this change, the original `supervised_real_p3_rotation_handoff.lua` captured the bound original Part4 trade session in a private `active`, while the separately tested `supervised_four_slot_operator_plan.lua` accepts an object with a `capture()` interface. The only demonstrated end-to-end manual multi-slot runner uses a **synthetic manual-contact adapter**, explicitly not the new real P3 contact.

New `controller.currentBoundReadOnly()` returns **only** a per-session `capture()` facade if the existing original coordinator proves a fresh, unique, exact-player, unchanged job/P3 epoch, currently safe client P4 GUI snapshot. The facade on every read reruns the original coordinator and protected IO, and permanently revokes itself if its original session changes, trade closes, P3 stops, any acceptance indicator becomes set, the partner changes, or a read is unsafe. No `offerItem`, `resume`, `accept`, `decline` or raw ability to mutate the game is exposed by the facade. It returns the protected client's existing private snapshot contract; **never export raw GUI contents, names or weapon keys**.

The associated actual-Lune integration mocks run the *real coordinator, original guarded P4 IO and bridge*, not a fake plan's decision engine. They verify the safe lease, denial before real contact, fresh offer-side reads, wrong GUI partner, accepted GUI, lifecycle stop, epoch drift, GUI close, old lease after new partner session and zero outgoing OfferItem calls. Both existing P3 integration and four-slot controller tests remain in the existing workflow.

## Release boundary

- **This is a DRAFT, read-only interface patch**. It does NOT modify the currently SHA-pinned PR214 native runner, connect the four-slot controller to automatic execution, supply owner inventory, source values or human consent for item offers, or authorize final Accept/Discord/profit/settlement.
- The original native P3 runner still loads the unchanged immutable coordinator at PR207, and all proven ALT-only guards remain unchanged. **Do not repoint the loader to this draft before exact-head offline CI and a separate reviewed native-integration design.**
- Later, separately implement a *single consenting-ALT-only* in-game operator-arm control to pass an exact human-chosen, actually owned, **non-Gingerscope** 1–4-item manual plan through this lease and the already protected `supervised_four_slot_operator_plan.run`. It must require a visible nonoverlapping step guide, verify all properties before each OfferItem, avoid repeated remote sends, and not press final Accept. No inherited fixed +15, highest-value opener, market claims or automatic hopping.
- Future market strategy must independently prove exact identity, fresh source, practical liquidity and attractive seller-side package; do not mistake the client lease for quote or trading authority.

## Review criteria

1. All existing CI at the **exact branch SHA** must complete successfully, especially the original Lune P3→P4 session fixture, full default-closed original P3 queue, watchdog, current P3 native runner and guarded 4-slot controller.
2. Verify no changes to original pinned scanner, native runner, Part4 guarded OfferItem source, Gingerscope protection, or global pricing.
3. Treat this branch as an interface-only review, **not a new iPad test requirement yet**. A future integration that adds an actual human-approved offer will require fresh separate exact-head CI and user consent.
