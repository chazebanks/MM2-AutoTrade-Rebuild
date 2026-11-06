# Gingerscope — Full Strategy and Research Workflow
**Updated:** November 6, 2026 (America/New_York)
**Role:** Long-lived strategy/research handoff for new ChatGPT chats.
**Read alongside:** [Active Gingerscope Handoff](./GINGERSCOPE_ACTIVE_HANDOFF.md).
**Current checkpoint:** FIRST *native* Stage36 image-relation probe completed with manually offered **Batwing** (user-supplied name), `schema=gingerscope-stage36-image-relation-v1`, `status=RELATIONSHIP_OBSERVED_INCONCLUSIVE`, `stopReason=IMAGE_RELATION_OBSERVATION_FINISHED`. **`exactNameRows=1`** and `nameCandidateRarityGroups=1`, `nameCandidatesChroma=0` yield **one supplied catalogue name candidate**, not item-ID/slot authentication. Correct alias accounting: `sourceAliases=1`, `physicalRows=1040`, `sourceLabelledRows=2080`. GUI image structure: `HTTP_HTTPS/ROBLOX_WEB/FILE_LIKE`, `assetId,width,height,format` query keys plus **one `other` unknown**; 703 of 1040 catalogue art refs use the same recognized four query keys, while 52 use `id`, 85 `RBXASSETID` and 200 `RBXTHUMB`. **Critical cause:** Code `parseQuery` clears `tokens={}` when any unknown GUI query key appears; with one GUI `other`, `candidateArtTokenRows=0` and `candidateWeaponKeyRows=0` are suppressed-by-policy, **not observed assetId inequalities**. `exactIconArtRows=0`, `exactIconOtherFieldRows=0`: byte-identical URL matching still fails. `uniqueArtReferences=1034`, `sharedArtReferenceGroups=6`, `artCollisionRows=12` physical-art reuse, not proof of overlapping weapons. Image writer/rendering source and raw key/slot remain INCONCLUSIVE; all trade/Accept/completion/profit authority FALSE. Latest code draft PR #75 head `35ec2d9a47048910a464a2ef6eb9b9f52ae306b1` not edited to guess a URL rule. **ONE next Codex question:** compare the GUI `assetId` value locally to art token values specifically for the name-matched Batwing row and globally across all 1040 physical rows, while treating unknown query key as unresolved, reporting **counts only** without URL, raw token, hostname/path, query values or private data. Reject malformed/duplicate keys, verify collisions and rarity/Chroma variants, and never promote candidate evidence into authenticated raw weapon ID or completed trade. Stop image chasing if no source-backed mapping; prefer directly bound raw item-key/slot evidence. [Full native report and next boundary](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/75#issuecomment-6681489240). No further valuable trades or repetitive full Stage36 probes. Gingerscope market/physical-copy strategy unchanged.

### FIRST real Stage36 Batwing rendering-relationship result (2026-11-06 Eastern)

- User specifically identified manually offered test weapon as **Batwing**. `RELATIONSHIP_OBSERVED_INCONCLUSIVE` with observed client slot and `contentKind=URI`, `sprite=false`. Within 1,040 distinct Sync table rows (`sourceAliases=1`), **one direct row had exactly the visible item name** (`exactNameRows=1`), with one candidate rarity group and zero Chroma flag. This is a useful catalogue *name* candidate, not an authenticated weapon key or item-slot proof.
- GUI image URI is `HTTP_HTTPS`, `ROBLOX_WEB`, `FILE_LIKE`, query `assetId,width,height,format` plus `other=1` unrecognized parameter. Across 1,040 catalogue art refs: 703 Roblox web references with matching known query-key layout (no extra unknown key), 52 with `id`, 85 `rbxassetid://`, and 200 `rbxthumb://`. Neither the actual values nor the path/hostnames were emitted. **No image-generation transformation or equivalence proven.**
- **Source-specific censoring of candidate counts:** `parseQuery` intentionally does `ambiguous=true` on any unknown query key, then `tokens={}`. The GUI has exactly one `other`, so `classify` sends **empty GUI ID tokens** into both the art-token and raw-key candidate checks. Their `candidateArtTokenRows=0` and `candidateWeaponKeyRows=0` are **not measured inequalities**. Preserve the no-identity gates; don't blindly treat unknown parameter as ignorable.
- This native result confirms `exactIconArtRows=0` and `exactIconOtherFieldRows=0`. Physical artwork reuse: 1034 distinct art refs, 6 shared groups / 12 rows, after actual Sync alias dedup. The prior 2,080 mirror-row total is correctly `sourceLabelledRows`, not 2,080 separate weapons.
- **Codex next ONE tightly scoped hypothesis:** Test *candidate* equality of the known GUI `assetId` field against the **single Batwing named Sync row**'s `assetId`, and quantify other physical rows sharing that same token. Analyze extra GUI query key safely (fixed category only) without exporting raw URL/token/key values, and guard repeated/malformed/unknown query layouts. Explicitly state that this does NOT establish image equivalence, exact raw item ID, or settled trade. Do offline regression first; only propose an additional read-only iPad test if it would discriminate. If Batwing relation cannot be grounded, stop image-only approach and investigate independent raw item-to-slot transport. [PR #75 checkpoint](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/75#issuecomment-6681489240). No automatic Accept/profit webhook, no Iceblaster transfer.

