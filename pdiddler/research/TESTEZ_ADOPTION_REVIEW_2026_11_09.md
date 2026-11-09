# TestEZ adoption evaluation — 2026-11-09

## Decision: defer installing TestEZ until there is a runnable, nonduplicate test

The official Roblox/testez repo is archived since September 14, 2024:
https://github.com/Roblox/testez

The documented installation expects either a Rojo project or Lemur/Lua5.1
test environment:
https://roblox.github.io/testez/getting-started/installation/

The current Gingerscope default branch is composed of standalone Delta/
Roblox scripts and research-only Python/Lua modules. The repo root has
no Rojo project, Wally TestEZ dependency lock, independently reproducible
MM2 test place, or verified Studio/DataModel runner. Installing TestEZ solely
to run the existing portable health module duplicates already tested behavior
without establishing Roblox or Delta compatibility.

## Verified alternatives already in separate draft PRs

- PR131: official Luau syntax and scoped static analysis.
- PR132: actual Lune offline execution of portable modules.
- PR133: scoped Selene and StyLua CI.
- PR134: sanitized Python CLIENT event replay, not server-trade parity.
- PR135: Hypothesis properties stacked on PR134, not an engine test.

## Criteria before introducing TestEZ

1. Identify an actual game-owned, extracted and testable ModuleScript
   with a specific untested contract (e.g., offer mutation invalidation).
2. Provide a pinned TestEZ dependency and reproducible harness that
   runs its tests under a supported runtime in GitHub Actions.
3. Prove an intentional bad implementation fails and the fixed
   implementation passes, using exact-head Actions logs.
4. Separate mock-based logic unit tests from tests requiring actual
   DataModel/Roblox services; never claim simulator success establishes
   Delta or MM2 server compatibility.
5. Keep automatic trade/Accept, settlement/profit and Discord learning
   prohibited until independently authorized and verified.

## Result

This is a first-party documentation and repository-layout review only.
No TestEZ package installed, no TestEZ tests executed, no live functions
changed, and no fake green CI result claimed. Reassess when the first
nonduplicate engine-oriented test contract and runner are established.
