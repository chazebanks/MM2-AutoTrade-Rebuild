# Stage111 — canonical Supreme HTTPS source capture archive (research-only)

## Status and source reality

- **Date:** November 10, 2026.
- Supreme's official [homepage](https://supremevalues.com/), [Ancients](https://supremevalues.com/mm2/ancients), [Godlies](https://supremevalues.com/mm2/godlies), and [Chromas](https://supremevalues.com/mm2/chromas) all still show **November 9, 2026 at 1:58 PM EST** as their latest publisher update. There is **NO independently observed new publication** as of this checkpoint.
- The original Nov9 first-party Supreme captured-source expiry from Stage109 remains **2026-11-10T22:26:48Z**; a fresh HTTP retrieval bearing the OLD publisher version does NOT extend that fixed expiry or make the old public values an authenticated current trade quote.
- Original Stage106 native iPad MAIN+consenting ALT **CLIENT-ONLY** one-callback/two-sided physical slot candidate match was successful; no additional iPad diagnostic is justified for publisher provenance.
- Stage107 [draft PR185](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/185) fixed same-count roster substitutions and nonnumeric `Priceless` label omissions; Stage110 [draft PR188](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/188) verified exact original parser/prior source blobs before admitting any manual source review candidate. Those modules are DRAFT/UNMERGED.
- Stage108 all 189 PUBLIC registry names matched historical Supreme website names; Stage109 public value **illustration** is purely historical and not an executable price strategy, authenticated item ownership, or server result.

## The actual missing operation

Stage110 was a pure admission function: it correctly refused arbitrary parser/prior baseline and treated a newer publisher date as `NEW_PUBLISHER_CANDIDATE_REVIEW_REQUIRED`, but it **did not actually fetch the web source**. Its synthetic `httpStatus=200` and user-supplied HTTPS URL were intentionally NOT independent proof that any real network call occurred.

This Stage111 [DRAFT PR189](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/189), stacked on Stage110, adds a deliberately narrow read-only HTTP collection and evidence-archiving workflow:

- `pdiddler/intelligence_lab/stage111_supreme_readonly_capture.py` fetches ONLY three exact canonical HTTPS URLs: `/mm2/ancients`, `/mm2/godlies`, and `/mm2/chromas`.
- Calls a Python `requests.Session` with certificate validation **requested** (`verify=True`), redirects explicitly disabled (`allow_redirects=False`), 8-second connect/20-second read timeout, no-cache headers and streaming mode. The CLI disables environment-proxy inheritance; sends no user/Roblox/GitHub credentials.
- Rejects any non-200 status, mismatched final URL, wrong MIME type, empty/malformed/too-large response, invalid UTC capture time or interrupted body transfer.
- **Complete-original-response guard:** for uncompressed/identity HTTP bodies, any mismatch between declared `Content-Length` and bytes received fails as `INCONCLUSIVE/CANONICAL_SOURCE_CONTENT_LENGTH_MISMATCH`. For `gzip`/other supported compressed representations, the on-wire compressed Content-Length is NOT compared to `requests.iter_content`'s decompressed body length.
- Stores original response bytes separately as `source_ancient.html`, `source_godly.html`, `source_chroma.html`, plus `source_audit.json` with canonical source URLs, retrieval UTC, original-response SHA256 and byte lengths, parser results, original-source Git blob proof and all denial flags. On partial capture, the manifest reports `INCONCLUSIVE` and retains only bounded pages actually captured.
- Before ANY web call, checks the exact original Stage69 parser Git blob `d5843a57f34078cbe7213aa78a4aa12a5775c016` and three original Stage84 prior-Nov9 HTML blobs `ce8178ab9579e8782d8f72a6dac051756a728506` (Ancient), `d3cf222a8e10cff3a9fb051b16188192389c4b2d` (Godly), `6c77624cac3df96168b008e9bc8eca68a2d78cf9` (Chroma).
- Then calls the independently reviewed Stage110 wrapper, which derives the historical baseline with the genuine verified Stage69 parser and invokes Stage104/107 source-date, same-roster, Priceless-label, URL and three-page integrity checks. A new publisher stamp is merely a **manual review candidate**, never a current-price authority or update to the market file.
- `externalCaptureAuthenticated=false` even on success: the script can report that HTTPS certificate checks were requested by the client, but does not cryptographically attest the publisher's raw bytes or server-signed game/trade event. Tests use injected fake sessions, which are NOT proof of a live TLS request. Source retrieval provenance is captured for independent review, not upgraded to cryptographic server attestation.
- `newResearchDatasetPublished=false`, `newCaptureExpiryUtc=null`, `mayUpdatePriceFiles=false`, `mayUpdateProduction=false`, all trade/Accept/current price/settlement/profit/Discord/learning authority fields FALSE. Nothing writes `values/mm2values.lua` or any pdiddler production Lua source.