### Source-backed rendering boundary — 2026-11-06 UTC

The available repository stops at reading the native icon and inventory/catalogue metadata. No renderer/lookup statement or bound item-key payload schema establishes the offered weapon. Roblox Image/ImageContent reflection and documented thumbnail formats explain possible representations, not MM2's actual implementation. No speculative URL-equivalence parser or raw-ID fallback was installed.

One prepared passive diagnostic now distinguishes physical catalogue rows from alias labels, observes fixed URI/content categories, and counts exact local metadata/name/token candidates without exporting any raw values. All mechanism, equivalence, raw identity, trade/Accept, settlement and profit permissions remain false. Duplicate names, excluded rarities, Chromas, missing metadata, unknown queries, aliases and concurrent owners are covered by realistic failure tests. Existing stages are preserved. Independent review and targeted [Actions](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42192437966) passed (16 pure +44 native mock cases, 37 Lua suites, 309 Python tests); this is offline evidence only. See the linked report for the fixed output contract, risks and stop rule.

Do not request another completed exchange, repeat Stage35's negative metadata census, treat mirrored rows as weapons, or keep adding guessed URI variants. A new iPad observation is needed only to supply the missing live representation snapshot if actual renderer/lookup source or equivalent evidence cannot be obtained; it would be one separately approved read-only no-transfer measurement. No new native test is requested by this checkpoint. Canonical main updates are docs only, PR75 remains draft, and economic/trading policy is unchanged.


### NEW: First live native exact-reference comparison (2026-11-06)

