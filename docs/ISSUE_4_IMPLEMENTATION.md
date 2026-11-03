# Issue 4 implementation ledger

Authority: Issue #4 and static audit comment 6615670488. Baseline is user-tested
draft PR #3, ab84df87f58f516d525f0ec96e734cf987bfcfd2; all 146 baseline blobs
are immutable. A new branch and new versioned runtime files preserve rollback.

Execution: inline implementation with one independent whole-change reviewer.
No broad research, no additional implementer agents. Use the earlier adaptive
branch only as reference, preserving PR #3 identities and Supreme arithmetic.

1. Reproduce and fix policy/opener/ranking/negotiation in new versions. Observe
   for 2.5s, skip speculative opener on any visible item, choose an affordable
   appealing item from complete priced inventories. Rank strictly safe plans
   by a documented acceptance heuristic, not maximum giveaway; cap sweetening
   at two steps and freeze voluntary mutations on either side's Accepted.
2. Preserve controller/GUI lifetime, timers, exact quantities and four-copy
   fallback. Add whole-source Luau regressions and run all original 189 tests.
   Commit a passing behavior checkpoint before completion/native work.
3. Inspect existing native completion/acceptance/webhook references. Implement
   verifiable pure acceptance/completion/reconciliation/outbox contracts; wire
   only evidence-supported native behavior. Unproved protocol transitions stay
   disabled with a named blocker and supervised evidence checklist.
4. New versioned loader, fixed fresh Supreme snapshot, immutable pin manifests,
   original source hashes, server-hop/busy integration. One final review, full
   local and CI tests, coherent commits, SHA-pinned loader and draft PR.

Ruling: accepted instructions fully specify Approach C and inline execution;
no further design approval loop is needed. Demand/stability inform explicit
ordinal heuristics only, not a fabricated resale price or acceptance probability.

Baseline: original 189 behavioral tests pass, including original integration,
transport, price parser, new-loader, extracted helper and whole-P4 Luau fixtures.
Official Luau 0.745 is available locally. Live evidence applies to the user's
reported PR #3 ordinary startup/scanning/requests/offer interaction, not to all
edge cases or new code. Native final auto-Accept remains off until proven.

Checkpoint A+B: 13 new policy tests and 11 whole-source Luau scenarios pass;
the new tests first exposed 11 policy failures and the immediate-opener failure.
All original 189 tests still pass, with original pinned modules untouched.
The existing DP discarded appealing alternatives at equal totals; v2 retains
distinct demand/risk packs within the same bounded state budget. Initial ranking
reserves two profit bands for negotiation, then uses appeal and preservation;
no numeric value multiplier or guaranteed acceptance probability is claimed.
Manual local Accepted is observed through the known YourOffer.Accepted node;
missing indicator holds mutations, and unsafe changed manually approved offers
are declined. Four-copy mode is retained because native stack limits remain
unproved. Unavailable inventories still run the empty/overall deadlines.

Final offline result: 252 behavioral tests pass (original189 +13 policy +25
lifecycle/outbox +8 V5 integration +17 whole-source P4 runtime). All146 PR3 blobs
are hash-checked unchanged. Official Luau0.745 compiles every new runtime module.
Full output: pdiddler/audit-notes/ISSUE4_TEST_RESULTS.txt.

One independent reviewer found accepted-state reset losing prior approval,
false decline just after a verified rebalance, and startup-missing partner
inventory escaping timers. Focused regressions reproduce these cases and pass
after fixing the approval latch and bounded missing-record path. The final
reporting contract also recomputes the whole inventory from canonical Supreme
prices, requires two stable reads and exact raw-count coverage, and rejects
unrelated deltas. No caller-supplied inventory total is trusted.

Native gates: final-control/cooldown protocol, transaction correlation of the
boolean completion event, complete stable inventory mapping, persistent outbox
and Delta delivery semantics remain unproved. The tested contracts are NOT a
native adapter. V5 hard-disables Accept/completion/Discord, starts no competing
observer/sender, and reports explicit blocker metadata. See ISSUE_4_DELTA_TEST.md
for the evidence required. This is a supervised adaptive deliverable, not a
claim of full autonomy or live verification of the new version.