## GitHub Actions behavior and activation

Workflow: `.github/workflows/gingerscope-stage111-supreme-source-archive.yml`.

- On PR or branch push: only run the **original pinned source / mocked HTTPS tests**. Real Supreme pages are **NOT requested** by the test job.
- The separate capture job runs only on `workflow_dispatch` or (after an approved merge to the repository default branch) a proposed **once-daily 16:17 UTC** schedule. As of this handoff, PR189 is **DRAFT/UNMERGED**; its scheduled capture is **NOT ACTIVE**. Do not claim that monitoring, automatic source alerts, or periodic research fetching has started.
- Read-only `contents: read` permissions, no `git push`, no research or production price file write, no game account login, no source-site credentials.
- The actual capture job retains HTML and JSON artifacts with `actions/upload-artifact@v4 if: always()` for 14 days, including source refusal or manual-review signals. On unchanged Nov9 publication, exits 0. On same-stamp row drift or claimed newer publisher, exits 3 (review required). On missing/incomplete/untrusted source, exits 2. A failure is a **manual inspection prompt** and NOT permission to trust or automatically publish a new snapshot.
- If GitHub Actions disallows, delays, or fails a schedule/website fetch, that does not imply anything about publisher value changes. Only a full capture and reviewed publication marker can support a version update.

## Test-first execution and verified defects

1. Initial test+workflow-only commit `bda75b1fefe1b50fc7e8ddb9ef017a82d4fa665c` failed the focused job, reporting 0 tests because the new unittest class accidentally overrode `unittest.TestCase.run`. Corrected the test helper to `capture_run` and added a **real command-line invocation** mock instead of accepting a false-zero pass.
2. In that runnable suite, **8/9 tests passed**; the ninth caught a genuine command-line read error: `godlys.html` instead of the actual pinned `godlies.html`. Focused [RED #42835700370](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42835700370). Fixed the CLI and the workflow's self-referential static source scan.
3. With **9/9 tests green** (focused [#42835893340](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42835893340)), added two additional response-completeness tests. Original downloader accepted HTML despite a contradictory uncompressed `Content-Length`; two real test-case failures [RED #42836066181](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42836066181). Fixed that without erroneously rejecting compressed-transfer semantics. Subsequently **11/11 original-source tests and focused CI passed** [#42836179725](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42836179725), including the CLI, redirect, MIME, 403, partial, stream interruption, oversize, tampered parser and historical baseline, old publication, fake future publisher, and artifact-only write checks.
4. After documentation is written, **verify all SIX workflows on the exact final PR commit**, not merely an earlier green source commit. No actual live Supreme source-capture job has been dispatched, and no merged scheduled behavior exists.

## Next useful work

When a genuinely NEW publication appears: review canonical source page completeness, site publisher timestamps, per-item source names/year/category and changed prices with preserved original HTML/SHA evidence before generating a NEW versioned research snapshot. A new public site record is NOT a verified live trade quote, does not by itself provide demand/liquidity execution evidence, and cannot authenticate current owned raw item instances or completed transfer/settlement. Separate ownership and trade result proof is still missing. The original iPad Stage106 client raw-key/GUI match must NOT be repeated merely for web source freshness.

The Gingerscope project remains aimed at portfolio growth and eventually obtaining and permanently protecting Gingerscope on outbound. There is NO mandatory old +15 profit rule, and automatic offers, final Accept, trade/profit Discord webhooks, and market learner remain disabled until separately proven safe.
