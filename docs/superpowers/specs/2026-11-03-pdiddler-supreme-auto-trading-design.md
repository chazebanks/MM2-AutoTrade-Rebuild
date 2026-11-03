# Pdiddler Supreme-valued automatic trading — proposed design

Status: proposed for user review; not implemented or live-verified.
Authority: the user's nine-step trading specification supplied November 3, 2026.
Existing bot-test loader and all frozen artifacts remain unchanged.

## Goal and changes to prior rules

Offer one highest-valued eligible own item first, respond to meaningful offer
changes, negotiate profitable trades, accept through native MM2 controls only
after full verification, prove completion, report it once, then resume rotation.

The latest user specification supersedes these older rules:

- Supreme is the operational numeric source; MM2Values is an optional labelled
  comparison, not an alternative source silently selected by a resolver.
- Minimum accepted profit is **+15 Supreme value**, with no raw-loss upgrade
  exception. Desirability cannot waive that floor. The older percentage-based
  profit thresholds do not silently replace it.
- Empty THEIR OFFER expires after **12 seconds**, including a fresh empty period
  after they remove everything. This replaces the earlier 15-second rule and
  the rule that Case 3 permanently suppressed the short empty timer.
- Negotiation considers an improvement after about **5 seconds**. When no better
  safe offer exists, one final **5-second** wait ends in decline if unaccepted.
- Automatic acceptance is the intended completed feature. Existing test builds'
  disabled final-Accept behavior is not a claim that this feature already exists.

The user delegated the overall timer choice. Recommendation adopted in this
proposal: retain a **60-second backstop from their first nonempty offer**, never
reset by changes. It bounds negotiation/indecision, but does not issue a competing
decline after a native completion has begun.

Existing code is not a drop-in implementation: the later manual-Accept observer
does not click either native acceptance control; current valuation rules still
permit the old quality-loss exception; sweetening stops after two steps without
the specified final wait; and empty offers still use the old 15/60-second model.

## Foundation and alternatives

Use new versions extending the later **identity-corrected nonadaptive pipeline**:
canonical scanner identities, proven offer-mutation verification/recovery, market
planner structure, passive completion verification, inventory ledger and webhook
outbox. Add the new Supreme valuation, negotiation and acceptance coordinator.

This is the suitable foundation for the supplied behavior. Patching the V3
loader's older P4 v2.3 would recreate substantial later work. Directly loading the
latest adaptive v6 is also unsuitable: its observe-first/adaptive opener conflicts
with the required immediate highest-item opener and has pending live validation.
Neither a filename nor a frozen label proves a baseline has every later fix:
the frozen v2.6.3 raw-ID/checker-ID market bug must not be reintroduced.

No frozen source is edited, no old loader is silently redirected, and no multiple
planners or competing hoppers are started. The implementation plan will enumerate
and verify every immutable dependency pin and its source identity.

## Valuation and identity

Every priced item retains both identities:

- raw MM2 owned/offer ID for UI actions, quantity ledgers and inventory deltas;
- canonical category/checker identity for the corresponding Supreme profile.

Map category, weapon type and Chroma status exactly. Never use substring names,
DisplayNames, punctuation-stripped player names, conflicting item IDs or a
same-name different-category match as proof. Ambiguity remains unresolved.

Only tradable eligible Godly/Ancient knives and guns, including their valid
Chroma variants, may be offered. Exclude pets, other rarities, Evo/untradable
entries and items without a supported finite Supreme value. Priceless/N/A is not
a numeric zero. Unknown quality metadata gets no invented Stable verification
or positive desirability credit. It must not contaminate known price arithmetic.

Retrieve and validate a complete versioned Supreme snapshot outside active
trades. Proposed operational choice: check publication freshness at startup and
at least every 15 idle minutes; failed or outdated checks block new automatic
trades until validated. Each active trade uses one immutable snapshot version;
never change its price basis mid-confirmation. Report the source publication and
snapshot version. These are source estimates, not guarantees of resale/acceptance.

Per-item values multiply by verified quantities. Native slot capacity is at most
four distinct offered stacks, not an assumption that four displayed slots means
four copies. The opener is exactly one copy. Quantity controls and inventory
limits remain authoritative; malformed nonempty quantity text is unresolved,
never silently quantity one. Noneligible filler may be shown but contributes no
eligible profit credit and cannot hide an unidentified eligible item.

