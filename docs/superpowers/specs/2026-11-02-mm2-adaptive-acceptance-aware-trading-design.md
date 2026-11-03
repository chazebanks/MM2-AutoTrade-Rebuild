# MM2 Adaptive Opener + Acceptance-Aware Trading Design

Date: 2026-11-02

Status: DESIGN ONLY — no live trading code changed by this document.

## Intent

Improve completed-trade acceptance rate without weakening the existing safety model.

The current trader is optimized primarily for:
- canonical identity,
- raw/protected value safety,
- demand/stability risk protection,
- minimum-profit enforcement,
- transactional offer mutation,
- stale-state recovery.

Live recordings show that this can still produce offers that are mathematically safe for us but unattractive to the counterparty.

The redesign adds a separate **counterparty-appeal layer** after safety filtering.

Safety remains authoritative.

## Research findings that drive the design

External MM2 trading research and current Supreme-style market data reinforce several patterns:

1. Raw value is not enough. Demand, stability, liquidity/exit quality, and whether an item is easy to trade materially affect perceived value.
2. Upgrade/downgrade direction matters. A player taking several smaller pieces usually expects compensation; a player receiving a stronger single-item upgrade may accept a modest overpay.
3. A first offer that is wildly outside the other player's realistic range is poor negotiation signaling.
4. Traders who grow inventory tend to cycle between upgrades and downgrades rather than take arbitrary positive-value trades.
5. A technically profitable bundle can still be undesirable if it pushes weaker-demand inventory onto the other side while taking their stronger inventory.

The current planner already has most of the data needed:
- raw value,
- protected value,
- demand,
- stability,
- material disagreement,
- risk points,
- weighted exit score,
- copy count / bundle shape.

No second market database is required.

## Current behavior being replaced

Part 4 currently:
1. refreshes our canonical inventory,
2. finds exactly one highest-value eligible own item,
3. immediately offers it,
4. waits for THEIR OFFER,
5. generates safe plans,
6. ranks profitable plans near the minimum-profit floor,
7. within similar profit bands, prefers plans where the items **we give** have the LOWER exit score.

The final ranking choice protects our liquid inventory but can make the counterparty receive worse-demand inventory.

That is the central strategy mismatch.

## Goals

1. Remove "highest-value item first" as the default opener.
2. Give the other player a brief chance to reveal intent before we offer.
3. If they do not offer, choose a realistic market-aware opener.
4. Preserve every current safety gate before any appeal logic runs.
5. Among safe plans, prefer trades that give the counterparty a credible reason to accept.
6. Support bounded sweetening without crossing the safety floor.
7. Keep all behavior deterministic, session-bound, and stale-safe.
8. Keep final automated Accept disabled during the new test phase.
9. Reuse the existing canonical market profile and market logic.
10. Add enough diagnostics to explain why an opener/plan/sweetener was chosen without console spam.

## Non-goals

This design does NOT:
- enable automated final Accept,
- change Part 1 bot avoidance,
- change Part 2 startup,
- redesign Part 3 scanner or outgoing ownership,
- add live HTTP market requests inside trades,
- expand the eligible rarity universe,
- invent values for missing metadata,
- remove raw/protected profit protection,
- allow unlimited sweetening,
- make per-player permanent preference profiles,
- scrape chat messages or infer private player intent.

## Chosen approach

Approach C:

**Adaptive opener + acceptance-aware safe-plan ranking + bounded sweetening.**

Two alternatives were considered:

### Approach A — adaptive opener only
Pros:
- lowest implementation risk,
- fixes the obviously unrealistic first-offer behavior.

Cons:
- final rebalancer could still replace the good opener with an unattractive low-exit bundle.

### Approach B — acceptance-aware ranking only
Pros:
- improves final trade quality.

Cons:
- leaves the highest-value-first opener problem intact.

### Approach C — chosen
Fixes both the initial negotiation signal and final plan ranking, while keeping sweetening bounded by existing safety rules.

## Architecture

Responsibilities stay separated:

scanner
-> resolver / canonical market profile
-> opener policy
-> safety planner
-> appeal ranker
-> sweetener state
-> transactional executor
-> verifier / webhook

The appeal ranker never authorizes a trade.

It only orders plans that the safety planner already accepted.

## 1. Adaptive opener

### 1.1 Observation window

