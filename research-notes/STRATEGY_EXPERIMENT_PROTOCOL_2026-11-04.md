# How to establish whether a strategy improves the current trader

Baseline: PR #14 at `b92348125372026393c3815ecabbc8f3be1df32b`. This is a research specification, not active instrumentation or permission to enable native actions. Preserve the same eligible Ancient/Godly/Chroma classes, Supreme+15 floor, conservative four-copy limit, native readiness and ownership/completion guards for every comparison. The separate personal acquisition roadmap never enters a policy arm.

## Questions and staged comparisons

Do not roll all suggestions into one unexplained new score. Start with shadow evaluation of the exact current policy, then compare one change at a time:

| Comparison | Exact hypothesis | What would disprove its value |
|---|---|---|
|Trade-wide ledger versus current per-signature allowance|Equivalent economic edits no longer trigger repeated spending without extra value|Lost completed gains from genuine improved offers outweigh avoided concessions, or safety rebalancing is obstructed|
|Consistent value-exposure metrics and retained-inventory alternatives versus current summaries/pruning|Equivalent giveaway plans retain better future options without unnecessary state growth|No improvement in subsequent exits/options, excessive computation or useful candidates lost to new pruning|
|Quote-grid-aware opening versus current 60%/fallback|Some disconnected safe quote regions deserve consideration at the start|Greater surrendered surplus and cooldown cost exceed the additional verified completions|
|Published-range/anchor review versus base-only acceptance eligibility|Incoming downside/exposure is reduced|The filter mainly rejects profitable opportunities without reducing subsequent exit losses|
|Bounded first-offer assembly versus immediate no-plan decline|Slow legitimate assembly is retained|Added waiting outweighs recovered safe completed trades or creates any unapproved mutation|

The control is the actual V11 path, not November 3's old band-first/five-second model. Experimental quote-region/budget thresholds must be explicit and approved before native comparison. No arbitrary acceptance probability is assigned to them.

## Stage 1 — deterministic and shadow checks

1. Reproduce the six published policy experiments and verify the three source blobs. These prove selection/measurement behavior, not returns.
2. On recorded known-input snapshots, calculate current choices and proposed alternatives without acting. Keep every candidate's exact quantities, +15 proof, metadata completeness, post-trade features and pruning/budget reason.
3. Verify hard negative controls:14.99 fails,15 passes; unknown/priceless is never zero; Chroma/normal and raw/checker identity remain separate; >4 copies remain unsupported; stale profiles block new actions; failed verification does not commit spending; opponent edits invalidate approvals; no GUI-close profit or webhook.
4. Measure compute separately from inventory/network/UI time. A state-budget failure is an explicit failure/hold outcome, not a zero-profit completed trade or an optimum found.
5. Shadow scoring cannot reveal whether an unoffered alternative would have been accepted. Label counterfactual acceptance unknown.

No new strategy acts until these checks pass in a separate draft engineering build. Only one planner/controller owns each action.

## Stage 2 — supervised native outcome evidence

Automatic final Accept/Confirm, completed-trade accounting and Discord are still OFF in the baseline. First establish real native controls, offer-finality semantics, correlated transaction/partner identity and exact stable raw inventory deltas. A user manually completing a normal trade can provide evidence; narration, one Accepted indicator and a disappearing GUI cannot substitute for it.

Use the same source version and known starting inventory for paired snapshot comparisons. For native sessions, match inventory bands, source age, eligibility rules and server cohorts as closely as possible. Predefine the policy assignment before seeing the outcome. Assign one complete strategy per trade/session; do not let two offer planners compete or alternate opportunistically after a bad result.

Repeated traders, servers and changing inventories create dependence and selection bias. Report session/trader clustering and inventory-path differences; a simple independent coin-flip model is not justified. Randomization or blocked assignment must be operationally feasible and reviewed. No universal sample size or guaranteed stopping date is prescribed. Choose a minimum worthwhile difference and uncertainty method before deployment; do not stop after a selected winning screenshot.

