# Stage104: Supreme canonical publisher date and stale URL guard (research-only)

## Actual user-supplied native result
Stage103 actual original MM2 iPad/Delta `[GINGERSCOPE STAGE103 ARCHIVED VALUES]` passed: 189 pinned public weapon references loaded; 2/2 manually offered weapons matched NAME-ONLY; original Stage9 observer 124 native frames; 3 local GUI epochs, 1 prior preview revocation, 2 stable research previews, offer mutation not seen during view; on-screen safe panel `onScreenGuideNonOverlappingTrade=true`, no placement failures, zero script offers/requests/Accepts/Declines/hops; protected own Gingerscope not observed. This is **not** live price/weapon raw key/server settlement proof. `finalOwnSlotCount=0`, `finalPartnerSlotCount=0` in report are default unused counters, not evidence of empty offers. Stage103 GUI archived-display objective CLOSED, no retests.

## NEW independent source risk found
First-party [Supreme Home](https://www.supremevalues.com/), [Ancients](https://www.supremevalues.com/mm2/ancients), [Godlies](https://www.supremevalues.com/mm2/godlies), canonical [Chromas](https://www.supremevalues.com/mm2/chromas) currently present **Values Last Updated November 9th, 2026 at 1:58 PM**; same original Stage84 timestamp `2026-11-09T18:58:33Z`. **No verified NEW publisher date as of research on Nov10.** Crucially the alternate legacy `https://www.supremevalues.com/mm2/chromas.php` was observed displaying the **OLDER Nov6 2026 10:56 AM** timestamp. Don't accidentally mix the legacy alias or conflate a fresh HTTP fetch with a new official price publication. Supreme is a fan-made value list; its figures are NOT official MM2 developer-verified prices.

## Stage104 narrow fix
`pdiddler/intelligence_lab/stage104_publication_timestamp_gate.py` is pure Python. It accepts separately acquired raw HTML + HTTP200 source evidence for exactly three canonical URLs (only `/mm2/ancients`, `/mm2/godlies`, `/mm2/chromas` on Supreme HTTPS, no query, fragments or `.php` alias), a reviewed previous Nov9 baseline, and the exact pinned original Stage69 Supreme HTML parser injected by the caller.

It independently reparses all 16 Ancient + 128 Godly + 46 Chroma original source records and embedded `data-updated-iso` timestamps; requires all tiers same published timestamp, same origin host, physically coherent retrieval timestamps, complete identity coverage, consistent rows and no duplicate labels. It reports:

- `NO_NEW_PUBLISHER_PUBLICATION` + unchanged record digest: prior Nov9 source unchanged; **do not extend expiry or rewrite Stage102 archive**.
- `NO_NEW_PUBLISHER_PUBLICATION` + row drift: **REVIEW_REQUIRED** rather than accepting silently edited values under unchanged publication date.
- `NEW_PUBLISHER_CANDIDATE_REVIEW_REQUIRED`: all three show a genuinely later timestamp; row and date changes are **research candidates only** requiring manual source review, no auto-deploy.
- `INCONCLUSIVE`: mismatched dates, legacy Chroma `.php`, mixed hosts, old publisher, missing pages, malformed HTML, URL redirect/HTTP anomaly, invalid time or identity count.

**All output flags false:** publisherRefreshApproved, currentPricesVerified, priceForTradeVerified, rawGameWeaponKeyAuthenticated, numericSupremeCheckerIdVerified, authorizesTrade, authorizesAccept, mayReportProfit, maySendDiscordWebhook, serverCompletionProven, mayUseForStrategyLearning. No Roblox work, no API fetch, no inventory mutation, no trade or loader changes. A future independently acquired newer publication must pass this *and* Stage94 identity diff review before any research archive replacement; never auto-upgrade stale sources to trade authority.

## Tests
GitHub CI pins **four original reviewed Git blobs**: source parser `d5843a57f34078cbe7213aa78a4aa12a5775c016`, original Nov9 HTML ancient `ce8178ab9579e8782d8f72a6dac051756a728506`, godly `d3cf222a8e10cff3a9fb051b16188192389c4b2d`, chroma `6c77624cac3df96168b008e9bc8eca68a2d78cf9`. Executes real parser on all three raw HTML documents plus corrupt and synthetic later/older publication cases and 300 seeded URL/time mutants. Five inherited standard project CI gates must also pass exact HEAD before approval. No native test necessary because Stage104 is offline-only research and existing native GUI/values reader already passed.

User decision preserved: after acquiring Gingerscope protect it from outgoing and keep compounding rest of inventory. Permanent non-overlapping in-game instructions required for all NEW future manual iPad tests; no console-only directions. After Stage104, focus on **actual raw offered-weapon identity binding** and independently measured demand/liquidity/desirability, rather than more generic GUI checks.
