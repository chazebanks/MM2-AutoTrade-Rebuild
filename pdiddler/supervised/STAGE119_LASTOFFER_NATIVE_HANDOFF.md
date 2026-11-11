# Project Gingerscope Stage119 — FIRST ORIGINAL MM2 read-only two-UpdateTrade LastOffer native diagnostic

## NOV 11 — SAFETY CORRECTION / STAGE119 V1 DEVICE LOADER WITHDRAWN (REVIEW AFTER PR225 MERGE)

**USER REJECTED TEST STRUCTURE. DO NOT EXECUTE the previously supplied PR225 Stage119 loader** `bf4bb943.../STAGE119_LASTOFFER_NATIVE.lua`. Its 6/6 CI is real *for the narrow mocked script* but insufficient for the established original working test workflow. The new Stage119 runner bypasses the physical purple **ARM P3**, real original protected P3 ALT-only outgoing request, paused P3 and *revocable bound P4 session lease*. It instead asks MAIN to initiate a manual trade. It also lacks the PR221 broad owner-conflict gate and always-accessible **STOP / COPY** after failure (failure hides GUI), and it doesn't keep moving the panel once nominal PASS is reached. Compare with actual successful PR221 `SUPERVISED_P3_STAGE101_IDENTITY_NATIVE.lua`: one operator ARM P3 enables one explicit ALT-only request; stage watcher, supervisor `currentBoundReadOnly()`, P3 epoch, original P4 lease, original Stage9 GUI and fixed overlay all checked; STOP button visible throughout. PR225's Lune 11 scenarios do NOT run those P3 components, so they cannot prove equivalence.

