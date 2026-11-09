# Stage86 — First actual planner → offer-snapshot-guard integrated DRY-RUN

**Date:** 2026-11-09. **Goal:** Begin practical trading-strategy integration after Stage85 without inventing another standalone planner or re-running redundant inventory probes.

## Tested inputs are REAL EXISTING CODE, SYNTHETIC ONLY DATA

Sources are pulled from their actual existing draft pull requests, not re-implementations:
- [PR106 existing portfolio compounding planner](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/106): exact code commit `6ed48e084bd58fab38e3bf061ac36fb295ecf103`, Git blob `78948cdacd2a760db5b888fce242d598fc6f14b6`.
- [PR105 existing four-slot offer-revision/quantity guard](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/105): exact code commit `2f49e2f25cdbf7c8ca01702db159d412cc4382bc`, Git blob `c5b87f159de5224d231b111da2541b8b23ac6284`.

`pdiddler/intelligence_lab/stage86_planner_guard_dryrun.py` is a small adapter, not a new price algorithm. It accepts **synthetic items with `test_` prefixed fake keys**, `SYNTHETIC_OFFLINE_TEST` bindings for job/partner/session, and a frozen explicitly synthetic research-only market catalog `SYNTHETIC-STAGE86-V1`. It invokes the exact existing planner `plan()` for market desirability/rarity, demand/liquidity, bounded four physical copies, +5 opportunity and upgrade/downgrade; takes the top deterministic candidate, converts planned copies to four indexed slots, and invokes existing snapshot-guard `evaluate()` against the current *synthetic* offer/partner/session/revision at a fixed clock.

**Risk demonstrated:** A nice +5 listed candidate is not executable if the opponent removes an offered item, changes the offer revision or quantity, the server/partner/session changes, the GUI accepted state or mutation flag changes, or the market evidence is stale/unproven. In all those cases the bridge returns `REJECTED_REPLAN_REQUIRED`, not a stale positive gain or approval to Accept. A perfect frozen simulated snapshot only becomes `IDEAL_SYNTHETIC_SNAPSHOT_MATCH_ONLY`; it **NEVER** authorizes gameplay, even if the fixture calls an identity `INDEPENDENT_EXACT`. All outputs retain `authorizesTrade=false`, `authorizesAccept=false`, `tradeOutcome=UNKNOWN`, `serverCompletionProven=false`, `verifiedMarketQuote=false`, `mayReportProfit=false`, `maySendDiscordWebhook=false`, `mayUseForStrategyLearning=false`, and `manualFinalAcceptRequired=true`. The old blanket +15 floor does not reappear; the synthetic +5 case must pass.

Tests use the ACTUAL downloaded original pinned Python functions, not handwritten stubs:
- Sidegrade +5, upgrade two small to one stronger, downgrade one item to two liquid items.
- Offer removal, same revision changed slot/stack, offer revision bump, partner/session/server/version mismatch, GUI open/bind/accept state and pending mutation.
- Declining/illiquid received assets, unavailable publisher, unproven identity, too-large or nonsynthetic/nonfake input, original source mutation detection.
- **500 deterministic modified-offer snapshots**, all refused without any terminal authority.
- Dedicated GitHub Actions **must verify both exact original Git blobs and run actual adapter tests.** All other baseline offline workflows should continue to pass.

## Boundaries and next steps

**This is NOT yet an actual Part3 scanner→Part4 runtime integration.** The current main `pdiddler/pdiddler3_scanner_*` files are legacy and the new Part4 logic lives across unmerged/stacked feature branches. Do NOT accidentally re-enable the old +15 algorithm by importing old `pdiddler4_planner_v1.lua`; do not pretend an offline Python adapter exercises Roblox/Delta buttons or partner inventory authorization.

Once Stage86 is green, move to ONE short **native manual-final-accept preview** on a verified fresh server, using only the necessary reviewed current scanner/Part4 code, and with explicit consent and a bounded risk plan. Alternatively do one more deterministic P3→P4 event handoff test if current branch ownership and callback identifiers do not match, but do not return to Stage79/80/83 identity loops. The user's objective remains growing high-demand liquid weapons toward Gingerscope, including upgrade/downgrade and true four-copy limits.

The November 9 Supreme 190-item public source snapshot (Stage84) was research-valid at acquisition but its price authorizations are FALSE and it expires under the earlier of 24h from retrieval and 72h publisher age. No current validated trade values, server-authenticated inventory, Accept/settlement, profit webhook, or market-learning permission is obtained by this dry-run. Stage85's actual sanitized event replay now quarantines reused client session tokens, but has no server transaction proof. **No new iPad action** for this offline integration stage. DRAFT/UNMERGED until exact-head CI passes and review.