## Ownership and state

One coordinator owns each trade token: server JobId, exact partner UserId,
PlayerGui instance, active trade-root instance, coordinator generation, both offer
signatures, mutation generation and valuation-snapshot version.

States: OPENING → MONITORING / NEGOTIATING → VERIFYING_ACCEPT → OWN_ACCEPTED /
COMPLETION_PENDING → OUTCOME_VERIFY → COMPLETE / NOT_COMPLETE / UNCONFIRMED.
RECOVERY and PROTECTED_HOLD handle interrupted/unverified mutations.

Only the coordinator authorizes offer/accept/decline actions; the executor is
serialized. Every action rechecks the token immediately before it and after any
yield. A pending physical click is not retried until its possible late effect has
been reconciled. Failure to verify never becomes presumed success.

Reacquire current UI nodes rather than retain dead popup references. Support both
known tablet/desktop and phone hierarchies. A hidden inactive layout must not
mask a visible request in another layout. Partner verification uses exact
username/UserId precedence. A replaced trade/GUI invalidates its token and
callbacks; unsupported recreation stops trading safely rather than binding old
callbacks to a new session. P5 is blocked during requests, active trades,
acceptance, completion uncertainty and inventory reconciliation.

## Opening and ongoing planning

Refresh own inventory, select one highest-Supreme-valued eligible priced item,
and add it immediately through the native inventory UI. Do not wait for their
offer. Verify its actual raw identity and quantity in OUR OFFER. Treat this as a
provisional opening: it cannot authorize acceptance before their offer is known
and the +15 floor holds.

Reuse transaction/signature/count verification and recovery logic in new files.
The user specifically calls for physical offering; adding and removing use
current native item controls with bounded late-click reconciliation, rather than
reporting that an intended plan was actually offered.

Every meaningful add/remove/quantity/identity change invalidates the old offer
generation. Reidentify both sides, revalue them and search legal combinations up
to four native slots. Prefer improved inventory trading potential, desirable
items/knives when otherwise comparable, and fewer unnecessary slots/copies.
Quality ranks only plans already meeting the strict Supreme +15 requirement.
Do not introduce a guessed liquidity score; use documented source metadata and
an explicit versioned scoring rule.

A still-safe current offer may stay when no genuinely preferable plan is needed;
their voluntary extra value does not require giving it back. A changed offer
always gets reevaluated, even when the decision is to hold. If all fully resolved
legal combinations fail the +15 requirement, decline rather than negotiate an
impossible trade. Unresolved is distinct from proved impossible: block acceptance
and use bounded resolution/recovery within the trade deadline.

## Negotiation and empty offers

Start the negotiation interval only once the actual offered plan is verified.
After about five seconds without counterparty acceptance, recompute using fresh
offer observations. Move to the nearest genuinely more attractive safe plan;
do not add blindly or repeat an already-applied plan. There is no requirement to
spend all available profit. Every improvement preserves at least +15 and all
identity/quantity/session checks.

When no further safe improvement exists, retain that verified best offer for a
final five seconds; decline if they still do not accept. Their meaningful change
invalidates scheduled improvements and final-wait decisions; reevaluate under
the unchanged 60-second backstop. While they have accepted a valid stable offer,
prioritize the verified acceptance path rather than voluntary sweetening.

For THEIR OFFER empty: start 12 seconds only after our opening is verified; if
they later remove everything, start a new empty period immediately. Decline
immediately on accepted-empty. At a timeout boundary, reread before declining.
Nonempty/empty transitions do not reset the overall 60-second backstop.
Empty means no actual occupied opponent slots. A visible item with unreadable
identity/quantity is unresolved, not an empty offer.

## Native acceptance and invalidation

The automatic acceptance path may start only when both observed signatures match
the plan's valuation inputs, all identities/values/quantities are valid, actual
OUR OFFER matches the intended plan, profit is at least +15, no mutation/recovery
is pending and the exact session/partner/root token is current.

Use MM2's normal initial Accept and final-confirm controls, once each per valid
generation. Respect native cooldowns and confirmation readiness; never bypass
them or treat a local elapsed timer alone as native readiness. After the native
acceptance/confirmation wait has cleared, require **one additional uninterrupted
second**, then fully reread and revalidate both offers and the token before any
final confirmation. Do not use a pre-wait cached approval.

