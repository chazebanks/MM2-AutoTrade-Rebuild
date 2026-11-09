# Stage75 — scoped MAIN-iPad live catalogue equality check (read-only)

Date: 2026-11-09. Status: **OFFLINE CI AND NATIVE CHECK PENDING** (do not call this a pass until exact-head checks).

## Grounded reason, without repeating completed tests

Stage73 purple scanner has already passed actual MAIN-iPad read-only visual check; no further Stage73 JSON/screenshot, trading, ALT or manual transfers. Stage54–58 previously observed 1,040 client-local game catalogue rows, 190 eligible items, 164 fuzzy/19 alias/7 internal resolver mappings, and ten specific naming hazards; **do not rerun a full census**.

Stage74 research-only DRAFT [PR142](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/142) independently pinned two public metadata sources (Oct5 995-row 178/190 historical names, Oct18 1040-row 188/190 names), with 14 pinned-source tests and all other CI green. Oct18 source is **THIRD-PARTY**, not official MM2/Roblox server attestation; only two absent strict labels are source `Battleaxe` vs game `BattleAxe`, `Battleaxe II` vs `BattleAxe II`. Game base/Chroma IDs are sometimes identical even when variants differ; never treat `ItemID` as a unique weapon identity.

## Exact small follow-up

The isolated `pdiddler/new_part4/STAGE75_READONLY_CATALOG_TWELVE.lua` tests exactly 12 public raw-game `Sync.Weapons` metadata rows, NOT a new 1,040-record price/inventory crawl:
- Modern: base and Chroma versions of Emberbow, Emberscythe, Mortal, Immortal, Embersickle (10 entries), including Ancient+Chroma cases.
- Historical orthography: `BattleAxe` (2017) and `BattleAxe2` (BattleAxe II, 2018).
- Exact `raw catalogue key, ItemName, ItemType, Rarity, Chroma flag, Year, Event, public ItemID` comparisons to source-pinned **public** Oct18 `mm2scripthub/mm2 db` (commit `0f2715187e7eae36eea4bd97afee809478fc877d`, Git blob `2be54c3f5c6b715844728c01a65cc2f24a55c02d`). `ItemID` comparison describes metadata only; shared Chroma/base `ItemID` does NOT prove a unique game weapon.
- In-game purple guide panel appears during execution (unless UI primitives unavailable), with step 1/2 and 2/2 progress and terminal instructions. The script automatically tries clipboard once and prints one complete, bounded anonymized JSON report to Delta console as fallback; a copy request is not OS paste proof. No user names, private raw owned items, player inventory, trade GUI, remotes, webhooks or purchases.
- Output only per-target case labels `T01` … `T12` and status codes/counts. No actual public raw keys, images, numeric asset IDs or any user inventory exposed in copied report.
- Reads only replicated read-only game Sync metadata via the same source access previously used in Stage57, checks MM2 PlaceId and JobId. Does not alter game state.
- Regardless of match count: `currentGameCatalogAuthenticated=false`, `sourceFresh=false`, `serverAttestation=false`, `rawGameToSupremeCheckerApproved=false`, `authorizesTrade=false`, `authorizesAccept=false`, no settled trades/profit/Discord learning. Do NOT populate Stage70 source-verified mappings or update Supreme value labels from Stage75.

## Test plan

The dedicated workflow must independently download and blob-hash-verify the exact Oct18 public source **as DATA only**, never run untrusted Lua. Python verifies that the 12 hardcoded Lua expectations correspond exactly to pinned published fields, then uses real Lua5.4 to run the Stage75 script against synthetic game/Sync tables. Adversarial cases: missing keys, Ancient Chroma flag/rarity corruption, altered names, bad/shared asset metadata, wrong place, missing game services, changed server, encoder failure, GUI absent and clipboard API missing/throwing. It must guarantee one single console report, no unsupported authority, and no player inventory access. Generic replay discovery without pinned external source should skip ONLY fixture-dependent tests; dedicated workflow requires fixtures.

## NEXT manual step ONLY AFTER exact-head CI green

On MAIN iPad/Delta, fresh original MM2 session with no other pdiddler scripts and Tablet selection, run the one immutable SHA-pinned `STAGE75_READONLY_CATALOG_TWELVE.lua` loader which must be supplied AFTER offline green (do not guess SHA). The in-game guide will run automatically, copy one JSON; user pastes that ONE report (or console fallback). No screenshot required unless a new GUI problem. No ALT, trade or Accept.

This can establish **local client catalogue metadata equality for those twelve keys only**; it never authenticates current game server ownership, Supreme numeric checker IDs or publisher clock. Supreme still shows Nov6 10:56 AM as latest public publication, outside the current 72h price freshness rule as of Nov9. Trading remains paused.

No other manual work is requested before exact CI.
