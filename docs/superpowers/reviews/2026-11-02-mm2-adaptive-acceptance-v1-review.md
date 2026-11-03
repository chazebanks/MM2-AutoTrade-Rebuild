# MM2 Adaptive Acceptance v1 Final Review

Date: 2026-11-02

Branch: `feature/mm2-adaptive-acceptance-v1`

Base: `e393fee65dd769cad76077e3c8b0d72ccece99dd`

Reviewed head before documentation: `50f89bb46f76f94b840cbc434df888aa2eea5b7b`

Plan:
`docs/superpowers/plans/2026-11-02-mm2-adaptive-acceptance-v1.md`

Spec:
`docs/superpowers/specs/2026-11-02-mm2-adaptive-acceptance-aware-trading-design.md`

Review type: self-review using the Superpowers code-review checklist because no independent subagent/reviewer tool is available in this harness.

## Scope reviewed

New production/runtime artifacts:
- `pdiddler4_market_logic_v2_ACCEPTANCE.lua`
- `pdiddler4_acceptance_policy_v1.lua`
- `pdiddler4_market_planner_v1_3_ACCEPTANCE.lua`
- `pdiddler4_balancer_ROTATING_v2_5_ADAPTIVE_ACCEPTANCE.lua`
- `pdiddler_MANUAL_ACCEPT_GAIN_WEBHOOK_TEST_STACK_v5_ADAPTIVE.lua`

New regressions:
- `pdiddler4_acceptance_policy_v1.luau`
- `pdiddler4_acceptance_planner_v1.luau`
- `pdiddler4_adaptive_part4_contract_v1.py`

CI:
- official Luau 0.745 compilation for all new modules,
- all pre-existing market/trade/webhook/Part 3 regressions,
- new acceptance policy matrix,
- adaptive Part 4 static/integration contract,
- bounded dual-variant planner regression,
- v5 stack wiring/pin guard.

## Strengths

1. **Safety and appeal are separated.**
   The existing planner still decides which trades are legal. Acceptance policy only orders already-safe plans or chooses not to present an unattractive safe plan.

2. **Highest-value-first opener is removed.**
   Part 4 observes THEIR side first for 2.5 seconds and only uses a market-aware opener when they remain empty.

3. **Stale opener race is defended twice.**
   THEIR side is observed during the window and re-read immediately before the opener remote fires.

4. **Sweetening is bounded and generation-bound.**
   It uses the unchanged THEIR signature, offer generation, and a maximum two-step 5s/10s progression. No detached `task.delay` callbacks exist.

5. **The old planner behavior was not simply reversed.**
   Same raw/protected DP states retain at most two variants: the low-exit safety extreme and the high-exit/low-risk appeal extreme. This preserves the existing bounded quality-upgrade path while allowing human-facing plans.

6. **Raw/checker identity is preserved through the new opener.**
   Market lookup uses `checkerId` when present while the selected opener retains the raw `Weapons.Owned` key for executor use.

7. **Final trade acceptance remains manual.**
   No new production/runtime file contains `AcceptTrade`, physical Accept/Confirm, `firesignal`, or a Discord webhook credential.

8. **Known-good artifacts were not edited.**
   The implementation is new versioned modules plus tests/workflow changes.

## Important findings fixed during review

### 1. Adaptive opener raw/checker identity mismatch

Original review finding:
- the opener queried the profile with the raw owned ID;
- raw keys such as `Iceblaster` with checker ID `481` could be incorrectly treated as unprofiled.

TDD evidence:
- RED run: `41565010480`, failed at the new adaptive acceptance identity regression.
- Fix: `78fa90b21c63bc8bed412076cf5f01c33b48d70f`.
- GREEN run: `41565080100`.

The v5 live stack is explicitly pinned to the fixed commit.

### 2. Final pin guard was inserted into the wrong legacy CI block

Finding:
- a workflow edit accidentally put the v5 pin assertion inside the old webhook-v1 contract.

Evidence:
- run `41565167805` failed at the old completed-trade webhook stack contract;
- runtime trading code itself was unchanged.

