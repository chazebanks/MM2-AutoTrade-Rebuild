# System 1 — ARM8 supervised eight separate client-trade scenario test

**Workstream:** existing open draft PR #241. **Mode:** one operator ARM, then eight independent P3 request epochs / client trade windows, each devoted to **one feature**; MAIN automatically clears its own offers and Declines as appropriate before advancing. ALT manually accepts only incoming trade **REQUESTS** and follows the displayed purple-panel instructions. **No final Accept is implemented.**

## Current evidence / limitations

- The prior first real iPad ARM5 live pass (5/5 client windows, no settlement) is immutable and does not prove this new eight-trade mode.
- New ARM8 code is in the same guarded native `pdiddler/system1/SYSTEM1_MAIN_AUTO_FOUR_TRADES_NATIVE.lua` loader. The file's historical name is unchanged; **select ARM8, not ARM4/5**. It exact-loads pinned protected original P3/P4, four-physical-slot planner, shadow lease and its own reviewed controller Git blob. It still uses **mocked P3 transport in CI**, so native CI success is **not real iPad/network proof**.
- Tested native CI scenario sequence includes eight fresh request epochs, ten guarded physical placements and ten one-at-a-time own removals, seven guarded MAIN declines and one expected ALT decline. The actual iPad eight-trade run remains **OPEN** until operator provides original diagnostic JSON.
- **This is an exact consenting ALT test**, not real multi-player scanning or autonomous economic negotiation. No verified server settlement, true item instance identities, current market prices, profit, learning labels, Discord profit or final Accept authority.

## MAIN and ALT preflight (do not ARM if missing)

1. Both accounts join **original MM2**, Roblox PlaceId `142823291`, in one **fresh** same Roblox JobId; MAIN runs the loader on iPad/Delta, consenting ALT is `venossgaming90190`. No competing pdiddler script, overlapping Delta panel or automation. Never restart ARM8 in the same server after STOP.
2. MAIN must own at least **FOUR distinct**, eligible Godly/Ancient/Chroma weapon raw types that can be offered, all genuinely cheap and unprotected. Select **exactly four** from the purple owned picker. The script will not start before manual ARM8 or without all four selections. **Gingerscope is never an outgoing choice**.
3. ALT must own **one inexpensive weapon in a genuine quantity of at least two** for the stacked-slot `x2` case; **one inexpensive Chroma weapon** for the variant case; **two distinct cheap items simultaneously** for trade 4; and **three distinct cheap items** A/B/C for trade 8. If the ALT cannot make these offers, **do not start**: the test cannot validly pass without them.
4. MAIN offers/removals/declines are **automatic after ARM8**. Do not click MAIN's trade controls or final Accept on either account. ALT may use **Decline** only when explicitly instructed in **trade 7**. Watch the MAIN purple panel to know which ALT action to perform. Do not send unrelated offers or let a third party interfere.

## One scenario per new trade window (after each, MAIN automatically cleans up and closes)

| Trade | Phase tested | Manual ALT actions | Automatically expected MAIN behavior |
|---|---|---|---|
| **1** | `STACK_QTY2` | Accept request. On `ALT_ADD`, offer ONE cheap physical item slot with **quantity x2**; on `ALT_REMOVE_ALL`, clear the slot | Verify stack x2 as **one** physical slot, guarded Decline, closure recorded |
| **2** | `CHROMA_VARIANT` | Accept new request. Offer ONE cheap **Chroma** item, **quantity x1**; clear when asked | Verify Chroma variant flag independently from ordinary display name/quantity, guarded Decline |
| **3** | `DELAYED_ALT_RESPONSE` | Accept new request. Once `ALT_ADD` appears, **wait at least six seconds**, then add ONE cheap item; clear when asked | No duplicate outgoing/false early timeout; rejects offer if it arrives before **5 seconds** from ALT_ADD |
| **4** | `ALT_SLOT_COMPACTION` | Accept new request. MAIN places TWO approved items. Offer TWO **different** cheap weapons; when told, **remove one of those two**, leaving its existing survivor unchanged, then remove the survivor | Verify ALT 2→1→0 unique visible survivor (allow GUI slot renumbering), MAIN removes its two items one-by-one and Declines |
| **5** | `MAIN_SLOT_COMPACTION` | Accept new request. MAIN places TWO approved weapons. Offer ONE cheap item, then remove it on prompt | MAIN removes both offered items one at a time; verify survivors across possible own-side GUI renumbering; Decline |
| **6** | `FOUR_MAIN_PHYSICAL_SLOTS` | Accept new request. MAIN places FOUR distinct approved weapons. Offer ONE cheap item; then remove it when told | Reconcile FOUR physical own slots and guarded sequential withdrawals; Decline |
| **7** | `NORMAL_ALT_CANCEL` | Accept new request. Wait until the purple panel shows `WAIT_ALT_CANCEL`; **press Decline** on ALT (not final Accept) | Observe client window closure, record `EXPECTED_PARTNER_CLIENT_CLOSURE_UNATTRIBUTED`, close exact P3 epoch and send a **new eighth request** |
| **8** | `TWO_ALT_REVISIONS` | Accept new request. MAIN offers cheap approved #1. Add cheap A. At `ALT_REVISE`, replace A with different B. At `ALT_REVISE_SECOND`, replace B with different C. **Leave C completely unchanged** while MAIN withdraws #1. At `ALT_CLEAR_FOR_REOFFER`, remove C. MAIN offers approved #2. At `ALT_READD`, add one cheap item. At `ALT_REMOVE_ALL`, remove it | Verify **two stable revisions** and no reuse of stale proposal; withdraw #1, reoffer **different** #2 only with both sides empty, withdraw #2 after ALT clears, automatically Decline |

