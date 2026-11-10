# Stage106 — two-sided UpdateTrade raw-key / physical-slot witness

## NOVEMBER 10, 2026 — ORIGINAL iPad/Delta native result (user-supplied sanitized aggregate)

**Stage106's intended original-device CLIENT-SIDE diagnostic has now PASSED** using the reviewed, immutable PR184 native wrapper source at commit `62f5101aec895575df4783c5838ba1872e78e327` (Git blob `07aa55b1c7d70e66eaf697c57d1b72652810d2e6`, independently verified all six exact-SHA CI workflows). The user furnished the standard `[GINGERSCOPE STAGE106 TWO-SIDED UPDATE TRADE]` report on the same date. This is *user-provided native client telemetry*, not independent server attestation or a completed trade.

**Precisely observed:** `status=CLIENT_MULTISLOT_RAW_KEY_CANDIDATES_MATCH_GUI_UNATTRIBUTED`, `reason=CLIENT_RAW_KEY_CANDIDATES_ONLY_NO_SIGNED_TRADE_SESSION`; `readOnly=true`, `clientOnly=true`; `inputClientEventCount=1`, `eventReceiptCount=1`; `bothSidesReconciled=true`, `ourMatchedSlotCount=1`, `theirMatchedSlotCount=1`, `clientPerSlotRawKeyCandidateUnique=true`; `clientEventGuiVariantMatched=true`, `clientEventGuiQuantityMatched=true`, `currentClientMetadataMatchedHistoricalPublicRef=true`; `sessionClientReferencesConsistent=true`, `exactPartnerGuiObserved=true`; `guiTwoStableSamples=true`, `observedVisibleGuiTransition=true`, `stage9ObserverBound=true`; `stage9Frames=43`, `elapsedSeconds=15`. On-screen guide: `onScreenGuideShown=true`, `onScreenGuideFinalShown=true`, `onScreenGuideNonOverlappingTrade=true`, `onScreenGuidePlacementFailures=0`, `onScreenGuideUpdates=249` (display refresh count, not separate trade events).

**Actions and authority observed:** `actualRequests=0`, `actualOffers=0`, `actualAccepts=0`, `actualDeclines=0`, `actualTeleports=0`; `authorizesTrade=false`, `authorizesAccept=false`, `serverCompletionProven=false`, `tradeOutcome=UNKNOWN`, `mayRecordCompletedTrade=false`, `maySendDiscordWebhook=false`, `mayReportProfit=false`, `mayUseForStrategyLearning=false`.

**Crucial unresolved evidence:** `guiNameOnlySlotCount=2`, `guiRawTextSlotCount=0`, `rawItemIdConfirmed=false`, `uniqueWeaponInstanceProven=false`, `eventSessionAssociationProven=false`, `callbackCausalityProven=false`, `serverTradeRevisionProven=false`, `serverAttestation=false`, `authenticatedOwnedInventory=false`, `numericSupremeCheckerIdVerified=false`, `currentPricesVerified=false`, `priceForTradeVerified=false`, `sourcePublisherFresh=false`, `marketValueAuthority=false`. A unique name/variant/quantity-compatible *client candidate* is NOT proof of a physical slot's true raw instance identity, an authenticated server trade revision or a market quote.

**Stage106 disposition:** NATIVE CLIENT-SIDE GOAL MET, STOP. Do not request another Stage106 ALT/MAIN run or resurrect Stages97/99/100/103 to reproduce it. No new auto-offer/Accept or trade-outcome/webhook/learner authorization. PR184 remains a DRAFT/unmerged research witness; production script has not inherited these modules. Preserve prior failed probes and their real original source semantics.

**Next independent blocker to investigate:** exact RAW weapon instance/slot identity and authenticated event-session association are STILL unproven after prior Stage35/36/41 and Stage101/106 work. Before creating another test, re-read their rejected hypotheses and Stage83 registry; do NOT assume another display-only or `LastOffer` client correlation creates server authentication. Price integrity remains separately blocked by Issue122 (stale/fragmented first-party Supreme publication and unresolved numeric checker-ID mapping). Choose ONE new root cause with offline negative tests first, otherwise explicitly document feasibility limits.

