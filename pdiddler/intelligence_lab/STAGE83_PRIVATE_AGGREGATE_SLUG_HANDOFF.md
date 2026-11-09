## Exact-head Stage83 offline VERIFIED and one native test next — November 9, 2026

**FINAL TESTED CODE SHA:** `61ba55afda3cc9971533ac9638fceb1ded726c5b`. [Dedicated Actions run 42702160213](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42702160213) **SUCCESS**: eight original Git-blob-pinned source inputs downloaded and verified; deterministic public-only 189-entry Lua static registry regenerated and compared byte-for-byte; actual Lua5.4 pure analyzer **14/14 groups + 400 seeded corrupted inputs** PASS; actual native wrapper executed against mocked Roblox services **9/9 groups**, including exactly one no-argument own `GetProfileData` request, no retry, same-client dedup, wrong game, Stage80 session isolation, missing Sync/source/remote, failure, empty data, numeric raw key and anonymized clipboard. Source/pin and policy Python suite **5/5 tests** PASS. The five project-wide Luau/Lune/Selene+StyLua/replay/Hypothesis workflows also PASSED at the exact code head. Corrected a documentation mismatch—registry generated from **eight**, not seven, immutable source files—and updated native helper+registry retrieval PIN to **`67c19a10f4dde23a005206e5b0c261d7e43c82a5`**. The user-facing loader below pins the WRAPPER to the **separately tested code commit** `61ba55af...`. No other live scanner/trading change.

