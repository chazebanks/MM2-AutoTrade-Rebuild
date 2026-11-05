# New Part 4 — Stage 9: Read-only MM2 offer observer

**Review-only, never auto-execute as a trader.** This stage stacks on the Stage 8 pure safety controller. It does not modify the active V15.8 loader, Part 1/2/3/5, old Part 4, market snapshot, Discord, teleport hooks, or final Accept.

## Components

- `p4_observer_contract.lua`: pure conversion of a captured visible trade to the Stage 8 observation contract. Parses explicit `x2`, `×2`, and numeric quantity labels; verifies raw item IDs or unique display-name/chroma matches against previously read scanner records; checks aggregate quantities, exact slot counts, acceptance booleans, and physical raw signatures. If the local offer can't be matched, `contextOK=false`; if the opponent can't be matched, `theirResolved=false`. Never assumes an absent quantity or acceptance indicator is `1` or `false`.
- `p4_native_observer.lua`: **read-only** GUI capture using the MM2 Phone/Tablet trade layouts (`TradeGUI_Phone` and `TradeGUI`). Session binding requires a specific GUI root instance, current JobId, PlaceId, local UserId, and matching named opposing Player UserId. Once a trade is observed closed, that handle never adopts a new trade. No RemoteFunction, RemoteEvent, simulated mouse input, UI mutation, new threads, or polling loops.
- `tests/test_p4_observer_contract.lua`: 26 executable Lua 5.4 tests.
- `tests/test_p4_native_mock.lua`: 18 executable Lua 5.4 tests with a synthetic Roblox GUI tree; **not actual MM2 client behavior**.

### Proposed integration contract (not wired in production)

Both modules return tables. Load the pure contract, then inject that returned table into the native adapter's configuration; do not rely on filesystem `require` in the Delta executor.

```lua
-- Illustrative only: the modules must first be loaded by a reviewed loader.
local contract = loadPureObservationModule()
local native = loadNativeObservationModule()
local handle = native.new({
    contract=contract, game=game, players=Players,
    root=knownCurrentTradeRoot, session=uniqueTradeSessionId,
    jobId=game.JobId, partnerUserId=expectedPartner.UserId,
    localUserId=Players.LocalPlayer.UserId,
    ownInventory=previouslyObservedOwnInventory,
    opponentInventory=previouslyObservedOpponentInventory,
    marketFresh=verifiedPinnedProfile.isFresh,
})
local observation, diagnostics = native.capture(handle)
```

The observer returns Stage 8's expected keys (`tradeOpen`, `session`, `contextOK`, `marketFresh`, `ourSig`, `theirSig`, `ourSlots`, `theirSlots`, `ownItems`, `theirResolved`, `quoteSafe`, `ourAccepted`, `theirAccepted`) and separate read-only diagnostics. **`quoteSafe` is always false** in Stage 9: GUI visibility and cached inventory matching cannot establish current listed value, demand, strategy suitability or completed trades. No action/accept authorization comes from this module.

## Findings and unresolved risks

1. **One-slot stack proof**: A rendered `Immortal ×2` slot normalizes to one physical slot and quantity two only when the text is explicit and the scanner record has at least two copies. Native removal acknowledgement is not implemented here.
2. **Transient offer edit**: Removing/changing an opponent item changes its physical signature, even when the value might stay the same; an item removal does not itself authorize an immediate decline.
3. **Acceptance evidence**: `YourOffer.Accepted` and `TheirOffer.Accepted` missing from the visible GUI are **unknown**, not `false`. Caller must not turn unknown into approval. No final acceptance is performed.
4. **Scanner freshness**: Stored scanner inventories can be old; Stage 6 recorded no last successful per-opponent scan timestamp. A name/ID match establishes internal consistency against the cache, **not a same-moment inventory proof**. This is insufficient to authorize live actions.
5. **UI variations**: Actual native item amount labels, trade-root handoff, and acceptance-node visibility require a new *read-only native Delta diagnostic* before this adapter is an authoritative real-time reader. Current source intentionally fails closed when labels are absent or ambiguous.
6. **Trade GUI reuse**: The observer never reattaches after detecting a close. A GUI that disappears and reopens wholly between two captures may not be distinguishable by instance identity alone; a future native session-event token is desirable.
7. **Prices**: This stage does **not** refresh or restamp the dated Supreme snapshot. The old Nov 4 snapshot expires Nov 5 at 21:55:32 UTC; price-dependent decisions are blocked after expiry without a genuinely new publication.

## Test commands

With Lua 5.4 installed and repository root as working directory:

```sh
lua pdiddler/new_part4/tests/test_p4_safety_core.lua pdiddler/new_part4
lua pdiddler/new_part4/tests/test_p4_observer_contract.lua pdiddler/new_part4
lua pdiddler/new_part4/tests/test_p4_native_mock.lua pdiddler/new_part4
```

The local development run passed **25 + 26 + 18 = 69 executable Lua 5.4 tests**. These tests validate module behavior and mock GUI reading, not real Roblox replication, native click delivery, or trade completion.

## Next boundary (Stage 10)

Build a **single-action physical executor** with independently verified acknowledgement for `REMOVE_ONE` and later item insertion. It must never interpret the Stage 9 observer alone as permission to mutate a trade: a separate fresh market proof, exact approved strategy plan, and verified session handoff are prerequisites. Keep production Part 4 unchanged while developing and testing that interface.