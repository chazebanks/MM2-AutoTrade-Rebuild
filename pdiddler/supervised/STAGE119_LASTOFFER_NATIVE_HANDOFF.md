# Project Gingerscope Stage119 — FIRST ORIGINAL MM2 read-only two-UpdateTrade LastOffer native diagnostic

## Proven prior steps, not repeated

- Original PR221 MAIN iPad/Delta Stage101 client ONLY 1/1 own+ALT game-key candidates and GUI cross-check PASSED ([real STOP/COPY](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/221#issuecomment-6788471060)); not an authenticated trade.
- PR222 merged historical MM2 v1456 LastOffer field/client Accept argument source audit; does not prove 2026 live field semantics or server validation.
- PR224 merged two-event **offline** LastOffer + original Stage9 quantity GUI correlation with 6/6 CI. No real iPad test. Do not redo any of those.
- Previous P3 native PR221 and PR218 one-item offer code remain byte-identical; this new test uses NO P3 automatic request/offer/accept/decline/hop.

## One new hardware question

Does CURRENT original MM2 on the MAIN iPad deliver two `UpdateTrade` callbacks whose opaque `LastOffer` equality can be compared while the consenting ALT `venossgaming90190` manually ADDs and then REMOVEs one inexpensive eligible weapon? **MAIN's offer must remain empty throughout.** This is DISTINCT from Stage101 two-sided weapon identification and doesn't repeat an auto offer.

The read-only native runner `pdiddler/supervised/STAGE119_LASTOFFER_NATIVE.lua` delegates to pure dependency-injected `pdiddler/supervised/stage119_lastoffer_native_controller.lua`. It loads **SHA-pinned** real original Stage9 contract, native GUI observer, Stage100 geometry, PR222 LastOffer audit, and PR224 Stage118 two-event bridge, and binds the one exact live ALT Player, one trade root, job, private local session. No clipboard or console data may contain LastOffer token value, raw weapon ID, ALT username, user IDs, market prices or game state. The displayed result contains only counters, sanitized equality category, client-only scope and constant authority=false flags.

### Human on-screen test (ONLY AFTER exact PR-head CI and merge)

1. **MAIN** runs one SHA-pinned diagnostic alone in a fresh original MM2 server with ALT already joined. MAIN manually opens an EMPTY trade with ALT. Purple current-step panel stays completely outside TradeGUI and OS safe areas.
2. **ALT** manually adds one cheap eligible weapon after the panel shows step 2. **MAIN offers nothing.** Leave it stable through GUI capture.
3. **ALT** manually removes the same weapon only when step 3 appears. MAIN still offers nothing. Neither side presses final Accept.
4. After client result is displayed, MAIN **manually Declines**, presses **STOP / COPY** and pastes sanitized report. No script Decline, Accept, OfferItem, request or teleport.

Expected successful `status=STOPPED`, `reason=OPERATOR_STOPPED_AFTER_CLIENT_PASS`, `nativeStage118Status=CLIENT_TWO_EVENT_LASTOFFER_GUI_UNATTRIBUTED`, two callbacks, two GUI quantity transitions, `clientGuiQuantityCrossChecked=true`, and a `lastOfferEqualityClass` of either TOKEN_CHANGED+OFFER_CHANGED or TOKEN_SAME+OFFER_CHANGED (PR222 category literal). `clientGuiCrossChecked=false` means full identity NOT independently proven in Stage119. Callback could run after native UI update; in that case fail closed `GUI_CHANGED_BEFORE_CURRENT_CALLBACK`, don't re-run a closed prior Stage101.

### Strict limits and fail-closed guards

- No actual gameplay remotes sent; only subscribes `UpdateTrade.OnClientEvent` after an empty Stage9 GUI is stable. Never logs server-authenticated proof, "completed trade", profit, current prices, or Discord.
- Exact original MM2 PlaceId 142823291, one fresh JobId/one run, unique exact target in same server, exact partner GUI label and player reference, original Stage9 native capture, unlocked/unaccepted sides, two callbacks only, monotone local clock.
- Original Stage100 non-overlap `choose(viewport,trade,{w=304,h=148})` rechecked on every tick, including viewport changes. On missing camera, full-screen/zero-size trade, moving overlay collision or no safe region, terminate INCONCLUSIVE and hide panel.
- If a mismatch, cancel, duplicate event, accepted indicator, session change, plugin API missing, UI creation failure or timeout occurs, disconnect and report INCONCLUSIVE without retry in same JobId.
- **ALL reports** retain `eventSessionAssociationProven=false`, `callbackCausalityProven=false`, `serverTradeRevisionProven=false`, `serverCompletionProven=false`, `rawItemIdConfirmed=false`, `authorizesAccept=false`, `mayReportProfit=false`, `maySendDiscordWebhook=false`, `tradeOutcome=UNKNOWN`.
- On-screen prompt is numbered, compact and noninteractive during the observation; STOP/COPY only appears after a client-positive result. Manual Decline is a user action and the scripted decline counter always stays zero.

### Release gate

CI `.github/workflows/gingerscope-stage119-native-lastoffer.yml` retrieves immutable original Stage9 parser `7c844... `, native observer `a6338...`, Stage100 geometry `e0eac...`; checks merged PR222 module `fba6...`, PR224 bridge `bfab...`, actual PR221 native runner `46cff...`; tests **ACTUAL** Stage119 runner/Stage9 native and safe mobile overlay in pinned Lune with positive, malformed, duplicate/late event, GUI movement/no space/missing camera, wrong target, accepted states, and 5 viewport geometries. Python verifies exact historical bytes and no script gameplay calls. Do not claim ready until all exact HEAD workflows pass, and do not provide a URL loader until merged and pinned immutable runner is verified.

This Stage119 native probe will not solve server authentication or settlement by itself, and LastOffer must not be used to authorize automatic Accept. After its one native observation, separately pursue market data/attractiveness, real demand and liquidity, compounding, four-slot upgrade/downgrade, and permanent Gingerscope outgoing protection. No old +15 or highest-valued forced opener.
