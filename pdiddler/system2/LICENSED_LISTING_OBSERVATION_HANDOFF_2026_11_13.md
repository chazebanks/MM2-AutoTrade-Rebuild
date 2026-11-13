# System 2 — first permitted independent market-evidence component (Nov 13, 2026)

**Scope:** OFFLINE-ONLY research on licensed daily MM2 **posted listing counts**. This is **not** a price feed or an autonomous trading strategy. Do not run in MAIN/Delta, do not wire into Part3/Part4, and do not enable final Accept.

## Why this distinct component exists

System1's same-job supervised client run physically passed on Nov13 (nonce `89caafab-b941-4545-99e5-bbf88113d138`, child PR248 merged into System1 development branch only). It proves the protected *mechanics*, not economic valuation, live item-key identity, actual settlement, market desirability, or price-learning authority.

**P1 price source still BLOCKED.** Existing DRAFT PR236 thoroughly investigated Supreme's [Terms](https://supremevalues.com/tos), direct HTTP Cloudflare 403, RBLXValue upstream rights and account restrictions, and the still-stale October12 [MM2 Index](https://mm2index.com/api/values.json) licensed dataset. Do not repeat Supreme scraping, circumvent challenges, try other accounts/keys or contact providers; user previously instructed no provider outreach. Existing synthetic MarketFeedV1, Stage121 source firewall, PR106/182/Stage120 synthetic planner are unchanged and already cover price-proof boundary. **A site page that was crawled today or a count updated today is not a new authenticated publisher price snapshot.**

## Why FairStash daily supply CSV can be inspected

- First-party dataset rights page: **https://fairstash.app/data**, observed Nov13. Explicit **CC BY 4.0** for its export `https://fairstash.app/data/supply.csv`, including project/commercial uses with proper credit. Attribution: **FairStash (https://fairstash.app), licensed under CC BY 4.0**; license URL https://creativecommons.org/licenses/by/4.0/. Its [Terms](https://fairstash.app/terms) prohibit bulk scraping of its regular value-list pages; this implementation never scrapes and only validates an operator-obtained copy of the explicitly downloadable licensed CSV.
- First-party data page states `game,item,slug,day,selling,buying`; as of Nov13 it reports **874 MM2 labels observed across 23 days** and the current dataset record range through **Nov12, 2026**. These are **website claims inspected manually**, NOT a verified downloaded full CSV body or authenticated provider HTTP receipt. This code's unit tests do not assert 874 weapon IDs or import those counts.
- Rows cover a sample of Traderie's recently updated **posted listings**, not all items or all player trades; daily observation windows may differ. `selling` reflects listed frequency *inside that observed window*, not total in-game supply; `buying` may be missing, and a missing calendar day **is unknown, not zero**. Zero is meaningful only if an explicit observed row says `selling=0`.
- These metrics **cannot prove prices, demand utility, actual fill probability, offer attractiveness, trade completion, real liquidity, item/server raw keys, or causally meaningful day-on-day velocity**. They may ultimately be one cautious feature alongside independently verified live price and actual settlement evidence, not an independent authority.

## What this research module actually does

`pdiddler/system2/licensed_listing_observation.py` provides an offline `audit_csv(raw, evaluated_utc="YYYY-MM-DDTHH:MM:SSZ", source_url=SOURCE, item_slug=None)` function. **No network/request/credential/API key/auto-retry**, no persistence of private inventories, no data extraction from Supreme/MM2Values, no import to any trader.

It verifies exact documented CSV columns, local byte cap and UTF-8, strict count and UTC-date format, unique MM2 item-slug/day, stable slug-to-label identity, missing buying vs observed zero, future dates and research-freshness of last actually observed MM2 day (conservative 2 calendar days, research policy only). The SHA256 of local supplied bytes detects that later local copies differ; **it is not proof of first-party HTTPS origin, publisher signature, grant ownership, or independent game/item identity**.

Optionally returns a one-item **posted-listing evidence** observation: latest-day selling/buying values only if observed, previous *calendar* day values only if actually observed, last-seen day, and explicit unknown gaps. Does **not** manufacture missing zeros, projected numbers, ranking, scores, trade acceptance estimates, values, velocity, prices, or real liquidity. No users, account IDs or chats are collected.

Outputs: `RESEARCH_LISTING_OBSERVATIONS_ONLY` if local CSV is syntactically plausible and last observed MM2 day is within the 2-day research window, `BLOCKED_STALE_LISTING_SAMPLE` for old calendar observations, or `BLOCKED` for malformed/untrusted input. All outputs (including positive research) retain:
`verifiedMarketQuote=false`, `mayFeedStage120AsVerifiedMarket=false`, `mayFeedLiveStrategy=false`, `authorizesOffer=false`, `authorizesAccept=false`, `mayUseForStrategyLearning=false`, `serverCompletionProven=false`, `tradeOutcome=UNKNOWN`.

**Important:** `source_url` is caller text; checking it against the documented canonical URL **does not authenticate HTTP transport**. The whole local CSV may be forged. Do not promote it into a production market source.

## Verified vs unverified

- **Verified from provider public page, Nov13:** CC BY 4.0 export license declaration, row format, observational meaning, missing/zero caveat, end-of-data headline through Nov12. Source URLs above.
- **Verified offline by exact Python source/unit tests:** syntactic validation, fail-closed flags, missing calendar-day treatment, duplicate/collision/date/quantity adversarial cases, source label and transport boundaries.
- **NOT done:** downloading and authenticating a full provider CSV HTTPS response, independently verifying rights holder, matching listing slugs to actual MM2 internal weapon IDs, getting safe current market prices, corroborating actual fulfilled trades or showing measurable bilateral acceptance/retradeability.

## Next distinct dependency

Only after this research-only component is tested, focus on **exact game item identity and a permitted fresh current value publisher** as two separately reviewed gates. They must not be quietly inferred from vendor listing names. Keep the existing System1 integrated PASS closed, original Stage120 synthetic valuation and Stage121 firewall intact, and do not merge this research work to `main` without review.

**Original price rights research remains in DRAFT PR236. This independent non-price signal branch does not depend on that unmerged code and does not declare it complete.**
