# Stage84 — New Nov 9, 2026 Supreme published-value source, original bytes and review-only freshness

**2026-11-09. Scope:** one independent current PUBLIC source publication/price timestamp problem after Stage83's native full historical reference coverage. DRAFT research; no live scanner, Part4, accepting, reported settlements, profit or Discord market learner changes.

## Starting point: Stage83 ACTUAL MAIN iPad result

The user provided `[GINGERSCOPE STAGE83 PUBLIC COVERAGE]` native client-only JSON: 183 original `Weapons.Owned` string keys, 457 copies = 182 Knife/Gun keys / 456 copies + 1 legitimate `Misc` entry / 1 copy. Eligible 69 Ancient/Godly weapon types / 76 copies, 4 Chroma copies. **All 69/69 eligible types and 76/76 copies** matched the exact 189-entry HISTORICAL public game key → Supreme URL slug candidate registry, with `historicalUnmappedEligibleKeys/Copies=0`, `historicalVariantDriftEligibleKeys/Copies=0`, no invalid copies/missing metadata. No private item names or raw IDs disclosed. That stage's client reference-coverage question is RESOLVED; do not repeat Stages79/80/83, old ALT trades or bot scans merely for item identity.

## Fresh publisher event discovered independently

On 2026-11-09 late afternoon Eastern, first-party HTML returned from `supremevalues.com/mm2/ancients`, `godlies`, and `chromas` each contained **`data-updated-iso="2026-11-09T13:58:33-05:00"`** (Nov9 1:58:33 PM EST / 18:58:33Z). This is objectively **newer than the prior Nov6 10:56:07 EST** publication and was verified across all three live pages independently, including via a fresh public web retrieval. Site records include Emberbow 650, Harvester 260, Gingerscope 16,000; the published price is NOT automatically trade-authoritative.

Actual Firecrawl `rawHtml` (maxAge=0) source captures were committed intact as Git blobs under `pdiddler/research_source_html/stage84_2026_11_09` with strict manifests. Three original sources:
- Ancient: exact blob `ce8178ab9579e8782d8f72a6dac051756a728506`, 76,908 UTF-8 bytes, acquisition-start `2026-11-09T22:26:48.761Z`.
- Godly: exact blob `d3cf222a8e10cff3a9fb051b16188192389c4b2d`, 329,339 UTF-8 bytes, acquisition-start `2026-11-09T22:26:48.761Z`.
- Chroma: exact blob `6c77624cac3df96168b008e9bc8eca68a2d78cf9`, 159,614 UTF-8 bytes, acquisition-start `2026-11-09T22:26:48.761Z`.

Each manifest entry includes real Firecrawl scrape ID, full official source URL, exact publisher ISO, immutable Git blob SHA and UTF-8 byte length. These are **Firecrawl-acquired third-party intermediary captures**, not an independently cryptographically origin-signed website reply; exact Git hashes authenticate saved bytes only.

## Existing strict parser reused without bypassing source policy

New `pdiddler/intelligence_lab/stage84_nov9_publisher_refresh.py` invokes the **original Stage69 strict HTML parser** at immutably reviewed Git blob `d5843a57f34078cbe7213aa78a4aa12a5775c016` and its **strict source manifest/observation receipt validator** blob `9b6faa9f7a9890d69635542529703fedc8e4d55f`; uses unchanged original old 190-row research roster Git blob `a85af4f6137278540e1fed0c27e7e801553e4111` as the *name/page* map, not an authenticated numeric checker ID. Requires complete source rows: Ancient16, Godly128, Chroma46 (total190), only 1 priceless; every row exact matching name/page; publisher exact 18:58:33Z on all pages; actual receipt not a future timestamp or older than 24h; strict value metadata/display consistency, demand and stability. Publisher age 72h remains independent of retrieval age 24h; effective expiry is the earlier **Nov10 2026 17:26:48 EST** retrieval+24h or **Nov12 2026 13:58:33 EST** publication+72h. Refetching unchanged site pages never changes their publisher timestamp.

The resulting **research-only** JSON reports how many old source values/demands/stability states changed while retaining old numeric checker IDs solely as *historical table row references*. Every row forces `verified=false`, `rawGameMappingVerified=false`, `priceForTradeVerified=false`; all final trading/final Accept, source-origin attestation, verified item mapping, settled-trade/profit/Discord learning permissions false. It is never loaded into P4 or the production scanner. [Dedicated Stage84 GitHub Actions workflow](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/workflows/gingerscope-stage84-nov9-new-publisher.yml) performs original HTML/blob verification, original parser tests, 400 negative source mutations, strict publisher/observation boundary tests, creates a research-only JSON as a **14-day artifact** only (no auto-deploy).

**Do not call Stage84 validated until its actual GitHub Actions focused run passes.** If it fails, correct one source/logic issue at a time; never relax the strict timestamp, name, count, amount or source authority requirements. No iPad action needed; previous Stage83 native item-source coverage already passes. Stage70 server-confirmed completed-trade outcome and current price-for-trade authority remain separate unsolved problems.

## Next question after exact-head CI

If all 190 source items align in a newly published dataset, the old **publication freshness** blocker is resolved **for research reference data only** until its strict earliest expiry. Then independently assess whether Stage82/83 public slug linkage, market liquidity/attractiveness and the trading engine can safely use a research quote without misrepresenting item authority, or whether a different authenticated item proof is necessary. Do not enable auto trading just because a page date changed.
