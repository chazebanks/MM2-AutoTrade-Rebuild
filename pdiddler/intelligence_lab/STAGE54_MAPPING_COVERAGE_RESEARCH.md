# Stage54 — Live eligible catalogue to frozen checker-reference mapping COVERAGE (READ ONLY)

## Why this is the next distinct question
Stage53 iPad Delta screenshot, [PR98 native result](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/98#issuecomment-6718220940): `Sync.Weapons == Sync.Item` on this client, 1,040 rows, 200 broad eligible candidate entries, zero invalid rows/printable-key collisions. Thus a supposed second independent catalog silently overwriting the first is **not supported** by the native session. No production scanner fix was needed for that conjecture.

Stage51's `checkerResolve` (not merged to `main`) uses seven curated raw-key associations, name aliases, or filename similarity to associate raw MM2 catalogue items with the *separately numbered* checker snapshots. The existing frozen checker image list has 190 entries and a known ambiguity: chroma checker IDs 1033 and 1034 both use `coming.png` placeholders. It is unsound to assert that the 200 live broad eligible entries correspond one-to-one to 190 old values rows; eligibility includes multiple in-game variants, stage-dependent items and exclusions.

Independent publisher context: [Supreme Values](https://www.supremevalues.com/) and its [Chroma page](https://www.supremevalues.com/mm2/chromas.php) explicitly label the price list last updated **November 6, 2026**. These pages expose item display identity, values, origin, demand, stability, etc., but were **not** demonstrated to publish a trustworthy MM2 raw `Sync.Weapons` internal-key mapping or a unique item instance identifier. Generic third-party item-database `id` is not assumed equivalent to a Roblox raw key. This question is *coverage / error analysis*, not official authenticated identity.

## Read-only implementation
`pdiddler/new_part4/STAGE54_READONLY_MAPPING_COVERAGE.lua` copies the **real** Stage51 Lua resolver functions from PR90 reviewed commit `7a289d62ef3f0be0a299506eb451c57435493be3` into a stand-alone census, with the legacy 190 `page|id|img` references and **numeric values zeroed**. The source is pinned and visibly frozen; no live or current prices are claimed.

In MM2 it `require`s only already-replicated `ReplicatedStorage.Database.Sync`, enumerates **local catalogue metadata only** (not the user's actual weapons or anyone else's inventory), applies the scanner's same eligibility gate, and tests:
- how many eligible raw keys resolve by `internal-key`, `alias`, or `match:<score>`, versus ambiguous/unresolved;
- how many distinct raw keys collapse into one provisional checker `page:id`;
- how many images are generic placeholder art or have conflicting source-year *hints* when both a year hint and image year are present;
- missing/malformed catalog rows, number/string printable-key collisions, changed server job, or unavailable Sync module.

It prints **one** aggregate non-identifying JSON report `[GINGERSCOPE STAGE54 MAPPING COVERAGE]` and a fixed clipboard status line. It attempts to copy **that exact already-anonymized report line** to Delta's local clipboard with `setclipboard`, `toclipboard`, or (when exposed) the `getgenv()` equivalents. Failed/unavailable clipboard functions are protected with `pcall` and leave the console JSON available as a manual fallback. It never copies raw keys, usernames, item names, IDs, asset paths, Job IDs, inventory, source payload or numeric item values. A year printed in an image is only a hint, not a validated item origin. Exact field counts still do not authenticate an external ID. All trading/Accept/completed-trade/profit authority remains false.

The actual Lua is tested by `pdiddler/intelligence_lab/test_stage54_mapping_coverage.py` against fake Roblox game objects: the original 18 targeted cases (internal/alias/fuzzy, year mismatch, duplicate checker target, placeholder artwork, evolution and nontradable exclusion, invalid rows, key collisions, wrong game, missing module, job changed), **7 clipboard/encoding edge cases**, and 400 seeded cases. Isolated, secret-free Actions regression covers the actual source, and the entire existing `main` Python suite.

## Interpretation / next evidence
**Only after exact-head CI is green**, one native Delta catalog read-only run is warranted. No trade must be started, no account or specific item needed, and no inventory is altered.

- A high fuzzy percentage means an enormous portion of the scanner's ID lookup depends on guessing based on filenames, even if all rows resolve.
- `duplicateTargetGroups > 0` flags multiple raw catalogue keys pointing to a single checker row; this may be legitimate versioning but must not be auto-certified as identical weapons.
- `yearHintConflicts > 0` or placeholder matches means the external ID/variant relation needs independent review.
- A zero-risk count still does not prove external market ID, source freshness, server-trade completion, or financial value.

**DO NOT** wire the legacy frozen image/ID source into the live price stream. Stage52's current mainline guarded research feed remains unchanged; Stage50/51/53 draft PR stack stays separate. The goal is to identify precisely which mapping identity assumptions need investigation, before changing any live trading logic.
