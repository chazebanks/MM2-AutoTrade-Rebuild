# System 1 — complete trading-engine integration and adversarial test matrix
**Created:** 2026-11-12 ET. **Workstream:** existing consolidated draft PR #241. **Do not open a separate micro-stage PR for each row.**

## Fixed evidence and status

The user's first real MAIN iPad/Delta automatic four-round receipt has **four successful client-only rounds**, four request attempts, three client-visible MAIN offers, three removal attempts, four decline attempts, and four observed closures. Exact sanitized run nonce `d1e4d5f7-758e-4ec9-b6a2-99f0c9a684d7`, [PR241 native checkpoint](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/241#issuecomment-6815237869). Do **not** repeat that test simply to obtain the same happy-path proof. This is not authenticated item settlement, accepted economic trades, verified market value, or autonomous Gingerscope acquisition.

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
| A05 | Multiple legitimate ALT add/remove changes during waiting and negotiation | Observer should track revision history, safely replan or re-arm once rather than freeze, **without accepting automatically** | **NOT IMPLEMENTED** — not a reason to claim system done |
| A06 | MAIN one- and two-slot guarded offer placement, one-at-a-time withdrawal | Reconcile exact slot state after each action; original guard and live four-round pass | **LIVE CLIENT PASS for scripted cases** |
| A07 | ALT distinct two-slot offers; one removal, then second removal | Continue exact 2→1→0, preserve surviving slot identity and quantity | **LIVE CLIENT PASS** |
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

### Efficient testing strategy, avoiding redundant manual work

**Batch all harmless, recoverable scenarios into one longer native session** once the required generalized controller supports them. Reuse the same cheap weapons, and vary ALT behavior according to live instructions. Do not send manual MAIN actions.

**A genuine hard-stop is terminal for that test run.** You cannot verify multiple real terminal faults in *one continuously running* script without violating the very stop-on-first-error requirement. Dozens of failure cases should therefore run **automatically offline** in CI first. For live validation, choose just a few representative safe faults in separate fresh test runs; each run supplies **one exact clipboard report**, then inspect it before further testing.

**Never use final trade Accept as an intentional live fault injection.** Test acceptance-indicator spoofing only in offline mocks. Do not consume valuable items, escalate authority or provoke server bans to increase test coverage.

### Immediate next engineering change in consolidated PR #241

- Add genuine **native original-source** negative cases B01/B03/B04/B05/B14 and positive A02/A03 where the existing deterministic scripted four rounds support it.
- Preserve current real tested SHA `5607c9655dda960aee5eb8226881a1bbb106eae5` as the known-good in-game happy path. Subsequent CI edits do **not** retroactively mean the altered build passed on iPad. New device loader only after exact head all-green.
- Next design iteration should generalize the 4-round fixed diagnostic into **scenario-driven, fully automatic MAIN** testing and normal-partner-revision handling, without weakening irreversibility of observed ABA or prematurely authorizing automatic final Accept.

**Boundary:** This is System 1 only. The market/strategy and settlement/learning systems follow after supervised trading mechanics meet their own acceptance checklist.
