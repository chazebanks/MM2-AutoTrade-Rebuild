# Read-only audit results — native closure still blocked

The final pinned four-check gate passes:34 actual audit-module cases,45 actual-bootstrap cases and the entire inherited insertion release gate, with all its nested suites. Official Luau0.745 compiles the audit module, its embedded bootstrap and the single entry. All455 predecessor files remain byte-identical. The original V15.8 loader,20 dependency pins, queue/ownership logic and two HTTP launches are unchanged.

The original bootstrap passed38 inherited controls and failed the new requirement to emit an audit snapshot before the two existing source launches. BOOTSTRAP_RED.txt preserves that genuine baseline RED. The new module was absent before implementation (MODULE_INITIAL_RED.txt). Further failing regressions caught full child-array iteration beyond a saturated/time-expired/active-owner budget and overlapping gethui/CoreGui roots losing concrete ScreenGui ownership; both were fixed. OVERLAP_RED.txt preserves the latter source failure. OFFLINE_RESULTS.txt contains final output and the complete inherited gate.

Tests assert zero mouse/touch/key/signal input and zero native property mutation across all inspected/guarded cases. They also verify privacy (no TextBox contents/arbitrary console body or untrusted image URLs in the trace), effective visibility, inaccessible/partial roots, finite observed geometry, cached same-job inspection, new-job assessment, bounded expansion and active-owner interruption. The module and bootstrap invocation have static no-input/mutation/network/yield checks. The embedded body is byte-equal to the actual tested module.

All24 published source blobs match tested local hashes:22 unchanged trading/probe files plus the audit bootstrap and its separately readable embedded module source. The new bootstrap makes the same two HTTP source launches as before; the module adds no runtime fetch. RUNTIME_PINS.json and PUBLISHED_PINS.json record immutable references and independent checks.

Reproduce:

```sh
LUAU_BIN=/tmp/pdiddler-luau/luau LUAU_COMPILE=/tmp/pdiddler-luau/luau-compile python3 pdiddler/tests/run_delta_ui_checks.py
```

**This does not verify Delta UI accessibility or automatic closure on iPad.** No native2.743.1136.ipa execution occurred in this workspace, no actual Exit selector/bridge is confirmed, and no automatic hide or successful obstructed incoming-decline trial has been run. The user confirms no Hide GUI setting in that build. Issue32 remains open; the manual bottom-right Exit remains necessary. The updated entry only gathers native evidence and continues unchanged V15.8 startup, without a new trading hold. See README.md for the requested trace and restart instructions.

The pre-existing standalone JobId-only limitation remains documented in the preserved insertion evidence. Supreme expiry is still2026-11-05 21:55:32UTC. Native final Accept, completed-trade Discord and every trade economic safeguard remain unchanged.
