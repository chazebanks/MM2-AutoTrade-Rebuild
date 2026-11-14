# VERIFIED MAIN iPad multi-feature test — CLIENT PASS (Nov 13/14, 2026)

**The operator completed the new native System2 batch** with one manually tapped profile read. Client receipt schema `gingerscope-system2-native-multifeature-v1`, `status=CLIENT_MULTI_FEATURE_REPORT`, `reason=CLIENT_ONLY_NO_SERVER_OR_PUBLISHER_PROOF`. All five observational subfeatures were populated: own census `PASS_CLIENT_ONLY`, metadata `CLIENT_METADATA_COVERAGE_OBSERVED`, variants `CLIENT_VARIANTS_CLASSIFIED`, integrity `PASS_CLIENT_COUNTS_RECONCILED`, session `PASS_LOCAL_SAME_JOB_READ_WINDOW`. The publisher/source subfeature correctly reported `NOT_TESTED_PUBLISHER_AUTHENTICATION_REQUIRED`. The client reports no unmapped/malformed/conflicting raw owned game metadata, reconciled eligible/excluded/unknown buckets, and no Chroma Ancient among owned *game metadata observations*. No script offer, Accept, Decline or teleport occurred; all research-to-trade/profit/Discord/learning and server authentication flags remain FALSE. The single snapshot's local read was within its programmed 15-second bound.

**Privacy boundary:** do not publish real inventory totals, exact owned item identities, user/ALT names, JobId, copied full JSON, trade partner data or account identifiers in this PUBLIC repository. This summary intentionally records the PASS reason and evidence class only. The receipt was pasted by the user; it is **not** cryptographic proof of game server state, price, transferable ownership, current publisher edition, or server settlement. **Hardware milestone CLOSED; DO NOT repeat this multi-feature batch or older two-read census, Stage119 or Stage101.**

**Next distinct task:** Source/market provenance offline. Historical original Stage111→Stage110→Stage104→Stage69 original pinned reader/archiver code has been inspected. Official first-party homepage and three canonical category pages visually agree on the Nov 13, 2026 1:20 PM publication text (site observation only); the private earlier 189-row calculator export has `publisherVersion:null` and no independently proven binding to that site edition. Never restamp or treat it as live-price authority. Keep market-source proof separate from game-side metadata coverage, and batch future hardware questions only if a truly new combined native witness is necessary. No original P3/P4 source changes, automatic Accept, profit or verified learning.

---

# System2 NEXT one-time MAIN iPad test — multi-feature catalog + inventory assessment

**Current draft PR #267:** https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/267, stacked on draft #266 → #265 → prior unmerged System2 research chain. No merge or production P3/P4/Delta changes. This test explicitly **replaces** serial tiny iPad tests with ONE safe operator action delivering multiple feature statuses.

## What is distinct from prior work

The previous real MAIN iPad two-read inventory census returned `CLIENT_TWO_READS_STABLE`; its two-read stability milestone is **CLOSED**. This NEW experiment requests only **ONE** MAIN own-profile read, then immediately checks **five different features at once**:

1. **Census shape:** distinct owned raw key count and total copies, validating nonnegative bounded integers and excluding zero-copy rows.
2. **Current client game metadata coverage:** exact raw-key lookup in the game's `Database.Sync.Weapons` and `Sync.Item`; count unknown IDs, conflicting source entries and malformed metadata separately. Not a new Supreme price source.
3. **Eligibility and variants:** Ancient, Godly, Chroma Ancient, Chroma Godly versus ordinary/excluded, evolution, placeholder and explicit game `Tradable=false`, `CanTrade=false`, `Untradable=true`, `NonTradable=true`. No fuzzy matching.
4. **Copy reconciliation:** independently sum eligible/excluded/unknown key and copy buckets and compare against full owned census. Zero-quantity rows are ignored, stacks counted by copy rather than physical offer slots.
5. **Safe context/freshness:** current original-MM2 JobId and local clock bound within 15 seconds, fail closed on trade UI, missing camera, prior owner, unsafe prompt position, unavailable remote, malformed data, or changed JobId. These checks do not authenticate a server lease.