**Provenance:** original user-supplied sanitized Stage106 JSON in chat; recorded Nov 10, 2026; no credentials, account identities, raw event packets, item raw keys or unverified profit recorded.

## Status

Standalone read-only research code for the existing task PR178. Initial Copilot implementation: `ecf9b54f9faa497b9755f07843373ecc6075f8d6` (SUPERSEDED). **Corrected canonical PR178 implementation:** `0865d92370e6353f5eaac43f6a5c5fa29ad477b8` (the four corrected files are byte-for-byte Git blob equivalent to independently tested PR184 at `c7fa30a3e1392a2d335b896f896b1cd5fa6d89b2`). That independent review branch passed 6/6 GitHub Actions including original Lua native-wrapper integration. The Copilot-origin PR178 initially showed `action_required`, and exact-commit CI on corrected PR178 must still be independently verified. The stage remains untested on-device.

The implementation reuses PR176's matcher; it adds no second identity matcher. It loads the immutable original Stage9 observer, Stage83 archival registry, PR176 corrected matcher, and PR170 Stage100 layout helper at fixed commit URLs. It does not merge or modify those branches.

## Independent TDD review and integration — Nov 10

[PR184](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/184) independently reproduced a **hidden-GUI-root / invisible-partner-header identity gate failure** against the original native wrapper. The RED original-Lua run is [42779889499](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42779889499). A `visibleInPlayerGui` ancestor check now confirms every GuiObject/ScreenGui from trade root and partner Username through the current PlayerGui. Negative tests reject hidden Container, hidden TheirOffer, and hidden Username BEFORE attaching the listener. Two CI defects were also corrected: format-tolerant Lua boolean static scanning and isolating the pinned-source Python/Lua test suite from unrelated broad test discovery.

At reviewed PR184 SHA `c7fa30a3e1392a2d335b896f896b1cd5fa6d89b2`, **all six Actions succeeded**, including [focused native mock 42780252521](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42780252521) and [inherited replay 42780252577](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42780252577). The four corrected files were copied into PR178, each Git blob SHA verified equal to PR184. This is code-equivalence evidence, not automatically a PR178 exact-SHA CI result.

An independent PURE offline comparator exists in [PR183](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/183): empty→stable ALT-only→listener after ALT→one MAIN callback→stable both-sided client snapshots. It has 12 original-Lua groups, 360 adverse mutations, and 6/6 CI PASS at `cbd05ba8d98d9495ade900c5e04ffb4db0552e4e`. The native wrapper already implements this sequence; PR183 is an independent oracle, NOT another native probe or a module to blindly merge.

**Evidence boundary:** no original iPad Stage106 test has been run. No live server event/session authenticity, unique item identity, current prices, or completed trade are proved. Do not use the old pre-review `ecf9b54f` loader or repeat completed Stages97/99/100/103.

## Post-review Actions caveat

GitHub Actions status belongs to an exact commit and PR context. The PR184 green run proves reviewed file blobs, NOT that the updated PR178 was independently executed. Do not request an iPad run until the exact native branch source pin and CI context are verified. No merge to main has been performed.

## Pinned source compatibility

| Source | Commit | Verified Git blob |
|---|---|---|
| Original Stage9 `p4_observer_contract.lua` | `1971b93d324f0275e6a9affb472ac3e804439ed8` | `7c84456006bd684dacb0217d0ae092d6d67575a4` |
| Original Stage9 `p4_native_observer.lua` | `1971b93d324f0275e6a9affb472ac3e804439ed8` | `a6338e946467ad738005bc5cb13cd2d2fbc2a2d0` |
| Stage83 public registry | `25b48b60fdb2f971bbb6b2a2020f3c7c4432f7ae` | `40e2a0ff01b70b2d0181c62cae347a08da82bcb8` |
| PR176 corrected Stage101 matcher | `29889595b5e80c788ade75fbb97880b736fc8cb2` | `c15afe8077d544534e0f122ce2f4a5081cb2ac90` |
| PR176 Lua regression corpus | `29889595b5e80c788ade75fbb97880b736fc8cb2` | `526b3b0ba45ca7ebdd5e328ba9c37c680c4a797a` |
| PR170 Stage100 safe-position helper | `59d869b7d4d8fbcee3f2709e266b47ffb4a05d78` | `e0eac8e039655999bd7bbac1f12da179db7c22ed` |

