# Supreme Values MM2 weapon census verification — 2026-11-16

**Scope:** operator asked whether the System 2 Supreme-only catalog contains the correct number of Ancient, Godly and Chroma weapons. Independent recheck performed against the actual current publisher pages, not the snapshot's self-reported counts. The publisher declares **Values Last Updated November 15, 2026 11:59 AM EST** on all three pages.

Sources: https://supremevalues.com/mm2/ancients · https://supremevalues.com/mm2/godlies · https://supremevalues.com/mm2/chromas

## The actual counts and exclusions

| Publisher page | Actual HTML `itemcolumn` cards | Ordinary priced weapon entries retained | Exceptions excluded |
|---|---:|---:|---|
| Ancient | 16 | **15** | 1 priceless special: **Nik's Scythe**; not a normal numeric trade quote. |
| Godly | 130 | **128** | 2 hidden `style="display:none"` cards with **Origin: Secret MM2 Item**, 1,000,000 each: **Batwing** and **Black Luger**. Do not map these to normal trade identities or values. |
| Chroma | 53 | **46 weapons** | 7 **Chroma Fire pets** (Bat, Bear, Bunny, Cat, Dog, Fox, Pig). Pets excluded by weapon-only policy. |
| **Ordinary, priced weapons** | | **189 = 15 + 128 + 46** | Secret/special/pets must not be silently admitted. |

The 46 Chroma *weapons* are **44 Godly-class + 2 Ancient-class** items. The Ancient-class entries are **Chroma Emberbow** and **Chroma Emberscythe**. The `chroma` source category is a separate **non-overlapping trading bucket**, not an additional count on top of the ordinary Godly/Ancient weapon buckets.

**Dangerous ID/name collision:** normal **Ancient Batwing** is in the 15 Ancients with value **40** and item ID `Batwing`; separately, the hidden secret **Godly Batwing** HTML card is assigned item ID `Batwing` and value **1,000,000**. These are *not* grounds for two tradeable versions under the same identifier; without exact authenticated Roblox game-instance evidence, NEVER map that secret Godly price to a normal Batwing. Source: both official Ancient and Godly pages above.

## Independently compared with PR #311

Pinned Supreme-only catalog `pdiddler/system2/supreme_only_189_research_catalog.json`, Git blob `0fefb1d82d6841a787974478447f5d9e1db922e7`, from actual November 16 Supreme-origin mediated capture. It has exactly 189 unique source categories/game-key candidates and 189 unique category/item IDs. An independent fresh public page fetch verified **all 189 catalog names and IDs** against the corresponding current publisher page, **zero missing ordinary entries, zero mismatched official item IDs**. Deliberately ignored exactly 1 priceless Ancient, 2 hidden Godly secrets, and 7 Chroma pets. The website's 130 Godly DOM cards are not the same as 130 normal usable/tradable Godlies.

Regression tests now assert exact 15/128/46, explicit exclusions, Ancient Batwing value 40, and target/normal chroma coverage. They do **not** assert public website records establish actual Roblox item IDs, legitimate availability for trading, or that future Supreme versions will always contain these counts. A new item or changed publisher category requires new source capture, reviewed raw game mapping and new version pin; do not blindly reclassify or include secrets.

**Status:** census verified for the publisher edition in use. Supreme-only economics research remains read-only and expired for live pricing six hours after 2026-11-16 04:36:35.765 UTC. No live OfferItem, Accept, settlement, trading or deployment authorization.
