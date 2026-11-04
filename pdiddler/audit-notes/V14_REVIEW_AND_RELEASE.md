# V14 implementation and review record

## Delivered code

This is an additive successor to PR15 b473b55c7f0514134eaaced0824cc396876916a6.
All248 files from that baseline remain byte-identical. V13 readiness protection
and versioned V14 policies/controllers reuse the working startup, physical input,
scanner, exact identities, rotation ledger, bot evidence and P5 transport.

The active build selects consistent first-safe quotes, applies one trade-wide
spending budget, excludes exact received canonical items from its offers, verifies
physical slots, retains accepted outcomes across closure, and supplies independent
raw reconciliation and durable reporting modules. It has one outgoing controller,
one P4 mutator, one lifecycle/completion owner and one outbox.

DoingWell is not automatically treated as adverse/volatile inventory. Explicit
Fluctuating/UnderpaidFor exposure agrees across bundle, candidate and retained-
inventory comparisons. These are source-condition descriptors, not estimated
liquidity losses. Quarter-point comparison bands are deterministic policy choices;
the60% initial region remains a documented heuristic, not an acceptance estimate.

## Root causes reproduced and corrected

| Cause | RED evidence | GREEN coverage |
|---|---|---|
| Readiness caps all hidden descendants before visibility filtering |10,000 hidden labels reproduce exact V12 limit|22 readiness cases; actual visible loading still blocks|
| Moving0.25 tolerance causes candidate-choice drift |Removing unused B changes selected A60/C58|Deterministic selection and permutation cases|
| Unsafe opener and opponent-first use different primary selection |Same holdings/reply produce70 versus40|Shared first-safe policy in production P4|
| Tied early appeal spends needless headroom |7→38 early change with identical ratings|Early hold; least costly genuine improvement; bounded late negotiation retained|
| Same item offered on both sides |Planner includes matching canonical A|Aliases/all copies excluded; add/remove race replans or declines|
| Accepted closure releases rotation without reconciliation |Pair at5s; close5.5s; no post-read|Retained lease in P4, outgoing and hopper guards|
| Evaluated market snapshot loses rawIDs/types |Real P4→lifecycle→V2 report rejects metadata|Raw/canonical IDs and weapon category/type retained; end-to-end fixture reports once|
| Open quote could qualify for outbox |Old `verified=true` flag alone admits it|Distinct completed-report provenance, totals and raw-proof requirements|
| Whole monetary coverage gates raw completion |Unchanged unpriced Common holding blocks report|Exact raw delta separate from subtotal/unpriced coverage|
| Price expiry erases submitted trade proof |Identical post-expiry reconciliation rejected|Identity-bound verified pre-expiry submission preserves valuation version|
| Durability/retry defects |Old O2 sends before storing sending;429120 retries30|Readback journal, serialization, durable transitions, full-delay tests|

## Independent whole-branch review and fix pass

A fresh reviewer inspected all runtime interfaces, fixtures, source preservation,
probe and release wiring. No Critical findings. Four Important findings and one
metadata inconsistency were reproduced:

1. Queue exceptions could echo a private endpoint. Error diagnostics were
   sanitized; throwing and false-return cases passed. Automatic publication review
   subsequently rejected credential propagation into queued source itself. That
   mechanism was removed completely, with a new RED→GREEN assertion that queued
   source contains no runtime credential. Only the public immutable loader URL is
   queued. Private configuration must be supplied independently in each session.
2. Retry deadlines used pre-request monotonic time. Runtime delivery now injects
   absolute wall time sampled afterHTTP; delayed responses and restored queues
   honor the complete server delay.
3. Initial native inventory retrieval preceded GUI lifetime listeners. Listeners
   now precede the yielding boundary; the lifecycle and P4 recheck lifetime/session
   afterward. A close/reopen inside the inventory call cannot offer into the old
   visible lifetime.
4. Enqueue failure discarded a valid completed report. Reconciliation facts,
   inventory and the report are retained and counted once independently of
   reporting availability. A separate report hold prevents unnoticed loss.
5. DoingWell still affected the retained-inventory exposure tuple. It now uses
   the same explicit source-condition meaning as the other comparisons.

Each correction has a failing reproduction and passing regression. No review
minor remains deferred. Additional research/crawls, speculative bot signals,
personal-item targets and price expiry extensions were not introduced.

## Verification and practical limits

37 leaf verification commands passed after the final credential-removal change.
15 added complete runtime sources compile under official Luau0.745;248 protected
blobs and17 immutable dependencies match.20 actual GitHub blob reads independently
match local bytes, covering dependencies, loader, probe and bootstrap.

Current suites include8 strategy,3 early-policy,13 transaction,38 reconciliation/
outbox,36 outgoing,12 actual production-P4,16 storage/transport,21 actual-probe,
24 loader,20 bootstrap and30 policy/oracle cases. The latter independently checks
1,500 generated inventories. Counts include inherited cases and are not independent
native trades or a profit backtest. Full stdout/stderr is preserved separately.

Native MM2/Delta and a real Discord POST were not executed. The production native
contract remains nil because no successful native trace/control/correlation/raw-
inventory adapter evidence was supplied. Automatic Accept/Confirm and live
completed-trade reporting therefore remain disabled. The generic acceptance,
reconciliation and reporting pipeline passes a complete fixture flow, but the
fixture is not a native protocol proof. The exact iPad evidence procedure and
activation requirements are in the test guide.

The existing price snapshot expires2026-11-04T21:42:28Z, unchanged. No claim of
universally optimal negotiation, realized liquidity, measured bot accuracy,
guaranteed profit or repaired native engine loading is made. Native outcomes are
required to compare verified gains per whole session-hour and subsequent exits.
