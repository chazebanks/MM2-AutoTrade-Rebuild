# Gingerscope Intelligence — Stage 4: Review-only offer ranking

**Status:** experimental Python laboratory; no live actions or completion authorization. This branch stacks on Stage 3. Do **not** merge into the active Delta loader or replace P4's production strategy yet.

## What was implemented

`offer_ranker.py` discovers **1–4 physical-copy** outgoing bundles for one explicitly specified, catalogue-priced and counterparty-owned incoming bundle. It consumes the exact checker-ID holdings and `Catalog` from the Stage 1–3 Python bridge. It uses `evaluate()` for actual post-trade portfolio effects. It never modifies Roblox state, calls remotes, clicks, accepts, server-hops, reports Discord completion, or assumes stacked quantity occupies one slot.

Every candidate includes:

- the exact checker-ID and quantity on both sides;
- supplied/received listed value, signed listed-value gain, and *listed-value coverage* of the requested item(s);
- whether the trade changes conservative **four-copy purchasing power**, and the Gingerscope four-copy gap after the hypothetical trade;
- the highest-value contribution in our offered package, as an opening-item **descriptor**, plus its Supreme ordinal demand;
- qualitative cautions for fluctuating/underpaid holdings, low source demand, nominal value losses, demand/stability deterioration, unknown inventory value, and unproved quantity-slot behavior.

It exposes **two review lanes**, not one fake optimal answer:

1. **Value-competitive offers**: closer in listed value to the target bundle, with quality and preservation tie-breakers.
2. **Four-copy progression offers**: improvement in the conservative four-copy ceiling, with cautious quality and listed-value tie-breakers.

The default **90% target-value coverage gate** excludes obvious large underoffers *from the main review lists*. This is an explicit configurable **research/display heuristic**, NOT a true acceptance threshold, evidence that the counterparty likes the items, a guaranteed fair trade, or the old absolute `+15` profit floor. `min_review_coverage=0` can show bad quotes for diagnostics. A positive listed-value gain is not evidence of an achievable trade; a near-equal offer is not evidence of the target owner's preferences.

Nominal losses are excluded by default. `allow_overpay=True` is strictly for offline exploration and marks losing quotes; it does not authorize losses. Unknown, stale, duplicate or nontradable item identities cannot enter offered or requested bundles. Excessive search space raises `quote-search-budget-exceeded`, never silently truncates. All source market times/expiry remain unchanged.

## Tests

```sh
cd pdiddler/intelligence_lab
python -m unittest discover -q
```

At implementation, **67/67 local unit tests pass**, including Stage 1–3 regressions and 17 Stage 4 test cases. Tests include price expiry, forged inventory quantities, same-item overlap, four-copy enforcement, unwarranted direct Gingerscope underquotes, bad Boneblade-for-150 style openers, a bounded search, two review lanes, and deterministic seeded scenarios. Stage 4 uses the pinned 16-item real-source excerpt fixture with synthetic opponent holdings. Native acceptance rates are not modelled.

### Local replay (not committed as user inventory data)

A private offline replay using the user's 14 scanner-confirmed high-tier types (listed value **4,548**) finds a conservative four-copy ceiling **3,870**. A direct Gingerscope quotation is **not admitted** to the normal list (only 24.1875% of target value). A hypothetical opponent-owned **Chroma Mortal (1,600)** produces example close quotes around 1,593, but no actual opponent was observed owning or accepting this item. The source calls Chroma Mortal `Doing Well`, not `Stable`; do not collapse those statuses.

## Still blocked before production

- The user's scanner export has no trustworthy `jobId`, `playerUserId`, `captured_at`, or opponent-specific contemporaneous inventory proof; the Stage 2 runtime authority gate is still unfulfilled.
- The pinned November 4 Supreme snapshot expires on **November 5, 2026 at 21:55:32 UTC**. Refresh only after verifying a genuine new source publication; never alter its expiry just to get the bot running.
- We have no validated counterparty trade acceptance or preference dataset. Actual observed declined/countered/completed negotiations are required to calibrate appeal and policy trade-offs.
- The current P4 executor, rebalancer, scanner/eligibility, bot gate, requests, hopper, Delta overlay and Discord pipeline remain unchanged. Native final Accept and completion proof remain disabled.

**This is a decision-support module, not a deployable Luau auto-trader.**