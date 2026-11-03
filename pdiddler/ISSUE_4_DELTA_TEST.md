# Issue 4 supervised adaptive build

PR #3 remains rollback. Use only the new V5 adaptive loader in a fresh join;
do not combine it with earlier startup or auto-execute scripts. It physically
offers/removes/declines items, but never clicks or fires Accept.

## Implemented and enabled

Approach C observes 2.5s from the confirmed trade instance. Any visible opponent
item skips speculation, including unresolved items. Otherwise a complete priced
partner inventory bounds a demand/stability-aware reachable opener. Missing or
unreachable inventory still reaches the 12s empty/60s nonempty deadline.

The bounded planner retains appealing same-value alternatives. Initial profit
bands reserve two negotiation steps; demand/stability and preservation order
offers inside the band. This is an explicit heuristic, not a calibrated
acceptance probability. No quality rule overrides +15 Supreme numeric profit.
Sweetening is limited to two steps, five seconds apart, then a final five-second
decision. Manual Accepted freezes mutations; changed approved offers decline.
Four copies total remain the conservative limit.

One scanner, outgoing owner, P4 planner/executor and P5 transport remain active.
Processed-user JobId records, exact usernames, GUI lifetime fences, incoming
request guards and the 45s exhaustion/final-scan hop remain preserved.
Scanner whitelist/UI figures remain MM2Values and are separate from the
explicitly labelled Supreme trade policy; scanner code is unchanged.

## Implemented offline, disabled in Delta

The verification contract tests one uninterrupted extra second after known
cooldown, current identity/count/value proofs and one-use final eligibility.
Completion requires a transaction-correlated event AND exact before/after raw
inventory delta with a verified whole-inventory valuation. The outbox builds
Discord fields, suppresses duplicate IDs, retries explicit 429 responses at most
three times, and retains ambiguous delivery ownership across supplied ledger
reloads. Missing liquidity is labelled unavailable.

These contracts are not a native Roblox adapter. V5 hard-disables automatic
Accept, completion accounting and Discord delivery; environment flags cannot
override that decision. No completion observer/sender is started, so no parallel
owner or webhook can silently consume unconfirmed trades.

Precise blockers:

1. Existing native references observe `YourOffer.Accepted` but provide no proven
   initial/final control and cooldown sequence, including cancellation semantics.
2. The existing `AcceptTrade.OnClientEvent(true)` callback supplies a boolean,
   not a proven transaction/partner/offer identity. A recent GUI snapshot does
   not establish correlation for delayed events. Closure alone proves nothing.
3. `Remotes.Inventory.GetProfileData` / `Weapons.Owned` is referenced, but its
   complete before/after mapping and stable-update timing are not live-proved in
   this build. The scanner values eligible weapons, not every inventory class;
   its total must not be presented as verified whole-inventory value.
4. Persistent outbox storage and Delta HTTP acknowledgement semantics are not
   proved. An in-memory ledger or a lost acknowledgement cannot guarantee
   exactly-once Discord delivery. No credentials are read, printed or committed.
5. Native stacked quantity/slot semantics are unproved; four copies are retained.

Enabling these requires a new reviewed adapter/version and the live evidence
below. A test fixture or a configuration toggle does not satisfy a native gate.

## Snapshot

Fresh source retrieval: 2026-11-03 21:42:28 UTC. Source publication remains
2026-11-02 17:34:27 UTC. Fixed expiry: **2026-11-04 21:42:28 UTC**.
190 canonical rows, 189 finite prices; Priceless is unpriced. Reloading cannot
renew expiry. Refresh only outside trades and publish a new pinned loader.

## Supervised mobile matrix

| Test | Expected | Stop condition |
|---|---|---|
| Fresh join/startup | Tablet picker, ten-second gate, one scanner/queue | Duplicate UI, repeated requests or owner error |
| Empty partner offer | `P4 OBSERVE` then reachable `P4 OPENING VERIFIED` | Immediate highest/unreachable offer |
| Opponent offers within 2.5s | Speculative opener skipped; verified safe plan | Unknown treated as zero or stale opener |
| Unknown/no candidate | Bounded hold, 12s empty or 60s nonempty decline | Guessed price or unbounded loop |
| Stable offer | At most two five-second sweetens, final five-second decision | Repeated additions or profit below +15 |
| Manual Accepted/change | No voluntary mutation; changed approval declines | Mutation while accepted |
| Decline/close/leave/respawn | Recover without completed count or webhook | Success inferred from closing |
| Exhaustion/bot server | Existing P5-only guarded hop | Hop during request, active trade or unknown owner |
| Native evidence capture | Observe both acceptance stages, event arguments, inventory timing | Never enable final auto-Accept to collect evidence |

Record native GUI paths/states, event arguments and before/after raw ID quantities
without credentials. Use a supervised small trade. Observe delayed/duplicate
events, cancellation and disconnect as negative controls before enabling any
completion or delivery adapter.
