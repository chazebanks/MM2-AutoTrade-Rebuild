# Stage51 — Preserve raw MM2 → checker-ID resolver provenance across cache (OFFLINE/SCAN ONLY)

## Trigger: genuine Stage50 succeeded, and generic shape INCOMPLETE is unrelated
REAL iPad Stage50 [PR89 native report](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/89#issuecomment-6715971733) has `TWO_PHASE_CLIENT_PREPROFILE_RAW_KEY_MATCHED`, one valid pre-offer own `GetProfileData().Weapons.Owned` literal STRING Batwing key, later matching actor-relative UpdateTrade own Batwing offer ×1 Weapons then matching removal, both offers empty, zero final Accept, two client callbacks, 48/48 listener cleanup. Top-level generic `p4_trade_update_shape` `status=INCOMPLETE/reason=OPAQUE_VALUE` reflects opaque Player userdata; separate Stage42–50 narrow inspectors are valid **client-only**. No confirmed unique weapon-instance ID, authenticated session, settlement or trade approval.

## Root-cause bug independently verified in actual scanner
The existing `pdiddler/presentation/pdiddler3_scanner_MODULE_v6_10_CURRENT_PRESENTATION.lua` has `checkerResolve` that maps MM2 raw weapon catalogue metadata to Supreme **checkerId** through three distinct methods: a static internal-key alias table, a display-name alias table and a heuristic filename/name score (`match:<score>`, threshold >=200). However it cached **only the returned item row** and on subsequent calls returned `"cache"` instead of the original mapping reason. `checkerMarket` then emitted only `source="verified-snapshot-2026-11-01"` — the dated **value snapshot source**, which does **NOT** authenticate raw MM2 catalogue ID or actual physical weapon instance. The rows therefore lacked evidence to distinguish exact manually curated association vs similarity-based guess. This is a provenance metadata bug, not evidence that any current trader made a bad deal.

Also, Supreme's independently checked official list currently identifies its latest values date as **November 6, 2026**, not Nov 1: [Supreme information page](https://www.supremevalues.com/info). The scanner's **Nov 1 pinned snapshot should not be described as current**. **This PR does not refresh prices** or change bot detection, liquidity or trading economics; source-freshness review is a separate concern.

## Narrow Stage51 correction
In the scanner module **only**, preserve cache entries as `{rec=<matched row>,mappingMethod=<actual original reason>}` and make future cached calls return `rec,mappingMethod`, preserving the 3 distinct proof classes exactly:
- `internal-key` — a hand-coded mapping, but **not independently server-authenticated**
- `alias` — normalized hand-written nickname-to-checker-ID association, also **unverified**
- `match:<score>` — heuristic filename/name score. **Never an authenticated exact item ID** even if only one row won.
- `ambiguous` and `unresolved` remain fail-closed. Neither becomes `cache`.

`checkerMarket` returns separate `mappingMethod`, `mappingAuthenticated=false`, `uniqueWeaponInstanceProven=false` and `provenanceScope="CLIENT_MAPPING_UNATTESTED"`, preserving the existing `source` snapshot date **only as economic value provenance**. Scanner row adds `checkerMappingMethod` and `checkerMappingAuthenticated=false`; its `valueSource` now visibly annotates `|mapping:<method>|CLIENT_UNVERIFIED` so no one mistakes a verified value **snapshot** for authenticated **weapon identity**. No change to which item is matched, selected numeric market value, or caching key. No live final-accept/rebalance/profit ledger logic changed or authorized.

## Validation
`pdiddler/intelligence_lab/test_stage51_checker_mapping_provenance.py` extracts the ACTUAL `checkerResolve` AND `checkerMarket` functions verbatim from the full Luau scanner source and executes them with `lua5.4` and synthetic catalogue rows in subprocess. This is **not a guessed copy** of the algorithm; it directly exercises current repository source. Tests check first/cached internal-key, first/cached alias, first/cached fuzzy match score, id selection consistency, `checkerMarket` unverified flags, duplicate score ties, unresolved lookup, and no method lost to a generic cache label. Additional source contract tests check provenance fields/dated source and that full scanner inventory functions remain intact.

The PR remains DRAFT stacked on the latest Stage50 PR89, not production; current existing Stage50 native probe source and actual previous iPad result unchanged. Exact-head GitHub Actions verification is required before declaring code tested.

## Explicitly not proven or changed
A deterministic mapping method is **not** an official server item ID, guaranteed Supreme checker ID, exact physical copy, or authenticated completed transaction. No auto trade/Accept, outgoing requests, webhook/profit, Gingerscope value/demand/liquidity strategy, 4-copy physical offer constraint, bot avoids, live Delta action or real server trade occur. No additional user Delta test is necessary for this source-only provenance fix.

**Next single question after this patch:** is there an independently verified, versioned raw MM2 weapon ID ↔ checker-ID mapping dataset, with collision/Chroma/type checks, that could justify any `mappingAuthenticated` escalation? Public values pages publish trading numbers and item display identities, not official unique MM2 physical instance IDs. Do not assume absent server source is available; if not, keep mapping unverified and handle economic uncertainty explicitly rather than endless fake proofs.
