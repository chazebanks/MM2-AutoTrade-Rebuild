# V12 researched trading strategy — isolated Delta build

Baseline: PR #14 `b92348125372026393c3815ecabbc8f3be1df32b`. All 224 baseline blobs remain unchanged. This build adds versioned trading successors; startup, physical Trade clicking, scanner/rotation, bot gate, loading readiness and P5 retain their existing pins.

## Exact entry

Disable older Auto Execute entries and begin a clean MM2 session with one build. Do not repeatedly inject different versions into the same JobId.

```lua
local e=(getgenv and getgenv()) or _G
local u="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/e468820916abf6825427fd69559d0dadc561deeb/pdiddler/pdiddler_V12_TELEPORT_AUTOBOOT_v1.lua"
e.PDIDDLER_V12_AUTOBOOT_URL=u
loadstring(game:HttpGet(u,true))()
```

Bootstrap pins loader/probe to `8bd4fd7f08301ae2752ed67bfa013d4302f6cb9a`; new strict/early/P4 modules to `a8b2e1641297678a51cb2ed04fe0932830b4a22d`. The twelve dependencies are recorded in [the manifest](tests/integration_sources_v 12.json). No moving branch URL is used. Existing native queue-on-teleport aliases are supported; if unsupported/rejected, use Delta built-in Auto Execute with the same snippet. Real Delta queue compatibility still needs a live hop.

**The preserved Supreme snapshot expires November 4,2026 at 21:42:28UTC.** Expiry is unchanged. A legitimately refreshed/approved source snapshot and a new immutable build are required afterward. Do not extend the cutoff or substitute unrelated values to run it.

## What the research changed in code

- One trade-wide ledger retains early spending and the two verified late steps across opponent edits. A genuine increase in received value can enlarge only the bounded current envelope; removed value and recovered/empty slots cannot refill it.
- Every planned increase reserves one exact action. Exact physical slot verification and the current+15 decision commit it. Failed/stale proposals cannot count or silently become free spending. Lost quote ownership closes safely or explicitly holds.
- Planner risk uses value-weighted exposure consistently. Post-trade descriptors cover **priced eligible inventory**, not a whole-inventory completion total or a liquidity forecast.
- Grouped bounded planning retains extension-equivalent alternatives, including different concentration, compact capacity and demand-threshold shapes. Equivalent interchangeable states merge, with the existing 50,000-state bound. Canonical overlaps preserve raw availability and mark uncertain extra descriptors unknown.
- The normal 60% opening region remains. A verified lower-demand capped quote can consider a comparable item only in a small explicit extension using the existing 20/25%-headroom bounds; +15 remains independent. This is a conservative policy choice, not a measured optimal acceptance rule.
- No arbitrary knife/set/Chroma premium, live price fetch, speculative event strategy, personal target or new assembly wait was added. The 9s/native ACCEPT/2.5s-ready safeguards remain.

## Research and evidence

