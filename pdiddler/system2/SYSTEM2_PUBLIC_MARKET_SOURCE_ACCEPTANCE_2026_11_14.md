# Gingerscope System2 — market source ingestion accepted (2026-11-14)

## Scope and actual result

**Completed one distinct dependency:** real read-only live HTTP market-source ingestion to a verifiable, immutable JSON research candidate. This is NOT native MM2 inventory-game-key mapping, active offer planning, completed trading, or learner integration. The operator explicitly requested one component at a time before new device tests.

### Actual verified evidence

- GitHub Actions run https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/43638552254, tested code commit `e172e9a81766e01985df0330f405afdf90df50dd`.
- Real network HTTP 200 on `mm2tradehub.com/values`, `/values/category/ancient`, `/values/category/godly`, `/values/category/chroma`, via GitHub-hosted runner. Earlier preflight https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/43637932292 verified true HTML card counts.
- Actual site's 2026-11-13 publication edition validated against 2026-11-14 retrieval UTC. Source HTML SHA256 for each tier archived in result.
- **209 displayed source cards**: 16 Ancient, 128 Godly, 65 Chroma. The page duplicates 19 Chroma cards representing exactly the same name, URL, two listed prices, demand, stability. The strict importer merges those 19 only when every normalized field is identical; conflicting duplicate blocks. **190 unique items**: 16 Ancient, 128 Godly, 46 unique Chroma.
- Downloaded exact generated JSON from Actions artifact ID `14131181445`, archive name `gingerscope-real-mm2-public-market-candidate`; independently inspected: `itemCount=190`, `deduplicatedCardCount=19`, `siteEditionDate=2026-11-13`. Spot checks: Gingerscope MM2=16000 Supreme=16000 demand=5; Harvester MM2=270 Supreme=270 demand=3; Chroma Evergun MM2=47000 Supreme=47000 demand=6; Iceblaster MM2=35 Supreme=32 demand=1.5.
- Source-contract suite **21/21 Python tests PASS** on the exact run, including adversarial missing page, wrong category, stale/future edition, missing official list price, price-label parsing, alias/host constraints, duplicate normalization and conflicting-duplicate stop. All live source/strict tests ran in the same workflow.
- Source does not require `RBLXVALUE_API_KEY`; RBLXValue API remains separate fallback with observed `PROVIDER_ITEMS_API_FORBIDDEN` (HTTP 403 JSON), not presumed fixed. Do not rotate secret blindly.

### Implementation and operational boundaries

- `pdiddler/system2/mm2tradehub_market_candidate.py`: normalized dual-source prices, demand, stability, original labels, source day, HTTP source hashes, item web slugs and categories, strict count checks and all-or-nothing staging.
- `pdiddler/ci/test_system2_mm2tradehub_market_candidate.py`: adversarial offline suite with source-contract fixtures.
- `.github/workflows/gingerscope-system2-public-tier-preflight.yml`: on-push and manually-dispatched live item-fetch workflow. FAILS RED on source mismatch; short-lived JSON artifact only on success. This research branch is not merged; no automatic production feed schedule has been deployed.
- Missing Supreme source values remain `null`, never 0; ambiguous publisher page aliases are scoped to known source hosts; no game player inventory, personal identifiers, tokens, or webhook payloads are collected.
- **Hard boundary:** `rawGameWeaponKey=null`, `chromaSubtypeVerified=false`, `canFeedLiveTrade=false`, `authorizesOffer=false`, `authorizesAccept=false`. This source dataset must NOT be cast as a proved game-ID mapping or confirmed player liquidity.

### Next task — only after operator approval

Market-to-game native identity and variant matching: compare 190 market IDs/names against canonical frozen Stage83/189 and current original MM2 client raw identities; reject ambiguous duplicate names, chroma subtype and quantity before using market rows as inputs to System2 decisions. No new MAIN/ALT gift cycle or old five-window tester. Keep unrelated P3/P4 code and Discord unchanged.

**STOP POINT:** Step 1 complete to source-ingestion level. Do not advance to Step 2 automatically; user requested approval between each item.
