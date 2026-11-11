# P1 source permissions — November 11, 2026 verified research

**Status: BLOCKED — SOURCE USE PERMISSION NOT VERIFIED. Research-only; no new market quotes or trade authority.**

## Why the direct collector is suspended

- The exact original Stage111→110→104→69 collector executed on prior draft PR #236 head `214aff6eb890bedf1f8ab3fc87c8dbc924be12ff`, GitHub Actions run [43122451661](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/43122451661). Original Stage111 returned `INCONCLUSIVE / CANONICAL_SOURCE_HTTP_NOT_200 / pages=0 / exit=2`. A separate headers-only diagnostic returned **HTTP 403**, Cloudflare server and `cf-mitigated: challenge`, exact no-redirect first-party URL. Six Python tests passed and no body was read by the diagnostic.
- Independent research of the **publisher's own current [Terms of Use](https://supremevalues.com/tos)** reveals that the site disallows collecting/copying its value-list data for use in applications, websites or bots, via scraping *or manual entry*, outside strictly personal individual use. The site explicitly invites developers unsure of compliance to contact the operator (@hdmi on Discord or through X). This is a restriction independent of whether an HTTPS client can get a 200 response. Do not build a bypass; obtaining raw body bytes or a historical archive does not grant reuse rights.
- The old canonical Stage84 HTML and source modules remain preserved as **historical evidence**, not a current licensed import. Prior collector results remain blocked; no retroactive claim is made about old data.
- The P1 GitHub Actions workflow is now **metadata-only**, running continuity, the original six diagnostic unit tests, eight source-rights unit tests and a rights-blocked JSON receipt. It performs **no Supreme fetch and no source archive capture**. Workflow PASS means safeguards executed, **NOT P1 source admission**.

## Candidate source directions (not verified authorization)

1. **Supreme Values first-party:** request a written, project-specific license/authorization, an approved data delivery method (documented endpoint, signed export, or permitted archival capture), refresh rate, allowed uses, revocation terms, and provenance for both values and accompanying ratings. The current ToS permits a question via [official terms/contact guidance](https://supremevalues.com/tos). No permission request has been sent.
2. **RBLXValue developer API:** official [v2 docs](https://docs.rblxvalue.com/v2/getting-started), [items](https://docs.rblxvalue.com/v2/endpoints/items), [meta](https://docs.rblxvalue.com/v2/endpoints/meta), [developer portal](https://rblxvalue.com/developer), and [API terms](https://rblxvalue.com/policy/tos) document API-key-based bot/app access, a 12-hour snapshot cycle, names/category/value/demand/stability/history/source columns, and free rate limits. However, its source-specific fields contain **Supreme-derived values**. These docs **do not independently establish a written grant from Supreme for downstream reuse**. Do not equate an aggregator API with Supreme's original first-party raw source or treat aggregated update time as Supreme publisher time. No API key was requested.
3. **MM2 Index** [About/methodology](https://mm2index.com/about): claims a public/free independent dataset calculated from trade-community posts, with some unvalued items and an owner associated with MM2 item sales. These are not independently proven in-game settlements; it also needs an explicit reusable-data license/allowed API before automation. Its scale, methodology and possible conflicts make it supplemental, **not replacement canonical Supreme evidence**.
4. **MM2Values:** separate first-party list has [its own TOS](https://mm2values.com/?p=tos); its values and semantics are *not equivalent* to Supreme. Any use in an application requires its own permissions assessment.

## Minimum standard for a future permitted P1 data pipeline

- Credible written source/provider license explicitly covers **this automated trading project**, ongoing collection, derived features, and appropriate retention; record publisher, scope, date, contact and constraints in reviewed private evidence, without publishing secrets.
- Approved feed/API path + TLS/response evidence + version/publisher clock + three relevant item categories + stable schema and unambiguous variants; for aggregator sources separately record original per-source publication time vs aggregation time, and enforce a distinct provider identity.
- Python regressions for denied permission, revoked/mismatched authorization, partial category, missing/chroma/stacked keys, source expiry, suspicious value shifts, duplicate rows, and no-success-on-failed transport. No guessed item mapping or downloaded public market-price authorization.
- Separate independent proof of actually settled trades/retradability; public trading posts are not accepted as completed fills. Keep Stage121, release readiness, and all live trader authority false until distinct later gates pass.

**No P2, Part3, Part4, Delta, auto offer/Accept, profit webhook or training behavior is authorized here.**
