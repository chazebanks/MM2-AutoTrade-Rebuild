# Recommended improvements and gates

**Current baseline update:** [November 4 PR14 review](CURRENT_TRADER_STRATEGY_REVIEW_2026-11-04.md) supersedes this document's old execution assumptions for new work. Verified-step ownership and the native-ready nine-second late wait are already in PR14. Use the new review's ranked remaining changes and experiment protocol; do not repeat completed fixes or restore the earlier five-second model. Original dated data and historical comparisons below are retained.

Research only. Issue #4 checkpoint `4b5c6d9095d21643349cee32d43719e515e294d1`
is preserved. No recommendation here replaces tested code or authorizes an
automatic acceptance, reporting or merge action.

## Do now without changing the runtime

| Priority | Action | Evidence / expected impact | Risk / effort / testability |
|---|---|---|---|
|P0|Resolve market-feed reuse permission and define an authorized update route|Primary terms explicitly restrict collection/copying; prevents relying on an unauthorized production refresh|Operational/legal clarification; do not infer permission from existing copies; readily auditable |
|P0|Keep native auto-Accept/completion/Discord disabled until the Issue #4 blockers are proved|Direct code/native-evidence gap; prevents false success, unsafe confirmations and duplicate reporting|Highest safety impact; native evidence collection required |
|P0|Use the matrix as a dated review artifact, not an evergreen price feed|All190 mapped;189 finite;118 cross-list differences;24 type gaps|Low implementation effort because this is documentation; validate IDs/flags and snapshot expiry |
|P1|Run the existing supervised matrix and retain every outcome|No unbiased completed-trade sample currently exists|No guessed performance; user-supervised native work; preserve all stop conditions |

## Separate engineering PR only after approval and validation

| Priority | Exact responsibility / touchpoint | Proposed change | Evidence, risk, effort and test |
|---|---|---|---|
|P0|`pdiddler/refresh_supreme_snapshot.py`, dated profile files|Authorized, visible-category/class-aware source adapter; reject hidden rows, pets, duplicate categories and anomalous identity joins|Direct hidden million-value/pet evidence; medium effort; isolated parser fixtures. New version only; do not edit frozen files |
|P0|Native adapter feeding `pdiddler_trade_verification_v1.lua`|Establish actual control/cooldown protocol, transaction correlation, complete raw before/after mapping and stable reads|Current contracts are not native evidence; high safety risk/effort; independent native negative controls required |
|P0|Persistent adapter for `pdiddler_webhook_outbox_v2.lua`|Runtime-only credentials; persist ownership before POST; explicit unavailable-liquidity/valuation scope|Unknown acknowledgments cannot guarantee exactly-once delivery; medium/high effort; request-error/5xx/restart/429 fixtures |
|P1|New version of `pdiddler4_supreme_policy_v2_ADAPTIVE.lua`|Build post-trade inventory/Pareto metrics and compare quality-first frontier against band-first selection; separate demand ordinal thresholds from weighted heuristic|Primary framework plus synthetic counterexamples; expected impact plausible, not measured; medium effort; paired equal-input fixtures |
|P1|New policy's risk gate|Separate base+15 from known-range downside and instability/concentration flags; dual absolute/relative disagreement review|Current Embersickle range example and118 disagreements; risk of rejecting good trades; medium effort; clear false-positive metrics |
|P1|New P4 coordinator version|Count only verified successful sweetens, preserve generation/approval latch and bound all recovery|Existing regression evidence; medium effort; many-safe-plan, no-op, failed apply, changed offer, manual Accepted tests |
|P2|Scanner adapter/status presentation; V5 loader|Clearly label frozen scanner MM2Values versus Supreme trading figures; avoid changing scanner classification|Confirmed mixed-display basis; low/medium effort; status-label and no-whitelist-regression tests |
|P2|Outgoing/P5 telemetry adapter|Compare eligibility, response/completion and elapsed time by server cohort while preserving one owner|Conflicting creator advice; unknown actual effect; medium effort; busy-state and stale-server fixtures |
|P3|Quantity/slot adapter, `applyPlan` / `evaluateSide`|Support >4 copies only after native stack proof across add/remove/accept and inventory deltas|Four slots alone is insufficient; high safety risk; controlled one-vs-four-slot and quantity-change evidence |

These filenames identify responsibilities, not instructions to patch the frozen
versions. Every change should use new versioned files and a new pinned loader.
The [strategy spec](PDIDDLER_TRADING_STRATEGY_SPEC.md) supplies exact decision order,
metrics and test cases. The market dataset is not linked into any runtime.

## Investigate further

- Obtain consented, minimally retained complete trade logs with attempts, failures,
  immutable source versions, verified completions and post-trade inventory.
- With permitted access, inspect actual public completed proof records rather
  than extracting more asking-price summaries. Track duplicate posters, selected
  submissions, creator/gift effects and inventory scope.
- Validate histories and freshness across sources with exact date/scale joins.
  Do not infer daily realized volatility from list updates.
- Compare public/dedicated servers by matched inventory tiers and actual response
  data; do not adopt a universal occupancy/wealth cutoff from creator opinion.
- Test range/quality filters' missed-opportunity cost alongside their adverse-
  selection benefit. Current research cannot estimate the tradeoff numerically.

## Do not automate

Named personal goals or owner hunts; universal knife/set/Chroma premiums;
guaranteed holiday predictions; losses to obtain an upgrade; cross-list price
shopping; inferred liquidity from asks/demand; hidden million-value rows; pets
through a Godly-name shortcut; unknown quantities; unrestricted stacks; GUI-close
success; uncorrelated completion booleans; blind webhook retries; multiple active
controllers; server hops during owned requests/trades/outcome uncertainty.

The personal acquisition roadmap is human-only and must never become a runtime
preference, target, scoring bonus, log objective, stop condition or whitelist.
