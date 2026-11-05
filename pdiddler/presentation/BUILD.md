# V15.5 — Issue24 scanner evidence correction

Draft test build, stacked on PR25. Disable older Pdiddler Auto Execute entries and join a fresh MM2 JobId before switching.

## One complete Delta entry

```lua
local e=(getgenv and getgenv()) or _G
local u="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/cd9e4d71deea1ecf30cf0845d4cd558cd807b397/pdiddler/pdiddler_V15_5_TELEPORT_AUTOBOOT_v1.lua"
e.PDIDDLER_V15_5_AUTOBOOT_URL=u
loadstring(game:HttpGet(u,true))()
```

Immutable chain:

- Bootstrap: `cd9e4d71deea1ecf30cf0845d4cd558cd807b397`.
- Loader: `22521aa80b8cb1a45114ab6a4791065bb7bd56c7`.
- New scanner/view/coordinator: `0230ed1481768e7b8ddfee87e9022f6d27462674`.
- Profile unchanged: `11537dfd47f8df72aec7aeba9ecaffdfc5c879d4`.

All20 immutable dependencies plus loader/bootstrap were independently fetched through GitHub and all22 published blob hashes matched the tested files. See PUBLISHED_PINS.json.

The full pinned8-check successor gate passes, including25 preserved checks and the inherited37-command V14 suite. Targeted cases include14 pure view,34 economics,8 actual scanner GUI/result/start helpers,20 actual successor loader,32 bootstrap and6 complete outgoing-worker runtime tests. All368 predecessor files remain byte-identical. Independent review's rescan redraw and expired-economic-label findings were reproduced and fixed with RED→GREEN tests.

**Snapshot expiry remains November5,2026 at4:55:32PM EST (21:55:32UTC).** This is not a price refresh. After expiry, new trading stays blocked and scanner presentation marks price/economic proof unavailable.

**Final native Accept and completed-trade Discord remain OFF.** The latest audit reports manual Accept/Immortal Claim and +40 at135−95; this build does not add authoritative reconciliation, completion reporting, post-manual-trade recovery or the separate Common-item fix.

Native iPad layout, real row timing and guarded request/hop behavior still need the checks in README.md. Passing simulated runtime tests is not proof of native completion or inventory gains.
