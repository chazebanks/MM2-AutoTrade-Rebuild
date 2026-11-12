# System 1 — Optional Adaptive Fifth Trade: MAIN automatic / ALT guided

> **2026-11-12 live test correction:** User's real five-round iPad attempt STOPPED in **round 4, not round 5**, with `ALT_REPLACED_ITEM_INSTEAD_OF_REMOVING`: `completedRounds=3`, `requestsStarted=4`, `offersAttempted=3`, `removalsAttempted=1`, `declinesAttempted=3`. The report **does not identify whether the remaining ALT item truly changed** or MM2 merely compacted its slot. Prior controller incorrectly demanded the retained item have the exact prior `NewItem` GUI index. Reviewed fix now requires exactly ONE match of the previous two item candidates by visible name, Chroma, quantity and optional visible ID **ignoring index only**; ambiguity/real substitution still STOP. Adds `actions.altRemovalSlotReindexesObserved` to sanitized output. Added original protected P4 native tests for compacted slot, unchanged second slot, replaced candidate, changed quantity, changed Chroma, and indistinguishable duplicate. **No fifth-round iPad pass yet.**


**Current stage (2026-11-12):** DRAFT PR #241, **corrected ARM5 LIVE CLIENT PASS** on MAIN iPad/Delta at exact frozen source commit `8007f24dab11ad741591fcdeb5206d72d8a6142c`. Operator-pasted nonce `a9394c5d-a14a-43ea-8bcb-412bbf11a7d4` reports `ALL_FIVE_CLIENT_ROUNDS_VERIFIED`, `completedRounds=5`, 5 requests / 5 visible offers / 5 removals / 5 declines / 5 closed windows, `altRevisionsObserved=1`, `adaptiveReoffersAttempted=1` and `altRemovalSlotReindexesObserved=1`; [full sanitized checkpoint](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/241#issuecomment-6816378923). Previous first ARM5 attempt stopped in round 4 and exposed the visual slot-compaction problem; its failure has been retained. The original four-round live result at `5607c9655dda960aee5eb8226881a1bbb106eae5` remains valid. **This proves only the client-side guarded scripted scenario**; no authenticated item identity, true game-server settlement, price authority or final Accept. **Do not repeat the same 5/5 happy path.**

## Why this test exists

The original four-round sequence proved that MAIN could automatically issue four consecutive request epochs, place three preapproved own items, withdraw three items, decline four times, and close four client-side windows. It did **not** prove that MAIN could react to a **normal ALT proposal revision by changing its own offer**. This optional fifth round tests exactly that, without economic decision-making, inventory transfer, or auto final Accept.

**The two GUI choices are distinct:**
- **ARM 4:** original fixed four-round diagnostic, already observed passing on MAIN iPad. Budget: 4 requests, 3 approved offers, up to 3 withdrawals, 4 declines.
- **ARM 5:** the four baseline rounds **plus a fifth adaptive round**, not a separate program. Budget: at most 5 fresh request epochs; 5 preapproved MAIN offer-item placements; 5 own-item withdrawal attempts; 5 declines; one ALT stable replacement + one different MAIN reoffer. The fifth round has a separate explicit authorizing gate `explicitAdaptiveRevisionConsent=true`, cannot be inferred from ARM4. **No final trade Accept** in either mode.

Only choose two distinct, genuinely inexpensive, expendable eligible MAIN weapons. The script still does NOT know verified current prices or practical liquidity, so MAIN's weapon choice is manually approved at startup. The ALT should have two different cheap test weapons (say ALT-A and ALT-B), neither protected/valuable. No real item transfer is necessary.

## MAIN preflight

1. Enter a fresh ORIGINAL MM2 server with MAIN on iPad Delta and the exact consenting ALT `venossgaming90190` simultaneously present. No other pdiddler scripts, trade controllers, or overlapping Delta UI remain active.
2. Run **only the new exact-head SHA-pinned** `pdiddler/system1/SYSTEM1_MAIN_AUTO_FOUR_TRADES_NATIVE.lua` after its precise revision passes all GitHub Actions. Do not use the older `5607...` four-round loader to seek a fifth trade; it cannot perform the adaptive scenario.
3. Purple GUI offers two separate buttons after the operator chooses TWO distinct cheap MAIN weapon types: **ARM 4** and **ARM 5**. Read the action budgets before tapping **ARM 5** once.
4. **Hands off MAIN after ARM.** All requests, offers, own withdrawals, declines, new P3 epochs, bounded timeouts and stop/copy are automatic. Do not manually place/remove own items or press final Accept. If any unexpected event stops the script, **do not restart in the same Roblox JobId**.

## ALT action sequence for five-round run

Rounds **1–4** are the previously validated baseline. See `SYSTEM1_MAIN_AUTO_FOUR_TRADE_RUNBOOK.md`. For each, ALT accepts MAIN's incoming trade **REQUEST**, never final trade Accept; ALT then adds/removes cheap items only when the purple panel instructs. MAIN automatically ends each window and sends the next request.

