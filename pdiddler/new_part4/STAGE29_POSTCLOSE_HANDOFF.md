# Stage 29 — Read-only post-closure inventory evidence (no completed-trade authority)

**Status:** Draft. This is a new observation test, NOT an autonomous trade controller.

## Why this stage exists

Stage 27 was proven on a real iPad: controlled one-item ADD and REMOVE each appeared in separate client GUI observations. Stage 28's native read-only observer correctly detected a **partner-only Accept** in a one-sided offer: the live corrected report showed 134 observations, repeated `THEIRS_ONLY` and `CLOSED_UNKNOWN`, with no false mutation or unresolved-offer flag.

Those results establish client interface behavior, **not** whether a trade was server-completed. The older Stage20 Python outcome auditor explicitly forbids a closed GUI or matching client inventory claims from producing a CompletedEvent, profit or Discord message. Stage 29 must preserve that boundary.

## New Stage 29 modules

- `new_part4/p4_stage29_postclose_ledger.lua` is a **pure** Lua ledger for one bounded job/account/partner/session. It accepts one fresh baseline own-inventory scan, a separately observed `CLOSED_UNKNOWN` window, and two separately called post-close own-inventory reads at least 750 ms apart. It rejects missing/incorrect canonical checker IDs, noninteger quantities, duplicate canonical item IDs, unmapped weapons, missing fingerprint, out-of-order scans, changed session/account/job/partner and stale pre/post timings.
- Its conclusions are deliberately **non-authoritative**:
  - `NO_ELIGIBLE_DELTA_OBSERVED`: the eligible item counts and raw weapon fingerprint matched. **Not proof of decline**.
  - `RAW_WEAPON_CHANGE_UNATTRIBUTED`: eligible counts match but the scanner's raw weapon fingerprint differs.
  - `ELIGIBLE_DELTA_UNATTRIBUTED`: eligible counts changed, but the change's cause is unknown. **Not proof of a completed trade**.
  - `POST_READS_DISAGREE`: two separate post-close inventory responses differ. No stable inference.
  - `INCOMPLETE`: at least one required observation or chain-of-custody check failed.
- Every result has `serverAttestation=false`, `serverCompletionProven=false`, `authorizesAccept=false`, `mayRecordCompletedTrade=false`, `mayReportProfit=false`. No individual item IDs, fingerprints, account IDs or user IDs are exported.
- `new_part4/STAGE29_POSTCLOSE_DELTA_PROBE.lua` is a one-paste **read-only** Delta experiment. It reuses Stage25's isolated scanner and Stage9 + Stage28 read-only GUI observation, performs one existing `scanner.getOwnInventory()` call while a manually opened trade is active, waits up to 30 seconds for that exact window to close, then performs two further existing scanner reads. It never calls OfferItem, AcceptTrade, DeclineTrade, GUI click, outgoing request, server hop, Discord or a trading policy.

### No second scanner

Stage 29 uses exactly the *existing* Part3/Stage25 scanner's `GetProfileData` own-inventory API. It introduces no new inventory remote and does not create another scanner or replace the existing Part4. The three readback calls are **client claims** returned by the MM2 inventory remote, not cryptographically authenticated server-completion proof. No price source is required to classify item counts; do not infer profit from the numeric values.

## One controlled native test

1. Rejoin MM2 to clear Stage 28's scanner listeners. Select Tablet, then run the Stage 29 read-only probe **before opening a trade**.
2. Wait for the existing scanner to finish, then manually open a trade with a trusted player. This is an observation test: no items need to be added from your side, and you **must not press Accept**.
3. The probe reads your current inventory once and prints a *baseline verified* notice. After that notice, manually decline/close the trade **within 30 seconds**. No player needs to press Accept to test post-close reconciliation.
4. The probe automatically reads your own inventory twice after closure and prints/copies `[GINGERSCOPE STAGE29 ANONYMIZED]` JSON. The expected result for a simple decline is usually `NO_ELIGIBLE_DELTA_OBSERVED`, but that is **not** evidence that decline caused the unchanged state. If scans are incomplete, the correct output is `INCOMPLETE`; never edit a cache or repeat an uncertain remote silently.
5. Send only the anonymized Stage29 JSON. The scanner's original in-game GUI/console may still show player names. Rejoin after the experiment to clear the long-lived scanner listeners.

**Do not complete a real trade for this test.** If no owned weapons or a verified baseline are available, the test must hold rather than fabricate a 'no-change' result.

## Relationship to Stage20

The older Stage20 auditor currently requires both sides nonempty before it can issue `CLIENT_CORROBORATED`, even though the Stage28 live test established that MM2 accepts one-sided offers. This is a **separate pending research boundary**, not a reason to change it while implementing a pure post-close count observer. Stage20 still returns `INCOMPLETE` for `closed_unknown` even when both accepted or inventory deltas match. Stage29 does not call Stage20 at runtime or promote its `CLIENT_CORROBORATED` category to authenticated server completion.

## Validation

- `new_part4/tests/test_stage29_postclose_ledger.lua`: 18 synthetic cases for unchanged, changed, raw-only changes, inconsistent post scans, replay attempts, unknown session, invalid checksums/IDs and timing.
- `intelligence_lab/test_stage29_postclose_evidence.py`: Python source/behavior tests, actual Lua regression invocation and compilation-only check of the native probe.
- Existing full Python and staged Lua suites run in GitHub Actions.

**No final Accept, completed-trade webhook, profit, server-authenticated completion or production loader enablement is introduced by Stage29.**
