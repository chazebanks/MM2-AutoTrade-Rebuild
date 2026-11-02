# MM2 v2.6 Market-Aware Part 4 Integration Results

Date: 2026-11-02
Branch: `feature/mm2-market-aware-part4-v2_6`
Integration base: `26aec153b5b0b29500391a3cb4e67a35f4303db2`

## Status

**PRE-LIVE INTEGRATION GATE PASSED.**

This is a TEST BUILD. It is not frozen as known-good until an iPad + Delta live-trade recording is reviewed for both successful behavior and regressions.

FINAL ITEM-TRADE ACCEPT remains disabled.

## Architecture

The v2.6 stack injects four dependencies:

`part4.run(scanner, marketProfile, marketLogic, marketPlanner)`

Market pipeline:

`scanner canonical identity -> exact page:id profile -> pure market decision engine -> standalone planner -> existing Part 4 transaction executor/verifier`

No live Supreme/MM2Values HTTP request occurs inside a trade.

## Files

Validated profile:
`pdiddler/pdiddler_market_profile_2026-11-02_v1_VALIDATED.lua`

Pure market engine:
`pdiddler/pdiddler4_market_logic_v1_TEST.lua`

Standalone pure planner:
`pdiddler/pdiddler4_market_planner_v1.lua`

New Part 4:
`pdiddler/pdiddler4_balancer_ROTATING_v2_4_MARKET_AWARE.lua`

Combined test stack:
`pdiddler/pdiddler_MARKET_AWARE_TEST_STACK_v2_6.lua`

Immutable stack commit:
`bc2deeeffbd7d77bd933d2f11b2e0bea9c13de15`

The stack internally pins the integrated market modules to:
`7809aa8c8d210d8005c223eb9fd3a6b3ea716ba5`

## Market profile verification

The validated profile was promoted from the tested candidate profile.

Result:
- Candidate rows: 190
- Validated rows: 190
- Row mismatches: 0
- Ancient: 16/16
- Chroma: 46/46
- Godly: 128/128
- Total: 190/190
- `liveReady=true`

No market value, demand, stability, identity, or disagreement row changed during promotion.

## Market logic evidence retained

Previously verified:
- offline evaluator PASS,
- decision matrix 14/14 PASS,
- deterministic ranking PASS,
- iPad + Delta target-runtime matrix PASS.

Critical examples remain:
- Emberscythe MM2Values 300 / Supreme 375,
- Chroma Mortal MM2Values 1800 / Supreme 1600,
- low-tier 5 vs 7 does not become material solely from percentage,
- missing metadata receives no positive quality credit,
- weak downgrade premiums are conservative,
- moderate opponent overpay remains valid,
- EXTREME-compatible decisions expose raw/protected profit safely.

## Planner integration

The planner is a standalone pure module:
- no `game:GetService`,
- no RemoteEvent/RemoteFunction,
- no HTTP,
- no GUI,
- no scheduler.

It:
- keeps raw MM2Values and protected market value separate,
- keeps same-raw / different-protected states separate,
- ranks safe plans using the validated market engine,
- prefers giving away weaker exit-quality inventory inside the similarity band,
- preserves deterministic canonical tie-breaking.

Startup order is deliberately preserved as P1 bot check -> P2 Tablet/startup -> scanner load -> market modules/preflight -> Part 4/outgoing. Preflight fixtures run before Part 4/outgoing arm:
- profile coverage 190/190,
- OUR Emberscythe protected at 375,
- moderate 230 -> 270 keeps the 230 offer (+40),
- extreme 20 opening with 90 available vs 105 chooses 90 (+15),
- uncertain/unprofiled 100 -> 43+44+43 has no safe BIG DOWNGRADE plan,
- equal-value Embersickle/Pearlshine gives away the weaker Embersickle first,
- raw 300 with protected 300 vs 375 remains two distinct planner states.

## Canonical identity hardening

Part 4 now uses canonical `page:id` for:
- live offer counts,
- planned offer counts,
- duplicate-slot verification,
- resolver ambiguity checks,
- transaction signatures include page.

