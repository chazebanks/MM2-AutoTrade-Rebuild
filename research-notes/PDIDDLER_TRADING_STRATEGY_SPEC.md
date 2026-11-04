# General-purpose inventory-growth strategy — research specification

Status: proposed, **not implemented or approved for deployment**. Engineering
baseline: Issue #4 draft PR #5 at `4b5c6d9095d21643349cee32d43719e515e294d1`.
Purpose: complete strictly profitable trades while preserving useful inventory.
No personal acquisition objective, named-item scoring exception, owner hunting,
target stop condition or wishlist belongs in runtime configuration or telemetry.
All items must pass the same generic rules.

## 1. Authoritative inputs and interfaces

`MarketSnapshot` contains immutable version, source publication/observation/expiry,
authorization status and canonical records: category, checker ID, exact name,
native type/class if verified, finite base value, demand/status, optional range,
optional flippability and optional provenance-labelled history. Missing fields are
distinct from zero. Source probabilities are not calibrated execution probabilities.

`InventorySnapshot` contains session/owner/time, raw MM2 Weapons IDs, canonical
mapping, quantities, native tradability, completeness flags and inventory version.
`OfferSnapshot` contains exact partner UserId/username, GUI lifetime, session and
offer generation; ordered actual slot contents/quantities; canonical totals and
signatures; both native Accepted indicators; mutation state and known cooldown.
`CandidatePlan` has raw action IDs, counts, at most four total copies until native
stacking is proved, canonical totals, risk/quality facts and deterministic key.
`Outcome` separates request failure, declined, cancelled, left, respawned,
unexpected close, unconfirmed and proven completion.

One resolver is authoritative from scanner to parser to executor. Exact category
and checker ID establish price identity; raw ID establishes ownership and native
action identity. Contradictory raw ID/name/class is unresolved. Aliases can help
human lookup but cannot override raw identity, Chroma status or category.

Supreme is the sole operational numeric scale. Other publishers supply labelled
disagreement signals only. Never select the higher received/lower given cross-list
price. Never multiply demand by a fictional cash/liquidity factor.

## 2. Hard safety and risk gates

Apply in this order to every opener, plan, mutation and acceptance check:

1. Verify authoritative controller, JobId, partner, exact username, GUI ancestry
   and visible-lifetime generation. Fence stale callbacks after every yield.
2. Verify source authorization and current immutable snapshot. Retain the current
   engineering limits: retrieval age at most24h and publication age at most72h;
   check at startup and idle intervals of at most15min. These are **engineering
   defaults**, not experimentally optimal staleness thresholds. No price refresh
   inside a trade; expiry blocks new offers and allows a bound-identity decline.
3. Require complete known mapping, native tradable Knife/Gun and approved rarity,
   valid integer quantities within actual owned counts and no duplicate raw rows.
   Unknown, Priceless, unsupported class, hidden source rows and incompatible
   metadata do not enter arithmetic as zero.
4. Compare integer cents: `received_base − given_base >= 1500`. Never permit raw
   loss or a quality-upgrade exception. Reprice both sides from the same version.
5. Record cross-source disagreement if absolute difference is at least15 **and**
   relative difference is at least10%. This proposed conservative **review flag**
   triggers protected HOLD for new automatic intake until identity/freshness is
   rechecked; it is not evidence that10% predicts losses. Any identity conflict
   blocks independently of magnitude. Low-value percentage-only differences are
   diagnostic, not permission to change the chosen scale.
6. For items with published numeric ranges, calculate a separate downside
   scenario: incoming lower bounds versus outgoing upper bounds. If that scenario
   is below+15, do not automatically intake the candidate in conservative mode.
   The base-value floor remains independently mandatory. `[N/A]` is “no published
   range,” not zero/unknown identity; it does not establish a guaranteed bid.
7. Incoming Underpaid For/Fluctuating/new-event exposure requires protected
   review when it would increase portfolio exposure and trustworthy completed
   exit evidence is absent. Unknown stability/demand is never invented as Stable.
   Fluctuating is not automatically dying; the hold is an uncertainty policy.

Risk gates are proposals for separate validation. The existing tested code is not
silently changed by this document. A HOLD must have a reason and bounded outcome:
active trades still obey empty/overall deadlines; terminal uncertainty stops
automation explicitly rather than spinning or pretending completion.

## 3. Opener and safe-plan selection

### Opener

