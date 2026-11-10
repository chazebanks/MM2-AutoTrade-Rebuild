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
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/REPLACE_WITH_TESTED_COMMIT/pdiddler/new_part4/STAGE100_READONLY_TWO_SIDED_EPOCH.lua"))()
```

Run this FIRST in a fresh original MM2 server, no previous pdiddler scripts. Both accounts manually open a trade within 30s. ALT adds first; MAIN then adds one test item; ALT withdraws its own, strictly on the displayed prompts. Neither account presses final Accept. If inconclusive, do not retry the one-shot in the same JobId. Send ONE `[GINGERSCOPE STAGE100 TWO SIDED EPOCH]` sanitized JSON.

**Limit:** a native Stage100 PASS is a valid source for a **CLIENT-ONLY two-sided revision**; it cannot bridge the archived Stage94 public reference directly into `identityLinkEvidence=INDEPENDENT_EXACT` or current live prices. These must be separately proven before any automatic offer/Accept/Discord settlement.
