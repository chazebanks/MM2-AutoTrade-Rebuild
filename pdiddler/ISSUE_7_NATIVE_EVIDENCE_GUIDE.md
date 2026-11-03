# Pdiddler V6 supervised recovery + evidence guide (November 3, 2026)

## Purpose / boundaries
This follow-up is a **real, isolated source change** from user-tested PR #5. It is not a complete unattended trader. It fixes the missing final five-second negotiation window, preserves the pinned PR #5 baseline, and provides a non-mutating iPad/Delta evidence probe to resolve the exact native protocol blockers. Do not merge automatically.

**What is implemented:** adaptive opponent-first opening, strict +15 Supreme protection, existing Part 3/Part 4/Part 5 behavior, a fixed final five-second offer window, read-only UI/remote observation, optional bounded profile reads, new offline regression and CI.

**What is not implemented/claimed:** native automatic Accept/Confirm, end-to-end completed trade accounting, Discord delivery, live evidence-based four-stack capacity. The new loader hard-disables those just like PR #5. The native probe never presses or fires anything to trade.

## One pinned test build, fresh MM2 server
Disable earlier pdiddler auto-execute entries. Start **one** V6 loader per new JobId:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/BRANCH_COMMIT_SHA/pdiddler/pdiddler_FASTGATE_V5_INTEGRATED_TEST_v6_FINAL_WAIT.lua",true))()
```

Use the **exact reviewed immutable GitHub commit SHA** from this draft PR; do not load `main` or a moving branch. The loader itself pins its strict v3 policy to commit `6008fd02345dad87d789a48f4868e6f65dbce7cc`, retains the other dependencies, and blocks a loaded V5/V4 owner. A stale Supreme snapshot refuses fresh trading; do not bypass it.

### Evidence probe: observational, no trader actions
The probe can be run in the same fresh session as V6 because it does not own or mutate the trade:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/BRANCH_COMMIT_SHA/pdiddler/pdiddler_native_trade_probe_v1.lua",true))()
```

The probe watches the **visible** `PlayerGui.TradeGUI[_Phone].Container.Trade` instance, exact offer visibility/quantity and Accepted indicators, candidate touch controls (via `GuiButton.Activated`), and the observed `ReplicatedStorage.Trade.AcceptTrade/DeclineTrade.OnClientEvent` arguments. It logs **types/booleans only** for remote messages; it never dumps private profile data, messages or credentials. Roblox documents `GuiButton.Activated` as touch-compatible. A remote event with only a boolean **does not contain a transaction ID**.

Optional, initiated manually from Delta's console (and only in a low-value controlled test):

```lua
getgenv().PDIDDLER_NATIVE_EVIDENCE_V1.inspectButtons()
getgenv().PDIDDLER_NATIVE_EVIDENCE_V1.capture("before")
-- Complete or cancel the controlled trade manually.
getgenv().PDIDDLER_NATIVE_EVIDENCE_V1.capture("after")
-- Once the first profile call returns and inventory has stabilized:
getgenv().PDIDDLER_NATIVE_EVIDENCE_V1.capture("after")
getgenv().PDIDDLER_NATIVE_EVIDENCE_V1.report()
```

`capture` is an optional `Remotes.Inventory.GetProfileData` **read** if that remote is present as a `RemoteFunction`. It runs in a separate thread and times out for evidence purposes at four seconds; if the call hangs, it is **not retried while in flight**. After two equal post-trade reads, `report()` prints the differences in raw weapon IDs and quantities only. Those differences are **not on their own proof of completion**; a server event and a matched trade-token/offer snapshot are also needed. If the profile structure is different, the probe reports unresolved rather than inventing IDs/quantities.

Stop probe:
```lua
getgenv().PDIDDLER_NATIVE_EVIDENCE_V1.stop()
```

### Test matrix (film one short controlled session)
1. **Normal trade open**: verify only one active V6 owner; probe logs visible trade-root generation and partner. No hidden phone layout masking tablet.
2. **2.5-second opener**: opponent stays empty -> reachable priced item; opponent places item during observation -> no speculative item. Verify every offered value is Supreme +15 or better when acceptance is considered.
3. **Safe final negotiation**: observe at most two five-second improvements, then one full five-second final window (including when NO better offer exists). No duplicate placement/decline.
4. **Manual initial Accept**: identify exact visible button path and `YourOffer.Accepted` transition; collect which RemoteEvent arguments are observed and their timing. **Do not test or enable auto-click yet.**
5. **Manual final Confirm**: identify whether a distinct second button/stage and native cooldown exist; record when control becomes active and whether the stage's GUI identity changes.
6. **Successful controlled completion**: capture read-only before/after raw counts, two stable post reads, and server event arguments; note precise UI and event ordering.
7. **Negative controls**: manual decline, partner leaves, UI closes without completion, offer mutation after manual Accepted, late event, respawn/PlayerGui recreation. No closed GUI or bare boolean may be counted as a completed trade.
8. **One controller and hopping**: no P5 hop during any request, active trade, confirmation uncertainty or inventory read.

## Evidence required before enabling automatic completion
- The *actual* UI control identities, initial Accept/final Confirm state sequence, native cooldown and cancellation behavior (not guessed names).
- A stable trade token: JobId, exact UserId, PlayerGui and trade-root generation, both exact offer signatures, verified price profile version and active acceptance state.
- Whether the server completion event can be uniquely correlated with that token. An observed `AcceptTrade.OnClientEvent(true)` alone cannot.
- Exact pre/post `Weapons.Owned` raw counts from stable reads (and mapping to each eligible priced weapon) for successful and cancelled trades, including delayed replication.
- Durable outbox storage and actual Discord HTTP acknowledgments, including rate-limit and network timeout behavior. No webhook secret may appear in source or logs.
- Evidence of native four-slot *stacked quantity* behavior before raising the conservative four-copy cap.

## User-facing conclusion
V6 with this probe is a safer, testable incremental step; it is **not** final autonomy. Once a real recording/log identifies the native controls and event/delta correlation, the next new adapter can be written against observed behavior rather than speculative remotes. Preserve PR #3 and PR #5, and test on cheap items with someone you trust.