The wrapper was exercised under Lua 5.4 with the actual pinned Stage9 observer and contract, PR176 matcher, Stage83 registry, and Stage100 geometry helper. This verifies offline source integration only; it does not prove live callback causality.

Stage97's earlier one-sided listener remains a completed, distinct native observation. Stage103's purple guide and Stage100 layout helper were reviewed; their already completed native scopes are not repeated. See PR167/170/174 and the canonical handoff.

## Validation at implementation commit

- `python3 -m unittest -v pdiddler.intelligence_lab.test_stage106_readonly_witness`: **2 Python tests passed**. The first runs the pinned PR176 Lua suite: **18 Lua groups and 500 adversarial mutations**. The second runs the Stage106 wrapper against mocked Roblox objects and the original Stage9 observer: **17 named integration groups**, including a two-sided swapped-player candidate, pre-listener ALT callback, x5 Chroma stack, four distinct slots per side, stale/delayed and duplicate/missing events, malformed packet, acceptance/lock, identity/session/root/job changes, protected Gingerscope, changed snapshots, unsafe layout, viewport movement, exact-target absence, and listener cleanup.
- `lua5.4 -p` (via `luac5.4 -p`) on the Stage106 wrapper and integration test: **pass**.
- Pinned StyLua 2.6.0 `--check` on the Stage106 wrapper and integration test: **pass**.
- Secret scan: **no secrets detected**.
- CodeQL: **0 alerts** for Actions and Python.
- Stage106 Actions run [42779257796](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42779257796) and inherited exact-commit checks [42779257627](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42779257627), [42779257614](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42779257614), [42779257709](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42779257709), [42779257604](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42779257604), [42779257887](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42779257887): all report **`action_required`**, each with zero jobs and no failed jobs/logs. This is not a CI pass; no retry was requested because the runs did not fail.

## One manual iPad test — only after all six workflows are green

**Prerequisites:** a fresh original MM2 server; MAIN iPad/Delta; the consenting ALT `venossgaming90190`; no other pdiddler scripts; exact current ALT Player object and original Stage9 trade GUI; do not retry in the same JobId. Run once on MAIN:

```lua
getgenv().PDIDDLER_STAGE106_TARGET_USERNAME = "venossgaming90190"
getgenv().PDIDDLER_STAGE106_READONLY_ARMED = true
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/0865d92370e6353f5eaac43f6a5c5fa29ad477b8/pdiddler/new_part4/STAGE106_READONLY_TWO_SIDED_UPDATE_TRADE_WITNESS.lua"))()
```

Follow the numbered purple/black on-screen guide; the Delta console is not the only prompt:

1. MAIN manually opens an **empty** trade with the ALT.
2. After the empty baseline is verified, ALT manually adds **one expendable eligible Ancient/Godly/Chroma weapon**. MAIN remains empty. The wrapper waits for two stable Stage9 snapshots before connecting the listener.
3. Only after that verification, the read-only listener attaches and records `before` with ALT's item already offered. When the guide shows `READY_MAIN_ADD_ONE`, MAIN manually adds one eligible expendable Ancient/Godly/Chroma weapon; ALT stays unchanged. Gingerscope remains protected.
4. Do not press final Accept. The wrapper accepts only exactly one complete callback plus two stable after-snapshots separated by at least 0.15 seconds. It disconnects on every exit and shows a sanitized PASS/STOP with optional dismiss.

If viewport/trade geometry has no safe non-overlapping placement with 12px clearance, the guide hides and the run stops inconclusive. A positive result is only client-side raw-key candidate consistency for both visible offers. It does not prove callback causality, server session association, unique item instances, ownership, current prices, completion, profit, or trade/Accept permission. Do not report raw keys, names, account identity, tokens, or packet payloads.

## Issue follow-up

Issue [#122](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/issues/122) remains the evidence thread. This session could read its latest comment but had no issue-comment/write tool, so no Issue #122 update is claimed here. The exact code SHA, test results, CI blocker, and gated manual sequence are recorded in this focused handoff and PR178.
