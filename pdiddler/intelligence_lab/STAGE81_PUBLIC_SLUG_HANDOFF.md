# Stage 81 — Complete first-party website-slug provenance for the historical 190-item Supreme roster

**2026-11-09.** Issue #122. Research only; no live MM2 inventory, no raw-item→Supreme numeric checker-ID proof, no market-price authorization or trading.

## Why this exists

The source age investigation found the original Stage69 implementation is correct: it computes the earlier of **source retrieval + 24h** and **source publication + 72h**. The live Supreme Ancient, Godly and Chroma pages still show a November 6, 2026, 10:56 AM Eastern publisher update when checked November 9. The strict publisher ceiling is **November 9, 2026, 10:56:07 AM Eastern (15:56:07Z)**. A re-fetch does not reset publisher age. The existing Stage69 original parser and Stage70 trade authority guard already have tests for this, so no source-expiry bypass or duplicate live code change is justified.

The next distinct problem is the *identity namespace*: original `supreme_snapshot_2026_11_06.json` has 190 historical records with **numeric `id` values** (e.g., Gingerscope's historical checker index `771`); the Supreme first-party HTML identifies actual items using **public detail URL slugs**, e.g. `ancients?item=Gingerscope` and `godlies?item=BA2`. The website does **not** authenticate that its public slugs equal old numeric checker indices or Roblox `Weapons.Owned` raw keys. Direct source page retrieval showed slug/name values, not a signed numeric mapping. Stage77 checked four examples. Stage81 checks the *entire* historical roster without claiming more authority.

## Implementation

`pdiddler/intelligence_lab/stage81_pinned_website_slug_coverage.py` is a **pure Python offline report**:

- Requires immutable Git object SHA-1 pins for five original sources: old 190-row snapshot, three November 9 Firecrawl-captured first-party HTML archives, and the fully tested local Stage77 Python HTML parser (reviewed code hash).
- Runs that trusted, hash-pinned parser on inert HTML, not browser JavaScript or arbitrary downloaded code.
- Requires exactly 16 Ancient, 128 Godly and 46 Chroma historical entries and exactly 15 Ancient, 128 Godly and 46 Chroma first-party public item slugs. Nik's Scythe is the one **Priceless** Ancient exception with no ordinary first-party item slug; we do NOT invent one.
- Matches only uniquely corresponding **exact page + casefolded first-party display name**. No fuzzy algorithm, image/asset `ItemID`, alias mapping, caller-supplied numeric checker ID, or tradeable item claim.
- Verifies original first-party publisher clock in all three pinned HTML pages equals `2026-11-06T15:56:07Z`; separately reports the fixed 72h publisher expiry. Even a historically successful source correspondence will report `currentAuthoritativeValueCount=0`, `sourcePublisherFresh=false`.
- Returns only summary counts and trust flags; never produces an account inventory, private raw weapon names, user ID, price, Discord claim or transaction outcome.
- Requires a dedicated Actions run using all five original immutable source blobs; tests include 400 adversarial corrupted bytes, clock rollback / missing timezone, category collisions and all authority flags false.

## What a successful test establishes

A positive result supports **public source identity correspondence only**, e.g. the historical Supreme roster's `("godly","Battleaxe II")` uniquely matches the official Godlies page's `item=BA2`. It does NOT independently establish which MM2 `Weapons.Owned` raw key is that item in a current account, whether the old numeric `checkerId` is authoritative, whether the first-party page is fresh, or whether a trade completed. Source capture through Firecrawl is not an origin-signed response. Git pins only authenticate preserved archive bytes.

This is not a request to rerun Stages73/75/79/80 or the ALT trade; **no user iPad action** for Stage81.

## Future engineering direction (not implemented here)

Replace numeric checker-ID assumptions in the **research-only** market resolver with a reviewed public slug/name/category crosswalk. Current UI could eventually display explicitly historical/unverified reference values without pretending they are tradable; trade approvals remain separately gated. Any future *current client owned raw-key→first-party public slug* evidence must be obtained independently and must reject collisions/mismatched Chroma variants. Never turn on auto final Accept, pricing authority, trade profit or Discord strategy learning merely because website slugs matched historical names.

**PR stays DRAFT/UNMERGED until exact-head all-green CI and independent code review.** Keep Stage70 reviewed raw-to-numeric ID roster EMPTY. Any actual fresh-source publication update must be verified separately and cannot overcome missing game→market identity proof.
