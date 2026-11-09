# Stage70 — Prevent source-price freshness from laundering approximate MM2 item identity

## Trigger and observed root cause

The user showed a T4.4 iPad MM2 eligible-inventory scanner where weapon NAME and RARITY are visible but all Supreme price fields show **UNVERIFIED**, with outgoing paused. That is correct with the expired Nov6 Supreme profile, not an empty/fake inventory.

We resolved the independent Stage69 source delivery/parse failure first: direct GitHub Actions `urllib` Supreme request gets **403**; stored three independent Firecrawl first-party public HTML responses with their true acquisition times, original site publication time and exact Git blob checks; ran original Supreme parser and 190-item diff. [Stage69 PR124](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/124) exact head `e36a50f00e1bde816e623205cf01db7b34b591c6`, [Actions 42565721527](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42565721527) **SUCCESS**, 40/40 tests and 21 actual changed price/demand/stability records. Source publisher date **Nov6 2026 15:56:07 UTC**, conservative 72h expiry **Nov9 2026 15:56:07 UTC**. Review-only JSON produced, **no executable Lua snapshot** or live override. The Firecrawl copy is an independently retrieved intermediary snapshot, not a cryptographically signed first-party-origin response.

### The separate mapping failure

The live scanner `pdiddler/presentation/pdiddler3_scanner_MODULE_v6_10_CURRENT_PRESENTATION.lua` resolves to a source checker ID through `checkerResolve()`:
- first: internal-raw-key special cases;
- then: name/type aliases;
- then: fuzzy `checkerCanon` and score/rank (threshold >=200, plus page/type/year hints).

Its `checkerMarket` returns `source="verified-snapshot-2026-11-01"` regardless of resolver confidence. It puts the resulting `checkerId` into the inventory row. The old `pdiddler/new_part4/P4_REPRICE_ONLY.lua` then accepts a row if the checker ID exists in a fresh profile, row page/name matches, and the listed value is finite, **without verifying that the ORIGINAL raw `Weapons.Owned` key really maps to that numeric checker ID**. Hence a price source can be accurate for the wrong item/variant. A fresh snapshot alone cannot fix this.

Native Stage54 mapping counts: **190 eligible**, **164 fuzzy**, **19 alias**, **7 internal**; Stage55 had 73 transformed-only fuzzy matches, 7 level-2. Stage57/58 reviewed ten hard cases and corroborated **public game item display identity** with MM2Wiki/Supreme; **zero authenticated raw-key -> numeric source checker ID links**. Client Stage66 demonstrated exact received-row raw string equality with +1 own raw `Weapons.Owned` key; that does NOT prove a Supreme numeric checker ID.

## Stage70 bounded fix — research-only source + item proof boundary

New `pdiddler/intelligence_lab/stage70_raw_checker_proof_gate.lua` is a pure **Lua5.4** reader. It refuses to treat caller-supplied `checkerId`, `verified`, `marketVerified`, `source`, `proof`, similarity, provisional alias or source-only `r.verified` as *independent proof*.

A private code-reviewed map `REVIEWED_RAW_TO_CHECKER` is **EMPTY** in production source. Only a future *versioned, separately reviewed* hard-coded mapping from a **raw MM2 weapon key to an exact Supreme page/checker ID, type, name and evidence ID** could supply per-item identity evidence. Before a future reviewed entry is used, even a fully fresh 190-row first-party price profile still yields `SOURCE_CURRENT_IDENTITY_UNVERIFIED` with **zero numeric price rows**. Unknown/missing/malformed, duplicate, bad-quantity, unmapped and stale source cases fail closed. The module checks the actual source fixed observation/publisher/expiry epoch and three original page URL/hash forms in addition to `profile.isFresh(os.time())`; it ignores an extra supplied timestamp argument so a client cannot rewind the source clock.

Return schema `gingerscope-stage70-raw-checker-proof-gate-v1`:
- `priceRowsVerified` is **0** with current empty map, `verifiedSubtotal=nil`, `completeValue=nil`; do not render nil as `0`.
- It avoids exposing player raw keys/names in new returned rows.
- Even a future, source-code-reviewed mapping and fresh trusted profile would produce **REVIEW_ONLY** values, with `authorizesTrade=false`, `authorizesAccept=false`, `mayRecordCompletedTrade=false`, `mayRecordRejectedTrade=false`, `mayUseForStrategyLearning=false`, `mayReportProfit=false` and `maySendDiscordWebhook=false`. This is a data-quality gate, **not a settlement engine**.
- This does **not** grant authenticated MM2 game-server item/transaction IDs or guarantee that raw catalogue metadata, source HTML and market prices are tamper-proof. An executor can modify client code; live trading safety still requires distinct validated boot/pins, offer revisions and settlement controls.

## Verification / failure attacks

`pdiddler/tests/test_stage70_raw_checker_proof_gate.py` uses the **actual real Lua5.4** module under scripted inventory and Supreme mock profiles. It exercises missing/stale source URLs, missing/old publisher times, source-hash shape, client-controlled clock attempts, duplicate/spoofed raw IDs, nonweapon category, broken qty, caller-injected proof booleans and bad checker identity.

The positive path is tested ONLY with a TEMPORARY TEST SOURCE FILE that inserts one **synthetic** static reviewed mapping; it cannot be injected through runtime `inv` arguments. Even then outputs never authorize trading/Discord/profit. A 400-seed run permutes invalid rows and `verified` claims; no unreviewed row can acquire a source quote.

CI also runs the exact Stage69 source parser/publisher-age/manifest provenance regressions. **No source fetch, Supabase write, MM2 game action, live scanner integration or user iPad test.**

## What remains before the user's T4.4 scanner can legitimately show verified monetary totals

1. Reconcile raw `Weapons.Owned` keys with a separately reviewed, frozen, versioned per-item identity crosswalk (high-priority alias/fuzzy/Chroma collision cases first), using evidence beyond the same fuzzy resolver and no self-issued `verified` flag.
2. Review the source freshness policy separately. A direct Supreme 403 GitHub runner and a publication after 72h are different problems; repeated scraping alone does not make source publication current. Consider **historical reference values clearly marked as indicative** while keeping current quote/trade eligibility false.
3. Deliberately integrate this guard into the scanner/read-only GUI with tests. Do not silently replace or promote unreviewed fuzzy values or inherit old scanner's misleading `source="verified-snapshot-2026-11-01"` string.
4. Only after independent corroboration of a new source publication and at least selected trusted raw-to-checker associations should quote display be promoted; actual outgoing and final Accept stay behind separate safety gates, and Discord learning remains withheld from test ALT `venossgaming90190`.

**At this stage: no full production fix, no new live repricing, all research PRs remain DRAFT.**
