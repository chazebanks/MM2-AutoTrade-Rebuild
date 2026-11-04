# V13 readiness scan correction — 2026-11-04

## Native evidence and cause

The user's V12 iPad screenshot shows Tablet selection dismissed successfully,
the optional friend prompt skipped normally, a rendered lobby/avatar/leaderboard
and incoming request, then `WAIT_READINESS | loading-ui-inspection-limit`.
V1 produces this specific reason only when PlayerGui:GetDescendants() contains
more than 8,192 entries. That check precedes text and visibility filtering.
It therefore cannot distinguish a genuinely unresolved loader from a large GUI
containing hidden inventory/templates. The visible lobby alone does not prove
every automation prerequisite is ready. The screenshot does not expose the
native hierarchy or prove which particular branch accounts for its size.

The separate `Workspace.Lobby.Elite...WaitForChild("Buy")` warning is from a
native workspace script. It does not produce our readiness reason. We do not
alter that game script or claim to have repaired it.

## Isolated correction

Readiness V2 replaces the loading-text descendant materialization with iterative
GetChildren traversal. Disabled ScreenGui and invisible GuiObject branches are
pruned before reading their children. Other containers remain conservative; we
do not assume script/folder contents are harmless or prune by names. Visible
loading text, character health/world membership, required request/trade UI,
stable readiness observation, deadlines and JobId cancellation remain required.

The scan retains a maximum 8,192 examined nodes and 128 traversal levels. An
incomplete active-tree scan remains a hold, never permission to trade. Diagnostics
include examined/pruned branch counts and the exact path at a budget/depth limit.
GetChildren may return a wide child array; enumeration beyond the examination
budget does not continue. No all-descendant array is built for loading detection.

Request-frame discovery is structurally different from loading visibility:
normally hidden idle request widgets must still resolve. Its existing known
paths and conservative unknown-layout fallback are unchanged. That fallback
retains its separate 8,192-total-node limit; it is not the screenshot's reason.

P2, physical click transport, scanner, outgoing rotation, V12 planner, P4 executor,
bot gate and P5 remain pinned to exactly the same implementations. Native final
acceptance, completed-trade reporting and Discord stay disabled. The preserved
price expiry is not extended.

## Reproduction and verification boundaries

Before implementation, the new large-hidden-inventory test was run against V1:
`texlua pdiddler/tests/v13_readiness_test.lua pdiddler/pdiddler_readiness_v1.lua`.
It failed with `ready lobby blocked: loading-ui-inspection-limit`, exit 1.
The fixture contains 10,000 hidden labels and a fully ready lobby; any attempt to
enumerate the hidden branch itself also fails. V2 passes that reproduction.

The versioned fixture extends native GetChildren and GUI subclass behavior in
test boundaries; it does not alter the preserved fixture. Independent read-only
review found no new false-ready blocker and confirmed requestFrames is unchanged.
Full release output and exact immutable dependency checks are saved separately.

All automated checks simulate Roblox/Delta boundaries. V13 still needs a clean
iPad execution to establish whether the actual large GUI is now fully inspectable
and whether every other native prerequisite passes. If an active-tree limit
persists, collect its reported limit path; do not raise the cap or bypass the hold.
