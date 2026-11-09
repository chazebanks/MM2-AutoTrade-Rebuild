## Exact-head offline verification — SUCCESS on 2026-11-09

**Actual code+docs head `6ec5de775527bfabb927bb42b308810dcab53dc3`** was verified by six exact-commit triggered workflows. Focused [Stage79 GitHub Actions run 42687613075](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42687613075) **SUCCESS:** downloaded scanner and Stage66 source originals with exact Git blob checks; actual Lua5.4 compiler and **15 named pure-analyzer tests +400 deterministic adversarial mutations** passed; actual Stage79 native wrapper executed with mocked Roblox services **8/8** test groups (one-call only, numeric+string collision, wrong game, another owner, missing Sync/remote, failed RPC, malformed profile, clipboard fallback, same-job dedup); **3/3 Python** pinned-source/boundary tests passed. Official Luau, Lune, Selene/StyLua, sanitized event replay and Hypothesis workflows also SUCCESS on the same SHA. This is tested OFFLINE only; it is **NOT** proof the native game will return a particular key type or that its profile is server-attested. Source `getProfileData` wrapper may time out, and an in-flight RemoteFunction is not cancellable. All authorization and market-learning flags remain false.

**NEXT AND ONLY USER DEVICE TEST (now eligible):** On MAIN iPad, fresh original MM2 lobby with Tablet selected, no other pdiddler/controller/scanner probes running, run exactly one SHA-pinned read-only loader:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/6ec5de775527bfabb927bb42b308810dcab53dc3/pdiddler/new_part4/STAGE79_READONLY_OWNED_TYPED_CENSUS.lua"))()
```

Do **not** trade or use ALT. The script reads only own `GetProfileData` once (4.5-second local deadline); it should auto-copy the aggregate `[GINGERSCOPE STAGE79 OWNED TYPE]` JSON, or output one console line if clipboard absent. User pastes **only that ONE aggregate marker line** or shows one screenshot if console/clipboard unavailable. Do not ask for raw owned IDs, names, profile dumps, Roblox usernames, transaction tokens or videos. After the native report, judge what it demonstrates, including unusual legitimate zero/count or key types, and whether a separate source identity issue remains. This remains client consistency only.

**Do not repeat** Stage63/66 manual transfers, Stage73 GUI scans, or Stage75 targeted catalogue test. PR149 stays DRAFT/UNMERGED. Source Nov6 Supreme publication remains stale beyond the active 72h policy; no repricing, outgoing, Accept or Discord learner.

---

# Stage79 — One original `Weapons.Owned` key-type census, no trade

**Date:** November 9, 2026. **Issue:** #122. **Status:** READ-ONLY proposed native diagnostic; production scanner, pricing, P4, Accept, Discord unchanged.

## Finding: existing data cannot answer original key types

- Main scanner `pdiddler/presentation/pdiddler3_scanner_MODULE_v6_10_CURRENT_PRESENTATION.lua` uses the own-inventory `ReplicatedStorage.Remotes.Inventory.GetProfileData:InvokeServer()` read-only RemoteFunction, then `inventoryFromProfile` converts the raw map key with `tostring(rawId)` before obtaining the matching client Sync.Weapons metadata through `Meta["Weapons|"..id]`.
- Stage66 `STAGE66_ROLE_NEUTRAL_PRIVATE_RAW_SNAPSHOTS.lua` **does not retain original typed map keys**: it parses `inv.seen` strings already formed from the earlier `tostring(rawId)..'x'..qty`. Thus the successful privacy-only Stage66 exact callback string ≡ +1 converted Owned key cannot tell whether the original key primitive was a string or number. No prior private raw ID may be recovered or inferred from that redacted report.
- Stage53 showed `Sync.Weapons == Sync.Item` in that observed run; Stage75 catalog 13/13 was separate; Stage77 four public game/market source crosswalks are still historical and unauthenticated. Evidence cannot be combined to invent an owned-key, Supreme numeric checker ID or server-attested transfer.

## One genuinely new native question

What are the *original* Lua key types in the LOCAL MAIN client's raw `Weapons.Owned` map, and do original string keys directly resolve to the SAME-session `Sync.Weapons` module by **exact raw-key lookup** without coercion, fuzzy name, art ItemID or Supreme market checker index? This is meaningful only as **same-client self-reported** evidence, never as game-server signed inventory.

New pure `pdiddler/intelligence_lab/stage79_typed_owned_census.lua` counts string, numeric and other owned keys, coercion collision pairs (`[42]` and `["42"]`), positive copies, direct metadata joins, missing/malformed items and Ancient/Godly/Chroma eligibles. It **never outputs original keys, names, raw item IDs, avatars, accounts, JSON profiles, prices, fingerprints, or destination identifiers**. Input tables are not trusted; questionable quantities and metadata fail closed. Every report explicitly sets full trading/accept/learning/completion/profit/source freshness authority FALSE.

New standalone `pdiddler/new_part4/STAGE79_READONLY_OWNED_TYPED_CENSUS.lua`:
- requires a fresh, isolated original MM2 lobby; checks correct game and existing active agent sessions;
- loads ONLY direct `Sync.Weapons` metadata and pinned pure analyzer at commit `a2da4d53b7ee92b289b9c58a34ac08e7ded6731a` (no production scanner);
- performs exactly ONE bounded `GetProfileData:InvokeServer()` without parameters, with 4.5-second local deadline and no retries; remote timeout does not cancel an already in-flight server call;
- inspects original `Weapons.Owned` table once **before** any `tostring(rawId)` conversion;
- returns **aggregate-only** `[GINGERSCOPE STAGE79 OWNED TYPE]` JSON in clipboard and console, with small optional purple guide; never opens or alters a trade;
- a green local direct-join result means only `CLIENT_TYPED_OWNED_DIRECT_CATALOGUE_MATCH_ONLY`, never authenticated inventory, verified market pricing or trading permit.

## Regression/test requirements

- Original scanner and Stage66 core are downloaded at immutable Git commits and verified bytewise via known Git blobs (`5395de38d88c76d049a51d801f2a01412defb8ee`, `1579a2a70047783e8579f91540ff03037e13ba59`).
- Focused actual Lua5.4 pure-module suite: 15 named groups plus 400 deterministic corrupted inputs, specifically distinguishing numeric and string keys, key collisions, missing types, malformed Chroma, nonfinite/zero quantities, metatables, hidden authorizing fields, overflow and private-name leaks.
- Actual `STAGE79_READONLY_OWNED_TYPED_CENSUS.lua` is executed with mocked Roblox APIs: one and only one own RPC, no remote on wrong game/another owner/missing sync or remote, failed/empty RPC returns inconclusive, clipboard fallback and same-job rerun deduplication.
- Python validates the *actual historical text* and source provenance instead of treating rewritten fixtures as observation.

**Do NOT ask the user to execute until a reviewed exact-head CI PASS.** If it passes, the ONLY native step is a **single, no-trade, own-profile read on the MAIN iPad** with fresh MM2 + Delta; no ALT needed, no manual transfer, no Stage63/66/73/75 reruns. Give the SHA-locked one-line loader and ask for ONE aggregate marker line. If no consent or device access, report offline-only result without claiming a native observation.

**Separate and unresolved:** Nov6 Supreme publisher source date is beyond the 72h freshness policy; matching the client catalogue to Supreme's historical website does not authenticate a numeric checker index. Server settlement remains UNKNOWN. Keep auto final Accept, outgoing offers, profit reports and Discord learning disabled. This PR remains DRAFT/UNMERGED.
