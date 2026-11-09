# Stage72 — show explicitly UNVERIFIED historical Supreme reference values without trading authority

## Why this is the next practical step

The user's T4.4 scanner already recognizes eligible MM2 inventory items and quantities. The November 6 Supreme profile embedded in the legacy scanner expired November 7. After Stage69 first-party Nov6 publication evidence and Stage70 raw-checker audit, simply forcing `verified=true` or extending `expiresAt` would be wrong: source values changed (e.g. Emberbow 400→525), and old `checkerResolve` sometimes passes along fuzzy or aliased IDs as `verified-snapshot-2026-11-01`.

Stage71 independently corroborated six **archived public MM2 raw catalogue item names** against source-name/page/Chroma counterparts in the 190-item Supreme list; [PR128](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/128) exact [CI 42568990007](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42568990007) SUCCESS (6 focused real-source tests with 250 corrupted sources, 21 inherited tests). This is NOT current server authentication and a numeric source checker ID is not a game raw weapon ID. Four 2026 items missing from older game catalogue are unresolved. No active trader may consume these as trusted values.

## Stage72 implementation (research-only draft)

`pdiddler/intelligence_lab/stage72_historical_reference_preview.lua` is a PURE read-only Lua5.4 presentation module. It receives the original scanner-style inventory and a pinned Supreme profile, but **never calls Roblox, remote services, a live valuation API, or a trading action**.

- It validates the snapshot's observed/published/expiry metadata and three original category source/hash shapes, and demands the originally reviewed 190-row source coverage.
- It indexes each published source record on `(page, exact case-sensitive sourceName)` rather than old `checkerId`. Duplicate source names for one category fail closed. No fuzzy matching, market aliasing, Chroma/base collapse or caller-provided `verified` promotion.
- It accepts only well-formed positive integer quantities, Weapons category, Knife/Gun type, distinct raw inventory keys, and an exact public source name. For Chroma, the name must explicitly start with `Chroma `. If the game metadata calls it `Candleflame` while the category is `chroma`, it gets **no reference** instead of silently finding Godly Candleflame.
- A historically matched item can be shown as `Historical Supreme ref: 400 each (UNVERIFIED, NOT FOR TRADING)` alongside the item name. This is a *public reference for manual research*, not verified inventory valuation. The source publication date stays visible, and `sourceExpired=true` when its genuine TTL has elapsed. Outgoing remains blocked.
- **In EVERY return value**, `totalText="UNVERIFIED"`, `portfolioTotal=nil`, `valuedInventoryComplete=false`, `identityMappingVerified=false`, `sourceAuthenticityProven=false`, `sourceCurrentVerified=false`, `numericTradingAuthority=false`, `outgoingPaused=true`, `authorizesTrade=false`, `authorizesAccept=false`, `mayReportProfit=false`, `mayUseForStrategyLearning=false`, `mayRecordCompletedTrade=false`, `mayRecordRejectedTrade=false`, `maySendDiscordWebhook=false`.
- Critical: This stage does **not** modify or replace the live T4.4 scanner. It is a research-only standalone function demonstrating honest label separation. Do not claim screenshot fixed yet.

Actual LUA tests exercise the pinned `pdiddler/snapshots/pdiddler_supreme_snapshot_2026_11_06.lua` with a simulated time after its expiry and name samples Gingerscope, Godly Candleflame, Chroma Candleflame and Emberbow. Emberbow intentionally displays **historical Nov4 400** with a stale/not-for-trading label, NOT Nov6 525 and never a verified current quote. Tests challenge spoofed checker IDs, forged `verified` flags, ambiguous Chroma variants, source collision, missing original category URLs, invalid quantities and future clocks; 300 seeded cases. Full earlier Stage69/70 regression suite runs too.

## Remaining work before native GUI adjustment

1. Verify exact-head Stage72 CI first; don't report passed tests prematurely.
2. Decide whether to add a **separate optional historical-reference panel**, with visibly different typography and no impact on existing Verified/Unverified/Outgoing states; do not inject these rows into the trusted `reprice()` path.
3. Current source freshness policy needs an explicit decision: old 72h publisher TTL may be restrictive, but a recently fetched unchanged web page is not a new publisher update. You may present accurate as-of-date reference values without treating them as tradable current market prices.
4. Eventually build trustworthy current raw game catalogue ↔ verified source-name/variant mappings. A good name bridge is not current server item validation or actual settled trading evidence. The Discord learner remains separate and may not use test ALT `venossgaming90190`.

All related PRs remain DRAFT and stacked, with no automatic trades or Discord learning enabled. No new iPad experiment is required for this offline code.