**Round 5 — adapt to a stable changing offer:**

1. ALT accepts the **fifth** incoming MAIN trade REQUEST only. MAIN automatically offers its **first preapproved** weapon using the existing protected P3/P4 gate.
2. When the GUI reads `ALT_ADD`, ALT adds **one** cheap weapon, ALT-A. Wait for GUI `ALT_REVISE`. (No final Accept.)
3. While MAIN's first item remains in its offer, ALT **removes ALT-A and substitutes a DIFFERENT cheap weapon ALT-B** into one physical slot. This may briefly show zero ALT slots; the controller tolerates the temporary empty state, and requires **two stable client snapshots** of the different item to proceed. It does not guess price, attractiveness, or a raw authenticated item ID.
4. MAIN automatically **withdraws its first preapproved item while ALT-B stays unchanged**. ALT must **not** touch ALT-B during this withdrawal; otherwise MAIN stops and copies `MAIN_WITHDRAW_PRECONDITION_FAILED` or `ALT_CHANGED_DURING_OWN_REMOVAL`.
5. Only when the panel says `ALT_CLEAR_FOR_REOFFER`, ALT removes ALT-B entirely. **Both offers must be empty.**
6. MAIN automatically places its **second, different preapproved weapon**, using a new protected outgoing offer plan. Wait until GUI says `ALT_READD`.
7. ALT adds **one** inexpensive weapon (ALT-A can be reused). When GUI changes to `ALT_REMOVE_ALL`, ALT removes it completely.
8. MAIN automatically withdraws its second item, verifies the empty GUI, automatically Declines and copies a **single five-round sanitized JSON** report.

**Stop conditions:** If ALT closes a window prematurely, changes item again while MAIN is withdrawing, adds more than the allowed physical slots, touches a final Accept control, leaves the server, or the script cannot establish exact bound client P3/P4 evidence, MAIN stops/copies and sends no further request. If the window is still open, manually Decline after STOP. Never clear the one-use owner/spent flags in the same server.

## Expected five-round JSON

```json
{
  "schema": "gingerscope-system1-main-auto-native-v1",
  "status": "CLIENT_TEST_SEQUENCE_COMPLETE",
  "reason": "ALL_FIVE_CLIENT_ROUNDS_VERIFIED",
  "phase": "DONE",
  "completedRounds": 5,
  "maxRounds": 5,
  "adaptiveRoundAuthorized": true,
  "actions": {
    "requestsStarted": 5,
    "offersAttempted": 5,
    "offersClientVisible": 5,
    "removalsAttempted": 5,
    "declinesAttempted": 5,
    "clientClosedWindows": 5,
    "altRevisionsObserved": 1,
    "adaptiveReoffersAttempted": 1
  },
  "authorizesAccept": false,
  "serverCompletionProven": false,
  "verifiedCompletedTrades": 0,
  "tradeOutcome": "UNKNOWN"
}
```

This is an **illustrative subset only**; actual JSON also contains per-round records and a generated `runNonce`. Counters track client-observed or attempted side effects, not authenticated server settle. If failure occurs, `status="STOPPED"`, `reason`, `round`, `phase` and `lastAction` identify the first problem; the full JSON is automatically *attempted* to clipboard and always printed/stored as a fallback.

## Tests and evidence, and exactly what remains

- Pure test `pdiddler/ci/system1_main_auto_failstop_mocks.luau`: legacy four-round default retained, separate ARM5 consent required, five-round adaptive path, distinct MAIN weapon index1→index2, fresh fifth P3 epoch, zero final Accept.
- Native mock `pdiddler/ci/system1_main_auto_native_original_mocks.luau`: loads real original protected TradeIO and original P3/P4 bridge and frozen PR240 ABA planner/shadow, with mocked P3 request transport. Tests real UI slot changes from ALT-A to ALT-B, MAIN guarded withdrawal while ALT-B remains in offer, both-empty reoffer, second distinct MAIN raw key, fifth guarded decline and completed five-round JSON. Separate adversarial test mutates ALT-B again **before the MAIN withdrawal** and requires STOP with no extra own withdrawal, no reoffer, and correct clipboard reason.
- Python integrity and repo-wide CI ensure no new automatic final Accept, no changed original protected main sources, and that native loader pins the exact reviewed controller revision.
- **Real iPad fifth-round happy-path test is CLOSED as CLIENT-ONLY PASS.** The corrected exact-commit run completed on a real MAIN iPad/Delta according to operator-provided copied JSON. That is stronger than offline simulation for this narrow flow, but still does NOT prove authenticated object identity, remote causality or game-server settlement. Terminal first-fault live checks, generalized dynamic partner handling, rotation and automatic economic decisions are still OPEN.
- This demonstrates a **scripted, controlled proposal adjustment**, not an independent valuation/recommendation. Generalized normal negotiation (multiple revisions, profitability, attractiveness, other players, session recovery) remains next within System 1, followed by other project systems. Never merge this draft as autonomous economic release or assume protected Gingerscope can be offered outbound.
