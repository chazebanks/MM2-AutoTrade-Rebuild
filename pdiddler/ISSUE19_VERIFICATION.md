# Issue19 — independent V15 verification

Original reviewed PR18 head:9d46606dec4dcf50d8b5fc013012cd9b4ee43fa3.
Verdict: original controller FAIL; corrected offline verification PASS;
native iPad/Delta verification NOT RUN, release promotion remains blocked.

## Confirmed defect and correction

The original12 pure tests,29 source fences, full37-command V14 suite and12
GitHub Actions workflows passed. They did not exercise the new P4 integration.

An actual production-controller reproduction exposed an upward-path bypass:
our verified7 quote against200; their added matching item worth7 gives207,
below the10 threshold; P4 replaces our mirrored item with20 via the rebalance
path. This spends13 despite insufficient net addition and exceeds half of7.
That path also fails to commit the opponent reward watermark as an early reward.

All post-anchor economic increases now pass the same V15 pure decision policy,
including safety replacements. A selected qualified replacement uses the early
commit path; otherwise P4 restores/replaces at or below the last committed
economic quote or declines if no valid nonmatching plan exists. No inferred
price, duplicated planner, reset allowance or time-based generosity is added.

An independent review caught an overly restrictive first fix: after a technical
clear, fallback capped offers at actual zero and unnecessarily declined. A failing
production test now requires restoration of100 after an interrupted reward.
Restoration uses the last committed quote as its economic baseline; it does not
spend or replenish a concession budget. The correction passes that test.

## Required scenario coverage

| Scenario | Offline result |
|---|---|
|200→205→210|Hold at205; one capped verified reward at210|
|200→210 reward→200→210|No second reward at the already credited value|
|210 anchor→220 /220.5|220 holds;220.5 crosses the exact5% threshold|
|1,000→1,049 /1,050|Hold then eligible bounded consideration|
|Same-value swaps;190 removal/readd200|No new generosity|
|Waiting9s; native-ready9+5 window|No timed increase; eventual single decline|
|Mirrored replacement, below/above threshold|No bypass; qualified reward commits once|
|Opponent edit during physical removal|Stale reward aborts; old safe quote restores|
|No feasible denomination; zero allowance|Hold; no blind item addition|
|Accepted local/partner; accepted-empty|No reward mutation; approval invalidation/decline retained|
|Downward repricing; no safe plan|Nonincreasing safe replacement or bounded decline|
|Cancellation; partner departure|No completed-trade claim|
|Expired Supreme prices|Decline without a new concession|
|Legacy V14 owner, GUI readiness, requests and hop lease|Inherited loader/outgoing checks plus V15-specific loader/bootstrap execution|

The handoff's example calling210→220 eligible conflicts with its exact5% rule:
5% of210 is10.5. This verification preserves the formula, not the erroneous
example. No lower threshold or expiry extension is introduced.

## Evidence and preservation

New tests execute the actual V15 P4 with the real V14 strict policy/lifecycle,
mocking only Roblox/executor boundaries.15 production cases pass, along with
12 original pure cases,29 source invariants,25 loader and22 bootstrap cases.
The full37-command V14 suite passes. Including the five feature checks and the
full-V14 hash check gives43 leaf verification commands; four V15 sources compile
in official Luau0.745. All294 V14 files remain byte-identical.

Every one of the17 actual loader dependency references was fetched from GitHub
and compared to local Git-blob hashes. Corrected P4 pin:
54c9ff4b999f67b2a257be10747c32916051bdd4. Loader/probe pin:
9670c10beec0065fed8bfdac05e5b3a0cb70b7d8. Bootstrap pin:
6f3fbcc8529a68144e76863048807ec247c26bc1.

Full output: audit-notes/ISSUE19_TEST_RESULTS.txt. Pin checks:
audit-notes/ISSUE19_PIN_CHECKS.json. CI now explicitly runs the actual V15
controller, loader and wrapper checks; previous CI only exercised V14 controllers.

## Native verification still required

This environment has no iPad/Delta session. No real trade recording, physical tap,
native completion, webhook POST, measured profit/session-hour or successful hop
is claimed. Final automatic Accept and Discord remain OFF. No private URL enters
GitHub or queued teleport source. Nothing is merged or approved for live release.

For the remaining supervised test, use a clean MM2 JobId and only the corrected
entry below. On a low-value known +15-safe offer, inspect actual slots after a
qualifying addition, confirm waiting alone produces no increase, then remove and
re-add without exceeding the last reward watermark. Also check cancellation,
UI recreation and one hop. Record the actual pending/closed result; GUI closure
does not mean completion. Native controls/cooldown still need observation.

```lua
local e=(getgenv and getgenv()) or _G
local u="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/6f3fbcc8529a68144e76863048807ec247c26bc1/pdiddler/pdiddler_V15_TELEPORT_AUTOBOOT_v1.lua"
e.PDIDDLER_V15_AUTOBOOT_URL=u
loadstring(game:HttpGet(u,true))()
```

The fixed price deadline remains2026-11-04T21:42:28Z. Do not test trading with
expired data or extend this deadline. A verified authorized refresh is separate.

Separate adjacent task, deliberately unchanged: P4's NoPlanNegotiationGrace is
declared but unused, so a stable no-safe-plan offer declines immediately. This
does not justify broad V14 changes within Issue19.
