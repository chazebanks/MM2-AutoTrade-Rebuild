# Pdiddler P1 v4.4 — Cohort-based incremental observation
Date: 2026-11-03

**Status:** Diagnostic-only; source created and read back on GitHub, not live-tested on Delta.

## Why v4.4
v4.3 repeatedly became INCONCLUSIVE in active normal servers because every join or leave invalidated the whole 90-second test. v4.4 preserves existing player measurements and evaluates only the final cohort found in both appearance snapshots and still present when observation ends.

## New behavior
- One 90-second observation, no global restart.
- Players joining after the start are sampled separately.
- Players leaving no longer invalidate other players' measurement histories.
- A rejoining UserId with a new Player instance resets their player-specific history.
- Each player's animation windows are measured relative to that player's first sample.
- First appearance snapshot targets 20–30 seconds; second targets 70+ seconds and must be separated from first by >=30 seconds.
- Appearance corroboration is recalculated on the **same intersection cohort** rather than mixing roster-wide totals from changing populations.
- Require >=8 matched cohort players for a meaningful group assessment; otherwise INSUFFICIENT STABLE COHORT.
- If a player leaves during final report, result is invalidated.
- One diagnostic only; no trade, hop, or automatic Part 5 handoff.
- Publishes advisory data as `PDIDDLER_P1_COHORT_EVIDENCE_V2` only; explicitly clears incompatible `PDIDDLER_P1_EVIDENCE_V1`.

## Known limits and pending work
- This build does NOT prove mixed-population accuracy. A small matched cohort appropriately produces an inconclusive result.
- The existing Part 1/P5 policy intentionally does not accept the new cohort evidence schema; adapting it requires independent verification and a fully authoritative busy-state snapshot.
- Missing observed animation tracks can occur for legitimate accounts; never treat individual flags as proof of bots.
- If the first appearance snapshot never succeeds, final result is inconclusive.
- The source is statically inspected but runtime tests are still required.
- Validate one labeled bot and normal server; prioritize a normal server with joins/departs and confirm retained cohort counts.
- Do not alter known-good modules or enable hopping based on v4.4 yet.
