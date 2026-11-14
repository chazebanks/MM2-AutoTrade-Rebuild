# Gingerscope — Component 1 live market-source acquisition checkpoint

**2026-11-14 15:41 EST.** This branch is scoped ONLY to live item-price source acquisition, not game-key mapping, growth planning, Discord, learning or in-game trading.

## Verified real-source outcome
- Live origin: https://mm2tradehub.com/values and the Ancient/Godly/Chroma category pages.
- GitHub Actions exact working code-and-test SHA: `2e4cdbbd257e1ea8ee875f74ad2b2fae8cbadbe7`.
- Full read-only live collection: https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/43638765841 (success), 22/22 Python positive/adversarial tests and artifact ID `14131302623`.
- Five inherited Luau/Lune/property/style/replay workflows at the same code SHA: all success. No original MM2 gameplay used.
- Site edition published: `2026-11-13` (DATE ONLY; do not pretend source timestamp includes a precise hour or first-party publication evidence).
- Live raw cards: 16 Ancient, 128 Godly, 65 Chroma = 209 display cards. Chroma contains 19 exact duplicated card observations across 46 distinct slugs; importer deduplicates only identical price/name/demand/stability, rejects conflicting duplicates. Unique items: 16 Ancient, 128 Godly, 46 Chroma = 190.
- User-independent artifact inspection of earlier successful 190-row ZIP at run #43638552254: 190 numeric MM2-listed values, 188 numeric Supreme-column values, 2 explicit nonnumeric/missing Supreme values (Niks Scythe Priceless, Flowerwood Knife UNAVAILABLE). Gingerscope: both site columns 16000, demand 5, stability Stable. These are WEBSITE DISPLAYED quotes, not independently first-party verified MM2 settlement.
- All pages fetched with HTTP 200 in actual GitHub Actions; source-page SHA256 hashes and retrieval time are stored in the short-retention JSON artifact. The live ingestion does not need any API key.

## What is solved versus not solved
- DONE: one real working repeatable source fetch from GitHub; bounded remote HTTPS; item card parser; category and expected count checks; strict unknown label failure; one-source-only item handling; exact dedup; Gingerscope present; publication date freshness check; source JSON artifact; no fake green on failed acquisition.
- NOT DONE (separate NEXT component, do not start without user's direction): verify provider-site slugs and categories against exact original MM2 raw game weapon keys and Chroma subtypes, own-game inventory and active trade offer lease. Therefore `rawGameWeaponKey=null`, `chromaSubtypeVerified=false`, `canFeedLiveTrade=false`, and no offer/accept authority.
- NOT DONE: background refresh scheduler or production consumption; research branch uses on-push/manual workflow only. Workflow schedules require default-branch deployment and should be reviewed with final integration.
- NOT CLAIMED: empirical liquidity, actual source first-party parity, Gingerscope tradability, settlement or real learner training. Do not mark those as ready from a website quote.

## Previously failed attempts and fixes (avoid repeating)
- Existing authenticated RBLXValue V2 item endpoint returned HTTP 403 JSON ACCESS_FORBIDDEN under #282. Do not ask operator to rotate another key blindly.
- Original source list lookup fetched 209 displayed cards, but a strict parser initially failed same-origin URL shape; alternate site aliases/relative links were recognized.
- The Godly Flowerwood Knife uses a one-source-only price row; retain its MM2 price and Supreme UNKNOWN, do not invent a missing Supreme price.
- The Chroma page repeats 19 identical item cards; reject conflicting duplicates and preserve real raw-count vs unique-item-count totals.
- Price-label drift now fails rather than silently treating unexpected text as missing. Covered in final 22 offline tests and actual live fetch.

## Exact next work authorization boundary
STOP after completing this source-acquisition checkpoint. Await operator's explicit 'proceed' before beginning Component 2 (exact item mapping / native MM2 inventory evidence). No old five-window Delta test, no new partner trade test, and no production mutation.
