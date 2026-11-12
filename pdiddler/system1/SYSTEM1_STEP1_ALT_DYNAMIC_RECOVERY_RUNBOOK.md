# System 1 — Step 1 of 2: automated ALT dynamic recovery (ARM 3)
Date: 2026-11-12. **DRAFT PR #246**, separate from original PR #241. Step 2 multi-player P3/P4 will be a separately reviewed script **only after** this actual iPad test passes; both tests must pass before merge/integrated one-server test.

## Already proven; do not repeat
- Known-good P1 bot detection, P2 startup, original ARM8 8/8 iPad ALT client-only result **untouched**.
- The **three novel** Step1 scenarios plus two adversarial STOP cases passed Lune native mocks of the original protected P4 IO, original P3/P4 bridge, original ABA shadow and original GUI with separate P3 transport mock. All PR CI checks green at the first head; no claim of physical iPad pass until operator provides a true native JSON receipt.
- No production code, existing user inventory, market-source values, final Accept, Discord, System2, or P5 hop changed.

## Preflight
1. On MAIN iPad/Delta, join the **original** MM2 game place `142823291` with trusted consenting ALT `venossgaming90190` already present. Start in a fresh server after old test owner flags have cleared; **run only this Step1 test**, no prior ARM8, overlay bot avoider or duplicate trader.
2. MAIN must have at least **TWO distinct low-value expendable** Godly/Ancient/eligible weapon types; no protected Gingerscope. Selecting types authorizes client-test placement only, **not exchange**. ALT should have two cheap different items A/B and **two copies of one cheap item** for scenario 2 stack x1→x2.
3. MAIN executes the one-line immutable reviewed loader **after GitHub CI is PASS at the final head**. Purple GUI should present Step1 recovery, two-item picker, STOP / COPY and **ARM 3**. If source load fails, do not bypass or run the old ARM8 script; copy static error.
4. MAIN selects exactly TWO distinct cheap own items; then taps **ARM 3 once**. From here MAIN automatically sends its own guarded P3 outgoing requests, places/revokes preapproved items, and safely declines. ALT manually accepts incoming **REQUESTS** and follows MAIN's visible instruction; MAIN does not manually initiate trade.

## Per-window steps — one feature per separate fresh ALT trade request
- **Round 1: A→B replacement.** After accepting incoming request, ALT waits for MAIN to place first own item. When screen says `ALT_ADD`, offer ONE cheap item **A x1**. When prompt changes to `ALT_REVISE`, **remove A and offer a DIFFERENT named B x1**. Leave B unchanged until MAIN withdraws. When prompted, clear B; MAIN automatically reoffers its second selected item. ALT puts ONE cheap x1 item when prompted, then clears it when prompted. MAIN automatically removes own item and guarded Declines, closing first client window. Never final Accept.
- **Round 2: same A x1→x2.** Accept fresh outgoing request, wait for MAIN first item. ALT offers **A x1**, then **increase A to a stack x2 of exactly the same weapon** when prompted. Keep same weapon/chroma variant. Once MAIN withdraws, ALT clears x2, waits for MAIN second selected item, offers any one cheap x1 item, then clears it. MAIN withdraws and Declines.
- **Round 3: stable-empty recovery.** ALT accepts fresh request and offers **A x1** after MAIN first item. When prompted, remove A completely, **wait for GUI to display the NEW `ALT_REVISE_READD` instruction** (do not immediately replace). Then offer DIFFERENT named B x1; MAIN withdraws. ALT clears B, waits for MAIN second-item reoffer, offers any one cheap x1 item, then clears. MAIN withdraws and Declines.

**Watch for the MAIN purple text to change before each ALT action.** Do not improvise a change while MAIN physically places an item. Every step is bounded and the first unexpected change intentionally STOPS the entire remaining batch. The overlay panel must not cover MM2 controls. If trade remains open after STOP, **manually Decline on both accounts** and do not run another script in the same job.

## Expected final JSON, paste only sanitized COPY output
- `status=CLIENT_TEST_SEQUENCE_COMPLETE`, `reason=ALL_THREE_RECOVERY_CLIENT_SCENARIOS_VERIFIED`, `completedRounds=3`, `maxRounds=3`
- `recoveryBatchAuthorized=true`, `eightTradeBatchAuthorized=false`, `actions.requestsStarted=3`, `actions.offersClientVisible=6`, `actions.removalsAttempted=6`, `actions.declinesAttempted=3`, `actions.clientClosedWindows=3`, `actions.altRevisionsObserved=3`, `actions.adaptiveReoffersAttempted=3`.
- The per-round scenario IDs must be `ALT_REPLACES_ITEM`, `ALT_STACK_X1_TO_X2`, `ALT_CLEAR_THEN_NEW`, each with client window closed. **All `authorizesAccept=false`, `finalAcceptEverAttempted=false`, `serverCompletionProven=false`, `verifiedCompletedTrades=0`, `tradeOutcome=UNKNOWN`**.
- On any `STOPPED`, submit the exact first-fault `reason`, `round`, `actions` and per-round ledger using **COPY**. Do not rerun until diagnosed. A failing or incomplete session is NOT a 3/3 pass.
- Completed trades here mean **closed client test windows only**, not actual in-game settled weapon exchanges.

## Constraints and sequencing
- **Step 1 only**. No public players, server hopping, Discord messages, real item transfers or automatic final Accept.
- **Step 2** will be a separately authored and tested multi-player P3/P4 handoff script (P3 owns contacts; P4 owns trade window), issued after confirmed actual Step1 ALT result.
- After both independent scripts pass actual iPad tests, merge integration changes and run the combined System1 workflow in one server. Leave the original ARM8 known-good source, P1 bot detector and P2 startup unchanged.
- No live public unattended operation or economic authority is implied by Step1 alone; user controls explicit ARM and STOP.
