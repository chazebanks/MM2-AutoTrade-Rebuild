## LATEST STAGE74: Oct18 third-party 1040-catalogue source and Chroma Ancient correction — CI VERIFIED (2026-11-09)

After Oct5 995-row archive (178/190 exact names, 12 absent) offline success, GitHub code search discovered independently posted `mm2scripthub/mm2` `db` at commit `0f2715187e7eae36eea4bd97afee809478fc877d` (2026-10-18), Git blob `2be54c3f5c6b715844728c01a65cc2f24a55c02d`. Its public `db2` is **THE SAME blob SHA, NOT a second independent source**. It contains **1,040 game-source table entries**, coincidentally matching the **1,040 client-catalogue rows already actually observed at native Stage54–57**. This is source-count corroboration, NOT verified producer identity.

**Reproducible exact Git-blob-pinned comparison:** 200 eligible catalogue weapon records, **188/190 strict unique Supreme (page, exact public name, Chroma marker) correspondences**, **0 duplicate-target names**; categories **Ancient 16, Godly 126, Chroma 46**. Ten of Stage74's twelve older-archive gaps are accounted for with explicit newer public names: Emberbow, Emberscythe, Mortal, Immortal, Embersickle and their five corresponding Chroma variants. **The only two missing exact names** are `Battleaxe` and `Battleaxe II`: newer public game metadata has `BattleAxe` and `BattleAxe II`. Do NOT silently alias/case-fold them into approved price records.

**Actual parser bug found and corrected by CI:** newer source marks `EmberbowChroma` and `EmberscytheChroma` as `Rarity='Ancient'` and `Chroma=true`. Prior Stage71 six-item archived check assumed all Chromas are Godly; this assumption cannot be generalized to Halloween 2026 Chroma Ancients. New parser accepts a Chroma flag on **Ancient OR Godly**, with separate page/variant, never treating a Chroma as its base item. The third-party source also reuses `Emberscythe`'s `ItemID` for `EmberscytheChroma`; item-art/native `ItemID` is NOT a unique weapon identity or independent Supreme checker number. Tests explicitly assert these cases.

