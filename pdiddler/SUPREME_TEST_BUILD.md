# Separate Supreme trading test build

Entry point: `pdiddler_FASTGATE_V5_INTEGRATED_TEST_v4_SUPREME.lua`.
Start in a fresh server session. Run one build once; switching between existing
loaders in an initialized session is deliberately blocked. This build offers,
removes, rebalances and declines real items/requests. Test with an inventory you
can supervise. **Automatic Accept is disabled; completion reporting and Discord
webhooks are not enabled.** Offline tests do not establish native MM2 behavior.

## Implemented

- Immediate highest eligible Supreme-valued opener, followed by actual-slot
  verification. Separate raw MM2 execution IDs and canonical price/checker IDs.
- Exact usernames, including underscores. Display names and substrings cannot
  establish a trade partner or outgoing recipient. Active tablet and phone roots
  are selected by visibility and current ancestry.
- Strict **+15 Supreme** profit floor, using integer cents for the comparison.
  No raw-loss quality exception. Unknown, contradictory, Priceless, malformed or
  non-finite prices/quantities cannot be offered or counted as zero.
- One bounded dynamic planner for each changed offer. Search actual eligible
  quantities up to **four copies total**, a conservative subset of the native
  four-slot capacity. This version does not exploit larger stacked quantities in
  those slots. At equal totals, prefer fewer copies, then preserve higher-demand
  inventory. Demand is metadata, not an invented resale-price multiplier.
- Reevaluate after every observed offer change. Five seconds without acceptance
  permits the nearest higher safe total; the best safe offer gets a final five
  seconds before decline. A resolved impossible offer is declined.
- Empty offers time out after twelve seconds, including a new empty interval
  after removal. Accepted-empty declines immediately. Keep a nonresetting sixty
  seconds from their first observed nonempty offer, including mutation waits.
- One outgoing owner and Part 4 owner. Requests protect the processed-player
  ledger for the current server JobId across safe outgoing-controller restarts.
  Ambiguous request cancellation is not retried with a second input/remote.
- Every offer mutation rechecks session, partner, GUI, offer generation and
  prices. Closing/reopening the same GUI during an inventory wait invalidates
  its old lifetime. Price expiry permits an identity-verified decline and blocks
  new requests/hops.

The bot gate, scanner, startup and transport dependencies remain immutable. The
scanner's existing whitelist criteria and scanner UI remain its original
MM2Values basis; the new trading API reprices copies of inventory to Supreme.
Displayed scanner eligibility/totals must not be read as Supreme trade totals.

## Snapshot and refresh

The dated snapshot maps 190 canonical items: 16 Ancients, 46 Chromas, 128 Godlies.
189 have finite prices. Nik's Scythe retains `Priceless` and has no numeric price.

- Source publication: **November 2, 2026, 17:34:27 UTC**.
- First observation: **November 3, 2026, 20:29:14 UTC**.
- Fixed expiry: **November 4, 2026, 20:29:14 UTC**.

The earliest of observation +24 hours and publication +72 hours applies. Reloading
does not renew it. Source estimates are not guaranteed resale values. The build
halts new trading after expiry; it does not fetch or change prices mid-trade.

To compare newer publisher records for research:

```sh
python3 pdiddler/refresh_supreme_snapshot.py \
  --mapping pdiddler/snapshots/supreme_snapshot_2026_11_04.json \
  --output-dir /tmp/supreme-review
```

The Stage 69 generator validates category and name matching, displayed values,
demand, stability and publication provenance. It emits research JSON with source
hashes and trade authority disabled. Existing dated Lua modules are archived
fixtures. A new runtime profile requires separately reviewed game-item identity
and freshness evidence.

## Verification and remaining work

Use Lua 5.3/5.4 (or texlua), Python 3, and official Luau 0.745:

```sh
python3 pdiddler/tests/run_integration_tests.py
LUAU_BIN=/path/to/luau LUAU_COMPILE=/path/to/luau-compile \
  python3 pdiddler/tests/run_trading_tests.py
python3 -m unittest discover -s pdiddler/tests -p test_refresh_supreme_snapshot.py
```

Complete native acceptance (including the extra uninterrupted second), correlated
completion/inventory-delta verification, durable completion logging and an
ambiguity-aware Discord outbox remain future work. No closed window increments
completed totals or fires a webhook in this build. Live Delta/tablet verification
of offer, remove, accepted indicators and GUI lifecycle is still required.

Research and proposed complete design remain on the
[`docs/pdiddler-trading-research-2026-11-03` archive branch](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/tree/docs/pdiddler-trading-research-2026-11-03).
