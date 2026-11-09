# Gingerscope MM2 trade learning: evidence and adapter architecture
Date: 2026-11-09 UTC
Status: RESEARCH ONLY — no production trading, learning, or outcome promotion authorized.

## Proven current implementation status

- Public main at research start: `6cad5c1652e576ead7ef9ad44ad690c72f866469` (Luau, Lune, style, replay, Hypothesis merged). Existing `scripts/discord_history_embed_audit.py`, `scripts/discord_private_history_import.py`, `scripts/discord_readonly_probe.py` and associated tests are evidence/audit tools; **not** a production offer-outcome learner.
- Inspected the user's separate private research archive **without exporting records or identities**. Exactly 50 sanitized rows: 30 known test-account exclusions, 17 internally consistent but UNVERIFIED historic trade notifications, three quarantined/unparseable. All 50 have `server_settlement=UNKNOWN`, `learning_eligible=false`, `completed_trade_verified=false`, `webhook_source_pinned=false`; no rejection/negotiation traces. The private importer workflow succeeded previously. **Zero learning examples**. Do not expose row contents/IDs in public logs/docs.
- The checked-in mainline `pdiddler4_tradeio_v1.lua` has no final Accept. Existing `pdiddler4_controller_v1_3.lua` includes decline logic but is historical/legacy scaffolding; do not mistake it for the current unmerged Stage73/native Gingerscope controller. No authenticated server completion signal is established. Replay/Hypothesis test a separate offline event model, NOT actual native MM2/Delta parity.
- A Discord embed title "MM2 Trade Completed", values that sum correctly, webhook identity, and a webhook send success are NOT independent MM2 settlement evidence. Historical messages may contain stale displayed item labels, unverifiable raw keys and old listed-value numbers.

## Independent market research and implications

- Supreme primary list for Gingerscope, scraped 2026-11-09: value **16,000**, demand **5**, Stable, `Rarely Flippable`; page says list refreshed 2026-11-06, item last updated 2026-11-04: https://supremevalues.com/mm2/ancients?item=Gingerscope .
- MM2Values primary ancient list, checked 2026-11-09: **7,750**, demand **5.5**, Stable: https://www.mm2values.com/mobile.php?p=ancient . These lists use different community conventions. Never compare or sum them interchangeably, invent an exchange rate, or treat either as a settled transaction.
- Traderie listings show *asks and attempted offers*, not proven completed game transfers. Recent 2026 player discussions encourage low-item upgrade/downgrade cycles and report hard-to-secure overpays. These are anecdotes and hypotheses, NOT accepted-trade denominators: https://www.reddit.com/r/MurderMystery2/comments/1w1a5s6/for_those_who_have_difficulty_trading_heres/ ; https://www.reddit.com/r/mm2/comments/1xgxbuh/how_do_you_gain_value_in_trading_now_a_days/ .
- Strategy objective stays multiobjective: compounding small eligible Godlies/Ancients/Chromas, upgrades, controlled downgrades, attractiveness to counterpart, liquidity, stability, four-physical-slot ability, concentration risk and progress to Gingerscope. Do NOT inherit retired mandatory +15 rule.

## Critical Discord API and policy constraints

- Discord official webhook documentation: `wait=true` can return created Discord message, but proves Discord delivery **only**: https://github.com/discord/discord-api-docs/blob/main/developers/resources/webhook.mdx . HTTP failures/429 require retries/backoff and a delivery idempotency strategy: https://support-dev.discord.com/hc/en-us/articles/6223003921559-My-Bot-is-Being-Rate-Limited .
- Official message API history is paginated; `READ_MESSAGE_HISTORY` is required. Reading history or observing `webhook_id` does not authenticate an MM2 transaction: https://github.com/discord/discord-api-docs/blob/main/developers/resources/message.mdx .
- **Discord Developer Policy §21** prohibits using message content obtained through Discord APIs to train machine-learning or AI models absent Discord's express permission. Policy also restricts data mining and use of API data to profile Discord users. Do not treat the historic archive as AI training material or create individual counterparty profiles: https://support-dev.discord.com/hc/en-us/articles/8563934450327-Discord-Developer-Policy .
- Preferred architecture: generate minimal, first-party non-Discord trade observations **at the research collector**, evaluate consent/terms and retention, store them in an appropriately private source with provenance, and publish separate **redacted status notifications** to Discord. Do not ingest Discord message content back into an ML training pipeline absent permission. Roblox's own rules also warn exploit clients risk account action: https://en.help.roblox.com/hc/en-us/articles/203312450-Cheating-and-Exploiting .

## Proposed minimal event contract (not implemented)

Each negotiation gets a random, per-run, non-identifying `session_nonce`, exact live trade/window session binding (when actually proven), event ID, source-of-observation, observed monotonic time, `offer_revision` and reproducible feature snapshot. No public player names, tokens or unredacted Discord message payload.