When an exact target trade window opens:

- do NOT immediately place an item,
- start an opener observation window,
- proposed default: **2.5 seconds**.

During this window:
- continuously observe THEIR OFFER,
- if THEIR OFFER becomes non-empty and resolved, skip the opener entirely,
- proceed into normal stabilization/planning against their revealed intent.

The existing empty-trade timeout remains authoritative outside this observation window.

### 1.2 If they offer first

No opener is placed.

Flow:

trade open
-> observe
-> THEIR OFFER appears
-> technical stability gate
-> safety planner
-> acceptance-aware ranker
-> transactional rebalance

This is preferred because their first item gives actual intent.

### 1.3 If they do not offer first

Choose one **adaptive opener** from our eligible canonical inventory.

The opener must be:
- canonically identified,
- market-profiled,
- non-disputed,
- positive raw value,
- positive protected value,
- actually owned with positive quantity.

### 1.4 Realistic affordability band

Use the partner's scanned eligible inventory to calculate:

- `partnerMaxSingle`
- `partnerTop4Raw` = sum of their four highest eligible raw-value copies

A forced opener is only allowed when it is realistically reachable.

Hard feasibility:
- opener raw value must be **below partnerTop4Raw** by enough room for the normal safety floor,
- if no such opener exists, do not force an opener.

This prevents cases like opening Chroma Watergun 2350 against a player whose realistic four-slot inventory cannot profitably reach it.

### 1.5 Opener ranking

Among feasible opener candidates, rank by:

1. complete/confident market metadata,
2. higher exit quality,
3. stable / positive market status,
4. lower material-disagreement risk,
5. value closeness to the partner's realistic tradable range,
6. deterministic canonical key.

The opener is a negotiation signal, not a commitment.

It may later be removed or replaced by the normal transactional planner.

### 1.6 No plausible opener

If no safe realistic opener exists:
- remain empty,
- continue observing THEM,
- retain the normal outer empty-offer timeout,
- do not place an absurdly over-sized opener just to force activity.

## 2. Safety layer remains unchanged

Before appeal ranking, every candidate must continue to pass the existing market/safety decision.

The existing rules remain authoritative:
- normal profit floor,
- downgrade premium,
- big-downgrade premium,
- protected-value floor,
- disagreement protection,
- missing metadata rejection/hold,
- quality-upgrade exception constraints,
- transaction verification,
- no stale offer mutation,
- no automated final Accept.

If zero plans pass safety, appeal logic receives zero plans.

## 3. Acceptance-aware safe-plan ranking

### 3.1 Current ranking defect

The current ranker prefers lower `givenExitScore` within similar profit bands.

That means the trader tends to keep easier-to-trade inventory and offer harder-to-trade inventory.

New behavior reverses that strategic bias only AFTER safety has already been satisfied.

### 3.2 Counterparty appeal inputs

For each safe plan calculate:

- `givenExitScore` — quality of what THEY receive from us,
- `theirExitScore` — quality of what they are giving,
- `qualityDeltaToThem = givenExitScore - theirExitScore`,
- `ourCopies`,
- `theirCopies`,
- trade direction from our perspective,
- raw profit,
- protected profit,
- required profit,
- disputed/unprofiled counts,
- item count / slot complexity.

### 3.3 Direction-aware appeal

Interpret bundle direction from THEIR perspective.

If we give fewer copies and receive more:
- THEY are upgrading,
- this is naturally appealing when our given item has strong exit quality,
- they may rationally pay a premium.

If we give more copies and receive fewer:
- THEY are downgrading,
- this is less appealing unless the bundle quality and value structure compensate them,
- de-prioritize such plans unless existing quality-upgrade logic makes the trade rational.

This does not change the safety threshold; it changes ordering among safe candidates.

### 3.4 Ranking order

For safe profit plans, use deterministic lexicographic ranking:

1. **Sweetening stage / allowed profit band** (defined below)
2. Higher counterparty appeal tier
3. Higher `qualityDeltaToThem`
4. Better direction for the counterparty
5. Fewer disputed copies
6. Fewer unprofiled copies
7. Simpler bundle / fewer OUR slots when otherwise equivalent
8. Deterministic canonical item key

Do not rank by "dump our worst exit-score items first" anymore.

### 3.5 Appeal tiers

Avoid one opaque magic score.

Use discrete tiers:

