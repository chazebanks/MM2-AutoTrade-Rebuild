# Gingerscope — RBLXValue V2 item-feed engineering checkpoint (Nov 14, 2026)

This is a child of draft PR #281, not an update to production main. One distinct System2 problem: the old one-shot RBLXValue workflow only validated /v2/meta, while the Supreme HTTPS recapture returned zero HTTP 200 pages yet the diagnostic GitHub workflow was green. Neither gave S2 actual item-level source candidates.

## New implementation
- pdiddler/system2/rblxvalue_v2_market_import.py retrieves real /v2/meta and every available /v2/items page for Ancient, Godly and Chroma categories, using the existing RBLXVALUE_API_KEY GitHub secret. All requests are sequential and bounded; no credentials, webhook URLs or player information are emitted.
- The importer preserves the provider's item ID, slug, name, weapon type, original source-A/source-B values, decimal blended estimate, demand, stability, and raw unzoned last_updated text. It never silently maps those provider identifiers to exact MM2 game IDs, or infers Chroma Ancient/Godly subtype from a generic provider 'chroma' category.
- Hard-fail checks include incomplete/mismatched pagination, duplicates, nonweapon exclusions, invalid number/demand, malformed source timestamps/metadata, HTTP 401/403/429, rate-bounded total request count and API key absence. Output is all-or-nothing.
- .github/workflows/gingerscope-system2-rblxvalue-live-items.yml runs isolated source-contract tests before performing actual authenticated requests, archives the candidate as a short-lived artifact only on success, and FAILS RED when source collection is blocked instead of reporting an irrelevant green.
- This is not authorization to trade: game raw-key/variant identity, timestamp timezone, independently verified current values, liquidity, partner willingness, offer revisions, actual Discord V2 and final acceptance remain separate integration gates.

## Evidence and next task
Record exact tested Git SHA, workflow run, number of retrieved rows (or precise BLOCKED code) and selected variant coverage. Only once a real snapshot is retrieved may downstream market-to-game item exact mapping be scoped. No repeat ALT gift, old five-window loader, or live public Accept. No user's secret needs to be pasted into chat.

## Verified real GitHub execution
- Research DRAFT PR #282: https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/282, stacked on unmerged #281; production main unchanged.
- Initial real-source run #43635287410: 16/16 isolated tests passed; authenticated provider call returned HTTP 403. Source job FAILED visibly, unlike earlier diagnostic-only green.
- Public /v2/meta without a key also returned 403. Next action tried authenticated /v2/items FIRST and separated endpoint failures.
- Run #43635511637: 17/17 offline tests passed; actual item request returned PROVIDER_ITEMS_ACCESS_DENIED.
- Latest run #43635681731: 19/19 adversarial Python tests passed; authenticated /v2/items returned PROVIDER_ITEMS_API_FORBIDDEN (HTTP 403 with JSON content-type), not a detected gateway challenge. Zero actual item pages, no admitted live market source.
- The existing GitHub secret was present, and format validation passed. This does NOT prove the key is active for item access. Do not blindly rotate, guess network mitigation, or claim a current value feed.
- Next task: distinguish current provider-account/credential access from other independently available current item feeds. No player test, old S2 five-window loader, or automatic Accept.
