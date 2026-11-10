## User-requested Stage100 on-screen prompts, trade-safe positioning — Nov 10, 2026

**User requirement:** Every present and FUTURE iPad/Delta diagnostic that asks for manual actions MUST show current, step-by-step instructions **inside the game**, not only in Delta console. The panel must NOT overlap, be covered by, or intercept taps on the active MM2 TradeGUI and its item/Accept/Decline controls. This is durable policy in [`pdiddler/GINGERSCOPE_ONSCREEN_MANUAL_TEST_POLICY.md`](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/blob/main/pdiddler/GINGERSCOPE_ONSCREEN_MANUAL_TEST_POLICY.md) and the TOP of main `pdiddler/GINGERSCOPE_LATEST_CHECKPOINT.md`; future conversation/agent MUST read it before issuing another native test.

**Actual updated Stage100 implementation:** A single in-game purple `PDIDDLER_STAGE100_ONSCREEN_GUIDE` (ScreenGui, DisplayOrder 1200, IgnoreGuiInset=true) shows numbered OPEN TRADE, ALT ADD, MAIN ADD, ALT REMOVE, and PASS/STOP. Unlike the initial draft draggable fixed top-right panel, it is now NON-DRAGGABLE, noninteractive during the test, with a dismiss X only after finishing. The existing panel's exact 292×154 dimensions are passed into immutable-source `stage100_screen_prompt_overlay.lua` `M.choose`, which checks actual camera viewport and `TradeGUI_Phone/TradeGUI.Container.Trade` AbsolutePosition/AbsoluteSize and chooses an out-of-trade safe corner with a 12px collision margin and iPad top/bottom insets. The witness reflows on each original `exactRoot` capture (including GUI movement) and on every manual prompt. If no safe nonoverlapping location or valid viewport is found, it HIDE/fails `INCONCLUSIVE` rather than cover trade controls or continue with console-only instructions. `onScreenGuideNonOverlappingTrade` is a CLIENT geometry check flag, not proof of server behavior.

**Test coverage:** Added original Stage100 Lua native-wrapper mocks for varied 1024×768, 768×1024 and 1366×1024 viewport/trade geometry, left/right positioned trade windows, full-screen trade (no safe region), tiny viewport, blocked panel creation and final dismiss. Tests explicitly assert the draggable/active flags are false, the panel is outside the trade root, and the complete four prompts appear in order. Python unittest requires >=19 REAL Lua test groups, plus previous original Stage9/Stage98 pinned-source exact hashes, no-scripted-offer/Accept policy, and pinned live geometry helper original Git blob. **The earlier pinned Stage100 executable SHA `7154226f...` was BEFORE this screen overlay safety fix; do NOT provide it for a new test.** Only use the final exact SHA after all six workflows are green.

**Native iPad verification:** No actual Stage100 run of this updated screen UI yet. CI is a simulated Roblox UI, so iPad-specific trade window geometry remains to be checked once with a consenting alt. If the user reports the overlay clipping or occupying the trade UI, stop; don't claim perfect placement from synthetic tests.

---

## Stage100 FINAL on-screen guide revision: collision-safe positioning (Nov 10 ET)

**Permanent user rule:** [pdiddler/IN_GAME_TEST_PROMPT_POLICY.md](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/blob/main/pdiddler/IN_GAME_TEST_PROMPT_POLICY.md). Future manual multi-step MM2/Delta tests must show each ordered action on the actual game screen, not only Delta console. Display MAIN/ALT actor, safe next action and no-final-Accept warning. Advance only when verified; show PASS/STOP and sanitized report; test in mocks and iPad.

