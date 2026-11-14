# Gingerscope System2 — first-party catalog discovery diff (research-only)

## Result: November 13, 2026

Operator's original browser `gingerscope-full-catalog-discovery-v1` receipt reported `DISCOVERY_COMPLETE`, three successful list requests and **199** entries (15 Ancient, 131 Godly, 53 Chroma). This is **catalog enumeration only**, not values and not a verified catalog of all possible in-game weapons.

Compared the receipt's `category` + `image` pairs to original Stage83 registry at commit `25b48b60fdb2f971bbb6b2a2020f3c7c4432f7ae` / blob `40e2a0ff01b70b2d0181c62cae347a08da82bcb8`:

| category | observed | historic weapon mappings | extras | missing |
|---|---:|---:|---:|---:|
| ancients | 15 | 15 | 0 | 0 |
| godlies | 131 | 128 | 3 | 0 |
| chromas | 53 | 46 | 7 | 0 |

Exactly 10 extras:
- Godlies with `origin='Secret MM2 Item'`: `mm2godlies/Batwing`, `mm2godlies/Black_Luger`, `mm2godlies/Mortal_Blade`. Special/hidden website entries; **do not assume all are non-tradable** without independent proof.
- Chroma Fire pets: `mm2chromas/CBat`, `CBear`, `CBunny`, `CCat`, `CDog`, `CFox`, `CPig`, all with origin `Season 1 Pet Egg`. Out of user-specified weapon scope even though site `class` says Godly.

Exact image identifiers matched all 189 historical weapon mappings (zero missing, zero unexplained new image identifiers, zero duplicate images). Two benign **case-only display name differences**: original `BattleAxe` -> site `Battleaxe` and original `BattleAxe II` -> site `Battleaxe II`. This does **not** alter the corresponding raw game keys `BattleAxe` / `BattleAxe2` or website images `mm2godlies/Battleaxe` / `mm2godlies/BA2`.

## Boundaries
- A later catalog may add weapons. **Never assume the 189 count remains exhaustive**; full three-category discovery must come before price gathering on new source versions.
- No current MM2 `Sync.Weapons` read or server item-instance identity was proven by this static website discovery.
- Website detail values are **not** included in this audit, neither verified nor promoted to live trading. In earlier full item detail test 53 validated plus four newly diagnosed values, but HTTP 429 stopped full collection; handle future detail collection with bounded batches and durable checkpoints rather than reissuing everything at once.
- System1 P3/P4 supervised same-server client integration was already physically passed and is separate. No new System1 tests or live code changed. Gingerscope remains protected outbound; no auto Accept, Discord profit, verified learning, or settlement.

## Code
`pdiddler/system2/catalog_discovery_diff.py` accepts a saved browser discovery JSON and exact pinned original Stage83 registry file as inputs. It does not contact the website, doesn't assume 189 as final, and distinguishes unreviewed extras from expected Secret records and pets. It fails closed on partial, contradictory, forged-count or malformed captures, and never authorizes automatic registration or trading.

Tests: `python3 -m unittest -v pdiddler.ci.test_system2_catalog_discovery_diff`.

When this helper is used against a future user-supplied capture, review **unreviewedExtra, missing and nameDrift** manually; a new site entry does not independently establish a new raw MM2 game key.
