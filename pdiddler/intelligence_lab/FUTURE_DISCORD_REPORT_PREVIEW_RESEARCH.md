# Future Discord report layout — preview only (never send)

**Status:** isolated research-only code. Not connected to Discord, a webhook, live MM2 sessions, inventory readers, or Part4. No gameplay or manual device tests required.

## Goal

Prepare the final report presentation contract now, without repeating the project mistake of interpreting unverified self-reported Discord trade-completed embeds as server-settled trades. The existing private history importer already excludes test account evidence and quarantines unverified claims; it remains unchanged.

The preview includes:
- **What we hypothetically gave:** weapon name, stack quantity, listed research value, demand /10, liquidity /10 and stability per item.
- **What we hypothetically received:** same complete metrics.
- **Hypothetical listed points:** given, received, and signed difference, explicitly NOT realized trade profit.
- **Hypothetical entire inventory value:** before and after on the assumption of the exchange, explicitly NOT a verified post-close inventory readback.
- **Catalog version:** a syntactic label only, not authenticated publisher evidence.

Supports at most four types per side, stack quantities 1–20, distinct gave and received arrays. A one-sided gift may display "None" on the empty side; never infers profit from it. Uses Discord embed field length limits (four fields, at most 1024 characters each). The title is **MM2 hypothetical trade preview — NOT VERIFIED**, intentionally NOT Trade Completed, so the historical importer cannot mistakenly learn from a preview.

## Privacy and authority

Refuses any input mentioning account usernames, player/user IDs, trader names, webhook URLs/tokens, Discord bot tokens, server transaction IDs, or unrecognized fields. Weapon names with @mentions or Markdown-like injection are rejected, not sanitized into other meanings.

Every result declares maySendWebhook=false, authorizesTrade=false, authorizesAccept=false, serverCompletionProven=false, mayRecordCompletedTrade=false, mayUseForStrategyLearning=false, mayReportProfit=false, tradeOutcome=UNKNOWN. No network transport exists. The pure function returns an in-memory preview object or blocks invalid data.

## Integration later

The existing Stage59 two-client proof is STILL not authenticated MM2 settlement, so nothing in this branch can send a completed-trade message. Once a trustworthy result protocol is found, a separate executor adapter can consume independently verified trade outcomes and verified post-close inventory values, while this formatter supplies text layout. Do not use the old unverified historical Discord claims as proof or training samples.

Regression coverage: named stack math, missing inventories, privacy, item name injection, Discord field limits and 1,000 deterministic adversarial mutations, plus the inherited intelligence suite.
