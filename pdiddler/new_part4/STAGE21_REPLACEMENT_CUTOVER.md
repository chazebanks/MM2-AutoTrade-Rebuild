# Stage 21 — Project Gingerscope replacement-only cutover (PREVIEW)

## What was actually replaced

This branch adds a *separate integration entrypoint* named
`new_part4/REPLACEMENT_INTEGRATION_PREVIEW.lua`, derived from the V15.8
bootstrap so the frozen bot gate, tablet startup, Part 3 scanner, GUI,
outgoing rotation, Part 5 hopper, and lifecycle/webhook infrastructure keep
their existing interfaces.

**The preview does not load the old Part 4 or the old +15 strategy module:**

- Old `pdiddler4_balancer_SUPREME_v11_VALUE_FIRST.lua` pin → NEW
  `new_part4/PDIDDLER_PART4_REPLACEMENT.lua`
- Old `pdiddler4_supreme_policy_v10_INVENTORY_GROWTH.lua` pin → NEW
  `new_part4/P4_REPRICE_ONLY.lua`
- Old P3 feasibility module with a +15 gate → NEW
  `new_part4/P3_ELIGIBILITY_NO_LEGACY_PROFIT.lua`
- Old early-counter and accept-gate modules are not loaded by this bootstrap.
- Bootstrap invokes `p4.run(scanner,profile)`, not the old policy,
  planner, concession or rebalancer invocation.
- There is no old `minimumProfit=15`, old offer algorithm, old
  physical rebalancer or double-running trade controller in the preview path.

The new P3 adapter interprets `reachable` ONLY as independently verified,
eligible own and counterpart weapons for an outgoing *request*; it does not
claim that an economically sound or negotiable offer exists.

The new Part 4 uses the existing Stage 9/15 read-only native GUI observer,
retains the Part 3 controller contract (`run`, `state.active`,
`session`, `stop`), and binds to one job, partner and trade root.
**It intentionally cannot select/place/remove an offer, decline, click
Accept, approve an economic quote, or claim a trade completion.** It only
records anonymous trade-window evidence. Trading windows must be exited
manually in this preview.

## Why the preview is not a deployable trader

Stage 18 connects Python-generated candidates to Stages 16–17 for OFFLINE
review, but there is still no verified native approval/offer insertion
adapter. Stages 8–11's withdrawal state machine and click ledger passed mock
tests, not an on-device controlled removal. Stage 20 is client-evidence
auditing, not an authenticated completion detector. Therefore enabling
automatic offers, withdrawal, or final Accept here would silently bypass
necessary safety boundaries.

The original official 2026-11-04 Supreme snapshot expired
2026-11-05T21:55:32Z. The bootstrap's existing `profile.isFresh()`
assertion is still enforced. **Do not manually extend it** or report the
preview as functional in a live server with expired prices.

There is an additional deliberate opt-in gate:
`PDIDDLER_ALLOW_REPLACEMENT_PREVIEW==true`.
This is not a recommended live execution instruction. Do not activate
until current-source price/identity data and native checks are proven.

## Test commands

From repository root:

    cd pdiddler/intelligence_lab
    python3 -m unittest discover -q

    lua5.4 pdiddler/new_part4/tests/test_p4_replacement_cutover.lua pdiddler/new_part4

GitHub Actions executes the full inherited Python/Lua suites plus these
Stage 21 contracts. A successful mock/API test does not prove Delta native
behavior.

## What has NOT changed

- The old production auto-execute entry and previously working V15.8
  bootstrap remain unchanged. They are **not part of this replacement
  runtime path** and must not be run beside it.
- Git history retains old sources for regression comparison. No delete or
  forced rewrite of the default branch is attempted.
- Existing bot detector, startup, scanner, GUI, P3 transport and P5
  teleport files are not edited by this stage.
- Existing Part 5/Discord transport code is preserved but cannot report
  successful trades without verified completion.

## The next distinct integration problem

Build a proven native insertion/withdrawal and quote-approval bridge from
Stages 16–18 into the Stage 8/11 state machine. Include true source and
scanner evidence, prove physical effects via controlled Delta replays,
then retire the opt-in preview and repoint the **single** active loader.

**Do not confuse removing old code from the replacement path with having
completed the entire live strategy cutover.**
