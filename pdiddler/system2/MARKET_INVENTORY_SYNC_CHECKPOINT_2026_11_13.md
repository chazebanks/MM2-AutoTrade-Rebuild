# System 2 — market and inventory revision synchronization, first implementation checkpoint

**Date:** 2026-11-13 New York. **Research-only branch** `research/system2-nov13-market-inventory-sync-gate` stacked on draft PR #262, not main. No existing P3/P4/Delta, chat, offer placement, automatic Accept, webhook or learning behavior changed.

## Why we built this instead of restarting System 2
Prior offline research PR #250–#262 already established catalog/source crosswalk, SHA256-pinned 189-row original capture, read-only scanner inventory shadow, attractiveness evidence, trade-replay and synthetic bounded counterparty enumeration. **Still missing:** synchronization between *successive* snapshots. A 60-second timestamp guard alone can reuse an inventory that has already changed, or evaluate a trade after an offer revision/partner/server change.

We need an independent System 2 data layer; S3 chooses trades, S4 learns from observed outcomes, S1 controls actual client actions, S5 orchestrates. Do not inherit original PR106 artificial liquidity scoring, 4-total-copy limit or max-counterparty-overpay as new decisions.

## Actual new publisher observation (research, NOT archived)
- On Nov 13, 2026, Supreme home `https://www.supremevalues.com/` and canonical `https://supremevalues.com/mm2/ancients`, `/mm2/godlies`, `/mm2/chromas` **all visibly displayed** “Values Last Updated — November 13th, 2026 at 1:20 PM”, Eastern Standard Time. UTC `2026-11-13T18:20:00Z`.
- This is a **visible text observation**, not exact authenticated original Stage111 raw HTML capture, historical publication field proof, or current absolute price authorization. Web search/index caches may disagree. Browser-export `publisherVersion:null` and source raw SHA256 remain **research-only**.
- Page observations from user-supplied input are in any case **untrusted**. Consistency of four rendered timestamps cannot promote a private operator market export to a live trusted quote. A newly observed publisher update AFTER stored research capture means **require a new original raw-source archive + independent mapping review**, never restamp previous file.

## Actual work
`pdiddler/system2/market_inventory_revision_gate.py` is a new pure Python two-phase **research** API:
1. `observe(export_bytes, stage83_lua_bytes, client_envelope, trade_binding, publication_pages, evaluated_at_utc)` always calls the original SHA256-locked `ingest`, recomputes independently expected full-189-record SHA256 seal, independently revalidates the original P3 scanner's **complete** read-only own-inventory census, and checks all four exact canonical publication URLs with matching update timestamps and coherent fresh observation times. Includes a synthetic untrusted job/lease/partner/offer-revision binding. It emits only restricted hashes and dates in `RESEARCH_SNAPSHOT_ONLY`, never source raw data or player identifiers.
2. `compare(previous_research_stamp, ...fresh input...)` re-runs the *entire source/census/lease validation*, then **invalidates** the prior decision on a new market watermark (including different-but-older publication), original source SHA/row seal, full inventory census (even excluded/non-eligible inventory keys), job/server, trade lease, partner ID, offer revision or missing/stale trade window. Preserves identical census when ONLY obsolete historical scanner price/total fields change. Never treats +overpay, verbal chat, or Accept as proof of a completed trade.
3. Statuses are `RESEARCH_SNAPSHOT_ONLY`, `UNCHANGED_RESEARCH_ONLY`, `INVALIDATED` or `BLOCKED`. **Even unchanged snapshot returns `researchDecisionReusable=false` for any live trade**; any offline replay flag is clearly labeled and not execution authorization.

## Trusted boundaries
- Original bytes and historical registry are pinned by exact SHA. No new source is admitted merely because its timestamp is later.
- `publication_pages`, `client_envelope`, `trade_binding` and explicit UTC are **caller-supplied synthetic contracts** until a native independent witness can prove they came from Roblox and the real source. They can be forged in a future executor and cannot authorize a live trade.
- Neither an old source file nor a Web crawl may be silently re-stamped as a fresh price publication. The original source's private raw data never enters this public repo.
- All `AUTHORITY_DENIED` flags remain false, including offer, Accept, trading, settlement, profit webhook and strategy-learning permission.

## Testing
- `pdiddler/ci/test_market_inventory_revision_gate.py` adds **34 targeted tests** for 4-page agreement/disagreement, future/expired pages and clocks, missing and adversarial URLs, market source change, inventory **quantity or excluded keys** changes inside 60s, trade revision / partner / job / lease change, closed windows, stale scanner, bad offered identities, frozen source/rows, spoofed source permission, replayed prior stamp, deterministic outputs and legacy old-price non-change.
- Dedicated `.github/workflows/gingerscope-system2-market-sync.yml` executes **all 275 previously source-bound tests + 34 new = 309 expected**, including original frozen Stage83, PR106 and corrected PR182 SHA locks.
- **Do not claim passing until the exact last commit CI run completes**, including original source checks. No native test was executed, and none is authorized by this draft.

## Next distinct task
Run an independently witnessed current market capture through original Stage111→110→104→69 admission with explicit publisher edition/expiry, plus a privacy-safe native scanner/offer revision change witness. Connect this System2 sync interface to S3 research previews only **after** preserving the independent safety controller and proving the real provenance, and keep the old cache as historical research, not a current live quote.