Any meaningful change cancels our previous approval and all scheduled final
confirmation. If already accepted, use MM2's native cancellation and verify that
approval cleared before another mutation. Automatic acceptance does not require
an unrequested rule that the counterparty must accept first. If our accepted
offer is waiting on them, negotiation may resume only after proven cancellation
and another full safety check. No negotiation mutation runs concurrently with
acceptance. Once native completion/processing is underway, freeze actions and
observe outcome instead of racing it with a decline, retry or server hop.

Native server acceptance remains authoritative if network updates race local
observations; the design does not claim a client can eliminate every network race.

## Completion, inventory and webhook

Window disappearance alone never proves success. Outcomes distinguish completed,
declined, cancelled, partner disconnected, unexpected close and unconfirmed.

Reuse the passive completion pipeline: correlated server-complete evidence, or
an authoritative pre/post inventory delta matching the exact raw IDs/quantities
for this trade. Completion listeners must be armed before outgoing requests can
open trades. A zero/ambiguous delta without server proof remains unconfirmed.

The native completion event does not itself carry a checked Trade ID; "latest
candidate seen within three seconds" is not sufficient correlation. Keep one
outstanding completion token, quarantine late events from unresolved sessions,
and require matching inventory evidence whenever event ownership is ambiguous.

Only a proved completed event commits a trade to the ledger. Reconcile the
updated own inventory and Supreme-valued eligible inventory total before starting
another automatic trade; unknown eligible prices make that total explicitly
unverified, not zero. Completion proof and inventory-total verification are
separate facts. If reconciliation fails, preserve the completed event and enter
bounded recovery; do not fabricate a total or reclassify a failed UI close as a win.
Unlike the existing logger, a timed-out inventory read must not send a supposedly
verified updated total. Keep the completion event pending reconciliation instead.

The immutable completion record contains a stable Trade ID, exact items/copies,
Supreme unit/subtotals, demand/liquidity metadata with honest missing markers,
given/received totals, net gain, updated verified eligible inventory total and
valuation version. The total is labelled as eligible tracked inventory, not an
assertion that excluded rarities or unknown-price items were valued.

Send that record through one deduplicated outbox. Never enqueue a completion
webhook for failure/close alone. HTTP faults cannot mutate trades. Bounded retry
and persistent deduplication prevent ordinary duplicate events/posts. Discord
does not provide general exactly-once delivery: a timeout after server receipt
is delivery-uncertain, and must not cause blind retry claiming a once-only
guarantee. Do not configure, print or commit a webhook secret in this work.

After outcome/reconciliation is resolved, mark the exact partner processed for
this server, keep their eligibility record, release P4 ownership and resume the
next unprocessed whitelisted player. The per-server request ledger must survive
safe controller restarts and forbid sending again to a processed/tapped partner.

## Verification and delivery gates

Implement only after design review, in isolated new versioned files and a new
loader. First cover strict Supreme pricing and identity mapping, 4-slot quantity
cases, offer-first opening, all meaningful changes, +14/+15 boundaries, impossible
plans, five-second steps/final wait, 12-second empty resets, accepted-empty,
60-second backstop, duplicate clicks, native acceptance cooldown plus extra second,
changes during that second, partner/root replacement during inventory reads,
late callbacks, completion vs all failure outcomes, inventory reconciliation,
webhook deduplication/uncertain delivery, processed ledger and no-hop ownership.

Reuse requires actual behavioral tests and checked immutable source refs, not
copying a filename or trusting a previous successful recording. Begin acceptance
verification with simulated controls; a live test must clearly identify whether
final acceptance is enabled. Do not silently activate it in the current V3 bot
loader. Review and report offline vs live evidence separately; no automatic merge.

## Proposed choices for review

- Retain 60 seconds from first nonempty offer as the overall backstop.
- Extend identity-corrected existing modules through new versions.
- Follow "physically adds" literally with native UI additions/removals.
- Use a frozen per-trade Supreme snapshot and idle freshness checks.
- Interpret inventory total as the tracked eligible inventory, labelled honestly.
- Treat uncertain Discord delivery explicitly rather than promise impossible
  exactly-once network delivery.

Implementation details left to the builder: exact new filenames/version numbers,
data-fetch adapters and validation format, native UI adapter mechanics, polling
frequencies, deterministic quality scoring, and bounded retry constants. None may
change the stated profit floor, timers, eligibility, acceptance verification or
completion-proof rules.
