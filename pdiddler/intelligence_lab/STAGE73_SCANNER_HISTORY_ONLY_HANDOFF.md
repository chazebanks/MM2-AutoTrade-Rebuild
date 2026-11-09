# Stage73 — isolated T4.4 scanner-only historical reference UI smoke test

## Why the user's screenshot looked wrong

The live T4.4 panel recognized eligible weapons but used an expired pinned Supreme snapshot (published Nov4, observed Nov6, expired Nov7); its inventory values and outgoing were deliberately `UNVERIFIED`/paused. The Stage69 parser later verified a new Supreme publication Nov6 with 21 changed records, but that research-only source is now past the original 72-hour publisher threshold, and raw MM2 game IDs ↔ historic checker IDs still lack independent current-game provenance. Stage70/71 explicitly separate source price quality from item identity, rather than falsely promoting fuzzy aliases.

## New research-only scanner presentation, not a production bot

`pdiddler/presentation/pdiddler3_scanner_view_stage73_history_v1.lua` is a narrow additive fork of the old `pdiddler3_scanner_view_v1.lua`, accepting a pure `HISTORICAL_PREVIEW` module (Stage72) through its varargs. It calls the original `V.inventory`, keeps `totalText='UNVERIFIED'`, `priceState='expired'`, the detailed per-item `UNVERIFIED` labels, the original `V.row` and `V.summary` outgoing pause logic, and appends at most three distinctly marked `HISTORICAL REFERENCES ONLY (UNVERIFIED; NO TRADING)` messages from the old 190-row source. No record is written as a verified quote. If the historical helper or source validation fails, omit annotations rather than change any existing state.

`pdiddler/new_part4/STAGE73_SCANNER_HISTORY_ONLY_BOOT.lua` is a fork of the **existing known-good Stage25 scanner-only loader**, uses the unchanged owner key `PDIDDLER_STAGE25_SCANNER_ONLY` to preserve the pinned Stage25 read-only probe, and loads only: old source-expired Supreme profile, existing strict repricer, new Stage72 pure reference module, Stage73 view fork, same pinned T4.4 scanner v6.10 and existing read-only diagnostic. No outgoing controller, offer mutation, final Accept, teleport, server hop, market learning or webhook. Keeps legacy bootstrap separation guards and adds Stage63/Stage66/Stage68 collector owner checks. It fails closed if the pinned old Supreme profile unexpectedly reports fresh, if a conflicting controller is active or if reference preview's trading flag is not false. Loader execution is itself the only explicit read-only test opt-in, no separate enable flag.

All Stage73 dependencies are SHA-pinned independently within the loader; the user should run just the loader, NOT the original Stage25 or Stage66/68 script simultaneously.

### Exact verified offline status

`pdiddler/tests/test_stage73_scanner_history_view.py` executes the real new view module, actual Stage72 reference module, original Supreme Lua profile, and strict existing repricer under Lua5.4. It checks fake checker IDs, Chroma/base collisions, forged display values/verification flags, source expirations, invalid quantities, duplicated raw input keys and 200 seeded UI state mutations. It asserts all total values remain `UNVERIFIED`, `priceState='expired'`, `Outgoing: paused` regardless of the three possible historical annotations. Separate Stage72 tests cover 300 private mutations. New separate GitHub Actions workflow also reruns Stage70 Lua strict checker/source proofs and Stage69 provenance tests.

[Workflow Stage73](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/workflows/gingerscope-stage73-scanner-history-view.yml): exact fork head `ac3ba59863edd7c06d72602e280a5837cb20520d`, [run 42570189258](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42570189258) **SUCCESS**. Recent logs show 6/6 focused Stage73 view tests and 28/28 Stage72/70/69 inherited tests. No native iPad Stage73 result yet.

## One manual UI action when user agrees

Fresh original MM2 game server on MAIN iPad; select Tablet; do NOT run any other pdiddler/Stage63/66/68 script. Run one exact SHA-pinned loader:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/ac3ba59863edd7c06d72602e280a5837cb20520d/pdiddler/new_part4/STAGE73_SCANNER_HISTORY_ONLY_BOOT.lua"))()
```

Do NOT trade or press Accept. Check the existing purple T4.4 whitelist panel: the old line `Total value: UNVERIFIED` and `Outgoing: paused` should remain; where raw items have an exact historical page/sourceName match, a separate section says `HISTORICAL REFERENCES ONLY (UNVERIFIED; NO TRADING)` with at most three examples, the Nov4 source publication and expired flag. One screenshot showing the panel plus any console error is enough to verify clipping/layout and actual rendered data. If nothing appears, send screenshot/error; do not force an ALT weapon transfer. If the panel is too long, subsequent work should fix scrolling, not reclassify source prices.

The script can display reference values from the OLD profile (for example Nov4 Emberbow=400), while the updated Nov6 first-party source listed Emberbow=525. It is NOT a current price. DO NOT use these annotations to decide or automate actual trades.

## Remaining true blockers

1. Need trusted CURRENT MM2 raw catalogue metadata matched to Supreme canonical name + type/page/Chroma and a reviewed price freshness policy (retrieval age vs publisher age). The numeric historical Supreme checker ID is source-local, not a game raw key.
2. Stage69 external first-party source acquisition remains research-only; GitHub runner direct Supreme HTTP gets 403. A fresh scrape cannot change publisher update timestamp.
3. Production scanner, trading strategy and P4 final Accept stay unchanged until separate safety/identity tests. Discord completed/rejected learner still off; test ALT `venossgaming90190` excluded.
4. One native GUI rendering test needed to determine if annotations fit the mobile screen; no trade is required.

All PRs remain DRAFT and stacked, not merged.
