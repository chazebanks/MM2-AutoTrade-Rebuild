# Stage 26 — Immutable dated Supreme source promotion

**Status:** Draft replacement branch only. No automatic trade authority, Accept, completed-trade webhook, or active loader cutover.

## Source and history

Stage 25 already verified the November 4 official Supreme publication using original official HTML retrieved through a browser-backed service, independently logged in GitHub Actions. The new November 6 *retrieval* is NOT a newly published Supreme values update. Exact comparison: **zero changes among 190 mapped weapons** (values, demand and stability). The source candidate is valid only for its fixed time window.

- Official publication: 2026-11-04T17:27:12Z
- Browser-backed observation: 2026-11-06T00:47:22Z
- Fixed expiry: 2026-11-07T00:47:22Z (November 6, 7:47:22 PM Eastern)
- Exact Gingerscope: ancient checker ID 771, Supreme 16000, demand 5
- 190 eligible mapped records, 189 finite values, one Priceless
- Source freshness: min(retrieval + 24 hours, publication + 72 hours); expiration is not renewed at runtime

## Staged files and evidence

The staged assets are:

- pdiddler/snapshots/supreme_snapshot_2026_11_06.json
- pdiddler/snapshots/pdiddler_supreme_snapshot_2026_11_06.lua
- pdiddler/source_evidence/stage26_dated_profile_promotion.json

The last file records original source artifact run ID, artifact ID, source acquisition label, source SHA256 values and both promoted files' exact SHA256. Python tests compare the GitHub files against the original downloaded GitHub Actions artifact **byte for byte**. The original November 4 JSON and Lua files are retained unchanged.

The specific immutable source commit for the replacement is d9d7970f281f725ff21d1a409495fcc197e3d2dc. The runtime does not fetch a moving main branch.

## Loader integration

The opt-in replacement preview and the existing scanner-only diagnostic bootstrap now reference the November 6 Lua profile via the immutable source commit.

- Source freshness stays anchored to official publication and original retrieval. The existing preview assertion rejects source expiry before launching trade-related modules.
- The existing Part 3 scanner repricer and outgoing request eligibility check freshness dynamically, including after bootstrap.
- Scanner-only mode does not start outgoing trading, Part 4, hopper or Discord.
- The replacement preview still calls the Part 4 controller WITHOUT a permit or native sender; automated placement remains off.
- The old +15 balancer is not a runtime dependency; the active autoexecute loader is unchanged.
- The profile does not auto-refresh and does not authorize any live action.

## Validation

The new Python suite pdiddler/intelligence_lab/test_stage26_market_promotion.py verifies artifact SHA256, complete record equality, immutable provenance, exact source dates and the two loader pins.

The new Lua suite pdiddler/new_part4/tests/test_stage26_dated_profile.lua runs the actual consumer at and around expiration, verifies Gingerscope identity and repricing, and confirms both the repricer and P3 eligibility refuse expired source prices.

Run from pdiddler/intelligence_lab using: python3 -m unittest discover -q

## Next issue

The Stage 25 Delta test proved 7/7 recent client scanner records but did not prove a native MM2 item placement or removal. The next focused task is a controlled, non-accepting Delta placement/withdrawal test using the existing Stage 22 and 11 interfaces. If this source expires before testing, retrieve a new source-backed candidate rather than adjusting the expiration date.

**No completed live trade or native placement is claimed by Stage 26.**
