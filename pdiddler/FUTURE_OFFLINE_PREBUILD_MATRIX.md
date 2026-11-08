# Gingerscope auto-trader — full-system offline prebuild matrix

**Reviewed:** 2026-11-08. **User directive:** Prepare ALL safe modules that can be implemented and tested offline, including future stages, without waiting for in-game testing or repeatedly asking for permission. Keep workstream boundaries, hard safety checks, actual Lua/Python regressions, exact-head CI and handoff notes. **Do not request manual device tests while user is on the main iPad and ALT iPhone recovery is paused.**

## Current core facts

- Stage52 mainline gated MM2Values page audit is merged and research-only; copied listed prices are NOT trusted current trading prices. Stored historical source date is not authenticated publisher update time.
- Stage53–58 display identity review produced only provisional raw weapon-key / external checker mappings; neither item-copy identity nor numeric checker IDs are independently proven.
- Draft Stage59 PR104 collected client-only results but prior "ALT" and "MAIN" reports were **identical RECEIVER receipts**. No authenticated ALT SENDER counterpart, server settlement proof or realized profit. iPhone-only recovery remains a **later manual dependency**, paused at user request.
- The target is inventory compounding toward Gingerscope through upgrades, downgrades, and desirable/liquid weapons. **No mandatory +15 rule**. Four visible trade slots per side. No auto-final Accept until exact identity, offer mutation invalidation and outcome verification are genuinely proven.

## Offline future components built and CI verified

| Draft PR | Component | Verified scope | Exact-head passing Actions |
|---|---|---|---|
| [#105](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/105) | Offer snapshot guard | Reject stale offer revision, changed slots or stack quantity, unknown identity, old publisher timestamp, poor demand/stability; +5 synthetic gain allowed; 1,600 native Lua mutations and Python tests | [42507323389](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42507323389) |
| [#106](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/106) | Bounded portfolio planner | Hypothetical 4-slot upgrades, downgrades, sidegrades; stacks, listed value, demand, liquidity and concentration penalty; strict maximum five types per side; 600 adversarial cases | [42507971573](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42507971573) |
| [#107](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/107) | Runtime state supervisor | Native Lua state-machine gates world/UI readiness, stale async epochs, session/partner, plan invalidation, closed-unknown trades, combat/hop cooldown, no actions; 5,000 fuzz transitions | [42508444280](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42508444280) |
| [#108](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/108) | Server/bot-signal intelligence | Cautious 10-second multi-signal behavior classifier; ignored voice chat; 11/12 then 10/12 observed population preference, full/visited/bot-like filters, no hop in combat/trade/loading; 1,000 malformed samples | [42508894936](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42508894936) |
| [#109](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/109) | Discord report preview | Hypothetical item names, stack counts, value/demand/liquidity, listed difference and inventory-total forecast; refuses tokens, usernames, mentions, and completed-trade claims; 1,000 adverse cases, **no sending** | [42509304817](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42509304817) |
| [#110](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/110) | Full-inventory preselector | 500-type input max, synthetic 112-type scale, explicit identity/risk/budget exclusions, stratified five-type shortlist without silent truncation; 1,000 malformed cases | [42509795411](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42509795411) |
| [#111](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/111) | Offline cross-PR integration contracts | Immutable pinned PR105–110 source checkouts; synthetic inventory → planner → fresh-offer guard → unsent preview, plus actual Lua supervisor → Python safe-server suggestions. 1,000 stale offer mutations and 900 unsafe-hop context mutations; no device, no accepting or sending | [42513500968](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42513500968) |

**All seven PRs (#105–#111) remain DRAFT and unmerged.** Successful CI means the tested offline behavior passed, **not** that any module works in Delta or may perform live trades. The source identity and result attestation gaps are deliberate blockers.

## Future integration dependency graph

1. **Market/identity input:** Stage52 research source and Stage53–58 client/raw/checker provenance must become independently adequate for *evaluating* hypothetical weapons. Do not elevate current provisional entries by setting a proof flag.
2. **Inventory shortlist:** PR110 operates on supplied broad inventory and opponent catalogues, reports excluded/uncertain types and produces at most five types per side. No hidden truncation.
3. **Portfolio strategy:** PR106 scores upgrade/downgrade/sidegrade research candidates from the bounded shortlist, respecting four slots, stacks, net listed gain and demand/liquidity/concentration.
4. **Exact offer recheck:** PR105 only evaluates a chosen candidate against fresh bound job/session/partner/offer revision, current displayed slots and market version. A cached green gain must be invalidated after ANY visible mutation.
5. **Runtime readiness and event arbitration:** PR107 drives a future event contract for world loading, 1.5-second UI stability, target scan, request observation, trade session, offer updates, unknown completion and safe hop candidates. It does NOT press controls.
6. **Server intelligence:** PR108 may provide suggested destinations and bot-like signals to PR107 once real, labeled behavior and a platform-supported server-selection adapter are proven. Server population is not a real-time reservation. Real join errors must be handled separately.
7. **Trade outcome:** Stage59 independent client reports still require authentic transaction/session/result binding. Even reciprocal inventory deltas without proof are not a verified completed trade.
8. **Notifications:** Only after trusted settlement plus a reliable post-close inventory value can a later controlled notifier adapt PR109 layout for real Discord posting. The private historical self-reported messages remain quarantined and test-account transactions excluded from learning.
9. **Live UI adapters:** tablet startup, Join-a-friend Play, physical request-button clicks, world/character loading gates and actual offer placement require separate Roblox/Delta device evidence. Do not claim these are solved offline.

## Next work that can still be done offline, without contacting user

**Cross-PR dependency smoke tests COMPLETE (pinned, synthetic, no device):** [PR111](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/111) has exact-head Actions [42513500968](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42513500968) SUCCESS. Confirms per-candidate quantities/listed differences through PR110 → PR106 → PR105 → PR109 and checks live-unsafe hop gates through actual PR107 Lua state samples → PR108 Python recommendations. These are *tested offline interfaces*, not proof of available trade/identity/server completion.



- Lua ports + parity tests for Python prototypes PR106, PR108, PR109 and PR110, ideally with a cross-module deterministic simulator and seeded adversarial replay.
- A bounded integration contract that asserts Stage58 unverified IDs **cannot** flow through the planner/snapshot guard as independently exact by self-declared booleans.
- Local simulation of request timeouts, late callbacks, bot-result changes, hop-candidate exhaustion, failed join retry/deduplication and simultaneous GUI state changes.
- Property tests of compounding under conservation of item quantities, inventory concentration and trade-slot limits; do not treat simulation as real trades.
- Recheck actual external market source freshness and existing updater CI; keep price research and settlement authority separate.
- CI compatibility checks between independently drafted branches before any merge; do not blindly stack or transplant old staged branches.

## Manual dependencies, PAUSED until user has the device or asks

- **ALT iPhone only:** recover the previously missing sender receipt with Stage59 ALT_RECOVER_LAST pinned to the current exact Stage59 head. This action requires the actual iPhone and is explicitly paused.
- **MAIN iPad later:** native UI button, trade window identity, offer rebalancing and live world-readiness tests for eventual integration. Do not unnecessarily rerun proven marker storage tests.
- **Both clients later:** narrow voluntary manual client-corroboration tests, only after report transport/recovery works, no high-value items. These do NOT automatically authorize final Accept.

**Development rule:** After each offline test result, continue debugging and preparing the next independent module in the active working turn; only ask user about a genuinely blocking manual action or significant unresolved choice. Keep all current live trading and Accept disabled.
