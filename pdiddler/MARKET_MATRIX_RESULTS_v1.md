# MM2 Market Matrix Results v1

Date: 2026-11-02
Branch: `feature/mm2-market-matrix-v1`
Base main: `3589d67f7edeac16bfa181ee6cd82b1a9b740a5f`

## Scope

Offline-only market logic. LIVE PART 4 INTEGRATION HAS NOT STARTED.

No changes were made to Parts 1-3, the v2.5 Part 4 executor, the v2.5 combined test stack, trade timers, transaction/recovery code, or final Accept behavior.

## Candidate profile audit

Candidate:
`pdiddler/pdiddler_market_profile_2026-11-02_v1_CANDIDATE.lua`

Static GitHub source audit against active scanner v6.8:
- scanner rows: 190
- candidate rows: 190
- unique canonical `page:id` keys: 190
- missing: 0
- extra: 0
- duplicate keys: 0
- MM2Values baseline mismatches: 0
- `liveReady=false`: confirmed

Known mappings:
- Emberscythe: MM2Values 300 / Supreme 375
- Emberbow: MM2Values 325 / Supreme 375
- Chroma Mortal: MM2Values 1800 / Supreme 1600
- Chroma Immortal: MM2Values 1800 / Supreme 1600
- Chroma Embersickle: MM2Values 1100 / Supreme 1300

## Independent market recheck

Firecrawl live page extraction on 2026-11-02 independently matched the critical values/status fields:
- Supreme Emberscythe: 375, demand 5, Fluctuating
- Supreme Emberbow: 375, demand 5, Fluctuating
- Supreme Chroma Mortal: 1600, demand 5, Doing Well
- Supreme Chroma Immortal: 1600, demand 5, Doing Well
- Supreme Chroma Embersickle: 1300, demand 5, Fluctuating
- MM2Values Emberscythe: 300
- MM2Values Emberbow: 325
- MM2Values Chroma Mortal: 1800
- MM2Values Chroma Immortal: 1800
- MM2Values Chroma Embersickle: 1100

Firecrawl's structured extraction returned inconsistent page-update timestamps, so those extracted timestamps were NOT accepted as evidence. The values/status fields above matched the frozen snapshot.

## Offline runtime

The pure market engine was executed using the installed Lua 5.4 shared runtime. The module intentionally uses a standard-Lua-compatible Luau subset and has no Roblox dependencies.

Fresh verification output:
- evaluator tests: PASS
- decision matrix: 14/14 PASS
- ranking tests: PASS
- forbidden-call/static scan: PASS

Forbidden strings checked in the market logic:
- `AcceptTrade`
- `RemoteEvent`
- `RemoteFunction`
- `PlayerGui`
- `game:GetService`
- `HttpGet`
- `loadstring`

Result: none present.

## Matrix outcomes

1. Same raw value / weaker received inventory: PASS — rejected.
2. <=3% controlled upgrade into materially stronger verified item: PASS.
3. +30 downgrade into weak/Underpaid pieces: PASS — rejected because market premium raised required profit above +30.
4. Emberscythe material source disagreement: PASS — OUR side protects 375; THEIR side credits 300.
5. Fluctuating received item vs Stable equivalent: PASS — requires larger premium.
6. Moderate opponent overpay 230 -> 270: PASS — +40 remains a valid profit.
7. Extreme 20 -> 105 input: PASS — +85 and 5.25x ratio exposed for later EXTREME GUARD integration.
8. Opponent offer reduction: PASS — decision recomputes from new input; no cached decision state.
9. Missing metadata: PASS — raw safety still operates, confidence=false, no quality-upgrade credit.
10. Mixed strong+weak bundle: PASS — weak pieces remain represented in weighted risk/premium.
11. Ranking data exposure: PASS.
12. 5 vs 7 low-tier disagreement: PASS — not material because absolute difference is only 2.
13. Chroma Mortal 1800 vs 1600: PASS — material protection applies.
14. Unknown/ambiguous profile identity: PASS — canonical MM2 baseline only; no guessed market profile.

Ranking verification:
- profit beats quality-upgrade,
- outside the similarity band, highest safe OUR raw offer wins,
- inside the similarity band, giving away lower-exit-quality inventory wins,
- fewer disputed copies wins ties,
- fewer unprofiled copies wins ties,
- item quantity alone does not improve rank,
- canonical IDs provide deterministic final tie-breaking.

## Rulings made during TDD

### Controlled quality upgrade protected-loss rule

The literal plan condition `protectedProfit >= 0` made the approved <=3% raw-loss quality-upgrade exception impossible whenever MM2Values and Supreme agree, because protected value then equals raw value.

Ruling:
- material disagreement remains forbidden for the exception,
- raw loss must be <=3% of OUR raw total,
- protected loss must independently be <=3% of OUR protected total.

This keeps the intended small strategic upgrade possible without weakening cross-source disagreement protection.

### Similarity ranking

Pairwise "inside similarity window" comparisons can create non-transitive sorting.

Ruling:
- profit plans are assigned deterministic similarity bands anchored from the minimum safe raw profit,
- quality is used inside a band,
- raw-offer priority decides across bands.

This preserves deterministic ordering.

## Remaining limitation

The committed profile/test stack has not yet been executed inside Delta/Roblox from pinned raw GitHub URLs. That target-runtime run is still required before any live Part 4 integration.

This limitation does not affect the offline arithmetic evidence above, but it means executor-specific compatibility has intentionally not been claimed.

## Stop condition

Reached.

Do not wire this module into live v2.5 yet. The next step is a separate Part 4 integration design/plan after target-runtime test evidence is accepted.
