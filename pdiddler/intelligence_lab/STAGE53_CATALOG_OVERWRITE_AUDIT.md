# Stage53 — Read-only MM2 catalogue overwrite census (one root-cause question)

## Scope and prior evidence
The real Stage50 iPad observation established only a **client** relationship between one owned Batwing raw key and the local offer ADD→REMOVE. Stage51 draft PR90 retained **mapping-method provenance**, but an internal-key, display alias or image/name similarity score is **not** independently authenticated proof that an MM2 raw catalogue key represents a particular Supreme checker ID. Neither a trade instance nor a successful settlement was attested.

This Stage53 substep investigates a narrower possible source of identity corruption **before** trusting any checker crosswalk: the actual scanner calls `indexItems(Sync.Weapons)` then, if different, `indexItems(Sync.Item)`. The second call replaces a `Meta["Weapons|"..id]` entry with a shared printable key without checking whether its year, chroma, event, category or artwork agrees with the first. Unknown behavior of the live game sources cannot be inferred from source code alone.

Offline inspection of the scanner's frozen **190** checker rows (16 Ancient, 46 Chroma, 128 Godly) found no duplicated exact `page:id`, no broken explicit mapping targets (7 internal-key assignments and 19 named alias branches), but one **duplicate normalized image identity**, `chroma:1033` and `chroma:1034` both displaying `coming.png`. This makes image-only matching insufficient for those two entries. These are source-inventory findings, not proof of individual raw-key authenticity or currently valid prices.

## Diagnostic implementation
`pdiddler/new_part4/STAGE53_READONLY_CATALOG_OVERWRITE_AUDIT.lua` is a stand-alone, **nontrading** script. In the MM2 place it reads the same local `ReplicatedStorage.Database.Sync` module already used by the scanner and compares `Sync.Weapons` and `Sync.Item` in memory. It **never invokes inventory remotes, opens trades, changes offers, reads another player's inventory, or transfers items**. The printed result contains **only counts and fixed status codes**, no raw keys, item names, player/session IDs, tokens, artwork URLs or full module data.

It distinguishes:
- identical table source: `SAME_TABLE_CLIENT_ONLY`;
- no overlapping eligible keys: `NO_ELIGIBLE_OVERLAP_OBSERVED`;
- matching overlapping fields: `CLIENT_OVERLAP_CONSISTENT_UNAUTHENTICATED`;
- missing comparison fields: `CATALOG_METADATA_PARTIAL` (unknown is **not** equality);
- contradictory chroma/year/event/item type/rarity/name/artwork/etc.: `CATALOG_METADATA_CONFLICT`;
- mixed string/number printable key collision or invalid structure: `INVALID_CATALOG_SHAPE`.

The code checks Roblox place and JobId consistency and always returns `mappingAuthenticated=false`, `serverCompletionProven=false`, `authorizesTrade=false`, `authorizesAccept=false`, `mayRecordCompletedTrade=false`, `mayReportProfit=false`, `tradeOutcome=UNKNOWN`. A clean client census does **not** prove an external market ID mapping.

## Tests and gating
`pdiddler/intelligence_lab/test_stage53_catalog_overwrite_audit.py` executes the **actual Lua launcher** under Lua 5.4 with a fake game, 16 named edge scenarios and 400 seeded adversarial case variations. It checks no sensitive values leak and all authority flags remain false, plus source-level forbidden-call gates. Existing stacked Stage14 Python/Lua regression workflow runs on this changed path. Review exact-head Actions CI before giving the iPad command. The Stage53 branch is stacked on Stage51 PR90 and must **not** be blindly merged into `main` (which now contains separately merged Stage52 guarded research prices).

## Remaining evidence / next step
After exact-head CI passes, perform **one** native Delta census (no trade required) and share the anonymized one-line `[GINGERSCOPE STAGE53 CATALOG CENSUS]` JSON only. If the live module structure differs, report its fixed error status; do not weaken the guard without diagnosing. This result determines whether a second catalogue source silently overwrites incompatible identities. It does **not** yet certify raw weapon key → Supreme checker IDs, publisher dates, variant/year completeness, or trade settlement. Continue those as **separate** Stage53/54 questions after this finding, not as speculative fixes.
