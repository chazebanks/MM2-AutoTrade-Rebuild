# System 1 — Automatic MAIN four-trade ALT test / fail-stop runbook

**Current live-test candidate:** `pdiddler/system1/SYSTEM1_MAIN_AUTO_FOUR_TRADES_NATIVE.lua` on consolidated **DRAFT PR #241**, not merged. THIS is the new MAIN-automatic runner. The older `SYSTEM1_MULTITRADE_GUIDED_NATIVE.lua` is the **MANUAL** read-only diagnostic and is NOT the correct loader for this test.

## Intended automatic behavior and user responsibilities

One operator action upfront: on MAIN, select **two distinct inexpensive, expendable owned eligible weapons** and tap **ARM 4 TRADES**. The list comes from current MM2-owned profile + game metadata; it intentionally excludes protected Gingerscope. The script does **not** know trustworthy current market value or how financially costly a weapon is, so the operator must choose two cheap test items. The items must occupy separate physical GUI slots; a stack of two copies of one weapon is **one slot** and cannot substitute for two distinct items.

After that single ARM, **MAIN automatically** does all of the following, without further MAIN clicks:
- Launches up to **four fresh, separately armed, exactly ALT-only P3 request epochs**. Each new P3 request uses a source-diff-verified clone of the existing default-closed P3 sender with **one possible send attempt**, never three retries after a pending-proof failure. It does not recycle a processed partner event from an earlier epoch.
- Verifies its P3/P4 original protected client trade window and exact ALT, including accepted flags, original root and 0–4 physical offer slots. Waits for two stable protected client reads per ALT action.
- **Round 1:** on ALT accepting the incoming REQUEST, MAIN automatically Declines the empty trade.
- **Round 2:** waits for ALT to ADD one test item then REMOVE it; MAIN automatically Declines.
- **Round 3:** MAIN automatically adds the first preapproved test weapon using the original guarded `OfferItem`, ALT adds one/then removes; MAIN automatically withdraws its own offered item via the original protected GUI ActionButton and Declines.
- **Round 4:** MAIN automatically adds the two preapproved **distinct** weapons with the reviewed PR240 pre-send ABA guard and continuously active client shadow witness. ALT adds two distinct cheap items, removes one, removes the second. MAIN automatically withdraws its own two weapons **one at a time**, verifies each GUI change, and Declines.
- After each confirmed close, MAIN stops the previous P3 supervisor/watchdog and creates a new separately gated session before requesting again. **No auto final Accept**, no completed-item transfer, no market prices, no settlement/profit/learning/webhooks/server hops.

ALT is still **manual**: it must ACCEPT each **incoming trade request only** and ADD/REMOVE cheap test weapons as instructed by the purple panel on MAIN's screen. Do **not** press the trade's **final Accept** on either account; don't change ALT's item before the panel asks. Avoid real value transfer.

## Preflight

1. MAIN iPad/Delta and consenting ALT `venossgaming90190` join **the original MM2** in the **same fresh server**, no legacy pdiddler GUI/trader/controller owner.
2. MAIN must own two distinct eligible cheap weapons (Godly / Ancient / recognized Chroma) with current game-key metadata; ALT must have two distinct expendable weapons, so Round 4 has two physical slots. **No Gingerscope or valuables.**
3. Run only the **SHA-pinned automatic loader** disclosed in the final verified PR241 checkpoint, on **MAIN only**. Do not use or mix the prior manual-only PR241 loader or PR237/239 iPad loaders.
4. Purple GUI first reads MAIN's current owned inventory. Tap two distinct list choices, then **ARM 4 TRADES** once. That one physical button authorizes exactly four requests to the exact ALT, 3 total selected outgoing item placements, up to three MAIN item-withdrawal clicks, and four automatic Declines. The ARM is not an authorization to final Accept or make any economic/portfolio decisions.
5. From here MAIN is hands-off. Watch the on-screen `SYSTEM 1 MAIN AUTO | TRADE n/4`, status, client evidence and required ALT action. Perform only the ALT interactions below.

## Four sequential rounds — what to do on ALT

### Round 1 — request/empty/automatic close

ALT sees a NEW trade request from MAIN. **ALT taps Accept on the incoming request popup**. Do not add an item. MAIN verifies two stable empty protected GUI observations, automatically Declines and starts a fresh P3 epoch for Round 2. Do not manually request again on ALT.

### Round 2 — one-sided ALT add/remove

ALT accepts the second newly received request. MAIN panel says **ALT: add ONE cheap weapon**. ALT adds one cheap eligible weapon. When panel advances to **ALT: REMOVE ALL offered weapons**, ALT removes the same item. MAIN detects the unchanged original protected item slots, automatically Declines and starts Round 3.

### Round 3 — MAIN automatic one-item placement, ALT changes, automatic MAIN withdrawal

ALT accepts the third newly received request. MAIN automatically offers the **first preapproved MAIN weapon** (do not touch MAIN). Wait for the purple panel `ALT_ADD`; ALT adds one cheap weapon. Panel advances to `ALT_REMOVE_ALL`; ALT removes its weapon. MAIN withdraws its own item, verifies the empty GUI, automatically Declines and starts Round 4.

### Round 4 — MAIN automatic two-slot placement and both-side removal

ALT accepts the fourth request. MAIN automatically offers the **two different preapproved MAIN weapons**, guarded by a live client-observed shadow ABA lease across the item-2 send. Wait for `ALT_ADD`; ALT adds **two distinct cheap weapons** in **two physical slots**. After `ALT_REMOVE_ONE`, remove one ALT item, leaving one; after `ALT_REMOVE_ALL`, remove the remaining ALT item. MAIN automatically withdraws its two own items one by one, automatically Declines, and automatically copies the **single four-round JSON report**.