[Conclusion and implementation mapping](../research-notes/deep-search/CONCLUSION_AND_IMPLEMENTATION.md), [new video/TikTok review](../research-notes/deep-search/VIDEO_TIKTOK_EVIDENCE.md), [community pages and original trade-image observations](../research-notes/deep-search/COMMUNITY_EVIDENCE.md), [TikTok index coverage](../research-notes/deep-search/TIKTOK_INDEX_OBSERVATIONS.json) and [partial public-platform study](../research-notes/deep-search/PUBLIC_PLATFORM_INVESTIGATION.json) are saved with the code. Earlier market/strategy work remains in [research PR #13](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/13).

Five newly read video transcripts, eight underlying guides/reference/discussion pages and two original trade images add contrary evidence. Two platform methods were checked directly. Thirty recent indexed TikTok captions were inspected, but their speech/OCR fields were null; focused lookups were empty and direct reads unsupported. We did not watch those 30videos or invent their contents. The bounded platform agent stopped at its credit cap with partial findings, clearly labelled. Verified completed-trade/exit sample remains 0. These sources support prudent representation/accounting; they do not prove higher realized profits or fit acceptance probabilities.

## Offline verification

```sh
LUAU_BIN=/path/to/luau LUAU_COMPILE=/path/to/luau-compile python3 pdiddler/tests/run_v12_checks.py
```

All 22 verification commands passed locally: the 17 preserved commands and 5 current commands. New coverage includes 30 pure-policy cases, a deterministic 1,500-small-inventory exhaustive oracle,24 actual-P4 runtime cases (16 inherited+8 new),17 loader cases,11 teleport-wrapper cases, and 3 verified-step compatibility cases. All 224 baseline blobs,12 dependency blobs and five complete Luau runtime compiles pass. [Full output](audit-notes/V12_TEST_RESULTS.txt) and [remote pin checks](audit-notes/V12_REMOTE_PIN_CHECKS.json) are committed; CI repeats them. Independent review reproduced and verified the post-apply ownership and intermediate-DP corrections.

These are offline Lua/Luau tests with Roblox, rendering, inventory calls and executor boundaries mocked. They are not native MM2 gameplay, a transaction backtest or 1,500observed traders.

## Exact remaining iPad tests

| Test | Action | Expected result |
|---|---|---|
|Startup and outgoing|Run the exact entry on a clean join, let Tablet/friend Play and gate/readiness finish, then permit one request.|Existing selectors, leaderboard/card/Trade physical taps and rotation work as before; one active controller.|
|Initial real quote|Try opponent-first and blank-first cases with known eligible items.|One real quote/opener is added and verified; no immediate duplicate early response. Console logs INITIAL QUOTE reason and actual verified totals.|
|Bounded comparable region|Where your actual inventory offers a tiny lower-demand candidate and a nearby stronger comparable candidate, have the other side show a known bundle.|The larger alternative is considered only within the documented small extension and+15. The synthetic 23/145/235 fixture is an offline example, not an instruction to assume those live item prices.|
|Equivalent edits|After a safe early improvement, have the partner swap known same-value/demand/status items.|Approvals invalidate; early allowance does not refill; no repeated free additions. A genuine higher-value change can create only bounded remaining room.|
|Value removed again|Have the partner add a valuable eligible item, then remove it before approval.|No budget from absent value survives; new decisions use the current offer and retain prior spending.|
|Unsafe first reply|Have a lower-value response to our real opener while a smaller owned combination can still make+15.|The opener can safely reduce to a verified safe plan; a missing prior profitable anchor does not strand it.|
|Native cooldown/steps|Leave a known profitable quote unaccepted and observe native countdowns.|Late steps wait for verified native readiness, the 2.5s buffer and 9s unchanged window. At most two verified late steps across that entire trade, including identity edits. LEDGER VERIFIED logs show spending and late-step count.|
|Changed approval / race|Use normal native controls yourself and change the other side before completion.|Real changed approval invalidates. An unresolved quote whose reservation cannot be verified is closed or explicitly held, not reused as a fresh budget or called success. The precise timing races are covered offline; do not inject another script to manufacture them.|
|Portfolio tie|When two otherwise equal offers exist but one consumes a useful denomination/duplicate reserve, inspect the selected plan and remaining eligible holdings.|The deterministic compact-capacity/demand/exposure/concentration tie policy is applied; no personal item wishlist or universal knife bonus.|
|Close and hop|Decline/cancel, allow rotation to continue, then exhaust eligible unprocessed traders and permit P5 to hop.|No completed-profit claim from GUI closure; no repeat outgoing request to a processed player; no hop while request/trade/outcome owns state. One pinned V12 reentry in the new JobId.|

Keep actual gameplay outcomes separate from these expected results and save native console evidence for any regression. Do not run competing builds in one server to compare them.

## Capabilities still OFF

Automatic final Accept/Confirm, correlated completed-trade accounting, whole-inventory reconciliation and Discord delivery remain disabled. Native transaction/acceptance/confirmation evidence and exact stable raw inventory deltas are still required. No GUI-close success, webhook success, measured bot accuracy, repaired native loading hang, acceptance uplift or realized profit is claimed by this build. The personal acquisition roadmap remains outside runtime.
