# Stage90 — Investigate actual Stage89 iPad player-card detection without clicking

**November 9, 2026. One-root-cause GUI question; no prices, inventory scans or physical requests.**

## Real Stage89 native result (already observed; do not repeat)

The user executed the original SHA-locked Stage89 single-request diagnostic in actual original MM2/Delta targeting their consenting test alt `venossgaming90190` and returned:
`[GINGERSCOPE STAGE89 SINGLE REQUEST]` with `status=INCONCLUSIVE`, `reason=EXACT_TARGET_CARD_NOT_OPENED`, `elapsedSeconds=21`, `exactTargetClientBound=true`, `ownContactEvidenceReady=true`, `visibleCardExactNameMatched=false`, `requestTapCount=0`, `clientPendingExactTargetObserved=false`, `tradeWindowObserved=false`; all offers/accepts/declines/teleports zero; all game-server, numeric checker ID, price, profit, Discord and learning authority FALSE.

**Interpretation:** Matching current player object and own local contact evidence PASS, but the Stage89 hard-coded `Leaderboard.Popup.Container.Username` + `Action.Trade` card wasn't proven. **ZERO request dispatched**. This is not evidence that the user forgot to open the card; the GUI shape assumption may be incorrect. Do not rerun Stage89 in that same server (one-shot registry/background scanner persists), do not enable retries or relax target binding.

## Independently established code-level hypothesis

Reviewed the actual original Stage51/PR90 `pdiddler3_outgoing_ROTATING_v18_REACHABLE.lua`, not an imagined GUI path. It handles:
1. Direct `Leaderboard.Popup.Container.Username` / `Container.Action.Trade`;
2. **Compatibility fallback** where the profile/card controls are elsewhere and the actual exact username label is a **sibling** above the Profile/Trade buttons, spatially distinct from the leaderboard row. Its `findOpenCardFor` can infer identity from a nearby matching name after checking a visibly paired Profile/Trade card.

Stage89 `exactCard()` has ONLY case (1) and reports a generic `EXACT_TARGET_CARD_NOT_OPENED` for all 20 seconds if case (2) occurs. We have NOT proven which native layout the user encountered; don't copy the fallback into a physical request sender until the native layout is observed and uniquely bound.

## New Stage90 — one-shot local-only GUI structural probe

- `pdiddler/intelligence_lab/stage90_card_layout_readonly.lua`: pure local DOM inspection of actual visible Game/Lobby Leaderboard structures, direct Popup/Username/Action/Trade, or visible candidate Profile/Trade controls with exact username **inside or nearby**, using old v18's geometry constraints. It never clicks or calls a game remote, checks original username rather than display name, and returns ONLY numeric counts and enum `DIRECT_POPUP_HEADER_MATCH`, `SIBLING_USERNAME_NEAR_PROFILE_TRADE`, `ALTERNATIVE_CARD_CONTAINS_EXACT_USERNAME`, `DIRECT_TRADE_VISIBLE_HEADER_MISMATCH`, `NO_VISIBLE_LEADERBOARD`, `NO_TARGET_CARD_CONFIRMED`.
- `pdiddler/new_part4/STAGE90_READONLY_CARD_LAYOUT.lua`: exactly ONE independently armed, original MM2 only, fresh job, no active Stage88/89/trader session. Resolves `venossgaming90190` as same-server Player by case-insensitive exact username, verifies unique instance and same UserId, then reads GUI structure for up to 8s. It loads only the immutable pure inspector at commit `14fefa245f0e3b72303f72b93101dd9b773e5e7d`, file Git blob `140c01c084d5a2e643f10ffd1573e98e5a2cc6cd`. It returns a bounded aggregate `[GINGERSCOPE STAGE90 CARD LAYOUT]` JSON report, optionally copies it. **No player names/IDs, inventory raw keys, coordinates, chat, prices, account data, GUI text, screenshots or contacts in the report.**
- The 8s diagnostic does **NOT** auto-open the card: user must **manually open the alt's original MM2 leaderboard Profile/Trade card before running the script**. It does **NOT** click Trade, send requests, open offers, accept/decline, hop or use Discord. Existing Stage89 code remains unchanged and unmerged.
- `pdiddler/tests/test_stage90_card_layout.lua`: original core plus actual native wrapper against mocked Lua5.4 GUI tree; direct popup, case/@-label normalization, sibling header, embedded card, wrong name, hidden popup, absent card, no username, wrong game, absent target, missing immutable source, job change, one-shot duplicate; no request APIs.
- `.github/workflows/gingerscope-stage90-card-layout.yml`: verify original core Git blob, run actual Lua syntax and behavior, static forbid physical trading or any remote calls; other standard project CI must remain green.

**Next:** Only after exact-code CI passes, one NEW fresh original-MM2/Delta lobby observation while the selected alt's player card is OPEN. Ask for one `[GINGERSCOPE STAGE90 CARD LAYOUT]` aggregate line, not repeat Stage89. If `SIBLING_USERNAME_NEAR_PROFILE_TRADE`, implement a narrowly approved and verified card locator for physical Stage89 one-tap UI *separately*, with strict same Player identity and no blind clicks. If `NO_TARGET_CARD_CONFIRMED`, request a cropped card screenshot/clarify exact UI state before edits. All source/price/trade/settlement/profit/Discord gates stay FALSE. No main production code modification.
