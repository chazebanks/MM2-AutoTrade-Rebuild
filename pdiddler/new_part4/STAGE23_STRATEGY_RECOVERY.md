# Stage 23 — New strategy review, single-use offer permit and protective recovery

**Status:** Draft, offline and simulated. No default live trade authorization, native MM2 send, final Accept, or completed-trade webhook.

## Why this stage exists

The new Part 4 at Stage 22 already has a one-shot offered-item insertion interface, and Stages 8–11 plus 14 already implement defensive withdrawal. Stage 17 evaluates a proposal economically from both parties' perspectives but intentionally returns `reviewOnly=true`, `authorizesTrade=false` and `authorizesAccept=false`. This stage **does not rewrite** those components or reintroduce the old +15 balancer.

## New integration

- `p4_strategy_permit.lua` is a pure Lua bridge: it checks the proposed single-copy give against canonical owned inventory, validates the exact visible resolved counterpart offer and quantity, checks session and fresh price-source evidence, and invokes **the actual Stage 17 bilateral reviewer**. A blocked review is rejected. Nonblocked economic research alone **still cannot authorize** a send.
- A **separate injected approval callback** (a future audited trading policy / controlled user approval) must return an explicitly bound approval record: same session, both offer signatures, source ID and exact give/receive candidate. The permit is single-use, expires in 250 ms and is revalidated against current source, exact item prices, demand, stability and stock before Stage 22 accepts it. This is a structural approval contract; an injected callback or a source `verified` flag is not cryptographic or server-origin proof.
- Existing Stage 17 was changed only to support injecting the existing Stage 16 reviewer when using a Luau `loadstring` loader; offline Lua `require` still works.
- `PDIDDLER_PART4_REPLACEMENT.lua` can **optionally** construct this bridge when a separate integration explicitly provides `placement.strategy` callbacks. The standard preview bootstrap provides **no** placement capability and remains observation-only. After one confirmed local insertion the current offer is monitored; later changes to either signature, acceptance indicator, session or source freshness latch recovery.
- With an independently injected, verified native click callback, recovery uses the **existing** Stage 8 safety controller, Stage 10 single-use native removal, Stage 11 coordinator and Stage 14 multi-observation stability gate. If that capability is absent or cannot be verified, the controller stops new placement and reports `MANUAL_WITHDRAW_OR_DECLINE_REQUIRED`. It does **not** invent a fallback click, force Decline, or press Accept.

## Tests

From the repository root:

    cd pdiddler/intelligence_lab
    python3 -m unittest discover -q

Two new Lua tests are also in the existing GitHub Actions matrix:

    lua5.4 pdiddler/new_part4/tests/test_p4_strategy_permit.lua pdiddler/new_part4
    lua5.4 pdiddler/new_part4/tests/test_p4_strategy_recovery_integration.lua pdiddler/new_part4

The latter creates a fake TradeGUI, obtains a mocked policy approval after an **actual Stage 17 classification**, dispatches one fake Stage 22 offer, independently verifies it in the GUI, changes the opponent's offer, and demonstrates the prior Stage 11/14 defensive sequence removing the local weapon exactly once. These are **mocked UI actions only**, not Delta proof.

## Blockers before activation

1. The 2026-11-04 Supreme price snapshot expired. A genuine updated, source-backed price and identity record must be acquired and checked; simply moving `expiresAtEpoch` is invalid.
2. A genuinely vetted policy must produce and justify approval records. A function always returning `allowed=true` is not proof of a sensible trade. No old +15 rule is used.
3. The preexisting native MM2 OfferItem remote and protective removal click callback need one-session Delta validation, including game UI changes and failed attempts. Python/Lua mock tests are insufficient.
4. Genuine trade-completion proof and automatic Accept remain separately unverified. The old active loader and default preview are not repointed or deployed.

## Cutover policy

The old Part 4 balancer, +15 rebalancer and old negotiation policy remain absent from the replacement code path. Existing Part 1/2/3/5 and all previously tested read-only modules remain unchanged. Retain the old files solely in version history for regression comparison, not as a runtime fallback.

**Do not confuse a successful mock trading pipeline with a deployed autonomous Gingerscope trader.**
