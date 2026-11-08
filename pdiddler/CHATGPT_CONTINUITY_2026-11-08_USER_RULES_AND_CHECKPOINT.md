# MM2 Gingerscope continuity — user operating requirements and audited checkpoint

**Audited:** November 8, 2026 (America/New_York). **Purpose:** Persistent context for the NEXT conversation, not executable code or an authorization to trade.
**Shared conversation to revisit:** https://chatgpt.com/share/6af1033e-70d4-83e8-9f06-32c4a6b855ff
**Current repository:** https://github.com/chazebanks/MM2-AutoTrade-Rebuild

## Read order / precedence

1. `pdiddler/GINGERSCOPE_ACTIVE_HANDOFF.md`
2. `pdiddler/GINGERSCOPE_READ_FIRST_NEXT_CONVERSATION.md`
3. `pdiddler/GINGERSCOPE_STRATEGY_AND_RESEARCH_PLAYBOOK.md`
4. `pdiddler/FUTURE_OFFLINE_PREBUILD_MATRIX.md`
5. Recent GitHub PR heads/comments and exact-head GitHub Actions, not merely historical summaries.

The historical `pdiddler/CHATGPT_HANDOFF.md` includes superseded strategies. Use it as history only, not active trade policy. Newer verified checkpoints supersede older Stage44 and Stage52 "next" instructions embedded deep in appended documents. Do not blindly merge any stacked old PR or seven future research drafts.

## The user's explicitly requested collaboration discipline

- Do not be a yes-man. Challenge proposals, independently form and explain defensible technical opinions, and separate agreement from evidence.
- Research beyond large mainstream sites. Examine real repository code, primary API/game evidence, GitHub commits, specialist trading sources, official market pages, relevant communities, and independently corroborated observations. Record dates, URLs, contradictions, weaknesses and what each source actually establishes. No invented completion/profit/acceptance evidence.
- Before ANY patch: investigate root cause; review interfaces between modules, regressions versus last working state, duplicate/conflicting logic, stale state and callbacks, race conditions, UI/world loading, executor limitations, wrong actor/job/session/offer revisions, unsafe retries, malformed or missing data, spoofed provenance, source freshness, and failure recovery.
- ONE scripting issue at a time. Finish its evidence, tests and regressions, then discuss secondary issues. Do not blindly append fixes, rebuild already-working modules, or introduce unrelated strategy defaults.
- Use actual Python tests as well as native Lua 5.4 tests, adversarial/property tests and CI wherever applicable. Test failure scenarios and cross-module interoperability, not only passing happy paths. Never equate simulations with native game proof.
- Review recordings and logs for failures as carefully as successes. Give exact execution instructions for any later requested Delta test (including what to do DURING execution); prefer a single pinned loader with reliable clipboard export when safe and practical.
- Continue work autonomously WITHIN an active user turn after reported results, until real manual game access or a material question blocks progress; do not require ritual "continue" or claim asynchronous/background work.
- Default live device = MAIN iPad/Delta; use ALT iPhone only when essential. The ALT Stage59 recovery/manual test is **PAUSED by user**. Do not request any manual tests until the user resumes it or it becomes genuinely necessary for the chosen problem.
- Preserve precise next-chat handoff notes on status, tested head/CI, unknowns, source evidence, safety restrictions, and next ONE issue. Do not preserve or expose Discord bot/webhook tokens or other credentials.
- The user explicitly requests all relevant work be remembered between conversations. These repository files are the durable evidence; assistant memory alone is not a substitute for reading them.

## Actual goal and hard policy boundary

Acquire a genuine MM2 **Gingerscope** through safe inventory compounding and attractive two-sided trades. Balance listed value with real demand, liquidity, retradability, stability, concentration and the counterparty's incentive; respect **four physical trade slots per side**, stacked quantities, and exact variant/identity. Research fair offers, upgrades, downgrades, quality consolidation and seller-aware proposals. An illustrative +5 listed gain is not forbidden; the old mandatory +15 rule must NOT return. Do NOT inherit old first-item opener, fixed timing/sweetening, 90% thresholds, old rotation/hops, old values or auto-Accept just because they appear in historical code. Reusing a proven mechanical subcomponent requires separate validation.

