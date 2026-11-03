# Pdiddler Part 1 — v4.2 integration safety checkpoint (2026-11-03)

## Immutable references
- Frozen original gate: `pdiddler/pdiddler1_KNOWN_GOOD.lua` blob `193d0319d54a3309fda338bdd054eb2f94b9190b`.
- Last user-tested observer: `pdiddler/pdiddler1_bot_detector_TEST_v4_1.lua` blob `53746433f22304458749d177a208515cd79e9b07`.
- Part 5 transport candidate is on `feature/mm2-server-hopper-design`. Do not merge or replace it blindly.

## Evidence
Labeled v4.1 test: 11-player bot server; 7 confirmed review, 2 unknown, both appearance checks positive, combined pattern. Labeled 10-player normal server: 0 animation review, 0 unknown, both appearance checks negative. Small sample; not an estimated true false-positive rate.

## New files on branch `feature/p1-bot-gate-safety-v1`
1. `pdiddler1_bot_detector_TEST_v4_2.lua`: observed-data compatible v4.1 measurements; additionally captures initial, intermediate, and final UserId membership, latches any observed join/leave, and publishes `getgenv().PDIDDLER_P1_EVIDENCE_V1`. Read-only, **90 seconds**, no hop, no trade.
2. `pdiddler1_p5_handoff_policy_v1.lua`: pure policy, three states `HOLD`, `ALLOW`, `REVIEW`. `REVIEW` is *advisory*, not authority to hop. Exact stable membership, fresh evidence (15 sec), two positive appearance snapshots, minimum review-group thresholds and known-safe state required. Incomplete/stale/changed population yields `HOLD`.
3. `pdiddler1_p5_handoff_adapter_v1.lua`: opt-in Part 5 integration boundary. Must receive a fresh *authoritative* `readyCheck` from integrated Parts 3/4 and existing Part 5 controller. Defaults disabled; checks readiness twice, enforces a local hop lock, delegates the teleport exclusively to existing `controller:hopNow()`.
4. `pdiddler1_p5_handoff_policy_TEST.lua`: 19 pure-policy test cases for membership, busy conditions, missing/loading evidence, stale sessions, appearance corroboration and normal-server behavior.

## Intentional limitations
- **No code here has been tested live in Roblox/Delta.** A GitHub file readback and source audit do not demonstrate runtime correctness.
- The tests are runnable Luau checks, not proof of a completed test run. Run the suite in a sandbox before deployment.
- The adapter cannot infer P3/P4 busy state safely. Do not supply a placeholder `readyCheck` that always returns ready.
- The observer's appearance scans use an independent subset of the original gate's rules, NOT exactly its entire score. Do not claim original gate agreement.
- The observed missing-animation-track pattern can reflect replication. It is not an individual bot identity verdict.
- Voice-chat absence, wall proximity and jump counts are **diagnostics only**, not server rejection criteria.
- If player membership changes anywhere in observation, a new observer session is required; a stable final roster alone does not restore confidence.
- One observer owns its session. Starting a new run supersedes the old generation. Old results cannot pass adapter's current-generation check.
- No automatic hopping has been enabled. Unknown/inconclusive situations fail closed.
- Part 5 has its own teleport and auto-execute uncertainties; evaluate separately.

## Future live acceptance tests
1. Run v4.2 on at least two additional labeled bot and two additional labeled normal servers, including variable player movement.
2. Add a legitimate player mid-observation: published `stable=false`, handoff `HOLD`.
3. Make a player leave and return: membership-change latch must remain set.
4. Begin observation then open an outgoing request/trade: authoritative readyCheck must prevent any handoff.
5. Start a new observer before old one finishes: stale generation must not publish valid evidence.
6. Observe and inspect the entire 90-second report. Test Part 5 handoff separately only after the readiness API is confirmed.
7. Ensure one and only one teleport owner, no repeated calls, correct fallback/recovery and Delta auto-execute behavior.

## Loader (read-only test)
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/feature/p1-bot-gate-safety-v1/pdiddler/pdiddler1_bot_detector_TEST_v4_2.lua",true))()
```

## Policy test loader
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/feature/p1-bot-gate-safety-v1/pdiddler/pdiddler1_p5_handoff_policy_TEST.lua",true))()
```
