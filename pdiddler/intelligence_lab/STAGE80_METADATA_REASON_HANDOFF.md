## Stage80 exact-head offline CI result — 2026-11-09

**PASS:** Clean [DRAFT PR #150](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/150) code SHA `08c9becf03cf38039c1bcde5da12c4421e434342`, [focused GitHub Actions 42690244778](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42690244778) SUCCESS. Verified TWO immutable original source Git blobs (actual Oct18 third-party 1,040-row game catalogue and exact Stage79 original classifier); executed **14/14 pure Lua5.4 test groups plus 400 seeded malformed cases**, **8/8 actual native wrapper mocked execution tests**, **3/3 Python tests**, including the real 13 `Misc` and 3 incomplete public records check. All five additional project Luau/Lune/Selene/replay/Hypothesis workflows also SUCCESS on the exact SHA. Two CI issues were caught and corrected before this green result: a stale Stage79 marker in the mock assertion, and missing Stage79 isolation-key check in the native wrapper; tests now verify the final code. No production scanner/P4/value/Discord changes. This is OFFLINE verification only, **not an observed native Stage80 result**.

**NEXT EXACT ONE USER READ-ONLY TEST (main iPad after fresh rejoin, no ALT/trade):**

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/08c9becf03cf38039c1bcde5da12c4421e434342/pdiddler/new_part4/STAGE80_READONLY_OWNED_METADATA_REASON.lua"))()
```

Paste ONLY one aggregate `[GINGERSCOPE STAGE80 METADATA REASON]` JSON line from clipboard or Delta console; no raw keys, account screenshots, profile dumps or manual trades required. This single-client own-profile query executes at most one read-only `GetProfileData` RPC, local 4.5-second timeout, and no retries. It rejects presence of Stage79/stale pdiddler owners (fresh server required). If `miscKeys=1` and other reasons zero, likely confirm category-only Stage79 false alarm. If missing/other reasons, preserve inconclusive and identify specific field family without guessing item. Preserve all live price/trade/Accept/profit/Discord/learning authorizations FALSE, source publication Nov6 expired. PR150 remains DRAFT/UNMERGED.

---

# Stage80 — one remaining `Weapons.Owned` metadata category, not another trading test

**Date:** 2026-11-09. **Issue:** #122. **Mode:** isolated read-only research. Do not merge or run before exact-head CI review.

## Stage79 REAL MAIN-client result (provided by user, not inferred)

`[GINGERSCOPE STAGE79 OWNED TYPE]` schema `gingerscope-stage79-client-owned-typed-key-census-v1`:
- `status=INCONCLUSIVE`, `reason=OWNED_TYPE_QUANTITY_OR_CATALOGUE_DISCREPANCY`
- `originalOwnedKeyTypesObserved=true`
- `ownedKeyCount=183`, `stringKeyCount=183`, `numericKeyCount=0`, `otherKeyCount=0`
- `positiveCopyCount=457`, `invalidQuantityCount=0`, `coercionCollisionPairs=0`
- `unmatchedStringKeyCount=0`, `directCatalogueKeyCount=182`, **`malformedCatalogueEntryCount=1`**
- `eligibleKeyCount=69`, `eligibleCopies=76`, `chromaEligibleCopies=4`
- all server attestation, price authority, trade, Accept, profit, Discord and strategy learning FALSE.

The historical Stage78 theoretical numeric/string collision **did not happen in this observed own profile**. Original key type and direct client catalogue lookup are now observed for 182/183 entries, the remaining one being a **metadata rejection**. The shared report does not preserve that key's name or exact raw field reason, by design. Do not infer it.

## Independent source research explaining why one might be rejected

In the **immutable third-party Oct18 `mm2scripthub/mm2` 1,040-entry public `db` Git blob `2be54c3f5c6b715844728c01a65cc2f24a55c02d`**, all entries were parsed without executing Lua. Exactly **13 source entries** have `ItemType='Misc'` and **three** `RandomLegendaryWeapon`/`RandomRareWeapon`/`RandomUncommonWeapon` placeholders lack ordinary `ItemName` and `ItemType`. The old Stage79 strict predicate rejected *all* non-`Knife`/`Gun` entries. This demonstrates plausible **legitimate non-weapon classification**, NOT proof that the user's ONE rejected entry is one of the 13 or 3. The archived catalogue is third-party, historical, and not Roblox server attestation.

## One scoped new question and implementation

Which **field reason** accounts for the ONE Stage79 `malformedCatalogueEntryCount` on a NEW single read of the same OWN `Weapons.Owned` client data?

- `pdiddler/intelligence_lab/stage80_owned_metadata_reason.lua`: a pure function classifying exact typed `rawget(catalogue,key)` matches to **well-formed `ItemType='Misc'`** (not a weapon), valid Knife/Gun, missing ItemName/type/rarity, unknown type, malformed Chroma, untrusted table, unmatched key, or invalid own quantity. Emits ONLY aggregate counts and static reason codes: NO actual raw owned key, weapon name, nickname, account ID, fingerprint, art ID, price, source checker ID or webhook. Does not infer whether the user-owned entity is tradeable from an arbitrary image.
- `pdiddler/new_part4/STAGE80_READONLY_OWNED_METADATA_REASON.lua`: standalone fresh-MAIN-lobby purple one-shot, same safety/isolation approach as Stage79; exactly **ONE** read-only `GetProfileData:InvokeServer()`, local deadline 4.5s, no retry/hop/offer/Accept/Decline. Loads SHA-pinned exact helper, compares direct `Sync.Weapons` keys without coercion; copies `[GINGERSCOPE STAGE80 METADATA REASON]` aggregate-only JSON. It refuses to run alongside Stage79/other pdiddler scripts in that session. Timeout can leave an uncancelable client in-flight request; do not rerun immediately.
- `pdiddler/tests/test_stage80_owned_metadata_reason.lua`: REAL Lua5.4 14 named groups, synthetic example with **identical Stage79 aggregate totals** (183 entries, 457 copies, 69 eligible keys, 76 eligible copies and 4 Chroma copies) that models a **hypothetical** single valid `Misc` entry. Tests missing, unknown, malformed and 400 seeded mutated inputs; synthetic example is NOT a discovered user item.
- `pdiddler/tests/test_stage80_native_probe_mock.lua`: execute actual native wrapper on mocks (one-call, no auto retry, no fake success).
- `pdiddler/tests/test_stage80_pinned_metadata_sources.py`: require actual pinned immutable historical Stage79 module and 1,040-row third-party catalogue; verify counts of 13 `Misc` + 3 incomplete source entries.
- `.github/workflows/gingerscope-stage80-owned-metadata-reason.yml`: exact-head proof; verify real Git blob hashes and execute actual Lua and Python tests. Until **CI success** do not hand user the native loader.

## Interpretation after native observation

- If `miscKeys=1`, missingName/type/rarity/other conflicts all 0 and original counts comparable, treat the root cause as **weapon-only validator was overly restrictive** for a correctly typed client `Misc` entry. **Do not silently enable trading or relabel `Misc` as Godly/Ancient**. Distinguish `Weapons.Owned` as a profile table name from actual weapon category.
- If `missingNameKeys=1`, `missingTypeKeys=1`, `missingRarityKeys=1`, unknown/chroma problems or unmatched keys, preserve `INCONCLUSIVE` and investigate that **specific aggregate category** with a future separate question; do not blindly whitelist.
- A result in a new lobby may have different inventory copies/keys from Stage79; compare counts honestly, never infer which item changed from category counts alone.
- All outputs, even positive, set `serverAttestation=false`, `authenticatedOwnedInventory=false`, `currentPricesVerified=false`, `numericSupremeCheckerIdVerified=false`, `authorizesTrade/Accept=false`, `mayReportProfit=false`, `mayRecordCompletedTrade=false`, `maySendDiscordWebhook=false`, `mayUseForStrategyLearning=false` and `tradeOutcome=UNKNOWN`.

**Do not rerun Stage79, Stage66 trades or Stage75 catalogue probe. Do not touch production scanner, repricing, economy strategy, or Discord.** Supreme Nov6 publisher clock still beyond the current 72h policy; price freshness is a separate issue.
