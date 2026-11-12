# Project Gingerscope — provider contingency after reported account ban
**Date:** 2026-11-12 | **Status:** RESEARCH-ONLY, no production price provider authorized

## Trigger and verification boundary
- User reported "our account got banned" immediately after RBLXValue API testing; context suggests RBLXValue account, but **the provider/account and ban notice have not been independently confirmed**. Prior authenticated `/meta` run #43294791492 **succeeded** before this report. A successful older response does not disprove a later account restriction.
- Stop using RBLXValue credentials/keys for Gingerscope until restriction is clarified; **no alt accounts, borrowed keys, proxies, legacy API, disposable email or other restriction workaround**. RBLXValue ToS explicitly limits keys per person and prohibits alts (https://rblxvalue.com/policy/tos). Official account appeal is https://rblxvalue.com/appeal, but user's no-provider-contact constraint remains; no appeal or contact was initiated.
- The existing `main` workflow is **manual-only**, not scheduled. Do not dispatch again. If needed, separately remove the GitHub secret via the owner's UI. Do not expose or copy the secret.

## Independent alternatives investigated (Nov 12 2026)
| Provider | Direct primary-source evidence | Freshness and coverage | License/provenance | Allowed use **now** |
|---|---|---|---|---|
| MM2 Index | https://mm2index.com/api/values.json ; https://mm2index.com/methodology | JSON `meta.updated=2026-10-12T00:42:14.608268+00:00`, 193 published, 421 withheld; ~31 days stale as of Nov12 | Dataset declares CC BY 4.0; site claims independent trade-post equation solver, not copying Supreme. Trade posts != independently confirmed actual settlements; publisher's resale-business connection disclosed | Historical/attributed **offline research only**. No current comprehensive production prices. |
| FairStash value MCP | https://fairstash.app/mcp ; https://fairstash.app/methodology ; https://fairstash.app/terms | 1,128 MM2 catalogue items, values stated as of Nov11 2026; read-only no-login MCP `https://fairstash.app/api/mcp` | MM2 values sourced from Traderie community list, not independently priced. FairStash allows linking/quoting an individual value but forbids bulk scraping. No independently documented permission for automated replication or full ingestion into P4; upstream Traderie rights also not verified | Individual read-only contextual research under provider terms; **no bulk market-price feed**. |
| FairStash **listing-count CSV** | https://fairstash.app/data | 874 MM2 item labels across 23 daily observation windows; page reports data through Nov11 | Explicit dataset-level **CC BY 4.0** for daily offer-listing counts; provide attribution and license. Only offered/wanted listing frequency, not verified completed trades, actual market value, or exact game raw item IDs. Sample limited to recent Traderie listings, not full market | **Best fresh openly licensed non-price indicator** for offline, attributed demand/supply research. Never convert count into price or confirmed liquidity. |
| BloxUltra | https://bloxultra.com/mm2-values ; https://bloxultra.com/terms | Page claims daily checked 920 MM2 items, 169 changes in 30 days | The site's own ToS says do not scrape, copy or reproduce content without permission. Its independent source/settlement method and documented permissioned machine feed were not verified. Vendor also sells items (possible spread/conflict) | Public human research only. **Do not scrape/ingest**. |
| RobloxTools BloxUltra mirror | https://www.robloxtools.net/values/mm2 | Claims Nov10 mirrored BloxUltra values | Secondary "free with attribution" statement does **not** override BloxUltra's own restrictions or establish transferable source-data rights | **Not an approved substitute**. |
| RBLXValue v1/v2, Supreme-derived scrapers, previously archived prices | https://rblxvalue.com/policy/tos ; https://supremevalues.com/tos | Old /meta success; no new authorized current item feed | Same banned provider or restricted upstream sources | **Do not switch versions/domains to get around restriction.** |

## Research-only architecture direction (no implementation in this change)
1. Separate **value estimates**, **supply/listing observations**, and **verified server-settled trades** as independent evidence types. A refreshed listing series is not a fresh price.
2. For **offline only** historical market calibration, retain existing MM2 Index CC BY dataset with source/publisher clock, version, attribution, item-missing markers and uncertain trade-post interpretation. Reject values beyond the source age policy for live offer decisions.
3. For **offline only** demand/supply studies, test a single immutable FairStash CC BY listing-count CSV with license attribution, dataset capture timestamp, source date, per-day sample window, and anonymized counts. No player identities; distinguish absence vs observed zero. Do not establish trade acceptance likelihood without separate observations.
4. Until a current, sufficiently covered, properly licensed valuation data path is established **and** exact MM2 raw weapon IDs and trade settlement gates are independently cleared, retain `MARKET_BLOCKED`; no auto offer, Accept, profit webhook or learning label. Future autonomous economic decisions are not authorized.
5. Source-of-truth remains the original Stage121 gate plus P1 rights gate. Avoid a parallel false-positive price validator or restoring +15 / forced high opener. Gingerscope remains permanently protected outbound.

## Exact next checkpoint
- Treat the reported account ban as a provider cutoff; don't run another RBLXValue request. If user confirms it was **Roblox/MM2 rather than RBLXValue**, update the scope: game access/ban appeal is a separate issue and none of these API alternatives restores access to MM2.
- Next single issue **if authorized**: build and regress **offline** adapter for a pinned, properly attributed FairStash CSV *listing-count* fixture as a non-price market-pulse input. Test missing days, zero vs unknown, stale collection dates, 4-slot/trade planner isolation, and failures with no source. No current valuation authority.
- Research deeper for an independently licensed **current** item valuation feed; as of this audit none meets price/source/identity/settlement requirements. Do not contact providers unless user changes no-contact instruction.

## Verified sources (as accessed Nov 12)
- RBLXValue bans and one-key-per-person: https://rblxvalue.com/policy/tos
- RBLXValue appeal process: https://rblxvalue.com/appeal
- MM2 Index original data and method: https://mm2index.com/api/values.json ; https://mm2index.com/methodology
- FairStash MCP, source, rights and listing dataset: https://fairstash.app/mcp ; https://fairstash.app/methodology ; https://fairstash.app/terms ; https://fairstash.app/data
- BloxUltra published list and terms: https://bloxultra.com/mm2-values ; https://bloxultra.com/terms