- Start the2.5s observation from confirmed active trade lifetime, not after an
  arbitrary fetch delay. During each observation iteration, recheck identity,
  source state, visible slots and deadlines. A yielding inventory refresh may
  outlive a trade; lifetime fences must reject its result.
- Any visibly nonempty opponent slot skips speculative opening. Unknown contents
  are HOLD, never an empty zero-value offer. Accepted-empty declines immediately.
- If still empty, use only complete priced partner inventory. Compute reachable
  capacity as its top four **copies**, not its entire inventory. This is ability,
  not willingness. An eligible one-copy opener must cost at least15 less than
  that capacity and pass all hard/risk gates.
- Order reachable candidates by source quality/known stability, ordinal demand,
  absence of downside flags, proximity to the partner's compact trade capacity,
  then lower inventory cost and exact canonical/raw key. Do not simply expose the
  most expensive item. No feasible opener means bounded observation without one.
- Re-read both actual sides immediately before mutation. If opponent signature,
  local Accepted, session, GUI or partner changed, skip/invalidate opener and
  return to the normal planner. Verify the added item in actual slots.

### Plan enumeration and Pareto comparison

Enumerate feasible owned subsets with quantities, at most four copies. Reuse the
bounded state budget; budget exhaustion is explicit HOLD/decline, never a partial
unverified optimum. Preserve alternative demand/status packs at the same price;
the old one-pack-per-total DP can remove an appealing safe candidate.

For each base-profitable candidate calculate the **post-trade portfolio**, not
only the give-away bundle. Keep these separate dimensions:

- Base profit and capital retained; both exact in the chosen list's units.
- Remaining value above each ordinal demand threshold, rather than treating a
  one-point demand difference as a measured cardinal liquidity change.
- Unstable/Underpaid exposure and completeness of current metadata/history.
- Concentration by exact item/variant (value shares and HHI are descriptive
  list-value measures), distinct usable denominations, retained compact anchors.
- Loss of a useful recognized set or small matching denomination, without adding
  a numerical set bonus to value. A source-labelled set is still component items.
- Counterparty financial appeal, comparable offered-item quality, native copy/slot
  count and any **explicitly verified** intent. Inventory alone does not establish
  desired upgrades, sets or willingness to trade every item.

Remove plans dominated across preservation, risk, copy count and comparable
counterparty appeal. Do not collapse those dimensions into a fabricated expected
cash return. Among the remaining plans use this deterministic initial order:

1. Counterparty quality tier: a compact offer with no lower minimum demand/status
   than their known offered bundle precedes one containing lower-quality filler.
   This is an ordinal heuristic, not an empirical acceptance probability.
2. Closest profit band to initial target2: width `clamp(0.02 * their_base,5,25)`,
   with bands measured from the smallest achievable strictly safe profit. Retain
   two bands for negotiation, as an explicit comparable operational baseline.
3. Higher preserved quality across demand thresholds; lower newly assumed risk;
   fewer copies; better retained denominations/sets; higher base profit; canonical
   plan key. Counterparty quality and preservation can conflict; retain/log the
   nondominated alternatives rather than claiming an optimum from an arbitrary
   universal weight.

This **frontier/quality before band** order differs from Issue #4's band-first
selector and weighted exit-score packs. Test it against the existing selector;
do not relabel its predicted appeal as observed acceptance.

## 4. Negotiation, execution and timers

One coordinator owns generation, selected plan, mutation/recovery and successful
sweeten count. A complete opponent signature change resets planning generation,
not the overall60s clock. Replan for real changes rather than automatically giving
back every increase. Check actual own counts against the intended plan.

After5s unchanged and neither Accepted indicator is active, consider a strictly
safe higher-given-total alternative with improved counterparty appeal and no new
prohibited risk. Recompute all proofs before clearing/applying. A no-op is not a
sweeten; count only a verified applied improvement. Failed/uncertain mutation
enters bounded recovery and cannot stack a second planner onto partial state.

Allow at most two verified sweetens. Each starts a new five-second consideration
window. When no better allowed offer remains, or after the second step, allow
the final5s window then decline if unaccepted. Do not increase a plan merely
because it is next in raw-value order. A resolved offer with no feasible+15 plan
declines after technical stability; unresolved items remain bounded HOLD.

Local manual Accepted freezes voluntary mutations. Any changed approved offer
invalidates that approval even when the native indicator resets; if safe native
unaccept semantics are unproved, decline through the bound context. Missing
Accepted-state evidence blocks mutation rather than assuming false.