**No separate NEXT ROUND button:** the runner creates the next P3 session/request automatically. MAIN's STOP and COPY buttons are available throughout.

## Stop-and-clipboard policy (first unexpected failure)

**On the FIRST unexpected behavior**, including request timeout, unbound original P3 event, wrong ALT, two visible trade roots, ALT leaves/replaced, a changed original job, unexpected offer revision/quantity, malformed protected GUI, competing script/owner, stale ABA witness before item-2 send, no protected ownership, offer IO ambiguity, nonconfirmed MAIN withdrawal or decline, failed P3 epoch teardown, GUI collision or watchdog heartbeat lost:
- The pure controller enters terminal `STOPPED`. It does **not** retry, skip that round, offer the next item, make a second P3 request or proceed to another server.
- The native runner stops current P3/watchdog and removes the guarded offer callback. **It does not attempt blind cleanup actions after an unsafe root.** If MM2 trade GUI remains open, manually tap Decline; never final Accept.
- Immediately calls `setclipboard` (or `toclipboard` when available) with a sanitized error report. Also stores exact JSON in `getgenv().PDIDDLER_SYSTEM1_MAIN_AUTO_LAST_JSON` and prints `[SYSTEM1 MAIN AUTO JSON]` to Delta console in case clipboard API is unavailable/denied.
- Report includes `round`, `phase`, static `reason`, `lastAction`, counts of attempted request/OfferItem/removal/decline, `possibleSideEffect`, completed rounds and one `runNonce`. It **never** includes player username/id, item raw keys, inventory or private market data.
- **STOP is terminal for that MM2 JobId.** Do not relaunch the same script in that server or manually clear its spent-state flags. Send the copied JSON so the exact first failure can be fixed before retesting.
- On voluntary STOP, reason is `OPERATOR_STOPPED` (distinguished from an unintentional fault). On complete success, status `CLIENT_TEST_SEQUENCE_COMPLETE`, four completed client windows and copy triggered automatically.

**TIMEOUT behavior:** 30s for each newly requested ALT window; 90s per manual ALT add/remove phase; 12s for each MAIN action confirmation, in addition to internally bounded original P4 UI checks. An ALT taking too long is reported as a timeout and is not misrepresented as a code bug.

## Expected successful sanitized JSON (counts)

| Field | Expected |
|---|---|
| `schema` | `gingerscope-system1-main-auto-native-v1` |
| `status` | `CLIENT_TEST_SEQUENCE_COMPLETE` |
| `phase` | `DONE` |
| `completedRounds` | `4` |
| `actions.requestsStarted` | `4` (**attempts**, not authenticated server delivery) |
| `actions.offersAttempted` | `3` (one in Round 3, two in Round 4) |
| `actions.offersClientVisible` | `3` |
| `actions.removalsAttempted` | `3` |
| `actions.declinesAttempted` | `4` |
| `actions.clientClosedWindows` | `4` |
| `tradeOutcome` | `UNKNOWN` |
| `serverCompletionProven`, `authorizesAccept` | `false` |
| `verifiedCompletedTrades` | `0` |

The real-device test is necessary because **offline CI does not prove P3 sent four requests to the game servers**: the full native mock supplies mock P3 transport while it executes original guarded P4 IO/bridge and exact frozen PR240 ABA planner. The real P3 fork is independently source-tested against its actual full 1,800-line Lua implementation and original processed history; its repeated real-device integration still needs this first ALT run. Do not label System1 DONE from a mock alone.

## Test evidence and source lineage

- `pdiddler/system1/system1_main_auto_failstop_controller.lua`: pure same-job four-round engine, exact sanitized error stop.
- `pdiddler/system1/pdiddler3_outgoing_single_send_epoch.lua`: original default-closed P3 sender with **one** attempt rather than three; source diff checks guarantee no other executable changes. Multiple fresh epochs, do not clear original processed user state manually.
- `pdiddler/system1/SYSTEM1_MAIN_AUTO_FOUR_TRADES_NATIVE.lua`: GUI + original protected P3/P4/TradeIO adapter, two real owned-choice selection, automatic MAIN actions and clipboard.
- `pdiddler/ci/system1_main_auto_failstop_mocks.luau`: 138 pure state machine assertions and terminal error/copy scenarios.
- `pdiddler/ci/system1_p3_single_send_epoch_mocks.luau`: ACTUAL P3 source start barrier, anti-replay, new epoch tests.
- `pdiddler/ci/system1_main_auto_native_original_mocks.luau`: full GUI/owned picker/4-round automatic MAIN native exercised with original protected TradeIO, original P3/P4 bridge, **exact byte-for-byte frozen PR240 multi-slot ABA plan and PR238 pure shadow**; mock P3 request transport only.
- `pdiddler/ci/check_system1_main_auto_integration.py`: original Git blob identity, precise new P3 diff, disabled final Accept, explicit GUI ARM, frozen sources, clipboard integrity and approved error boundary.
- `.github/workflows/gingerscope-system1-multitrade.yml`: Lune + Python exact-HEAD continuous integration.

**Project scope:** This is supervised automated test execution toward System 1, not automatic Gingerscope target trading. Live final Accept remains unapproved/disabled; the research/market inputs, confirmed completed trade settlement and learning gates are separate.
