# Stage73 — isolated T4.4 scanner-only historical reference UI smoke test

## Why the user's screenshot looked wrong

The live T4.4 panel recognized eligible weapons while using an expired Supreme snapshot published November 4. The scanner displayed `UNVERIFIED` values and paused outgoing. The November 6 source comparison recorded 21 changed publisher rows for research. Current game item mappings still require independent evidence. [Issue #122](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/issues/122)

## New research-only scanner presentation, not a production bot

`pdiddler3_scanner_view_stage73_history_v1.lua` displays eligible names and copies, `totalText='UNVERIFIED'`, and a paused outgoing status. It can append up to three distinctly labeled historical references per card from the older source. The fixed view has no current-price path even when the device clock rolls back. Failed source or match checks omit the historical annotations.

`STAGE73_SCANNER_HISTORY_ONLY_BOOT.lua` loads the old Supreme source, the historical reference helper, the fixed view, the T4.4 scanner, and its read-only diagnostic. It passes an empty compatibility policy to the scanner. The delayed Stage 25 report sees no active price profile and reports `sourceFresh=false`. Boot still requires an isolated session and the old dated profile to be expired.

All Stage73 dependencies are SHA-pinned independently within the loader; the user should run just the loader, NOT the original Stage25 or Stage66/68 script simultaneously.

### Exact verified offline status

`test_stage73_scanner_history_view.py` exercises the Lua view, the real boot and delayed report against mocked Roblox services, and 200 seeded inventory states. It uses a real older source and a clock rollback that would have made the legacy repricer accept that source.

The fixed loader commit `837fc4f9e5b792cabfb18b524656f2d1b3ef5c0a` passed eight focused Stage 73 tests and 28 inherited tests. The native iPad rendering check is pending. [Exact-commit CI](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42573177588)

## One iPad layout check

Join a fresh MM2 server on the main iPad and select Tablet. Keep the trade window closed and run only the pinned loader.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/837fc4f9e5b792cabfb18b524656f2d1b3ef5c0a/pdiddler/new_part4/STAGE73_SCANNER_HISTORY_ONLY_BOOT.lua"))()
```

Send one screenshot of the purple T4.4 panel and any console error. The expected summary is `Total value: UNVERIFIED` and `Outgoing: paused`. Any exact historical matches should appear in their own section with the original publication date. The check is for rendered content, clipping, and scrolling.

The script can display reference values from the OLD profile (for example Nov4 Emberbow=400), while the updated Nov6 first-party source listed Emberbow=525. It is NOT a current price. DO NOT use these annotations to decide or automate actual trades.

## Remaining true blockers

1. Need trusted CURRENT MM2 raw catalogue metadata matched to Supreme canonical name + type/page/Chroma and a reviewed price freshness policy (retrieval age vs publisher age). The numeric historical Supreme checker ID is source-local, not a game raw key.
2. Stage69 external first-party source acquisition remains research-only; GitHub runner direct Supreme HTTP gets 403. A fresh scrape cannot change publisher update timestamp.
3. Production scanner, trading strategy and P4 final Accept stay unchanged until separate safety/identity tests. Discord completed/rejected learner still off; test ALT `venossgaming90190` excluded.
4. One native GUI rendering test needed to determine if annotations fit the mobile screen; no trade is required.

All PRs remain DRAFT and stacked, not merged.