**NEXT ONE MAIN-only new native diagnostic** (justified distinct question, not repeat of Stage79 or 80): On a **fresh original MM2 game lobby with Tablet selected, no existing pdiddler/bot/rotation/trading probes active**, run ONE copy of the following in Delta. It makes **one read-only own-profile `GetProfileData` RPC**, two pinned project-code/public-source fetches, and NO trade, Accept, Decline, Teleport, Discord or prices:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/61ba55afda3cc9971533ac9638fceb1ded726c5b/pdiddler/new_part4/STAGE83_READONLY_PUBLIC_SLUG_COVERAGE.lua"))()
```

Paste **ONE** automatically copied JSON line beginning `[GINGERSCOPE STAGE83 PUBLIC COVERAGE]` or a screenshot of only that aggregate marker if clipboard unavailable. It contains only counts (eligible keys/copies with old public slug match, missing old reference or metadata drift, plus total weapon/Misc counts). Do NOT send weapon names, raw IDs, player IDs, account profiles, offers or trade videos. A timeout or error is a result—**do not immediately rerun it** because an outstanding RemoteFunction cannot be canceled.

**Never overinterpret a positive result**: it is a client-reported correspondence to a historical third-party/website public item mapping, not independently authenticated ownership or fresh market quotes. `currentOwnedRawToMarketSlugVerified=false`, `sourcePublisherFresh=false`, `currentPricesVerified=false` and all trade/Accept/Discord/profit/settlement-learning flags remain FALSE. It does NOT resolve the original Supreme numeric checker mapping or server-authenticated trade completion. PR153 remains **DRAFT/UNMERGED**; historical Supreme publisher date Nov6 expired 72h on Nov9 10:56:07 AM EST. Existing Stage79/80 classification root cause resolved, no retest of those tests.

---

# Stage 83 — Read-only current client coverage of historical Supreme website-slug candidates

**2026-11-09. Scope:** One evidence question from Issue #122. Research-only, draft, no production scanner/Part4/Accept/Discord changes. Keep the old +15 rule superseded.

## What existing evidence does and does not prove

Stage79/80 native MAIN-client reports together proved one client's `Weapons.Owned` originally had **183 string keys / 457 total copies**, including **182 Knife/Gun keys / 456 copies** and **one valid Misc key/copy**. Their category counts include **69 Godly/Ancient keys / 76 copies, 4 Chroma copies**, but intentionally did not publish specific raw keys, names or private inventory. They do NOT prove which of those 69 eligible raw keys appear in Stage82's static public registry.

Stage82 [draft PR152](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/152) passed 10/10 original-source Python tests: an October18 THIRD-PARTY MM2 game catalogue with 200 eligible public raw weapon keys was joined by exact category/name/Chroma to an older 190-record Supreme roster and three Firecrawl-captured first-party website pages; **189 unique public raw key→official `?item=slug` candidates** were found. The 190th old roster entry, priceless Nik's Scythe, has no normal page slug, and 10 catalogue-only eligible public keys lack the old Supreme roster counterpart. All source pages retain publisher Nov6 10:56:07 EST, 72h expired Nov9 10:56:07 EST.

**The one new question:** In a NEW, SAME client session, among locally observable *eligible* `Weapons.Owned` keys, how many can be matched exactly to a **historical public reference**, how many have no old reference, and how many have changed local `ItemName`/`ItemType`/`Rarity`/`Chroma` metadata? These are **aggregate counts**, NOT owned item proofs, trade values or prices.

## Stage83 isolated implementation

- `stage83_export_public_slug_registry.py` deterministically exports a **public-only** `stage83_public_slug_registry.lua` with 189 typed raw/public site slug candidate tuples, no prices, no site numeric checker indexes, no account data. CI reads **eight** immutable Git-blob-pinned originals: October18 1040-entry third-party game data; old 190-row Supreme list; 3 original website HTML snapshots; previously reviewed exact Stage77, Stage81 and Stage82 Python modules. CI re-runs Stage82's strict original source audit, then checks that the regenerated Lua is byte-for-byte identical to the committed static registry.
- `stage83_private_aggregate_coverage.lua` compares original typed `Weapons.Owned` string keys by **exact `rawget`** to the SAME client `Sync.Weapons` metadata and the pinned 189-entry static public reference registry. It classifies owned total, Misc, valid Knife/Gun, eligible Ancient/Godly, Chroma and three **eligible** coverage buckets: historical-reference matched, no historical reference, or existing key but current client type/name/variant drift. It treats `Misc` as nonweapon (Stage80 fix), never silently converts a numeric raw key, never assigns prices, and does not export a raw owned key, weapon name, official URL, account/JobId, inventory fingerprint, trade signal or Discord data.
- `STAGE83_READONLY_PUBLIC_SLUG_COVERAGE.lua` is ONE isolated native MAIN-only diagnostic, not part of the production scanner. It loads the **helper and static public-only registry from the SAME fixed Git SHA**, checks correct MM2 and no other agent session flags, reads a single `GetProfileData:InvokeServer()` of OWN inventory with no arguments, a 4.5-second local deadline and **no retries**, and prints one bounded `[GINGERSCOPE STAGE83 PUBLIC COVERAGE]` aggregate JSON line, automatically copied if Delta exposes a clipboard API. If the remote returns late, a local timeout cannot cancel the in-flight RPC—do not auto rerun it.
- `tests/test_stage83_private_aggregate_coverage.lua`: 14 real Lua5.4 behavioral groups + **400 seeded altered inputs**, including Chroma Ancient vs Godly, original numeric keys, legitimate `Misc`, absent historical source rows, metadata drift, forged price authority, and privacy.
- `tests/test_stage83_native_coverage_mock.lua`: execute ACTUAL native wrapper with mocked Roblox APIs; exactly ONE local read, wrong game, old Stage80 session guard, missing catalogue/source/remote, failed own profile, malformed shape, numeric client key, clipboard fallback and same-session dedup.
- `tests/test_stage83_public_export_and_safety.py`: actual eight-blob source pin verification, exact generated registry, 400 mutated archives, no site numeric IDs, no personal data and only one own profile RemoteFunction call.
- `.github/workflows/gingerscope-stage83-aggregate-coverage.yml`: fail-closed GitHub Actions run that must pass actual downloaded source hashes and Lua/Python tests before native use.

## Permanent non-authority rules

**Even if every client key matches a public page**, that means only client-reported *historical public reference coverage*, not authenticated ownership or current game data, and certainly not a proven server settlement. The local report ALWAYS retains:

`serverAttestation=false`, `authenticatedOwnedInventory=false`, `currentGameCatalogueAuthenticated=false`, `currentOwnedRawToMarketSlugVerified=false`, `numericSupremeCheckerIdVerified=false`, `sourcePublisherFresh=false`, `currentPricesVerified=false`, `authorizesTrade=false`, `authorizesAccept=false`, `mayRecordCompletedTrade=false`, `mayReportProfit=false`, `maySendDiscordWebhook=false`, `mayUseForStrategyLearning=false`, `tradeOutcome=UNKNOWN`.

Static registry's public tuples may be derived from old sources, and the pinned download is not a cryptographic origin signature or live Roblox attestation. A full 189-entry static registry can be misused if someone imports it into P4 as a trading ID; the explicit source-authority flags prohibit that. Full names and raw keys remain on the client; the OUTPUT transmits aggregate numbers ONLY.

## Decision gate and next action

**Do not give the user an iPad loader until exact-head CI passes**. This is one new question, not a request to repeat Stage79, Stage80, Stage66 test trades, Stage73 GUI or Stage75 catalogue check. If CI passes, ask for exactly ONE fresh MAIN iPad/Delta lobby / Tablet / no other scripts read-only test. Require only one `[GINGERSCOPE STAGE83 PUBLIC COVERAGE]` JSON result (never raw IDs/names). Do not repeat on a timeout. PR remains DRAFT/UNMERGED.

If real client result has drift/unmapped keys, isolate the *category* before any broader identity work; avoid automatically promoting historical page URLs into tradeable prices. Publisher freshness is a separate independent blocker that remains unsolved.
