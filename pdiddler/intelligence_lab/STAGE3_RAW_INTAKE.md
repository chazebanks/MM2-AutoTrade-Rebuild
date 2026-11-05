# Stage 3: real raw inventory intake (read-only)

The standalone GetProfileData exporter returns native MM2 item IDs and quantities, **not** Supreme checker IDs. `raw_inventory_intake.py` accepts this format and rejects duplicate IDs, corrupt quantities, and unsupported sources.

To price an item, the separate scanner must supply its original native ID **and** quantity together with a candidate `(page, checkerId, name, type)`. `reconcile_scanner_output` checks exact ownership quantities, catalog identity, unique checker identity, and price consistency. Unknown, ambiguous, or conflicting records are not priced. A reconciliation match does not grant permission to trade: Stage 2's time, game, session, ownership and market-provenance gates remain mandatory.

`EXPORT_SCANNER_IDENTITIES_READONLY.lua` is manually run in MM2 after the **existing** V15.8 main loader's scanner is ready. It uses the scanner's own read method and copies the scanner result JSON. It does **not** initialize the trader, place or accept offers, or send webhooks. The already-running trader remains active independently and may continue to trade/hop.

Local verification: `python -m unittest discover -p 'test_*.py' -q` passed 47 Python tests (34 inherited Stage 1-2 + 13 Stage 3). Synthetic contract tests are not a substitute for a captured live scanner export.

The owner's pasted 112-ID/382-copy inventory is handled privately as an offline fixture and **is not uploaded to this GitHub branch**. The previously identified 14 source-price candidates (19 copies, 4,548 Supreme listed units) are still provisional pending native scanner reconciliation; lower-rarity items and any unverified collectibles are not assigned invented numerical prices. The pinned market snapshot expires at its original time and is never silently extended.

Do not merge or autoexecute this branch until native evidence is checked and the new decision engine is ready.
