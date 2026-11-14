# System2 — NEXT multi-feature MAIN iPad test (historical game-key reconciliation)

**Research-only DRAFT PR #268:** https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/268, stacked on #267. Main and existing P3/P4/Delta scripts unchanged. Prior native MAIN two-census and five-feature classifications are **DONE/CLOSED**; this is a distinct new batch, not a replay.

## Exact scope: six separate outcomes from ONE read-only iPad session

1. Historical public source candidate: original exact 189-entry Stage83 raw-key/variant/title registry (15 Ancient, 128 Godly, 46 Chroma), pinned to original immutable Git commit/blob; inherited publication expiry **2026-11-09**, so **not current market prices**. Malformed/forged/expired-date-restamped source is blocked.
2. Current Roblox `ReplicatedStorage.Database.Sync` **all-189 game-catalog audit**: does a historical raw key still exist? For each exact key, are its type, rarity, Chroma flag, base name and explicit tradeability flags still compatible? Return only aggregate missing/malformed/conflict/structural-change/label-drift/ineligible counts.
3. The MAIN account's **current eligible raw keys against historical key roster**: counts of exact source-key matches, newly eligible raw keys outside the old registry, type/variant drift and label drift. Unknown keys must remain UNPRICED; no fuzzy name matching. Count stacks and copies separately without leaking owned raw weapon names/IDs.
4. **Stack/concentration flags**: number of own eligible duplicated keys, extra copies, keys with >4 copies, maximum stack, and four-*distinct*-slot planning limitation. No claim of actual slot/trade feasibility.
5. **Protected Gingerscope**: original historical target registry includes the Ancient Gun and policy never offers it outbound. Do not expose whether MAIN currently owns it.
6. **Local safe session**: original MM2, no open trade UI, no competing controller, safe purple on-screen position, one bounded manually requested read-only `GetProfileData:InvokeServer()`, no other remotes or action. No server-authenticated trade lease.

ALL outputs in the sanitized JSON are client-only or historical; `currentMarketPriceAuthenticated=false`, `publisherEditionBound=false`, `gameItemInstanceProven=false`, `authorizesTrade=false`, `authorizesOffer=false`, `authorizesAccept=false`, no profit/Discord/learning. Original actual private 189-row calculator export stays PRIVATE and cannot be restamped into current first-party publisher prices.

## Immutable exact sources and offline test

- New `pdiddler/system2/native_key_reconciliation_core.lua`: pure Luau aggregate-only source, immutable commit **`eea9d6f5da3dfac8599e2f3e7b9fe1764d6ba288`**, Git blob **`6d6d5760930c284317b7cee3980b50880ea642fc`**.
- New `pdiddler/system2/SYSTEM2_KEY_RECONCILIATION_READONLY_NATIVE.lua`: MAIN iPad UI, immutable commit **`98e39c8d7e82e1ffbce4c0c15e3532e938f59274`**, blob **`6c23cda8c0189f2d18157dbd372593a67621893a`**. This frozen runner loads the pinned pure core, original historical Stage83 and original reviewed Stage100 safe geometry.
- Original `pdiddler/intelligence_lab/stage83_public_slug_registry.lua`: **`25b48b60fdb2f971bbb6b2a2020f3c7c4432f7ae`**, exact blob **`40e2a0ff01b70b2d0181c62cae347a08da82bcb8`**. Historical 189 raw keys, no value columns, **expired**, not a newer market publication.
- `pdiddler/ci/system2_native_key_reconciliation_mocks.luau` runs REAL GUI/remote runner under Lune plus direct classifier adversarial cases (all 189 original rows, exact/missing/outside, label/rarity/Chroma drift, user-untradable, target protection, high copy stacks, zero entries, 4k cap, source forgery/date restamp, game trade window and overlay conflicts, readonly single RPC, no secret leakage).
- Dedicated `.github/workflows/gingerscope-system2-key-reconciliation.yml` SHA-pins the core, runner and the original Stage83 Git blob; replays actual native Lune and inherited 311 original Stage83/PR106/PR182-locked research Python tests + continuity verify/recover + no mutation RPC audit.
- **Initial code head:** `30da07ade91ef0d61a99e2f4661aedf4b8222f82`: focused workflow [#43557706404](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/43557706404) PASS **121 real Lune assertions** and **311 inherited Python tests**, no skips; general GitHub workflows must be checked at final docs HEAD, not just this code head.

## ONE authorized operator hardware test — ONLY after exact final head green CI

MAIN iPad Delta, original MM2, fresh job, no active trading script or open trade. No ALT, item transfer, incoming trade, or Gingerscope ownership disclosure required. Copy/paste this **frozen** command:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/98e39c8d7e82e1ffbce4c0c15e3532e938f59274/pdiddler/system2/SYSTEM2_KEY_RECONCILIATION_READONLY_NATIVE.lua"))()
```

When the **purple/black safe on-screen panel** appears, tap **RUN 6 NEW CHECKS** exactly ONCE. The six client-only tests complete using a single MAIN own profile read, original historical public market key registry and current local game Sync metadata. Then tap **COPY / CLOSE** and paste only the sanitized JSON into ChatGPT.

If clipboard isn't available: copy the sanitized console line `[S2 KEY AUDIT SAFE RESULT]` or `getgenv().PDIDDLER_S2_KEY_AUDIT_LAST_JSON`. Do **not** paste raw profile JSON or public-private account identifiers. On failure/timeout/unsafe overlay, share the status rather than bypass protections or rerun in the same JobId.

**What next:** inspect individual six feature statuses, not just overall success; investigate real current-game source drift or owned unpriced additions before authorizing any future strategy data feed. Publisher-current-edition authentication remains a separately needed fresh first-party source task. No final Accept authorization or production change. **No native hardware result for this new batch until the user sends it.**
