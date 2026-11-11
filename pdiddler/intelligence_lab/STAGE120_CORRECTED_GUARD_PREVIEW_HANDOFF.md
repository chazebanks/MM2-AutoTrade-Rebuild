# Stage120 — Corrected four-physical-slot portfolio preview, original research components

## Why this is NOT a repeat of Stage86

**Latest real MAIN iPad:** [PR226 Stage119 V2](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/226#issuecomment-6801472940) returned actual two `UpdateTrade` callbacks / two original Stage9 GUI quantity transitions / changed opaque LastOffer and protected P3/P4 client-only evidence. **HARDWARE STAGE119 CLOSED**. No new iPad run needed for this offline economic work.

The user discarded the proposed automated chat-negotiation feature and returned to the next trading decision-engine task: evaluating whether a trade improves desirable, liquid, retradable inventory toward Gingerscope without prematurely executing.

**Stage86 PR156 already tested PR106 original portfolio planner + OLD PR105 offer guard** in purely synthetic inputs (14 tests + 500 mutations). Do not clone its entire system. The **distinct gap** is that Stage86's guard pin `c5b87f159de5224d231b111da2541b8b23ac6284` predates **PR181 physical-slot vs copies correction** and **PR182 permanent outgoing Gingerscope protection**. Simply rerunning Stage86 would preserve obsolete guard behavior. Its source synthetic `SYNTHETIC-STAGE86-V1` uses a hardcoded synthetic +5 research case, not a universal policy.

## One narrowly scoped new adapter

`pdiddler/intelligence_lab/stage120_corrected_guard_preview.py`:

- **REUSE** original actual PR106 `future_portfolio_planner.py` at immutable commit `6ed48e084bd58fab38e3bf061ac36fb295ecf103`, Git blob `78948cdacd2a760db5b888fce242d598fc6f14b6`.
- **REUSE** actual fixed PR182 `offer_snapshot_guard.py` at immutable commit `94ecefee86fd36293dcac58d0c24d9f379e719e5`, Git blob `11db895622d053ddced4fba9666135bf97bd615b`; validates four PHYSICAL indexed slots independent of stacked quantities; rejects any outgoing `Gingerscope` regardless of nominal profit while allowing it incoming. It replaces old Stage86's guard ONLY inside this isolated offline experiment, not main production code.
- **Separate source expiry boundary** `sourceValidUntilUnix`: even a freshly retrieved OLD publisher page cannot extend the independent approval expiry or fool the planner's existing publisher-age guard. Do not treat fetched time as publisher update; the Nov9 real Supreme archival capture expired Nov10 and remains unpriced. Every input uses `SYNTHETIC-STAGE120-V1`, `SYNTHETIC_OFFLINE_TEST` fixture binding and only `test_*` fake weapons, except the protected sentinel `Gingerscope` in synthetic tests.
- Call existing planner with `min_gain=0` (not old fixed +15, not even synthetic universal +5), and its explicit original demand/liquidity/stability and seller-side value shortlisting. For each bounded planner candidate, compare the **corrected** guard against explicitly idealized SYNTHETIC current offer/partner/session/revision; block outgoing Gingerscope. No source-derived acceptance percentage, no arbitrary highest-value opening.
- A separate `verify` step requires its own separately supplied simulated offer snapshot (never construct it on behalf of a real client), rechecks hard source expiry/revision/slot/quantity/partner/session/accepted/mutation flags with original PR182 guard. Any mismatch returns `REPLAN_REQUIRED`, never an actionable offer.
- **No gameplay:** No Roblox API, P3/Part4 change, physical items/clients, market downloads, current market quote, automatic offer/Accept/Decline, Discord/settlement/profit/strategy learning. Output `SYNTHETIC_PROPOSAL_ONLY` / `IDEAL_SYNTHETIC_MATCH_ONLY` is explicitly NOT a live trading recommendation. All `authorizesTrade`, `authorizesOffer`, `authorizesAccept`, `mayReportProfit`, `maySendDiscordWebhook`, `mayUseForStrategyLearning` always false; `tradeOutcome=UNKNOWN`.

## True limits requiring later distinct work

The corrected PR182 GUARD **allows stacks greater than four copies in up to four physical slots**, but original PR106 planner **still conservatively enumerates up to four TOTAL copies**. This adapter DOES NOT silently redefine that planner; a positive guard test with quantity x5/x6 is **not proof** a real 5+ stack is selectable or can be placed by the planner. A separate future planner migration would need explicit source/tests and slot proof, not an inference.

PR106 source liquidity score is a synthetic supplied ordinal field and is NOT observed genuine market fill time. Seller-side `max_counterparty_overpay_pct=100` here only bounds the toy search; not a real offer recommendation or probability. Independent live market freshness, observed player inventory, real checker-ID mapping, trustable demand/liquidity, 4-physical-item plan and authentic settlement remain unresolved.

## CI

`.github/workflows/gingerscope-stage120-corrected-guard.yml` fetches ORIGINAL PR106 and **corrected** PR182 source at exact immutable Git commits, SHA-validates both actual Git blobs and the exact PR182 Gingerscope outgoing guard, then runs actual modules in Python. `pdiddler/ci/test_stage120_corrected_guard_preview.py` includes +5, upgrade, downgrade, protected outgoing and incoming Gingerscope, 5/6 stacks in one slot, physical five-slot rejection, synthetic source expiry vs new retrieval, publisher expiry, item identity/demand/liquidity, simulated offer mutations (900 deterministic scenarios) and proof flag denial.

**One issue at a time.** Do not merge or request hardware without CI success, exact reviewed source and explicit handoff. After this distinct corrected-guard preview, the next blocking step is independently current and trustworthy price sources plus true market desirability/liquidity data, not rewriting existing P3/P4/LastOffer diagnostics or inventing chat.
