# Future full-inventory research shortlister — offline precursor to planner

**Why:** The real project has historically observed over 100 owned eligible weapon types, while the bounded [future portfolio planner PR106](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/106) deliberately accepts at most five distinct types per side. We must not silently discard most of the inventory or claim a globally optimal strategy based on five conveniently chosen items.

This standalone Python reference can consume **up to 500 distinct inventory types per side** from already-supplied hypothetical snapshots. It applies only to **synthetic / independently sourced** full inventory and market profiles. It does not read MM2, connect Delta, authenticate a raw weapon key, access Supreme, query GitHub, or initiate any trade.

## Selection design

- Reject malformed inventory, duplicate names and invalid quantities; no guessing or destructive normalization.
- Require a market source version and independently known publisher update timestamp. Reject missing or older than 48-hour publisher provenance, rather than treating crawl timestamps as updates.
- Quarantine missing/unverified weapon mappings and missing value/demand/liquidity/stability instead of treating them as zero-value assets.
- Compute a **theoretical** upper bound for a possible offer: the four highest-valued distinct eligible owned types, up to two owned copies per type. This does not establish real four-slot feasibility or opponent willingness.
- Exclude opposite-side items outside that theoretical affordability bound, or with low demand (under 4/10), low liquidity (under 4/10), or undesirable stability.
- Rank qualifying weapons using a declared research-only quality heuristic, but select **at least one from each available value band first** (up to five), so the shortlist does not consist exclusively of large weapons. The future planner can explore compounding +5 gains, upgrades and downgrades.
- Cap copies in the output to two because the bounded PR106 planner has that limit. **Count every quantity cap, excluded item and nonselected item explicitly** in the result so missing coverage is visible.
- Never claim full-inventory optimality or complete inventory coverage. No real Stage58 key↔checker mapping is currently independently attested; actual unproven identities should remain quarantined.

**Outputs:** at most five own and five opponent hypothetical type/quantity rows plus a transparent exclusion/count report. All outcomes have weaponIdentityAuthenticated=false, counterpartyInventoryAuthenticated=false, authorizesTrade=false, authorizesAccept=false, mayReportProfit=false, mayUseForStrategyLearning=false, serverCompletionProven=false and tradeOutcome=UNKNOWN.

## Safety and future integration

This is only an input preselector. PR106 must still enumerate and score candidate exchanges, and PR105 must later revalidate any proposed offer against the **current exact trade-session offer slots and revisions**. Neither path authorizes gameplay. The synthetic source/identity flags in these fixtures never authenticate game metadata or a Supreme numeric ID.

No manual test is required. Offline tests exercise a 112-type scale, two-copy cap, item exclusion counters, unattainable Gingerscope target, deterministic order and 1,000 adversarial malformed inventories. A future Lua translation will need parity tests before runtime integration.
