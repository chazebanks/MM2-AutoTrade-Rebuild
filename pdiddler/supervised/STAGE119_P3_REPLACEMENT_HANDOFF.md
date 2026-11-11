# Stage119 V2 — strict protected P3/P4 parity corrective work (DO NOT RUN ANY DEVICE LOADER)

## NOV 11 2026 — FINAL CRITICAL FIX: STAGE119 V2 PR226 MERGED; ORIGINAL PROTECTED P3→P4 WORKFLOW RESTORED (NEW MAIN IPAD RESULT **NOT YET RUN**)

**THIS SUPERSEDES** the earlier withdrawn Stage119 V1 [merged PR225](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/225). After the user challenged the incorrect manually-opened test flow, actual source comparison identified V1 had omitted the prior real-iPad-proven purple physical **ARM P3**, exact ALT-only P3 outgoing request, original P4 protected *revocable lease*, broad previous-owner/script conflicts, and always-visible purple STOP/COPY on inconclusive. Its 6/6 CI was limited to weak native mocks; **DO NOT RUN that old immutable PR225 loader**, even though it remains retrievable. This failure was admitted and recorded at [PR225 review](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/225#issuecomment-6789682775).

**NEW CORRECTED V2 RELEASE:** [PR226 MERGED](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/226) history-preserving merge `8b8b333c2f5327fe8259b6f5e6f0a104429a4f9d`, reviewed exact head `0c24bcdb08419394cb863f9b10eba5e505a281ae`. ALL **7/7 GitHub Actions SUCCESS** on exact head, including actual original-source P3 startup supervisor + P4 coordinator/TradeIO + original Stage9 native GUI `Lune` **342 assertions** [focused workflow #42981216197](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42981216197), Python strict PR221 comparison **4 tests** [release gate #42981216232](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42981216232), official Luau, Lune, Selene/StyLua, sanitized replay, Hypothesis. Source pinned exact Git blobs for ORIGINAL P3 boot, P4 coordinator, Stage9 native/contract, geometry, protected TradeIO, P3/P4 handoff, watchdog; original scanner/outgoing sources SHA-checked separately despite use of outgoing/Roblox test doubles in native offline mock. Exactly 7 newly added files, **ZERO existing source files changed**, including known-good PR221 Stage101 and PR218 auto one-item code. No device Stage119 V2 run yet.

**V2 reviewed LOADER** `pdiddler/supervised/STAGE119_P3_BOUND_READONLY_START.lua` Git blob `ef98ecab81cd4b7e4b2b9402a346cb6ab74430e3`; it downloads exact **TESTED native runner** immutable commit `0e8e88fba07d72a7e1fb51178e0b105c3a647568` / Git blob `fc25514564e78d390b089742eb4e7da7508c12fa`. The frozen runner is forked from actual PR221 successful MAIN iPad source with exact same explicit **ARM P3**, ALT-only original request, P3 paused current epoch and `supervisor.currentBoundReadOnly()` + P4 capture/Stage9 full label/chroma/quantity corroboration on every callback; replaces ONLY original Stage101 weapon-id observation with existing PR222 opaque LastOffer + PR224 two-event comparison. No script OfferItem, final Accept, Decline, hop, Discord or profit. Browser / CI confirms launcher and frozen native hashes after merge.

**ONLY APPROVED FUTURE MAIN iPad Delta command:**
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/8b8b333c2f5327fe8259b6f5e6f0a104429a4f9d/pdiddler/supervised/STAGE119_P3_BOUND_READONLY_START.lua"))()
```

**ONE NEW distinct on-screen physical test**, fresh original MM2 server with consenting ALT `venossgaming90190` already joined, no other pdiddler script or pre-open trade:
1. MAIN runs loader, purple **1/5 MAIN ARM P3** appears. MAIN physically taps **ARM P3**; only original P3 sends exact ALT incoming TRADE REQUEST.
2. ALT manually **accepts the REQUEST**, BOTH sides leave offers **EMPTY**. Wait for protected P4/Stage9 empty baseline confirmation and actual purple step **3/5 ALT ADD**.
3. ALT manually adds ONE expendable, inexpensive eligible weapon. MAIN offers **ZERO**. Wait for purple **4/5 ALT REMOVE** (two stable captured GUI frames after one client callback).
4. ALT manually withdraws exactly that ONE weapon. MAIN still offers ZERO. Never final Accept either side.
5. Purple **5/5 client result** appears if two client callbacks+two original P4/Stage9 GUI quantity changes match; MAIN manually **Declines** the open trade and taps purple **STOP / COPY** to obtain sanitized JSON. If inconclusive / safe UI absent, STOP and send captured JSON, NO retry in same JobId.

**Expected positive client-only after STOP:** `clientLastOfferStatus=CLIENT_TWO_EVENT_LASTOFFER_GUI_UNATTRIBUTED`, `callbackCount=2`, `guiQuantityTransitions=2`, `p3ArmObservedClient=true`, `clientTradeWindowObserved=true`, `protectedP3P4LeaseCrossChecked=true`, `clientGuiQuantityCrossChecked=true`, `lastOfferEqualityClass=CLIENT_LASTOFFER_CHANGED_WITH_DIFFERENT_OFFER` or `CLIENT_LASTOFFER_UNCHANGED_WITH_DIFFERENT_OFFER`. Both ONLY client opaque token equality; `clientGuiCrossChecked=false` (this test isn't Stage101 full item-identity proof), `eventSessionAssociationProven=false`, `callbackCausalityProven=false`, `serverTradeRevisionProven=false`, `serverCompletionProven=false`, `rawItemIdConfirmed=false`, `authorizesTrade=false`, `authorizesOffer=false`, `authorizesAccept=false`, `mayReportProfit=false`, `maySendDiscordWebhook=false`, `tradeOutcome=UNKNOWN`. No automatic final Accept. The previous physical PR221 1+1 weapon identity client pass remains closed; do not repeat it. After new Stage119 V2 iPad receipt, analyze ONLY observed live LastOffer token behavior/failure and choose next **distinct** blocker, later continue market freshness, demand/liquidity/attractiveness, four-slot upgrade/downgrade compounding, protected Gingerscope acquisition. No universal +15 or forced highest-value opener.


## NOV 11 2026 — Stage119 V2 now built; strict original P3/P4 integration verified OFFLINE

Previous PR225 manual-open Stage119 device command remains WITHDRAWN and must never be reused. This new v2 is a *different* source and does NOT repeat actual PR221 Stage101 weapon identity.

**Native P3-bound replacement:** pdiddler/supervised/STAGE119_P3_BOUND_READONLY_NATIVE.lua, immutable source commit 0e8e88fba07d72a7e1fb51178e0b105c3a647568 and Git blob fc25514564e78d390b089742eb4e7da7508c12fa. Source forked from actually successful PR221 native P3 runner, retaining supervisor, exact ALT-only scanner, outgoing request module, coordinator, original protected TradeIO/P4 binding, watchdog, original Stage9 physical reader, on-screen ARM P3 and always available STOP/COPY. ONLY the research observation was replaced by original PR222 LastOffer comparator plus merged PR224 two-event State118 witness. Unlike PR225 it never asks MAIN to open a trade manually or offer any weapon.

**One-line future device launcher (ONLY after this PR is merged and exact final CI checked):**
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/COMMIT_AFTER_MERGE/pdiddler/supervised/STAGE119_P3_BOUND_READONLY_START.lua"))()
```
Do not publish a guessed post-merge SHA; after actual merge verify loader blob and replace COMMIT_AFTER_MERGE with exact returned Git SHA. Loader pins native immutable 0e8e88... and refuses old Stage119 V1 owner or already-used same JobId.

**On-screen protected V2 flow:** fresh original MM2 on MAIN iPad Delta, exact consenting ALT venossgaming90190 already in same server, no other pdiddler scripts or already-open trade. Run loader on MAIN. Step 1 MAIN physically taps purple ARM P3, which authorizes ONLY original P3's one ALT trade request. Step 2 ALT manually ACCEPTS incoming request and BOTH offers remain EMPTY while original P4 paused bound lease and Stage9 baseline is verified. Step 3 when visibly prompted ALT manually ADDS exactly one inexpensive eligible weapon, MAIN remains EMPTY; two physical Stage9+P4 GUI samples confirm after original UpdateTrade event. Step 4 ALT manually REMOVES exactly the same weapon after second prompt, MAIN remains EMPTY; second callback and two stable GUI captures cross-check; no final Accept on either side. Step 5 MAIN manually presses Decline after client result, then purple STOP / COPY and pastes sanitized JSON. Script never offers, final Accepts, declines, teleports or reports genuine trade. One-shot only; no same-job retries.

**Full actual original module verification:** dedicated strict source-bound GitHub Action fetches and SHA-verifies historical actual PR221 P3 boot+P4 coordinator, original Stage9+native, Stage83/Stage101 test deps, PR222 LastOffer, PR224 Stage118, and the exact NEW native blob. Lune tests execute REAL protected supervisor/coordination/Stage9 while stubbing only old outbound queue and Roblox physical UI; they exercise real ARM, empty ALT baseline, callbacks for ALT ADD and REMOVE, changed and unchanged LastOffer token, exact/old missing-bound-lease, wrong ALT, P3 root disappearance, V1 owner collision, duplicate/malformed callback, no ARM, zero physical item offers, safe responsive geometry, and STOP/COPY maintained including **after success when the trade GUI moves** and unsafe viewport hides the panel. Original main PR221 runner and PR218 prior successful auto-offer unchanged. Current validated dedicated integration: **342 Lua assertions**, Python parity release gate **4 tests**, all seven exact PR-head CI workflows previously passed, including official Luau, Lune, Selene/StyLua and sanitized/Hypothesis replay; reconfirm checks after final handoff commit.

**Proof limit:** The new native source is tested offline ONLY; there is NO physical MAIN iPad Stage119 V2 result. LastOffer is client opaque equality, NOT a server authenticated session nonce or trade revision. Every offer/Accept/profit/Discord authorization false, tradeOutcome UNKNOWN. Client GUI quantity correlation is not the old Stage101 full item identity proof. Never claim current server acceptance or settlement from this test.


## Identified failure of development process

The original MAIN iPad PR221 Stage101 test truly operated under the ORIGINAL protected P3 supervisor to P4 live trade:
- Purple ARM P3 user tap, then only P3's already-reviewed ALT-only outgoing trade request
- Exact consenting ALT accepts request, exact partner Player instance
- Original P3 paused on active trade and P4 read-only lease from supervisor.currentBoundReadOnly()
- Original Stage9 physical GUI independently cross-checked against protected P4 TradeIO
- Purple step-by-step panel plus STOP/COPY always available and disjoint from MM2 Trade GUI
- Failclosed on owner/epoch/lease changes and prior old missing interface, without automated final Accept

PR225 Stage119 departed from that architecture despite 6/6 green offline CI. It replaced P3 auto-request and P4 bound lease with a manually opened trade and root/header client observations. Its narrower Lune mock could not catch those omitted protections; startup only denied Stage119's own owner, and it hid the step overlay on errors instead of exposing STOP/COPY. The correct approach preserves the PR221 P3/P4 integration and changes only the novel LastOffer observer.

**Withdrawal recorded** in [PR225 review comment](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/225#issuecomment-6789682775) and canonical/latest/strategy/Stage119 handoffs. Old immutable SHA-pinned PR225 Delta URL cannot be revoked by changing main. DO NOT RUN. No real Stage119 iPad result exists.

## One issue to fix first: restore P3/P4 parity

1. Use exact original successful PR221 P3/TradeIO/coordinator/boot/watchdog/scanner, not substitute mocks or manual trade.
2. Purple panel displays ARM P3 and STOP/COPY on MAIN BEFORE any trade request. Single ARM P3 user action passes supervisor.arm with explicitUserAuthorization=true, allowRealP3RequestRotation=true, finalAcceptMustRemainManual=true.
3. ALT manually ACCEPTS incoming original P3 request. No request, offer or Accept before ARM; never request a stranger.
4. Each callback and Stage9 capture verifies current protected P3/P4 lease via supervisor.currentBoundReadOnly(), including P3_BOUND_CANDIDATE_READ_ONLY, part3Paused=true, part4TradeVisible=true, partnerExactClientBound=true, exact root/Player/JobId/epoch. Reuse original PR219 physical cross-check against protected P4 TradeIO.
5. After protected session with BOTH offers empty and unique listener attached show ALT ADD ONE. Once stable show ALT REMOVE ONE. MAIN offers nothing. Exactly two bounded callbacks, no token/value logging and all server revision/Accept/profit/Discord authority false.
6. STOP/COPY visible at every on-screen step. On inconclusive keep safe on-screen status/stop until dismissed; if no safe geometry hide and copy sanitized receipt but do not prompt for actions.
7. Reuse original Stage100 safe iPad geometry and recheck continuously while user must interact, including AFTER local-positive result before manual Decline/STOP. Never cover trade controls.
8. Do not expose production test-only dependency injection to override frozen sources; tests need a segregated harness.
9. Lune tests MUST exercise exact pinned real P3 supervisor/coordinator/TradeIO, negative missing-bound-lease, changed epoch, wrong ALT, ARM never tapped, duplicate/delayed callbacks, stale GUI, viewport movement, unsafe prompt placement and hidden STOP. Verify frozen original sources by Git blob as PR221. Run Python and inherited CI at exact HEAD. Green from a mock skipping P3 is not enough.

## Current checkpoint

New pdiddler/ci/test_stage119_p3_parity_release_gate.py is intentionally RED: it rejects PR225 and fails until NEW pdiddler/supervised/STAGE119_P3_BOUND_READONLY_NATIVE.lua, its immutable loader, and pdiddler/ci/stage119_p3_bound_original_mocks.luau exist and pass. A dedicated workflow runs the gate; no device loader approved while this is RED.

No new hardware test authorization yet. Original Stage101 iPad client-identity proof remains CLOSED. Preserve user objective of attractive/liquid market-aware inventory compounding, upgrades/downgrades and protected Gingerscope, but solve missing P3/P4 parity first.
