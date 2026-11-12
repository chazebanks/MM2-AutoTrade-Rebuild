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


## Nov 12 operator decision: public-server multi-player rotation

**LATEST OPERATOR DIRECTION:** Verify *actual* multi-player P3 rotation in public MM2 servers; an additional controlled ALT is NOT a prerequisite for that narrow observation. The earlier text demanding two personally controlled ALT accounts for public rotation is **superseded** by this section. Controlled same-ALT P4 ARM8 8/8 is closed and not repeated.

### Exact distinction between normal public requests and controlled P4 trials
- Public players are eligible for a normal *bounded in-game trade request* if their stable original P3 scanner inventory is proven eligible; they can ignore or decline. Being eligible and receiving a normal game UI request **does not establish consent to a diagnostic item transfer**, nor prove item/partner/server settlement. Avoid automated chat spam, pressure, multiple requests to one player, or public disclosure of usernames.
- This pilot can measure **P3-only**: scanner recognizes two or more distinct Godly/Ancient/Chroma players, whitelist versus UNKNOWN/blacklist, **one request max per distinct UserId**, 15-second no-answer classification with actual confirmed pending GUI cancellation, normal decline, late accept/root uncertainty STOP, and fresh Player object identity / P3→P4 handoff if a request gets accepted. For accepted windows, **offer zero items**, do NOT press final Accept; if the bound trade has both sides empty, the operator can safely decline under a separately verified supervised handoff and advance to next player. Don't treat a public player's refusal as a test failure of trade economics.
- Max **3 distinct eligible targets** per single explicitly armed pilot; no retries of processed contacts, no server hops, no unbounded restarts, no automatic final Accept, no item placement/withdrawal or economic strategies, no Discord success/profit messages. No automatic invite targeting based on account/user data outside the game's own visible/public inventory. For a stop, preserve prior processed results and refuse next target; a fatal fault must not be skipped to claim a full batch.
- **Preflight requirement:** first test isolated original P3 source with a frozen 3-player gate and a source-pinned public-lobby runner; never strip P3's strict cancel-pending proof or P3/P4 exact bound session and watchdog. The original fixed-ALT `SYSTEM1_MAIN_AUTO_FOUR_TRADES_NATIVE.lua` hardcodes one ALT and **must not be run as a public-rotation pilot**.
- New `pdiddler/system1/system1_public_lobby_target_gate.lua` is a PURE *frozen-candidate filter*, validated via original-source Lune CI: operator arm gate, stable Player-instance object & matching UserId, scanner state whitelist, deterministic up-to-three eligible targets, revocation/leave/replacement fail-closed semantics. It **does not send any trade requests or invoke live P3/P4**. It must be hooked up to a separately testable public-lobby runner and original P3 only after offline integration proofs; do not present it as ready to run on an iPad. No specific public account names are hardcoded or reported.
- **Expected public outcomes, not economic claims:** unique visited eligible targets; distinct attempted request count; per-target client statuses `declined`, `ignored-with-pending-cancel-verified`, `trade-open-bound-client-only`, `left`, `unavailable`, `blocked-unsafe`, and exact first failure. Counts must never imply a completed in-game trade or independently verified inventory movement.

### Test acceptance for PUBLIC request-only pilot
1. Two or three **different** eligible, stable, current Player objects within one public server, max one outbound request attempt per UserId. No UNKNOWN/blacklist or repeated target. If fewer than two verified candidates, don't arm and don't fabricate a pass.
2. In original P3 source, if ignored after 15 seconds, prove pending GUI was successfully canceled and **no late client trade opened** before moving to another player. An uncertain send/cancel is a STOP, not "ignored".
3. If player declines, only classify via supported client evidence; if accepted, P3 pauses at the exact current client root and prevents any new request until the supervised trade is safely closed/released. No offers and no final Accept.
4. If player leaves, fresh eligibility changes, GUI conflicts, unexpected incoming request, late trade open, or Player object substitution, fail closed instead of contacting the next target blindly.
5. At DONE, one sanitized ledger and compare actual distinct attempted player count against original P3 counters. This proves only client request rotation; no trade settlement, bot detection, full unattended hop reliability, or autonomous strategy.

**Next engineering step:** original P3 **public-lobby request-only runner integration** and negative CI using the new candidate gate. This is not yet done by adding the pure gate. Preserve PR #241 DRAFT and request no hardware run until reviewed CI has tested the runner against actual original P3 source.


## LATEST operator-priority correction — automated ALT settlement before public integration

**Supersedes the earlier public-lobby 'immediate next engineering step' wording in this same document.** Full architecture and test policies are in [SYSTEM1_OWNERSHIP_AUTONOMY_AND_ALT_SETTLEMENT_DECISION_2026_11_12.md](SYSTEM1_OWNERSHIP_AUTONOMY_AND_ALT_SETTLEMENT_DECISION_2026_11_12.md).

The operator directs that the system's **end goal is fully autonomous operation**. One operator ARM should authorize bounded automatic testing of mechanics. Current `authorizesAccept=false` means *this already-tested version has intentionally not implemented safe automatic final confirmation*; it is **not a permanent ban on developing/testing final Accept**. First establish real completed-trade observation on a consenting ALT with inexpensive inventory and persistent post-rejoin dual-account deltas, then separately authorize/test a bounded **automatic final-accept ALT pilot** after offline fault coverage. Public-server player-rotation pilot is postponed until the Parts and settlement workflow have been reviewed; no second ALT is required to test eventual P3 player rotation. Actual hop execution is not present in the current Part1 classifier nor verified in reviewed P3 sender. Keep separate subsystem ownership and avoid forcing P4 to own P3 contact/hop.

**State:** architectural/test-order correction, not a live trading-script update; do not ask the operator to execute the old fixed-ALT ARM8 to verify completed trades. No public test loader or automatic final Accept produced.
