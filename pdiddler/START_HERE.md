# Gingerscope — compact working entrypoint

## NOV 12 2026 — latest ACTIVE UNMERGED System 1 iPad evidence (draft PR #241)

**READ THIS before continuing old Nov 11 P1-only handoff.** An independently developed supervised System1 engine in [DRAFT PR #241](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/241) has **just passed eight separate client trade test windows on a real MAIN iPad/Delta**, user-supplied report run nonce `8f8d14d1-13f2-4bfb-8da9-a592bafb868a`, frozen tested runtime `6dbf7d70544f8441c50abcd7f284dbff49605f83`: 8 requests, 10 MAIN guarded placements/removals, 7 MAIN declines, 1 expected ALT cancellation, 8 client closures, one stacked ×2, one Chroma, bounded delay, ALT 2→1 slot compaction (1 observed live reindex), MAIN guarded two/four-slot withdrawal (0 own reindexes observed live), two ALT offer revisions and distinct reoffer. [Full immutable PR issue comment](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/241#issuecomment-6817606073); [live updated acceptance matrix](system1/SYSTEM1_COMPREHENSIVE_ACCEPTANCE_MATRIX_2026_11_12.md). **Do NOT repeat ARM4/ARM5/ARM8 happy paths.** Preserve failed startup blob-pin 404, hidden ARM8 selection UI, premature stack validation, and their corrections as historical proofs.

**What this means:** closes ONLY the supervised fixed-consenting-ALT multiwindow **client-side** testing. `finalAcceptEverAttempted=false`, `serverCompletionProven=false`, `verifiedCompletedTrades=0`, `tradeOutcome=UNKNOWN`. No authenticated raw weapon instance, fresh market price, liquid profit, learner label, Discord profit or unattended trading authority. Only one consenting ALT participated; **no true player rotation proven**. The **next distinct System1 vertical** is eligible/blacklisted multi-player P3 scanner and request rotation, new joins/incoming priority, normal cancel recovery and safe exhaustion/hop, with 2+ consenting participants, original P3/P4 lease and first-error STOP. Develop System2 synthetic portfolio quality and System3 quarantined learning offline in parallel; never use these client-only receipts as settlement. Keep PR241 DRAFT and **do not merge or deploy** on this evidence alone. Always check latest GitHub PR/CI/branch/main before action; this Nov12 record is on **PR241 draft branch**, not necessarily main.

---

## NOV 11 2026 — VERIFIED PLAN/HANDOFF ENTRYPOINT

For the **next conversation**, read `pdiddler/NEXT_CONVERSATION_HANDOFF_2026_11_11.md`, `pdiddler/continuity/NEXT_WORKPLAN_2026_11_11.json`, and `pdiddler/continuity/LEGACY_CLEANUP_AUDIT_2026_11_11.md` after the continuity `verify`/`recover` gate. This is the **planning-only** update anchored at reviewed main `f27002118363a544321bb7f0f1af00c2f2124d1a`. No Part3/Part4/Delta, gameplay, market-priced trading or automatic final Accept code was changed. Check GitHub's current HEAD before assuming this PR is merged. Continue exactly one distinct task: independently verify a genuinely new first-party publisher source version with original Stage111→110→104→69 raw provenance. Keep market, trade, learning and settlement authority disabled until separately proven. Long-term growth/attractiveness, one-side-versus-partner appeal, learner verification and conditional listed-value-loss direction remain intact.

**Purpose:** get the current verified state and task-specific source evidence without preloading megabytes of repeated handoffs. This is an index, not a replacement for source records.

## The required first checks

1. Inspect the **actual latest main HEAD**, current target PR, action runs and any in-progress change. A displayed stage number is not proof a branch was merged.
2. Run `python3 -m pdiddler.continuity.manager verify` and `python3 -m pdiddler.continuity.manager recover` in a checkout. Inspect `pdiddler/continuity/manifest.json`, `policy.json`, `current_state.json` and `history_index.json`. **Stop on any stale or conflicting source pin.**
3. Consult `pdiddler/strategy/growth_policy.json` **if present on this branch**. The November 11 direction is development of future bounded controlled listed-value-loss upgrades; **no live losses or auto final Accept are authorized without a separate explicit deployment decision**.
4. Read only the historical PRs, files, failed hypotheses, device receipts and CI results **relevant to the current change**. The stage-title catalog is incomplete and cannot certify that all stages have been read.
5. Implement and test one real issue at a time. Run focused tests then inherited regressions. Preserve a lossless, immutable reference before reorganizing source.

## Known evidence boundaries at the initial cleanup

- Stage119: protected P3/P4 **client-side** observations; no verified server settlement. Previously closed physical iPad test; do not re-run merely to fill a progress metric.
- Stage120: offline **synthetic** PR106 portfolio planner + corrected PR182 four-physical-slot/target guard. Its original planner still limits candidate total copies to four, separately from physical slots.
- Stage121: research-only first-party source-to-strategy firewall. A value publisher version, source refresh, or demand label is **not** proof of retradable liquidity or a completed trade.
- PR229 continuity: metadata-only recovery / job ledger. Not an autonomous dispatcher, not a trading runtime, not automatic iPad data ingestion.
- PR230 growth direction: conditional quality-loss policy, and **not a passed risk budget or live trading approval**. Check current branch/PR merge state independently.
- Gingerscope remains a protected **incoming target**, never an outbound offered item. No obsolete universal +15 or forced highest-valued opener, no autonomous chat negotiation.

## Source-on-demand: original evidence is retained

| What changed | Source |
|---|---|
| Current evidence index | `pdiddler/continuity/README.md` and `pdiddler/continuity/history_index.json` |
| Latest canonical events | `pdiddler/GINGERSCOPE_NEXT_CONVERSATION_CANONICAL_2026_11_10.md` |
| Latest checkpoint | `pdiddler/GINGERSCOPE_LATEST_CHECKPOINT.md` |
| Original strategy constraints | `pdiddler/GINGERSCOPE_STRATEGY_AND_RESEARCH_PLAYBOOK.md` |
| All older dated handoffs | `pdiddler/GINGERSCOPE_ACTIVE_HANDOFF.md`, `pdiddler/GINGERSCOPE_READ_FIRST_NEXT_CONVERSATION.md`, `pdiddler/CHATGPT_HANDOFF.md` |
| Supervised iPad tests | `pdiddler/supervised/SUPERVISED_ONE_ITEM_PILOT_HANDOFF.md` |
| Trading strategy offline | `pdiddler/intelligence_lab/STAGE120_CORRECTED_GUARD_PREVIEW_HANDOFF.md` |
| Market source boundary | `pdiddler/intelligence_lab/STAGE121_SOURCE_TO_STRATEGY_HANDOFF.md` |
| Cleanup aliases and restoration | `pdiddler/history/REMOVED_DUPLICATES_2026_11_11.json` |

**No historical handoff was deleted by this pass.** They have valid original source and immutable Git SHA provenance. Keeping their contents out of the default read path is what reduces token/time overhead.

## Prohibited shortcuts

- Do not execute old `pdiddler4_balancer_ROTATING_v2_3_EXTREME_GUARD.lua` for the new strategy: it retains a mandatory highest opener and +15 floor. It is a historical test fixture, not an approved active implementation.
- Do not purge 236 branches without individually checking merged/unmerged code, linked PRs, pinned device results, and unique historical proofs.
- Do not put private Discord messages, real inventory, player identifiers or executor telemetry into the **PUBLIC** repository.
- Do not claim that a simulated positive result proves true MM2 server Accept/settlement or real trading liquidity.

This file is short deliberately; inspect original evidence as needed, and update this index only after verifying new state.
