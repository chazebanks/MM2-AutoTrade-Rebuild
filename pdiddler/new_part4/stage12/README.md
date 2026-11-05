# Stage 12: MM2 native read-only trade UI validation

**Separate diagnostic only; NO live Part 4 replacement.** This stage extends the stacked new-Part-4 draft work in Stage 11. The diagnostic checks the real GUI assumptions before any trade remotes or physical removal clicks are introduced.

## Single-session Delta probe

`pdiddler/new_part4/stage12/p4_stage12_readonly_probe.lua` returns `M`, with `M.start()` to show a small moveable read-only on-screen panel. It polls the visible `TradeGUI_Phone` / `TradeGUI` tree approximately every 0.08 seconds and records distinct visible snapshots, including side item internal attributes, displayed item names, exact unmodified amount labels, chroma tag visibility, native accepted-indicator visibility, trade root layout, number of concurrent roots, accept/decline button presence, and whether the opposing username matches exactly one current player. Event report redacts usernames, UserIds and JobIds.

One manual Delta loader (after replacing SHA with the verified Stage 12 commit):

```lua
local Probe=loadstring(game:HttpGet('https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/REPLACE_WITH_STAGE12_COMMIT/pdiddler/new_part4/stage12/p4_stage12_readonly_probe.lua',true))()
assert(Probe.start())
```

Press **COPY** on the probe panel after one or more manually initiated trades; paste the report into ChatGPT. If clipboard is unavailable, record the visible panel in a screen recording. Press **STOP** when finished; the probe does not queue across teleports and has no auto-execute entry.

For this test, **disable the old Pdiddler auto-execute**, since its current Part 4 can decline trades when a player edits an offer. That would make the read-only test ambiguous. Manually open a trade with a cooperating player; ideally demonstrate an item removal and replacement, a stack, and a native acceptance indicator, without completing a trade involving valuable items.

## What it does NOT do

- Does not use `ReplicatedStorage.Trade`, `RemoteFunction`, `RemoteEvent`, `VirtualInputManager`, `mouse1click`, `FireServer`, server hopping, Discord, or Webhooks.
- Does not read private inventory remotes, perform Supreme lookups, generate or execute offers, decline, accept, or prove completed trades.
- Does not assert that missing item amount labels indicate 1. Unknown acceptance remains unknown.
- Does not prove items are priced, available in player inventories, or safe to trade. It's a diagnostic and its GUI visibility evidence still must be cross-checked against the actual screen.
- Sampling is observational, not instantaneous. Offer edits shorter than the 80ms polling interval can be missed. Native trade GUI may reuse an existing Instance in future sessions, so this is not a complete transaction identity proof.

## Local test

```sh
lua pdiddler/new_part4/stage12/tests/test_stage12_probe.lua pdiddler/new_part4/stage12
```

These pure/helper and mock-GUI tests do **not** replace a native iPad/Delta read-only run. Existing Stage 11 production pins are untouched. Stage 12 does not enable final Accept or the Stage 7 strategy.
