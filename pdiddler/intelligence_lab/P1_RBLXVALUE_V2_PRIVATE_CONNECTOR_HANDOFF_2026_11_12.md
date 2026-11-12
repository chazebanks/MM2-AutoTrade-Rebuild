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


## November 12 post-authenticated-metadata source admissibility audit

**THIS ADDENDUM SUPERSEDES the earlier pre-connection status above.** One credential-bearing metadata request has succeeded. It does **not** remove the separate upstream-source restrictions or authorize item-value ingestion.

### Verified operator-produced result

- Manual GitHub workflow [run #43294791492](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/43294791492), main commit `44268df1e3080b49aa9e586851867fd602a3ce1f`, exactly pins research adapter `0b2ff8983a1ced5199b585dacbff268bcdca76f4` and was **SUCCESS** on Nov 12, 2026; focused preflight **96/96** offline Python tests pass.
- Sanitized positive result: `AUTHENTICATED_AGGREGATOR_METADATA_ONLY`; `datasetItemsReported=1091`; `aggregatorRefreshHours=12`; `aggregatorLastUpdatedUnzoned=2026-11-12 12:02:36`; `aggregatorLastRunUnzoned=2026-11-12 12:02:36`; `knownSupremeDerivedData=true`. Both times are timezone-unverified **aggregator** clocks; they are not independent source publisher revisions.
- Prior [run #43282499790](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/43282499790) failed due to transport formatting; exact research fix `0b2ff898...` corrected nine double-escaped LF usages in real curl config / status parsing, plus false-positive test fixtures. The manual workflow now makes **one** /meta request and no follow-on curl probe. No new API-key rotation is needed.

### November 12 primary-source rules assessment — NO /items request

1. [RBLXValue v2 items](https://docs.rblxvalue.com/v2/endpoints/items) documents `value` as a blended source estimate and `value_source_a`/`value_source_b` as MM2Values/Supreme Values inputs. Slug/id/acronym are **RBLXValue identifiers**, not proof of in-game raw weapon instance identity. Per-item `last_updated` uses an aggregator clock, and no game/server settlement proof is supplied. `/meta` item count is **not count of eligible Ancients/Godlies/Chromas**, much less coverage of an owner's inventory.
2. [RBLXValue Terms November 2026](https://rblxvalue.com/policy/tos) allow controlled API access but explicitly do not claim the third-party valuations as their own property; API key authorization does **not** establish an upstream sublicensing grant, nor prove completed trade values. Developer GitHub MIT license covers **example code**, not the published dataset.
3. [Supreme Values Terms](https://supremevalues.com/tos) prohibit copying value-list data into an application or bot outside narrowly described strictly personal individual uses. Given this project is an automated trading application, do not declare its Supreme-derived prices or blended derivative source permissible for the trading engine without a separately documented appropriate grant. This is a conservative project-use eligibility determination, not a legal judgment about all API users.
4. [MM2Values Terms](https://www.mm2values.com/?p=tos) are separate; no explicit transferable value-list API/dataset license for this project was verified. Cannot silently replace a prohibited Supreme field with MM2Values-derived data and treat access as permission.
5. Independently [MM2 Index public JSON](https://mm2index.com/api/values.json) declares CC BY 4.0 and [methodology](https://mm2index.com/methodology) claims values independent of Supreme/MM2Values. But publisher `meta.updated=2026-10-12T00:42:14.608268+00:00`, only 193 items published / 421 withheld (including sets); **31 days stale** at this Nov 12 checkpoint. Input is *public trade posts* solved as proposed barter equivalences; NOT authenticated in-game completed trades. Its operator discloses a related virtual-item sales business. A website's moving "updated 1 minute ago" banner does not override this specific fixed JSON publication timestamp.
6. Other recent-looking aggregator candidates did not demonstrate both primary dataset reuse scope and independent provenance: BloxUltra is cited second-hand as "free with attribution" by RobloxTools, but its own API terms/feed could not be independently verified in this audit; derivative sources (other Supreme/MM2Values republishers) do not resolve the rights question by having a fresh webpage date.

**Decision:** `P1_CONNECTION_VERIFIED_SOURCE_DATA_NOT_ADMISSIBLE`. No authorized full market-price catalog was established. Do **not** perform `/v2/items` or `/history` automated collection for P4, import current values, treat 12-hour aggregator refresh as source publication time, contact providers against user instruction, or expose API key anywhere. There is **zero** live market/trader/offer/accept/profit/Discord/learning authority from this success. Preserve existing Stage121 and `p1_source_rights_gate.py` refusal; avoid creating a redundant overlapping gate.

**Next independently justifiable P1 work:** research a **primary-source published license** or demonstrably independent, correctly dated, sufficiently covered dataset with verifiable key mapping, without contacting providers; only a separately reviewed decision can authorize any item-level fetch. Independently observe completed trades before claiming retrade liquidity. If none qualifies, document a real external blocker and continue offline synthetic strategy tests—not a disguised source import or metadata-refresh loophole. Current draft PR #236 remains DRAFT and unmerged.
