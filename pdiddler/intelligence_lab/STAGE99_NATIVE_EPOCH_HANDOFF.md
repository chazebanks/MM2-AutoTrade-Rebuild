## Verified current Stage99 code SHA and edge-case audit

**Code/tests exact SHA `33b3d4338a579d1ad7aefde20f9f2ab0bd2e7727`** (before this handoff-only update), focused [Actions #42761338825](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42761338825) SUCCESS: **14/14 Lua native-wrapper mock groups** executed by 3 Python unittests, original three immutable Git blobs verified, and static zero-transaction policy verified. Inherited Luau, Lune, Selene/StyLua, sanitized replay and Hypothesis workflows must all be green at current HEAD; recheck after doc changes.

Independent code review strengthened the native witness: multiple observed GUI revisions within any ONE manual phase are INCONCLUSIVE rather than counted as a single step; exactly four local GUI epochs (empty baseline, first add, second add, removal) are required. The first offered item must remain visibly unchanged when the second, different item is added. After removing either item, MM2 may renumber `NewItem2` to `NewItem1`; the surviving visible item is compared by its label/Chroma/quantity/optional GUI raw text without requiring the exact old slot index. This does NOT assert a unique weapon instance or authenticate the client feed. The earlier Stage97 one-shot owner flag is an explicit conflicting-owner blocker. New mocked regressions cover the duplicate intra-phase GUI mutation, renumbered removal and cross-stage owner reuse. As in Stage98, a fast, entirely unseen remove/re-add between polls cannot be proven absent; report `noUnobservedMutationsProven=false`.

# Stage99 native original Part4 offer epoch — real multi-item sequence, read-only

## Existing evidence — DO NOT REPEAT

- **Stage97 actual MAIN iPad/Delta native PASS:** one consented ALT partner `UpdateTrade` callback and current exact trade GUI name/quantity matched across 11 original Stage9 frames; `CLIENT_PARTNER_EVENT_GUI_NAME_QTY_CONSISTENT_UNATTRIBUTED`. No physical GUI raw key, no independently signed server trade session nonce, 0 automatic game actions. This *completed* the partner callback presence/correlation question.
- Stage50 own-side Batwing client profile→raw `Scythe` callback add/remove; Stage83 69/69 eligible type & 76/76 copy historical public-reference coverage; Stage91–93 request/partner/Part4 GUI wiring all previously completed for their respective narrow scopes.
- [Stage98 PR168](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/168) **offline green at `642768973f5eb560a184119237c44c84697a208f`**: original Stage9 `parseQuantity`, local GUI epoch/token revocation, original PR105 stale positive snapshot guard, 700 adversarial cases, six CI workflows. No native Stage98 integration proven yet.

## Narrow Stage99 question

Can the real unchanged `p4_native_observer.lua` feed the actual Stage98 `stage98_client_offer_epoch.lua` under original MM2 on iPad/Delta, and **correctly observe THREE distinct visible ALT offer mutations** (0→1→2→1 physical slots) with two preview revocations, stable snapshots, and no false assumption of server event or prices?

**New standalone** `pdiddler/new_part4/STAGE99_READONLY_MULTI_SLOT_EPOCH.lua` is a one-shot, deliberately passive diagnostic. Requires explicit `getgenv().PDIDDLER_STAGE99_READONLY_ARMED=true` and consenting exact `PDIDDLER_STAGE99_TARGET_USERNAME`, PlaceId `142823291`, no existing pdiddler transaction owners, one visible GUI root and matching partner `TheirOffer.Username`. It waits passively up to 30 seconds for MAIN and ALT to **manually open** an empty trade. It loads immutable original Stage9 native/contract from `1971b93d...` and unchanged original Stage98 module from `64276897...` with `marketFresh=false`, no scanner inventories, no pricing or game remotes.

The native adapter privately passes exact original GUI raw side/slots/Amount/Chroma observations into Stage98 `observe`, checks all deny/authority flags and requires two stable empty baselines. It then prints one prompt for each operator action, requiring current ALT GUI to be:
1. `[STAGE99] READY_ADD_FIRST`: ALT manually adds ONE eligible Ancient/Godly (or Chroma) weapon. MAIN remains empty. Original Stage98 sees local GUI offer epoch 2 and two stable samples, then creates RESEARCH-only preview token #1.
2. `[STAGE99] READY_ADD_SECOND_DIFFERENT`: ALT manually adds a SECOND **different weapon type**, preserving first intact, now two distinct physical slots, two total copies. Original preview token #1 must be REVOKED by a new local offer epoch; two stable samples create token #2.
3. `[STAGE99] READY_REMOVE_ONE`: ALT manually removes ONE of those two items, leaving exactly ONE previously seen item. A renumbered surviving GUI slot is allowed when its visible item/Chroma/quantity and optional raw text match a previously seen item; its slot index change still invalidates the preview. Token #2 must be REVOKED; the stable last GUI snapshot is client-only.

The witness never sends a request, places/withdraws an item, Accepts, Declines, teleports, starts a server-hop, invokes inventory remotes, listens to `UpdateTrade`, computes a value or sends Discord. All 0 actual game actions, no names/keys/IDs/partner details/session/JobId in the output. The watcher is **GUI-ONLY**: it cannot detect unseen remove/readd between polls, and Stage98's optional client-callback invalidation is not exercised in this witness. No server revision, account ownership, raw weapon ID, numeric Supreme checker ID, source quote, trade result or profit is proved. Output `[GINGERSCOPE STAGE99 OFFER EPOCH]` status `CLIENT_MULTI_SLOT_ADD_REMOVE_EPOCH_OBSERVED` implies only three visible client GUI steps with local revocations; `noUnobservedMutationsProven=false`.

**Failure cases:** wrong/missing target, duplicate visible GUI root, wrong partner, stale job/current PlayerGUI, nonempty baseline, first two items added simultaneously, second identical/replacing first, removed item replaced with a third, stack x2 instead of second distinct slot, no manual action, any own offer change, any Accept pressed, hidden/closed trade GUI, stale >2s observation, no stable captures => INCONCLUSIVE and no retry on that JobId. Read-only exception handler sanitizes unexpected errors.

## CI requirements

- Git-blob pinned unchanged original Stage9 contract blob `7c84456006bd684dacb0217d0ae092d6d67575a4`, original native adapter blob `a6338e946467ad738005bc5cb13cd2d2fbc2a2d0`, original Stage98 blob `748639e88823198fd7cc0dce92fba49ad07e2729`.
- Python unittest executes the ACTUAL new Delta Lua wrapper with MOCK Roblox Players/PlayerGui/TradeGUI/Visible/Accepted and a *manual* three-step scheduler. Positive original 0→1→2→1, delayed manually opened trade, and negative duplicate/missing partner, wrong session, malformed stack, changed job, own offer, duplicate item, replacement, timeout and ownership conditions. No game actions and no private names logged.
- All five inherited Luau/Lune/Selene/StyLua/sanitized-replay/Hypothesis workflows green **at the same exact tested code SHA**. PR remains DRAFT stacked on PR168; do not merge to main without reviewing dependencies.

## Native test, only after CI green

Use a FRESH original MM2 server with MAIN iPad/Delta and consenting ALT `venossgaming90190`. Do **not** run previous pdiddler scripts simultaneously. Execute on MAIN first:

```lua
getgenv().PDIDDLER_STAGE99_TARGET_USERNAME = "venossgaming90190"
getgenv().PDIDDLER_STAGE99_READONLY_ARMED = true
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/33b3d4338a579d1ad7aefde20f9f2ab0bd2e7727/pdiddler/new_part4/STAGE99_READONLY_MULTI_SLOT_EPOCH.lua"))()
```

On `WAIT_FOR_MANUAL_TRADE_WINDOW`, manually open a trade with both offers empty within 30 seconds; NEVER press final Accept. On `READY_ADD_FIRST`, ALT adds first weapon. On `READY_ADD_SECOND_DIFFERENT`, ALT adds a distinct second weapon. On `READY_REMOVE_ONE`, ALT removes one. Leave MAIN offer empty the entire time. Do not rapid-fire changes before the prompts. Share ONE `[GINGERSCOPE STAGE99 OFFER EPOCH]` sanitized JSON or console screenshot. No rerun in same server if inconclusive.

No source-current quote authority, final Accept, automatic offers or Discord settlement learning is gained by a positive native test. Old blanket mandatory +15 rule remains superseded.