**Sixth disclosure-only category:** the Supreme publisher/source authentication field remains `NOT_TESTED_PUBLISHER_AUTHENTICATION_REQUIRED`, not a pass. Old 189-source operator export still has `publisherVersion:null`. Actual liquidity, live trade revision, item-instance ownership, offer authority, final Accept, profit and learning stay unverified and unauthorized.

The `features` subobjects contain distinct status strings. A missing `Database.Sync` returns `INCONCLUSIVE_SYNC_UNAVAILABLE` while raw inventory count/integrity can still pass. A current-game metadata match is not server-authenticated item identity nor proof that a copy is transferable. No raw item names, weapon IDs, full player inventory, JobId, trade contacts or private receipts are committed to the public repository.

## Frozen actual implementation

- Pure classifier `pdiddler/system2/native_multifeature_catalog_core.lua` pin **commit `139311e7eb5dc8d155652218ac1acc30e33955c5`**, Git blob `aceec887302772c6d576a1a01d577aed33206a77`.
- User-facing native runner `pdiddler/system2/SYSTEM2_MULTIFEATURE_READONLY_NATIVE.lua` pin **commit `046dfb636326c6f3d261b2cfd883dacaa988e172`**, Git blob `7c9c4a7d9de9db257b21897a83bbc6931af8188a`.
- Runner loads original immutable Stage100 safe geometry at `5b8ee35d7f281c23d9c2181abd97a063e59a0660`, checks closed trade before source loading, never runs P3/P4, never invokes a mutation remote, and allows exactly one human CAPTURE tap.
- `pdiddler/ci/system2_multifeature_native_mocks.luau`: runs actual runner with injected original-MM2 Roblox mocks, plus pure classifier hostiles (Chroma Ancient/Godly, nontradable/evolution/placeholder, sync missing/conflict, counts/stacks, invalid raw key/qty, oversized zero-only profile, stale clock, trade/UI/owner/source failure, no raw data in clipboard).
- Dedicated `.github/workflows/gingerscope-system2-multifeature.yml` SHA-pins both original code blobs and checks their exact checkout bytes. It also validates continuity `verify`/`recover`, no trade remote usage and **311 inherited original Stage83/PR106/PR182 pinned-source Python regressions**.

**Code-head green proof:** commit `07c87f1d24a3d8bbf9922582ddae9027e9b2fea7`, six workflows SUCCESS, focused [#43556269883](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/43556269883) **105/105 actual native Lune assertions PASS** and **311/311 inherited Python tests PASS**. The final documentation HEAD must be checked independently before claiming it is green.

## The SINGLE new MAIN-only iPad test (release only after final CI)

Use a fresh ORIGINAL Murder Mystery 2 job on MAIN iPad Delta. No ALT needed, no trade open and no other pdiddler/auto-trading script running. This is the immutable single command:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/046dfb636326c6f3d261b2cfd883dacaa988e172/pdiddler/system2/SYSTEM2_MULTIFEATURE_READONLY_NATIVE.lua"))()
```

The purple panel should show **MAIN — 1/2 RUN SYSTEM 2 CHECKS** and **RUN 5 CHECKS**. Tap that **once**. The script requests MAIN profile one time, looks up the game's existing `Database.Sync` metadata, validates categories and sums, and shows **2/2 CHECKS COMPLETE — CLIENT ONLY** or **STOPPED/INCONCLUSIVE**. Tap **COPY / CLOSE**, then paste ONLY the sanitized JSON. If the clipboard fails, the script also prints `[S2 MULTI SAFE RESULT]` and sets `getgenv().PDIDDLER_S2_MULTI_LAST_JSON`. Do not paste any raw inventory profile. No trade, ALT, item transfer, final Accept or second diagnostic is required.

If a critical UI, source or RPC failure occurs, stop and send the sanitized status; do not bypass collision checks, replay in the same JobId, or assume a client-only match proves server ownership.

## Next state after operator's actual report

Review every feature independently: if catalog metadata is available, distinguish provisional exact-key eligibility from unknown/malformed/conflicting keys and verify observed category totals; a data gap remains unknown until genuine device evidence. Only then decide whether a **subsequent combined read-only** P3/job/offer-revision witness is necessary. Market publisher authenticity remains a separate offline Stage111→110→104→69 source task, not an approval for live offers or Accept. Preserve closed Stage101, Stage119 and own two-read tests. **No iPad test result yet.**
