# Stage78 — strict owned raw-key ↔ current catalogue exact lookup research

**November 9, 2026. Issue #122. Isolated DRAFT research; no production scanner, P4, bot avoider, pricing, Discord or offer changes.**

## The resolved design question

The actual pinned main scanner file `pdiddler/pdiddler3_scanner_MODULE_v6.lua` contains:
- `indexItems(Sync.Weapons)`, and `indexItems(Sync.Item)` when tables differ;
- for every client profile `prof.Weapons.Owned` pair, `local id=tostring(rawId)`;
- direct `Meta["Weapons|"..id]` lookup to obtain name, rarity, type and Chroma metadata;
- **only after that**, a separate `checkerMarket(meta)` which uses historic fuzzy/alias market checker IDs and stale cached price values.

Therefore the game-catalogue metadata lookup itself is direct string-based and does not require a Supreme numeric checker-ID to display a weapon's class/name. The old market mapping remains **unverified** independently, as Stage70 established. Stage53 previously observed `Sync.Weapons==Sync.Item` in its tested client session, so do **not** revive the speculative double-table overwrite as a demonstrated bug.

### One concrete weak boundary

The legacy scanner's `tostring(rawId)` can collapse a numeric `[42]` and string `["42"]` into the same text `"42"`. This is an **offline reproducible source-level type confusion**, not evidence that actual MM2 profiles presently contain numeric raw weapon keys or that a user's item was misidentified.

The Stage66 user's iPad client-only one-row callback string exactly matched an increased `Weapons.Owned` raw string in a single observed window. That established a **client-side** raw receipt/owned equality only. It does NOT say which of Stage75's 13 probed catalogue keys the privately held raw item was, and does not authenticate transaction, item instance, publisher, or server. Don't request the Stage66 ALT trade again.

## New research-only strict guard

`pdiddler/intelligence_lab/stage78_strict_owned_raw_catalogue_join.lua` is a **pure, offline Lua5.4** function `evaluate(owned,catalogue)`; it has NO Roblox service calls and is never loaded into the live scanner. It:
- requires each owned raw key to be an actual Lua **string**, never coercing via `tostring`;
- counts positive integer copies with upper bounds, rejects zero/float/numeric string/nonfinite quantities rather than inventing counts;
- uses only `rawget(catalogue,rawKey)` for exact catalogue identity, requiring valid `ItemName`, `ItemType`, `Rarity`, `Chroma` fields;
- accepts Godly and Ancient base/Chroma classifications without forcing Chromas to Godly; excludes unrelated rarities from eligible counts;
- rejects absent raw keys, metatables, malformed Chroma, unknown weapon types, unsupported raw-key types and copy-count overflow;
- never exports raw key strings, account IDs, inventory fingerprints, art `ItemID`, price or market checker identifiers.

**Research output `CALLER_CLIENT_RAW_TO_CATALOGUE_EXACT_LOOKUP_ONLY` is deliberately NOT authenticity proof**, because input tables are supplied by a caller and the function is never run against a real server. All outputs preserve sourceFresh, currentPricesVerified, numericSupremeCheckerIdVerified, authenticatedOwnedInventory, trade/Accept/profit/Discord/market-learning/settlement false.

## Tests and provenance

- Original scanner text is fetched from immutable main commit `18bc3de067d02a8a043b165f813e5804f8ad4bfc` and SHA-verified to **Git blob `65137e7e6966784cdb3c6bb3f6cd5adf885a68ba`** in dedicated CI.
- `pdiddler/tests/test_stage78_pinned_legacy_raw_join.py` extracts the ACTUAL original `inventoryFromProfile` function (no hand-rewritten clone), translates only five Luau `out.field+=` statements into Lua5.4 equivalent assignments, and runs both `{["42"]=1,[42]=1}` and normal direct-owned string cases in actual Lua5.4. The expected `"42"` duplicate type-erasure behavior is a **synthetic reproduction** only.
- `pdiddler/tests/test_stage78_owned_raw_catalogue_join.lua` executes the new pure guard under real Lua5.4, including base+Ancient Chroma positive tests, direct lookup, numeric/string collision rejection, 400 deterministic corrupted cases, spoofed authority flags, quantity cases, unknown keys, metatables, and no raw key output.
- Dedicated workflow `.github/workflows/gingerscope-stage78-owned-catalogue-join.yml` requires actual Lua5.4 and the original code pin. It cannot silently skip the original-source fixture or treat a source mutation as evidence. Green CI means the **source-level regression** and new strict guard function worked offline, not that real MM2 Owned keys were observed in a new session.

## Next boundary

Do not turn this research code into a live profiler or prices merely because offline tests pass. Existing Stage53/66/75 evidence cannot automatically be composited into one verified game/owned market mapping: those observations came from different sessions and did not expose the private gained weapon key. The next incremental step should assess whether existing **non-sensitive native Stage66/Stage57 evidence** can establish a narrow item-specific join without requesting repeat manual transfers, or whether one truly new read-only targeted observation would be necessary. Resolve source publication age separately (Nov6 values >72h on Nov9).

**All automatic offers, final Accept, settlement claims, updated portfolio values, Discord learner and actual trade permissions remain OFF/UNVERIFIED.**
