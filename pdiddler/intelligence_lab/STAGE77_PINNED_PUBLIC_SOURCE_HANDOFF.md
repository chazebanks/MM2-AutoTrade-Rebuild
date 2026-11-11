## Exact-head real-source CI outcome — 2026-11-09

**PASS:** Source+tests HEAD `6775e10a8266da43b8b316cddaa3a8042c0f3dda`, dedicated [GitHub Actions 42682838049](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42682838049) downloaded **four** immutable actual public input Git blobs, verified all four raw Git object IDs and executed **15/15** real Python unittest groups (including the actual pinned-archives positive result and 400 seeded corruptions). This supersedes the prior 'real-source test pending' text below. The tested source parser returned `PINNED_PUBLIC_SOURCES_CORRESPOND_ONLY` for the four reviewed game/source slug/name/rarity/Chroma pairings. Luau/Lune, replay and Hypothesis also succeeded on this code HEAD; check status on any later documentation commit separately.

**Real-source regressions and fixes before green:** Initial pinned run refused the source because the Ancient list contains unlinked priceless Nik's Scythe, which cannot be assigned a fabricated URL. Fixed to skip this exact known exception while continuing to reject any unknown unlinked row. The Chroma page contains seven distinct pet records in a `data-tier=pets` section; excluded only the explicitly reviewed seven names. Four Chroma weapon row links abbreviate `Chroma` as `C.`, while `data-name` has the full string; permit only exactly `C. ` expansion in a Chroma page, with negative tests against other aliases. Godlies contains exactly two `style=display:none` 1,000,000-value placeholder rows `Batwing`, `Black Luger`; explicitly quarantined them, reject any unfamiliar hidden row. Those are original site structures, not evidence of wrong four-key crosswalk. This source-only parser neither assigns prices nor calls gameplay code.

**Trust boundary:** The Git blob SHAs authenticate immutable repository bytes, not the original website's server identity or the currently running Roblox server. The Supreme HTML was captured by Firecrawl Nov9 with page-level publisher Nov6; it is stale beyond the current 72h policy. The Oct18 MM2 catalogue is third-party. Independent *source strings* now agree for four public cases; no authenticated owned raw key, Supreme site-local numeric checker index, real-time valuation, market-learning outcome, trade, or settlement has been established. All authorization flags stay FALSE. Keep [draft PR147](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/147) unmerged; **no iPad test needed for this archived source task**.

---

# Stage77 — pinned independent public-source identity proof boundary

**Date:** 2026-11-09. **Issue:** #122. **Status:** Research-only, no scanner or trading modifications.

## Research question

Stage76's four Supreme website slug matches were tested against caller-supplied fixture rows. That catches shape mismatches, but not the critical failure where both sides of a test repeat the same manually authored assumption. Stage77 tests the same **four already-reviewed representative pairs** against genuinely separate immutable public-source bytes:

1. Third-party October 18 MM2 game catalogue, `mm2scripthub/mm2`, exact Git commit `0f2715187e7eae36eea4bd97afee809478fc877d`, original `db` Git blob `2be54c3f5c6b715844728c01a65cc2f24a55c02d`. The catalogue is an untrusted public copy, NOT authenticated current Roblox server data.
2. Three Supreme page-HTML captures from Nov9 Firecrawl Stage69 archives (`ancients`, `godlies`, `chromas`), exact Git blobs `7e11a2d835eadbb522d351bdabe393a7c9688f4b`, `2e4a0c1b8df894f9037e737ba80919b9b2d0c9ae`, `0d2d156d9d9c499ef0e1213376796c1a916e6ce1`. These are archived first-party **website content as captured through an intermediary**, NOT signed/verifiable bytes from the original HTTPS server and NOT fresh trade prices.

The CI downloads all four original blobs from immutable Git commit URLs, rejects a single changed byte, uses **actual Python HTMLParser and Lua table-literal text regex** to inspect real fields, and checks:

| Public game raw key | Required game fields | Supreme HTML item identity |
|---|---|---|
| `Gingerscope` | Ancient Gun, nonchroma | `ancients?item=Gingerscope` + Gingerscope |
| `EmberscytheChroma` | Ancient Knife, chroma | `chromas?item=CEmberscythe` + Chroma Emberscythe + class Ancient |
| `BattleAxe` | Godly Knife, nonchroma | `godlies?item=Battleaxe` + Battleaxe |
| `BattleAxe2` | Godly Knife, nonchroma | `godlies?item=BA2` + Battleaxe II |

The website's `id` / URL slug, game public raw key, reused image `ItemID`, historic Supreme **numeric checker ID**, and *owned inventory* raw key are separate identity systems. A matching public name/slug is useful but cannot prove a user owns that item. No normalizing fuzzy aliases, duplicated market records, counterfeit page hostnames, or changing `Ancient Chroma` to `Godly Chroma`.

## Code and verification

- `pdiddler/intelligence_lab/stage77_pinned_public_identity_audit.py`: source-bound, offline, fail-closed research module; hashes both sources and parses only metadata. It **never executes** the downloaded Lua/HTML, reads live MM2 inventory, sends Roblox events or assigns prices.
- `pdiddler/tests/test_stage77_pinned_public_identity_audit.py`: 11 Python test groups, including 400 deterministic corruptions, duplicate/changed item IDs, website URL injection, false Chroma classification and blob mutation. Real pinned fixture test MUST run in dedicated CI; other unrelated generic test discovery skips that one group if fixtures absent.
- `.github/workflows/gingerscope-stage77-pinned-public-sources.yml`: downloads exact source bytes, confirms all four Git blob SHA-1s, runs actual Python test suite with `STAGE77_REQUIRE_PINNED=1`.

**Local initial tests:** 10 synthetic/negative groups passed; the real four-archive group was not locally runnable because network access was unavailable. Do not call Stage77 empirically verified until its exact-head dedicated GitHub Actions run executes and passes the full pinned-source group. Fix any real-source parser differences rather than weakening pin checks.

## Non-authority invariants

All result variants keep `authenticatedOwnedInventory=false`, `currentGameCatalogueAuthenticated=false`, `serverAttestation=false`, `numericSupremeCheckerIdVerified=false`, `sourcePublisherFresh=false`, `currentPricesVerified=false`, `authorizesTrade=false`, `authorizesAccept=false`, `mayReportProfit=false`, `mayRecordCompletedTrade=false`, `mayRecordRejectedTrade=false`, `mayUseForStrategyLearning=false`, `maySendDiscordWebhook=false`.

Stage69 Supreme publisher date Nov6 still exceeds the 72h threshold on Nov9. Stage77 intentionally does not repair source freshness, introduce a live raw-owned weapon mapping, claim server settlement, or enable P4/autotrading. Stay DRAFT/UNMERGED until review. No iPad test is needed for archived-source research.

## Next after real-source green

One issue at a time: examine which **game-owned raw key** representations are actually established by evidence, distinct from public catalogues; only then consider broader mappings. Treat the Supreme publication-age policy as a separate review. Avoid duplicating Stage75 native key tests or Stage73 GUI tests.
