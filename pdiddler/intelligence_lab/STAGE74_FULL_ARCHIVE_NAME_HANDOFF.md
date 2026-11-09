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
