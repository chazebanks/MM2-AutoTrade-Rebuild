# Stage69 — Review-only Supreme three-page publication and price-diff audit

## Why user sees every weapon UNVERIFIED

User's MM2 T4.4 screenshot clearly shows **7 whitelisted players, 1 blacklisted, 0 unknown**, and eligible items with name/quantity, but every listed value is `UNVERIFIED: price expired or unavailable`; outbound is `paused - Supreme prices expired or unavailable`. This is **not** an inventory-scan failure. The scanner's [actual view](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/blob/0230ed1481768e7b8ddfee87e9022f6d27462674/pdiddler/presentation/pdiddler3_scanner_view_v1.lua) refuses to call `P4_REPRICE_ONLY.reprice` unless `SupremeProfile.isFresh()` returns true. Its [pinned Nov6 Supreme profile](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/blob/d9d7970f281f725ff21d1a409495fcc197e3d2dc/pdiddler/snapshots/pdiddler_supreme_snapshot_2026_11_06.lua) expired **Nov 7 2026 00:47:22 UTC**, before screenshot. Outgoing remains correctly blocked.

The [Stage52 MM2Values refresh](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/96) is a *separate research-only* updater with unknown publisher update date. It doesn't refresh the Supreme profile. Do not substitute it for verified Supreme price and raw-key mapping authority.

## Source-level live audit, November 8, 2026

Read current **first-party** original pages (not untrusted screenshots, not valuation calculators, not replica websites):
- https://supremevalues.com/mm2/ancients
- https://supremevalues.com/mm2/godlies
- https://supremevalues.com/mm2/chromas

The current three HTML responses are HTTP 200 and each expose `data-updated-iso="2026-11-06T10:56:07-05:00"` (= **2026-11-06T15:56:07Z**, a *publisher-supplied timestamp*). This publication claim is newer than the old Nov4 snapshot. The HTML still exposes structured `data-name`, `data-value`, `data-demand`, `data-stability`, and `data-tier` information, so adapting the already separately tested Stage26 structured parser rather than rebuilding a brittle fuzzy text scraper is feasible.

Raw HTML counts of `data-name` attributes in the three pages were approximately **15 Ancients**, **130 Godlies**, **53 Chromas**, but these are *not* weapon coverage figures: special items may lack buttons, Godlies have known intentionally hidden placeholders, and Chromas have several pets. The separate parser must categorize and exclude only the exact previously independently reviewed nonweapons/hidden rows, and fail closed on any new exclusions. The old canonical baseline expects **16 ancient weapons (including priceless Nik's Scythe), 128 Godlies, 46 Chromas = 190**. Do NOT infer new canonical additions from simple `data-name` counts.

Concrete published price drift independently checked:
- Old Emberbow = **400** in frozen Nov6 profile vs current site **525** (Ancient).
- Old Emberscythe = **400** vs current **500** (Ancient).
- Old Traveler's Axe = **7300** vs current **7100**.
- Gingerscope presently **16000** on current site, equal to the old 16000.
These are source observations to *review* only, not authoritative planner valuations. Demand/stability can change even if price doesn't, and exact raw MM2 item IDs/variants do not follow merely from matching displayed strings.

## Architecture, one bounded research-only change

- `pdiddler/intelligence_lab/stage69_supreme_parser_reference.py`: a **read-only copy** of the already tested [Stage26 parser](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/blob/a2a2e601be864f970da0a69c436ab3b12efd8112/pdiddler/refresh_supreme_snapshot.py), with direct publishing entrypoint **disabled**. Verifies DOM metadata/display equality, genuine categories, publisher site timestamp, no duplicated names, known exclusions and valid demands/stabilities. The original Stage26 branch is unmerged, so do NOT merge its older stack wholesale.
- `scripts/stage69_supreme_source_audit.py`: takes exactly three unmodified HTML byte responses and the immutable prior 190-row JSON baseline, checks raw SHA256/source time, exact 16/46/128 counts, full canonical name+page identity, every changed price/demand/stability, new/unmapped names and missing items. Converts current source to **REVIEW_REQUIRED** when drift exists. **It never writes a new live Lua price snapshot, touches trading loaders or modifies current `values/mm2values.lua`.**
- Invalid source, duplicate or hidden new items, conflicting source publication timestamps, altered display-vs-DOM values, future-dated pages, malformed baseline or source older than existing 72-hour policy hard-fail. This code *records the age-policy failure* rather than overriding the clock or faking retrieval time. A future design review can explicitly change a restrictive policy if justified by actual update cadence.
- GitHub Actions runs source/parser regression tests with 400 deterministic corruption variants, inherited intelligence Python suite, and an independent **read-only live source audit** in a separate job. The live job fetches exactly three original-page endpoints and the immutable old baseline, uploads **only a 7-day review artifact** (source hashes/timestamps/changes), **not the full HTML or a trading price module**. The live job must succeed with all three publisher pages before we consider a source complete. If blocked or changed, that job correctly fails.
- Regardless of source status, every resulting record has `outgoingPaused=true`, `liveReady=false`, `authorizesTrading=false`, `authorizesAccept=false`, `mayReportProfit=false`, `mayUseForStrategyLearning=false`, `mayPublishLiveSnapshot=false`. This is **evidence capture and change review**, not production repricing.

## Remaining blockers before clearing UNVERIFIED

1. Inspect actual live audit artifact: complete 190-item source, source hashes and publication clocks, all named price changes, any new or missing names, zero new hidden/nonweapon exclusions. Handle offline parser breakage separately from price staleness. **A passing unit test is not the same as completed native source parsing.**
2. Review full source diff, especially high-value/volatile 2026 items, and reconcile identity provenance for the exact MM2 `Weapons.Owned` raw keys to Supreme numeric checker IDs. Stage66 proved one raw client receipt matched one raw own gained key; it did NOT prove all ~190 raw keys correspond to external price IDs. No fuzzy heuristic promotions.
3. Only after approving those distinct questions, build a new **immutable expiring** Supreme profile with accurately preserved publisher date and current retrieval hash; test the actual Lua T4.4 view/repricer on mock items, then run a **read-only** iPad scanner test before considering actual trading permissions.
4. Keep the Discord completed/rejected trade learner and auto final Accept disabled until evidence and economics are independently sufficient. Test-alt transfers are excluded from market learning.

This is the first, intentionally isolated, price-source issue. No additional user script or weapon transfer is needed to perform this audit.