## Minimum event record

These are proposed fields; no logging adapter is implemented by this PR:

- `build_sha`, policy ID/parameters, source version and publication/observation/expiry times.
- `server_job_id`, trade-session ID, partner identity/generation, inventory version and exact raw/canonical IDs, categories, variants and quantities.
- Monotonic event time and event type:eligible discovered, request initiated, request failed/timed out, trade opened, opponent offer changed, quote proposed, actual quote verified, mutation failed, approval changed, decline/cancel/leave, native evidence received, inventory reconciled, outcome unconfirmed.
- Before/after actual offer signatures; given/received totals; strict-profit proof; intended versus observed counts; current and cumulative verified concession; native cooldown/readiness state; technical versus voluntary mutation reason.
- Candidate features:post-trade demand-threshold values, status-specific exposure, known-range scenarios, concentration, one-to-four-copy capacity, denomination/set changes and unavailable fields.
- Outcome proof references, exact raw before/after deltas, stable-read coverage and valuation scope. Native-unconfirmed/ambiguous cases remain explicit, not manufactured completions.
- Time components:discovery, loading/gate/hop, request wait, assembly, planning, inventory read, apply/readback, cooldown, approval and terminal recovery.

Store enough information to reproduce decisions. Do not let a proposed telemetry path alter controller ownership, completion truth, expiry or outgoing rotation.

## Metrics and denominators

| Metric | Numerator / denominator | Interpretation limits |
|---|---|---|
|Request response|Responses / all initiated requests, with failures/timeouts retained|Separate trade opens from any response; no completed-profit inference|
|Verified completion|Proven completions / all assigned eligible trade opens|Report request funnel separately; native-unconfirmed cases cannot disappear from the denominator|
|Verified value gain|Sum of same-version received−given across proven completions|Marked-to-list trade gain, not cash or a price-update return|
|Gain per session-hour|Verified gain / all elapsed session time, including zero-gain sessions|Include loading/hopping/recovery; report unresolved cases and possible losses separately rather than assuming zero|
|Concession efficiency|Additional verified completions/gain versus verified value surrendered and time added|A concession observed before success is not proof it caused success|
|Exit quality|Subsequent verified exits, holding duration, required discount relative to the recorded scale, and failed attempts|Still-held inventory is censored; missing exit is not automatically worthless or liquid|
|Inventory composition|Demand-threshold values, status exposure, compact capacity, concentration, denominations/sets|Descriptors, not calibrated expected returns; show conflicting dimensions|
|Missed safe opportunity|A known+15 candidate existed but failed/no action/budget limitation occurred|Does not prove a partner would accept it|
|Safety/reliability|Wrong/stale actions, unresolved outcomes, mutation/readback failures, duplicate events and hangs / all relevant opportunities|Any violation blocks promotion; no profit can excuse below+15 or unproved completion|

Keep gifts, creator/friend interventions, manual policy overrides, pricing changes and unrelated inventory changes separately labelled. Do not learn a repeatable trader's acceptance or gains from these exceptional cases.

## Stage 3 — acquisition and exit chains

An incoming bundle can increase today's list total and reduce tomorrow's opportunity set. Follow the received items through later offers/exits with their true holding time and source versions. A profitable downgrade followed by an unprofitable upgrade violates the approved every-leg+15 rule and is not a valid successful path for this bot.

Until native evidence exists, evaluate structural possibilities only:feasible next offers within four copies, retained anchors/adds, known-range exposure, equal-stat alternatives and denominator completeness. Do not call these structural checks a historical backtest or sustained-profit result.

## Promotion rule

Retain the current build until a separately reviewed change demonstrates correct hard gates, no execution regressions, a defensible improvement on the predefined session/exit metrics and uncertainty that is honestly reported. A stronger quality average or a single large win is insufficient. Unresolved native behavior stays disabled; the original price expiry remains binding.
