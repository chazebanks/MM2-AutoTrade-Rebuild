# Gingerscope strategy decision — conditional autonomous quality-loss upgrades

**Recorded November 11, 2026. This is a long-term product direction, NOT permission for any live trading or automatic final Accept.**

## Decision

The long-term autonomous trader **may eventually** execute carefully controlled *listed-value-loss upgrades* if verified inventory quality, practical resale liquidity, and the probability-adjusted ability to acquire Gingerscope justify it **within a separately tested and approved risk budget**.

The user expressly requires **verification and separate authorization before deployment**. No monetary, percentage, per-day, or cumulative loss limit has been approved yet. The current system MUST NOT execute any such loss. Machine-readable restrictions are in `pdiddler/strategy/growth_policy.json`; default state is fail-closed.

## What the policy means for strategy research

- Compare **quality-adjusted post-trade portfolio** to the original inventory, accounting for retradability, real trade demand, stability, price-source disagreement, risk, concentration and ability to fund the eventual Gingerscope exchange.
- Consider all credible **no-loss** upgrade/sidegrade alternatives before a losing upgrade; label unavailable evidence as unknown rather than estimating acceptance odds from demand labels.
- Keep upgrade, downgrade, sidegrade, compounding and protected target-acquisition options available; **do not restore the obsolete universal +15-profit rule or a forced highest-value opener**.
- Observe and distinguish actual counterparty decisions, changed offers, cancellations, unknown outcomes and independently corroborated completed trades. Do not treat historical Discord webhook self-reports as verified settlements or learning labels.
- Protect Gingerscope permanently against outbound offers, even in synthetic high-profit cases; never use this strategic decision to bypass P3/P4 identity, offer freshness, trade session or settlement requirements.

## Required pre-deployment decision, separately requested

Before any real listed-value-loss automation, propose **specific risk parameters and evidence** for user approval: per-trade hard limit, daily/cumulative loss budget, maximum exposure to weak/unstable items, stop conditions, price expiry, item identity and exact state proof, strategy validation on held-out observations, explicit rollout and rollback criteria. The project must pass technical verification and retain the ability to stop safely.

**No existing numeric proposal is approved.** In particular, the historical November 2 ~3% exception and later `min(25, 2% of outgoing, 0.5% of portfolio)` hypothesis are archived research, not policy. Do not copy them into live execution. Likewise, Stage120 is offline/synthetic and does not authorize trading.

## Why recorded separately

This is a *new user policy direction*, not a change to the earlier proof of stages or implementation status. The prior notes correctly say no controlled-loss deployment approval existed; that remains true. New conversations and code agents should read this **before changing the trading decision engine**. Do not claim all prior stages were audited merely because this document exists.
