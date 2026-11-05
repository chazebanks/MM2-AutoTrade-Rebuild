# New Part 4 — Stage 8: isolated safety state machine

**Review-only prototype. Do not run as the live MM2 trader.** This module is a *replacement Part 4 component*, not a patch to the old Part 4. It deliberately has no Roblox/UI/remote/network access.

## Why this exists

The Nov 5 screen recordings demonstrated that old Part 4 immediately declined when an opponent temporarily removed Chroma Watergun while our 3-slot offer remained. Its protective path allowed an emergency clear only for **one slot/one copy**, and verification was hard-limited to **0.24 seconds**. Moreover, the old `clearOurOffer()` calls `txValidate()`, which recursively calls the safety inspector, allowing the safety decline to interrupt its own withdrawal.

This stage builds a new **single-owner, pure state-machine contract** rather than repairing the old economic policy.

## Interface

```lua
local Core = require('p4_safety_core')
local state = Core.new('unique-job:trade:target', {
    removalSeconds = 1.35, clearSeconds = 6.5,
    stabilizeSeconds = 0.65, emptySeconds = 12, buildSeconds = 5,
})
local action, reason = Core.step(state, verifiedObservation, os.clock())
-- After REQUEST_PLAN, and only after independent strategy review:
local ok, why = Core.authorizePlan(state, observedOpponentSignature,
    {{slot=1,id='InternalWeaponId',qty=1}}, os.clock())
```

A future observer must supply an independent, **authoritative snapshot** on every step: `tradeOpen`, `session`, `contextOK`, `marketFresh`, `ourSig`, `theirSig`, `ourSlots`, `theirSlots`, `ownItems=[{slot,id,qty}]`, `theirResolved`, `quoteSafe`, `ourAccepted`, and `theirAccepted`. Each signature MUST be based on the current visible item IDs/chroma/quantities, and `quoteSafe` MUST be freshly decided from a trustworthy market/pricing engine. The Stage 8 module is **not** capable of independently establishing such native evidence.

Supported output actions: `HOLD`, `REMOVE_ONE`, `REQUEST_PLAN`, `DECLINE`, `STOP`. **None of these perform an action**; the executor will later translate a `REMOVE_ONE` into one physical item removal, then request a new native snapshot. The controller **never repeats a remove request before verifying progress**. It does not accept trades, open trade requests, hop, access Discord, or alter inventories.

- **MONITOR:** Hold an unchanged, verified-safe quote. On any physical change or unsafe quote, invalidate it and begin withdrawal.
- **AWAIT_REMOVAL:** One item-removal command at a time, awaiting a strict multiset decrease of verified owned item IDs and quantities **and** a changed raw physical offer signature. Reordering slots is allowed; invented items, no proof, timeout, or partner acceptance leads to decline. Opponent may continue swapping items without resetting the withdrawal transaction.
- **WAIT_REPLAN / PLAN_REQUESTED:** Only after our slots reach zero, wait for a stable, resolved opponent offer before requesting the independent growth strategy to design a new plan. No automatic offers.
- **BUILDING:** A separate strategy must authorize a bounded exact item multiset. The observed items must stay inside the authorized plan, the opponent version must remain fixed, and no acceptance may occur. A complete physical quote is rechecked before entering MONITOR.
- **ACCEPTED_HOLD:** No offer modifications. Any post-acceptance quote change requires immediate decline.
- **DECLINE_REQUIRED / STOPPED:** Explicit terminal intent. `STOP` prevents accidentally declining/clicking a different trade after the session changes or the GUI closes, even if a decline had just been requested.

### Deliberately conservative behavior

An opponent change does **not** instantly decline an unaccepted trade if we can prove each withdrawal and clear it within bounds. But there is no guarantee that a multi-item withdrawal can finish successfully; when the game fails to prove a removal, **decline remains mandatory**. The executor must also never treat `REMOVE_ONE` as proof that an item was actually removed. The existing V15.8 +15 strategy is not imported, and new price/strategy decisions are deliberately outside this component.

### Validation

Local **Lua 5.4 execution**: 25 tests pass, including 200 deterministic multi-slot sequence trials. These cover Chroma Watergun removed during a 3-slot offer, stacked Immortal x2 in one visible slot, physical item-shift/reordering, opponent swaps, delayed removals, missing proof, accepted-state quote changes, unauthorized build items, price expiry and session changes.

```sh
lua tests/test_p4_safety_core.lua pdiddler/new_part4
```

The module uses a Lua 5.4/Luau-compatible subset, but **has not been run under Delta/Luau**. The tests validate its pure state transitions only, not UI click delivery, native event order, networking or real game trade results.

## Blockers before native testing or replacement

1. Build an independently testable **read-only MM2 offer observer**, including exact quantities, accepted state and trusted trade session identity. Do not reuse the old recursive inspector unchanged.
2. Build the one-remove-at-a-time **physical executor** with acknowledgement and a single authoritative action owner. Test stacked and reordered slots on Delta.
3. Port the separately researched growth/attractiveness policy to the **same explicit plan contract**, and test offer construction end-to-end. Stage 7's Python planner remains research-only, including its conservative four-copy assumption despite visible stacking evidence.
4. Verify current Supreme source publication and expiry. Do not extend expired snapshots or auto-enable acceptance by changing timestamps.
5. Validate native manual acceptance and verified completion independently. Keep native final auto-accept OFF until proven safe.
6. Do not replace the old Part 4 module pin, requeue entrypoints, or Parts 1/2/3/5 until an integration branch has passed native replay. Do not merge this draft into the active trader.

**The main Pdiddler loader and all deployed scripts remain unchanged.**