Retain12s for each genuine empty episode, accepted-empty immediate decline and
60s nonresetting from first nonempty opponent observation, including executor
waits. Timers run even without scanner records or a feasible opener. Native
completion already in progress must not receive a competing decline; this needs
proved native state, not a guessed animation or GUI-close signal.

## 5. Acceptance, completion, reporting and next server

Automatic native Accept remains OFF until initial/final controls, cooldown,
unaccept semantics and every final-state proof are established. A modelled extra
second is not native protocol evidence. When verified, any change resets the
uninterrupted extra1s proof. Final action must consume one current token only.

Completion requires correlated session/partner/transaction/offer evidence plus
exact raw before/after quantity deltas. Require two stable post-trade reads with
complete coverage; reject unrelated changes, late/duplicate events, partial
valuation and source-version conflicts. A completion boolean or disappearance
alone is unconfirmed. Whole-inventory totals must not be a disguised sum of only
eligible weapons when other inventory classes remain unvalued.

Only proven reconciled outcomes enter performance totals and the Discord outbox.
Report names, quantities, Supreme unit/subtotals, demand, liquidity or unavailable,
both totals, signed gain, verified inventory total/scope, transaction/time/version.
Runtime-only credentials; persist send ownership before a network attempt. Retry
explicit429 rejection with bounded backoff; request exceptions/5xx/lost replies
can be ambiguous and must not trigger blind duplicate posts. No persistence or
unproved acknowledgement semantics means reporting remains disabled.

Mark the outgoing partner processed for this JobId while preserving eligibility.
Resume the next unprocessed whitelisted trader only when the active session and
outcome ownership are settled. One P5 transports; keep the45s exhaustion/final
scan and request/trade/uncertain-completion busy guards. A classifier or server
occupancy preference is not a reason to interrupt an owned trade.

## 6. Falsifiable fixtures and experiments

Keep the original252 engineering tests. Add paired fixtures with identical
inventory, partner offer, arrival time, snapshot and quantity constraints:

| Fixture | Required outcome |
|---|---|
| Supplied A90/B60/C20/D10 versus T100 | Reproduce baseline80, Approach C70, candidate hybrid60 choices; never assert measured acceptance |
| Same-value high-demand anchor versus filler pack | Retain both until Pareto/tie-breaking; detect surrender of better retained inventory |
| Beachy75 versus Embersickle90/range85–100 | Base+15 passes; conservative range-risk intake fails |
| Hidden wrong-category million-value row | Exclude; never substitute for identically named canonical weapon |
| Chroma Fire pet / duplicate raw ID / underscored username | Reject unsupported identity; preserve exact name/quantity/partner |
| +14.99 / +15.00 | Reject/allow numeric gate using cents |
| Opponent item arrives inside2.5s or during a yield | No stale speculative opener; unknown is not zero |
| Many safe improvements | At most two applied sweetens and final wait; no no-op increments |
| Accepted resets on changed offer / just after bot rebalance | Invalidate real changed approval; no false decline on unchanged verified plan |
| No scanner record/candidate | Empty/overall deadline still runs |
| Native four slots with repeated copies | Keep four-copy fallback until actual add/remove/final quantities are demonstrated |
| Fake completion, unrelated inventory delta, duplicate callback | No completion count or webhook |
| Lost HTTP acknowledgment/restart | Delivery-uncertain ownership; no duplicate send |
| New server while old callback remains | Old epoch cannot mutate, accept, reconcile or hop |

Synthetic scenarios are feasibility/ranking checks, not historical backtests.
There is no verified transaction dataset for a genuine performance backtest.

After native outcome proof is available, compare baseline B against proposed F
using server-session or blocked inventory-tier assignment, fixed eligibility,
identical price versions where possible and all attempts retained. Switch one
strategy variable at a time; creator/gift/manual interventions are separate.
No arbitrary universal sample size or stopping rule is asserted. Predefine a
minimum worthwhile difference and use uncertainty intervals with session/trader
clustering; do not stop on the first winning screenshot.

Metrics: verified base-value gain per completion; observed attempts/opens/
completions with denominator and confidence interval; time to completion and
holding duration; demand-threshold/stability mix; unpriced/flagged exposure;
turnover; unique counterparties; source age; missed feasible opportunities; and
surplus surrendered by sweetening. Separate price-list revaluation from trading
gain. Trade-board asking estimates remain a separate labelled metric. With final
acceptance/completion disabled, automatic performance estimates remain unavailable.
