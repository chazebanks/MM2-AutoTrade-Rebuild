# Stage 18 — Read-only connection of existing trading intelligence

**Draft only. No production loader, no live quotes, no native actions, no user inventory committed, no automatic Accept.**

The project already has:
- Stage 7: finite candidate generation and hypothetical seller economics in Python;
- Stage 5: portfolio growth and Gingerscope four-copy gap in Python;
- Stages 16–17: strict item/source review and BOTH players' exchange economics in Lua.

Previously those components did not review the same proposal through one contract.
This stage adds only the missing **offline bridge**.

## Exact flow

1. Independently supplied Stage 1 Catalog, own holdings, opponent holdings, selected opponent-owned target bundle and time are validated. This does **not** prove scanner freshness, server presence or human counterparty wishes.
2. Reuse Stage 7 study_counteroffers() as the existing bounded candidate producer. Preserve its 90% coverage and experimental bounded nominal concession defaults as **research filters**, not approved trading rules.
3. Reuse Stage 5 plan_growth() against that target; annotate the candidate with Stage 5's wealth, four-copy, quality or caution lane **when it occurs in that bounded shortlist**. Missing from a Stage 5 shortlist is not automatically a disqualifying trade. Reuse Stage 1 evaluate() to calculate exact portfolio deltas for every Stage 7 candidate, including nominal-loss hypotheses.
4. Convert exact checked item IDs, quantities, source times and integer-cent prices into the existing Lua Stage 16/17 input contract. Do NOT invent source price ranges or flippability from listed price/demand. Keep the conservative 4-copy and 4-slot limits.
5. In offline replay/CI, review_in_lua() calls the **unchanged actual** p4_dual_perspective.lua Stage 17 module via a local Lua 5.4 subprocess and reports its seller-case classification next to the Stage 5 and 7 evidence. No new duplicate evaluator or acceptance policy.

Output remains quote_safe=false, native_ready=false, authorizes_trade=false, authorizes_accept=false, scan_age_proven=false. No network/API in these modules; Lua subprocess is local CI/offline only. The programmatic serialization is a constrained data literal, not an executable game loader.

## Tests

From repository root:

    cd pdiddler/intelligence_lab
    python3 -m unittest -v test_stage18_strategy_bridge

With lua5.4 installed, the above runs an actual Stage 17 Lua review.

Tests cover full Stage 7→Stage 5→Stage 17 review, a +5 trade without the old +15 floor, strict exact identities, non-mutation, missing source metadata, no-candidate result, source expiry, serializer safety, bounded searches and no execution authority. GitHub Actions runs this test after the existing Stages 8–17 tests. All fixtures synthetic.

## What this does NOT do

- Does **not** attach to the live Part 3 scanner or authorize cached opponent inventories.
- Does **not** refresh the expired November 4 Supreme snapshot. The stage refuses stale sources. A live source refresh requires independent provenance and checked mapping.
- Does **not** merge the separate two-account screenshots into one tradable inventory.
- Does **not** prove the four-type stack theoretical ceiling is executable. Four physical copies are still the conservative maximum.
- Does **not** select one 'winner' based on a fabricated acceptance probability or turn QUALITY_TRADEOFF into approval.
- Does **not** connect Stage 8/11 REQUEST_PLAN to offer insertion, verified decline, automatic Accept, live Discord, or trade outcome confirmation.

## Next separate problem

Prove an authoritative timestamped same-session scanner and trade-observer data contract, a newer source-backed market snapshot, and a reviewed plan-authorization boundary. The Stage 11 coordinator deliberately holds REQUEST_PLAN pending separately verified intelligence. No new scanner is needed; only a specific evidence-path fix, once tested, would be considered.

**No change to established Parts 1/2/3/5, original V15.8, old legacy trade policy, or the user's executing Delta code.**
