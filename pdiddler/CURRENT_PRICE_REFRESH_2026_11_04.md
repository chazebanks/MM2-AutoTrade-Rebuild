# Genuine Supreme refresh — V15.1

The old snapshot remains expired at 2026-11-04T21:42:28Z. This build does not
extend it. It imports newly retrieved facts from Supreme's November 4 publication
and changes only the selected snapshot, integration identity and old-owner guards.
The corrected Issue #19 negotiation logic is preserved.

## Source and validation

Sources: https://supremevalues.com/mm2/ancients ,
https://supremevalues.com/mm2/chromas , https://supremevalues.com/mm2/godlies .
All three were fetched live with maxAge: 0 and HTTP 200. Each explicitly shows
publication 2026-11-04T12:27:12-05:00 = 17:27:12 UTC.

Observation is conservatively anchored to the known pre-retrieval UTC clock
bound 21:55:32, rather than the later copy/generation time. Fetch evidence and
source SHA256 digests are saved with the structured snapshot; raw HTML is not
redistributed. Existing strict parser checks full source names, categories,
displayed/data values, demand and stability before exact canonical mapping.

- 190 unchanged canonical identities: 16 Ancient, 46 Chroma, 128 Godly.
- 189 numeric prices; Nik's Scythe remains Priceless/unpriced, never zero.
- 25 items changed price/demand/stability; 22 changed numeric price.
- 9 source rows outside the verified mapping remain quarantined and unusable.
- New version: supreme-2026-11-04- 97613e277b36.
- New expiry: **2026-11-05 21:55:32 UTC = 4:55:32 PM EST**.

New expiry follows the existing minimum of 24h observation/72h publication; it
does not restart when the script loads or when a player/server changes. A new
publication was actually retrieved; the old values were not merely re-dated.

## Fresh immutable entry

Disable older Auto Execute entries and join a fresh MM2 JobId. Do not layer this
over active V15/V14 controllers; duplicate-owner checks intentionally refuse that.

```lua
local e=(getgenv and getgenv()) or _G
local u="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/8a970a858c2f06ffa578638b99fa82381565d4ce/pdiddler/pdiddler_V15_1_TELEPORT_AUTOBOOT_v1.lua"
e.PDIDDLER_V15_1_AUTOBOOT_URL=u
loadstring(game:HttpGet(u,true))()
```

Snapshot pin 11537dfd47f8df72aec7aeba9ecaffdfc5c879d4; loader/probe pin
672f1ef4472d78eca55047356edb8b52520295c2. The QA-tested P4 correction remains
54c9ff4b999f67b2a257be10747c32916051bdd4. No moving branch URL or runtime
price switching is used. Values lock to this version within a trade.

Expected: fresh price profile passes the startup price check and shows the new
version. It still holds for genuine loading, unresolved identities, expiry or an
existing owner. A new published snapshot does not prove MM2 gameplay. Final
automatic Accept and Discord remain OFF pending their native evidence.

## Checks and limits

Parser suite: 13 cases; 190 canonical identities / 189 actual repricings; 22 changed
prices; exact freshness boundaries; Priceless rejection and +15 checks pass.
New loader/bootstrap tests pass. Full 37-command preserved V14 regression suite,
actual V15 P4 cases and 294-file preservation pass. The price-scope check proves
the normalized new loader is otherwise byte-identical to the corrected V15 loader.

Historical repricing tests use an explicit as-of test time so old snapshots remain
reproducible; the production snapshot's own isFresh function continues using real
UTC and the fixed expiry. No tests turn that check off in the runtime.

Full outputs: audit-notes/CURRENT_PRICE_REFRESH_RESULTS.txt. Structured changes,
quarantine and retrieval evidence: snapshots/*2026_11_04.json. A legitimate item
catalog may contain a personal goal item; it is not a target/preference in code.

No native iPad/Delta session or real Discord POST was performed. This resolves
the expired-price blocker for this new entry only. Older PR #20 / V15 entries still
point to expired data. Native verification and no-auto-merge requirements remain.
