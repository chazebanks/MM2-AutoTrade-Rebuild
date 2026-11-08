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
