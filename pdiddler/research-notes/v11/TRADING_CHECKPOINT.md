# V11 trading checkpoint — 2026-11-04

Baseline: PR #12, ca09aaddd7982fcfd794d4aa8cecea79a91c41f7. Existing files remain byte-identical. The new Part 4 v6 and policy v7 are isolated successors; the existing opener, early-counter policy, UI readiness gate, scanner and outgoing v16 remain authoritative for their responsibilities.

## Evidence and decisions

Issue #6 research is preserved separately in draft PR #13 (1fd11876deacb3ed22039cf1a3ad7c76073a6bef). It contains source references, quarantined market data, strategy comparisons and a separate personal roadmap. It finds no independently verified completed-trade sample from which to fit an acceptance model. Demand/stability are useful relative proxies; liquidity data are mostly absent. No evidence supports maximizing the opponent's offer less 15 as an opening price, always offering the highest item, or a universal knife preference. Existing adaptive, partner-reachable opener and bounded concessions are retained. Policy budgets are conservative design choices, not measured acceptance probabilities. Personal item goals do not enter runtime.

Nov 3 native recording shows an approximately 6-second acceptance cooldown. Keep the existing 9-second late wait and native ACCEPT visibility plus 2.5-second ready buffer; the earlier research's nominal 5-second wait does not override this evidence.

## Root causes and changes

1. An opponent-first initial quote was followed by a second early response to the same signature. A physically verified initial quote now consumes that signature's early decision.
2. Late negotiation counted proposals as completed improvements. Policy v7 reserves one pending proposal; only exact actual slot verification and a safe trade decision commit the step. Failed verification blocks further late concessions for that signature.
3. A failed replacement could recover to empty slots and obtain a larger fresh initial quote. An unverified mutation now retains its failed signature. Once safely cleared, an unchanged opponent offer is declined rather than given a new price budget. A genuinely changed offer can be evaluated again.
4. Old session cleanup waited for any visible trade after a stale inventory yield. It now follows the retired root's visible lifetime and rearms only after its witnessed close or replacement. Old callbacks remain fenced.
5. The overall timer could decline a trade while both native Accepted indicators were visible. A verified, unchanged, profitable pair is observed without mutations for at most 15 seconds, then terminally held as completion-unconfirmed. Every poll retains freshness, valuation and approval-signature protection. The integration must synchronously stop outgoing work via holdOutcome and hold hopping. Changed or unsafe approval still declines. This is not completion evidence.

## Verification

All checks passed locally: original integration58; trading118; snapshot refresh13; Issue4 additional63 (252 original behavioral cases combined); V6 policy7; V7 policy9; V8 UI gate12; V9 early policy26; V10 selection14; V10 bootstrap8; V10 actual-P4 fixture7; V11 actual-P4 fixture14 (7 inherited +7 new); V11 verified-step unit3. These are offline/simulated tests. Original frozen-source/hash and pin checks pass in their runners. Official Luau0.745 compiles and executes the full production P4 in a Roblox boundary fixture.

New regressions were observed failing before the relevant correction: duplicate initial response, proposal-count timing, visible-lifetime rearm, paired-acceptance safety, and recovery-empty budget bypass. The successful late verification case additionally exercises real offer rendering, removal and re-addition.

Native automatic acceptance, correlated completed-trade accounting, whole-inventory reconciliation and network Discord delivery remain OFF. A GUI close or bare boolean completion event cannot establish a completed trade. Existing pure verification/outbox modules remain preserved, not promoted to native verified status. No new live-trading success is claimed.

Follow-up: successful physical verification also advances the observed signature before yielding. This prevents a valid immediate pair of Accepted indicators from comparing against pre-mutation slots; the changed-offer guard remains tested.
