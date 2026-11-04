# Research validation

PASS 190-row/189-price consistency; exact identity joins; missing-data flags; 801 publisher records
PASS reproducible window arithmetic, synthetic feasible plans and hypothetical roadmap arithmetic
PASS all protected engineering blobs unchanged; documentation-only paths; no personal target in strategy spec

The source-backed counts/windows and hypothetical roadmap arithmetic were checked independently by one read-only critic. The critic identified and corrected the initial-vs-final offer comparison and softened unmeasured adverse-selection/optionality claims. No new sources or runtime edits were delegated.

This is research-data consistency checking, not a completed-trade backtest or live Delta validation. The engineering checkpoint and all164 original repository blobs are unchanged.

Recalculate with `PYTHONDONTWRITEBYTECODE=1 python3 research-notes/tools/validate_research.py`. Recreate the SVG with the adjacent plotting script.


## November 4 current-strategy follow-up

Current policy baseline: PR14 `b92348125372026393c3815ecabbc8f3be1df32b`.
The separate engineering checkout remains unchanged. All new tracked work is
under `research-notes/`; original dated market JSON/CSV and the personal roadmap
are unchanged. Five older prose documents gain a pointer to the current review.

```sh
PYTHONDONTWRITEBYTECODE=1 python3 research-notes/tools/validate_research.py
PYTHONDONTWRITEBYTECODE=1 python3 research-notes/tools/evaluate_current_strategy.py --runtime-root /path/to/exact-PR14-checkout --check
python3 research-notes/tools/plot_strategy_tradeoffs.py
git diff --cached --check
```

The new driver verifies three exact Git blobs, executes six actual pure-policy
experiments, checks seven observations and reproduces the recorded analytic
thresholds/missing-data flags. `CURRENT_STRATEGY_EXPERIMENT_RESULTS_2026-11-04.txt`
contains the full experiment output. The SVG is an analytic sensitivity plot,
not a fitted acceptance model. Matplotlib is needed only to regenerate it.

The test clock is fixed to the preserved snapshot observation date. This is a
historical offline fixture, not a live-expiry bypass. Raw IDs and native weapon
types in the named-item experiments are synthetic legal fixture fields; they
are not evidence of native tradability. No Roblox actions or live market refresh
are performed. The original data-consistency/protected-baseline checks pass.

An independent reviewer checked the new evidence claims and the probability
ratio/HHI arithmetic; the before/after label, exact-fraction wording and full
attempt-duration definition were corrected. No claim of measured strategy
superiority, acceptance rates, completed gains or native verification was made.
