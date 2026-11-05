# Issue24 — truthful scanner evidence (V15.5)

This bounded follow-up addresses the latest V15.4 native audit in [Issue24 comment6646587255](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/issues/24#issuecomment-6646587255). It is stacked on PR25, cf69d7e82f81f2867a39ede6e18d64b97a9d8fcb. All368 predecessor files remain byte-identical.

## Actual causes

1. V15.4 sends economic classifications through `setRequestState`. An unknown result caused by OUR10-second proof cache relabels an already verified opponent row as UNKNOWN. The header summary still counts raw rarity, so rows and summary describe different things without saying so. Reusing request ownership also lets economic updates replace REQUESTING/PROCESSED presentation.
2. `assess` checks own proof before recognizing an independently verified zero-eligible blacklist. That target cannot possibly supply +15, even if our proof is unavailable; the v1 ordering unnecessarily calls it unknown.
3. Scanner presentation uses the legacy embedded price map: Immortal140 and Embersickle80. P4's pinned current profile is already correct at135 and95. This discrepancy is presentation, not a P4 profit-calculation error.

The supplied original native video is not present in this workspace. The latest issue audit reports manual final Accept and an Immortal Claim panel, stronger evidence of an exchange than closure alone; it quotes +40 at the pinned135−95 prices. This patch does not implement authoritative completion reconciliation or diagnose the later rotation delay.

## What changes

- Scanner receives the same profile and strict policy as P4 before any initial item display. Its raw catalog, parser, rarity classification, owned quantities, scan/retry algorithms and inventory readers remain unchanged.
- Pure presentation reprices canonical items without mutating raw inventory. UNPRICED/Priceless/unverified rows remain visible; they never become a fake zero. Expired/unavailable prices remove current price and economic reachability claims.
- Separate row fields show raw inventory rarity, economic assessment and genuine request state. Request/processed headings retain priority. Summary separates inventory rarity counts from economic counts for unprocessed players.
- Own-proof missing/stale and transaction-paused reasons are explicit. Read-only economic presentation updates continue during transaction holds; global guards still prevent requests and hopping.
- A fully verified blacklisted opponent with zero eligible entries is unprofitable without our owned proof. Missing, malformed, unpriced, ambiguous, contradictory or actively scanning inventories remain unknown. Price/global holds remain enforced.
- Initial rendering, scanner result publication, scan-start progress, periodic repaint and request updates use the same current-price/composed presentation paths. This avoids transient loss of request/processed fields during rescans.

No P4 negotiation, Common-item handling, native completion, auto-final-Accept or Discord-completion changes. P1/P2/P5, physical request controller and final send proof code remain pinned unchanged. Own refresh/backoff and10-second proof TTL, exact final own read/fingerprint/JobId/price/controller fences,30-second unknown allowance and45-second exhaustion clock are unchanged.

## Failing-before / passing-after evidence

- Real legacy scanner helpers reproduce UNKNOWN/BLACKLIST contradiction,140/80 prices, request-state overwrite, missing economic counters and stale expiry values.
- Actual `applyPlayerResult` and `scanPlayerLive` reproduce the post-result/start repaint race. Both now preserve genuine request/processed state without changing scan control flow.
- Real coordinator v1 calls a verified empty opponent `unknown/own-inventory-unavailable`; v2 proves `unprofitable/no-eligible-opponent-items` independently of owned proof, while retaining global holds.
- New tests cover current initial render, raw record immutability, current135/95 values, unknown/Priceless exclusions, normal/Chroma distinction,10s own expiry/recovery, separate counts and processed exclusion, transaction pauses, profile expiry and final send rejection.
- The complete outgoing-worker fixture runs with the successor coordinator and preserves all six ownership/navigation/timeout/pause/resume/inventory-change scenarios.

Run with official Luau0.745 and Lua5.4 (texlua also used locally):

```
LUAU_BIN=/path/to/luau LUAU_COMPILE=/path/to/luau-compile python3 pdiddler/tests/run_issue24_scanner_checks.py
```

This runs8 top-level scanner checks, the preserved25-check gate and inherited37-command V14 suite; all predecessor hashes, critical scan/identity/read paths and exact final-send/refresh/clock code are checked. See RED_BEFORE.txt and OFFLINE_RESULTS.txt. Native iPad gameplay was not executed here.

## Native verification still required

1. Fresh JobId, older entries disabled: initial scanner must display Immortal135/Embersickle95, consistent with P4. Confirm quantities and Chroma variants remain distinct.
2. During a pending request, other verified blacklists stay blacklisted. Own proof pauses appear only in the separate economic field; raw rarity counts stay consistent.
3. Observe native REQUESTING/PROCESSED rows while periodic scans begin/end. Confirm headers, drag/minimize controls and P4-owned status remain stable.
4. After a manually finished trade, verify own-proof recovery and rotation independently. This patch cannot prove or report a completed trade from a closed window.
5. Before price expiry, verify normal requests and final pre-click guards; after expiry, new trading must remain blocked and UI price/economic assessment must show the hold.

The fixed Supreme expiry is still **2026-11-05T21:55:32Z (November5 at4:55:32PM EST)**. No refresh or extension is included. Final Accept and completed-trade Discord remain OFF. Common-item negotiation and authoritative completion are separate follow-ups.
