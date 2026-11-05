# Issue28 verification

The final pinned eight-check gate passes. Official Luau0.745 compiles the new policy, loader, bootstrap and single Delta entry. All407 safety-predecessor files remain byte-identical, including the complete P4v10 controller; valuation, strict +15, identity/quantity verification, reservation ledger, early policy5 and19 unrelated dependency pins are unchanged.

Production-policy cases:30/30. Whole-production-controller strategy cases:14/14. The unchanged44 immediate-safety and15 economic-controller cases also pass with policy10. Actual successor loader cases:22/22; bootstrap cases:36/36. The full parent gate, its six checks and all prior nested suites pass.

The old policy fails16 of the30 policy contracts (14 passing controls), and its actual-controller run fails6 of14 strategy cases (8 passing controls). The baseline failures reproduce capped initial quotes and the40-value opener against a42-value single reply. Separate review REDs reproduced the uncapped ordinal-demand premium and the451-versus-feasible960 demand cliff. The final real-source1295 case selects960/+335; the restricted actual-owned405 fixture still selects405/+890. Exact100/125/140/130 cases are explicitly synthetic verified fixtures, not Supreme snapshot additions.

All23 published runtime blobs match tested hashes:20 loader dependencies, loader, bootstrap and the unchanged native observation probe. RUNTIME_PINS.json records the immutable chain; PUBLISHED_PINS.json records independent remote hash verification. The final entry uses bootstrap `ae6c94dbcaf85ee6cc0789840a6a6a24ac7aa24d`.

Reproduce with Lua and official Luau0.745:

```sh
LUAU_BIN=/tmp/pdiddler-luau/luau LUAU_COMPILE=/tmp/pdiddler-luau/luau-compile python3 pdiddler/tests/run_issue28_checks.py
```

OFFLINE_RESULTS.txt includes complete output and inherited results. RED_POLICY_BEFORE.txt and RED_RUNTIME_BEFORE.txt show the baseline. REVIEW_DEMAND_CAP_RED.txt and REVIEW_DEMAND_CLIFF_RED.txt show failing review reproductions before correction. No native Roblox/MM2/iPad execution was performed here; no acceptance-rate increase, realized profit, completed inventory gain, successful hop or Discord completion is established. README.md gives the native A/B protocol.

The Supreme snapshot remains fresh at verification time and expires2026-11-05 21:55:32UTC. Expiry still blocks new live work; no timestamp was extended or source data invented. Automatic final Accept/completion/Discord and the separate Common-item classification task remain unchanged.
