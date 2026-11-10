# Offer snapshot guard — strictly OFFLINE research prototype

**Date:** 2026-11-08. **Scope:** evaluate a proposed MM2 trade's current visible offer state against its original analysis snapshot, using synthetically supplied valuation and desirability evidence. **Not connected to the auto-trader. No Lua game calls, no inventory writes, no final Accept, no Discord completed-trade webhook, no realized profit and no server settlement attestation.**

## Motivation from native evidence

An earlier MM2 manual trade UI showed an old positive gain after the opponent removed one weapon. A stale label or a plan generated before a slot mutation must not survive as if the current offer had not changed. The existing Stage32/Stage59 diagnostic sees client offer changes but cannot attest server transaction outcomes; Stage53–58 raw item ↔ public checker identity review remains provisional.

Every input is untrusted, including purported identity proof, cached prices, UI slot lists, game job IDs, clocks, trade state and acceptance indicators. A passing synthetic case demonstrates algorithmic coherence, **not** that a live MM2 item ID is authenticated.

## Inputs and fail-closed invariants

- **Proposal:** sessionId, jobId, partnerKey, catalogVersion, monotonic integer offerRevision, observedAtUnix, ours and theirs (1–4 indexed visible slot entries with exact item key and integer quantity).
- **Latest local observation:** all four session/partner/catalogue bindings match; tradeOpen=true, exactPartnerBound=true, ourAccepted=false, theirAccepted=false, offerMutationPending=false; the same offerRevision. Both exact slot lists must match including index, item key and stacked quantity. Observation at most 2 seconds old; this is an offline research heuristic, not a claim that the real game guarantees that latency.
- **Research market catalogue:** source SUPREME_DISPLAY_RESEARCH_ONLY, exact pinned version, publisherUpdatedAtUnix distinct from retrievedAtUnix, publisher update within 48 hours, positive integer listed value per item, demand 1–10, known stability, with identityLinkEvidence=INDEPENDENT_EXACT supplied for every referenced item. **No current Stage58 live/raw-key mapping satisfies independent identity proof.** This flag is only used in deliberately synthetic fixtures. A Boolean by itself cannot authenticate a server-owned ID.
- **Desirability:** default research-only received-item minimum demand 4/10; receiving items marked Declining fails even when nominal list gain is positive. Stable or Overpaid For can be examined. These are configurable examples, not a proven optimal Gingerscope strategy.
- **Economics:** strictly bounded four **distinct physical visible slots** per side, with stacked quantity independently parsed as a positive integer up to original Stage9's defensive parsing bound of 1,000,000 (not a verified game-enforced maximum). Values are research-only integers. Default minimum projected gain is 0; a +5 synthetic opportunity is admitted. **Do not reinstate the old mandatory +15 rule.** A manual one-sided gift with an empty side is intentionally outside this trade-planning guard.

## Outputs and nonauthority

Every result fixes authorizesTrade=false, authorizesAccept=false, serverCompletionProven=false, mayRecordCompletedTrade=false, mayReportProfit=false, mayUseForStrategyLearning=false, exactItemIdentityAuthenticatedByGuard=false and tradeOutcome=UNKNOWN.

- REJECTED with machine-readable reason on any divergent/stale/unknown, low-demand or weakly attested identity.
- RESEARCH_CANDIDATE_ONLY for internally coherent synthetic inputs, including projectedListedGain, valueOffered and valueRequested as hypothetical list-value arithmetic, never realized profit or permission.

No Roblox, Discord, GitHub, external pricing, executor or live inventory calls. Entirely deterministic and side-effect free.

## Regression coverage

- Historical stale +17 vs actual -15 discrepancy yields an invariant: a removed weapon increases offer revision, invalidating the previous candidate even if the old label remains positive. If the revision erroneously stays the same but item/quantity differs, exact slot comparison still rejects it.
- Actual Lua 5.4: 1,600 deterministic adverse mutations plus named tests for wrong session/partner/job, changed revision, 4-slot overflow, stacked quantity changes, stale clocks, expired or absent publisher timestamp, unknown identity, low demand, undesirable stability and existing Accept.
- Python reference: 2,000 deterministic adverse mutations plus +5 candidate, quantity stacking and policy cases. GitHub Actions runs all inherited intelligence tests and actual Lua.
- **No user manual testing is needed.** Do not integrate into Part4 or Accept logic until live exact identity, publisher provenance, and transaction settlement are independently established.

## Public context — research only

