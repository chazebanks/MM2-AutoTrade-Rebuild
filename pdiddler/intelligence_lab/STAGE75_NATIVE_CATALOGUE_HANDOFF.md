## Stage75 CI retry checkpoint — 2026-11-09 (NOT NATIVE VERIFIED)

Initial exact-source Stage75 GitHub job [42673099422](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42673099422) installed actual Lua5.4 and validated the pinned Oct18 public Git blob; 17 unit tests executed, **three test assertion failures**, not production trading errors. The deterministic fixture expected five overlapping asset-ID pairs even when one partner's catalogue record was absent or malformed (actual correct count four); corrected in test source. A scanner-code prohibition test incorrectly matched the **text of a comment** stating not to run a full catalogue census; test now checks executable lines. No tests or price/trade safety assertions disabled. A prior additional test run also had a legitimate early code issue and was fixed.

Next exact-head run [42673632717](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42673632717) failed at **workflow scheduling** with **0 jobs** in GitHub Actions REST (not a failing Lua unit test); its PR-head Stage75 [42673639590](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42673639590), replay [42673639500](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42673639500), and Lune [42673639467](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42673639467) also show failure/zero jobs. Meanwhile same SHA Luau CLI, Hypothesis and Selene checks passed, indicating mixed GitHub job scheduling, **not** proof source test succeeded. Do not request MAIN iPad test until a NEW exact-head dedicated Stage75 run executes 17/17 actual tests and passes; no branch merge or auto-trading changes. Attempt one new docs-triggered run, then investigate if job dispatch continues failing.

---

# Stage75 — targeted read-only 13-key LIVE client catalogue comparison (NO trading)

Date: 2026-11-09; follows the successful Stage73 native in-game layout smoke test and Stage74 historical public name comparisons.
Status: **DRAFT, isolated from main; offline CI required; one future MAIN-iPad test ONLY after green**.

## What we know before Stage75

- Stage73 read-only T4.4 purple scanner was visually confirmed on the user's MAIN iPad, report delivered, no repeat required. Outgoing paused, values UNVERIFIED, Accept disabled.
- Stage74 clean DRAFT PR142 compares independent public catalogues to historical Supreme source labels. October5 source: 995 game rows/190 eligible and 178/190 exact page/name matches. October18 independently posted third-party `mm2scripthub/mm2 db` at commit `0f2715187e7eae36eea4bd97afee809478fc877d`: **1040 rows, 200 eligible, 188/190 exact historical Supreme labels**, Chroma Ancients correctly recognized, two case-sensitive Battleaxe mismatches. `db2` duplicates `db` byte-for-byte and is not another independent source. **Source-level names are not current game or server item authentication**.
- Five base/chroma pairs in Oct18 mirror the same `ItemID`: Emberbow, Emberscythe, Mortal, Immortal and Embersickle. The art/asset `ItemID` is NOT a unique item-instance key and should not be used as a Supreme checker-ID.
- Supreme Ancients/Godlies/Chromas publisher date remains Nov6 2026 10:56 AM, past current fixed 72h source-age gate; new download is not a new publication. Stage70 `REVIEWED_RAW_TO_CHECKER` remains EMPTY, and the old heuristic price/source flags must not be trusted.

## Narrow Stage75 question

Does the **current local MM2 client** `ReplicatedStorage.Database.Sync.Weapons` contain the same public **raw catalogue keys + exact displayed names + type + rarity + Chroma variant** for 13 representative high-risk targets in Oct18 pinned third-party public metadata? Specifically 10 Halloween2026 base/Chroma variants, two `BattleAxe` casing variants, and Gingerscope control.

This is NOT another 1040-row census: the Lua script accesses ONLY `sync.Weapons[target.raw]` for 13 static known public raw keys (constant lookup), no `pairs(sync.Weapons)`, no personal `Weapons.Owned`, no player names or inventories. It may count duplicate *asset ID occurrences* among the 13, **without logging ID values**. It cannot authenticate game server settlement, future raw owned keys or numeric Supreme checker IDs.

## Exact implementation

- `pdiddler/new_part4/STAGE75_READONLY_13_KEY_CATALOG_PROBE.lua` is **one self-contained, immutable-pinnable** read-only Delta entrypoint. Its expected 13 names/keys are statically embedded from Git blob `2be54c3f5c6b715844728c01a65cc2f24a55c02d`; matching Python provenance test compares each against full exact downloaded source.
- Presents local purple/black instruction panel **during the test**, step1/step2 and final; automatically copies ONE sanitized JSON marker `[GINGERSCOPE STAGE75 CLIENT CATALOG]` using `setclipboard/toclipboard`, with ONE console fallback. Copy API success is only a copy request, NOT verified iPadOS paste. Never displays a value, reads inventory or sends gameplay remotes.
- Return per-public-key exact/partial/missing/malformed status with up-front hard false flags `currentPricesVerified`, `rawToSupremeCheckerVerified`, `authenticatedServerInventory`, `authorizesTrade`, `authorizesAccept`, `mayUseForStrategyLearning`, `maySendDiscordWebhook`, `mayReportProfit`. Missing/wrong/ambiguous field is never normalized or auto-approved. A joined/hopping/Part4 session blocks the probe.
- `pdiddler/tests/test_stage75_native_catalog_13_keys.py`: actual Lua5.4 mock Roblox game tests for all exact, missing, wrong Chroma/name, malformed, same asset IDs, source provenance, no full-game census, no trade methods, wrong game, changed session, failed require, missing clipboard, absent UI, idempotent rerun. Source test **strictly requires pinned public bytes in dedicated CI**, but can skip only when unrelated generic test runner has no public-source fixtures.
- CI `.github/workflows/gingerscope-stage75-native-catalogue.yml` pins the third-party Git blob and runs all provenance and mocked native tests; **cannot claim a native iPad pass**. No merge, no trading.

## ONE future native test after exact-head green

Original MM2 on MAIN iPad / Delta, select Tablet, fresh server, no other pdiddler scripts or trade windows. Paste **one** SHA-pinned loader generated only after CI passes. The in-game panel instructs that the probe copies public game-catalogue raw keys and metadata, **not personal inventory**. Let it complete, paste **one** `[GINGERSCOPE STAGE75 CLIENT CATALOG]` JSON into ChatGPT; if copy fails, paste that one line from the Delta console. No ALT account, manual trades, Stage54/55/57 reruns, or second screenshot unless the GUI is broken.

## After the result

Interpret as client observed **catalogue** correspondence only. `EXACT_13_PUBLIC_CATALOG_FIELDS_CLIENT_ONLY` would corroborate live client fields but does not independently authenticate Supreme site-local numeric IDs or current prices. Any partial/missing is logged as evidence, **no automatic fuzzy fallback**. Issue #122 stays open; source age policy must be handled separately. No advancing to live trading/Accept/Discord learner based on this probe.

**Never ask user to repeat their prior Stage73 diagnostic or earlier counterpart trades.**
