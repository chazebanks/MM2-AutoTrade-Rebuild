# Stage94 — Historical public raw-key → November 9 Supreme publication research join

**Status:** research-only draft; never deploys to MM2/Delta. Follows user-confirmed native Stage93 `CLIENT_P4_GUI_OFFER_MUTATION_OBSERVED` (original Part3→Part4 client offer GUI integration PASSED with 20 Stage9 frames, one alt item add, own offer unchanged, zero scripted offers/Accepts). **No need to repeat Stage89–93**. This stage addresses the separate off-device economic-data integration gap.

## One distinct engineering question

Can the **actual existing Stage82 pinned PUBLIC archive key→Supreme detail-slug candidates (189 unique)** be reconciled exactly with **Stage84's actual new November 9 first-party published numeric values, demand and stability (190 source records)** without trusting historical numeric checker IDs or mixing up Ancient/Godly/Chroma variants?

This is NOT a claim that any user's inventory contains those public keys, that a game server confirmed item ownership, that the first-party website signed its HTML, or that these prices authorize live trades. Both Stage82 and Stage84 are independent historical-public/research-only analyses and their separate provenance limits remain.

## Reused original work, no duplicate pricing parser

- Stage82 original source file `stage82_public_source_slug_resolver.py` Git blob `91362b647a8cc630e4fabcf7aa5d65eb44adb399`, rebuilt using **seven source Git blobs**: 1,040-row October18 third-party public MM2 catalogue, old 190-row Supreme roster, three original old site-page captures, and exact Stage77/81 reviewed source.
- Stage84 original source `stage84_nov9_publisher_refresh.py` Git blob `2a5aba0e339a3a27cd43e20d2a7731ac37c99822`, rebuilt with the **original strict Stage69 parser and manifest reader**, same roster, actual Nov9 3-page captures, original receipt manifest and SHA checks.
- The project Stage94 module `pdiddler/intelligence_lab/stage94_public_source_join.py` accepts only the two original **regenerated** inputs. It validates prior-stage denied authority, immutable publisher/expiry, 189 distinct public slug candidates, the 190-name/page source partition, 1 priceless no-slug item, 10 game-only old-catalogue entries, literal rarity/chroma variant, one-to-one exact page+name+slug. It never uses old numeric `checkerId` as a game item identity.
- A regenerated JSON artifact has 189 **public reference rows only**: public raw archive key, public canonical name and slug, source-published value/demand/stability. **No user inventory, account, owned quantity, Roblox interaction or secrets**. Every row has `historicalPublicCandidateOnly=true`, `priceForTradeVerified=false`. Every result denies trading, final Accept, claimed settlement, profit, Discord and strategy learning.

## Time and expiry

The new source publisher is `2026-11-09T18:58:33Z`; research capture expiry `2026-11-10T22:26:48Z` (Nov10 5:26:48 PM ET), **not renewed by a subsequent download of unchanged page data**. CI uses a fixed Nov9 23:00Z clock solely for reproducible historical validation, independently tests the exact expiry threshold, and evaluates *current time* for the generated research artifact. After the historical expiry the output says `PUBLIC_JOIN_ARCHIVED_SOURCE_EXPIRED`, never `PUBLIC_RESEARCH_JOIN_READY`, without invalidating the archival cross-source match. Do NOT use its values as live P4 valuation.

## Tests and failure modes

Dedicated GitHub Actions fetches and Git-blob-verifies all **15 distinct original inputs**; loads original Stage82 and Stage84 Python logic, reruns their strict checks, tests exact public join, publisher/receipt expiry, 189-row counts, overpriced/priceless categories, Chroma ambiguity, fake reassigned URL/name/rarity, duplicate rows, invalid source price/quantity/demand, forged verified flags, tampered provenance and **400 seeded negative cases**. It also runs inherited repo Luau/Lune/Selene+StyLua/replay/Hypothesis checks at exact PR head.

**No iPad test for Stage94.** Next after CI: review the research-only public catalogue results and the *existing* Stage86 planner/offer guard for compatible evidence labels. DO NOT feed this reference directly to automatic offer selection or final Accept. Current live raw-weapon identity, per-transaction offer ownership, freshness, source quality, strategic decisions and independently authenticated settlement remain open gates; the user's objective remains growing desirable high-liquidity inventory to obtain Gingerscope, not blindly maximizing public listed numbers.

## Native Stage93 archival result

User native report: `status=CLIENT_P4_GUI_OFFER_MUTATION_OBSERVED`, `stage9ObserverBound=true`, `stage9Frames=20`, `theirGuiOfferMutationObserved=true`, `theirGuiOfferAddObserved=true`, `ourGuiOfferStayedUnchanged=true`, `requestTapCount=1`, correct exact partner, all offers/Accepts/Declines/hops zero. No verified item identity/prices/profit/settlement. Recorded in `main/pdiddler/GINGERSCOPE_LATEST_CHECKPOINT.md` and Issue #122.