- Corrected Codex Stage36 probe (`gingerscope-stage36-client-slot-icon-catalog-audit-exact-reference-v2`) actually ran on user iPad: `comparisonMode=BYTE_FOR_BYTE`, `stopReason=ICON_REFERENCE_CATALOGUE_AUDIT_FINISHED`, `status=NO_IDENTICAL_REFERENCE`. It performed 2,080 source-labelled artwork comparisons and found 0 identical source strings; no speculative URI decoding or early parser return.
- Source alias finding: **`Sync.Weapons==Sync.Item`**, same Lua table, represented twice by conservative `collectExact` source labels. Thus **2,080 source rows = 2 passes × 1,040 source entries**, and 2,080 image-reference comparisons reflect this mirroring. `duplicateReferenceGroups=1034`, `rowsSharingReferences=2080`, `stringifiedKeyOverlapGroups=1040` cannot demonstrate that 1,034 different weapons share an icon. There were no reported conflicting stringified key groups. One valid art value per labelled row; two other optional fields absent yields `missingArtFields=4160`.
- Even with `catalogueCoverageComplete=true`, only the **supplied rows** were covered, not necessarily every MM2 weapon or its rendered UI asset. No identical string means only no literal reference equality; visually identical images could still use URLs in different representations.
- Main task now belongs to a **source-backed rendering provenance investigation**, not a fifth blind URL parser. Codex should inspect how the MM2 client obtains the HTTP `Container.Icon.Image` URL from actual item/source data. If not statically accessible, propose ONE tiny passive local structural URI-correlation instrument (allowlisted categories + bounded anonymized aggregate counts), without exposing tokens, raw URLs, asset IDs, paths, query values, hashes or partner info. Ensure source aliasing is accounted for. Ask the user before such a new native diagnostic. Prefer genuine raw item-ID mapping if discovered; do not mistake image equality for authenticated ID/server settlement.
- Latest draft [PR #75 native report](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/75#issuecomment-6680826959), code HEAD `52d27bf00002267b54511881ca4852404c99ce6e`, module pin `c2485e3422d21c04401b1551b938b24288736ddd`. Last offline targeted CI [42188077527](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42188077527) passed 76 pure exact-reference Lua + 2 mocked native Lua + 306 Python; **native comparison now observed, but weapon identity still unknown**. No further transfer, auto Accept, profit webhook or merge is authorized.

### Second native Stage36 failure — Codex handoff, no further speculative loader (2026-11-06)

- **Actual corrected native result:** `slotIconReferenceComparable=false`, `iconReferenceFormat=OTHER_HTTP_IMAGE_REFERENCE`, `status=INCOMPLETE`, `nativeOfferSlotObserved=true`, `YourOffer` slot 1, `catalogEntriesFormatInspected=1040`, `catalogueReferenceFormatCounts={assetId=137,unsupported=903,robloxHttp=0,thumbAsset=0,gameAsset=0,builtin=0,filename=0}`. `catalogEntriesAudited=0`, `matchingCatalogueEntries=0` because **no equality comparison ran**.
- **Specific unanswered engineering question:** What actual HTTP content reference does MM2 place in `TradeGUI.Container.Trade.YourOffer.Container.NewItem1.Container.Icon.Image` and how does that relate to the 903 unsupported raw `Database.Sync` image/texture strings? The anonymized audit intentionally does not expose raw URLs. Reuse, aliases, CDNs, query variants and asset delivery transformations could make blind string/number conversions unsafe. Inspect actual source and, if needed, small privacy-safe URL host/path structure under controlled consent, not a successful valuable trade.
- User prefers **Codex** to handle this if it fails; it did. **Do not create Stage37 or patch another speculative parser**. [PR #75 source-backed Codex brief](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/75#issuecomment-6679993429) has current SHA, test suite, exact counters, data privacy, all-tier collision checks, fail-closed conditions and handoff instructions. Keep Stage34 name-only ambiguity and completion/profit authorization false until independent evidence.
- The last CI at `46a0ab0c6df6516f18e8079a54c0734d36240f06` was **offline-green** (32 Stage36 Lua and 303 Python), while the revised **native identity verification is a failure**. Do not conflate.

### Stage36 first actual iPad URI mismatch and corrected Stage36 parser (2026-11-06)

- User returned `status=INCOMPLETE`, `YourOffer` slot 1, `iconReferenceFormat=INCOMPARABLE_REFERENCE_FORMAT`, 0 audited entries and 0 matches. Inspecting Stage36's pure source shows **the parser returned early before catalogue iteration**. Therefore 0 does NOT mean no catalogue entries or no weapon image matched.
- First-party Roblox [Assets documentation](https://create.roblox.com/docs/projects/assets) explicitly supports thumbnail URLs (`rbxthumb://type=Asset&id=...&w=...&h=...`), game-local names (`rbxgameasset://...`) and `rbxhttp://`, beyond the Stage36 original recognized formats. The exact observed UI image value was never captured; cannot claim it used any particular one.
- New in-place Stage36 parser handles bounded official forms, fails closed on any unknown query/URI with safe enum, **never equates `rbxthumb` and `rbxassetid` by shared digits**, and independently counts fixed families of catalogue image refs when the slot format is unknown. New metadata `catalogEntriesFormatInspected` means inspected for **format**, NOT audited for weapon equality. `catalogEntriesAudited` remains 0 where no equality audit took place. IDs, icon URLs, names and user details remain private.
- Current draft PR #75 head `46a0ab0c6df6516f18e8079a54c0734d36240f06`; updated core module pin `30eb8498f82fd6a79f2f0fbbfc282e59b97c7bdd`; targeted [Actions 42182570797](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42182570797) **SUCCESS** with 32/32 actual Lua and 303/303 Python tests including native compile. No revised device result yet.
- **Use only this corrected SHA-pinned Stage36 read-only loader:**
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/46a0ab0c6df6516f18e8079a54c0734d36240f06/pdiddler/new_part4/STAGE36_READONLY_ICON_CATALOG_DELTA_PROBE.lua"))()
```
- Fresh MM2 rejoin to clear old owner, choose Tablet, run corrected Stage36 before manually opening trade. Offer one low-value/default weapon; **neither player Accepts**. Wait for anonymized JSON and manually Decline. No weapon transfer or Iceblaster repeat. Even single icon-catalogue match is client-only and not a verified raw ID, transaction settlement, or automated completed-profit webhook. If the format remains unknown, the sanitized scheme category and catalogue format histogram should tell us precisely which compatibility boundary to inspect next.

### Stage35 SUCCESSFUL native JSON and Stage36 client-only image-reference audit (2026-11-06)

- **First successful native Stage35 metadata JSON**, user-provided: `status=SLOT_METADATA_SHAPE_OBSERVED`, `stopReason=SLOT_METADATA_CAPTURED`, `TheirOffer` slot 1, item name present, **zero candidate ID attributes** and **zero candidate ID ValueBase nodes**. `Container.Icon` is populated; 7 other populated decorative image nodes include `Container.Gradient`, `ItemName.BG`, `Tags.*.BG`, etc. Those backgrounds are not indicators of actual rarity tags or unique weapon IDs. `spriteRect=false` for reported nodes; per [official Roblox ImageLabel docs](https://create.roblox.com/docs/reference/engine/classes/ImageLabel) zero image rect uses whole image rather than a sprite subregion.
- Actual current `pdiddler/presentation/pdiddler3_scanner_MODULE_v6_10_CURRENT_PRESENTATION.lua` reads `ReplicatedStorage.Database.Sync`, indexes `Sync.Weapons` and `Sync.Item` and stores `d.Image`/`d.Icon`/`d.Texture`. Stage36 is the **one next narrow test**: compare `TheirOffer` or `YourOffer` filled slot's `Container.Icon.Image` string **internally** with all available Sync weapon art sources **across all rarities**, counting distinct weapon-key matches and missing/incompatible references. Same icon shared across different rarities is a collision; no match due filename-vs-asset syntax does not prove item absence. No arbitrary digit substring matching. No icon URI, raw asset ID, item key, account or job ID is printed.
- New [Stage36 draft PR #75](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/75#issuecomment-6679694148), stacked on Stage35 #74. Exact head `eeb4eb190581d10f02925665b13d710ad8fc4cc0`; pure Lua module pinned `8203511e4a8b8566c4603e60716ace4e5716354c`. [Actions run 42181222333](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42181222333) **SUCCESS**: 20/20 Stage36 Lua, 302/302 Python, native compile-only. One earlier run had a false-negative Python test assertion requiring two no-authority flags to share a line; this was corrected without changing the actual logic.
- **ONE next immutable Delta loader**, confirmed on GitHub:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/eeb4eb190581d10f02925665b13d710ad8fc4cc0/pdiddler/new_part4/STAGE36_READONLY_ICON_CATALOG_DELTA_PROBE.lua"))()
```
- **No-exchange procedure:** Fresh MM2 join to clear old Stage35 key, choose Tablet, run only Stage36, manually open a trade, place **one unimportant weapon** in either visible offer slot, wait for `[GINGERSCOPE STAGE36 ANONYMIZED]` JSON, then manually decline; **no Accept on either account**. Does not scan inventory, call trading remotes, click any GUI button, send Discord webhook or teleport. If `Database.Sync` cannot be read or icon metadata uses incompatible reference formats, do not bypass the no-identity authority gate.
- Stage35 no longer needs repeating. Stage34 eligible +1/-0 quantity match and `AMBIGUOUS_NAME_ONLY_OFFER_IDENTITY` remain true. Stage33 Claim popup was informational after item credit; none of these convert client UI/icon evidence into server-confirmed settlement or permission to auto Accept. Preserve Gingerscope target, four-copy buying power, demand/liquidity, seller-side economics and independent research workflow.

### Stage35 screenshot debugging and verified Lua return fix (2026-11-06)

- Screenshot: trade window visible with one occupied `TheirOffer` slot, Stage35 startup line present, no metadata report; other lobby warning unrelated. Stage35's original `root and filledSlot(root)` assigned only **one** of the helper's **three** return values (Lua binary logical operator), so `side,index` always nil and report capture branch impossible. This was a code defect, not a need for another trade or more delay.
- Fixed `local slot,side,index; if root then slot,side,index=filledSlot(root) end`. Added Python regression that extracts the real native binding and executes under Lua5.4 to verify `slot`, `TheirOffer`, and slot index `1`, plus nil-root fallback.
- Exact verified commit `79444860a7d105e5245eed624c6fad10fd512739` at [draft PR #74](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/74#issuecomment-6679423370); [targeted CI 42179375788](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42179375788) SUCCESS, 13 Lua + 297 Python. Prior `12223ccdd93df1968c3230517d5ec556ee8762ef` Stage35 loader is **defective**, never instruct user to rerun it.
- Fixed Delta loader:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/79444860a7d105e5245eed624c6fad10fd512739/pdiddler/new_part4/STAGE35_READONLY_SLOT_METADATA_DELTA_PROBE.lua"))()
```
- Fresh server clears old owner. Select Tablet, run only this script, open a manual trade, have one visible offer weapon, **neither player presses Accept**. Allow observer to capture then manually Decline. Only request `[GINGERSCOPE STAGE35 ANONYMIZED]` JSON. An ID-like key or image presence is only a candidate, not authenticated identity. **Historical checkpoint: the first fixed-version native report was later received; see the Stage36 section above.**

### Stage35 next test and operational boundary (2026-11-06)

- **Historical Stage35 Delta loader** (already successfully run; do not repeat):
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/79444860a7d105e5245eed624c6fad10fd512739/pdiddler/new_part4/STAGE35_READONLY_SLOT_METADATA_DELTA_PROBE.lua"))()
```
- Existing Stage34 [PR #73](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/73#issuecomment-6679188406) stores actual iPad +1/-0, 97 stable frames and name-only slot evidence. Next [PR #74](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/74#issuecomment-6679198159) narrowly inspects **whether the trade GUI actually exposes an ID-like field or image node under the occupied slot that Stage9 overlooked**. It reports shape only, no raw ID, asset URI, text or PII; any found candidate is NOT automatically reliable.
- Fresh server + Tablet + Stage35 **only**. Wait for console prefix. Have trusted partner offer one item (no need to finish transaction), let observer capture it, then **DECLINE**; neither account ever presses Accept. Output `[GINGERSCOPE STAGE35 ANONYMIZED]` JSON is the only requested next evidence. If no slot can be observed, report INCOMPLETE. No item transfer, server settlement proof or webhook.
- Stage32 operator-confirmed Iceblaster transfer and Stage33 Claim Weapon UX remain completed prior tests. User clarified that received items appear in inventory before Claim acknowledgment, and that their trusted account must offer an item to enable Accept; preserve both facts. Do not reopen these questions or substitute a questionable name match as exact canonical identity.

## 1. Actual goal and strategy identity

The objective is to **acquire the genuine MM2 Gingerscope**, not simply make many small paper-value profits. The target is tracked by exact category, checker ID, and variant, with price refreshed from a genuinely current source rather than hardcoded as permanent. The separate Gingerscope research lab historically uses goal identity ancient:771:checker-id; verify the live catalogue and actual item identity before reusing its current valuation.

Trading progress is judged on SIX separate dimensions, not one merged score:

1. **Listed inventory wealth** — exact quantities and canonical item identity; before/after priced value; unknown items are *unpriced*, not valued at zero by assumption.
2. **Practical buying power** — the maximum verified value of a usable **four-physical-copy** package from the *same account*. Four distinct stacked types is a separate theoretical ceiling until the game actually verifies stack/slot behavior.
3. **Inventory market quality** — demand level, price stability/status, volatility, item desirability, risk of overpaid-for/underpaid items, concentration, and likelihood of needing later disposal. Source demand is an **ordinal descriptor**, never a measured probability that someone accepts.
4. **Progress toward Gingerscope** — whether an exchange meaningfully closes the gap to obtaining a usable four-copy Gingerscope package or directly acquires it. A hypothetical multi-step trade path is not a completed trade path.
5. **Counterparty economics** — independent seller-side comparison: What would the other player receive in listed value, demand, quality and copy count? A favorable deal for us can be unattractive to the seller; no algorithm can infer consent from their inventory.
6. **Safety, provenance, and execution** — complete price source; ID/quantity; offer mutation checks; player/job/session binding; verified GUI actions; independent inventory readbacks; no double execution, stale retry or false completed-trade record.

**Research lanes:** (a) fair/value-competitive offers, (b) value accumulation, (c) four-copy purchasing-power upgrades, (d) verified quality consolidation/rotation, (e) seller-aware counteroffers, (f) caution/unstable/disputed bundles. Preserve multiple shortlists. Do not pretend there is one universally best trade or an established acceptance probability.

### Relevant source implementation, not just a narrative

- Intelligence lab: pdiddler/intelligence_lab/README.md and evaluator.py (Stage 1 strict independent valuation), market_bridge.py (Stage 2 Supreme checker-ID/expiry mapping), offer_ranker.py (Stage 4), growth_planner.py (Stage 5), negotiation_research.py (Stage 7), stage18_strategy_bridge.py (Stage 18), stage19_portfolio_ledger.py (Stage 19), stage20_outcome_audit.py (Stage 20).
- Lua dual-perspective evaluator: pdiddler/new_part4/p4_dual_perspective.lua, whose seller-side labels mean *economic cases*, not accepted offers or measured liquidity.
- Historical approved but **separate** design: docs/superpowers/specs/2026-11-02-mm2-market-aware-planner-design.md and docs/superpowers/plans/2026-11-02-mm2-market-decision-matrix-plan.md. They preserve old v2.5/v2.6 mechanics and old profit floors. They do **not** automatically override the newer Gingerscope objective.
- Newer intelligence-lab README explicitly says **old fixed +15 trading rules are NOT inherited**. Stage4/5 default 90% offer coverage is a **display filter**, NOT an evidence-based probability or trade acceptance policy. Stage7's min(5%, 20 units) concession limit is an **offline research hypothesis**, not an instruction to lose that value in a live trade. Research any future real threshold independently.

### Candidate economic constraints and unresolved decisions

- Exact eligible Godly/Ancient/Chroma weapons, both guns and knives; only canonical mapped, tradeable and owned quantities. Unknown, Priceless/ambiguous or stale-price identities fail closed.
- Conservatively cap proposed physical copies to four per side. Whether stacked copies consume one native slot is **NOT proven** by an offline 4-type theoretical upper bound.
- Normally avoid raw value losses; a small source-backed quality improvement can be **studied** but cannot become automatic overpay authority without explicit risk review and user decision.
- Downgrading high-demand liquid assets into many cheap low-demand copies may increase paper value while reducing four-slot buying power and retradability.
- Distinguish inventory held in the user's main versus alt account. A theoretical aggregate is not one account's physically tradable inventory; internal transfers are not realized profit.
- Never treat a market snapshot's observed or valid-until timestamp as current without checking. The initial November 4 Supreme snapshot is expired; newer Stage26 snapshots are also strictly time-limited.

## 2. Intended full modular auto-trader (desired design, NOT current execution claim)

1. **Bot avoidance / entry** — rapidly distinguish likely bot farms from real MM2 servers. Evaluate false positives/negatives on real device; never hop with an unresolved trade.
2. **Startup selector** — use known-working Tablet UI click behavior and optional joining-friend Play path. Preserve it while trading behavior is being tested.
3. **Player inventory scan** — scan every available player by accurate canonical checker ID, verify new joiners and fresh inventory, classify verified no-eligible separately from unknown/incomplete. Maintain whitelist/blacklist status UI without poisoning unknown players.
4. **Request rotation** — process eligible players sequentially with bounded pending state and no duplicate outgoing to a player marked processed. Incoming requests are secondary while outgoing trade ownership is active. Rotate/resume only when a trade is resolved.
5. **Offer intelligence** — examine both actual offers and their stable signatures, use fresh identity/valuation, enumerate safe one-to-four-copy offers, evaluate both our benefit and theirs, prioritize route to Gingerscope, and refuse unsupported plans.
6. **Transaction executor** — single active owner/session, one offer mutation at a time, native add/remove verification after each action, abort/replan immediately on opponent mutation or partner/job change, bounded no-spam retries. Do not run two balancers or old/new controllers simultaneously.
7. **Acceptance and outcome** — final **automatic Accept remains DISABLED** until native acceptance, offer stability, actual post-trade reconciliation and a trustworthy transaction-specific completion protocol have been independently tested and separately approved. An observed Accept icon or window close alone cannot authorize it.
8. **Discord & portfolio** — once actual completion is separately evidenced, journal each completed transaction exactly once, with both sides' exact copies, source-backed values, demand/stability, value change and updated own inventory. Never send a completed-trade webhook based solely on a named client RemoteEvent, GUI close, or inferred gain.
9. **Continuation / server hop** — only after terminal state and pending reporting integrity are resolved; do not rejoin the same server repeatedly, contaminate session state or drop unresolved requests.

These are **the architecture we intend to achieve**, not proof that Stage32 already runs autonomous trading. The current Stage25–32 branch intentionally works on observation, source truth and safe release gates. Do not merge into the main production trader or reactivate old economic policy during a passive stage.

## 3. Repeat the SAME deep research method in future chats

The user specifically wants the prior deliberate multi-source GitHub/Codex/Firecrawl style: decompose questions, read source documents, research independently across platforms (including less mainstream MM2 sources), challenge conclusions, verify actual transaction evidence, test, and save the result. **Do not claim to have used a research tool, site or multiple sub-agents unless actually used.** Use available connectors and web tools appropriately.

### Research pass A — inspect actual project evidence first

Read the active handoff and this playbook on GitHub main. Read the current stage PR description/comments, actual relevant Lua/Python modules and tests, last confirmed device JSON, and GitHub Actions run/log. Compare the last verified working version with any regression.

Define **one concrete question**: e.g., "Did the client see CompleteTrade after manual success?", "Are listed MM2 values for this exact variant current?", "Does this candidate actually improve four-copy Gingerscope capacity?", or "Are these two posts independent completed trades?" Do not combine unrelated code changes.

### Research pass B — separate independent sources/questions (parallel where tools allow)

**Lane 1: publisher lists and exact asset identity**
- Current Supreme Values MM2 ancients/chromas/godlies pages, Supreme Use Guide, and published MM2Values list as separate sources. Search for their **verified current URLs** rather than assuming paths.
- Check canonical page and checker ID, weapon type, variant/year, quantity, exact quoted numeric value, "Priceless" labels, ordinal demand and status (Stable, Fluctuating, Doing Well, Underpaid For, Overpaid For), source update date, observation timestamp, time-to-expiry and hash/commit.
- If Supreme and MM2Values disagree, record both values and materiality. **Do not average** them or silently cherry-pick the favorable number.

**Lane 2: trading markets and specialist boards**
- Locate original current listings and user trades in Traderie, MM2-specific trading hubs/boards, available MM2 community exchanges and specialized indexes.
- Distinguish: active *ask*, wanted post, value opinion, W/F/L screenshot, proposed trade, accepted GUI, claimed completion, and **corroborated actual completed exchange**. A listing is not transaction volume.
- Analyze item bundles, quantities, offer dates, fill time when visible, source independence, historical volatility and repeat turnover. Without verified fills, call liquidity **unproven** rather than claiming it is high or low.

**Lane 3: independent community behavior**
- Search Reddit and also **YouTube, TikTok, community Discord logs when accessible, wikis and specialized trade discussions** by exact item and variant; do not rely only on Reddit/YouTube or a viral clip.
- Check the original publication date and actual video context rather than snippets or reposts. A click of Accept or a closed window is not proof of a settled exchange.
- Check whether multiple claims copied the same source: five duplicate reposts are **one** observation, not five corroborations. Never derive fake acceptance percentages from views, demand ordinal or a few anecdotes.

**Lane 4: native mechanic and runtime evidence**
- Read Roblox Creator docs for RemoteEvent and GUI APIs, but don't infer MM2-specific transaction semantics from generic Roblox documentation.
- Reconcile actual user-supplied iPad/Delta traces with the exact version of the code tested. The GUI can be recreated; signals can be transient; remotes may be server-to-client names without verified transaction identifiers.
- Compare opposing possibilities and test them with one bounded read-only diagnostic, not a dozen speculative hooks.

### Research pass C — sample queries for fresh external searches

Adapt current month/year and exact item, and run separately for each source class:
- "Gingerscope" "Supreme Values" MM2 current value demand stability
- "Gingerscope" "MM2Values" trade list latest variant
- "Gingerscope" MM2 actual completed trades item received
- "Gingerscope" Traderie MM2 current requests offers
- site:reddit.com/r/MurderMystery2 "Gingerscope" trade
- "Gingerscope" MM2 trade TikTok YouTube walkthrough
- "Gingerscope" MM2 liquidity quicksell underpaid fluctuating
- "Chroma Watergun" MM2 checker ID Supreme MM2Values comparison
- MM2 "CompleteTrade" "EndTrade" "DeclineTrade" behavior

Use web search plus Firecrawl search/crawl/scrape when connected and useful, GitHub for precise repository code, and specialist forums or board originals when accessible. If a site is blocked or unavailable, disclose the gap and seek alternative independent sources. Don't invent URLs, claimed trades, or screenshots.

### Research pass D — required evidence ledger BEFORE code changes

For **each material market/mechanic claim**, keep a dated GitHub note with:

- Original source title and URL; retrieval time UTC; publisher update time; page snapshot/commit/hash where possible.
- Exact item page, checker ID, variant, quantity, both bundles and observed market value(s).
- Evidence type: official list, posted asking offer, W/F/L opinion, negotiation, claimed completion, corroborated completed exchange, native iPad trace, or synthetic test fixture.
- Demand ordinal and exact status label, with uncertainty. Market "stability" labels are not an empirically measured probability.
- Independent corroborators and duplicate/repost risk; unresolved conflicts, collection biases, source expiry, liquidity unknowns, stack assumptions.
- Decision implication: safety hold, update an offline hypothesis, controlled native experiment, or no change. Never silently convert low-confidence material into trading authority.

### Research pass E — question the plan and its failure modes

Explicitly challenge:
- Could nominal profit be junk accumulation or decrease maximum four-copy Gingerscope buying power?
- Would the *seller* find our package desirable, and what actual evidence supports that beyond a source demand number?
- Does a trade improve overall inventory utility or only a short-lived price quote?
- Is "proof of completion" actually just a GUI close, Accept indicator, or remote event name without session identity?
- Are the web results independent, recent, and about exactly this variant?
- Does a code change duplicate an existing controller, reuse stale callbacks, retry a timed-out RPC or overwrite a proven scanner?
- What behavior worked before the change, what new failure appeared, and what is the smallest regression patch?
- Could stale source TTL, wrong checker ID, wrong partner, incorrect quantity, reopened GUI, or bot-server false positive cause unsafe automated behavior?
- What experiment would *falsify* the favored explanation?

Document rejected alternatives. Do not respond with blanket agreement or obscure uncertainties.

### Research pass F — implement and prove in order

1. **Pure Python** research/valuation and real source provenance, using existing evaluator, offer_ranker, growth_planner, seller-aware logic, Stage18 strategy bridge and Stage19/20 audit. No duplicate economics authorizer.
2. **Pure Lua / Stage9 native mocks** for the one exact observed mechanic. Test stale scans, wrong root, late/duplicate events, one-sided offers, mismatched identities, partial success and errors.
3. **GitHub CI** on actual branch/commit, inspect logs and fail/root-cause fix before user test. Synthetic PASS is not live proof.
4. **One short immutable pinned Delta loader** for the one unresolved boundary. Explain expected console marker, exact manual steps, what would indicate failure and what cannot be inferred.
5. **Analyze native anonymized JSON and user on-screen account**, including negative evidence. Reconcile with tested code, do not assume success.
6. **Checkpoint in GitHub**: PR comment, current handoff status, verified tested commit, actual CI and Delta observations. Preserve existing known-good build and avoid repeating successful tests with no new issue.

The user's device is iPad/Delta; normal desktop keyboard/mouse assumptions do not transfer. No promises of working asynchronously, and no claims that a connected source/website was checked unless actually accessed.

## 4. Explicit old-versus-current decision conflicts

| Question | Current Gingerscope research objective | Older archived assumptions |
| --- | --- | --- |
| End goal | Own real Gingerscope through useful progressive inventory | Optimize short-term raw trade profit alone |
| Profit floors | No automatic inherited fixed +15; study hard safety and long-run inventory utility | v2.5 / v2.6 fixed +15 and percentage floors |
| Offer quality | Source-backed market status, seller case, real liquidity, four-copy power | Treat added item count or higher nominal value as win |
| Offer opener | Research and verify effective, safe initial offer behavior | Always highest-value item, then fixed wait/sweetening |
| Values | Correct checker ID and fresh source with independent cross-check | Frozen snapshots/possibly expired value claims |
| Outcome | Read-only native evidence; no server attestation yet | Inferring completed trade from closing GUI/named event |
| Discord | Only idempotent verified completed transactions | Premature report from Close/Accept |
| Production | Exact one-owner session; staged release gates | Patch-stacking multiple controllers |

Archived specs remain valuable for rollback, explicit regression tests and operator UX, but are NOT permission to re-enable their settings without a deliberate economic review.

## 5. Current checkpoint: do not skip

Stage32 PR: https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/71

The user has NOW sent the first native Stage32 JSON. It reports:
- status ELIGIBLE_DELTA_WITHOUT_RESULT_NAMED_RECEIPT, stopReason TWO_POST_CLOSE_READS_FINISHED
- one eligible weapon copy gained, zero lost, one eligible type changed, raw weapon inventory changed, two post-close reads
- our Accept indicator ever visible, their Accept indicator not observed, both stable not observed
- **zero** CompleteTrade / EndTrade / DeclineTrade client receipts
- trade closure closed_unknown and all server/completion/profit/auto-accept authority false.

**Corrected operator observation (2026-11-05 Eastern / 2026-11-06 UTC):** successful one-sided Iceblaster transfer from trusted account to receiver, neither item nor copy offered on the receiving side; both manual Accept; Iceblaster remained in receiving inventory. Earlier user statement implying their own weapon was offered was corrected. The Stage29 and Stage32 live client data are **consistent** with this exchange but are not an authenticated server transaction receipt. Partner's unseen Accept indicator in a ~90ms poll does **not** disprove the reported second player's manual confirmation.

**Regression and Python verification:** The Stage29 one-sided-gain Lua fixture matches +1 eligible / 0 eligible lost / raw weapon change, while Stage32 pure correlation remains `UNKNOWN` with zero result receipts. A Python `unittest` invokes the **actual Lua suite**. [GitHub Actions run 42164723294](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42164723294) on commit `6637a25ec69e96f6cc4215b86a97cecba56cd0e8` succeeded: 20 Stage29 Lua tests, 18 Stage32 Lua tests and 281 Python tests. The separate synthetic scenario of **spending an excluded-tier weapon** is **NOT** what happened in Stage32 and must not be used as an explanation.

**Next question is technical:** Which MM2 client/native protocol can identify successful settlement for the exact transaction without trusting only GUI closure, Accept icons, a generic named event or two post-close inventory reads? No repeated Stage32 transfer test, no automatic Accept, completed-trade/profit webhook, production merge, or inherited fixed +15 profit policy on the present evidence.


## 6. Exact new-chat starter

"Continue Gingerscope in chazebanks/MM2-AutoTrade-Rebuild from the canonical active handoff and this playbook on main. Focus only on Stage36 image writer/raw weapon identity. Latest native exact-string result is NO_IDENTICAL_REFERENCE: 2,080 labelled comparisons over the SAME 1,040-entry Weapons/Item table, zero equal strings. Stage34 +1/-0 reconciliation works but remains name-only ambiguous; Stage35 found no candidate IDs. Read PR75 and https://github.com/chazebanks/MM2-AutoTrade-Rebuild/blob/35ec2d9a47048910a464a2ef6eb9b9f52ae306b1/pdiddler/new_part4/STAGE36_RENDERING_PROVENANCE.md. The actual MM2 image-generation mechanism and slot-to-key binding remain unproven. One reviewed passive representation diagnostic is prepared but has NOT run natively; offline green is not an identity fix. Do not request another completed transfer or valuable Iceblaster test, repeat settled probes, assume URL equivalence, or turn on Accept/completed logging/profit webhooks. If a user elects the one no-transfer diagnostic, obtain approval before sharing a pinned launcher. Otherwise seek the actual renderer/lookup source or an independently scoped raw-key/slot schema; stay INCONCLUSIVE without evidence. Preserve the Gingerscope four-physical-copy/market-quality/seller-side strategy."