**Absolute safety:** no automatic final Accept, no server-proven completed-trade claim, no realized-profit webhook, no live market authority, and no learning from unverified trade history until genuine identity/session/settlement proof exists. Unknown must remain UNKNOWN; a successful UI close, user manual acceptance, matched client deltas or a named remote alone is not server settlement.

## Verified latest project checkpoint (Nov 8, 2026)

- Discord private history import: 57 messages inspected, 50 archival records, **30 from test alt `venossgaming90190` excluded**, 17 internally consistent but **UNVERIFIED** self-reported trade claims, 3 quarantined; **zero** server-proven settlements and **zero** learning-eligible records. Private archive in `chazebanks/MM2-Trade-Research-Private`; do not export private logs into public repo. Discord learner expansion paused after archive/read-only validation.
- Stage52 gated daily MM2Values updater: **PR #96 merged to main**; research-only publication safeguards, not current live price authority. The old Stage52 PR #91 was stacked on unmerged PR #90 and is superseded for deployment.
- Stages53–58: real client Sync catalogue, mapping coverage and candidate diagnostics were run. `Sync.Weapons` and `Sync.Item` same Lua table in the tested session (1,040 rows). ~190 eligible client rows resolve within current scanner, yet many use aliases/normalization/fuzzy matching; **no independent official raw weapon key → exact Supreme/MM2Values checker numeric ID/variant authority**. Stage58 crosswalk remains provisional and draft. Do not mistake a 190/190 resolution rate for authenticated identity.
- Stage59 PR #104: manual two-client correlation is **NOT** proven. The ALT-labeled and MAIN-labeled submissions had the **same RECEIVER receipt/role**, not independent client evidence. Earlier saved-report button and clipboard overwrite issues were found/corrected in offline code; real iPhone recovery of the genuine ALT SENDER report was not completed. Manual recovery and further paired-client tests PAUSED. Result remains UNKNOWN.
- OFFLINE draft PR #105 offer mutation/price/demand/identity guard, #106 bounded upgrade/downgrade planner, #107 Lua runtime supervisor, #108 server-candidate/bot-like-signal classifier, #109 unsent Discord preview, #110 up-to-500-type inventory shortlist, and #111 pinned SHA cross-module contract smoke tests. **All seven remain DRAFT, UNMERGED, research-only.** Relevant exact-head successful PR111 Actions run: https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42513500968 (cross-check the latest head and runs before work). Synthetic mutation tests passed, not live Delta/Roblox proof.
- PR111 HEAD recorded at this audit as `9852962b5ff996f9e7c6ae2e29df02930b484b8b`; offline compatible examples included shortlist→planner→guard→unsent preview, plus Lua supervisor→Python server shortlist, testing stale/session/price/identity and unsafe hop context. No production adapter enabled.
- Keep distinction between successful prior device observation, local-only evidence, offline simulations, unmerged drafts, and merged production. The target is NOT finished, regardless of how many tests pass.

## Next one issue to prioritize when development is explicitly resumed

**Prevent unverified Stage58 item identities from being promoted into verified trade eligibility merely by passing caller-supplied trust flags through the PR110→PR106→PR105 boundary.** Build a negative contract test with hostile/provisional IDs, mismatched variants, stale source provenance and forged 'verified' booleans; inspect the real interfaces first, and only propose a narrowly-scoped fix. Then evaluate Lua parity and integration work for the remaining Python modules. Do not silently turn an offline prototype into trading behavior.

**Known future tasks (not authorization to do all at once):** Lua parity tests for #106/#108/#109/#110; quantity-conservation and concentration property tests; stale callback, near-full join, exhausted-hop and rejoining failure simulation; source publisher-time/authenticity; Stage59 iPhone recovery when explicitly resumed; exact external weapon IDs; server-attested completion provenance; main iPad/Delta UI and world readiness; eventual safe controlled integration. 

This file is a continuity record only and changes no game code, market values, production loader, automatic Accept, Discord sends, or server navigation.
