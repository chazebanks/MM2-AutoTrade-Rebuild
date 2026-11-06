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

The new `.github/workflows/gingerscope-stage25-market-preflight.yml` executes the existing Python parser against actual live pages in CI and uploads a **review-only JSON/Lua candidate artifact**. It does *not* commit or deploy a new snapshot, change the active pinned loader, or assert new prices were published. If any source fetch or parse fails, the job fails and there is no price authority.

## Delta probe

`new_part4/STAGE25_READONLY_DIAGNOSTIC.lua` reads **only** the replacement preview's existing `rawScanner.getRecord` and `rawScanner.getVerificationState` cache. It does not invoke inventory remotes, click, accept, decline, teleport, or make requests.

The diagnostic checks each currently present player's stable-scan proof for server-job match, player reference, monotonic scan age, fingerprint, verified final state, valid item category/quantity and absence of in-progress retries. It reports **P1/P2 anonymized rows**; no real names, UserIds, job IDs, or webhook tokens are printed. Source freshness and client scan recency are separate fields; neither represents authenticated server proof.

The diagnostic can return `REPLACEMENT_PREVIEW_NOT_RUNNING` because the loader intentionally blocks expired market snapshots. This does **not** justify starting the old V15.8 trading system.

## Tests

- Existing Supreme parser tests expanded with Chroma pets and hidden test rows.
- `pdiddler/intelligence_lab/test_stage25_source_preflight.py`: Python-first source and privacy regressions; executes actual Lua probe tests via subprocess.
- `new_part4/tests/test_stage25_readonly_diagnostic.lua`: 11 synthetic cases for scan recency, missing metadata, player/job mismatches, blacklist inconsistency and no PII.

GitHub Actions runs the full Python and Lua suites plus an **independent networked live-source** preflight. Mock tests are not a controlled native Delta validation.

## Next

If live-source preflight passes, inspect its candidate artifact and exact source-diff before any price-file replacement. Do a **read-only** Delta test of the newly timestamped original scanner and post its anonymized output. Only then consider activating permitted offer placement. Final Accept and verified completed-trade webhook remain disabled, and the old balancer remains excluded.
