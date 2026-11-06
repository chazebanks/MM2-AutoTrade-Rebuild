# Stage 25 — Source-verified market preflight + read-only Delta scanner diagnostic

**Draft research checkpoint. This does not replace, activate, or authorize a live trader.**

## Existing capabilities reused

- Original Python `pdiddler/refresh_supreme_snapshot.py` parses real Supreme HTML, retains exact canonical checker IDs, checks all three page source timestamps and SHA256 provenance, and imposes `min(retrieval+24h, publication+72h)` expiry.
- Original fixed-snapshot Lua profile and scanner from Stage 24 remain the *only* current production-like sources. No new price registry or scanner was created.
- The replacement loader is still gated and uses the November 4 dated snapshot. A generated candidate is **not** automatically installed.

## Independent current-source finding

The three live Supreme weapon-category pages reported **November 4, 2026, 12:27 PM Eastern** as their publication timestamp at this check. Their HTML includes 16 ancient eligible items, 46 Chroma weapons plus 7 Chroma pets, and 128 visible Godly weapons plus 2 *hidden* Godly test/placeholder rows (`Batwing`, `Black Luger`). The hidden Godly Batwing is **not** the separately indexed Ancient Batwing.

The original parser previously traversed every `itemcolumn`; the extra 9 nonweapon or hidden rows would either create silent coverage mismatch or cause identity confusion. Stage 25 tightens **that existing parser**:

- Exclude the seven **named** Chroma pets only when actually inside the source `section[data-tier="pets"]`. A weapon with the same name outside that section is not silently excluded.
- Exclude the two **named** hidden Godly rows only when their source column is explicitly `display:none`.
- Fail closed on any new hidden/nonweapon source row until reviewed; no automatic newly added weapon ID guesses.
- Require exact visible source totals `ancient=16 / chroma=46 / godly=128` before generating a candidate snapshot.
- Keep the existing SHA256, published timestamp, retrieved timestamp, canonical name/ID, 190-record/189-priced, and fixed-expiry checks.

The new `.github/workflows/gingerscope-stage25-market-preflight.yml` first attempts the existing Python parser against **direct official pages**. GitHub's runner returned HTTP 403. Instead of pretending that attempt succeeded, a separate, clearly labeled source path imports immutable browser-retrieved copies:

- `pdiddler/source_evidence/stage25_supreme_browser_import_manifest.json`: exact official URL, browser receipt ID, observed UTC time, original source publication UTC time and Git blob SHA for each source.
- `pdiddler/stage25_import_source_blobs.py`: retrieves the three immutable Git objects, rechecks their complete Git SHA-1 byte identity, source title and date, fails if observation or publication is stale, and restores the **actual browser retrieval time** as each original HTML file's mtime.
- Original `pdiddler/refresh_supreme_snapshot.py --input-dir`: independently parses these real source bytes with the same old 190-item checked mapping, records SHA256 of the source, and enforces the existing min(retrieval+24h, publication+72h) expiry.
- Existing Lua profile consumer and original expiry boundary are tested in CI against the generated candidate.

This browser-import path **is not a direct GitHub-runner fetch and not a new Supreme publication**. The provenance difference remains labeled. The candidate is uploaded as a **review-only ZIP artifact**; it is not committed to the active snapshot path or loaded into Delta. If either direct source or the immutable browser-import fallback fails, the job fails.

## Source comparison — verified result

GitHub Actions run `42140758571` used the immutable browser-retrieved official Supreme HTML to generate a dated source-checked candidate. It then ran the **actual Lua profile consumer** and the Python `stage25_market_diff.py` comparison.

- All **190/190** canonical item values, demand scores and stability categories **matched** the November 4 baseline: zero changes.
- Official page publication stayed `2026-11-04T17:27:12Z`. The newer `2026-11-06T00:47:22Z` timestamp describes the browser retrieval, **not a new Supreme publication**.
- The review-only candidate expires at `2026-11-07T00:47:22Z`, anchored to retrieval+24 hours and publication+72 hours. It is not automatically installed in Delta.
- Direct GitHub Actions fetch remains HTTP 403. The browser-acquisition fallback is identified separately, checked against immutable Git blobs and SHA256 evidence, and never presented as a direct site fetch.

The comparison report is included with the snapshot in the CI artifact. This is a finite, expiring source record; repeating its import later does NOT refresh its observation time.

## Isolated scanner-only Delta test entrypoint

To test Stage 24 scan timestamps while the ordinary preview still refuses the expired market profile, Stage 25 also has `new_part4/STAGE25_SCANNER_ONLY_BOOT.lua`:

- Loads the **same existing scanner** with the existing dated profile, repricer and GUI. It does **not** load outgoing request rotation, Part 4, hopping, Discord, offer placement or Accept.
- Explicit opt-in is required via `PDIDDLER_ALLOW_SCANNER_ONLY_TEST=true` and it refuses a parallel legacy/replacement session.
- It does **not** treat stale profile values as usable trade prices. `marketFresh=false` is reported truthfully. This test is for scan completion evidence only.
- This is a local test that requires manually selecting the appropriate MM2 device UI. The bootstrap intentionally does not press startup buttons; it only starts the existing scanner on the correct game.
- Scanner inventory reads do occur, and its existing GUI/console may display player names. **Only the Stage25 diagnostic JSON is anonymized**; do not share raw scanner console logs if identities must remain private.
- The existing scanner has persistent listeners and no externally verified teardown. **Rejoin** after the diagnostic; never load a second copy in the same server.
- **One-paste test:** the scanner-only bootstrap loads the existing diagnostic automatically **once** when the initial scanner cache settles, or after its bounded observation window. It prints and optionally copies a single anonymized JSON report. No second script is required. The diagnostic uses no inventory RPCs of its own, and every result has `authorizesTrade=false` and `serverAttestation=false`.

This is a controlled test preparation, not proof of native Delta behavior and not a new trading entrypoint.

## Delta probe

`new_part4/STAGE25_READONLY_DIAGNOSTIC.lua` reads **only** the replacement preview's existing `rawScanner.getRecord` and `rawScanner.getVerificationState` cache. It does not invoke inventory remotes, click, accept, decline, teleport, or make requests.

The diagnostic checks each currently present player's stable-scan proof for server-job match, player reference, monotonic scan age, fingerprint, verified final state, valid item category/quantity and absence of in-progress retries. It reports **P1/P2 anonymized rows**; no real names, UserIds, job IDs, or webhook tokens are printed. Source freshness and client scan recency are separate fields; neither represents authenticated server proof.

The diagnostic can return `SCANNER_CACHE_NOT_RUNNING` if neither the isolated scanner-only session nor the replacement preview is present. This does **not** justify starting the old V15.8 trading system.

## Tests

- Existing Supreme parser tests expanded with Chroma pets and hidden test rows.
- `pdiddler/intelligence_lab/test_stage25_source_preflight.py`: Python-first source and privacy regressions; executes actual Lua probe tests via subprocess.
- `new_part4/tests/test_stage25_readonly_diagnostic.lua`: 11 synthetic cases for scan recency, missing metadata, player/job mismatches, blacklist inconsistency and no PII.

GitHub Actions runs the full Python and Lua suites plus an **independent networked live-source** preflight. Mock tests are not a controlled native Delta validation.

## Next

If live-source preflight passes, inspect its candidate artifact and exact source-diff before any price-file replacement. Do a **read-only** Delta test of the newly timestamped original scanner and post its anonymized output. Only then consider activating permitted offer placement. Final Accept and verified completed-trade webhook remain disabled, and the old balancer remains excluded.
