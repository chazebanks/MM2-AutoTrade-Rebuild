# Stage72 — Scanner-only T4.4 inventory vs Supreme price-confidence integration

## Purpose

The user's screenshot showed eligible weapons visibly listed in the purple T4.4 scanner, but every item `UNVERIFIED` because the embedded November6 Supreme snapshot expired November7. That implies **the market prices are not verified**, not that the player inventories cannot be scanned.

Stage69 resolved a first-party Supreme data extraction problem (CI direct HTTP 403, independently retrieved and original-time-blobs pinned HTML, 190 canonical names, 21 genuine publisher changes, research-only JSON); Stage70 found a separate false-proof problem in the legacy fuzzy/raw→checker ID repricer; Stage71 wrote and tested a clear read-only display separating these facts. None of these grant verified live prices or automatic trading.

This Stage72 integrates ONLY the **read-only scanner display**, retaining the scanner's existing inventory-reading module and touch-friendly purple/black GUI; no other trading system is loaded.

## Implementation

- `pdiddler/new_part4/STAGE72_SCANNER_CONFIDENCE_ONLY_BOOT.lua`: standalone replacement for the old Stage25 scanner-only bootstrap. Requires original MM2 PlaceId and a nonconflicting executor session (new original lobby, no other pdiddler instance). Module dependencies are **frozen by Git commit**, not mutable branch names:
  - Original immutable Nov6 Supreme profile, fixed expiry: `d9d7970f281f725ff21d1a409495fcc197e3d2dc`
  - Legacy P4 strict module passed ONLY for old scanner API compatibility, not used for displayed values: `daf42166b9a713b69b0a8c93708ff13e86b36283`
  - Original T4.4 scanner source, reads MM2 players and `GetProfileData` as previously: `001d228a407076d3cc411a5a7132b0076ec4c027`
  - Stage70 fail-closed proof gate, Stage71 confidence view and Stage72 adapter all at frozen source commit `cf8c55fff64ae3e702bf8dd01a76fbf44ac66b1a`.
- `pdiddler/presentation/stage72_scanner_confidence_adapter.lua` implements exact old presentation contract: `inventory(inv,profile,strict)`, `row(rec,outgoing,request,profile,strict)`, `summary(white,black,unknown,outgoing,profile)`. The old scanner requires those functions to draw player cards, whitelist counts and request-state text. Stage72 routes each inventory through the **actual Stage70 proof gate + Stage71 read-only confidence view**; it NEVER invokes the passed legacy fuzzy `strict.reprice` or trusts its `item.value`.
- Displays `CLIENT-OBSERVED eligible weapon copies`, weapon names/quantities and a **separate** price reason. Source expired => `Supreme quote: UNVERIFIED (source expired/untrusted)`; fresh but no approved raw→checker ID => `Supreme quote: UNVERIFIED (raw ID not independently reviewed)`. Missing proof or unsafe inventory => clear unavailable/partial status. Verified total displays **UNVERIFIED (not 0)**. No raw weapon key/name fallback if display name missing.
- Outgoing always **PAUSED**, no numeric trading authority, manual Accept remains user's own interaction outside the bot, and all bot Accept, actual trade completion/rejection, Discord learner and realized profit flags FALSE. A request state named `accepted` is explicitly labeled *NOT* a settled MM2 trade outcome.
- This is one scanner, no additional profile fetch for the price proof gate. Source texts fetched from Github pin are code dependencies, not MM2 inventory RPC; real inventory data comes from original scanner's existing `GetProfileData` requests. No local second scanner is started.
- Boot refuses competing session keys and duplicate same-job launches, returning partial status when any pinned source is unavailable. In that case a **fresh MM2 rejoin** is required rather than rerunning broken modules in place.

## Testing and limits

`pdiddler/tests/test_stage72_confidence_scanner_boot.py` runs the **actual Lua5.4** boot and adapter against a FAKE old scanner implementing its three view calls and exported scanner API. The fake contains a deliberate legacy repricer that raises an error if called: it proves the new presentation does not reach it. It tests wrong game, overlapping old Stage25, unavailable module, twice executing same loader, and 200 idempotent starts. Inherited Stage71/70/69 source, trust and identity tests run in the same workflow.

**Critical limitation:** This does NOT emulate the full live Luau/Roblox Instance GUI renderer, input focus, screen size, network jitter or Delta compatibility. Its actual purple GUI placement and runtime integration are not native-verified yet. The original T4.4 engine and original Supreme profile are immutable. Even if the screenshot text looks correct, source freshness and numeric raw-key crosswalk remain unproven, so this test cannot authorize actual trading.

## Next necessary human action only after exact-head CI GREEN

One **MAIN iPad only** test; no ALT, no trading, no manual item transfer:
1. Rejoin a fresh original MM2 game server. Do not run any other pdiddler scripts.
2. Execute ONE immutable SHA-pinned Stage72 loader (provided separately after exact-head CI review). Stage72 opens the original eligibility scanner GUI and rewrites ONLY the read-only display composition.
3. Wait for the usual scanner roster to finish. Send **one screenshot** of the scanner showing whitelist rows and the updated source-vs-inventory labels (or one console error). Do not press Accept, send trades or offer weapons.
4. If UI is blank/unresponsive, stop. The old active script has not been changed; we will compare Stage25/T4.4 working rendering with Stage72 to find the regression rather than patch blindly.

Keep all PRs **DRAFT and stacked**: Stage72→Stage71 PR126→Stage70 PR125→Stage69 PR124→Stage26 PR65. Do not merge or enable trading through this experiment. This does NOT solve the official Supreme 72-hour publisher-age policy or independent exact raw→numeric checker ID mapping; those remain separate research issues after the UI is verified.
