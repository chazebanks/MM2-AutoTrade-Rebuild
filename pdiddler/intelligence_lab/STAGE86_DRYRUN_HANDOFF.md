## Native Part3→Part4 contract audit — concrete NEXT blocker

After Stage86 original Python planner→guard passed, inspected the ACTUAL existing new-Part4 Lua code on the unmerged `feature/gingerscope-stage51-checker-mapping-provenance` branch, not obsolete original `pdiddler4_planner_v1.lua`:
- `pdiddler/new_part4/P3_ELIGIBILITY_NO_LEGACY_PROFIT.lua`, Git blob `b781beb27743788c8d3f522d47dd8116199add54`: despite being described as **request eligibility only**, `validateInventory()` requires `inv.unpriced==0`, each `it.checkerId` a numeric string, positive `it.value`, current `profile.isFresh()`, and an independent `strict.reprice()` call. If no authenticated market source is available, it returns `unknown` and prevents even the benign `reachable` request-eligibility outcome. This is a **real interface dependency**, not evidence of a runtime failure in today's MM2 servers.
- `pdiddler/new_part4/p4_strategy_permit.lua`, Git blob `9316e344b9d81c2eb5c7514181ca1c80ea9155f9`: candidate IDs and observed opponent offers demand the `page:numeric-checker-id:checker-id` syntax and exact source binding. This contract cannot consume Stage82's historical **public** `?item=slug` references directly, and MUST NOT be made to trust those slug links as verified numeric checker IDs.
- `pdiddler/new_part4/PDIDDLER_PART4_REPLACEMENT.lua`, Git blob `9e99cd9a3105238a42e7ba644a72bba61dbbdcdf`, remains observation-only, explicitly no legacy +15, no offer placement/Accept/Decline. `REPLACEMENT_INTEGRATION_PREVIEW.lua` is a separate opt-in preview, not production.

**NEXT exactly ONE practical code issue:** Split P3's **scan/request candidate eligibility** (client observed Godly/Ancient Knife/Gun metadata, valid quantities, explicit unknown otherwise) from **priced offer feasibility and Part4 trade approval**. A legitimate no-price eligible counterparty should be marked `REACHABLE_FOR_CONVERSATION_ONLY`, never `PRICE_VERIFIED` or `OFFER_AUTHORIZED`. Do not alter P4 permit or final Accept while addressing this. Write real Lua tests for 0/unknown price and numeric checker-ID absent, malformed inventory, ambiguous partner, and no permission escalation. Only after CI should we connect this one safe handoff to the actual Part3 rotation in a bounded native test. Avoid another historic public-price audit to answer P3 request eligibility.

This finding does not make Stage86 synthetic test results stronger: actual Python planner/guard passed its own limited question only. No user iPad test for this cross-branch source audit.

---

## Stage86 exact-head CI passed — 2026-11-09

**Verified exact code/test SHA `9aa7f54b25bb33af19891b2aa8d36f1ae122d34f`:** [dedicated GitHub Actions 42715946242](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42715946242) **SUCCESS 14/14 real Python integration test groups + 500 seeded offer mutations**. GitHub downloaded actual original **PR106 planner Git blob `78948cdacd2a760db5b888fce242d598fc6f14b6`** and actual **PR105 four-slot offer guard Git blob `c5b87f159de5224d231b111da2541b8b23ac6284`** at fixed reviewed commits and verified exact hashes before importing their actual functions. It demonstrated +5 sidegrade, two→one upgrade, one→two liquid downgrade and failure of stale copied UI gain after item removal, offer revision/stack/slot mutation, swapped partner/job/session, already accepted/pending trade, stale publisher, unproven item link, illiquid/declining received assets. The first CI run caught **one test-harness fixture name shadowing a method**; this was corrected by a test-only rename, not by suppressing tests or altering planner/guard. The second exact-head dedicated run **SUCCESS**, and all five other repo actions (sanitized replay incl. Hypothesis, official Luau, Lune, Selene/StyLua) **SUCCESS** on same SHA. No real MM2 inventory, name, event or network involved.

**What is NOT yet done:** actual native Delta/Roblox Part3 scanner/rotation → Part4 offer placement/withdrawal wiring remains untested and unmodified. This stage proves only **original two Python research modules interoperate with correctly frozen synthetic inputs**. The existing PRs #105/#106 and Stage85 PR155 are separately DRAFT/UNMERGED; avoid stacking blindly. A live manual-final-accept preview must have a clearly reviewed Lua source branch, player/session identity binding, no automatic final Accept and an explicit visible stop condition. No user device test is warranted solely by these Python results.

**Next SINGLE practical issue:** inspect actual current Part3-to-Part4 callback/offer paths and identify the first native safe handoff without resurrecting obsolete +15 rules. Prefer testing one no-trade transition before moving to real item placement; record exact native expectations, fail closed, and only then request one purposeful MAIN/ALT manual test. Keep server completion/profit reporting UNKNOWN and Discord learning OFF.

---

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
