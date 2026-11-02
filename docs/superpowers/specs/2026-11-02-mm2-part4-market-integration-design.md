# MM2 v2.6 Part 4 Market-Aware Integration Design

**Date:** 2026-11-02

## Intent

Integrate the already validated 190-item market profile and pure market-decision engine into the current known-good Part 4 planner without redesigning the trade executor, request ownership, scanner scheduling, timers, transaction generation, recovery, offer verification, or final Accept behavior.

## Proven inputs

Current live/test Part 4 baseline:
`pdiddler/pdiddler4_balancer_ROTATING_v2_3_EXTREME_GUARD.lua`

Validated market profile source:
`pdiddler/pdiddler_market_profile_2026-11-02_v1_CANDIDATE.lua`

Validated market engine:
`pdiddler/pdiddler4_market_logic_v1_TEST.lua`

Validated evidence:
- offline evaluator PASS,
- 14/14 decision matrix PASS,
- deterministic ranking PASS,
- iPad + Delta target-runtime matrix PASS.

## Integration architecture

Use explicit dependency injection from the combined test stack:

`part4.run(scanner, marketProfile, marketLogic)`

The combined stack loads the profile and market engine before Part 4 starts. Part 4 itself performs no HTTP market lookup and contains no duplicated value table.

This keeps the data path:

`scanner canonical item -> exact page:id profile -> market assessment -> planner -> existing transaction executor -> existing verifier`

## Files

Create:
- `pdiddler/pdiddler_market_profile_2026-11-02_v1_VALIDATED.lua`
- `pdiddler/pdiddler4_balancer_ROTATING_v2_4_MARKET_AWARE.lua`
- `pdiddler/tests/pdiddler4_market_integration_static_v1.lua`
- `pdiddler/pdiddler_MARKET_AWARE_TEST_STACK_v2_6.lua`

Do not modify:
- Parts 1-3 known-good files,
- active scanner v6.8,
- outgoing v15,
- Part 4 v2.3 EXTREME GUARD,
- v2.5 combined test stack,
- frozen audit snapshot,
- validated offline matrix files.

## Validated profile promotion

Create a new profile module from the tested candidate rows.

Changes from candidate:
- keep all 190 rows exactly identical,
- set `liveReady=true`,
- add validation metadata identifying the offline matrix and Delta target-runtime pass,
- keep exact `page:id` lookup.

No value/demand/status row may change during promotion.

## Part 4 dependency contract

`M.run(scanner, marketProfile, marketLogic)` must assert:
- scanner API is complete,
- marketProfile is a table,
- `marketProfile.liveReady == true`,
- `marketProfile.get` exists,
- `marketProfile.coverage().total == 190`,
- marketLogic exposes `itemAssessment`, `bundleAssessment`, `tradeDecision`, and `rankPlans`.

If any dependency is missing or malformed, Part 4 must fail to arm rather than silently fall back to the old quality system.

## Old market system removal

Remove from the new Part 4 only:
- `MARKET_QUALITY_UPDATED`,
- `MARKET_QUALITY`,
- `exactQuality`,
- `qualityRatio`,
- old `requiredProfit`,
- old `tradeDecision`,
- old effective-value DP/ranking behavior.

Do not leave both old and new market systems active. There must be one planner authority.

## evaluateSide integration

Keep the current MM2 UI reading, slot resolution, signature, counts, and unresolved behavior.

For every resolved eligible item, build canonical market input:
`{page,id,name,value,qty}`

Exclude ineligible zero-value slots from market assessment.

After the existing slot resolution loop:
- call `marketLogic.bundleAssessment(eligibleItems, side, marketProfile.get)`,
- attach the resulting bundle as `out.market`,
- expose compatibility aliases only where necessary:
  - `out.protectedTotal = out.market.protectedTotal`,
  - do not recreate multiplier-based effective value.

The existing raw `out.rawTotal`, `eligibleCopies`, `signature`, and `counts` remain authoritative for executor verification.

## Current-offer decision

A thin Part 4 wrapper calls:

`marketLogic.tradeDecision(ourEval.market, theirEval.market)`

The wrapper may expose compatibility fields for existing EXTREME GUARD/logging:
- `effectiveProfit = protectedProfit`,
- `rawRequired = requiredProfit`,
- `effectiveRequired = requiredProfit`.