This prevents a same-ID collision on different scanner pages from being treated as the same trade item.

## Retained executor behavior

Verified against Part 4 v2.3:
- `txValidate` unchanged,
- `waitForOurOfferMutation` unchanged,
- `clearOurOffer` unchanged.

The `applyPlan` mutation/retry flow is retained; its intentional identity change is the duplicate-slot lookup moving from bare `id` to canonical `page:id`.

Retained constants:
- Empty timeout: 15s
- Case 3 active window: 60s
- Recovery max attempts: 2
- EXTREME ratio: 2.0x
- EXTREME flat floor: 50
- EXTREME required-profit multiple: 2.5
- EXTREME minimum upward replan step: 5

Retained behavior:
- one highest-value eligible opening item,
- accepted-empty immediate decline,
- transaction generation/signature invalidation,
- TX ABORT,
- late-remove observation guard,
- one bounded remove retry,
- recovery / protected hold,
- Part 3 rotation handoff,
- FINAL ACCEPT disabled.

## Removed duplicate/obsolete market logic

The new Part 4 does not contain:
- `MARKET_QUALITY`,
- `exactQuality`,
- `qualityRatio`,
- old multiplier-based effective-value logic,
- duplicate `NormalMinFlat` / downgrade / big-downgrade / upgrade-cap planner thresholds,
- a duplicate local `buildPlans`,
- a duplicate local `makeUnits`,
- dead `marketProfileRecord` / `marketItemAssessment` helpers.

There is one market decision authority.

## Official Luau CI

Workflow:
`.github/workflows/mm2-market-integration-ci.yml`

Official Luau version:
`0.745`

Final tightened pre-documentation head:
`0752ccc1da23b39e8e55e346297134146bacc227`

GitHub Actions run:
`41525905272`

Result:
**SUCCESS**

Successful steps:
- Install official Luau 0.745
- Compile market integration modules
- Compile combined v2.6 stack
- Run pure market integration tests
- Static Part 4 regression guards

Static guards verify:
- dependency injection contract,
- exact canonical identity markers,
- timers and EXTREME thresholds,
- transaction/recovery functions remain present,
- old market system absent,
- duplicate planner logic absent,
- dead market helpers absent,
- final Accept absent.

## Final-Accept audit

No `AcceptTrade` call is present in the new Part 4 or combined stack.
No physical final Accept click is present.

**FINAL ITEM-TRADE ACCEPT IS DISABLED.**

## Remaining gate

The next and only planned gate for this build is a real iPad + Delta recording using the immutable v2.6 stack.

The recording must be reviewed for:
- startup/preflight errors,
- request ownership regressions,
- scanner contention,
- first-offer behavior,
- market-aware plan decisions,
- opponent-offer decreases,
- TX abort/recovery,
- duplicate quantity handling,
- moderate overpay hold,
- EXTREME replan,
- 15s/60s timer behavior,
- trade close/rotation,
- duplicate sends/actions,
- any console error or warning attributable to pdiddler.

Do not freeze v2.6 as known-good before that recording review.


## Startup-order regression fix

The first v2.6 stack draft ran market-module/preflight work before the frozen P1/P2 startup sequence.

That ordering was rejected because it could:
- perform extra HTTP/module work before the bot avoider,
- delay or interfere with the known-good Tablet/startup selector,
- change the startup timing that v2.5 had already proven.

Corrected immutable stack:
`bc2deeeffbd7d77bd933d2f11b2e0bea9c13de15`

Corrected order:
1. Part 1 known-good bot avoider,
2. Part 2 known-good Tablet/startup selector,
3. scanner v6.8 load,
4. validated market modules + preflight,
5. Part 4 market-aware arm,
6. outgoing v15 arm.

CI run `41526118216` on the corrected stack commit completed successfully:
- official Luau 0.745 install: PASS,
- compile integration modules + combined stack: PASS,
- pure integration tests: PASS,
- static Part 4 regression guards: PASS.

Use only the corrected stack for the iPad live test.
