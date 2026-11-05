# V15.4 — Problem A outgoing reachability

Draft test build. No native iPad execution is claimed. Disable older Pdiddler Auto Execute entries and join a fresh MM2 JobId before switching builds.

## One complete Delta entry

```lua
local e=(getgenv and getgenv()) or _G
local u="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/5d44c0cc5563b988ea3004893f4b53ce0338ea62/pdiddler/pdiddler_V15_4_TELEPORT_AUTOBOOT_v1.lua"
e.PDIDDLER_V15_4_AUTOBOOT_URL=u
loadstring(game:HttpGet(u,true))()
```

Immutable chain:

- Bootstrap: `5d44c0cc5563b988ea3004893f4b53ce0338ea62`.
- Loader: `36c601fcd08a8c9fe7a318b2c52d6f1449b266c9`.
- New scanner/outgoing/feasibility/evidence dependencies: `b411a5eca727649c86f079b22a5368039cc60fc3`.
- Supreme profile remains `11537dfd47f8df72aec7aeba9ecaffdfc5c879d4`.

All19 dependency files plus loader/bootstrap were independently fetched at their immutable refs through GitHub; all21 published blob hashes match the tested local files. See PUBLISHED_PINS.json and RUNTIME_PINS.json. The original shell-network verification was interrupted; no raw-HTTP verification result is claimed.

The25-command top-level offline gate passes, including the full inherited37-command V14 suite. Targeted checks include14 feasibility,27 evidence/input,37 queue/helper,8 scanner API,14 actual loader,30 bootstrap, and6 complete actual outgoing-worker runtime cases. Prior V15 negotiation, current-price, GUI, detector and bootstrap checks pass. All342 predecessor files are byte-identical.

The full production outgoing fixture FAILS on v17 because it physically requests Seer3 and PASSES on v18. The new loader also resolves the old unreachable-player and indefinite-unknown exhaustion failures. RED_BEFORE.txt and OFFLINE_RESULTS.txt retain reproducible output. Independent review's partial-own retry and suppressed-row rendering findings are fixed with failing-before/passing-after tests.

**Price expiry remains November5,2026 at4:55:32PM EST (21:55:32UTC).** This build is not an automatic value refresh. After expiry, new trades remain blocked until genuinely source-refreshed prices are selected by a new immutable build.

**Automatic final native Accept and completed-trade Discord delivery remain OFF.** No realized profit, completed transaction, native server-hop success or acceptance-rate improvement is established by these tests.

See README.md for the exact bounded unknown policy, root cause, trade-offs and required iPad checks. Stop after Problem A; negotiation and the separate Common-item classification issue are unchanged.
