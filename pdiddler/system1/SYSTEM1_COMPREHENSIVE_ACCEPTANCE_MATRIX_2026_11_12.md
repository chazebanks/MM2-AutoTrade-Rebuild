# System 1 — complete trading-engine integration and adversarial test matrix
**Created:** 2026-11-12 ET. **Workstream:** existing consolidated draft PR #241. **Do not open a separate micro-stage PR for each row.**

## Fixed evidence and status

The first real MAIN iPad/Delta automatic four-round receipt passed **4/4 client-only rounds** (nonce `d1e4d5f7-758e-4ec9-b6a2-99f0c9a684d7`), preserved in [PR241's 4-round checkpoint](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/241#issuecomment-6815237869). The subsequent first ARM5 attempt STOPPED in round 4 (nonce `6524a469-10a7-474c-9b9a-ec86e70589cf`), exposing possible physical GUI-slot compaction; its failure remains preserved. The corrected SHA-pinned ARM5 re-test then passed **5/5 actual MAIN iPad client rounds** (nonce `a9394c5d-a14a-43ea-8bcb-412bbf11a7d4`), with 5 requests, 5 visible offers, 5 removal attempts, 5 declines, 5 closures, 1 ALT revision, 1 adaptive MAIN reoffer, and 1 observed client slot reindex. Exact head `8007f24dab11ad741591fcdeb5206d72d8a6142c`; [new native checkpoint](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/241#issuecomment-6816378923). All three receipts are **client-only**; zero authenticated settlement, item identity, market price, learning labels, final Accept or autonomous release. Do **not** repeat either 4/4 or 5/5 happy path for its own sake.


### Nov 12 new ARM5 physical acceptance checkpoint

- The corrected script under exact SHA `8007f24dab11ad741591fcdeb5206d72d8a6142c` produced operator-pasted `status=CLIENT_TEST_SEQUENCE_COMPLETE`, `reason=ALL_FIVE_CLIENT_ROUNDS_VERIFIED`, `completedRounds=5`, with 5/5 client-closed trade windows. See [durable PR comment](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/241#issuecomment-6816378923) for counters, original run nonce and the 12/12 offline JSON internal-consistency checks. That is not independent game-server proof.
- In the same client run, `altRemovalSlotReindexesObserved=1`, `altRevisionsObserved=1`, `adaptiveReoffersAttempted=1`. This closes the *narrow* supervised ARM5 happy-path acceptance item and reproduces the corrected GUI compaction behavior in vivo. It does not verify arbitrary ALT revision patterns, live risk budgets, a verified economic strategy, settlement, or autonomous Accept.
- **Do not run another identical ARM4/ARM5 happy-path test.** Next consolidated System1 issue: generalized bounded partner revision / valid decline-cancel handling with fixed consent budgets and strong ABA invalidation, offline original-module testing first. Then add multi-player contact scanning/rotation. Keep PR #241 draft and all final Accept, price, learning, Discord profit, unattended live authority disabled.

### Architectural rule

**MAIN performs all test actions automatically after initial item selection and one explicit ARM.** ALT manually accepts incoming trade **requests** and follows the on-screen ALT test instructions. Neither account should press **final Accept** as part of any normal test. Every test action or side effect is bounded, tied to the exact consented ALT and current P3/P4 session, and recorded in a single sanitized per-session report. If an **unexpected** event occurs, stop immediately, never automatically resume/retry, copy the exact phase/reason/last action and any possibly already attempted side effects. A planned/intentional fault still stops the engine; it is graded **EXPECTED_STOP** by the external test checklist, **not silently treated as a successful trade**. No auto-trading release authorization is implied.

**We need both kinds of evidence**:
- Normal trade variation that the future engine should **handle and continue**. These need new functional logic, not just more negative tests.
- Invalid or unsafe trade state that the engine must **stop, copy, and never send a subsequent request**.

### Track A — continue correctly under normal conditions

| ID | Scenario and intended ALT action | Automatic MAIN behavior / acceptance | Current evidence |
|---|---|---|---|
| A01 | Four consecutive fresh request/offer/remove/decline windows (already performed) | All 4 client windows close without manual MAIN action | **LIVE CLIENT PASS 2026-11-12** |
| A02 | ALT one physical slot contains a stacked item quantity x2; later removes it | Physical-slot count stays **one**, preserve quantity and Chroma variant; continue if otherwise expected | Existing parser tests; expand native variant |
| A03 | ALT offers a Chroma-variant cheap weapon | Keep item variant and quantity distinct, not just name; no fake raw-ID proof | Needs native GUI variant |
| A04 | ALT adds a weapon after a realistic delay below 90 s | Remain in WAIT_ALT phase; do not prematurely click MAIN item or decline | Deadline tests partial |
| A05 | Multiple legitimate ALT add/remove changes during waiting and negotiation | Observe revision history; safely replan/re-arm when bounded and authorized, **without final Accept** | **ONE controlled ALT A→B replacement + different MAIN reoffer LIVE CLIENT PASS (ARM5)**; generalized multiple revisions and recovery **NOT IMPLEMENTED** |
| A06 | MAIN one- and two-slot guarded offer placement, one-at-a-time withdrawal | Reconcile exact slot state after each action; original guard and live four-round pass | **LIVE CLIENT PASS for scripted cases** |
| A07 | ALT distinct two-slot offers; remove either; survivor may be renumbered by GUI | Continue 2→1→0 ONLY when exactly one earlier client-visible candidate survives (same name/Chroma/quantity/visible ID); never treat GUI index as item identity | **Corrected ARM5 LIVE CLIENT PASS**: `altRemovalSlotReindexesObserved=1`, round4 passed; unique real item/server identity still unproven |
| A08 | 3 or 4 *distinct* MAIN slots, nontrivial quantity/chroma combinations | Prove no duplicate slot clicks, fresh shadow for each addition, and withdrawal verification | **OFFLINE only for four-slot planner** |
| A09 | New consented ALT trade after previous exact-ALT session completed | Fresh P3 epoch and fresh request, no old processed-event replay | **LIVE CLIENT PASS for 4 epochs**, no general queue |
| A10 | Scan multiple players, prioritize eligible requests, decline disallowed incoming, pause/resume rotation | No duplicate requests, enforce one active transaction, fail closed on ambiguity | **NOT INTEGRATED into current fixed-ALT runner** |
| A11 | ALT declines an unattractive offer normally, or declines a proposal before MAIN sends another item | Controlled recovery or candidate rotation once agreement is not pending; no runaway retries | **NOT IMPLEMENTED**; current diagnostic correctly stops |
| A12 | Bounded response to slow/dropped UI callbacks without partner/root ambiguity | Separate expected short wait from true timeout; no false authority or repeated side effects | Limited 1.5s native handoff grace; more needed |

### Track B — first unexpected event must STOP and copy

| ID | Injected or operator-triggered fault | Expected first reported error / safety outcome | Verification |
|---|---|---|---|
| B01 | ALT closes/declines after a trade opens but before MAIN's expected close | `TRADE_CLOSED_UNEXPECTEDLY`; no following request | Offline controller covered; **live not yet proven** |
| B02 | ALT does not accept request within 30 seconds | `TIMEOUT_WAIT_OPEN`; no unbounded repeat | Pure offline; live unproven |
| B03 | ALT adds more slots than the phase authorizes | `ALT_ADDED_UNEXPECTED_EXTRA_SLOTS` and no further offer | Test native |
| B04 | Accepted indicator becomes visible unexpectedly | Reject guarded original P3/P4 snapshot; **never auto final Accept** | Baseline bridge, extend MAIN native |
| B05 | Different player, exchanged UserId/Player object, or ALT leaves | Static exact-partner or ALT-left error; never decline an uncertain partner | Native wrong player PASS; disconnection untested |
| B06 | ALT changes an offer A→B→A between guarded MAIN sends | Existing shadow becomes irreversibly stale, block next remote | **OFFLINE native PASS**; real native only happy path |
| B07 | ALT item quantity/chroma changes mid-step without authorization | Do not treat name/slot count alone as invariant | Exact P4 snapshots; expand native |
| B08 | MAIN owned item disappears or stale approval is used | `GUARDED_OFFER_FAILED_OR_UNCONFIRMED`, no subsequent send | Pure offline; native failure branch unproven |
| B09 | MAIN removeOne fails or GUI did not confirm own withdrawal | Bounded terminal error, do not click the next item blindly | Pure offline; native negative pending |
| B10 | MAIN DeclineTrade returns ambiguous or trade window does not close | Bounded terminal error, no second decline or new P3 request | Pure offline; native negative pending |
| B11 | P3/P4 bound root replaced, multiple visible trade UIs, watchdog loses heartbeat | Specific `ORIGINAL_P4_ROOT_CHANGED` / `MULTIPLE_VISIBLE_TRADE_ROOTS` / `P3_WATCHDOG_LOST` | Some native/offline cases covered |
| B12 | Concurrent stale P3 owner, old event replay, duplicate controller/loader | Block before side effects, retain spent same-job flag | Source guarded + P3 tests |
| B13 | GUI collision with Delta/native trade controls, screen resize, missing controls | Fail closed; avoid clicking concealed or mispositioned UI | Baseline manual geometry native, auto scenario pending |
| B14 | Clipboard API errors or absent on iPad | Preserve JSON in Delta log + `PDIDDLER_SYSTEM1_MAIN_AUTO_LAST_JSON`; differentiate attempted from delivered | Native source design; negative test pending |
| B15 | CTRL loop throws, P3 callback throws, time advances backwards or stalls | Static first-fault code; no ghost success; stop watchdog | Pure offline partial, broader integration needed |
| B16 | Previous round is closed but a stray duplicate request/trade reappears | No replay or renewed offer; fresh epoch must be proven before proceeding | New test needed |
| B17 | Operator presses STOP during any phase | Terminal `OPERATOR_STOPPED`, report copied; no further requests | Pure offline PASS; native integration pending |

### Track C — what completing the **whole supervised trading engine** requires

These are **features** as well as tests: designing more trap cases without implementing them would still leave System 1 unfinished.

1. **Contact/rotation:** P3 scanner, exact whitelist/blacklist, incoming prioritization, fresh target/epoch, timeout and auto hop only after independent safe cleanup; stop duplicate outgoing contact.
2. **Trade-state machine:** stable P3/P4 lease ownership, independent accepted-state/GUI checks, physical slots/stack/Chroma, armed outgoing one-to-four item plan, safe verified removes and rebalancing, dynamic ALT revisions and controlled proposal changes.
3. **Error recovery:** distinguish a normal partner decline/cancel from unsafe item state; bounded recovery for expected closing/rejection, immediate hard STOP for unsafe ambiguity, no duplicate remote after an uncertain send. Preserve operator consent boundaries.
4. **Integrated GUI/telemetry:** phases and ALT actions, current request/offer/revision status, planned vs actual side effects, explicit STOP/COPY, exact first root cause, repeatable sanitized ledger across sessions. No fake server authority.
5. **Full release-to-supervised-test evidence:** adversarial offline matrix, controlled ALT live scenarios, session closure/restart/ALT departure/GUI overlays, snapshots collected from actual iPad, review of failures, no final Accept. **No numerical risk budget or economic trading authorization** is presumed.

### ARM8 implementation — offline evidence and real-device gate (November 12)

- Built an **explicit ARM8** button into existing full MAIN native runner and authorized **four distinct cheap owned item selections**, one ARM for eight independent client windows. Historical ARM4 and ARM5 paths remain separate; no default-on, no auto final Accept. The controller's `batchNames` names, deadlines and first-error per-trade reporting are source coded and part of exact-head CI.
- Eight scenarios **implemented and exercised** with frozen-original protected P4, original P3/P4 bound bridge, reviewed four-slot planner/shadow, and mocked P3 request transport: **T1 stacked x2**, **T2 Chroma x1**, **T3 delayed ALT response ≥5 s**, **T4 ALT 2→1 GUI transition**, **T5 MAIN 2→1 GUI transition**, **T6 four sequential MAIN physical slots**, **T7 ALT cancellation then fresh P3 request**, **T8 TWO ALT revisions A→B→C and distinct MAIN reoffer**. Each successful trade records client closure then ends its protected P3 epoch before new request; unexpected error STOP/COPY preserves completed trade ledger and failed scenario.
- Real native CI found and corrected an **actual restricted adapter gate** that accepted safe ALT-present MAIN withdrawal only in ARM5 round5; ARM8 round8 now also satisfies the explicit protected precondition without broadening authority elsewhere. The original controller's MAIN `NewItem` ordinal equality was also replaced with a **uniquely matched visible-survivor** check. Both have original-source native regression, with true substitutions blocked. Existing live ARM5 pass is NOT retrospectively transferred to ARM8.
- Expected successful ARM8 client-only counts: **8 separate requests, 10 safeguarded MAIN physical offer placements, 10 removals, 7 MAIN declines, 1 ALT intentional decline, 8 closed client windows, 2 observed ALT revisions, 1 adaptive reoffer**, one stack/chroma/delay result each. Actual GUI reindex counts vary legitimately across device implementations. **0 final Accept, 0 proven settlements**, no values or learning labels.
- [ARM8 full guided device runbook](SYSTEM1_EIGHT_SEPARATE_TRADE_RUNBOOK.md). **Real MAIN iPad/Delta ARM8 remains unverified until an operator supplies the complete copied report.** Never present eight offline mock windows as eight independently authenticated MM2 server trades. Keep this PR draft, and do NOT rerun historic ARM4/ARM5 happy paths.

### Operator-approved batched scenario architecture — November 12

**One scenario per distinct trade window, many sequential windows per single ARM session** (not many unrelated tests mixed in the same trade). Following each successful scenario, MAIN automatically withdraws all test offers, guarded Declines and waits for client window closure, closes the original P3 epoch and writes that scenario's sanitized receipt **before** starting a genuinely new request/epoch. This better pinpoints the trade index and phase of a break, while approximating repeated encounters. [Exact operator-direction checkpoint](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/241#issuecomment-6816592899).

Proposed distinct scenarios, one per window: (T1) stacked ALT quantity as one physical slot, (T2) Chroma variant identification, (T3) slow but bounded ALT response, (T4) ALT-side 2→1 GUI compaction, (T5) MAIN-side 2→1 GUI compaction after one protected withdrawal, (T6) MAIN protected three/four-slot stepwise offer and removal, (T7) one trade devoted to multiple legitimate ALT offer revisions and guarded MAIN replanning, (T8) ordinary ALT decline/cancel treated as a bounded non-success and continued only if a specifically implemented recovery policy safely authorizes next contact. Each scenario is standalone; T7 intentionally performs several related mutations because **the one tested feature** is revision handling. This is a proposed *new* runner; the current ARM5 does not support it yet.

Maintain one operator-approved batch plan, explicit per-trade action budgets, one-time P3 epochs, original P4 bound leases, per-trade results `scenarioId/tradeIndex/phase/lastAction/expectedOutcome/observedOutcome/clientClosedWindow/firstError` and a single final sanitized receipt. Unexpected unsafe events STOP the **entire batch** on first fault and preserve the exact partial ledger—never skip a failing trade to inflate passing counts. Deliberate terminal faults therefore need a fresh separate device run; exercise most offline. Repeating the same consenting ALT in fresh windows **does not** prove genuine multi-player rotation: that requires a separate multi-consenting-player scanning test. Keep final Accept disabled and no settlement/profit/learning promotion.

### Efficient testing strategy, avoiding redundant manual work

**Batch all harmless, recoverable scenarios into one longer native session** once the required generalized controller supports them. Reuse the same cheap weapons, and vary ALT behavior according to live instructions. Do not send manual MAIN actions.

**A genuine hard-stop is terminal for that test run.** You cannot verify multiple real terminal faults in *one continuously running* script without violating the very stop-on-first-error requirement. Dozens of failure cases should therefore run **automatically offline** in CI first. For live validation, choose just a few representative safe faults in separate fresh test runs; each run supplies **one exact clipboard report**, then inspect it before further testing.

**Never use final trade Accept as an intentional live fault injection.** Test acceptance-indicator spoofing only in offline mocks. Do not consume valuable items, escalate authority or provoke server bans to increase test coverage.

### Immediate next engineering change in consolidated PR #241

- Add genuine **native original-source** negative cases B01/B03/B04/B05/B14 and positive A02/A03 where the existing deterministic scripted four rounds support it.
- Preserve current real tested SHA `5607c9655dda960aee5eb8226881a1bbb106eae5` as the known-good in-game happy path. Subsequent CI edits do **not** retroactively mean the altered build passed on iPad. New device loader only after exact head all-green.
- Next design iteration should generalize the 4-round fixed diagnostic into **scenario-driven, fully automatic MAIN** testing and normal-partner-revision handling, without weakening irreversibility of observed ABA or prematurely authorizing automatic final Accept.

**Boundary:** This is System 1 only. The market/strategy and settlement/learning systems follow after supervised trading mechanics meet their own acceptance checklist.
