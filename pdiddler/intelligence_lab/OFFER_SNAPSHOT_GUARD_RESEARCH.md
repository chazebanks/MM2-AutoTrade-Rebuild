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
- **Economics:** strictly bounded four visible slots per side, up to 20 units per slot for hypothetical stacked quantities. Values are research-only integers. Default minimum projected gain is 0; a +5 synthetic opportunity is admitted. **Do not reinstate the old mandatory +15 rule.** A manual one-sided gift with an empty side is intentionally outside this trade-planning guard.

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
