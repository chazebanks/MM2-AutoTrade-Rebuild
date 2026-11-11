# Stage75 — One new read-only native direct public-name correspondence test

Status: **DRAFT/RESEARCH ONLY; NATIVE TEST NOT RUN UNTIL EXACT GREEN CI**.
Goal: Close a narrow source-identity gap behind Gingerscope issue #122 without re-running the earlier Stage54/55/57 fuzzy mapping census.

## Known results before Stage75

- Stage73: main-iPad T4.4 purple scanner native display/copy-status UI passed; do not repeat it. Prices stayed historical/UNVERIFIED, outgoing paused.
- Stage54/55: native 1,040 current client catalogue rows; legacy selected 190, 164 fuzzy/19 alias/7 internal. This is old evidence, NOT 190 authenticated mappings.
- Stage57/58: 10 unusual game-only raw catalogue entries observed/reviewed. Existing `Gingermint_K` describes Cookiecane knife, NOT Gingermint gun. Do not redo these checks or use image/asset ID equality as proof.
- Stage74: independent pinned Oct5 public archive yields 178/190 unique public-name/category correspondence; pinned THIRD-PARTY Oct18 `mm2scripthub/mm2/db` yields 188/190, 0 candidate collisions (Godly `Battleaxe` and `Battleaxe II` differ in game metadata as `BattleAxe`, `BattleAxe II`). Nov18 source file includes 1040 table rows like native game observations but **third party**, not Roblox server authenticated. Its `db2` is same blob as `db`, not independent corroboration. Two 2026 Chroma Ancients have `Rarity=Ancient` and `Chroma=true`; Stage74 parser corrected and tested. A reused `ItemID` between base and Chroma Emberscythe rules out equating that art/asset ID with unique owned weapon identity.
- Supreme site Ancients/Godlies/Chromas still publishes November 6 at 10:56 AM Eastern as of November 9; default 72h age cap expired Nov9 10:56 AM Eastern. A new fetch cannot freshen publisher time. The original Nov4 list below is a **names-only HISTORICAL input** (no prices or numeric market keys).

## Stage75 exact implementation and proof scope

This stage checks the **present local MM2 client's** `ReplicatedStorage.Database.Sync.Weapons` against the 190 original historical public category/variant/label entries, using strict case-sensitive equality. It DOES NOT access another player's inventory or your own `Weapons.Owned`, no trade window, no hop, no server remotes and no values. Current catalog client table is not independent current-game server authentication.

- `pdiddler/intelligence_lab/stage75_historical_public_name_index.lua`: 190 source names and categories ONLY, generated from exact Nov4 Supreme historical JSON blob `955e3fb7cd25999fc4f0aad4a77378b9a7bb9ba3`. CI independently compares every name to exact source bytes; **NO SOURCE PRICES** or site numeric IDs in this index.
- `pdiddler/intelligence_lab/stage75_strict_live_public_name_comparison.lua`: pure evaluator; runs over client `Sync.Weapons`, counts all catalogue records, eligible Ancient/Godly/Chroma knives and guns, checks unique exact `(page, ItemName)` (prefixing Chroma using `Chroma==true`, allowing Chroma Ancient). Never uses `ItemID` as a join key. It exports only aggregate counts and at most 12 missing **public publisher labels**, not raw game IDs/keys, player names, inventory or identifying metadata. Duplicate candidates are ambiguous; unexpected current catalogue row count, shape errors or source indexing fail closed into research-only states. All numeric-price/trade/Accept/Discord/learning/settlement/profit flags are FALSE.
- `pdiddler/new_part4/STAGE75_NATIVE_STRICT_PUBLIC_NAME_BOOT.lua`: one pinned original MM2 client loader using previously demonstrated `Database.Sync` game ModuleScript; bounded one-shot, repeat-run guard, isolated session check, game-place check, in-game small purple instruction GUI DURING execution, automatic sanitized-report clipboard with console fallback. The script loads ONLY pinned own source index & pure evaluator from GitHub, does not execute third-party Oct18 database. It does not depend on Stage73 continuing to run.
- Synthetic test builds 1,040 anonymized fake game entries (200 eligible; 188 unique name matches, two Battleaxe case variants + 10 extra source-external game entries, 840 commons) with mock Roblox services; asserts current-source corruption, duplicate source/name, unexpected catalogue drift, missing/invalid row, base/Chroma collision, explicit Chroma Ancient behavior, session interrupts, one report, one in-game status and fallback clipboard APIs. Real Lua5.4/luac5.4 run in CI. **Synthetic 188/190 does not predict the real client's exact number.**

## Next one manual action only AFTER code-head CI passes

- MAIN iPad Delta, fresh original MM2 server, **Tablet** selected, trade closed, NO other pdiddler scripts/ALT. Run only one SHA-immutable Stage75 loader, with exact head to be recorded upon green CI.
- Read on-screen purple Stage75 instructions, allow auto-copy, paste exactly one anonymized `[GINGERSCOPE STAGE75 PUBLIC NAME ONLY]` JSON report. One small screenshot only if the GUI visibly fails or a status error appears (avoids redundant Stage73 visual validation).
- If source report returns 188 unique, two Battleaxe names missing and 0 ambiguous, it corroborates the current local game catalogue's strict names. Still NOT proof of live Supreme price freshness, players' weapon ownership keys, market checker numeric identity, server settlement, or trading authorization. Even a perfect 190/190 name match would not justify P4 automatic acceptance.
- No need for any further Stage54/55 fuzzy counts, Stage57 cases, or manual ALT trading.

No final Accept, automated trading, completed/rejected Discord learner, profit reporting or price refresh authorization from this stage.
