# Future Gingerscope inventory-growth planner — OFFLINE prototype

**Build scope:** this component anticipates the later upgrade/downgrade/recycling and inventory compounding strategy. It is not the live MM2 autotrader and it does not connect to any executor, trade button, Discord webhook, or server-hop action.

## What it prepares in advance

- Generates hypothetical one-, two-, three-, or four-**physical-slot** exchange candidates from preselected inventory and opponent item pools. Several stacked copies of one weapon occupy one slot in this bounded research model; copies and slots are NOT synonyms.
- Handles stack quantities explicitly. A weapon with two copies may be offered as two only when the input inventory actually contains two.
- Differentiates **UPGRADE** (more copies offered than received), **DOWNGRADE** (fewer copies offered than received), and **SIDEGRADE** (equal counts), while keeping the four-visible-slot constraint. Quantity-based labels are research-only and do not predict willingness to trade. These are structural definitions, not market guarantees.
- Uses list-value change, demand, liquidity, stability and a concentration-increase penalty to rank candidates. All policy weights are provisional and can be revised once verified market/trade-outcome evidence exists. A +5 candidate is permitted; **no inherited mandatory +15 profit floor**.
- Refuses raw weapon/checker mappings not marked as independently exact, absent or expired *publisher* timestamp, untrusted value fields, low-demand/low-liquidity acquisitions, and received items with Declining stability. The real project's current Stage58 mappings are still unauthenticated, so those real inputs must fail closed.
- Refuses any input pool of more than five distinct types per side. It **does not silently trim full inventories**. Selecting a quality shortlist from a 100+-type inventory is a separate future engineering component.
- Enumerates exhaustively **only within the explicitly supplied bounded shortlists**: five distinct types maximum, **two copies per type (separate research cap)**, **four occupied physical slots per side**. Four occupied slots may carry up to eight stacked copies in this prototype. The theoretical number of nonempty side configurations is 210, so at most 44,100 pair comparisons per search. Larger stacks (three or more copies per type) are still **BLOCKED** here, not claimed impossible in MM2 or silently truncated. This corrects the former `sum(quantities)<=4` mistaken copy/slot conflation.
- Rejects same-key outgoing/incoming swaps to avoid artificial zero-risk recycling and inventory-count accounting mistakes.

## Nonauthority contract

Every result has globalInventoryOptimalityProven=false, counterpartyConsentProven=false, weaponIdentityAuthenticated=false, serverCompletionProven=false, mayRecordCompletedTrade=false, mayUseForStrategyLearning=false, mayReportProfit=false, authorizesTrade=false, authorizesAccept=false, tradeOutcome=UNKNOWN.

The positive status CANDIDATES_PREPARED means **only** a deterministic synthetic research ranking. It is not evidence that the other player would accept, the items are accurately identified, a market price is tradable, or a trade can be sent. No real trading actions are generated.

## Integration later

1. **Shortlist module:** choose which five inventory and opponent weapons deserve search, using full inventory and independently verified source profiles. Must not claim completeness if more than five considered.
2. **Offer snapshot guard (draft PR105):** after a specific candidate is selected, compare it against a fresh exact trade-session slot observation, catalog version, acceptance indicators and offer revision; invalidate any changed offer.
3. **Trade runtime state controller:** eventual UI actions must remain behind identity and settlement gates; these pure modules do not authorize final Accept.
4. **Outcome learner:** no completed-trade records from these hypothetical candidates. The unverified Discord claims remain quarantined.

## Testing

Named upgrade, downgrade, stacked quantities, four-slot limits, source timestamps, concentration, +5 gain and opposite-side same-item edge cases plus 600 deterministic adverse mutations in Python. Source has no Roblox, HTTP, API token or webhook dependencies. This branch stays draft/offline, no manual device testing needed.
