# Stage49 — Exact raw Sync / own-profile / scanner key correspondence, CLIENT ONLY

## Root-cause source review, not guessed semantics

The actual checked-in current scanner `pdiddler/presentation/pdiddler3_scanner_MODULE_v6_10_CURRENT_PRESENTATION.lua` derives raw catalogue keys from `ReplicatedStorage.Database.Sync.Weapons` (and `Sync.Item` only when a distinct table) in `indexItems` at approximately lines 628–657. It reads **raw current own inventory ownership** from the client-returned `GetProfileData` structure `Weapons.Owned` at approximately 1216–1279. It then invokes `checkerMarket(meta)` and exports `id=tostring(rawId)` plus `checkerId=market and market.id` into the scanner's inventory row. The old `checkerResolve` (approximately 1019–1091) allows hard-coded internal-key mappings, named aliases, and fuzzy normalization/scoring with threshold 200 and tie detection. Its `checkerMarket` returns `source="verified-snapshot-2026-11-01"` even for *heuristically* matched IDs; the publication label does **NOT** attest raw key -> checker ID mapping! This is the specific trust boundary Stage49 addresses.

The genuine Stage43/44 user iPad diagnostics saw a Batwing raw STRING catalogue key in a typed `UpdateTrade` local Player2 Offer triple (quantity 1, category Weapons) and distinct ADD then REMOVE client callbacks, but never proved that raw key was also present in a **same-session fresh own profile**. The real Stage46 `StartTrade(TABLE,STRING)` matched current client table and partner username but no unique session ID. Stage32 Iceblaster transfer was operator-confirmed, not machine-server settlement. Stage47/48 offline Python checker-ID auditor now safely supports one-sided net deltas and pre-owned outgoing copy feasibility, but still relies on checker-ID bucket accuracy. No remote-event naming or GUI proximity alone proves a server transaction.

## ONE Stage49 question

Can a raw weapon key supplied from a later *independently validated same-local-context offer observation* be linked **without type coercion** to the same key in `Sync.Weapons`, the actual client-returned own `Weapons.Owned` dictionary, and the scanner inventory row whose `id=tostring(rawId)`? This is **only structural key/copy-count consistency**, not a claim that the key came from a particular offer, that checker ID is accurate, or that any item was transferred.

### Exact pure Lua boundary

`pdiddler/new_part4/p4_stage49_raw_key_ownership_bridge.lua` is a pure function, no Roblox APIs/remotes/browser, profile RPCs, final Accept, inventory or trade changes, printing or webhooks. It fails closed on all of:
- Missing/unsupported/aliased data shape and metatables
- `Sync.Weapons` and `Sync.Item` alias/collision inconsistencies
- **Numeric vs string raw keys with identical `tostring`** spelling (the native scanner stringifies keys, so it cannot safely distinguish these)
- Missing raw key; absent/insufficient owned copies; malformed quantities; complete profile raw-total mismatch
- Incomplete scanner rows, nonzero `unmapped` or `badQty`, duplicate row identity, sparse/extra indexes, category/page/type/name mismatch, copy-count mismatch
- Illegal Evo/untradable/unknown-tier metadata; Chroma scanner name-prefix mismatch
- Raw IDs supplied as numeric keys. They can match the Profile map privately, but scanner's stringified ID **CANNOT** establish exact raw key provenance and this module rejects their claimed match.

**Only** when the raw key is literally present in Sync, literally present in Owned, has sufficient copies, scanner rawTotal matches full Owned, and the scanner row has exactly the same string key/quantity/known metadata, `rawKeyOwnedClientMatch=true` and `status=CLIENT_RAW_KEY_OWNERSHIP_CORRESPONDENCE_ONLY`. This is an **in-memory client structural relation**, NOT proof of actual event-to-session association or server inventory state. The input `key` may be arbitrary, so `offerKeyOriginVerified=false`. Importantly, **even a fabricated `checkerId` and `valueSource` string never changes `checkerIdentityVerified=false`**. No raw names, item keys, IDs, URLs, user IDs, literal values or hashing in the output. All item-instance, event/session, server completion, trading, Accept and profit/report authority remain **FALSE**.

## Test and deployment scope

Lua test fixtures target 38 specific positive/adversarial cases, including raw-key aliases, numeric/string collisions, own-profile count mismatch, Chroma and scanner mislabeling, arbitrary checkerId, invalid metadata/metatables and catalogue limits. The Python full `unittest` invokes the **actual checked-in Lua tests** via subprocess and runs **500 randomized real Lua cases** with scanner/inventory tampering and privacy/authority assertions. Targeted staged Part4 GitHub CI includes the new Lua test. Source/test branch is draft, **not merged** into production. No native Delta launcher exists at this point and no user item transfer is required merely to verify a pure function.

**Next decision only after exact-head CI:** Assess whether a later read-only, same-account, same-server, no-Accept diagnostic can safely record the raw key from a controlled local offer and a contemporaneous profile read in one stable trade window. This could support **client key ownership correlation**, not exact checker-ID mapping or authenticated trade/session/settlement. Do NOT invent a separate session ID or call a same-name market lookup verified. No auto final Accept, completed-trade journal/profit Discord webhook, bot hopping or old +15/90% economics added. Preserve Gingerscope's demand/liquidity/stability, attractiveness and four physical-copy economics research separately.