Fix:
- `50f89bb46f76f94b840cbc434df888aa2eea5b7b` moved the assertion into the v5 wiring guard.

Final verification:
- run `41565278318` SUCCESS.

## Critical issues

None found in the reviewed branch.

## Important unresolved issues

None that can be established offline.

## Deferred minors

1. The v5 stack still carries historical metadata variables such as `NO_PLAN_BASE` / old no-plan commit identifiers that are not used to load the adaptive Part 4. They do not affect runtime behavior. Avoid changing the tested stack only for cosmetic cleanup before live validation.

2. Some v5 header comments still describe the earlier v2.6 lineage. They are historical context, not runtime logic.

## Rulings

### Ruling 1 — any visible non-empty THEIR OFFER suppresses the opener

The design initially described a resolved/non-empty offer. Runtime v2.5 suppresses the opener as soon as a visible non-empty THEIR side appears, even if resolution is not yet complete.

Reason:
- visible counterparty action is stronger evidence than our guessed opener;
- firing an opener while their UI is changing creates a race and poor negotiation signal.

Cost if wrong:
- an unresolved/junk visible item may leave us passive until the existing bounded window rather than showing an opener.

### Ruling 2 — recovery remains safety-authoritative over manual-Accept display

The manual-Accept freeze prevents voluntary opener/rebalance/sweetening. If a transaction has already become uncertain and `recoveryNeeded` is active, recovery remains allowed before the manual-Accept hold check.

Reason:
- recovery exists to restore a non-authoritative/partially-mutated offer to a known state;
- treating a broken partial offer as frozen merely because local Accepted became visible could preserve an unsafe state.

Cost if wrong:
- in the rare overlap of manual Accept and active recovery, the script may clear/repair OUR offer and thereby reset the local acceptance.

### Ruling 3 — no guessed set premium or current-event penalty

The market supports set-specific behavior and event volatility, but the canonical profile does not yet provide verified set membership/premium or current-event age for every item.

Reason:
- adding guessed set/event economics would violate the canonical-identity/value rule.

Cost if wrong:
- v1 can miss profitable set completion/preservation opportunities or react more slowly to event-item volatility.

## Verification evidence

Final CI:
- run `41565278318` — SUCCESS.
- official Luau 0.745 compile step — SUCCESS.
- legacy market/webhook/Part 3 regressions — SUCCESS.
- adaptive acceptance policy matrix — SUCCESS.
- adaptive Part 4 contract — SUCCESS.
- dual-variant planner regression — SUCCESS.
- adaptive v5 stack wiring/pin guard — SUCCESS.

Independent static safety scan of all five new runtime files:
- no `AcceptTrade`,
- no physical Accept/Confirm,
- no `firesignal`,
- no `task.delay` stale callback path,
- no embedded Discord webhook credential.

## Live-only uncertainties

CI cannot establish Roblox/MM2 UI/replication behavior. The following still require recordings:

1. THEY offer within 2.5s -> opener is skipped.
2. THEY stay empty -> realistic opener is placed and verified.
3. Raw/checker opener identity works live on an item such as Iceblaster.
4. No realistic opener -> OUR side remains empty without hanging.
5. Acceptance ranking chooses the healthier counterparty-facing safe plan.
6. Unchanged THEIR offer -> one sweeten near 5s and final sweeten near 10s, no third step.
7. THEIR mutation during sweetening invalidates the old generation.
8. Appeal tier D produces a hold instead of forcing an ugly bundle.
9. Manual Accepted freezes voluntary mutations.
10. Completed trade still emits exactly one verified webhook with inventory-after and Trade ID.
11. Existing unchanged no-safe-plan >5s decline remains live-correct.
12. Existing Part 3 fully-unproven outgoing retry path still awaits live proof.

## Assessment

**Ready for controlled live testing: YES.**

**Ready to declare production-complete: NO.**

The offline implementation is internally consistent and fully green, but the new negotiation behavior depends on MM2 UI timing and human interaction. The next gate is a controlled recording, not automated final Accept.
