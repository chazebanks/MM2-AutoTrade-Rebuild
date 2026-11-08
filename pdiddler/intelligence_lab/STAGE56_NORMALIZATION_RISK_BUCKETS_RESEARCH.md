# Stage56 — isolate normalization rules behind the 73 transformed-only mappings (RESEARCH-ONLY)

## Native trigger and boundary

User's actual iPad Delta [Stage55 native report](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/100#issuecomment-6718397284): `fuzzy=164`, `fuzzyDirectRaw=45`, `fuzzyDirectName=89`, `fuzzyBothDirect=43`. Thus exactly **91** have at least one level-0 exact source-to-frozen-checker-image text agreement and **73** are transformed-only. The cloned resolver reproduced every score (0 errors), and 163 of 164 had runner-up gaps >100. This is a measurement of a *locally computed* string-similarity score, **not proof of accurate official raw ID→Supreme ID**. Zero duplicate checker targets; two placeholder images; just five year-comparable examples.

**Next one issue**: partition the **73 transformed-only** by first successful canonicalization level and Chroma vs other, while counting token hints that could explain the normalization. Do NOT make an operator retest Stage55 or speculate that all 73 are wrong.

## Implementation and privacy

`pdiddler/new_part4/STAGE56_READONLY_NORMALIZATION_RISK_BUCKETS.lua` inherits the pinned Stage55 read-only local `ReplicatedStorage.Database.Sync.Weapons` catalogue audit and *only* adds count-only explanations. No public/secret market-price requests. Legacy 190 checker references contain ID and image filename **internally**, with numeric prices forced to zero; no item-level values or raw keys ever printed/copied.

New counters:
- `transformedCount` and `transformedChroma`/`transformedNonChroma` (exclusive).
- `transformedLevel1` / `transformedLevel2Only` (first level that provides equal normalized strings) / `transformedNoMatchingLevel` (safety anomaly).
- `transformedNearRunner`: second-best score gap at most 99, among transformed-only.
- Hints **that can overlap**: `transformedYearHint`, `transformedYearInBoth`, `transformedChromaPrefixHint`, `transformedUpdatedHint`, `transformedUpV2Hint`, `transformedTypeSuffixHint`, `transformedNoObviousTokenHint`. These count token properties, **not causal proof** or independently valid variants.

An error status `TRANSFORM_CLASSIFICATION_INCONSISTENT` is forced if the transformed-only count disagrees with Stage55's own calculation, any transformation cannot be reproduced at level 1 or level 2, or Chroma/other counts do not total the transformed count. Score-reproduction errors and ties remain fail-closed. All immutable safety / non-authority flags remain false: **no trade, outgoing request, final Accept, completed settlement, profit, or verified source price**. This is local item-catalogue metadata only; no player profiles or real inventory involved.

The anonymous report is automatically copied via Delta's `setclipboard`, `toclipboard`, and guarded `getgenv` fallbacks; the console remains available. No item names, IDs, years, owners, server identifiers, tokens, URLs, source payload, or numeric source prices leave the local script.

## Testing and interpretation

`pdiddler/intelligence_lab/test_stage56_normalization_risk_buckets.py` launches the real Stage56 Lua script in Lua 5.4 with mock game objects, inheriting Stage55's direct/runner tests, 7 clipboard/encoding failure cases and 400 deterministic synthetic observations, with 4 new named cases for Chroma abbreviation, filename `UP` suffix, type suffix needing level2, and stripped year. Separate secret-free GitHub Actions job runs it plus all inherited Python suites.

**Gate:** until exact-head CI is green, do not send a Delta command or claim a working live probe. After native counts, decide whether to advance to a versioned manually reviewed crosswalk and *settlement evidence* rather than endless generic matching probes. Do not automatically promote normalizations into an authoritative item ID and do not restore legacy +15 trading rules. Earlier PR99/100 remain unmerged research drafts stacked off latest main; Stage56 is stacked on PR100 and does not alter default branch.