Supreme Values publishes listed value, demand, stability and rarity with a public update label (e.g. November 6, 2026). See [Supreme Godly](https://supremevalues.com/mm2/godlies) and [Supreme Ancient](https://supremevalues.com/mm2/ancients). Publisher update time is not crawl time; values are not realized offers. Stage52's MM2Values updater is a separate research-only source; no Supreme entries or display-name/ID mappings were imported into this prototype.

## Integration boundary

This branch is a guard only, not a Gingerscope trade planner. It does not optimize upgrade/downgrade portfolios, choose openers, learn private Discord claims, execute an offer or decide whether a trade settled. Those remain separate questions after Stage53 identity and Stage59 provenance work.

## November 10, 2026 — audited corrections (both Python and real Lua)

Two independent failures were proven by **tests written before source edits**. Neither component is connected to live MM2 trading:

1. [Draft PR181](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/181), based on PR105, corrects the old `MAX_COPIES_PER_SIDE=4`/`MAX_QUANTITY=20` false restrictions. MM2 trade slots limit distinct offered types, not stacked copies. Python and real Lua tests assert a one-slot own x5 and received x6 candidate (+130 research units), x21 and x13 (+105) and rejection above the Stage9 parser ceiling; the separate four-distinct-slot limit remains. Test-only SHA `c45fe131af2a8cd32612d470bca21fe736d4c367` failed in the inherited Python and actual Lua gate ([RED Actions 42777866832](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42777866832)); corrected Python/Lua SHA `e29a0fbbb4edc01b53ea47cbcce2f57dee3ae2b0` passed its focused exact-commit CI. No claimed actual market prices.

2. [Draft PR182](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/182), stacked on PR181, plugs a **separate protected-asset policy gap**. The old pure guard allowed a positive `RESEARCH_CANDIDATE_ONLY` hypothetical plan with the **exact Stage83 current game raw key `Gingerscope` outbound**, contradicting the permanent user requirement to protect acquired Gingerscope and compound OTHER inventory. New Python and real Lua tests first failed on that old behavior, [RED Actions 42778131262](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42778131262). The corrected guard returns `REJECTED/PROTECTED_GINGERSCOPE_OUTGOING` regardless of listed gain; `Gingerscope` received from partner is still a research candidate. Protection here is based on the **literal known key only**, not an independently server-authenticated weapon. A future executable must enforce protection across EVERY outbound selector/rebalance/withdrawal path, not just this offline guard.

All unchanged no-authority flags remain false. The historical market input is synthetic and stale; no real final Accept, automated offer, completed trade proof, new iPad test, Discord webhook, or portfolio-learning authorization follows. These are stacked DRAFT branches, not merged production modules. Verify exact final commit workflow results and PR dependencies before integrating; Stage106 is a separate read-only identity witness.

## Additional offline worst-case public-source sensitivity (2026-11-08)

The pure `dual_source_sensitivity.py` module evaluates small candidate offers using the **ten dated, display-name-only Supreme vs MM2Values records**. It intentionally grants no game item identity, publisher clock, actual trade profit, Accept or autonomous trading authority. For each item, *received* value is bounded below by the **lowest** listed source value, while *given* value is bounded above by the **highest**; the worst-case displayed gain is the difference. The optimistic end uses highest received minus lowest given. These are mathematical source-disagreement bounds, **not executable market prices, real offers, or probabilistic forecasts**.

Real reviewed example **Emberbow for Emberscythe**: Supreme-only displayed difference is **−25**, MM2Values-only difference is **0**; combining cross-source upper/lower uncertainty yields worst **−75** and best **+50**. A naive best-case +50 label is not robust. **Chroma Emberscythe for Gingerscope**: Supreme-only difference **0**, MM2Values-only **+3,500**; the worst cross-source listed difference is **0**, not a guaranteed gain. **Harvester for Icepiercer plus three Batwings**: both public source-only gains and conservative bound remain positive (**+36** worst, **+50** best), but the result STILL does not know liquidity, demand sufficiency, MM2 item identity, actual offer feasibility or server settlement. None are trading recommendations.

Tests: `test_dual_source_sensitivity.py` includes 600 source tampering cases, 500 randomized bound containment checks and named examples. It runs in GitHub Actions with all existing Python/Lua research tests. Any result that appears favorable remains `CROSS_SOURCE_DISPLAY_MARGIN_POSITIVE_ONLY` with all authority flags false and `tradeOutcome=UNKNOWN`. No live device or user action is needed.
