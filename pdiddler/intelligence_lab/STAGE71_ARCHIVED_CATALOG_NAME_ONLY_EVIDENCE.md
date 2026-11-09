# Stage71 — Independent archival game catalogue ↔ Supreme public-name corroboration

## What this solves (and what it does not)

Issue [#122](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/issues/122) arises because the T4.4 scanner has recognized eligible inventory but its pinned Supreme snapshot expired; numeric values are `UNVERIFIED`. Stage69 source parser [PR124](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/124) proved 190 current Supreme public names and 21 changes via pinned first-party HTML and exact-source import CI. Stage70 [PR125](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/125) identified that the old checker passes along fuzzy/alias `checkerId` under a misleading `verified-snapshot` string; its new strict gate blocks such mappings and passed 8 actual Lua5.4 source tests, 400 adversarial mutations, 40 inherited source tests, and dedicated duplicate reviewed-ID/aggregate overflow cases. These gates are **research-only DRAFTS**; outgoing trading remains paused.

**Key insight:** The numeric Supreme checker IDs in our historical market snapshot are source-specific/legacy value-database identifiers, not native MM2 raw weapon IDs. New first-party Supreme HTML includes category-specific item display names and unique source links, **not** the historical checker numbers such as `Gingerscope: ancient:771`. Requiring MM2 game-server to authenticate a site's arbitrary numeric checker ID directly is the wrong proof objective. We can independently corroborate a **public game raw key → public item name/category/variant ↔ Supreme canonical item name** with explicit limited provenance, while leaving the numeric checker ID as a separately verified local price-record lookup and keeping automatic trade authorization closed.

## Exactly one independent external catalogue source

Pinned public archived MM2 client code (NOT a current MM2 backend):
- <https://github.com/tlredz/decompiledGames/blob/0552a0f3502217a1cf89df66be9bd0f153e47fa4/murder-mystery-2/v1456/ReplicatedStorage/Database/Sync/Item.lua>
- Git blob **`b0661d54893f681777ebd3eae50d0a4ebe9a46e3`**, ~241KB.
- The archive includes `Gingerscope` as a Gun/Ancient, a distinct `CandleflameChroma` knife with `Chroma=true`, and `TreeGun2023Chroma` as a Chroma Evergun gun. These game-raw keys are *not* numeric Supreme checker IDs.
- Other MM2 2026 items such as `Emberbow`, `Emberscythe`, `Mortal`, `Immortal` do **not** appear in this old v1456 catalogue, so their identity is unresolved by this source. This stage cannot magically price new-event items.

Frozen Supreme snapshot for **historical correspondence**, not current quoting:
- `pdiddler/snapshots/supreme_snapshot_2026_11_04.json` pinned Git blob **`955e3fb7cd25999fc4f0aad4a77378b9a7bb9ba3`**, 190 rows; each has `page`, `sourceName`, `id` (market-local checker index), value/demand/stability (all may be stale).
- The current first-party site publishes names and source-specific pages, but is not an MM2 game-server attestation.

## Proof class and implementation

`scripts/stage71_archived_catalog_source_name_bridge.py` reads BOTH full pinned source bytes and rejects mismatched Git blob hashes. It extracts the six specific direct Lua catalogue entries and checks `ItemName`, `ItemType`, `Rarity`, `Chroma`, `ItemID` with strict expected forms. Then it resolves to `(page, publicSourceName)` rather than numeric checker ID. For Chroma variants it forms `("chroma", "Chroma " + ItemName)` and requires exact source-name match to that Supreme category; this prevents `Candleflame`/Chroma Candleflame and Evergun/Chroma Evergun from collapsing into one site record.

Six literal pinned historical examples:
- Gingerscope (Ancient, gun) → source name Gingerscope
- Candleflame (Godly knife) → source name Candleflame
- CandleflameChroma (Chroma knife) → Chroma Candleflame
- TreeGun2023 (Godly gun) → Evergun
- TreeGun2023Chroma (Chroma gun) → Chroma Evergun
- Darkshot (Godly gun) → Darkshot

Both archived raw game keys and all item names here come from pinned **public** source code, not a user inventory leak. Results do not echo user inventory or map `ItemID` to Supreme `id`.

Positive ONLY `ARCHIVED_CATALOG_SOURCE_NAME_MATCH_ONLY`, with `historicalPublicNameMatches=6`, `unsupportedModernItems=4`; it never declares an authenticated game item-to-numeric-market-ID relation. In ALL outputs, `currentGameCatalogAuthenticated=false`, `sourceNameMatchIsRawCheckerIdAuthentication=false`, `numericSupremeCheckerIdProvenByGame=false`, `mayMarkWeaponValueVerified=false`, `mayProvideIndicativeResearchOnly=false`, `mayUseForStrategyLearning=false`, `mayReportProfit=false`, `authorizesTrade=false`, `authorizesAccept=false`.

## What is required before any real UI pricing

1. **Current** raw `Sync.Item/Sync.Weapons` catalogue provenance needs verified scope/epoch, not merely a historical v1456 GitHub archive. User's Stage66 in-game raw-key equality proves client consistency for one transfer, but doesn't independently verify whole current catalogue or Supreme checker mapping.
2. The Supreme current page should be a reviewed, versioned canonical source name rather than a hard-coded market checker ID derived from fuzzy aliases. Preserve variant, page, rarity and type. Numeric ID is an internal lookup key only, never the proof.
3. Ambiguous display names, duplicate keys, Chroma/base collisions and incomplete 2026 event catalogue must fail closed. A lower-confidence, **historical reference** column could be displayed with a clear `INDICATIVE/NOT VERIFIED` label in the future; never feed it to planner, automatic final Accept or Discord completed/rejected learning. This Stage71 script does not change the UI.
4. Current publisher timestamp from Stage69 HTML was Nov6 10:56:07 EST, so 72h publication freshness expires Nov9 10:56:07 EST; a new fetch cannot reset it, and old prices must not be marked current.

**No new user Delta action necessary.** CI downloads and Git-blob-verifies the full archived game source, runs actual Python against it and the pinned 190-row source, then negative source-corruption/variant checks and inherited actual Lua5.4 source identity tests. A successful check is only a **name-level archival corroboration**, not a completed production price fix.
