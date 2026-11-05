# Gingerscope Intelligence — Stage 1 (offline Python lab)

This is **new, isolated trading-decision research**. It does **not** modify or
execute the existing Pdiddler Luau trader, scanning, bot avoidance, GUI,
teleport/Delta control, HTTP/webhooks, or native acceptance. There are no live
trade actions. No old `+15`, concession, or proposer rules are inherited.

## Run the tests

```sh
python -m unittest -v test_evaluator.py
```

Python 3.10+ and standard library only. All supplied prices in the tests are
**synthetic fixtures**, not a live trading database. The example Gingerscope
price is fixture data, not a live market claim.

## What the evaluator does

- Verifies exact **type:item:variant** identity and quantities on both sides.
- Refuses to price unknown, ambiguous, zero-valued, nontradable or expired
  assets as if their value were confirmed. Portfolio totals with unknown items
  are explicitly **lower bounds**; no unknown item becomes zero by default.
- Computes exact listed-value change with no arbitrary fixed-profit floor.
  It does **not** automatically accept negative-value offers either.
- Separates value, stable-value concentration, and ordinal demand profiles.
  Demand ratings are **not** likelihoods of opponent acceptance or a currency
  that can be added to value.
- Computes a conservative theoretical **best four copies** and an optimistic
  **four distinct types with stacked copies** ceiling. Neither proves the MM2
  native UI will allow the requested quantities. Source-specific item caps and
  native execution are deferred until evidence is available.
- Reads the target Gingerscope value from the same verified, nonexpired
  catalogue, not a hardcoded amount. Reports both gaps to the listed target.
- Returns warnings, evidence, and `human-review-only`. `compare()` only
  returns a winner if all comparable metrics Pareto-dominate the alternative;
  otherwise it reports `incomparable`.

## The next integration boundary

Stage 2 will require a **verified item identity adapter** for live Supreme data,
including year/variant, the live owner's quantities, partner quantities, price
validity timestamps, and MM2's actual slot/stack semantics. Stage 3 will
validate offer generation and decisions by replaying native recordings. Only
then should a versioned Luau strategy replace the old one. Preserve the old
working code as a frozen rollback; never have old and new economic rule
sets both authorizing the same trade.

## Deliberate limitations

- No current Supreme feed; no inferred demand from trade-board post counts.
- No acceptance probability, recommendation to auto-Accept, or market-liquidity
  claims based on synthetic tests.
- No claim the current inventory equals its listed subtotal when low-tier or
  year-ambiguous items are unpriced.
- No positive prediction of Gingerscope tradeability from merely reaching the
  item's listed value in four slots.
- The old live trader remains unchanged. Its dated price snapshot is not
  silently extended by this laboratory.