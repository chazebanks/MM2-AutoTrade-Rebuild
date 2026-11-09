# Stage71 — separate observed inventory from VERIFIED Supreme economic quote

## Problem seen in the real MM2 iPad screenshot

T4.4 says `Inventory rarity: Whitelist 7 | Blacklist 1 | Unknown 0`, yet each listed weapon has `UNVERIFIED: price expired or unavailable`. This **does not mean those players have unverified, fake or invisible inventories**. The client scanner can observe the replicated MM2 eligible weapon names, rarities and quantities. It cannot establish a trustworthy numeric current Supreme quote, because the original pin expired, and because raw weapon-key→Supreme checker ID resolution is often approximate.

The old presentation combined these two facts under one overloaded `UNVERIFIED` status, making the screenshot confusing. This was a presentation/terminology problem distinct from actual source freshness and identity assurance.

## Source and item identity stages already established

- Stage69 [DRAFT PR124](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/124) verified the original structured parser on all 190 canonical Supreme items using externally acquired, blob-pinned first-party HTML, 21 changed price/demand/stability records; [Actions 42565721527](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42565721527) **SUCCESS 40 tests**. Actual publisher timestamp Nov6, 2026 15:56:07 UTC; existing 72-hour TTL expires Nov9 15:56:07 UTC. The later GitHub checkout of an external fetch is NOT a new site publication. Still research-only; no executable price Lua, no production promotion.
- Stage70 [DRAFT PR125](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/125) found the latent false-verification path: old `checkerMarket` returned source `verified-snapshot-2026-11-01` even when matching via fuzzy/alias, and old P4 repricer would price `checkerId` based on fresh source+name, without independently proving the original raw MM2 key. Stage70 new pure Lua guard has an **EMPTY** hard-coded reviewed raw→checker crosswalk; no client `verified=true` can fill it. [Actions 42567126953](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42567126953) green, and later exact-head safety improvements reject duplicate checker-target proof and overflowing subtotals.
- Stage58 independently corroborated ten game *display identities*; no independently authenticated numeric raw→Supreme checker ID association. Stage66 one client raw received weapon key matching an own raw gain does not prove a Supreme numeric ID or confirmed settlement.

## This ONE read-only display workstream

`pdiddler/presentation/stage71_inventory_price_confidence_view.lua` is a standalone **pure Lua 5.4 prototype**, not plugged into legacy T4.4 yet. It accepts the already observed client inventory, source profile and optional Stage70 proof guard; reads NO Roblox services, no player profile RPC, no remote trades, no webhooks.

Its return:
- `inventoryState=CLIENT_ELIGIBLE_ITEMS_OBSERVED` if all listed eligible raw-key rows, categories, integer quantities and scanner error counters are coherent. This is **client-observed**, not game-server authenticated.
- `inventoryState=PARTIAL_CLIENT_INVENTORY` or `UNAVAILABLE` when source/client inventory is inconsistent, missing, unsafe or collisions exist. Then count is unknown, never a fabricated zero.
- Separately `priceState=SUPREME_SOURCE_EXPIRED_OR_UNTRUSTED` when Stage70's proof guard refuses source freshness; `SUPREME_SOURCE_CURRENT_RAW_ID_UNREVIEWED` when source is current but there is no reviewed exact ID association; `SOURCE_AND_ITEM_ID_NOT_VALIDATED` when the proof guard is absent, invalid, or a malicious external stub.
- `marketValuesShown=false`, `authoritativeTotal=nil`, no price numbers drawn from old `item.value`, `verified`, `checkerId` or the old fuzzy `source` string. The UI explicitly says `Total verified value: UNVERIFIED (not 0)` and `Outgoing: PAUSED | Auto Accept: DISABLED | Discord learning: DISABLED`.
- No private `Weapons.Owned` raw key fallback when a display name is missing. User-visible names are bounded and control characters sanitized; max 40 rendered rows. This UI does not export private inventory to network or Discord.
- All trade, actual completed/rejected profit reporting, auto final Accept, live trading and learning flags permanently FALSE.

Example (not a real live execution of this module):

```text
CLIENT-OBSERVED eligible weapon copies: 3
Supreme quote: UNVERIFIED (source expired/untrusted or provenance missing)
Supreme publisher timestamp: 2026-11-06T15:56:07Z
Raw item-to-Supreme checker identity: UNREVIEWED for live pricing
Displayed weapons: Icepiercer x1 [price UNVERIFIED], Batwing x2 [price UNVERIFIED]
Total verified value: UNVERIFIED (not 0)
Outgoing: PAUSED | Auto Accept: DISABLED | Discord learning: DISABLED
```

## Tests and explicit integration gap

`pdiddler/tests/test_stage71_inventory_price_confidence_view.py` runs the **actual Lua5.4 modules** under controlled tests, including stale/fresh source clocks, unreviewed raw keys and client proof flags, malformed quantities, duplicate/sparse inventory rows, missing private display names, malicious multiline GUI strings and 500 seeded adversarial inputs. Inherited Stage70 and Stage69 tests remain required. No replay of user's Stage63/66 ALT→MAIN transfer needed.

**Important:** This is a **separate view prototype only**. It does NOT modify or deploy `pdiddler/presentation/pdiddler3_scanner_view_v1.lua`, its immutable old boot URLs, or live T4.4, and it does not make Supreme prices current. Future integration must wire the Stage70 proof gate and this view into one intentionally reviewed read-only boot and demonstrate correct GUI states on a test snapshot before asking for one native iPad visual check. Never apply the source refresh and UI changes by merging every historical stacked PR indiscriminately.
