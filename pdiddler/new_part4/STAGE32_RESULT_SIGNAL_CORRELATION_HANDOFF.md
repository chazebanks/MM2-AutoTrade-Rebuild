# Stage 32 — Read-only result-named signal × inventory correlation

**Status:** Draft. No automatic trade actions, final Accept, completed-trade webhook, profit statement, or server-completion claim.

## What has actually been established

- Stage27: iPad/Delta controlled one-item ADD/REMOVE each observed by separate native trade GUI snapshots, not a completed exchange.
- Stage28: real iPad test proved partner-only Accept icon on a legitimate **one-sided offer**; closure was `CLOSED_UNKNOWN`.
- Stage29: real iPad test showed one own-inventory baseline plus two separate post-close own inventory readbacks, no eligible change. This does not prove a decline.
- Stage30: real iPad client received exactly one `DeclineTrade` event `WHILE_OPEN` as the user manually closed a trade.
- Stage31: a second real iPad run, with the *partner* declared as the actor closing the trade, **also** received one `DeclineTrade` event `WHILE_OPEN`. Names alone cannot distinguish initiator. Neither trial ever received `CompleteTrade` or `EndTrade`.
- The 16-name client RemoteEvent catalog exposed `CompleteTrade`, `EndTrade`, and `DeclineTrade`, but a RemoteEvent name or `OnClientEvent` receipt is **not a server-authenticated transaction result**. Roblox documents the server-to-client RemoteEvent API but not MM2 game-specific outcome guarantees: https://create.roblox.com/docs/scripting/events/remote.

## New Stage32 code

- `new_part4/p4_stage32_result_correlation.lua` is a **pure, bounded** three-input join. It requires one exact Stage28 session terminal GUI close, one Stage30 terminal client signal census, one Stage29 terminal **three-read** client own-inventory ledger, and close timestamps within one second. Any missing/failing evidence reports `INCOMPLETE`. It records whether **a received** (not merely cataloged) `CompleteTrade`, `EndTrade`, or `DeclineTrade` signal coincided with a changed local eligible inventory. Missing/unverifiable receipt data or a truncated census cannot be treated as a negative proof. All result categories still say `tradeOutcome=UNKNOWN`.
- `new_part4/STAGE32_READONLY_RESULT_DELTA_PROBE.lua` reuses the tested Stage25 scanner, Stage9 reader, Stage28 timeline, Stage29 ledger and Stage30 census, without modifying any of those modules or creating a second inventory scanner. It watches **only three** observed trade RemoteEvents (names above), using callbacks that take no arguments, and the existing partner departure signal. It binds to one GUI root/partner/session/job, collects a baseline own-inventory read, watches the client for up to 30 seconds, then performs **two separately called post-close** own-inventory reads. It disconnects every listener before printing an anonymized JSON.
- `new_part4/tests/test_stage32_result_correlation.lua` checks both candidate result-named signals present/absent, inventory delta present/absent, conflicting CompleteTrade and DeclineTrade, partner departure, truncation, wrong session, bad closure and readback failures, all with **zero** server-completion authority.
- `intelligence_lab/test_stage32_result_correlation.py` runs the actual Lua module and compilation check and asserts zero trade clicks/remote sends/automated Accept or completed-trade authorization.
- The inherited staged Part4 Lua and full Python regression suites must pass in GitHub CI.

## One carefully controlled native test (optional; manual item exchange)

**This differs from Stages30/31.** To discover whether MM2 *actually delivers* `CompleteTrade` or `EndTrade` for a successful manual exchange, there must be an **ordinary manually completed trade**. No script action can make a real completion happen, and no user or partner should risk valuable inventory for a diagnostic.

1. Rejoin MM2 to clear Stage31's existing scanner and listeners. Select Tablet. Run the **one** Stage32 passive script *before* opening a trade.
2. Let the existing scanner complete, then manually open a trade with a **trusted, consenting participant**. Use only a genuinely expendable low-value duplicate weapon. A one-sided gift is allowed by MM2's observed rules if **at least one weapon is offered in total**, and requires both people to choose their own manual Accept/confirmation. This is not a suggestion to transfer any costly collectible. No exchange is needed if neither person consents to losing that item.
3. Wait for `[GINGERSCOPE STAGE32] BASELINE + CLIENT SIGNALS BOUND`. **Do not act before that message.** Manually verify the exact offered weapon(s) on both sides. Both players manually decide whether to confirm the trade. **The Stage32 script will never click Accept, confirm, place, remove, decline or change either offer.**
4. When that exact trade GUI closes, Stage32 performs two separate own-inventory readbacks and copies `[GINGERSCOPE STAGE32 ANONYMIZED]` JSON to the clipboard. Send the JSON and report whether you *personally observed* the manual exchange complete. If the trade did not complete, report that instead.
5. Rejoin after the run. Never reuse the scanner's old listeners on a second trade.

**If you don't want to give or receive any low-value item, do not complete a trade for this test.** A manual close can still exercise the probe, but its evidence will likely duplicate Stage30/31 and cannot establish any success-event behavior.

## How to interpret the output

Examples: `COMPLETE_NAMED_RECEIPT_AND_UNATTRIBUTED_DELTA`, `END_NAMED_RECEIPT_AND_UNATTRIBUTED_DELTA`, `COMPLETE_NAMED_RECEIPT_WITHOUT_ELIGIBLE_DELTA`, `CONFLICTING_RESULT_NAMED_RECEIPTS`, `NO_RESULT_NAMED_RECEIPT_OBSERVED` or `INCOMPLETE`.

All such results mean **only client-side observations**. Even a `CompleteTrade` signal plus an apparently matching inventory change and two Accept indicators cannot authenticate a server trade, prove causation, establish a new profit, authorize Accept, or trigger a Discord completed-trade webhook. The older Stage20 auditor remains restrictive and cannot be bypassed by Stage32.

### Risk controls / known limitations

- All module sources are pinned to immutable GitHub commits. No dated Supreme valuation profile is used and no profit is computed.
- The probe may fail to bind if the existing scanner inventory or partner record is not ready within the allowed session/time; it reports `INCOMPLETE` rather than retrying uncertain remotes.
- The window can close before two stable Accept icons are sampled; Stage32 still records the raw observed indicators without claiming unseen acceptance.
- Game-specific successful trade transport is **not independently documented**; it may involve different events, GUI states, cached inventory or absent inbound events. A missing candidate receipt is not proof that no trade completed.
- A remote receipt's payload and session reference are deliberately not read to avoid collecting item IDs or user IDs. Consequently Stage32 **cannot prove that a candidate receipt belongs to the exact transaction**, even with closely aligned timestamps.
- Partner leaving, a new trade reopening, mismatched root/job or readback disagreement invalidates the stage. No production loader, strategy/rebalancer, Discord outbox or automatic final Accept is touched.

**Next checkpoint:** one actual device report before deciding whether further event-contract analysis is warranted.
