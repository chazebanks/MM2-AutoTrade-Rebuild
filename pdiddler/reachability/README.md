# Issue24 Problem A — outgoing reachability (V15.4)

## Cause and change

V15.3's outgoing `nextTarget()` consumes every unprocessed scanner-whitelisted player. Whitelist means eligible rarity, not a possible +15 trade. Its loader separately treats every whitelisted player as hopper availability, and blanket pending scanner work can prevent exhaustion forever. The actual scanner parser/current repricer reports Seer3; the production planner finds no +15 plan against a positive owned giveaway; the old queue still selects that player.

V15.4 leaves scanner rarity eligibility intact and adds a separate outgoing assessment:

- **reachable / verified-feasible-witness**: a concrete owned single giveaway and up to four distinct opponent weapon entries, one copy each, passes the existing production planner and +15 policy. It is evidence of economic feasibility, not a proposed opener or transaction success.
- **unprofitable / profit-unreachable**: every possible owned single giveaway fails even against all verified eligible opponent quantities excluding the same canonical identity. This deliberately optimistic upper bound proves impossibility. Positive values imply any feasible larger giveaway contains a cheaper feasible single.
- **unknown / specific verification reason**: incomplete/malformed/missing/unpriced inventory, active target scan, stale ownership, unsupported stacked-slot opportunity, or planner failure. A failed witness search alone never proves impossibility. Normal/Chroma identities remain separate; unknown/Priceless values are never substituted.

All classes remain visible in the existing scanner's row details, independently of rarity eligibility. Request/processed states retain display priority. Skips are not outgoing attempts and never enter the processed ledger.

## Bounded unknown policy

Each exact present unprocessed Player gets a fixed30-second unknown episode. Retries, changing unresolved fingerprints, or scheduled/active scans do not extend it. Thereafter the class stays **unknown**, reason `verification-unavailable` with the original cause; requests stay blocked, but the player ceases blocking exhaustion. Processed players' rescans never block exhaustion.

Own reads use the existing guarded RPC (4.5-second timeout), at unknown episode offsets0,5,15 then45,90,... without overlaps or catch-up bursts. Incomplete successful RPC responses and known-empty eligible own inventory use the same backoff. Successful own snapshots refresh at5 seconds and expire at10 seconds. Existing opponent scans/retries are preserved; `hasPendingWork` remains available but no longer acts as an unlimited global exhaustion blocker.

The45-second exhaustion clock advances only while verified exhausted; initial unknown verification, request/trade ownership and global guards pause it. Only a new reachable transition resets it. Identical cache recovery does not create a new opportunity. Current roster/classifications are checked during the existing final2-second recheck and actual P5 transport guard. Global expiry/readiness/native-UI/transaction/controller holds NEVER age out.

## Final input authorization

After reserving the exact outgoing target, capture exact Player/UserId, both inventory fingerprints, JobId, profile version, current PlayerGui and outgoing/P4/lifecycle ownership. Card navigation preserves this token. Immediately before input, perform a fresh own read; a changed or unavailable inventory aborts. After all visibility/coordinate/card preparation, a non-yielding predicate revalidates the token, exact native player card, current target scan state, own snapshot age and fresh prices immediately before mouse-down. Abort produces neither a Trade click, a retry of that input, a failure attribution nor a processed mark. Existing post-tap timeout and ownership protections remain.

This is a local evidence fence. It cannot make asynchronous MM2 server inventories atomic or prove native input delivery.

## Preserved behavior and known limits

All342 files at PR23 `a4d68f5b6a4dd7b4bd20bc99660a5600d04a0311` remain byte-identical. The scanner derivative adds only a read-only evidence API; its catalog, scans, retries and GUI are unchanged. P1, P2, P4, economic concession rules, P5 navigation, native readiness, final Accept and Discord-completion capability gates remain unchanged. The new loader uses distinct owner keys and refuses previous-build owners in the same JobId.

Supreme version: `supreme-2026-11-04-97613e277b36`. Expiry is unchanged: **2026-11-05 21:55:32 UTC (4:55:32 PM EST)**. No price refresh or expiry extension is included. New trading is blocked after expiry.

Only supported nonstacked witnesses authorize outgoing requests. Players needing unverified stacking stay unknown by the user's selected policy. This can skip real opportunities until native stacking is established; it does not label those players unprofitable.

The separate Common-item P4 stall, opener/rebalance strategy and native finalization are deliberately not fixed here. No inventory gains, completed trades, acceptance-rate improvement, webhook delivery or successful native hopping are claimed.

## Reproduce

With official Luau0.745 and Lua5.4 (texlua also used locally):

```
LUAU_BIN=/path/to/luau LUAU_COMPILE=/path/to/luau-compile python3 pdiddler/tests/run_issue24_checks.py
```

The gate preserves the complete inherited37-command V14 suite and V15–V15.3 tests, checks all342 predecessor blobs and immutable runtime pins, compiles all successor runtimes, and runs targeted production scanner/planner/queue/input/loader/bootstrap cases. `RED_BEFORE.txt` retains failures against original code; `OFFLINE_RESULTS.txt` retains final output. Historical fixtures use an explicit as-of profile only in tests; runtime freshness is never overridden.

## iPad verification required

Use only the final immutable entry in BUILD.md, older Auto Execute entries disabled, in a fresh MM2 JobId and before expiry. Record the scanner, native slots/request UI and developer-console transitions.

1. Seer3 stays visibly eligible but outgoing-unprofitable; no request. A verified reachable target receives one physical request.
2. Let a request remain unanswered; verify processed/ignored/uncertain classification and no resend, never a completed-trade count.
3. Rescan changed inventory or a new player; confirm a newly reachable target enters rotation. Confirm rotation resumes after a trade closes.
4. Observe unknown verification age-out and45-second exhausted countdown, then actual transport/re-entry with one owner and headless detector.
5. Exercise inventory/partner changes during card navigation; verify safe abort and scanner reason with no stale Trade click.

Do not infer any successful final transaction from a disappearing window.
