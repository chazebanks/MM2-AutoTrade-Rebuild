# Issue27 verification status

The combined prepublication gate passes all six top-level checks. Immutable publication pins are pending. This file records offline verification only; native Roblox, MM2 and iPad Delta execution have not been run by the test harness.

The runtime runner bundles the complete production P4 successor with the preserved Roblox boundary fixture, actual policy 9, early-counter policy 5 and lifecycle 1. It records physical mouse-down/release, OfferItem, DeclineTrade and planner timestamps. Its only source injection adds a read-only getter for the existing BOUND closure; the production algorithm and API are unchanged. The inherited Issue19 suite is executed verbatim against the successor.

Reproduce the release gate with Lua and official Luau 0.745 installed:

```sh
LUAU_BIN=/tmp/pdiddler-luau/luau LUAU_COMPILE=/tmp/pdiddler-luau/luau-compile python3 pdiddler/tests/run_issue27_checks.py
```

The release gate requires `safety27/RUNTIME_PINS.json`, all 20 immutable dependency references and exact loader/bootstrap blobs. The GitHub workflow uses this pinned mode. The prepublication flag does not relax any predecessor blob, inherited dependency or behavior check.

The gate compiles all 3 new root Lua runtime files and runs six top-level checks: Issue27 scope, the full pinned predecessor scanner-evidence gate, actual successor runtime tests, unchanged inherited runtime tests, loader contracts and teleport-bootstrap contracts. Complete output is written to `/tmp/issue27-all-results.txt`, including the predecessor's full nested results.

The actual controller suite passes 44/44 cases; the unchanged inherited Issue19 suite passes 15/15. Loader integration passes 21/21 and teleport-bootstrap contracts pass 34/34. The same 44-case runtime suite against predecessor P4 v9 produces 19 passes and 25 failures. The scope gate verifies all 390 predecessor files byte-identical, preserves 19 dependency references and checks unchanged identity, valuation, +15 decision, planner and timer blocks. The pinned predecessor gate passes, including its 8 scanner checks, 25 preserved checks and inherited 37-command V14 suite.

The original cause was control-flow ordering: a changed opponent signature continued through the 0.65-second stability wait before checking the current physical quote. Aborted replacements could then add recovery delay before another safety decision. Confirmed failing-before cases show no urgent action before 0.65 seconds for 405/1295→405/115 and 33/101→33/33. Baseline post-insert decline took 1.840 seconds, unknown-own-after-insert decline took 2.830 seconds and final-verification decline took 1.770 seconds in the deterministic fixture.

The successor checks safety before voluntary debounce and at transaction boundaries. The passing cases cover:

- Immediate decline for stacked/multiple-slot exposure and unsafe local or partner acceptance state; urgent single-copy withdrawal followed by the exact 18/33 (+15) verified quote.
- A single total 0.24-second withdrawal deadline from mouse-down, no retry, uncertain-acknowledgement ownership hold and missing/nontext live quantity requiring decline.
- Opponent changes at mouse-down, remove verification, post-remove, partial insertion, post-insert and final slot verification; stale safe-empty transactions retain guarded recovery.
- Unknown Common items remain unresolved, invalidate approval and cannot become zero-valued profit proof. If local acceptance becomes true or unknown while those same raw slots remain visible, the controller declines immediately.
- Stable quote verification clears its invalidation flag even when optional telemetry returns nil. Valid quantity spelling changes such as x1→1 cause no physical reset or new concession; malformed quantities remain unknown.
- Emergency withdrawal retains the prior economic ceiling and existing concession ledger, including first-response and successive-change cases that have no rewarded anchor. Native acceptance history survives early exits for missing layout, unresolved own identity or expired prices.

The complete successful local gate output is `/tmp/issue27-all-results.txt`. The baseline reproduction is available from `python3 pdiddler/tests/run_issue27_runtime.py --baseline`; its nonzero exit is expected. Publication must rerun the same gate without the prepublication flag after the immutable manifest is written.

Native client/server acknowledgement can be delayed beyond action initiation. The 0.24-second deadline bounds the controller's one withdrawal attempt and verification waits in the simulated scheduler; it is not a promise of atomic native UI mutation. Reconciliation, realized profit and the separate Common-item behavior remain outside this change.
