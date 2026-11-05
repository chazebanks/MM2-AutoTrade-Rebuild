# New Part 4 — Stage 10: Verified single-action removal executor

**Status: isolated development / not a live trader.** This stage stacks on Stage 9 (PR #47) and Stage 8 (PR #46). Do **not** merge into the active V15.8 loader, set as Delta Auto Execute, or enable native Accept from this work.

## Purpose

Stage 8's safety core can request `REMOVE_ONE`; Stage 9's observer can report the current live slots and item identities. They still need a precise boundary between an *authorized protective removal attempt* and *proof the UI actually changed*. That separation was missing from old V15.8 Part 4: a 0.24s emergency clear, recursive safety checks and multi-slot instantaneous decline caused otherwise recoverable offer changes to close trades.

### Modules

- **`p4_removal_executor.lua`** — pure, deterministic one-shot command ledger. The only actionable input is exactly `REMOVE_ONE`. It selects the highest verified physical slot, records exact internal ID and quantity, and returns one tokenized `DISPATCH` instruction. Repeated requests are held. Once a separate native adapter reports one click attempt, it waits for a **new independent observation** confirming the exact target ID decreased **and** the physical raw local offer signature changed. Any other item increase/decrease, unverified acceptance, session mismatch, missing proof, or timeout fails closed as `ESCALATE` or `STOP`. No duplicate click is generated. It never accepts, offers, hops or declines itself.
- **`p4_native_removal.lua`** — MM2-specific single-click actuator with an **explicitly injected** bound Stage 9 `observer`/`handle` and a caller-supplied `clickOnce(button,intent)` function. There is intentionally no default VirtualInputManager clicker, no standalone executor entry, no Roblox remotes, no polling and no trading automation. It consumes the token before any click attempt, captures a fresh read-only observation, rechecks partner/session, exact raw local signature, target slot/ID/quantity and both acceptance indicators, then invokes the injected click **at most once** on that slot's currently visible `ActionButton`. A `SENT_ONCE` receipt means only that the click function reported an attempt. It NEVER means the item was removed.

A controller must call `Exec.dispatched(state,intent,Native.execute(handle,intent),now)` and later `Exec.observe(state,newObservation,now)`. Only a `VERIFIED` acknowledgement permits issuing another remove intent. `ESCALATE` means the orchestrator must invoke the separate protective-decline path after validating the same session; it must never retry a click blindly.

## Timing contract

Default execution confirmation: 0.25s for reservation dispatch, 1.0s after a claimed click for independent removal proof. These must fit within **Stage 8's** 1.35s per-removal timer; both clocks must be shared by the final orchestrator. The Stage 8 6.5s aggregate removal budget is independent and stricter. Changing those defaults requires benchmarked native Delta evidence.

## Important safety limits

1. **Protective removal only**. A stale or unavailable market cannot justify adding an item or accepting a trade. The Stage 10 adapter uses Stage 9's verified trade context/acceptance/own slot, not Stage 9's intentionally unapproved `quoteSafe=false` as a claim of economic safety. Stage 8/market logic retains authority to issue the safety removal directive.
2. A removal may be delivered while the opponent changes *their* still-unaccepted offer; however a change to *our* physical items, the local player, the trade root, the bound session or either player's acceptance blocks or escalates the action.
3. A stack such as `Immortal ×2` is **one visible slot**. A confirmed decrease from 2 to 1 is progress but does not mean the slot is clear; another new one-shot intent is required. A decrease from 2 to zero removes two copies; do not infer automatic one-copy removals.
4. Native clicks are subject to UI replication races. A no-yield preflight reduces the window but does not eliminate it. Only **post-click independent GUI observation** establishes a verified removal.
5. The injected click callback is **not yet implemented against real Delta**, and the Stage 9 observer has not been proven against all live MM2 trade UI variants. This is NOT ready to replace Part 4.
6. The previous Supreme source expires 2026-11-05T21:55:32Z. Do not restamp it. This stage never prices or constructs a new economic offer.
7. No user inventory JSON, user IDs, opponent aliases, private screenshots or webhook data are included in this branch.

## Test coverage

Run from repository root with Lua 5.4 (or a host that can execute Lua test files):

```bash
lua pdiddler/new_part4/tests/test_p4_safety_core.lua pdiddler/new_part4
lua pdiddler/new_part4/tests/test_p4_observer_contract.lua pdiddler/new_part4
lua pdiddler/new_part4/tests/test_p4_native_mock.lua pdiddler/new_part4
lua pdiddler/new_part4/tests/test_p4_removal_executor.lua pdiddler/new_part4
lua pdiddler/new_part4/tests/test_p4_native_removal.lua pdiddler/new_part4
lua pdiddler/new_part4/tests/test_p4_stage8_stage9_stage10_integration.lua pdiddler/new_part4
```

Local tests: 25 Stage 8 + 26 Stage 9 pure + 18 Stage 9 native mock + 25 Stage 10 pure + 16 Stage 10 injected-click native mock + 4 Stage 8/9/10 mock integrations = **114 passing Lua tests**. The pure Stage 10 suite includes 200 deterministic multi-slot replays. All native tests use simulated UI objects; they do not establish actual Delta input or MM2 acceptance/completion behavior.

## Next integration boundary

Stage 11 should validate the observer against native UI read-only recordings, then connect a reviewed **single-owner orchestration harness** that enforces Stage 8/9/10 action/clock/session ordering. Add command-level event traces (without private IDs). Introduce an explicit physical-click adapter only after validating button location and post-click acknowledgement on Delta. Defer item insertion and strategic approvals until real source price freshness and same-session partner evidence are available. Keep all existing loader pins unchanged until a separate native safety replay has passed.