- **A:** counterparty receives a clear quality/demand upgrade or attractive upgrade shape
- **B:** roughly neutral quality with sensible bundle shape
- **C:** counterparty receives weaker exit quality but trade is still safe
- **D:** unattractive safe plan; use only if no better safe alternative exists

The exact tier rules will be implemented in pure market logic and covered by an offline matrix before live wiring.

## 4. Bounded sweetening

### 4.1 Purpose

Sweetening should improve acceptance without turning negotiation into uncontrolled profit leakage.

### 4.2 Reuse existing profit-band concept

Current ranker already calculates a market-scaled profit-band width:

`window = min(25, max(5, theirRaw * 0.02))`

Reuse this instead of inventing a new arbitrary value system.

### 4.3 Sweetening ladder

For each unchanged THEIR OFFER generation:

- compute all safe plans,
- group by profit band above the minimum safe profit,
- choose the best counterparty-appeal plan inside each band.

Preferred progression:

1. Start one safe band above the floor when such a plan exists.
2. If they do not accept and THEIR OFFER remains unchanged for **5 seconds**, step one band toward the floor.
3. After another **5 seconds**, step to the best plan in the minimum safe band.
4. No further sweetening below the safety floor.
5. Continue normal active-offer timing / negotiation hold behavior after reaching the floor.

Maximum sweetening steps:
- proposed default: **2**

### 4.4 Reset conditions

Sweetening generation resets immediately when:
- THEIR OFFER signature changes,
- partner changes,
- trade closes,
- session changes,
- transaction recovery starts,
- metadata becomes unresolved,
- local/manual Accept state becomes active.

Old sweetener callbacks must not mutate a newer offer generation.

Prefer loop/state timestamps over detached delayed callbacks.

### 4.5 Manual Accept interaction

While manual local Accepted is visibly active:
- freeze sweetening,
- freeze voluntary offer mutation,
- completion observer remains read-only,
- if MM2 clears Accepted because THEIR OFFER changes, the new generation may plan again.

Automated final Accept remains disabled.

## 5. Opener and sweetener must not compete

Only one offer-management state may own OUR OFFER:

- `OPENING_OBSERVE`
- `OPENING_COMMIT`
- `PLAN`
- `REBALANCE_TX`
- `PROFITABLE_HOLD`
- `SWEETEN_HOLD`
- `RECOVERY`
- `MANUAL_ACCEPT_HOLD`
- terminal close/decline

No opener may fire once a real THEIR OFFER generation has begun.

No sweetener may run while a transaction or recovery owns the offer.

## 6. Observability

Keep diagnostics concise.

New high-signal events:

- `ADAPTIVE OPENER OBSERVE`
- `ADAPTIVE OPENER SKIP — THEIR OFFER FIRST`
- `ADAPTIVE OPENER SELECT <item> value=<v> exit=<e> reachable=<top4>`
- `ADAPTIVE OPENER NONE — no realistic candidate`
- `APPEAL PLAN <tier> qualityDelta=<x> direction=<...> profit=<...>`
- `SWEETEN STEP 1/2`
- `SWEETEN STEP 2/2`
- `SWEETEN FLOOR`

Do not print every polling iteration.

## 7. Offline test matrix before live integration

A new pure test matrix must prove at least:

1. THEIR OFFER appears during observation -> no opener placed.
2. No THEIR OFFER -> plausible high-exit opener selected.
3. Highest raw-value own item is unreachable -> not selected.
4. No reachable own item -> opener remains empty.
5. Two equally safe/profitable plans -> higher counterparty exit quality wins.
6. Higher-exit bundle with tiny profit difference beats uglier bundle within same allowed band.
7. Unsafe attractive plan never outranks safe plan.
8. Counterparty-upgrade shape outranks counterparty-downgrade shape when otherwise comparable.
9. Disputed/unprofiled attractive item cannot receive positive appeal credit.
10. Initial sweetening stage retains profit reserve when available.
11. First 5s sweeten moves one band toward floor.
12. Second 5s sweeten reaches floor.
13. Sweetening never crosses required raw/protected profit.
14. THEIR OFFER change resets sweetening generation.
15. Stale generation cannot mutate a new THEIR OFFER.
16. Manual Accept state freezes sweetening.
17. Transaction recovery blocks opener/sweetener.
18. Existing quality-upgrade exception remains bounded by its current loss caps.
19. Existing no-plan 5s grace still functions.
20. Existing accepted-empty behavior remains immediate.