**EXACT CODE HEAD:** `ec836274b56b1995bbf1f0d972b54f52051dd7fd`, [Stage74 Actions #42668864449](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42668864449) **SUCCESS**, also [#42668858094](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42668858094) **SUCCESS**. Real Python **14/14 unit tests, total 440 seeded corrupt original bytes** across older+newer files; CLI executed BOTH source comparisons and printed expected 178 and 188, all authority flags FALSE. Earlier CI found a genuine malformed parser insertion from JavaScript replacement and an overly restrictive old Chroma Godly-only assumption; both fixed and regression-tested. The GitHub PR remains **DRAFT/UNMERGED**, no production code touched.

**Trust boundaries:** newer Oct18 public `db` is THIRD-PARTY, not official live Roblox server provenance. No per-user inventory was read, no raw item key/asset ID/site-local checker ID surfaced in report, no current prices, no net value or strategy-learning/Discord; current game raw keys ↔ canonical game metadata and source freshness still require independent verification. Supreme public issuer clock Nov6 10:56 AM is beyond existing 72h limit. Stage73 native UI already passed and must not be rerun.

**NEXT distinct question:** obtain **one** read-only strict equality observation on the present live `ReplicatedStorage.Database.Sync.Weapons` in MAIN iPad against a **verified provenance-only 190-name historical list**; do not repeat Stage54–58 fuzzy/census scripts. Until that is tested, the 188 public third-party row similarities do NOT establish live-game identity. Use in-game guided UI and automatic clipboard as required by owner, without inventory/trading reads. If CI proves a new targeted probe is necessary, ask only ONE new native test. No price authority.

---

# Stage74 — comprehensive historical public name coverage (NOT trading authority)

Date: 2026-11-09, after Stage73 native MAIN-iPad display pass.
Status: **RESEARCH-ONLY**, new clean branch off `main`; no Lua/Delta/trading, prices, player inventories, Discord or stage74 native test.
Scope: one question—how many of the 190 historical Supreme `(page,sourceName)` labels can be located **uniquely** in a separately published *archived game catalogue* without reusing the project's fuzzy `checkerResolve`?

## Why this is a real incremental step

Stage54/55 client evidence was **already collected**: 1,040 current client catalogue rows, 190 eligible, 164 fuzzy, 19 aliases, 7 internal. Stage57 inspected ten difficult cases and Stage58 corroborated their public display metadata; Stage71 compared **six hand-selected** archived game keys against Supreme names. **Do not request another Stage54/55/57 census.**

This Stage74 test expands Stage71's six examples to *all 190* published Supreme historical rows with a strict `page + exact case-sensitive sourceName + variant` join. It does not use an internally derived checker ID, asset-art equivalence, fuzzy aliases, player's inventory, or a game remote.

**Immutable public source inputs:**
- October 5, 2026, public archived MM2 `tlredz/decompiledGames v1456 ReplicatedStorage/Database/Sync/Item.lua`: exact pinned Git blob `b0661d54893f681777ebd3eae50d0a4ebe9a46e3`. It contains 995 top-level table entries (not the later native 1,040 observed in Stage54; that's a DIFFERENT DATE/SOURCE).
- November 4 Supreme historical 190-row canonical snapshot `pdiddler/snapshots/supreme_snapshot_2026_11_04.json` from archived Stage71 branch: exact Git blob `955e3fb7cd25999fc4f0aad4a77378b9a7bb9ba3`. Website-source numeric IDs are internal indices, NOT game `ItemID` or raw owned keys.
- Provenance is raw bytes pinned to public Git objects. This is **not** an authenticated present-day MM2 server snapshot or fresh market price.

## Preliminary full-archive source comparison (must be confirmed by exact CI)

- 995 top-level archived game entries, 190 eligible archived Ancient/Godly/Chroma knife/gun entries.
- **178 / 190 unique exact historical public (page, name) correspondences** (14 Ancient, 123 Godly, 41 Chroma); **0 source-name collisions** under strict category+variant matching.
- **12 / 190 canonical historical names absent in the Oct5 archive**: Ancient `Emberbow`, `Emberscythe`; Chroma `Chroma Emberscythe`, `Chroma Emberbow`, `Chroma Mortal`, `Chroma Immortal`, `Chroma Embersickle`; Godly `Mortal`, `Immortal`, `Embersickle`, `Battleaxe II`, `Battleaxe`.
- These missing rows may reflect later releases, alternate historical names or archive coverage—not proof that items are unavailable in the live game. Do NOT fill them using fuzzy guesses. For example `Gingermint_K` is the Cookiecane knife, NOT the distinct Gingermint gun.
- Passing exact names are only public-source **candidates**. Do not populate Stage70's `REVIEWED_RAW_TO_CHECKER` from this set: a public name is not a proven current-game ownership key, and a source numeric checker index is not a native game ID.

## Independent market clock verification (not a new live quote)

On Nov9, exact three first-party Supreme categories Ancients/Godlies/Chromas still displayed **`Values Last Updated - November 6th, 2026 at 10:56 AM`**, individually checked by uncached page fetches. That publisher timestamp is more than **72h old after Nov9 10:56 AM EST**, so the existing fixed publisher-age gate correctly blocks pricing. *New retrieval* on Nov9 does NOT turn a Nov6 publisher update into a new issuance. Historical Stage74 correspondence does NOT authorize an age exception, live reprice, trading, price totals or player profiles.

## Integrity and safety tests

`scripts/stage74_full_archive_name_coverage.py` consumes exact byte-pinned archive inputs. It:
- checks both full Git blob IDs before parsing; rejects altered/missing/truncated inputs;
- reads literal top-level Lua catalogue direct fields only, rejects ambiguous/direct duplicate fields, unexpected source row counts, non-weapon types, chroma/category conflicts, invalid item IDs;
- partitions every distinct Supreme canonical label into exact unique match, multi-candidate collision, or missing; never treats ambiguity as success;
- only emits public source-name labels of absent historical rows (no private raw `Weapons.Owned`, no user IDs, no source numeric checker IDs, no inventory/counterparty data);
- fixes ALL trade, Accept, completion, profit, rejected-trade, Discord learning and current-price flags FALSE regardless of input;
- runs 240 seeded byte corruptions in CI plus source integrity, chroma/base, malformed metadata tests.

## Next step (after exact green CI)

1. Freeze this quantitative historical corroboration as evidence, **not** a new current market map. No further scanner cosmetic changes or Stage73 rerun.
2. Separately address two independent blockers on issue #122: (a) current game-catalogue provenance/unique raw-to-current-public-name for newer items, ideally with direct game/client source rather than a new fuzzy aggregate, and (b) a clearly reviewed publisher-update-age policy, without `expiresAt` laundering. Current Supreme Nov6 issuance has aged out.
3. Only when each has separately passed do we consider research-quality live quote calculations; final P4 Accept, server settlement and learner are other workstreams and stay disabled.

**No manual action for the user in this Stage74 offline phase.**
