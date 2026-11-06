# Stage36 icon-reference investigation

Date: 2026-11-06 UTC. Native result remains **INCOMPLETE**; actual HTTP structure and exact weapon identity remain **INCONCLUSIVE**. This report documents source findings and bounded offline comparator corrections. It does not introduce a loader or request another iPad test.

## Evidence and scope

The starting evidence is the [active handoff on main](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/blob/main/pdiddler/GINGERSCOPE_ACTIVE_HANDOFF.md), its [strategy/research companion](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/blob/main/pdiddler/GINGERSCOPE_STRATEGY_AND_RESEARCH_PLAYBOOK.md), and the [latest read PR #75 Codex brief](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/75#issuecomment-6679993429). The tested native source is commit `46a0ab0c6df6516f18e8079a54c0734d36240f06`; its launcher fetches pure module commit `30eb8498f82fd6a79f2f0fbbfc282e59b97c7bdd`.

The supplied native report observed `YourOffer` slot 1, `usesSpriteSheet=false`, `iconReferenceFormat=OTHER_HTTP_IMAGE_REFERENCE`, and `slotIconReferenceComparable=false`. It inspected 1,040 collected catalogue entries for reference format, reporting 137 asset-ID references and 903 unsupported references. `catalogEntriesAudited=0` and `matchingCatalogueEntries=0` mean there was no eligible slot-to-catalogue comparison. They do not mean the catalogue contained no matching icon, or that 903 weapons failed to match. Stage35's earlier `TheirOffer` observation is a different session and cannot establish the identity of this Stage36 offer.

The repository was not shallow. The investigation searched the working tree and all locally reachable history: **950 commits, 1,291 unique blobs, 26,720,917 blob bytes**. Searches included Sync readers, image assignments, art URI literals, catalogues, snapshots, and file history. This is the scope of this repository search, not an exhaustive search of the internet, unreachable Git objects, the live Roblox client, or private upstream game source.

No real MM2 `Database.Sync` snapshot, native weapon-image renderer, real native weapon-art URL literal, or documented asset alias map was found. Art URI examples in the repository are synthetic test data or parser patterns. Supreme snapshots are market/checker data, not a live Sync art catalogue; for example, [the market snapshot](../intelligence_lab/supreme_snapshot_2026_11_04.json) identifies its format and publisher sources separately. A test name referring to an "actual Stage36 native unreadable URI case" does not turn its fabricated `rbxthumb://type=User...` input into an observed URI.

## Root cause and unresolved structure

The immediate failure is supported by source: the slot's HTTP reference does not belong to a comparison family accepted by the tested parser. The original [parser at the native-tested head](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/blob/46a0ab0c6df6516f18e8079a54c0734d36240f06/pdiddler/new_part4/p4_stage36_icon_catalog_audit.lua#L18-L68) accepts one exact web asset URL shape, then returns `OTHER_HTTP_IMAGE_REFERENCE` for remaining HTTP(S) references outside the recognized `www.roblox.com/asset/` prefix. The anonymized result contains no actual host, path, query keys, or query values. A CDN, alternative Roblox endpoint, redirect, thumbnail URL, or external host is a hypothesis until observed.

[Roblox's asset URI documentation](https://create.roblox.com/docs/projects/assets) describes content-reference families, including asset IDs, thumbnails and project resources. Those semantics do not specify which reference MM2 assigned to this GUI, establish that two asset IDs resolve to identical images, or prove a URL transformation performed by MM2. An image-content reference is not a raw weapon key or transaction identity.

The source also exposed independent comparator correctness problems: lowercasing the entire reference could merge case-distinct filenames/paths/query values; dropping thumbnail width and height could merge different rendered references; and an entry with some recognized art could conceal additional unsupported art when evaluating coverage. These are bounded offline correctness issues. Correcting them does **not** make the observed HTTP reference comparable.

## Catalogue collection and identity limits

The [native collector at the tested head](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/blob/46a0ab0c6df6516f18e8079a54c0734d36240f06/pdiddler/new_part4/STAGE36_READONLY_ICON_CATALOG_DELTA_PROBE.lua#L114-L159) requires the live `ReplicatedStorage.Database.Sync` module. It iterates direct table-valued rows of `sync.Weapons` and, if that table is a distinct object, `sync.Item`. There is no rarity filter, so this does not deliberately omit Common, Uncommon, Rare, Legendary, Vintage, Unique, Ancient, Godly or Chroma rows. However, absence of a filter is not proof that all rarity data exists in these two tables or has the assumed flat shape.

The actual `Weapons`/`Item` relationship is unknown. The collector tests table pointer equality and merges rows under `tostring(key)`; it does not prove that equal keys from different sources describe the same item. Conflicting same-key records lose source provenance. Numeric key `1` and string key `"1"` collapse. Distinct-key aliases remain distinct candidates. Nested tables, non-weapon rows, an Item-only catalogue, and differently typed art representations are not characterized by the current native output.

Only nonempty string-valued `Image`, `Icon` and `Texture` fields are retained. Their semantic roles are not established: a texture need not be the GUI icon. Missing, empty and non-string fields disappear before the pure comparator sees them. The format histogram counts candidate strings, not entries; unsupported combines every rejected family. The equality of `137 + 903` and 1,040 does not establish one reference per entry, zero missing art, or 903 HTTP references. Multiple fields or source duplicates can increase the reference count while other entries have no retained reference.

The [existing scanner](../presentation/pdiddler3_scanner_MODULE_v6_10_CURRENT_PRESENTATION.lua) reads live Sync at lines 628–657 and incorporates `d.Image or d.Icon or d.Texture` into a metadata signature at lines 668–681. Its `assetKey` extracts a numeric substring or normalized text; it is not a verified image renderer or asset-equivalence map and must not be copied as an icon identity rule.

Consequently, actual cross-rarity collisions, aliases, conflicting source keys, complete missing-art coverage and raw-to-rendered equivalence remain unknown. Synthetic fixtures can demonstrate how the comparator handles such conditions; they cannot establish which conditions occur in the game.

## Comparison rules and evidence gaps

| Boundary | Allowed rule or current conclusion |
| --- | --- |
| HTTP URL / query variants | Retain the existing bounded documented asset-ID shape. The native `OTHER_HTTP_IMAGE_REFERENCE` remains unsupported. No guessed hosts, arbitrary numeric extraction, query dropping or query reordering. Actual host/path/query structure is unknown. |
| Asset aliases / redirects | Equal recognized asset IDs can share their existing asset-reference key. Different IDs or URLs require independently verified mapping. No alias, redirect chain, or same-content conclusion is established here. |
| Thumbnail versus raw asset | Keep thumbnail and raw asset families separate even when their IDs contain equal digits. A thumbnail is not proof of a weapon key. |
| Thumbnail dimensions | Preserve width and height in the thumbnail comparison key. Equal asset IDs with different dimensions must not be silently treated as equal rendered references. |
| Case | Case-insensitive syntax recognition must not lowercase filenames, resource paths or query values used for comparison. Preserve their bytes. No MM2-specific case equivalence is known. |
| Resource paths | Compare only the bounded recognized family and preserved path. Do not conflate `rbxasset`, `rbxgameasset`, different paths, percent-encoding variants or project-local names. |
| CDN / transformed images | A CDN URL, hash, resized image or image with identical appearance has no established relationship to a Sync field. Do not add a host parser or fetch/resolve it speculatively. |
| Filename | Compare only preserved identical filenames within that family. A checker-site filename is not automatically a native image URL or asset ID. |
| Missing / unsupported art | An entry with no comparable art, or with additional unsupported candidate art, leaves a coverage gap. One recognized field must not conceal an unsupported field that might collide. Native empty/non-string omissions remain a separate measurement gap. |
| Duplicate refs / keys / rarities | Repeated equal art on one candidate counts once for that candidate. Matches across distinct keys remain ambiguous; a source/key alias or same-key conflict needs provenance before deduplication. Actual all-rarity collision counts are not available. |

## Bounded changes and deliberate native hold

The accompanying local work is limited to byte-preserving comparison for case-sensitive portions, preserving thumbnail dimensions, and reporting mixed recognized/unsupported art as incomplete coverage. A synthetic regression reproduces the published aggregate shape: 1,040 entries, 137 recognized asset-ID candidates, 903 unsupported candidates, unsupported HTTP slot, and zero audited entries. The data in that test is invented; it is neither a recovered Sync snapshot nor the actual host/path.

The native launcher and its immutable pure-module pin are deliberately unchanged. Therefore that existing launcher still fetches the **old pinned core**, not these corrected working-tree comparator semantics. No new pinned loader is supplied, and no claim is made that the device has run the offline corrections. A future native revision needs its own reviewed measurement scope and pinned-source verification.

Stage34's `AMBIGUOUS_NAME_ONLY_OFFER_IDENTITY` guard is unchanged. `exactWeaponIdentityConfirmed`, `rawItemIdConfirmed`, `serverAttestation`, `serverCompletionProven`, `causalAttributionProven`, `authorizesTrade`, `authorizesAccept`, `mayRecordCompletedTrade` and `mayReportProfit` remain false. `tradeOutcome` remains `UNKNOWN`. A unique client icon association cannot override these boundaries.

## Concrete possible measurement, only if later authorized

The missing evidence can be narrowed without exporting arbitrary image URLs or asking for an item transfer. A possible future read-only measurement would classify the slot and catalogue references locally into a **fixed schema**: allowlisted host categories, fixed path-family categories, fixed known query-key presence categories, and bounded shape enums such as numeric versus hash-like versus other. Unknown hosts, path segments, query keys and values must map to fixed `OTHER` enums, rather than being emitted. Do not output arbitrary URL fragments, query values, asset IDs, item names, player identifiers, stable fingerprints, or reconstructible hashes.

Locally, compare preserved reference bytes across every available source and rarity, preserving source provenance, typed keys and same-key conflict information before aggregation. Report bounded counts for missing/empty/non-string art, unknown field shapes, aliases suspected from duplicate references, source/key overlaps, and matches across rarity categories. Keep reference equality distinct from rendered-image equivalence. Sprite metadata and which offer side/root was observed must remain explicit; neither side's item can be assumed from another session.

This proposal adds **no HTTP resolution, image download, redirect following or outbound image request**. Such requests require the concrete host and request purpose to be understood and separately approved first. No new probe or device action is part of this report.

An alternative is a documented, directly observed mapping from the offered slot to a raw item key, with its source and ambiguity tested. If such source becomes available, prefer that identity evidence to inference from art. A locally matched icon or locally recovered candidate key must still be described as client evidence, not authenticated raw-ID or server-settlement proof.

## Validation record

Local runtime: official Lua **5.4.8**, compiled from `lua/lua` tag `v5.4.8` (`6e22fedb74cf0c9b6656e9fce8b7331db847c605`) because Lua was not preinstalled. With `/workspace/.tools` on `PATH`:

- Baseline: existing Stage36 suite **32 passed** and intelligence-lab Python suite **303 passed**, with the real Lua subprocess checks enabled.
- Before the core corrections, `lua5.4 pdiddler/new_part4/tests/test_stage36_reference_safety.lua pdiddler/new_part4` exited 1: **3 passed, 25 failed**. Failures included four case-folded false matches, three dimension-collapsed false matches, two concealed mixed-art gaps, and absent coverage fields. After correction the same command reports **28 passed, 0 failed**.
- `lua5.4 pdiddler/new_part4/tests/test_stage36_icon_catalog_audit.lua pdiddler/new_part4`: **32 passed**. Existing fixtures were corrected to require identical case/dimensions, and the falsely labeled native thumbnail fixture was renamed synthetic.
- All **33 Lua suites** listed by `.github/workflows/stage14-part4-tests.yml`, including its Stage12 command, passed locally. This includes the **29-case Stage34** reconciliation suite. The Stage34 pure module/native launcher and Stage36 native launcher have zero diff from the tested starting head.
- `python3 -m unittest discover -s pdiddler/intelligence_lab -q`: **304 tests passed**, including actual Lua execution and native compile-only checks. `git diff --check` passed.

These are offline synthetic/source checks, not evidence of successful native HTTP identification. GitHub Actions must run on the committed PR head; the task's final report and PR checks identify its exact run and result separately. The prior 32-Lua/303-Python GitHub run is not verification of these corrections.

The repository-history scan and source review above were completed read-only. No native Stage36 rerun, image resolution, new loader, transaction, completion claim or profit claim was performed for this investigation.
