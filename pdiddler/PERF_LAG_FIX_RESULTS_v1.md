# MM2 v2.6.1 Lag Fix Results

Date: 2026-11-02
Branch: `fix/mm2-v2_6-lag`

## Status

**PERFORMANCE FIX PRE-LIVE GATE PASSED.**

This build exists specifically to reduce the severe runtime lag reported while testing v2.6. It does not freeze or replace v2.6 as known-good yet.

FINAL ITEM-TRADE ACCEPT remains disabled.

## Root-cause investigation

The first hypothesis was that the new market-aware planner was continuously recomputing.

That was not true.

Part 4 already suppresses repeated planning for an unchanged opponent offer through:
- `lastTheirSig`
- `stableSince`
- `lastBalancedSig`

So the planner is not rerun every 0.12s once an unchanged offer is settled.

The confirmed repeated work was lower in the pipeline:

`evaluateSide -> marketBundleAssessment -> marketLogic.bundleAssessment -> profile lookup + itemAssessment`

`evaluateSide` is called repeatedly from:
- the main active-trade polling loop,
- `txValidate`,
- remove/mutation verification,
- recovery checks,
- apply-plan verification.

Some of those verification loops poll at 0.05-0.08s. They only need raw totals, signatures, slot counts, and identity, but v2.6 still recalculated the same market bundle for the same unchanged offer each time.

That repeated Supreme/MM2/demand/stability work was redundant because the market profile is frozen during the session and the same canonical bundle produces the same assessment.

## Fix

New pure module:
`pdiddler/pdiddler4_market_bundle_cache_v1.lua`

Cache behavior:
- bounded to 64 entries,
- canonical key includes side + page + id + raw value + quantity,
- bundle item order is normalized before keying,
- OUR and THEIR assessments are cached separately,
- same bundle in a new poll reuses the previous immutable market assessment,
- changed bundle computes a fresh result,
- alternate profile input bypasses the cache and preserves original behavior.

Production integration is deliberately outside Part 4:
- the validated market logic is loaded unchanged,
- the cache wraps only `bundleAssessment`,
- all other market API functions are forwarded unchanged through `__index`,
- Part 4 itself is the exact v2.6 integration build.

This means no changes were made to:
- Part 4 polling interval,
- scanner scheduling,
- request ownership,
- transaction generation,
- offer signatures,
- remove verification,
- TX ABORT,
- recovery,
- 15s empty timer,
- 60s Case 3 timer,
- EXTREME GUARD,
- planner rules/ranking,
- final Accept lock.

## TDD evidence

RED:
- test commit `2d18be091a00e5c8b7f7e8b65a86df4b902792e0`
- CI failed because `pdiddler4_market_bundle_cache_v1` did not exist.

GREEN:
- cache implementation commit `03dd37b0f3d49700a38c55d7f7d15e83de077911`
- identical bundle computed once,
- same signature/new eval object reused,
- reversed item order reused,
- OUR/THEIR remained separate,
- changed signature computed fresh.

## New test stack

File:
`pdiddler/pdiddler_MARKET_AWARE_TEST_STACK_v2_6_1_PERF.lua`

Stack creation commit:
`92eddb1d15699510e7e6f86a9414f6d28a4d3da8`

Final CI-tested head:
`b1ef79d8f9ce815a56cfd0b58f1c4a11a33c4088`

It retains:
- P1 -> P2 -> scanner startup order,
- v2.6 market profile,
- v2.6 market logic,
- v2.6 market planner,
- exact v2.6 Part 4 commit `7809aa8c8d210d8005c223eb9fd3a6b3ea716ba5`,
- outgoing v15,
- FINAL ACCEPT disabled.

Only new runtime component:
`marketBundleCache.wrap(marketProfile, marketLogicBase, 64)`

## Official Luau CI

Workflow run:
`41528139709`

Head:
`b1ef79d8f9ce815a56cfd0b58f1c4a11a33c4088`

Result:
**SUCCESS**

Passed:
- official Luau 0.745 install,
- compile market profile,
- compile market logic,
- compile market planner,
- compile cache module,
- compile Part 4,
- compile v2.6 stack,
- compile v2.6.1 PERF stack,
- 14/14 market matrix,
- ranking tests,
- planner integration fixtures,
- 190/190 profile promotion,
- cache performance regression,
- Part 4 static regression guards,
- v2.6/v2.6.1 stack guards.

## Live comparison required

Compare the user's current v2.6 recording against v2.6.1 PERF.

Look specifically for:
- frame-rate/input responsiveness,
- freezes when THEIR OFFER is unchanged,
- freezes during remove/rebalance verification,
- lag when THEIR OFFER changes,
- planner/rebalance behavior unchanged,
- request ownership unchanged,
- scanner behavior unchanged,
- 15s/60s timing unchanged,
- any new console warning/error.

If lag remains severe only when a new opponent offer becomes stable, the next suspect is the one-time planner DP calculation, not repeated bundle valuation. Do not stack another optimization until the recording confirms that pattern.


## v2.6 live before-recording evidence

Recording:
`ScreenRecording_11-02-2026 16-20-03_1.mp4`

Duration:
~3m33s.

This is the **before** recording for the original v2.6 stack, not v2.6.1 PERF.

Observed functional behavior:
- Tablet/startup path completed.
- Scanner reached active state and produced whitelist/blacklist results.
- P3 authoritative request ownership worked.
- A request with no pending proof retained ownership and later ended as `UNCERTAIN TIMEOUT | NO RESEND THIS SERVER`.
- A later request was pending-confirmed and canceled at the 15s no-response boundary.
- Trade with `venossgaming99190` opened and Part 4 became active.
- Rebalancer repeatedly reacted to opponent offer changes.
- Multiple `TX ABORT ... opponent offer changed | modified true` events were followed by `RECOVERY VERIFIED ... our offer cleared`.
- Fresh `REBALANCE VERIFIED` events followed recovery.
- PROFITABLE HOLD appeared in NORMAL / UPGRADE / DOWNGRADE decisions.
- 60s Case 3 boundary declined/rotated.
- Part 3 continued into another trade later in the recording.
- Final item-trade Accept was never executed.

Developer Console:
- 0 script errors visible.
- 2 warnings visible; no evidence they originate from the v2.6 market script.
- console shows the v2.6 active marker and final-Accept-disabled marker.

Important console sequence visible around the first trade:
- REBALANCE VERIFIED
- TX ABORT on opponent offer mutation
- RECOVERY VERIFIED
- fresh REBALANCE VERIFIED
- PROFITABLE HOLD
- another TX ABORT / RECOVERY cycle
- later NO PLAN / 60s rotation boundary

Performance evidence:
- user reported the run as severely laggy.
- the recording's first active trade is the heaviest mutation/recovery sequence.
- this does **not by itself prove** the market bundle assessment is the only source of lag.
- however, it strongly exercises the already-confirmed redundant hot path:
  `txValidate / remove verification / recovery -> evaluateSide -> bundleAssessment`.
- therefore v2.6.1's transparent bundle cache is the correct first isolated performance experiment.

Do not alter planner DP/polling/timers yet.

Next comparison:
run `pdiddler_MARKET_AWARE_TEST_STACK_v2_6_1_PERF.lua` and compare responsiveness during the same active-trade / repeated-offer-change conditions.