## 8. Live test sequence

Only after offline tests and CI are green:

### Live test A — adaptive opener
- open trade,
- other player does nothing for observation window,
- verify realistic opener is selected,
- confirm highest-value unreachable item is not blindly used.

### Live test B — they offer first
- have other player add an item immediately,
- verify no opener is placed,
- planner responds to THEIR OFFER.

### Live test C — appeal ranking
Use a controlled inventory where two safe plans exist:
- one gives weaker-demand inventory,
- one gives stronger-demand inventory,
- verify stronger counterparty plan is selected while profit remains safe.

### Live test D — sweetening
- hold THEIR OFFER unchanged,
- do not accept,
- verify one bounded sweeten at ~5s,
- second/final sweeten at ~10s if available,
- no third sweeten below floor.

### Live test E — offer mutation during sweeten
- change THEIR OFFER during sweetener hold,
- verify old sweeten state is invalidated and no stale transaction fires.

### Live test F — manual completion
- manually Accept a final safe offer,
- verify MANUAL ACCEPTED freeze,
- exactly one completion webhook,
- tracked inventory after and Trade ID still correct.

## 9. Success criteria

The redesign is considered successful only if:

- all existing safety/identity/webhook regressions remain green,
- highest-value-first behavior is removed,
- adaptive opener is live-proven,
- acceptance-aware ranking is live-proven,
- bounded sweetening is live-proven,
- no stale callback can mutate a newer offer,
- no safe-floor violation is observed,
- final automated Accept remains disabled during testing.

Longer-term success should be measured by:
- request-to-trade-open rate,
- trade-open-to-counterparty-offer rate,
- counterparty Accept rate,
- completed-trade rate,
- median raw/protected gain per completed trade,
- average exit-quality change in our inventory.

The objective is not maximum acceptance at any cost.

The objective is **more completed profitable trades per server/session while preserving inventory quality and safety**.

## 10. Implementation boundary

This design should be implemented as new versioned modules.

Do not edit frozen known-good artifacts in place.

Expected new work:
- pure opener/appeal policy module,
- market-logic ranking revision,
- offline strategy matrix,
- new Part 4 version integrating the state machine,
- new test stack,
- CI guards,
- handoff update.

Parts 1-3 remain unchanged unless testing proves a separate regression.


## 11. TikTok validation and resulting design adjustments

Additional research was performed against current TikTok-indexed MM2 trading content and TikTok transcripts.

### Evidence that supports the existing design

A current MM2 trading-tips TikTok explicitly recommends:
- using Supreme-style market status, not raw value alone,
- checking whether an item is Stable / Doing Well / Underpaid For,
- building value in **small steps** rather than trying to force one huge win,
- taking advantage of explicit `LF` (Looking For) intent because a player seeking a specific item may pay extra,
- being cautious around current-event items because values can drop quickly,
- expecting players to ask for adds even when a trade is already fair or slightly over.

A separate current trade-up challenge shows inventory progression being measured as incremental progress from one fair trade to the next rather than requiring every trade to be a huge win.

These observations reinforce:
- adaptive opener,
- counterparty-appeal ranking,
- bounded sweetening,
- modest initial profit reserve rather than maximum-profit opening,
- demand/stability-aware decisions.

### Design adjustment A — revealed intent outranks generic appeal

When the other player provides direct in-trade evidence of intent, use that evidence before generic opener assumptions.

Current implementation scope:
- THEIR first offered items are considered direct revealed intent.
- If THEY offer first during the observation window, skip our opener and build around that actual offer.

Future optional scope:
- explicit public `LF <item>` chat signals could be treated as intent, but no chat-reading subsystem is added by this design.

Do not infer preferences that are not actually observed.

### Design adjustment B — small-step progression is the default profit posture

Do not optimize the first safe plan for maximum raw profit.

Among safe plans:
- prefer the strongest counterparty appeal inside a reasonable safe profit band,
- retain only a modest reserve above the floor initially,
- use bounded sweetening to move toward the floor if necessary.

This directly matches the "small steps at a time" pattern found in current TikTok trading advice.

### Design adjustment C — stronger receive-side Underpaid For penalty

