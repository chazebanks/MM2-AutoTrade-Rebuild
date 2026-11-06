# Gingerscope — Full Strategy and Research Workflow
**Updated:** November 6, 2026 (America/New_York)
**Role:** Long-lived strategy/research handoff for new ChatGPT chats.
**Read alongside:** [Active Gingerscope Handoff](./GINGERSCOPE_ACTIVE_HANDOFF.md).
**Current checkpoint:** Stage35's **FIXED** iPad probe successfully produced native metadata JSON: `SLOT_METADATA_SHAPE_OBSERVED`, `TheirOffer` slot 1, **`attributeCandidates=[]`, `candidateValueNodes=[]`, `candidateIdFieldPresent=false`**; eight image nodes are populated, including the plausible weapon picture `Container.Icon`. These are **image references, not raw weapon IDs**; backgrounds/tag images can exist while hidden. Stage34 previously matched +1 incoming / 0 outgoing with 97 stable frames but still `AMBIGUOUS_NAME_ONLY_OFFER_IDENTITY`. The existing scanner indexes game `Database.Sync.Weapons` and `Sync.Item`, preserving `d.Image`/`d.Icon`/`d.Texture` across all rarities. Stage36 new [draft PR #75](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/75) now provides a **read-only icon asset reference vs all-tier Sync catalogue collision audit**, not an item-ID or server settlement proof. Only counts/status/format flags exported; shared icon, missing artwork, incomparable URI, sprite sheets, source failure remain inconclusive. [Targeted GitHub Actions run 42181222333](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42181222333) at exact Stage36 head `eeb4eb190581d10f02925665b13d710ad8fc4cc0` passed **20 Stage36 Lua + 302 Python tests**, including real Lua runner and native compile-only. **First Stage36 iPad test pending.** Its read-only loader below can run during a manual trade with one *visible* offered weapon and **neither account pressing Accept**, then user manually declines; a completed exchange or valuable Iceblaster transfer is **not** needed. All automated Accept, completed-trade/profit webhook, raw ID confirmation, and old fixed +15 policy remain disabled.

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

"Continue Gingerscope from GitHub chazebanks/MM2-AutoTrade-Rebuild. Read pdiddler/GINGERSCOPE_ACTIVE_HANDOFF.md and pdiddler/GINGERSCOPE_STRATEGY_AND_RESEARCH_PLAYBOOK.md on main, inspect Stage32 PR #71, preserve the target-Gingerscope/4-copy/market-quality/seller-perspective strategy and the independent Supreme/MM2Values/market-board/Reddit/TikTok/YouTube deep-research methodology. Stage32 operator already confirmed a one-sided Iceblaster transfer: trusted account offered Iceblaster, receiver offered zero items, both manually accepted, trade visibly completed and Iceblaster was retained. Client probe saw +1 eligible / 0 lost / 0 result event receipts. Stage33 already received native JSON with one pre-open StartTrade, UpdateTrade +9.039s, two AcceptTrade +16.736/+17.989s and no post-close/result-named events. User clarified the weapon is already in inventory after the trade window closes, and Claim Weapon popup merely displays received items for manual acknowledgment; Claim is NOT an inventory-credit prerequisite. The popup and inventory credit were reported by the user, not directly recorded by Stage33. Stage34 FIRST native iPad run already returned +1 received / 0 lost, 97 stable frames, name-only slot (no raw ID), so its strict AMBIGUOUS status is correct. Stage35 fixed native JSON already observed a filled TheirOffer slot, ZERO ID-like attributes/value nodes and a populated Container.Icon image reference. Stage36 draft PR #75 now compares only this native icon's reference with the full available Sync weapon catalogue across ALL rarities to detect exact reference collisions; no assets/IDs printed. Exact Stage36 commit eeb4eb190581d10f02925665b13d710ad8fc4cc0 passed 20 real Lua + 302 Python tests (Actions 42181222333); native Stage36 report pending. Run its one SHA-pinned read-only loader with one item temporarily in a trade offer, **neither player presses Accept**, collect anonymized JSON and manually DECLINE. Do not repeat Stage35 or exchange Iceblaster. No item transfer or repeat Iceblaster. Claim Weapon is informational after inventory credit. No client-only event/GUI closure/candidate key grants authenticated server settlement, automatic Accept or completed webhook. No silent old +15 floor, speculative completion, production wiring or auto-Accept."
