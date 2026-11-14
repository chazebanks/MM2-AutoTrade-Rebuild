# Gingerscope System2 S2.2 — exact market-to-game raw-key crosswalk (Nov 14, 2026)

## One component only — implementation and factual outcome

Operator approved S2.2 immediately after the prior live-market source S2.1 draft. This change reconciles **the validated 190 unique items in the current public MM2 Trade Hub market candidate** to the **immutable, public original Stage83 189 raw-game-key reference registry**. It does not read personal inventory or modify P3/P4/native gameplay, Discord, strategy, public requests, offers, or final Accept.

The original Stage83 registry is *historical*: exact original Git blob `40e2a0ff01b70b2d0181c62cae347a08da82bcb8` at commit `25b48b60fdb2f971bbb6b2a2020f3c7c4432f7ae`. Historical price expiry 2026-11-09 must never be restamped. The current **market quotes** come from the independently refetched Nov 13 source edition; raw-game-key candidates come from the pinned original registry. These are separate sources of evidence.

**Actual result:** 189/189 unique historical raw-game-key candidates mapped to the current 190-row market candidate. Per game rarity: 15 Ancient, 128 Godly, 46 Chroma; the Chroma category includes both Ancient and Godly original game types, determined ONLY from the pinned raw-key registry. An explicit single-source, collision-tested alias matches `FlowerwoodKnife` (client base label `Flowerwood`) with public `Flowerwood Knife` (`flowerwood-knife`); its separate `FlowerwoodGun` remains distinct. The sole extra market record `Niks Scythe` (`niks-scythe`) is not auto-registered as a tradeable Stage83 weapon. No fuzzy or edit-distance item ID guesses.

## Source code and safeguards
- `pdiddler/system2/public_market_gamekey_crosswalk.py`: pinned-source 189-key bijection, source SHA/edition/age checks, exact category/Chroma/type/rank pairing, explicit alias/extra exclusion and duplicate-collision stops, deterministic item-map SHA. Unknown or future keys remain UNPRICED.
- `reconcile_one_client_metadata`: individual original MM2 client `Sync` identity contract for exact raw key + name + ItemType + Rarity + Chroma + trade eligibility; rejects drift, evolution, untradability and changed mapping hash. This is a **pure supplied-metadata validator**, not a claim a fresh live RPC was performed.
- `pdiddler/ci/test_system2_public_market_gamekey_crosswalk.py`: 21 adversarial original-pinned-registry tests, including Chroma Ancient vs Godly, Flowerwood Knife vs Flowerwood Gun, tampered registry blob, forged source authorization, missing/extra/duplicate/renamed items, stale price feed, target protection, and unknown raw key.

**Prior real hardware evidence, reused instead of repeating an iPad test:** `pdiddler/system2/S2_NEXT_KEY_RECONCILIATION_HANDOFF_2026_11_14.md` documents a previous *client-only* six-feature iPad audit: all 189 original Stage83 raw keys matched the then-current game `Database.Sync` metadata with no reported structural, name or Chroma drift. This prior local observation does not certify that *this* newly generated crosswalk was read back on a new device, nor demonstrate true item instance identity or account inventory provenance. No new user iPad test needed for this offline component.

## Actual GitHub test/proof
- [Live crosswalk + source regression run #43639674100](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/43639674100): **21/21 new key-mapping Python tests PASS**, **47/47 inherited market-source + intelligence tests PASS**, original Stage83 exact Git blob SHA verified, fresh 4-page market capture obtained HTTP 200, real source `itemCount=190`, real key mapping `matchedHistoricalGameKeys=189`.
- Artifact `gingerscope-s2-real-market-gamekey-crosswalk` with exact deterministic rows hash `e049219e947bbcee92fc70884f003353d3ad021a7c357423879bd8d46579259d`. Independently checked exact item examples and protection: Gingerscope 16,000/16,000, Flowerwood Knife 230/MM2 and no Supreme, Flowerwood Gun 235/240, Chroma Emberbow 6,000 Ancient, Chroma Darkbringer 60/65 Godly. Exactly one protected target.
- Green CI is evidence of source and historical candidate mapping logic; all crosswalk outputs keep `actualGameIdentityRevalidatedNow=false`, `actualCurrentOwnedInventoryVerified=false`, `mayUseForLiveOffer=false`, `authorizesTrade=false`, `authorizesAccept=false`.
- This PR is stacked on unmerged PR #283 and does NOT merge or change production `main`.

## Correct stop/next step
**STOP until operator says proceed.** The next separate component is runtime integration of the exact mapped prices with **fresh current MAIN inventory and offer revision witnesses**, including 4 physical slots and arbitrary stacked quantities, with zero user private data committed to public GitHub. That fresh native integration is NOT claimed as complete here; keep five-stage combined intelligence device test withdrawn until its dependencies are actually integrated.

No unverified 189-key public market crosswalk may independently authorize trading.
