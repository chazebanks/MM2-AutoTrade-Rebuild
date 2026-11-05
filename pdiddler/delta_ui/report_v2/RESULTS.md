# Reporting repair verification

The actual V1 bootstrap fails7 of the10 new native-report/replay cases while3 safety controls pass. The failure reproduces missing structured evidence when the native encoder throws or HttpService is unavailable, and failure to replay the cached same-server report. These are source-execution tests, not calls to a mocked JSONEncode API alone. BOOTSTRAP_BASELINE_RED.txt preserves the result.

The actual V1 module produces a64-byte GUI name ending in UTF8 byte195 with no continuation, as recorded in UTF8_BASELINE_RED.txt. The V2 module escapes this source byte and preserves distinct literal backslash names. Before implementation, all7 initial formatter contract cases fail because the real module has no formatter. Additional RED tests caught owner-only output exceeding16KiB and a skipped report incorrectly claiming an inspection; both are corrected with their evidence retained.

The final new suites pass12 actual-module formatter cases and10 actual-bootstrap cases. The34 inherited audit-module cases also run against V2; all original45 bootstrap cases and the complete pinned predecessor gate pass. The six-check release gate verifies compilation with official Luau0.745, exact embedded module identity, preserved bootstrap transport, all474 previous files, privacy projection, no-input/no-mutation contracts, stale-cache metadata, both JobId checks, print failure retry, once-per-server behavior, and exact original two-launch ordering. Python independently parses all27 produced payloads as complete printable ASCII JSON with the16KiB cap. Independent source review found no remaining release blocker for this reporting change.

Reproduce from the repository root:

```sh
LUAU_BIN=/tmp/pdiddler-luau/luau LUAU_COMPILE=/tmp/pdiddler-luau/luau-compile python3 pdiddler/tests/run_delta_ui_report_checks.py
```

OFFLINE_RESULTS.txt contains the full run, including all inherited results. RUNTIME_PINS.json binds the new immutable diagnostic entry/bootstrap to their tested blobs and the unchanged trader loader. All24 public GitHub source blobs (22 unchanged runtime/probe files and the two diagnostic sources) match their tested hashes; PUBLISHED_PINS.json records those checks. No iPad native V2 report, actual Exit identity, successful automatic close or obstructed trade request handling has been verified. Issue32 remains open; this is a repair to the evidence collector.
