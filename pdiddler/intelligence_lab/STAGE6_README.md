# Stage 6 — Read-only opponent scanner-cache evidence

**Research only. Not authorized to execute trades. Do not autoexecute this as a trader or merge it into the live V15.8 bootstrap.**

This stage collects the current scanner's **cached** opponent inventory rows without calling Roblox remotes, modifying GUI state, sending requests or trading. Cached rows contain verified item IDs and quantities but lack last-scan timestamps; **the export timestamp is not the time those inventories were scanned**. The Python adapter deliberately labels scan age unproven and never authorizes a live trade.

## Components

- `EXPORT_OPPONENT_CACHE_READONLY.lua`: one-shot manual Delta export of existing V15.8 scanner records, including current presence, scanner/retry state, completeness flags, fingerprints, `page + checkerId`, raw display values, and snapshot market version. It uses generic `P1`, `P2` labels; no player name/user ID leaves the client. Requires the existing V15.8 loader to have initialized its scanner. It does **not** refresh inventories.
- `opponent_observation.py`: validates format, market freshness and source version, export age, exact checker IDs/names/weapon types, quantities, duplicate identity, and completeness. Raw display value discrepancies are logged, not assigned market authority. Returns human-review-only records and can call Stage 5's existing `plan_growth` for *hypothetical* offers.
- `test_opponent_observation.py`: 13 synthetic contract tests and static guard that the Lua exporter contains no trade/remote execution calls. 103 tests pass locally for the complete Stage 1–6 laboratory.

## Human workflow

1. Run existing V15.8 trader, wait until its scanner panel displays inventory results. **The trader may still initiate requests or hop while running.**
2. Execute `EXPORT_OPPONENT_CACHE_READONLY.lua` once in Delta. It copies a JSON snapshot or prints it if clipboard support is absent.
3. Paste the JSON in chat promptly for research-only analysis; the Python importer rejects exports more than 120 seconds old or from an expired market source. If `marketFresh=false`, refresh the source publication separately; **do not extend old expiry manually.**
4. We may rank plausible opponent-specific *hypothetical* trades from the cache, but none should be assumed accepted, available now, or automatically safe to execute. Cache must not be used as trade-window completion evidence.

## Limitations and next gate

- Existing scanner records don't supply **last successful scan time**, or guaranteed offer-window freshness. `snapshotAtEpoch` records export time only.
- The 190-row Supreme snapshot is source-pinned and expires 2026-11-05 21:55:32 UTC (4:55:32 PM New York). New data requires a real source refresh, never a timestamp substitution.
- Old P4 profit/concession logic is unchanged; no new intelligence is wired to the live trader. Native final Accept and verified completion/webhook reporting remain disabled.
- Stage 5's 90% review coverage is an uncalibrated filter; real trade behavior still needs observation.