**Current source-pin tested SHA `a7119802987a56bc65cfb203d180c0b922e5ffb9`**, script immutable Git blob `8d32148cf4624d351e1948e93295fd094e6d2ba4`, [focused Actions #42764830043](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42764830043) SUCCESS and five other workflows SUCCESS at exact same SHA. It loads an additional immutable pure safe-layout helper `pdiddler/new_part4/stage100_screen_prompt_overlay.lua` pinned to `5b8ee35d7f281c23d9c2181abd97a063e59a0660` (blob `e0eac8e039655999bd7bbac1f12da179db7c22ed`). The native mocks include viewport and trade-root rectangles, reject accidental trade-window overlap, test terminal/creation failures, and retain all four ordered prompts.

**Correction to older guide description:** The FINAL implementation is NOT freely draggable; unrestricted dragging could obscure actual trade item or Accept/Decline controls. It auto-docks the compact purple panel to a viewport corner with a minimum gap to the exact visible trade-root rectangle. If no safe non-overlapping location exists, it returns `INCONCLUSIVE` rather than cover gameplay controls. Guide positioning checks use `Workspace.CurrentCamera.ViewportSize` and the actual trade-root `AbsolutePosition` / `AbsoluteSize`; this has passed mocked geometry, **not yet actual Delta native layout**. Users should share the sanitized reason if the screen is too cramped; never blindly force the panel over a trade. Terminal PASS/STOP prompt and dismiss-X remain.

**NEXT one native Stage100 test, with FINAL on-screen code:** fresh original MM2 server, MAIN iPad/Delta and consenting ALT `venossgaming90190`, no older scripts. On MAIN execute exactly:

```lua
getgenv().PDIDDLER_STAGE100_TARGET_USERNAME = "venossgaming90190"
getgenv().PDIDDLER_STAGE100_READONLY_ARMED = true
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/a7119802987a56bc65cfb203d180c0b922e5ffb9/pdiddler/new_part4/STAGE100_READONLY_TWO_SIDED_EPOCH.lua"))()
```

Follow the guide `STEP 1/4: OPEN TRADE` (MAIN opens EMPTY trade), `STEP 2/4: ALT ADD` (ALT adds one eligible expendable weapon), `STEP 3/4: MAIN ADD` (MAIN adds one eligible expendable weapon without ALT changing theirs), `STEP 4/4: ALT REMOVE` (ALT removes their weapon, MAIN unchanged). Never final Accept. Send ONE `[GINGERSCOPE STAGE100 TWO SIDED EPOCH]` sanitized JSON. This also tests real screen placement; if it stops with `ONSCREEN_GUIDE_*` or `SAFE_ONSCREEN_PLACEMENT_MODULE_UNAVAILABLE`, report and investigate actual iPad viewport and trade rectangles, NOT item identity. No rerun same server. After Stage100, prioritize weapon identity and independently current values/demand/stability/liquidity and strategy integration; no more generic GUI repetition.

---
## New user requirement: IN-GAME ON-SCREEN ACTION PROMPTS (Nov 10, 2026)

The user requested the current native test steps be displayed **directly on the iPad MM2 game screen**, not only in the Delta console, and requested that **future conversations implement this as the default for all manual multi-step tests**. Durable main rule: [pdiddler/IN_GAME_TEST_PROMPT_POLICY.md](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/blob/main/pdiddler/IN_GAME_TEST_PROMPT_POLICY.md).

**Stage100 GUI implementation:** same existing PR170, no new trading or market code. In `STAGE100_READONLY_TWO_SIDED_EPOCH.lua`, create a compact dark-purple draggable `PDIDDLER_STAGE100_ONSCREEN_GUIDE` under MAIN `PlayerGui` once the consenting ALT is bound. Prompts `STEP 1/4: OPEN TRADE`, `STEP 2/4: ALT ADD`, `STEP 3/4: MAIN ADD`, `STEP 4/4: ALT REMOVE` appear on screen before corresponding console prompts; every step changes only after the previous observed offer transition has been validated. Warning `MANUAL ONLY | NEVER FINAL ACCEPT` remains visible. A terminal `COMPLETE - CLIENT GUI ONLY` or `STOPPED - INCONCLUSIVE` stays visible until operator chooses X to dismiss. Panel can be dragged by touch, sits at upper-right edge by default and is under ~300px wide. If guide construction/update fails, return INCONCLUSIVE without continuing; no console-only silent fallback. Sanitized report adds `onScreenGuideShown`, `onScreenGuideUpdates`, `onScreenGuideFinalShown`, `onScreenGuideCurrentStep` (no weapon, account or JobId).

**Verified changed SOURCE SHA `666a2a17f6269c4cdfea3b711ae8fc551b904334`** (before handoff-only update), script Git blob `f1aed343b622d6bc828fc8ae47527d55eab5e705`. [Focused GitHub Actions 42764466599](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42764466599) **SUCCESS**: 15 actual Lua5.4 mocked Roblox Stage100 groups run via three Python tests, immutable real Stage9/Stage98 blobs checked; tests verify all FOUR screen steps, proper ALT/MAIN instructions, draggable property, final close button, STOPPED UI, and fail-closed when Instance GUI creation fails. Five inherited Luau/Lune/Selene+StyLua/replay/Hypothesis CI **SUCCESS at exact same code SHA (6/6 green)**. No ACTUAL iPad visual/position test of this overlay yet; do not call it native-verified.

**Next device run MUST use the UPDATED pinned GUI-enabled Stage100 source** (not earlier no-overlay source):

```lua
getgenv().PDIDDLER_STAGE100_TARGET_USERNAME = "venossgaming90190"
getgenv().PDIDDLER_STAGE100_READONLY_ARMED = true
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/a7119802987a56bc65cfb203d180c0b922e5ffb9/pdiddler/new_part4/STAGE100_READONLY_TWO_SIDED_EPOCH.lua"))()
```

Use fresh original MM2 MAIN iPad+ALT, no older scripts, manually open empty trade when STEP 1/4 shows, add ALT one item when STEP 2/4 shows, add MAIN one item without altering ALT when STEP 3/4 shows, remove ALT item without altering MAIN when STEP 4/4 shows, never final Accept. Share ONE sanitized `[GINGERSCOPE STAGE100 TWO SIDED EPOCH]` result and optionally a screenshot showing the on-screen panel (only if verifying layout requires it). Before any new phase, read on-screen current step. After a successful native result, continue weapon identity/value integration per current handoff, not more repetitive GUI tests.

---
## Current verified Stage100 checkpoint (Nov 10, 2026 ET)

**Stage100 [DRAFT PR170](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/170)** current head `7154226fc10a1667959c35a5a88d8d8a5b4047b8`; the actual Stage100 executable is byte-for-byte **identical** to commit `eeae57d1cdc1978a8c4f3f93083b5ce13fb4a9f4` (same original Git blob `78a2c265ed350a60dcbffe66892d8664ba2fd01a`). [Focused Actions #42763170877](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42763170877) **SUCCESS**, 3/3 Python tests executing 13 actual Lua5.4 native-wrapper mock groups, all 3 immutable actual original Stage9 native/contract and Stage98 Git blobs checked, static no-auto-offer/Accept policy PASS. The other five official Luau/Lune/Selene+StyLua/sanitized-replay/Hypothesis workflows **SUCCESS at exact current code SHA (6/6 green)**. **No actual Stage100 iPad native result yet**. Prior native Stage99 0→1→2→1 ALT-only GUI revision success must be retained; do not rerun it.

**Next: ONE read-only iPad/Delta test, then weapon identity/value integration.** The Stage100 experiment only tests two-sided original GUI observer (MAIN 0→0→1→1, ALT 0→1→1→0), still with name-only physical GUI item identities, no current prices. After a real native Stage100 result, **prioritize integration of original game raw-key→canonical public Supreme reference and explicitly fresh value/demand/stability alongside both sides' quantities**, NOT more redundant single-item GUI experiments. Stage94 dated 189-row public price publication has fixed expiry Nov10 22:26:48 UTC, so never promote archived research as current quotes. Numeric Supreme checker IDs and callback-session attestation remain unresolved; if a slot is display-name-only, report estimate/unbound and never authorize automatic offer/final Accept or Discord settlement.

## Source-pinned Stage100 CI verification — no real iPad run yet

**Exact initial full code/test/document HEAD `eeae57d1cdc1978a8c4f3f93083b5ce13fb4a9f4`**. [Focused Actions #42763047986](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42763047986) SUCCESS: **13 genuine Lua5.4 original-source mocked native groups**, executed through **3 Python unittest groups**, strict no-gameplay policy and three immutable original Stage9 native/contract plus Stage98 source Git blobs verified. The later PR-triggered exact-HEAD workflow plus inherited five Luau/Lune/Selene/StyLua/replay/Hypothesis workflows must be checked before a device request. User's real Stage99 native PASS is recorded in main handoff; Stage100 remains untested on iPad.

# Stage100 — two-sided MANUAL offer local epoch witness (native diagnostic, read-only)

## Previously completed real-device evidence (do not repeat)

- Stage50: MAIN-side own Batwing profile/callback/raw `Scythe` correspondence, but no independently authenticated transaction.
- Stage83: 69/69 eligible current client weapon types, 76/76 copies historical public reference coverage; does not prove a live priced offer.
- Stage91–93: exact contact request → exact ALT trade GUI → original Stage9 partner-side manual add observed.
- Stage97: actual one ALT-side `UpdateTrade` callback and physical GUI label+quantity consistent, no physical raw GUI key; client-only unattributed.
- Stage99: **actual MAIN iPad native PASS** `CLIENT_MULTI_SLOT_ADD_REMOVE_EPOCH_OBSERVED`, original Stage9 100 frames, exact ALT-side 0→1→2 different→1, Stage98 localObservationRevision=4, two revocations, three stable previews, main side empty, 0 scripted actions. That previously completed ALT-only multi-slot observation.

## One new relevant issue

A real-valued trade plan requires observing **BOTH offers simultaneously** and withdrawing research confidence when either participant changes their offered item. Stage99 deliberately kept MAIN's offer empty, and Stage105/86 four-slot guard/portfolio planner are still off-device research-only. Rather than rerun Stage99, Stage100 tests one **new** two-sided Stage9→Stage98 client GUI path:

1. On **MAIN iPad/Delta**, manually start a trade with consenting alt `venossgaming90190` and both sides EMPTY. This one-shot wrapper waits 30s for exact open trade.
2. After `[STAGE100] READY_ALT_ADD_ONE`, ALT manually adds ONE expendable eligible Godly/Ancient/Chroma. MAIN stays empty. Stable Stage98 research preview #1 created.
3. After `[STAGE100] READY_MAIN_ADD_ONE`, MAIN manually adds ONE expendable eligible Godly/Ancient/Chroma while ALT's item stays unchanged, creating two-sided 1:1 offer GUI. Local client revision must increment, previous preview revoked, stable preview #2 created.
4. After `[STAGE100] READY_ALT_REMOVE_ONE`, ALT manually removes ITS item only; MAIN's one item remains unchanged. Old preview revoked; last research-only preview #3 created.

Expected visible GUI revision sequence: `(our=0,their=0)→(0,1)→(1,1)→(1,0)`; four LOCAL client revisions including baseline, exactly two old-preview revocations, three stable previews, no offer/Accept/Decline or remote client actions. Original native Stage9 `p4_native_observer.lua` and `p4_observer_contract.lua` are commit-pinned; original Stage98 `stage98_client_offer_epoch.lua` remains immutable. No numeric checker ID, current price, completed settlement or offer approval.

The script's `samePrivateItem` helper compares in-memory GUI label, Chroma, parsed quantity, optional raw GUI text only, WITHOUT exposing names, keys, user/account or server IDs in JSON/clipboard. If the ALT item changes while MAIN adds, if MAIN's item changes while ALT removes, if a side has a stack x2 rather than one copy, if an unexpected extra mutation/slot appears, if the trade GUI/root/user/job changes or any Accept indicator turns on, the witness must stop `INCONCLUSIVE`. It does **not** use `OnClientEvent`, server remotes, inventory or market service; no visible GUI raw key or server revision authenticated. Between-poll invisible changes cannot be excluded. It is not a substitute for current market/liquidity/offer policy.

## Test and PR policy

New **DRAFT Stage100 PR** stacked on Stage99 draft PR169, which is stacked on Stage98 draft PR168; production main loader unchanged. Python driver executes real Lua5.4 original source under fake Roblox Players/PlayerGui/TradeGUI/Accepted, strict 3 Git-blob exact dependencies, positive two-sided 0→(0,1)→(1,1)→(1,0), delayed manual-open and negative wrong partner, bad quantity, own/ALT substitution, no phase, wrong job, nonempty baseline, accepted/closed trade and invalid arm. CI must pass exact reviewed SHA (dedicated plus five inherited gates) before any iPad test.

## Manual Delta loader — use only an exact green tested SHA

```lua
getgenv().PDIDDLER_STAGE100_TARGET_USERNAME = "venossgaming90190"
getgenv().PDIDDLER_STAGE100_READONLY_ARMED = true
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/a7119802987a56bc65cfb203d180c0b922e5ffb9/pdiddler/new_part4/STAGE100_READONLY_TWO_SIDED_EPOCH.lua"))()
```

Run this FIRST in a fresh original MM2 server, no previous pdiddler scripts. Both accounts manually open a trade within 30s. ALT adds first; MAIN then adds one test item; ALT withdraws its own, strictly on the displayed prompts. Neither account presses final Accept. If inconclusive, do not retry the one-shot in the same JobId. Send ONE `[GINGERSCOPE STAGE100 TWO SIDED EPOCH]` sanitized JSON.

**Limit:** a native Stage100 PASS is a valid source for a **CLIENT-ONLY two-sided revision**; it cannot bridge the archived Stage94 public reference directly into `identityLinkEvidence=INDEPENDENT_EXACT` or current live prices. These must be separately proven before any automatic offer/Accept/Discord settlement.
