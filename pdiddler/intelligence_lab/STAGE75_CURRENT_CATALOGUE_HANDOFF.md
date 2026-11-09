## Verified Stage75 offline checkpoint — actual pinned source & Lua5.4; manual MAIN iPad report NEXT (2026-11-09)

**Exact code/test SHA** `74cecca70988f809e81e7dedb3b60a41cef5b973`. [GitHub Actions Stage75 run 42671136986](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42671136986) **SUCCESS** (11 named Python tests executing real Lua5.4 mock + exact Oct18 third-party source Git-blob verification). [Stage75 code-only push run 42671128439](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42671128439) also **SUCCESS**. Current live controller NOT touched.

Tests: 12 exact third-party public metadata expectations checked against pinned Oct18 `db` without executing its Lua source; Lua syntax, public game categories including Chroma Ancients and reused base/Chroma ItemIDs, 12/12 matching simulated game catalogue, missing/invalid 12th key, wrong name/type/Chroma/rarity, changed or missing item ID, wrong game, missing ReplicatedStorage or Sync, server change, clipboard API failure/unavailability, JSON failure and optional GUI disappearance; clipboard sends exactly one bounded report/console copy; all trade, price, settlement/profit and learner flags remain FALSE. Terminal in-game panel guide text was shortened to three lines to avoid the earlier Stage73 clipping mistake; tests enforce this bounded status.

**NEXT operator action ONLY, no ALT or trade:** on MAIN iPad in original MM2, fresh game server, Tablet chosen, no other pdiddler scripts, execute exactly this immutable one-line loader in Delta:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/74cecca70988f809e81e7dedb3b60a41cef5b973/pdiddler/new_part4/STAGE75_READONLY_CATALOG_TWELVE.lua"))()
```
Follow the purple in-game guide until DONE. Paste ONE auto-copied `[GINGERSCOPE STAGE75 CATALOGUE EQUALITY] {...}` into ChatGPT. If clipboard fails, use the same single console line. Screenshot is NOT requested unless GUI visibly fails. No need to repeat Stage73, Stage57 or other catalogue census; this is the first bounded 12-key current-client equality test. **Source-only evidence, even if 12/12, NEVER verifies current Supreme prices or authorizes final Accept/Discord learning.** PR144 draft/unmerged.

---

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
