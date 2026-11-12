# Gingerscope System 2 — manual Supreme reference and offline bridge
**Date:** 2026-11-12. **Scope:** one new offline-only human reference packet; separate System 1 runner. **Do not merge or enable live economic actions solely from this checkpoint.**

## Product decision
1. Use [Supreme's official MM2 calculator](https://supremevalues.com/mm2/calculator) personally to check *a particular contemplated trade*. For human use it already shows current values/ranges, demand, stability, and warnings about item stacks. You do not need a second paid Discord bot, private API, proxy, browser auto-scraper, or nightly weapon-table ingestion.
2. Keep existing **daily Supreme publication-change monitoring** at the public homepage/changelog level. An alert signals **human review**, not permission to copy or auto-import item-value data. Avoid duplicate scheduled tasks or automatic price-file edits.
3. Supreme [Terms](https://supremevalues.com/tos) prohibit copying the list into an application even by manual transcription; their stated strictly individual permitted examples include browsing, writing paper notes and an arithmetic calculator. A human using their own calculator is distinct from training or auto-pricing Gingerscope. No complete Supreme catalog, item price, demand or stability field may pass into this module.
4. Supplied *offer labels* come only from our own client-side observation, and are UNVERIFIED descriptors. The packet links to Supreme's first-party calculator. It is never authorized to make, revise, decline or Accept a trade. A website review does not prove raw key identity, current revision, upstream rights, settled transaction, liquidity or opponent attractiveness.
5. System 2's offline portfolio research may proceed with **synthetic or independently licensed** datasets, keeping every outcome and confidence clearly separated. The existing Stage120 synthetic strategy, PR #232 sensitivity work, and unmerged planner PR #243/#244 must be checked before any new strategic code; do not duplicate or overwrite them.

## Actual System 1 state verified before starting System 2
- [PR #241](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/241) remains DRAFT; its detailed acceptance matrix and operator receipt document **ARM8 8/8 iPad CLIENT PASS** on 2026-11-12 (original ARM4 and ARM5 also passed). Client script verified bounded request / offer / withdrawal / decline / revisions, NOT final Accept or server settlement.
- Next *distinct System 1* task is multi-player scanning/rotation/incoming/hop with safety and one test case at a time. Do NOT retest closed ARM4/5/8 happy paths. System 2 can work offline in parallel, but neither supersedes that field coverage nor grants unattended release.
- Stage121 source firewall and nine release gates remain blocked for real market prices, item identity, settled trades and autonomous final Accept. Gingerscope is permanently forbidden outbound. No universal +15, mandatory highest-valued opener, auto-chat negotiation, unverified training labels or unapproved loss budget.

## First tested System 2 boundary
- `pdiddler/system2/supervised_supreme_reference.py`: pure function `make_review_packet`; accepts only observed item label / quantity / broad category on up to four PHYSICAL slots per side. Allows stacks greater than four copies while each slot counts as one. Links to exact first-party calculator, marks all game item identities and outcomes UNKNOWN, prohibits Gingerscope outbound and unrecognized fields such as copied price/demand/stability. Cannot fetch, store or evaluate Supreme data.
- `pdiddler/ci/test_system2_supervised_supreme_reference.py`: synthetic names only, rejects wrong types, URL/field injection, 5th physical slot, Gingerscope outgoing, unsanctioned market metrics and autoAccept. Run `python3 -m unittest -v pdiddler.ci.test_system2_supervised_supreme_reference`.
- Result is a **supervised read-only reference aid**, not a current value feed and not a trading algorithm. The user manually selects items in Supreme's own calculator and independently decides whether to trade. We cannot silently relay those results into the trading engine.

## Next System 2 work (after this one distinct issue)
1. Inspect latest PR #243/#244 state and integrate their planner slot/target corrections only after separately passing tests/review; no racing parallel edits to same planner.
2. In a separate offline-only test, compare strategy options (upgrade, downgrade, sidegrade, no trade) using clearly synthetic, revision-scoped inputs, with a separate estimate of *our long-term benefit* and *the opponent's appeal*. Never claim demand stars or posted offers equal actual acceptance probability.
3. Independently verify client identity, settlement and guarded genuine market authority before live source-aware P3/P4 suggestions or auto final Accept. Any unknown / changed offer -> re-review.
4. Continue user-approved System 1 multi-player coverage separately. No real trade execution, cloud deployment, Discord learning or webhook reporting is authorized here.

**Do not use RBLXValue account credentials after the reported ban. No provider contact was initiated.**
