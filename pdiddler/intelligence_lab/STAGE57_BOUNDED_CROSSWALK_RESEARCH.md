# Stage57 — bounded independent-review crosswalk candidate evidence

## Decision after the Stage56 live result
The operator returned the Stage56 guided iPad Delta result, recorded in [PR101 discussion](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/101#issuecomment-6718509534). Of 1,040 local game-catalogue rows, 190 passed the scanner's broad eligibility filter. All 190 resolved to some legacy checker row through the current, **unauthenticated**, Stage51 string resolver. The 164 scored matches included 73 transformed-only. Stage56 showed **66 level1, 7 level2**, with 7 Chroma/66 non-Chroma; no score reproduction errors, unexplained transformations or client checker-ID collisions. The 2 `coming.png` placeholder checker artworks remain ambiguous by artwork, and one score-based match had a smaller but positive runner-up gap. These client observations **do not authenticate the external checker IDs or prices**.

Repeated aggregate diagnostics now yield diminishing returns. The next necessary input for a manually reviewed versioned identity crosswalk is **a bounded set of actual weapon catalogue records** for the highest-risk cases, paired with their currently inferred checker IDs. This will support source-backed item name/rarity/type/year comparison using external MM2 Wiki/public market displays. No webpage provides a server-attested raw `Sync.Weapons` key-to-Supreme ID crosswalk; **do not assert official validation**.

## This narrow read-only test

`pdiddler/new_part4/STAGE57_READONLY_CROSSWALK_CANDIDATES.lua` copies the already-reviewed Stage56 resolver/census and a live **local-only, dismissible purple instruction panel**. It performs no inventory profile calls, MM2 trade requests, GUI Accept, server writes, teleportation, Discord notifications, or external API calls; the only HTTP is the operator's standard GitHub `loadstring(game:HttpGet(...))` loader. All old checker numeric values are still explicitly `0`. All mapping, trade, final Accept, settlement and profit flags remain **false**.

**Important change to privacy scope:** Unlike Stages54–56's aggregate-only receipts, this test intentionally copies **selected public game-catalogue weapon keys and display names** to the operator's local clipboard for reviewed source cross-check. It does **not** inspect their owned inventory, player names/IDs, server/JobId, offers, Discord tokens, executor metadata, or full 1,040-row catalogue. This scope is explained in the runtime panel before the scan; the operator can close the panel. The code chooses only:
- all first-equality-at-level2 fuzzy candidates (7 in Stage56);
- the two generic `coming.png` checker-image cases;
- any candidate with a positive 21–99 score gap to the runner-up (1 in Stage55, potentially overlapping above).

It merges flags for identical raw-key/checker candidates and sorts deterministically by tier/key/checker ID. **At most 12** records may be exported; if there are more than 12, or any candidate field fails a strict length/ASCII content check, the script clears the candidate array and reports `CANDIDATE_EXPORT_NOT_COMPLETE` rather than silently truncating or copying partial evidence. Each selected record has only `rawKey`, `displayName`, `checkerId`, `checkerImage`, `rarity`, `weaponType`, `sourceYear`, `sourceEvent`, `sourceItemId`, `tier`, `mappingMethod` and three reason flags. These are game catalogue metadata, NOT proof of authenticity; source year can be blank.

The operator sees instructions **during Delta execution**: no trades, no alternate account, auto-read only, and paste the copied report when complete. If clipboard UI is blocked, guide text remains in Delta console.

## Evidence ledger next steps

Treat these as **candidate relationships**, not verified inventory or market prices. For each candidate, review external source display name, type, rarity, year, and variant with source URL, publication/revision date, and any ambiguity. A visually plausible image, matching listed value, or a high scorer margin alone never authenticates the raw key. Quarantine contradictions, missing years, generic artwork or insufficient publisher provenance. Separate public-source identity corroboration from *server settlement proof*; do not unblock auto final Accept or profit reports using these receipts. Do not commit raw game logs or personal inventory information to the public repo.

Tests execute the **actual Lua** via Lua 5.4 under a mock Roblox game, including bounded/invalid-data cases, GUI instructions, clipboard fallbacks and old Stage56 cases. The isolated Actions workflow also executes all inherited Python tests. Do not give the immutable loader until exact-head CI passes. Do not merge stale Stage50/51/52 stacked market snapshots over main.
