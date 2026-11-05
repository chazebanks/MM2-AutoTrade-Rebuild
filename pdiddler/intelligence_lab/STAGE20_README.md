# Stage 20 — Python client-outcome evidence audit

**Offline research only.** Existing scanner, old V15.8, new Part 4 stages, Delta and final Accept remain unchanged. No webhook or real completion is claimed.

## Reuse, don't rebuild
- Stage 9 provides a read-only *trade-window observation* contract and an actual Delta diagnostic, but **no server trade-completion proof**.
- Stage 6 can export cached opponent inventory; it is not a fresh authoritative post-trade readback.
- Stage 19 reconciles completed-trade ledger claims to before/after holdings, but does not prove the claims are true.

Stage 20 adds only a **pure Python offline cross-check** for normalized observations that a later adapter might supply. It does not invent another scanner or an on-device trading mechanism.

## Outcome contract

Use one final **resolved** offer, the observed acceptance indicators, a separately reported closure classification, a complete before-inventory snapshot and **two independently numbered, separately timed, matching post-closure inventory snapshots**. The account and job must match all snapshots; account/job/session/partner must match the offer/closure. Check exact canonical checker IDs, quantities, offer-to-inventory delta and time order.

- `INCOMPLETE`: missing/ambiguous evidence; closed window or either Accept alone cannot prove completion.
- `INCONSISTENT`: partner/session/job mismatch, wrong inventory changes, post-read discrepancy or invalid capture order.
- `CLIENT_CORROBORATED`: the **caller-provided** client records agree. **This is not independently verified MM2 server completion.**

Every output deliberately has `server_completion_proven=false`, `may_record_completed_trade=false`, `may_report_profit=false`, `authorizes_trade=false`, `authorizes_accept=false`. No Stage 19 CompletedEvent is automatically emitted. A fabricated UI status, reused timestamps, screenshot or account-switch cannot turn into a completed-trade profit claim.

## Tests

Run from the repository root:

```sh
cd pdiddler/intelligence_lab
python3 -m unittest discover -q
```

All 24 new Stage 20 tests use synthetic evidence and cover matching stacked copies, session and partner swaps, job changes, alt account separation, late/duplicate reads, price-free exact ID deltas, invalid quantity, ambiguous Laser, and refusal to mint trade completion without server proof.

The release gate for real completion remains unproven until the actual game has reliable outcome evidence and fresh inventory readbacks, then a native test demonstrates the implemented client adapter matches this contract. Nothing here enables final Accept.
