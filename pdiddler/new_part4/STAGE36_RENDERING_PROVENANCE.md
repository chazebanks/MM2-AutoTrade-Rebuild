# Stage36: rendering provenance remains unproven

2026-11-06 UTC. One issue: how MM2 assigns the offered weapon image and whether its source binds to a raw weapon key. This document supersedes the earlier pending-device conclusions; previous implementations and native evidence remain intact.

## What the latest device report proves

[Latest native evidence, PR #75](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/75#issuecomment-6680826959): `NO_IDENTICAL_REFERENCE`, 2,080 labelled rows audited, 2,080 comparisons, zero identical references, `sourcesAliasSameTable=true`, 1,040 overlapping keys and no reported conflicts. `Weapons` and `Item` are the same 1,040-entry table in that session. Two source labels are not two sets of weapons. The 1,034 duplicate-reference groups include every mirrored reference and cannot be interpreted as 1,034 independent weapon collisions.

The exact comparator reached its equality checks. Its parser is no longer the failure boundary. The visible GUI image reference differs byte-for-byte from every supplied `Image`/`Icon`/`Texture` string. This establishes a representation/data-source mismatch, **not its generating mechanism**. It does not establish thumbnails, a URL transform, an alias, a missing weapon, or a failed trade. `catalogueCoverageComplete` refers only to supplied rows.

Stage34 already reconciles stable offered quantities against before/two after inventory reads; its native +1/-0 result remains `AMBIGUOUS_NAME_ONLY_OFFER_IDENTITY`. Stage35 already observed no candidate slot ID attributes/value nodes. Those results are preserved, not repeated as new discoveries.

## Source search and direct-identity boundary

The non-shallow repository at the start of this investigation had 955 reachable commits, 1,310 unique blobs and 26,971,656 blob bytes, including 635 Lua and 20 Luau blobs. Searches across the working tree and every reachable blob found no real MM2 weapon renderer, source assignment to the native trade icon, real Sync art snapshot, or documented asset alias map. This is repository coverage, not a claim to have inspected private MM2 source or every public website.

The known code stops at these boundaries:

- `STAGE36_READONLY_ICON_CATALOG_DELTA_PROBE.lua` locates the native `Container.Icon`, reads `Image`, and requires existing `Database.Sync`. It does not contain the game's image writer.
- `p4_native_observer.lua` checks five raw-ID attribute/ValueBase names. Stage35's broader native census found none of its ID candidates. Repeating it cannot manufacture a binding.
- The presentation scanner's `assetKey()` extracts a numeric substring for metadata signatures. It is not rendering code or a valid image-equivalence rule.
- The scanner retains raw `Weapons.Owned` keys. Stage27 can send a raw key to `OfferItem`; neither establishes the identity of a particular received/displayed slot.
- Stage33's observed `UpdateTrade` receipt discarded its payload arguments. There is no evidenced payload schema linking a key to the observed slot/session. Event existence is not that schema.
- The historical `GetUserThumbnailAsync` image setter belongs to the bot's avatar UI (`pdiddler_p1_p5_observation_gui_v1.lua`, historical blob `470603435917d27d8360072797eb71f97085f3b8`). It is not a weapon renderer.

A more reliable route would be the actual renderer's raw-key lookup or an independently bound native item-key/slot payload schema. Neither is present in the supplied source/evidence. No script-local extraction, hook, decompiler, unknown helper execution, or new transport probe is introduced.

## What Roblox documentation establishes

- [ImageLabel.Image](https://create.roblox.com/docs/reference/engine/classes/ImageLabel#Image) “Reads and writes to ImageContent.” [ImageContent](https://create.roblox.com/docs/reference/engine/classes/ImageLabel#ImageContent) supports asset URIs and EditableImage objects. Reading these properties shows current representation, not the assignment statement or writer.
- [Content.SourceType](https://create.roblox.com/docs/reference/engine/datatypes/Content#SourceType) distinguishes URI/object content; URI content exposes its Uri. This can distinguish representation categories, not a weapon ID.
- [ImageRectSize](https://create.roblox.com/docs/reference/engine/classes/ImageLabel#ImageRectSize) and offset allow partial images; if either size dimension is zero, the entire image is displayed. New diagnostic sprite classification follows that rule without changing old stages.
- [Asset URI documentation](https://create.roblox.com/docs/projects/assets#asset-uris) documents raw assets and thumbnail representations. Its examples do not prove that MM2 uses a thumbnail service or that two different URLs are equivalent.
- [Script.Source](https://create.roblox.com/docs/reference/engine/classes/Script#Source) is protected; ordinary Script/LocalScript reads cause errors. [ModuleScript.Source](https://create.roblox.com/docs/reference/engine/classes/ModuleScript#Source) requires PluginOrOpenCloud capability. This diagnostic does not attempt runtime source access or bypasses.
- [RemoteEvent.OnClientEvent](https://create.roblox.com/docs/reference/engine/classes/RemoteEvent#OnClientEvent) documents transport arguments, not MM2's argument meanings.

## One proposed measurement, not an identity fix

`STAGE36_READONLY_IMAGE_RELATION_PROBE.lua` is one bounded, passive snapshot using the existing visible trade-root/slot scaffolding. It stabilizes the icon **and item-name label** for three polls, reads only the existing Sync module, and checks the same owner/player/job/root/slot/icon/label again. No exchange or Accept is necessary. The previous exact-reference launcher is unchanged.

Its pure `p4_stage36_image_relation.lua`:

1. Counts physical table/key rows once when the two sources are the same table, while retaining source-labelled row counts. Distinct source tables and typed keys are never merged merely because their text agrees.
2. Reports fixed reference categories: schemes, allowlisted host families, generic path shapes and known query-key presence. Unknown hosts, paths, keys and values are never exported. These are observations, not supported URL equivalence formats.
3. Compares the entire GUI string with all direct string metadata fields, including fields outside Image/Icon/Texture, while exporting no arbitrary field names. Counts missing art, exact name candidates across all rarities, Chroma candidates, and duplicate-name rarity groups without exporting names or rarity values.
4. Measures exact local token coincidence for documented raw-asset URI payloads/known query values and string catalogue keys. No decoding, numeric conversion, substring search or URL rewrite establishes equivalence. Ambiguous/unknown query layouts are excluded from token candidates. **Token/name/key candidates do not authenticate an item and do not establish that one URL was generated from another.**
5. Reports physical artwork-reference reuse separately from alias duplication. Every successful report remains `RELATIONSHIP_OBSERVED_INCONCLUSIVE`, with `imageGenerationMechanismConfirmed=false`, `semanticEquivalenceEstablished=false`, `slotIdentityLinked=false` and every raw-ID/trade/Accept/completion/profit gate false.

ImageContent support may be unavailable on the device; that becomes a fixed UNREADABLE category, not an exception or a reason to infer a renderer. The measurement performs no image request, redirect resolution, inventory RPC, remote subscription, input simulation, webhook, or mutation of the game catalogue.

## Risks, limits and stop rule

Component/token coincidence can occur for unrelated content, reused icons, duplicate names, different rarities and Chromas. A different reference can render the same pixels; a matching reference can fail to load. Missing/nested/non-string metadata and unknown query fields leave coverage gaps. Bounds reject oversized snapshots rather than silently sampling. The diagnostic cannot name the script writer or prove a server-bound slot ID. Token candidates can include malformed/unknown authorities; they are value coincidences, not valid-URL or renderer proof. Sprite stability records its boolean category, not exact crop coordinates.

If its fixed categories/candidate counts do not discriminate a relationship, do not add another guessed URI rule. Obtain the actual client renderer/lookup source or an independently scoped raw item-key mapping. Even a strong local token relationship needs source/slot binding before changing Stage34 identity handling.

No completed transfer is needed. To obtain the still-missing live representation evidence, one optional no-transfer iPad observation would be needed **unless actual renderer source or a privacy-safe equivalent snapshot becomes available**. This work prepares and tests that measurement; it does not claim it has run on the iPad, and does not request execution before review.

## Verification record

Real Lua 5.4.8 regression checks pass **16 pure diagnostic cases** and **44 actual-launcher mock cases**. Both suites demonstrated RED before implementation; the additional competing-owner isolation finding reproduced five failures before correction. Independent whole-change review found no remaining material blocker. All **37 workflow Lua suites** and **309 Python tests** pass locally; Python invokes the real Lua suites and compiles the new files. Exact commands are the existing `.github/workflows/stage14-part4-tests.yml` Lua loop plus `python3 -m unittest discover -s pdiddler/intelligence_lab -q`. GitHub run URLs and exact-head results are recorded in PR #75 after log inspection. Offline fixtures are synthetic; they are not new MM2 observations. Stage34, Stage35 and all previous Stage36 implementations are checked unchanged against `52d27bf`.

Reviewed pure-module pin: `6c053d61344603f93c4810047c3d3211522fcc2c`. The new diagnostic has not been run on the device.
