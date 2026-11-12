# System 1: consolidated multi-trade verification campaign
**Research/testing status:** draft PR #241, 2026-11-12. **Not a claim of full System 1 completion, server settlement or final Accept authority.**

## Scope: one operator-armed sequence per safe normal-variation batch
- Existing exact-ALT **ARM8 8/8 live client proof is CLOSED**, as recorded in original [PR241 live operator receipt](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/241#issuecomment-6817606073). Do not repeat it.
- The next safe single ARM batch should target **new** real-world P3 **multi-eligible-player selection, request exhaustion/ignored cancel proof, incoming when idle, P3/P4 bound handoff/resume**, and P4 **bounded normal offer revisions**, each in distinct client windows, with per-target consent and hard side-effect budgets. The current fixed-ALT ARM8 runner **cannot execute a multi-player rotation batch**. Do **not** tell the operator to run ARM8 again or claim existing code covers multi-player live.
- Requires at least **two explicitly consenting eligible test accounts/players** present in original MM2 for a multi-player claim. Do not contact random public lobby players for a diagnostic or invent user account names. The user has identified only one ALT so far; the multi-player native runner must first be developed and source-pinned.
- **No way to test every terminal fault in one uninterrupted live session.** A true error must STOP the entire run, prevent next request, and preserve exact first-fault JSON; subsequent independent fault cases require separate clean runs. Run them as distinct mock sessions offline first. Do not intentionally trigger final Accept, spend valuable weapons, or hide GUI ambiguity to increase test count.
- P4's active MID-PLACEMENT mutation (ALT new singleton, stacked x2, Chroma, second slot) has now passed **four distinct OFFLINE original protected P4 native fail-stop cases** after five prior mock windows. They explicitly check the mutation was injected and no item2/3/4 send, no blind decline, no seventh request, no fabricated settlement. This is **not** a live client test nor normal recover/replan proof; the safe behavior is STOP.
- The existing P3 15-second ignored-request cancel-cannot-prove-clear safety fix is already present in draft source and tested with 8 boolean combinations; do not duplicate it. True live latency/late-open after timeout still needs supervised evidence.

## Coverage table
| Concern | Evidence | Still needed |
|---|---|---|
| Own offer/revoke/GUI slots 1-4; Chroma; stacked x2; ALT revision; expected cancel | ARM8 8/8 **iPad client** evidence | Generalization to multiple players; arbitrary offer changes |
| ALT during 4-slot MAIN send | 4 **native offline** cases under exact protected original modules | Separate safe physical targeted scenario only if needed |
| First fault STOP / no resend / no Accept | Native original-module regression; offline mock cases B01-B17 partial | Representative new hardware negative tests in clean runs |
| Real incoming and pending cancellation | P3 source and original timeout decision matrix | New focused multi-player P3 device batch |
| Multi-player whitelist/filter, rotation, processed ledger, leave/join | P3 code exists; fixed-ALT ARM8 DOES NOT test it | Integrated consenting multi-player hardware and source-pinned mocks |
| P4 economic replan / prices | Stage120 synthetic, Stage121 source firewall | System2 independently licensed data/identity; not System1 client mechanic authority |
| Server-side completed trade, final Accept, profit, Discord learner | **0 verified** | Independent distinct safety/release phases; not safe to include in this live test batch |
| Server-hop/bot avoider | Historical separate modules | Not integrated into tested P3 runner; never claim passed |

## Safe run protocol for future consolidated runner
1. Preflight: immutable exact SHA, original MM2 PlaceId, one active system controller, stable UI geometry, consenting whitelist of at least two player object/UserId pairs, verified empty trade and no pending request. Operator selects only cheap expendable preapproved items; no Gingerscope outbound.
2. One ARM with explicit MAX requests / MAX physical offers / MAX withdrawals / MAX guarded declines; P3 owns scanning, request/processed ledger, 15s response timeout and cancel verification. P4 owns only bound active trade and client safe close.
3. Each accepted client trade: confirm exact partner object + UserId + P3 epoch + P4 root, exercise ONE new normal variation, verify empty before/after, one-by-one protected withdrawal and expected closure, classify `CLIENT_SEQUENCE_PASS` **not** `SETTLED`, then release exact lease; only then P3 may start next eligible contact.
4. If ignored request: never rotate unless outgoing pending UI is demonstrably gone and no late trade root appears. Incoming while idle: decline only if specific visible popup and exact current request are proven; do not fake simultaneous incoming/outgoing that cannot occur.
5. In P4, a changed ALT offer while a multi-item MAIN plan is *physically in flight* invalidates the prepared shadow. If remote side effects uncertain, STOP and COPY, **no continued sends/declines/retries**. Treat ordinary revisions between remote actions as distinct separately budgeted replan opportunities only if original identity/session/source and operator consent remain valid.
6. At terminal DONE: copy one sanitized ledger with all windows and counters. At STOP: copy all earlier completed windows, exact single first failure and possibleSideEffect=true where applicable. No server-completed trades, inventory-value gain, financial profit, Discord training or final Accept claims.

## Immediate engineering gate, before next iPad ARM
- Implement and CI-test the **true multi-eligible-player consented batch** by composing existing P3 scanner/outgoing/handoff with guarded P4 client decline, without duplicating a new scanner, without using auto player-hops, and without losing original request ownership. Add offline native tests for processed/eligible/UNKNOWN, incoming, timeout cancellation, owner changes, callback interruption, late trade-open and stale root. All standard negative cases first.
- Prepare exactly one user-facing script loader with static pin after green original-source tests; do not issue an untested loader or suggest rerunning ARM8. The number of live scenario windows must be dictated by distinct unproven normal behavior, not vanity test counts.
- `system1_batch_receipt_grader.py` rejects fake server/Accept claims and counter/ledger disagreements; its 8-round schema only grades the **already closed ARM8 receipt**. Extend it with a separately reviewed schema for the new multi-player test (never silently pass different-run data).

**Current next action:** original P3 consenting-multi-target batch integration, **not** a second fixed-ALT ARM8. Preserve this precise checkpoint for next session.