**Latest proven physical iPad remains PR221 client candidate identity PASS, no new Stage119 hardware result.** Corrected Stage119 must restore protected original P3/P4 (without repeating Stage101's matched-weapon test) and test empty→ALT manual add→ALT manual remove events under the real lease with full native P3/Lune tests including stale lease and old missing-method sources. Keep no OfferItem/Accept/Decline/hop/Discord, failclosed and report token equality only. Do not publish a new loader before exact SHA source-bound integrated CI. PR225 cannot be withdrawn from an immutable historical SHA; keep this warning and never suggest that URL as the next step. Full-auto attractiveness/liquidity/portfolio growth/Gingerscope goal unchanged. See [review comment on PR225](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/225#issuecomment-6789682775).


## NOVEMBER 11 2026 — MERGED PR225: NEW FIRST ORIGINAL MM2 STAGE119 READ-ONLY NATIVE LASTOFFER 2-CALLBACK DIAGNOSTIC (NOT YET TESTED ON IPAD)

**Newest code milestone:** [PR225 merged](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/225) with history-preserving merge SHA `4241b0ea12ef3ddf51d0f97d282c9790a6a5b749`, reviewed exact PR head `bf4bb943a1d75059fe2c0567fc797b98b0f57d2f`. Original reviewed frozen native entrypoint `pdiddler/supervised/STAGE119_LASTOFFER_NATIVE.lua` Git blob `7cb6e0391599149e3271b51c80c21bb3559885f2`; actual native runner **imports frozen controller** commit `58f0bb357f467fb6764b077ec70c787fe1e059cf` / blob `bd9174a69d4c18c75a17ce0e84fb54a877242f12`. Workflow downloaded this precise controller and confirmed byte-for-byte identity with local tested source, preventing old PR220 lease pin mistakes. **SIX/SIX exact-head GitHub Actions SUCCESS** incl original-source real Lune native [run 42976486555](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42976486555), **11 actual original Stage9 GUI Lune scenarios, 62 assertions, 4 Python integrity tests**; inherited official Luau/Lune, quality, sanitized replay and Hypothesis all GREEN. Real previous PR221 native and PR218 one-item offer scripts byte-identical; six additions only: native runner, pure controller, Lune mock, Python audit, CI, handoff.

**NEW NATIVE GAME-READ-ONLY test now BUILT but NOT RUN on actual physical MAIN iPad.** It uses exact original MM2 PlaceId 142823291, MAIN iPad Delta, unique consenting ALT `venossgaming90190`, a fresh JobId and no other running pdiddler scripts, source-pinned original Stage9 physical GUI observer/contract, PR222 opaque LastOffer audit, PR224 2-event Stage9 quantity correlation and original Stage100 geometry with 12px collision margin + iPad safe areas. Fully noninteractive purple numbered current instructions, dynamically outside TradeGUI, UI failclosed if unsafe, user STOP/COPY after success. **NO scripted trade request, OfferItem, final Accept, Decline, teleport, pricing, Discord or result learning.**

**ONE-LINE FROZEN MAIN Delta launcher (reviewed exact PR head):**
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/bf4bb943a1d75059fe2c0567fc797b98b0f57d2f/pdiddler/supervised/STAGE119_LASTOFFER_NATIVE.lua"))().start()
```

**ONE NEW MANUAL HUMAN ACTION SEQUENCE:**
1. Fresh original MM2 server with trusted ALT already present. MAIN runs loader alone. Step 1: MAIN MANUALLY opens an EMPTY trade with ALT (neither offers anything).
2. When purple step 2/3 actually appears (the real original Stage9 empty GUI baseline plus UpdateTrade subscription are ready), ALT MANUALLY adds exactly one cheap eligible weapon. MAIN offers nothing. Hold unchanged until GUI first quantity transition is stable.
3. When step 3/3 appears, ALT MANUALLY removes that one weapon. MAIN remains empty. NO FINAL ACCEPT ON EITHER ACCOUNT. Keep window open until client result.
4. After `DONE - MAIN MANUAL DECLINE` is displayed, MAIN manually Declines then taps purple `STOP / COPY`. Paste ONLY the sanitized JSON. If startup/GUI/event fails, test auto stops and copies INCONCLUSIVE; user supplies that JSON, does NOT rerun within same JobId. If no purple panel, consult clipboard/Delta console; do NOT manually act without visible step.

**Client-only successful `STOP/COPY` target:** `status=STOPPED`, `reason=OPERATOR_STOPPED_AFTER_CLIENT_PASS`, `nativeStage118Status=CLIENT_TWO_EVENT_LASTOFFER_GUI_UNATTRIBUTED`, `callbackCount=2`, `guiQuantityTransitions=2`, `clientGuiQuantityCrossChecked=true`, `clientGuiCrossChecked=false` (no full item ID verification in this test). LastOffer equality class may be `CLIENT_LASTOFFER_CHANGED_WITH_DIFFERENT_OFFER` or `CLIENT_LASTOFFER_UNCHANGED_WITH_DIFFERENT_OFFER`. Both are **only client observations**, no authenticated server revision/nonce/settlement/unique item/profit. ALL `eventSessionAssociationProven`, `callbackCausalityProven`, `serverTradeRevisionProven`, `serverCompletionProven`, `rawItemIdConfirmed`, `authorizesTrade`, `authorizesOffer`, `authorizesAccept`, `mayReportProfit`, `maySendDiscordWebhook`, `mayUseForStrategyLearning` FALSE, `tradeOutcome=UNKNOWN`. Source/failclosed runner auto-denies no safe panel, wrong root/partner, duplicated callbacks, missing LastOffer, stale offer or accepted state. Hardware behavior is not yet known.

**DO NOT REPEAT** real PR221 Stage101 two-sided weapon match, prior PR218 offer placement, PR222 historical source audit or PR224 offline two-event bridge. Once actual Stage119 iPad JSON arrives, analyze ONLY live LastOffer semantics and exact failure if inconclusive. Then advance independently to authenticated outcome constraints and market source/attractiveness/demand/liquidity/four-slot compounding/Gingerscope protection; no old +15 or forced highest-valued opener.


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
