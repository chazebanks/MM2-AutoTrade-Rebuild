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