Each trade has its **own** protected P3 request epoch and own visible client trade root. The test uses the **same consenting ALT**, so it proves repeated independent sessions with a partner, *not* true rotation among several different players.

## Expected final sanitized JSON

```json
{
  "schema": "gingerscope-system1-main-auto-native-v1",
  "status": "CLIENT_TEST_SEQUENCE_COMPLETE",
  "reason": "ALL_EIGHT_CLIENT_SCENARIOS_VERIFIED",
  "phase": "DONE",
  "completedRounds": 8,
  "maxRounds": 8,
  "eightTradeBatchAuthorized": true,
  "actions": {
    "requestsStarted": 8,
    "offersAttempted": 10,
    "offersClientVisible": 10,
    "removalsAttempted": 10,
    "declinesAttempted": 7,
    "clientClosedWindows": 8,
    "stackedAltSlotsVerified": 1,
    "chromaAltSlotsVerified": 1,
    "delayedAltOffersVerified": 1,
    "partnerCancelWindows": 1,
    "altRevisionsObserved": 2,
    "adaptiveReoffersAttempted": 1
  },
  "authorizesAccept": false,
  "serverCompletionProven": false,
  "verifiedCompletedTrades": 0,
  "tradeOutcome": "UNKNOWN"
}
```

This is an illustrative subset of the **client-only** report. `rounds` contains **eight ordered independent entries** with `round`, `scenarioId`, `phaseAtEnd`, `closedBy`, `clientWindowClosed`, `reason`, `status`. `ownRemovalSlotReindexesObserved` and `altRemovalSlotReindexesObserved` may legitimately be zero or positive depending on what the client GUI does; **do not force them to equal a fixed number**. `requestEpochAttempts=8` is also expected. No economic transfer should occur.

## First error, STOP/COPY, and physical evidence

- Any unexpected invalid item type/quantity, wrong ALT, accepted indicator, stale P3/P4 root, extra slot, failed own removal, uncertain Decline, watchdog loss, GUI overlap, or arbitrary ALT mutation **stops the entire eight-trade batch** immediately. Previously completed per-trade ledger entries are preserved. **Do not continue to trade N+1 after a true first fault.**
- STOP report must include `round`, `scenarioId`, `firstFailureScenario`, `phase`, `reason`, `lastAction`, attempted action counts and `possibleSideEffect`. Native launcher attempts to copy it automatically, stores a fallback string at `getgenv().PDIDDLER_SYSTEM1_MAIN_AUTO_LAST_JSON` and prints it in the Delta console if clipboard is missing.
- **Do not rearm/restart in the same JobId** after any STOP. If a trade GUI remains open, a human may manually Decline **after** the automation has stopped and only when sure of the current correct partner; that manual close is not part of the automated result.
- Copy the **entire exact JSON** result back into the conversation. Do **not** claim the script has settled eight trades, created confirmed profit or learned price/liquidity from these client-only declines.
- Fatal-fault injection is a separate test program: most B01–B17 cases belong in automated original-source CI, and a real hard STOP must not be silently skipped inside ARM8.

## What remains outside ARM8

Real multi-player whitelist/blacklist/scan/rotation, new joins, incoming priority, trade attractiveness, real-time licensed market valuation, autonomous pricing risk budgets, verified server settlement, final Accept deployment, Discord profit, and reliable learning. Those require their own separate gates. **ARM8 is a substantial supervised System1 mechanics test, not an unattended live trading release.**
