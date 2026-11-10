# Stage106 — two-sided UpdateTrade raw-key / physical-slot witness

## Status

Standalone read-only research code for the existing task PR178. Implementation commit: `ecf9b54f9faa497b9755f07843373ecc6075f8d6`. The focused Python/Lua tests pass locally, and the original source blobs listed below were fetched and hash-checked. **Do not run the iPad test yet:** all six exact-commit GitHub Actions checks are `action_required` with zero jobs, not green. The stage must remain untested on-device until those checks can run and pass.

The implementation reuses PR176's matcher; it adds no second identity matcher. It loads the immutable original Stage9 observer, Stage83 archival registry, PR176 corrected matcher, and PR170 Stage100 layout helper at fixed commit URLs. It does not merge or modify those branches.

## Pinned source compatibility

| Source | Commit | Verified Git blob |
|---|---|---|
| Original Stage9 `p4_observer_contract.lua` | `1971b93d324f0275e6a9affb472ac3e804439ed8` | `7c84456006bd684dacb0217d0ae092d6d67575a4` |
| Original Stage9 `p4_native_observer.lua` | `1971b93d324f0275e6a9affb472ac3e804439ed8` | `a6338e946467ad738005bc5cb13cd2d2fbc2a2d0` |
| Stage83 public registry | `25b48b60fdb2f971bbb6b2a2020f3c7c4432f7ae` | `40e2a0ff01b70b2d0181c62cae347a08da82bcb8` |
| PR176 corrected Stage101 matcher | `29889595b5e80c788ade75fbb97880b736fc8cb2` | `c15afe8077d544534e0f122ce2f4a5081cb2ac90` |
| PR176 Lua regression corpus | `29889595b5e80c788ade75fbb97880b736fc8cb2` | `526b3b0ba45ca7ebdd5e328ba9c37c680c4a797a` |
| PR170 Stage100 safe-position helper | `59d869b7d4d8fbcee3f2709e266b47ffb4a05d78` | `e0eac8e039655999bd7bbac1f12da179db7c22ed` |

The wrapper was exercised under Lua 5.4 with the actual pinned Stage9 observer and contract, PR176 matcher, Stage83 registry, and Stage100 geometry helper. This verifies offline source integration only; it does not prove live callback causality.

Stage97's earlier one-sided listener remains a completed, distinct native observation. Stage103's purple guide and Stage100 layout helper were reviewed; their already completed native scopes are not repeated. See PR167/170/174 and the canonical handoff.

## Validation at implementation commit

- `python3 -m unittest -v pdiddler.intelligence_lab.test_stage106_readonly_witness`: **2 Python tests passed**. The first runs the pinned PR176 Lua suite: **18 Lua groups and 500 adversarial mutations**. The second runs the Stage106 wrapper against mocked Roblox objects and the original Stage9 observer: **17 named integration groups**, including a two-sided swapped-player candidate, pre-listener ALT callback, x5 Chroma stack, four distinct slots per side, stale/delayed and duplicate/missing events, malformed packet, acceptance/lock, identity/session/root/job changes, protected Gingerscope, changed snapshots, unsafe layout, viewport movement, exact-target absence, and listener cleanup.
- `lua5.4 -p` (via `luac5.4 -p`) on the Stage106 wrapper and integration test: **pass**.
- Pinned StyLua 2.6.0 `--check` on the Stage106 wrapper and integration test: **pass**.
- Secret scan: **no secrets detected**.
- CodeQL: **0 alerts** for Actions and Python.
- Stage106 Actions run [42779257796](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42779257796) and inherited exact-commit checks [42779257627](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42779257627), [42779257614](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42779257614), [42779257709](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42779257709), [42779257604](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42779257604), [42779257887](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42779257887): all report **`action_required`**, each with zero jobs and no failed jobs/logs. This is not a CI pass; no retry was requested because the runs did not fail.

## One manual iPad test — only after all six workflows are green

**Prerequisites:** a fresh original MM2 server; MAIN iPad/Delta; the consenting ALT `venossgaming90190`; no other pdiddler scripts; exact current ALT Player object and original Stage9 trade GUI; do not retry in the same JobId. Run once on MAIN:

```lua
getgenv().PDIDDLER_STAGE106_TARGET_USERNAME = "venossgaming90190"
getgenv().PDIDDLER_STAGE106_READONLY_ARMED = true
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/ecf9b54f9faa497b9755f07843373ecc6075f8d6/pdiddler/new_part4/STAGE106_READONLY_TWO_SIDED_UPDATE_TRADE_WITNESS.lua"))()
```

Follow the numbered purple/black on-screen guide; the Delta console is not the only prompt:

1. MAIN manually opens an **empty** trade with the ALT.
2. After the empty baseline is verified, ALT manually adds **one expendable eligible Ancient/Godly/Chroma weapon**. MAIN remains empty. The wrapper waits for two stable Stage9 snapshots before connecting the listener.
3. Only after that verification, the read-only listener attaches and records `before` with ALT's item already offered. When the guide shows `READY_MAIN_ADD_ONE`, MAIN manually adds one eligible expendable Ancient/Godly/Chroma weapon; ALT stays unchanged. Gingerscope remains protected.
4. Do not press final Accept. The wrapper accepts only exactly one complete callback plus two stable after-snapshots separated by at least 0.15 seconds. It disconnects on every exit and shows a sanitized PASS/STOP with optional dismiss.

If viewport/trade geometry has no safe non-overlapping placement with 12px clearance, the guide hides and the run stops inconclusive. A positive result is only client-side raw-key candidate consistency for both visible offers. It does not prove callback causality, server session association, unique item instances, ownership, current prices, completion, profit, or trade/Accept permission. Do not report raw keys, names, account identity, tokens, or packet payloads.

## Issue follow-up

Issue [#122](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/issues/122) remains the evidence thread. This session could read its latest comment but had no issue-comment/write tool, so no Issue #122 update is claimed here. The exact code SHA, test results, CI blocker, and gated manual sequence are recorded in this focused handoff and PR178.
