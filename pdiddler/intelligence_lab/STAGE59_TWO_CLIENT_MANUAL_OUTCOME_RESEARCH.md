# Stage59 — one bounded manual trade, TWO read-only client receipts (NEVER server-authenticated)

## Prior real evidence and why this is different

Earlier **actual iPad/Delta Stage32** tested a manually completed **one-sided Iceblaster gift**: trusted sender offered one Iceblaster, receiver offered none, both accounts manually pressed Accept, user says recipient kept Iceblaster. Local receiving client observed +1 eligible weapon and 0 eligible lost across two independent own post-close profile readbacks, but `CompleteTrade`, `EndTrade` and `DeclineTrade` client signal receipts were **all zero**, and partner's Accept indicator was unobserved. The Stage32 result remained `ELIGIBLE_DELTA_WITHOUT_RESULT_NAMED_RECEIPT`, `tradeOutcome=UNKNOWN`. See native proof and correction in [Stage32 PR71](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/71).

**Do not repeat the same receiver-only test.** The new, distinct question is whether both participating local clients report *reciprocal*, bounded and separately observed eligible-weapon count deltas for **one** voluntarily managed manual trade, without pretending this proves a server transaction ID or weapon instance identity.

Roblox [RemoteEvent documentation](https://create.roblox.com/docs/reference/engine/classes/RemoteEvent/FireServer) describes server→client messages but offers no MM2-specific transaction settlement contract. The [RemoteFunction documentation](https://create.roblox.com/docs/reference/engine/classes/RemoteFunction) explains client/server request/response behavior but not an authenticated per-trade receipt. A received callback, two matching client inventory claims, or manual visual success alone cannot certify MM2 server settlement in a modified client runtime.

## Two new components, separate from production

**Read-only guided Delta observer:** `pdiddler/new_part4/STAGE59_GUIDED_DUAL_CLIENT_WITNESS.lua`.

- One test program runs on BOTH devices, one logged in as `SENDER` and the other `RECEIVER`. In-game **purple instruction panel** asks the operator to select the role on each device and displays actionable steps DURING execution. If the UI is unavailable, the role can be supplied explicitly as a Lua parameter and all instructions print in the Delta console.
- Reuses the previously native-tested Stage32 passive collector from exact immutable repo SHA `6637a25ec69e96f6cc4215b86a97cecba56cd0e8`; it performs only the same bounded local/partner catalogue/profile reads and UI observation. It DOES NOT press any trade controls, offer/request/cancel a trade, auto Accept, teleport, write inventory, send webhooks, change prices, or reconnect.
- A real manual trade is the ONLY possible way to produce meaningful positive reciprocal evidence. There is no script-initiated trade.
- The observer's untrusted `S.result` is exported through a **strict primitive field allowlist**. It copies only a role, one static experiment label, a randomly generated **non-account** receipt GUID, local timestamp, fixed fail-closed authority flags, and the bounded Stage32 aggregate. It does not export player names, user IDs, `JobId`, usernames, weapon names/IDs, source payloads, personal inventory lists, tokens or Discord details. Auto-copies on iPad Delta and prints a console fallback.
- Earlier scanner may itself draw in-game player list UI; share only the `GINGERSCOPE STAGE59 PAIRED WITNESS` JSON and avoid recordings showing account details.
- It checks for pre-existing Stage32 owner or another Stage59 test; rejoin game to clean up old listeners between attempts. Do not stack unrelated bot or trader scripts.
- This is **not** a server-owned protocol, and a shared static pair label plus close timestamps is **not** a server transaction identifier.

**Offline reciprocal adjudicator:** `scripts/validate_manual_trade_pair.py`.

- Requires exactly one `SENDER` and one `RECEIVER` wrapper, different fresh random receipt GUIDs, same test label and at most 90-second timestamp gap.
- Requires each original Stage32 result to remain `ELIGIBLE_DELTA_WITHOUT_RESULT_NAMED_RECEIPT`, with one local before and two separate post-close reads, stable closure and safe authority fields; refuses changed session/job, inconsistent reads, client result signal, malformed raw counts or any server proof claim.
- Requires sender **lose one** eligible item and gain zero, receiver **gain one** and lose zero. It checks aggregate changes **only**, not exact weapon-type identity, causal attribution, instance ownership, actor binding or remote acknowledgement.
- Even if the operator says the same trade was visibly completed on both devices, the strongest output is **`CLIENT_RECIPROCAL_ELIGIBLE_DELTAS_UNATTRIBUTED`**, with `tradeOutcome=UNKNOWN`, `serverCompletionProven=false`, `causalTradeAttributionProven=false`, `mayRecordCompletedTrade=false`, `mayReportProfit=false`, `mayUseForStrategyLearning=false`, `authorizesAccept=false`, `authorizesTrade=false`.
- A false/mismatched pair, reused nonce, missing consent, stale or divergent times, wrong-signed gain/loss, nil data, or user-reported outcome conflicts yields `INCOMPLETE`. It NEVER claims server settlement.

## One manual test (ONLY after exact-head CI passes and with voluntary consent)

This is deliberately **different** from the single-account Stage32 test and cannot be simulated using just one running account:

1. Have **two devices/clients**, each signed into an account under your own control or a consenting trusted partner. Join **the same MM2 server** on both. Rejoin fresh to remove prior Stage32 listeners. Select Tablet where needed.
2. Execute the Stage59 immutable loader **on each device** and choose **SENDER** on the donating/test alternate account, **RECEIVER** on the receiving/main account. No account identifiers are printed.
3. Follow the live in-game panel. Wait for `READY` on BOTH clients, then open one manual trade. **Do not place or Accept anything until BOTH displays reach `BASELINE BOUND`.** If one fails to bind, decline manually and send the error—not an assumed success.
4. If **both users voluntarily agree**, the sender can manually offer **one genuinely expendable eligible duplicate**. The receiver offers nothing. Each user manually presses their own Accept/confirmation after checking both sides. There is no automatic Accept or guaranteed success. **Do not risk valuable weapons**, use an item you're comfortable transferring or skip the completion test.
5. After that window closes, wait for **POST_CLOSE_READS**, then **FINISHED** on BOTH devices. Do not server-hop, rejoin, change inventories or open a second trade while waiting. The report copies itself to each device's clipboard.
6. Paste **BOTH** `[GINGERSCOPE STAGE59 PAIRED WITNESS]` JSON reports separately in ChatGPT, indicating which device was sender and receiver and whether you *personally saw* the same manual exchange finish. Don't paste usernames, IDs, webhook tokens or full inventories. Then stop.

**If you can't use two devices/accounts simultaneously, do not run this as a unilateral transfer test.** The safe next step would be to design a different proof path. If a report indicates incomplete, malformed, no eligible delta or signals not previously catalogued, stop and analyze that single issue before another trade.

## Testing, code review and safe deployment

The new Python test module `test_stage59_two_client_manual_witness.py` exercises nominal client reciprocal status and **800 seeded adversarial pairs**. The actual Stage59 Lua wrapper is executed under Lua 5.4 against a fake GUI and fake Stage32 emitter, including role selection, clipboard, error conditions, older listener collision and invalid source authority. This is **not a live Roblox test**; exact-head GitHub Actions must pass before the operator executes a pinned SHA.

Both new files are RESEARCH ONLY, based on current post-Stage52 main. No production bot, Part3 scanner, Part4 offer writer, automatic final Accept, Supreme value updater or Discord learning system was modified. The historical Stage32 module itself remains unchanged on its earlier draft branch.

**Next branch after this:** If the native pair produces reciprocal inventory claims and the operator reports visible completion, investigate whether the game provides a genuine transaction/session/result contract exposed to clients. Otherwise use a clearly named **client corroboration** workflow with explicit manual review; do not represent inferred profit or inventory wealth as independently settled.

## Stage59 first native receiver test and corrective patch — 2026-11-08 09:31 Eastern

The user executed the first Stage59 immutable guided observer on their receiver client and pasted a **single receiver-side JSON**, not a completed two-sided test. The client did find a stable own-inventory baseline (`beforeObserved=true`) but did not close the manual trade before the original **30-second** deadline:

- `stage32.stopReason=TRADE_WINDOW_NOT_CLOSED_WITHIN_30S`, `stage32.status=INCOMPLETE`.
- `stage32.inventoryStatus=AWAIT_CLOSE`; `windowClosureObserved=false`; `postReadbacksObserved=0`; `closureStatus=not-closed`.
- `observedOurAccept=false`, `observedTheirAccept=false`; `signalReceipts=0`.
- Wrapper incorrectly called this `collectorStatus=CLIENT_STAGE32_READBACK_CAPTURED` simply because an incomplete Stage32 source table existed. That was **misleading** and is not a successful readback.

These observations establish an unfinished **client-side observation**, not a failed trade, no trade completion proof and no evidence of sender-side deltas. The separate sender report is not necessary to diagnose this timeout.

### Root causes in the actual pinned source

The original immutable [Stage32 launcher in PR71](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/71) imposes `os.clock()-beforeTime<30` plus `maxBeforeToClose=30` in the Stage29 pure ledger, with a 30-second stop reason. The original [Stage29 pure ledger](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/blob/06374ead14ce0b18fb05e55c80c2df6a143bf0ce/pdiddler/new_part4/p4_stage29_postclose_ledger.lua) also hard-fails a window longer than **60 seconds** (`age<=60`). Blindly changing only the outer observer deadline to 120 seconds would still produce `before-to-close-age-invalid` or a constructor error, not a valid result.

Stage59 updates only its own read-only diagnostic forks:
- `pdiddler/new_part4/STAGE59_POSTCLOSE_LEDGER_120S.lua`: **exactly one** alteration relative to the original Stage29 file: increase the **bounded preclose guard** from `age<=60` to `age<=120`; preserve the original separate `maxPostAge<=60`, the actual post-close readback age `maxPostAge=30`, scope and inventory identity checks, changed-items and acceptance boundaries.
- `pdiddler/new_part4/STAGE59_RESULT_DELTA_120S_PROBE.lua`: original Stage32 source altered at **exactly six places**: Stage29 module pin/name, `maxBeforeToClose=120`, GUI `beforeTime<120`, the 120s human prompt, and the named `TRADE_WINDOW_NOT_CLOSED_WITHIN_120S` stop. Every other client observer call, event listener, two post-close own inventory RPCs, and privacy/authority field are **byte-identical** to earlier Stage32. The original source was not changed.
- `pdiddler/new_part4/STAGE59_GUIDED_DUAL_CLIENT_WITNESS.lua`: pins the new fork to its immutable source commit, shows a roughly 15-second-cadence 120s monotonic countdown after `OBSERVING_CLOSE` begins, and fixes `collectorStatus` so terminal readbacks are `CLIENT_STAGE32_TERMINAL_OBSERVATION` **only when** the nested Stage32 source includes the initial baseline, window closure, two after-close reads, terminal stop reason and `status!=INCOMPLETE`; timeout/errors produce `INCOMPLETE_STAGE32_NO_POST_CLOSE_EVIDENCE`. Neither status represents server settlement.
- The offline `validate_manual_trade_pair.py` now also **requires** a proper terminal wrapper status instead of accepting a timeout mistakenly labeled as complete. Any old/partial receipts are `INCOMPLETE`.

**Exact-code source fidelity audit:** Python takes each fork's byte stream, reverses the one Stage29 or six Stage32 explicit changes, and computes the real **Git blob SHA-1**, asserting exact equality to the original sources `bbb40941ab6fe6ed40c6ce999a0eb40fc7b7576e` and `3cbe1aedaa9c8601a6e1727331aabf3a206ed1e0` respectively. This proves no unrelated trading/identity/transport edits slipped into the forks.

**Real Lua 5.4 tests** instantiate the adapted Stage29 ledger at 31, 115 and 120 seconds and show a scoped three-read eligible +1 or -1 **unattributed** client result; 121 seconds and post-close reads beyond 30 seconds are refused. They run **400 seeded timing/quantity cases**, plus the native-shaped Stage59 timeout report, GUI/clipboard and 800 paired-evidence adversarial cases. Full inherited Python tests also run. No source price, automatic Accept, completed-trade journal, or webhook changes.

**Exact-head CI gate for this patch:** [Actions 42490773595](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42490773595) SUCCESS with **11 targeted Python tests** and **102 total Python tests**. This was a synthetic Lua/CI check, NOT an actual new iPad result.

### When next manual evidence is appropriate

1. **Rejoin both MM2 clients fresh** to clear old Stage59/Stage32 listeners, and put them in the **same server**.
2. Use only the newest immutable Stage59 loader on both clients; old pinned SHA `607e55bd...` is **superseded and must not be rerun**.
3. In the in-game panel select SENDER or RECEIVER, wait BOTH clients show READY, manually open the trade, wait BOTH show `BASELINE BOUND`, then complete/decline the trade **within the 120-second observation window**. If not willing to transfer an expendable duplicate, **do not Accept**.
4. After window closure, do not rejoin or start another trade. Wait for BOTH `POST_CLOSE_READS` and `FINISHED`; paste separate sender and receiver anonymized JSONs. If a client times out or errors, paste that result and stop.
5. The panel displays a remaining-time approximation; the actual ledger owns the authoritative bound. Two matching client inventories do NOT mint a server-authenticated trade receipt. Manual confidence may be stated separately from machine attestation.
