# V15.2 — startup GUI and no Fast Gate overlay

The screenshot shows V14 stopping at `INITIALIZE | profile` with `Supreme snapshot expired`. Its scanner and main GUI were never started. The native Halloween `EyeLeft` errors are from MM2 workspace scripts, not the pdiddler panel.

V15.2 adds a small passive purple status panel before Tablet selection, keeps actual startup/errors/loading holds visible, and hands over to the existing scanner GUI. It removes the Fast Gate overlay while preserving its ten-second measurements, generation/roster fences, and hopping evidence. It does not modify native Loading Map/World/Character screens, click selectors repeatedly, or bypass readiness. Trading controllers, +15 protection, final Accept/Discord settings and scanner drag/minimize behavior are unchanged.

## Entry

Disable old Auto Execute entries and join a fresh MM2 server JobId. Do not layer this over a running V14/V15/V15.1 session.

```lua
local e=(getgenv and getgenv()) or _G
local u="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/004c284309253f76bc82c32a0e3119a74c20e92b/pdiddler/pdiddler_V15_2_TELEPORT_AUTOBOOT_v1.lua"
e.PDIDDLER_V15_2_AUTOBOOT_URL=u
loadstring(game:HttpGet(u,true))()
```

Pinned chain: bootstrap `004c284309253f76bc82c32a0e3119a74c20e92b` → loader/probe `d624793fdc1c2bac638283b65bdec78091b05474` → headless detector `64b7f6de7dfd8737554de797ceb8b6a0199a393f`. The profile remains the genuine November 4 snapshot pinned at `11537dfd47f8df72aec7aeba9ecaffdfc5c879d4`; its fixed expiry is **November 5, 2026, 4:55:32 PM EST (21:55:32 UTC)**. This GUI fix does not extend that expiry or implement automatic market refresh.

## Exact remaining iPad tests

1. Fresh startup: the small `PDIDDLER | V15.2` panel appears while Tablet selection is running. Native Tablet and optional friend Play should dismiss normally. No Fast Gate overlay should appear during the ten-second detector observation; console evidence should still print.
2. With valid prices and native readiness, the startup panel disappears as the original interactive scanner panel appears. Initial scan/player rows should update normally; minimize and touch-drag still work. Only one outgoing rotation/controller starts.
3. If native Loading Character/World is actually visible, the status panel identifies readiness waiting. Trading remains paused. If loading resolves within the existing bounded observation, initialization continues once. If it does not, `READINESS_HOLD` remains visible without repeated selectors or automatic hops.
4. When a prerequisite fails (including expired prices), expect an error or hold reason on the panel, not an unexplained missing GUI. Do not edit clocks/expiry to simulate this on the live trading account; the deterministic regression covers that branch.
5. Inspect physical outgoing trade-button clicks and visible offer verification with a willing partner after handoff. The startup panel has no input buttons or active frames and is destroyed before outgoing starts. The existing scanner panel still has its own normal footprint and should be moved/minimized as before.
6. On a normal queued hop, this same pinned bootstrap starts once in the next JobId. There should be one startup panel followed by one scanner panel and no Fast Gate overlay.
7. Re-running the entry in the same JobId must not duplicate panels, selectors, outgoing requests or teleport queues. Switching from an older build should refuse until a fresh server session.

## Offline evidence and limits

- 38 loader cases (26 inherited + 12 GUI cases) exercise the real successor loader with deterministic Roblox boundaries. They cover pre-scanner visibility, expired prices, readiness resolving/holding, scanner fetch/execute failure, hide/handoff, duplicate owners, GUI API failure and P4 status ownership.
- All nine full production detector regressions plus one no-PlayerGui/no-Instance assertion pass under official Luau 0.745.
- 26 bootstrap cases verify pinning, old-owner exclusion, queue behavior and no private configuration propagation.
- All 325 files from the prior checkpoint remain byte-identical. A scope assertion proves the remaining loader logic and headless detector evidence are unchanged.
- The complete preserved 37-command V14 suite, actual V15 P4 tests, fresh-snapshot/price-loader/bootstrap regressions and strict parser suite pass. Full output is in `OFFLINE_RESULTS.txt`.

These are simulated runtime/regression results. No iPad/Delta rendering, physical touch/click-through, live bot classification, native trade completion or Discord POST was executed here. Native final automatic Accept and Discord remain OFF pending the existing evidence requirements. The build and PR remain separate and unmerged.