Current market logic already adds risk points for `Underpaid For` items, but TikTok evidence suggests these items are commonly expected to receive underpays and can be difficult inventory to move.

New rule for the acceptance-aware strategy matrix:
- an item WE RECEIVE with `Underpaid For` status cannot contribute positive appeal/quality credit,
- receiving such an item must increase required compensation or lose ranking priority,
- a raw-value overpay made mostly of `Underpaid For` inventory must not outrank a smaller but healthier bundle solely because its sticker value is larger.

This remains a ranking/risk rule, not a silent value rewrite.

### Design adjustment D — current-event risk requires verified metadata

TikTok advice strongly warns against current-event items because their values can move rapidly.

However, the current canonical profile does not yet guarantee a verified `currentEvent`/age field for every item.

Therefore:
- do NOT guess event status from names,
- do NOT hard-code a current-event blacklist without canonical metadata,
- rely on existing stability/disagreement/risk fields for the first implementation,
- event-age risk can be added later only if the canonical profile gains a verified origin/event field.

### Design adjustment E — bounded sweetening is confirmed, not endless adding

TikTok advice also notes that MM2 players often ask for adds even when a trade is already fair.

Therefore:
- the script may sweeten only through its precomputed safe bands,
- maximum sweetening steps remain 2,
- it must never chase repeated "add" behavior below the safety floor,
- once the floor is reached, hold or walk away according to existing timing/state rules.

### TikTok research limitations

TikTok itself blocks normal page scraping in this environment.

Research used:
- TikTok-indexed web search results,
- a TikTok-capable transcript provider for specific videos.

One retrieved transcript was high quality and strategy-rich; several other videos had sparse or unusable transcripts.

Therefore these findings are treated as supporting behavioral evidence, not a complete census of the MM2 TikTok trading community.


## 12. Broader 2026 market validation and additional constraints

A broader research pass was completed after the TikTok validation, using:
- Supreme Values' current use guide and current value/status pages,
- current 2026 Reddit MM2 trading discussions,
- current MM2 trading glossary/guide material,
- recent trade-up/downgrade examples.

### Confirmed market behavior

1. **Fair by raw value is not necessarily fair by market quality.**
   Current trading guidance explicitly distinguishes value from demand/stability and recognizes "fair by value, bad by demand" as a real outcome.

2. **Upgrade and downgrade are asymmetric.**
   Upgrading into a stronger single item commonly costs a modest premium.
   Downgrading a stronger item into several smaller items can justify compensation, but the required premium depends on the quality/liquidity of the smaller items.

3. **Small overpays are normal for genuinely high-demand inventory.**
   A rigid "never overpay" rule is inferior to bounded quality-upgrade logic when the received item is materially healthier and the loss is capped.

4. **Selectivity is a trading skill.**
   Current traders repeatedly describe server hopping / waiting for better inventories instead of forcing a trade with every available player.

5. **Underpaid/dropping inventory can be rejected even when the numbers look close.**
   Recent examples show traders refusing nearly-equal-value bundles because the offered pieces are dropping or undesirable.

### Additional design constraint — skip unattractive opportunities

The planner is not required to produce an offer merely because one safe plan exists.

If every safe plan is appeal tier D and none provides a credible counterparty benefit:
- do not mutate OUR OFFER simply to force activity,
- hold for THEIR next change within the existing negotiation window,
- if no better plan appears, use the existing bounded no-plan / outer-window exit behavior.

This is a deliberate move from "always transact when mathematically possible" to "only present a trade we would reasonably expect a market participant to consider."

### Additional design constraint — upgrade premium must be bounded and quality-backed

The existing quality-upgrade exception remains the only path that permits a small raw/protected loss.

It must require:
- materially better exit quality,
- complete/confident market metadata,
- no material disagreement,
- current existing capped loss percentages.

No general acceptance score may authorize a loss.

### Set-value risk discovered

Supreme Values tracks matched sets separately and set market behavior can differ from simple component sums.

The current canonical profile is item-based and does not contain a verified set-membership / set-premium model.

For this implementation:
- do not invent set premiums,
- do not hard-code guessed set bonuses,
- record this as an explicit limitation,
- future set-aware protection should use a verified canonical set table before the planner is allowed to preserve/break/complete sets strategically.

This prevents a new acceptance feature from silently introducing unverified set economics.
