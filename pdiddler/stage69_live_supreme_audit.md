# Stage69 — audit CURRENT Supreme value sources, no live repricing or trading

The direct-fetch and manifest-import entry points both emit research JSON.
A matched publisher row leaves the raw game identity and trade-price flags
false. The preflight validates JSON and exercises the archived Lua profile
in its existing consumer regression.

**Priority**: screenshot of T4.4 GUI clearly shows recognized eligible items yet item prices and totals `UNVERIFIED`. The presentation deliberately invokes `profile.isFresh()`; the pinned Nov6 Supreme snapshot expired Nov7 00:47:22 UTC. The Stage52 merged MM2Values feed is a distinct, research-only data source and must not be substituted for Supreme. [Issue #122](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/issues/122).

## First-party audit, Nov 8 2026 Eastern

Live first-party HTML independently requested from all three `supremevalues.com/mm2/{ancients,godlies,chromas}` pages, with cache bypass for inspection:

- The pages all expose **`data-updated-iso="2026-11-06T10:56:07-05:00"`** (publisher update, equivalent to **2026-11-06T15:56:07Z**). That differs from the checked Nov4 snapshot's true publisher date of 2026-11-04T17:27:12Z. **Neither date is the time of a later source fetch.**
- Ancients have 16 visible canonical `itemcolumn` rows; all 16 matched old canonical names. Direct changes detected: `Traveler's Axe` **7300→7100**, `Emberbow` **400→525**, `Emberscythe` **400→500**. Gingerscope remains 16000. Source-level demand/stability sample appears present.
- Godlies page has **130** `itemcolumn` markup blocks, but **two** are known hidden source rows `Batwing` and `Black Luger`. Excluding those produces **128 canonical Godlies**. Eleven of the existing Godly price/demand entries visibly differ, e.g. `Traveler's Gun` 5200→5100 and `Embersickle` 95→130; these need structured-parser confirmation before any publication.
- Chromas page contains **53** markup blocks: **46 canonical weapon rows** and **7 Chroma Fire pets** under the pets section. Pet items are not priced as eligible weapons. Preliminary name matching indicates all 46 old canonical weapon names still occur, with several changed prices including `Chroma Emberscythe` **11000→16000**. Some quick textual heuristics mishandle pet section boundaries; **do not rely on this manual count as production parser approval**.

These counts are a first-pass independent source check, not authentication of MM2 `Weapons.Owned` raw keys to Supreme checker IDs. Our old scanner's aliases and fuzzy checker mappings remain provisional.

## Important source-age point

The existing `pdiddler/refresh_supreme_snapshot.py` source policy uses the lesser of:
- source HTML observation time **+24 hours**; and
- publisher's last update **+72 hours**.

A source still showing Nov6 10:56 AM Eastern thus expires for trading authority at or before **Nov9 10:56:07 AM Eastern**, even if a fresh fetch succeeds today. The 72-hour publisher TTL may be too restrictive if Supreme publishes infrequently, but blindly relaxing it would have silently reused wrong Emberbow/Traveler Axe prices in the old snapshot. Research a more defensible stale-market risk policy separately; a publisher timestamp must never be relabeled to scraper observation time.

## Implemented step: run existing original parser against CURRENT live pages, research only

New isolated workflow `.github/workflows/gingerscope-stage69-live-supreme-audit.yml` invokes the **actual** proven Stage25–26 source parser and frozen 190-item canonical map, fetches all three first-party HTML pages in GitHub Actions, runs existing parser/mapping/epoch tests, creates a dated candidate under `/tmp/stage69`, runs full 190-item before/after diff, and uploads seven-day **NOT FOR TRADING** artifacts. Fails on source parse drift, unknown source names, missing hidden/pet filtering, original 190-item coverage mismatch, absent publisher timestamp, future dates or original fixed freshness policy.

No writes to `main`, `values/mm2values.lua`, the live scanner, production Supreme profile, inventory valuation, Discord learner or outgoing trading. CI run results are independent and still need verification. No declaration that the first-party fetched pages necessarily pass the old parser until CI actually confirms it.

## Acceptance boundaries and next issue

Once all 190 current source rows and diffs are independently tested, decide policy for publisher age and whether any raw `Weapons.Owned`→`checkerId` aliases can be considered verified. Do NOT turn existing old T4.4 price labels green by changing only a version string, expiry timestamp, or `verified=true`. A fresh first-party price is **not** automatically an authenticated item-variant mapping.

All prior Stage66 real in-memory own raw-key match and Stage67/68 offline replay work remains valid but does not establish Supreme-specific checker mapping. All production actions, auto final Accept, actual completed/rejected Discord learning and profit reporting remain disabled.
