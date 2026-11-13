# Stage108 — strict historical game-public-name ↔ Supreme source coverage

**Scope:** OFFLINE source corroboration only. No new iPad probe. User's original iPad Stage106 passed a client-only full two-sided `UpdateTrade` candidate↔visible slot match, but every GUI slot was name-only and neither a unique item instance, authenticated trade session, current source quote nor server settlement was proven. Keep all those gates FALSE.

## Trusted source artifacts

1. Exact Stage83 public registry `pdiddler/intelligence_lab/stage83_public_slug_registry.lua` Git blob `40e2a0ff01b70b2d0181c62cae347a08da82bcb8`, 189 public raw game *name-reference* rows, original public publisher `2026-11-06T15:56:07Z`; it is historical and is NOT current server-owned inventory.
2. Unmodified Stage69 first-party Supreme parser `pdiddler/refresh_supreme_snapshot.py`, Git blob `d5843a57f34078cbe7213aa78a4aa12a5775c016`.
3. Three Nov9 original first-party Supreme HTML blobs, Ancients `ce8178ab9579e8782d8f72a6dac051756a728506` (16 weapons), Godlies `d3cf222a8e10cff3a9fb051b16188192389c4b2d` (128), and Chromas `6c77624cac3df96168b008e9bc8eca68a2d78cf9` (46), all parser-returned site publisher `2026-11-09T18:58:33Z`. They are historical source publications, NOT current verified prices.

The dedicated GitHub Actions workflow independently fetches **all five** original git blobs, checks each SHA, executes the actual original parser on the original full HTML, then executes the pure `pdiddler/intelligence_lab/stage108_strict_public_name_coverage.py`. It never calls Roblox, the live Supreme site, a trade remote, webhook, inventory API or a server game endpoint.

## Actual observed name matching (verified original parser)

| Metric | Original evidence result |
|---|---:|
| Public Stage83 registry raw key/name-reference rows | 189 |
| Official Nov9 source weapon rows | 190 |
| Exact name strings within exact category/Chroma variant | 187 |
| Same category/variant, **only capitalization different** | 2 |
| Total exact case-folded public-name matches | **189 / 189** |
| Unresolved registry source names | **0** |
| Official Supreme source weapons outside the 189-name Stage83 registry | **1** (`Nik's Scythe`, Priceless) |

Crucial correction to preliminary superficial HTML scan: an HTML-wide search of `data-name` attributes showed 177 exact-case and 10 seemingly unresolved names, but **that search included source attributes outside the original parser's validated per-weapon `itemcolumn` context**. Independent first-party Stage69 parser plus original source tests proved those 10 were NOT real unresolved canonical weapon names. Two Battleaxe labels differ only by uppercase/lowercase letters. Do not resurrect the earlier false 10-unmatched conclusion.

The newer 2026 game-public reference entries `Emberbow`, `Emberscythe`, `Mortal`, `Immortal` and all four corresponding Chroma variants are present in Stage83 and match exactly the expected first-party Nov9 Supreme source `page/name` combinations. This advances beyond the old v1456 decompiled archive of Stage71, which legitimately lacked 2026 weapons. It is still **public catalogue-source consistency only**, not independent proof of current client or server ownership.

## Defensive properties and regression cases

- Strict one-to-one `(page, source-name.casefold(), Chroma)` relation; Chroma and non-Chroma never collapse; Ancient and Godly pages remain separate.
- Normal case folding is counted distinctly from exact-case identity. **No fuzzy matching, punctuation removal, apostrophe collapsing, alias lookup or numeric Supreme checker IDs**.
- Duplicate raw key or shared site target across different raw keys, repeated source name and malformed source page all FAIL CLOSED.
- All original input bytes pinned: modified catalogue or altered/missing Supreme HTML can never become a positive report.
- Output exposes **only aggregate counts and historical dates**, never per-player raw inventory keys, account identity, unique item instances, item valuation, projected gain, checker ID, request or raw event packet.
- `currentGameCatalogAuthenticated=false`, `rawItemIdConfirmed=false`, `rawKeyToCurrentSiteItemVerified=false`, `numericSupremeCheckerIdVerified=false`, `currentPricesVerified=false`, `priceForTradeVerified=false`, `serverCompletionProven=false`, `authorizesTrade=false`, `authorizesAccept=false`, `mayReportProfit=false`, `maySendDiscordWebhook=false`, `mayUseForStrategyLearning=false`. Stage70's reviewed raw→numeric checker crosswalk remains EMPTY, Stage104/107 original publisher expiry unchanged, and Gingerscope remains protected outbound.

## Tests and dependencies

[Draft PR186](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/186), main-based, independent of stacked Stage70/71/104 drafts. Exact source/provenance workflow: `.github/workflows/gingerscope-stage108-public-name-coverage.yml`. The first test-only source commit `0370ea1565be6db8d19e98ac76a1abbf852df581` correctly failed because the validator did not yet exist; code plus actual parser corrected the naive counting estimate. Real source regression tests include 2026 entries, Nik's Scythe extra source row, Chroma/base negative, punctuation/alias denial, casing-only, duplicate source/registry IDs and source-byte corruption. All six Actions must pass at the **final doc SHA** before claiming complete.

Stage107 sibling [PR185](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/185) independently fixed TWO Stage104 bugs: source roster replacement with unchanged count and omitted `Priceless` source label drift; actual Nov9 original-source RED → 6/6 GREEN, still DRAFT. PR186 does not merge PR185 or enable source refresh.

## Next distinct blocker (NO live trading)

Historical public name parity is now broad but old. Next work must establish **current** original game client `Sync.Weapons` field provenance / category/variant semantics and independently reviewed **current** Supreme publisher source before any read-only *indicative* pricing UI. A current site-public name is not a server-signed item instance and must never be promoted to trade/profit authority. Do not rerun Stage106 or previous GUI probes. A proposed Stage109 should begin with actual source/code and negative regressions; only request a new manual test if it measures a genuinely unobserved fact. Automatic final Accept, Discord completed-trade webhook and strategy learner remain disabled.
