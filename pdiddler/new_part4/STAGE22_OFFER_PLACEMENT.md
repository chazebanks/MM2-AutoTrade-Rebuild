# Stage 22 — New Part 4, one-copy native placement contract

**Status: integration-test candidate; not a live autonomous trader.**

Stage 21 replaced the legacy Part 4 and +15-profit gate. Stage 22 adds
the **missing ADD half** of the new transaction execution path while
reusing Stage 9's native observer and Stage 10's existing independent
single-shot protective withdrawal architecture.

## What is new

- `p4_offer_executor.lua`: a pure state machine. An independent
  `validatePermit(proposal, observation, time)` callback must approve a
  source/stock/market-checked, current-session proposal. Stage 16/17
  `reviewOnly` responses **are NOT permits**.
- `p4_native_offer.lua`: native one-shot send adapter. It re-reads the
  exact same Stage 9 bound session, both trade signatures, both accepted
  flags, resolved counterpart, market freshness, own scanner item ID,
  checker ID, page, quantity and four-slot capacity immediately before
  invoking the separately injected `sendOnce(itemId, "Weapons")`.
  Consumes the token before attempting the transport. It never clicks
  Accept and does not claim receipt means the server placed the item.
- `PDIDDLER_PART4_REPLACEMENT.lua`: extended **the same** replacement
  controller from Stage 21 to optionally bind the above offer state
  machine, with one session-bound pending action, verification on later
  GUI observations, and terminal HOLD/ESCALATE rather than repeated sends.
  The existing preview bootstrap calls `p4.run(scanner,profile)` with NO
  placement capability. It **does not enable offer insertion**.
- Python `test_stage22_offer_contract.py` drives the **actual** Lua
  native mocks in a subprocess on CI, instead of creating a duplicate
  Python trader. The Lua suite covers 22 placement cases and an
  end-to-end mocked controller/GUI offer insertion.

## State and rejection rules

Only one new copy of a **different** eligible item per verified send.
Physical stacked additions are not assumed; the original research
four-copy limit is unchanged. Successful command dispatch alone is NOT
successful offer placement.

An ADD command never runs when any of the following hold:
- source or ownership context is unproven; proposal permit callback absent;
- the trade closed, partner/session or job changed, offer signatures drifted;
- either Accept indicator is true or unknown;
- their eligible offered item identities are unresolved;
- our side already includes the requested identity or there are four slots;
- the local-owned item checker ID/page/category/type/quantity cannot be
  uniquely verified by the scanner;
- the native send was attempted already under the same token.

The only success signal is a **separate later** Stage 9 capture showing
exactly the requested one-copy gain, no other local change, a changed own
signature, an unchanged opponent signature, and both sides unaccepted.
Timeout or any unexplained mutation triggers ESCALATE, with no repeat.

## Hard limitations

There is **no authoritative strategy permit provider** in the active
bootstrap. Stages 16–18 supply review/valuation, not execution authority.
Neither this module nor the Stage 21 preview automates Accept or
trade-completion webhooks.

The on-device MM2 `OfferItem` transport is only a known external
mechanism at this stage. The sender is deliberately injected; our
mock sender is NOT native Delta proof. The real remotes, offer replication,
session transition, 4-slot/stack behavior, and withdrawal after a failed
insertion still need controlled Delta tests before activation.

The November 4 Supreme price snapshot is expired. Do not extend the
validity timestamp artificially. The original preview refuses stale
source prices.

## Tests

Python first, including subprocess execution of Lua 5.4:

    cd pdiddler/intelligence_lab
    python3 -m unittest discover -q

Direct Lua regressions:

    lua5.4 pdiddler/new_part4/tests/test_p4_offer_placement.lua pdiddler/new_part4
    lua5.4 pdiddler/new_part4/tests/test_p4_replacement_offer_integration.lua pdiddler/new_part4

Existing Stage 8/10 withdrawal safeguards and Stages 16/17 research are
unchanged. This stage does not add a competing strategy engine.

## Next single task

Implement the **trusted strategy-permit provider** from fresh source data,
native inventory evidence and Stage 17 review, then connect the already
existing Stage 8/11 defensive withdrawal when an attempted placement becomes
unverifiable. Only then conduct a one-session controlled Delta test (no
final Accept) before touching the active loader.
