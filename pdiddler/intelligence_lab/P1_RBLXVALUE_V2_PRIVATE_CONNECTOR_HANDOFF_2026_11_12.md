# Gingerscope P1 — RBLXValue v2 private API connector (Nov 12, 2026)

**Status:** Verified against official provider documents, original source tests, and CI; NO LIVE USER KEY, NO AUTHENTICATED DATA, NO ACTUAL PRIVATE BACKEND, NO PRICE IMPORT. The code is key-ready for a future private one-shot metadata probe, not connected to P4 or Discord. Project user's no-human-contact constraint is respected: the provider's own self-service developer portal is the only account process involved, and no message/contact has been sent.

## Existing P1 work preserved

- Rights gate `pdiddler/ci/p1_source_rights_gate.py` veto remains immutable: external API access is not independently proven upstream data permission, and Supreme/derived sources are not promoted.
- MarketFeedV1 `pdiddler/ci/p1_market_feed_v1.py` continues to enforce synthetic-only price schema, exact proof fields, item coverage, normalized timestamps, and never authorizes a quote or trade.
- Stage121 research source-to-strategy firewall and all P3/P4, auto Accept, source/price files, Supabase, Discord, learning, release flags unchanged.

## New deliverables

1. `pdiddler/ci/p1_rblxvalue_v2_private_adapter.py` (stdlib, private metadata one-shot): URL pinned to `https://api.rblxvalue.com/v2`; only the fixed `/meta` and `/items` paths accepted by private transport; key sent via `X-Api-Key` **header**, never URL. Redirects disabled to prevent key disclosure, TLS standard verify, 8-second timeout, 512KB cap, **zero retries or automatic background work**. A one-shot CLI can call **only** the metadata endpoint if the separate operator switch `--probe-meta` AND private env `P1_PRIVATE_METADATA_PROBE=YES` AND private `RBLXVALUE_API_KEY` are present. No default API call and no `items` network CLI.
2. Source-bound v2 `classify_meta(status, body)`: checks metadata shape, totals, source list, interval, and `last_updated`/last_run; explicitly reports aggregator clock `UNSPECIFIED`, not UTC; identifies Supreme/MM2Values upstream source blend. All source, identity, trade, profit, webhook, learning and P4 price authority remain FALSE.
3. v2 `classify_item_page(status, body)` **offline parser only**: checks documented pagination `total,limit,offset,count,items`, duplicate slug/id, category/year-like variant ambiguity (without asserting raw game keys), non-negative finite integer values and upstream source components, item update timestamp shape, demand. **Returns only aggregate sanitized status, no items or prices.** For unknown timezone, no conversion; items still `RESEARCH_ITEM_PAGE_ONLY` with `sourceDerivedFromSupreme=true`.
4. `pdiddler/ci/test_p1_rblxvalue_v2_private_adapter.py`: offline original adapter and transport tests, plus malformed timestamps, 401/403/429/5xx, page duplicates and counts, secret exfiltration attempts, redirects, keyless and unarmed probes, no-network default CLI, status suppression, source-rights denial and 100 malformed metadata cases.
5. Add tests to existing `.github/workflows/gingerscope-p1-canonical-archive-research.yml` offline workflow; no new credentials, secrets, HTTP source capture, cron or external dependency in CI.

## Official provider evidence

- [v2 Getting Started](https://docs.rblxvalue.com/v2/getting-started) establishes `X-Api-Key`, all data endpoints require one, base `https://api.rblxvalue.com/v2` and no full game raw weapon-key mapping.
- [v2 Items](https://docs.rblxvalue.com/v2/endpoints/items): list page limit **1–100**, offset, total/count; `id, slug, category, value, value_source_a, value_source_b, demand, stability, last_updated`. Upstream values are **MM2Values + Supreme Values**, and some category semantics like `chroma` are not reliable raw game-year identities.
- [v2 Meta](https://docs.rblxvalue.com/v2/endpoints/meta): `last_updated, update_interval_hours, totals, sources, last_run`, but docs example `2026-09-05 05:51:53` has **NO TIMEZONE**; the item doc says `last_updated` is in **UTC+2**. This must NOT become `2026-09-05T05:51:53Z` or authenticated underlying Supreme publisher clock. Provider's recent blog saying `/meta` no key contradicted actual first-party HTTP **401 key required** and its v2 docs; assume key required.
- [v2 rate limits](https://docs.rblxvalue.com/v2/rate-limits): free plan 30 requests/minute and user-interface attribution when returned `credit="Data from rblxvalue.com"`. Probe never retries a 429; no polling setup without account and source-use review.
- [RBLXValue Terms](https://rblxvalue.com/policy/tos): developer keys private, no public/client code exposure, no alt-account evasion of rate quotas, no unauthorized redistribution; service explicitly disclaims owning third-party value IP. **API self-service access is not evidence of upstream commercial sublicensing or use rights for P4's autonomous trade valuation.**

## Usage boundary (for later PRIVATE BACKEND only)

Run from a private Python runtime with a credentials manager, NEVER on Delta, public GitHub Actions, or a client device with exposed source. User must obtain their own free API key from https://rblxvalue.com/developer using their own Roblox account; **do not paste it into ChatGPT, screenshots, console or public repos**. The private backend can inject it as `RBLXVALUE_API_KEY`. The probe is deliberately double-armed; example command *without credential material*:

```sh
P1_PRIVATE_METADATA_PROBE=YES python3 -m pdiddler.ci.p1_rblxvalue_v2_private_adapter --probe-meta
```

This prints only a non-sensitive, **research-only** classification, not prices or usernames. This is not a request to run it on the iPad. If no key is configured it returns `KEY_REQUIRED` without network; without explicit --probe-meta+switch it returns `DISABLED`. **Do not run from CI using a secret or collect full data until upstream rights and real source publication semantics are checked.**

## Remaining blocker and next decision

**The code is now ready for private metadata connectivity but cannot prove live usable market data:** no user API key, no authenticated actual item response, unknown upstream use rights, no source-local publication clock provenance, no exact live raw game weapon keys, and no server-completed liquidity. The user's no-contact constraint means no human permission request will be sent; a publicly documented independent license that expressly covers this use, or defensible self-generated market evidence after independent settlement, is needed. When/if an API key and compatible permissions are privately available, the next single step is ONE authenticated metadata-only probe, inspect timestamp semantics and source attribution, then decide whether item access is justified. Do not build a scheduled raw-price collector or let Stage120/P4 evaluate real items on the current research-only output.

**Discord learning remains a separate, AFTER-ALL-TESTS phase as user directed.** No final Accept, protected Gingerscope outbound, value-loss permission or market-priced live offers were enabled.