Features to log for **each visible offer**, including rejected proposals:
- Our and their quantities and item keys (raw key separately from displayed label, checker/source ID only if actually proven), two-side physical-slot counts; source-specific `value_list_id`, publication timestamp, freshness flag; demand, stability, optional liquidity with `unknown` flags.
- Proposed exchange type: small-item flip, multi-item consolidation, desirable downgrade, growth candidate, Gingerscope-target; before/after portfolio quality and concentration, costs/risks.
- Event time/sequence, who changed which offer, old/new signatures, explicit observed offer acceptance per side, any actor-authenticated decline, timeout, cancellation, window close, server hop, network failure.
- Policy and planner versions, feature version, proposed score/rank and if possible reason it was selected; retain *all eligible attempts*, not only reported winners, to avoid survivorship and selection bias.

Strict outcome taxonomy:
1. `COUNTERPART_EXPLICIT_DECLINE_OBSERVED` only when actor and current revision/session are verifiably bound. This is a negative observation for **offer attractiveness**, NOT proof that the item's intrinsic value is bad.
2. `OWN_DECLINE_OR_SAFETY_ABORT` must NOT count as a partner rejection; also separate price failure, invalid identities, offers changed, and four-slot infeasibility.
3. `TIMEOUT_NO_RESPONSE`, `UI_CLOSE_UNKNOWN`, `SERVER_HOP`, `NETWORK_UNKNOWN` and actor-ambiguous `DECLINE_SIGNAL` are censored/UNKNOWN, **not** negative offer-attractiveness labels.
4. `PARTNER_ACCEPT_OBSERVED` (revision-bound) is a possible positive **negotiation interaction** signal, NOT independently authenticated settlement. Any intervening offer change invalidates this signal.
5. `SERVER_SETTLEMENT_VERIFIED` / `CONFIRMED_TRANSFER` cannot be manufactured from Discord notifications, closing UI, client inventory delta, acceptance flags or webhook response. If MM2 exposes no trusted attestation, keep settlement UNKNOWN; human-reviewed transfers can be a separately labeled, lower-assurance tier.
6. Strictly quarantine test alt sessions, contradictory duplicate or delayed events, identity mismatch, stale values and missing baseline. Never silently coerce UNKNOWN into accepted/rejected.

## Learning pipeline — separate analysis from live execution

`First-party observations -> fail-closed event validator -> private append-only event/evidence ledger -> deterministic replay & audit -> outcome labels per evidence tier -> offline attractiveness/growth research -> shadow scoring against frozen baseline -> human-reviewed promotion`

- **Two separate outcomes**: offer-response behavior and independently evidenced inventory transfer. Do not call a favorable response a profitable completed trade.
- Acceptance estimator: start with conservative bucketed rates by offer composition, listed-value gap, liquidity/demand, four-slot complexity and trade direction; use uncertainty intervals and recency segmentation, not speculative per-user intent. Estimate the opponent-side appeal **and** our long-run inventory quality.
- Economic objective: `estimated_acceptance_probability * validated_net_trade_utility - opportunity_cost` is a candidate analytical objective only. Net utility includes *verified and source-consistent* value gain, desirable-item/liquidity effects, upgrade path and concentration. Never optimize acceptance alone (e.g. perpetual giveaways), nor listed value alone (illiquid stock accumulation).
- Protect against selective observation: accepted-only Discord notifications cannot estimate acceptance frequency; track exact attempts and explicit outcomes across versions; compare against a frozen baseline using chronological holds/uncertainty and separate trade tiers. Do not label "no trade" as rejection. Avoid fake precision from 17 unverified claims.
- Time drift: event-driven repricing is independent of learned preference; reject expired price snapshots and unverified rawKey->checkerID mappings. No rule learner may bypass a stale/unknown source, four physical slots, session binding, final Accept lock, or settlement proof.
- Do not turn on online reinforcement learning in a live executor. First evaluate synthetic fixtures, deterministic event permutations, randomized corrupted payloads, out-of-order updates, duplicates, contradictory declines, test sessions, stale item identities, and webhook retry/idempotency. Require explicit owner authorization before any strategy rollout.

## One-issue-at-a-time recommended implementation sequence

1. **Read-only first-party offer/negotiation event schema and collector** (strict redaction and no username storage), tested against synthetic events; do not trade or accept. Confirm real UI identity/session binding separately.
2. Derive a **non-ML deterministic outcomes validator**: clear actor/revision-bound partner decline vs own decline vs timeout/UNKNOWN; no completed settlement claims.
3. Implement independent **delivery-only** Discord notifications using sanitized aggregate/illustrative status; add idempotency, bounded queue, 429 backoff, no secrets in client/public repo.
4. Build **offline shadow analytics** with full denominators and conservative baseline; evaluate attractiveness, small-weapon growth and Gingerscope progress with uncertainty and data lineage. No learning on 50 historical self-reports.
5. Only after trusted evidence, decide whether any ML training is permitted with the actual data's origin/terms; require policy compliance and explicit approval for live changes.

Status: research recorded, no production code change, no verified source for rejected offers, no authenticated completed-trade training sample.