No old market multiplier logic remains.

## EXTREME GUARD

Preserve behavioral semantics:
- only applies to normal profit decisions,
- ratio threshold remains 2.0x,
- flat surplus threshold remains 50,
- required-profit multiple remains 2.5,
- minimum upward replan step remains 5,
- moderate overpay is held,
- extreme overpay may move OUR offer upward only to another safe market-aware plan.

Use protected profit as the second safety dimension formerly called effective profit.

## Planner units and DP

Each own inventory unit carries:
- canonical page/id/name,
- raw MM2 value,
- protected OUR-side value,
- exit score,
- disputed flag,
- unprofiled flag.

The planner still considers at most 4 eligible copies.

For DP states, do not collapse every equal-raw-total combination to one pack using the obsolete effective multiplier.

Use a market-aware state key containing:
- raw cents,
- protected cents.

For the same raw + protected state, keep the strategically preferable pack:
1. lower weighted exit score (better weak inventory to give away),
2. fewer disputed copies,
3. fewer unprofiled copies,
4. deterministic canonical pick key.

This preserves alternative packs when source disagreement changes protected value while bounding state growth.

## Candidate decisions

For each DP pack:
- construct an OUR bundle assessment from the pack metadata,
- call validated `marketLogic.tradeDecision`,
- retain only passing plans.

Each plan must expose:
- `ok=true`,
- `picks`,
- `units`,
- `rawTotal`,
- `protectedTotal`,
- `rawProfit`,
- `protectedProfit`,
- `requiredProfit`,
- `baseRequired`,
- `marketPremium`,
- `kind`,
- `mode`,
- `qualityGain`,
- `givenExitScore`,
- `disputedCopies`,
- `unprofiledCopies`.

Then call:
`marketLogic.rankPlans(plans, theirEval.market)`

No independent ranking copy is allowed in Part 4.

## Existing executor/verifier behavior that remains byte-for-byte or logically unchanged

- trade GUI discovery,
- partner verification,
- opening one highest-value eligible item,
- accepted-empty immediate decline,
- 15s empty timeout,
- 60s active offer window,
- offer generation/signature invalidation,
- `txValidate`,
- physical remove flow,
- late-remove guard,
- one bounded remove retry,
- `clearOurOffer`,
- `applyPlan`,
- exact plan verification,
- TX ABORT on opponent changes,
- protected recovery,
- recovery retry limits,
- trade-close handling,
- request-state ownership,
- Part 3 handoff/resume,
- final Accept disabled.

## Logs

Keep diagnostics concise.

Replace old "EFFECTIVE" terminology with "PROTECTED" / "MARKET" in new planner logs.

Important logs should show:
- raw OUR/THEIR,
- protected OUR/THEIR when relevant,
- raw/protected profit,
- required profit,
- market premium when nonzero,
- decision reason for NO PLAN / hold,
- EXTREME ratio/replan.

Do not print all 190 profiles.

## Failure behavior

- missing market dependency at arm time => fail Part 4 arm,
- missing exact profile for a resolved eligible item => pure market engine handles it as unprofiled; no positive quality credit,
- malformed profile => safe fallback through pure engine,
- opponent changes => existing transaction cancellation/recovery,
- planner exception => no offer mutation from that decision,
- live profile is never fetched during a trade.

## Test strategy

Before live testing:
1. promoted profile 190/190 exact-row equality check against validated candidate,
2. static integration test confirms old market table/functions are absent,
3. static test confirms executor/remotes/timer constants remain present and unchanged,
4. pure integration fixtures exercise current-offer decisions and planner ranking using the integrated wrappers,
5. compile/load Part 4 in a stubbed Roblox environment where practical,
6. build a new combined stack pinned to exact commits,
7. verify no `AcceptTrade` or final Accept click exists.

First live test must remain observation-only regarding final completion: Part 4 may rebalance/decline exactly as v2.5 did, but never final-Accept.

## Success criteria

Integration is ready for an iPad recording only when:
- profile promotion is exact 190/190,
- market matrix remains 14/14,
- new Part 4 has one market authority,
- planner uses validated market engine,
- executor/recovery/timers are not redesigned,
- EXTREME GUARD semantics remain,
- v2.5 files are unchanged,
- new stack is pinned,
- FINAL ACCEPT remains disabled.
