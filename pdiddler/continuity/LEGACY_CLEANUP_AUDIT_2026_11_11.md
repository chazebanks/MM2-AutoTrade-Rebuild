# Gingerscope legacy cleanup review — November 11, 2026

**This is a NON-DELETION audit**, not a script change. Examined the recursive `main` Git tree at `f27002118363a544321bb7f0f1af00c2f2124d1a`. Use `pdiddler/START_HERE.md` to load only relevant history. The archive remains in Git.

## What is already clean

Merged PR #231 deleted exactly three byte-identical scanner test aliases only after searching references; `pdiddler/history/REMOVED_DUPLICATES_2026_11_11.json` preserves canonical file names and full original Git blob IDs. CI source verification passed. Do not repeat the deletion.

## Four exact duplicate pairs still on current main

| Existing paths | Identical Git blob | Action |
|---|---|---|
| `pdiddler/pdiddler1.lua` and `pdiddler/pdiddler1_KNOWN_GOOD.lua` | `193d0319d54a3309fda338bdd054eb2f94b9190b` | **KEEP**: historical loaders reference KNOWN_GOOD |
| `pdiddler/pdiddler2.lua` and `pdiddler/pdiddler2_KNOWN_GOOD.lua` | `463915e34d509b55b1a17634ec74396e7d82b76c` | **KEEP**: current CLI and multiple old test stacks reference different paths |
| `pdiddler/pdiddler3_outgoing_KNOWN_GOOD_v5.lua` and `pdiddler/pdiddler3_outgoing_test_v5.lua` | `d29dd8d44833b153e160c4364dd04ad354666f67` | **KEEP**: path used by historical test stack |
| `pdiddler/pdiddler3_scanner_MODULE_KNOWN_GOOD_v6_3_PURPLE.lua` and `pdiddler/pdiddler3_scanner_MODULE_v6_3_PURPLE.lua` | `38c4e5eb717a2b60c8e6d7dfd96775fa0b4a258c` | **KEEP**: path used by historical stacks |

The duplicate bytes do not imply redundant **file paths**. Until all relevant loadstrings, tests, repository refs and pinned SHA consumers are checked, deletion would risk breaking historical reproducibility.

## Historical runtime files that must not become new policy

- `pdiddler/pdiddler4_balancer_ROTATING_v2_3_EXTREME_GUARD.lua`, blob `041496d2fbda726acbd97165d5c3d260a8e3246b`: prior version has `NormalMinFlat=15` and first offers highest valued item. Those are **superseded** product rules.
- `pdiddler/pdiddler3_scanner_MODULE_v6_8_CRITICAL_PAUSE.lua`, blob `f1d4b5393846289fee766f06591dc1d5d5eda890`: historical scanner evidence, not proof it is the currently permitted integrated offer controller.
- Old combined stacks, pinned frozen loads and dated handoffs can contain obsolete +15/highest-opener logic; do not adopt them just because the file name says `KNOWN_GOOD`.
- Existing PR106 planner is source-proven **synthetic**, and still caps *four copies*, unlike corrected PR182 guard's four **physical slots**. This is a separate future planning-code task, NOT a change made here.

## Deletion criteria for later review, not now

1. Verify current `main`, then scan all script/test/workflow references AND historical PR/branch pinned consumers.
2. Identify exactly one canonical immutable retained source by Git blob SHA; compare actual code and execution contract.
3. Confirm no shared loader, tests, or recovery manifest require the old path; retain a reverse map and historical commit.
4. Remove only proved-unused aliases on a narrow PR; include missing-file/retained SHA tests, all inherited CI, rollback plan.
5. Preserve large original handoffs. Reduce *default reading* with compact indexed navigation rather than deleting evidence.
6. Inspect 236 historical branches individually before any purge; an unmerged branch may contain unique proof or source. **No branches deleted this session.**

**Final effect of this pass:** 0 runtime Lua edits, 0 additional file deletions, 0 branch deletions; only better navigation, policy continuity and a sequenced, testable next-conversation plan.
