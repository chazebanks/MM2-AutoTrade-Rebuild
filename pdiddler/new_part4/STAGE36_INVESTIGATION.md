# Stage36: exact original image-reference comparison

Updated 2026-11-06 UTC. Scope: compare the original `Container.Icon.Image` string with original `Image`, `Icon`, and `Texture` strings from `Database.Sync.Weapons` and `Sync.Item`. This is an offline-reviewed client reference diagnostic, not weapon authentication or completion verification. No new iPad test is requested.

## Why the previous comparison never ran

The [native debugging brief](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/75#issuecomment-6679993429) recorded `OTHER_HTTP_IMAGE_REFERENCE`, 1,040 entries inspected for format, 137 recognized asset-ID reference occurrences and 903 unsupported occurrences, but **zero equality comparisons**. The parser treated recognizability as a prerequisite for comparison.

The actual HTTP URL and live Sync artwork were not exported. The [earlier investigation at 5124325](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/blob/512432572b8df5d16b540a3432f3fd3fbe98d649/pdiddler/new_part4/STAGE36_INVESTIGATION.md) found no real art snapshot or game rendering source in reachable repository history. Therefore HTTP aliases, redirects, transformations and rendered-image equivalence remain unknown.

Those unknowns prevent normalization, but they **do not prevent literal equality**. Lua string `==` compares the entire byte sequence. It does not require a recognized URL host, format or scheme. The new native path uses that operation alone. It does not claim that equal references render successfully, that different references render different images, or that an image identifies a weapon.

## Implementation

The existing pure `p4_stage36_icon_catalog_audit.lua` now exports:

- `collectExact(sync)`: collect every direct table-valued row of both sources, without a rarity filter or key merge. Return an internal catalogue or a fixed failure reason.
- `assessExact(input)`: validate the visible slot and supplied catalogue, then compare every nonempty original artwork string with the original slot string using `art.value == input.icon`.

`STAGE36_READONLY_ICON_CATALOG_DELTA_PROBE.lua` calls only these functions for collection/assessment. The historical normalized `assess()` remains solely for compatibility with prior offline regressions; it is not called by the native exact path. Format classification cannot short-circuit the new comparison.

No trimming, case folding, numeric extraction, zero stripping, scheme/host aliasing, query reordering, percent decoding, thumbnail resizing, filename mapping, URL fetching or redirect following occurs. Even a malformed or unrecognized reference can be compared as an opaque nonempty string. Whitespace and embedded byte differences remain differences. Bounds are 4,096 bytes per string and 5,000 source rows; exceeding a bound fails closed instead of silently truncating.

## Provenance and conflicts

Each internal row retains its source (`Weapons` or `Item`), original typed key, field labels/original nonempty string values, rarity and Chroma flag. Empty, missing and non-string artwork fields are counted separately; no non-string value is converted to an image reference. Neither original source is mutated.

There is no `tostring(key)` deduplication. For example, numeric `7` and string `"7"`, or `Weapons.same` and `Item.same`, remain separate rows. Textual-key overlap is counted, and differences in original art-field placement/values, missing/empty/non-string counts, rarity or Chroma mark a conflict. Stringification is used only to detect this overlap, never to merge rows or compare images. Counts do not certify agreement of unrelated metadata fields.

If the two source names point to the very same table, both source paths remain represented and `sourcesAliasSameTable=true` identifies the overlap. Two equal-reference rows are conservatively two matching **source rows**, not two proven weapons. Conversely, differently keyed rows with the same artwork remain distinct. Source aliases are not guessed.

Every rarity participates. A global reverse index counts references shared across source rows, including duplicates unrelated to the current slot. Repeated equal fields within one row count as multiple comparisons/matching occurrences but only one matching row. Nothing here establishes the real game's collision distribution; fixtures are synthetic.

## Sanitized report contract

Schema: `gingerscope-stage36-client-slot-icon-catalog-audit-exact-reference-v2`; `comparisonMode=BYTE_FOR_BYTE`.

| Result | Meaning |
| --- | --- |
| `NO_IDENTICAL_REFERENCE` | Every supplied nonempty string was compared; none was byte-identical. Missing art remains visible in the counters. This does not mean the weapon is absent or that different references cannot render the same image. |
| `MULTIPLE_IDENTICAL_REFERENCE_ROWS` | More than one source row contains the exact slot string. No source/key aliases are silently collapsed. |
| `SINGLE_IDENTICAL_REFERENCE_WITH_GAPS` | One matching source row, with missing/non-string artwork or conflicting stringified-key groups elsewhere in the supplied catalogue. |
| `SINGLE_IDENTICAL_REFERENCE_CLIENT_ONLY` | One matching source row, no such coverage/key conflict, and no sprite-region ambiguity. This establishes only reference equality within the supplied rows. |
| `SPRITESHEET_REFERENCE_NOT_IDENTITY` | Exact matches exist, but sprite metadata prevents a whole-icon interpretation. |
| `INCOMPLETE` | Invalid/unavailable context, catalogue, provenance, artwork shape or bounds. This is not a no-match result. |

Report counts are `catalogEntriesAudited`, `catalogueReferencesCompared`, `matchingCatalogueEntries`, `matchingReferenceOccurrences`, `matchingSourceCount`, `duplicateReferenceGroups`, `rowsSharingReferences`, `stringifiedKeyOverlapGroups`, `conflictingStringifiedKeyGroups`, `missingArtEntries`, `missingArtFields`, `emptyArtFields` and `nonStringArtFields`. Duplicate groups count references shared by at least two source rows; shared-row count is the union of their rows. Key conflicts are a separate counter, not a fabricated weapon identity.

`catalogueCoverageComplete` means every supplied source row has at least one nonempty string and no non-string artwork field. Missing optional fields do not create a gap when a row has valid string art. It does not attest full game catalogue completeness or image loading. `imageReferenceAmbiguous` remains true for no match, multiple source-row matches, sprite regions, coverage gaps or key conflicts.

Only fixed schema/status/reason strings, aggregate counts and booleans leave the assessment. No artwork URL, host, query, key, name, rarity, raw provenance table, user/partner ID, job ID or fingerprint is exported. All identity/Accept/trade/completion/profit authority flags remain false and `tradeOutcome=UNKNOWN`, including in the single-reference case.

## Behavioral verification

All fixture references and catalogue keys are synthetic, not recovered native data.

- `tests/test_stage36_exact_reference.lua`: **76 cases**, including opaque HTTP matches/no matches; unchanged bytes; case/whitespace/query/scheme/ID/thumbnail differences; every rarity; field duplicates; source conflicts; numeric/string keys; alias tables; missing/empty/non-string artwork; bounds and invalid context. Its 1,040-row fixture compares **1,146 artwork occurrences** per assessment. Each of the 1,040 row images is assessed separately to expose truncation or skipped comparisons. **1,120 reports** undergo recursive privacy/authority checks.
- Against baseline `5124325`, the initial new suite failed **75/75** because the exact path did not exist. A minimal opaque-HTTP behavior fixture also failed before implementation. Independent review identified a sparse-array validation flaw that could skip a competitor; an additional regression reproduced the false uniqueness result before the fix. The final suite passes **76/76** under real Lua 5.4.8, including rejection of that sparse catalogue before any audit counts are emitted.
- `tests/test_stage36_exact_native.lua`: **2 cases** execute the actual native launcher with a mocked game hierarchy and the real local core, one per offer side. Three source rows produce nine comparisons, two matching rows/six matching occurrences, and one source-key conflict. It asserts original-string forwarding, stable polls, sanitized JSON, no legacy-assessor call and no image/network/remote/input actions. Baseline native flow failed both tests; the new path passes both.
- Existing historical Stage36 and Stage34 suites remain in `.github/workflows/stage14-part4-tests.yml`. Python invokes both new actual Lua suites and retains native compile checks. Local final verification passed all **35 workflow Lua suites** and **306 Python tests**, including the **29-case Stage34 suite**, old **32-case Stage36 audit**, and **28-case reference-safety suite**. GitHub run URLs and exact-head conclusions are recorded in the PR description after log inspection.

The native module pin is `c2485e3422d21c04401b1551b938b24288736ddd`, containing this exact implementation. Independent offline review and local verification preceded pinning; the identified sparse-array issue was reproduced and fixed before this pin. No code is merged to production and no launcher is distributed as a device-test request. Stage34 reconciliation, automatic trading, completion verification and webhooks are unchanged.
