# System 2 S2.7 — Discord bot / webhook feedback is the LEARNER'S intended source
**2026-11-14, research-only draft. This is an architectural correction from the operator, not an authorization to deploy machine learning, trade actions or new webhook sender.**

## Operator requirement — first and foremost
The user reminded the assistant that **the Discord bot and webhooks were specifically made to feed the learning system**. The right product architecture is:
`MAIN MM2 P3/P4 trade observations and eventual verified outcomes → original Discord webhook notifier → original Discord bot → PRIVATE Discord evidence archive → System 2 S2.7 evidence gate and adaptive learner → S2.3/S2.4/S2.5 attractiveness and Gingerscope growth decisions.`

Do not reimplement a disconnected data collection system, use arbitrary public chats as the learner's truth source, or accidentally redefine System 2 as repeated ALT→MAIN manual gifts. The user specified earlier that **P4 Discord sends come AFTER trading/settlement proof**; a webhook saying "completed" is insufficient to prove independent server completion. Model adaptation comes after verified outcome attribution and offline/shadow checks, not before.

## Verified historical pipeline
Existing code already in this repo:
- `scripts/discord_readonly_probe.py`: supervised PRIVATE Discord bot API probe; no raw payload in logs
- `scripts/discord_history_embed_audit.py`: real historical embed parser/classifier; exact `MM2 Trade Completed` fields, not just text
- `scripts/discord_private_history_import.py`: `mm2-discord-private-evidence-ledger-v1` importer, exact `build_record`, idempotent, conflicts on changed duplicate, private GitHub workspace required for persistent archive
- `pdiddler/research/DISCORD_PRIVATE_LEDGER_PLAN.md`: already agreed privacy and learner evidence boundary
- Original `pdiddler/intelligence_lab/test_discord_*py` and `pdiddler/intelligence_lab/SANITIZED_EVENT_REPLAY_HANDOFF.md`: source-verified tests and evidentiary history

2026-11-08 source audit: **57** channel messages, **30** exact test-alt trade notifications, **17** non-test self-consistent **UNVERIFIED** trade claims, **3** unparseable/quarantined, **6** nontrade webhook messages and **1** nonwebhook. **Zero independently confirmed server settlements and ZERO learning-eligible records.** These are old observations, not a new Discord channel fetch. Webhook ID pinning means source selection only; it does NOT authenticate MM2 transaction settlement. The original importer parses **historical completed-trade claims ONLY**. It does NOT presently capture attributable declined offers, timeouts, bot negotiation chats or other learning denominators. Do not invent these signals.

## New bridge implemented in this research draft
`pdiddler/system2/discord_learning_evidence_bridge.py` consumes exact v1 **private** importer record shape from the REAL `build_record`. It:
1. Counts parsed reported completed trades, excludes exact ALT test records, quarantines malformed/unknown, and treats the same Discord message received multiple times as ONE message. Same ID with changed record blocks the entire run.
2. Refuses any historical record that claims `completed_trade_verified`, `learning_eligible`, `authorizes_accept`, `authorizes_trade`, `may_report_profit` or non-`UNKNOWN` settlement, even if source webhook ID was pinned. Never extracts or returns trader usernames, bot token, raw game weapon identity, trade items, raw message IDs or reported profits.
3. Tests a **separate FUTURE webhook-event-v2 proposal, synthetic ONLY** with original `pdiddler/system2/counterparty_response_learning_lab.py` S2.7 state machine. Distinct events model ignored requests, attributable partner decline, cancellation, changed/invalidated offers, chat recipient ambiguity, client Accept indicator and closed-window UNKNOWN without falsifying a settled trade.
4. Returns a privacy-safe aggregate evidence accounting and no learning permissions. It is an adapter, NOT a new trained model, real Discord bot listener, private repo import run, server-authoritative trade proof or auto final Accept.

**Bridge must remain entirely offline** until private storage is verified, trust semantics independently established and intended bot event types captured. Existing PRIVATE GitHub repo was proposed earlier, but this PR does not claim an archive currently exists or was imported. Do NOT commit private Discord archive rows, bot token, webhook URL or user identities to PUBLIC `MM2-AutoTrade-Rebuild`.

## What actual adaptive learning from the Discord feed requires, in order
1. **Reporter**: P4 must have a provably bound `tradeSession/JobId/partner/offerRevision/weaponKey+qty` and clear actor/outcome classification; a generic `DeclineTrade` remote may be fired by either side and cannot be blindly treated as "partner rejected."
2. **Delivery**: a future versioned private webhook payload must report both successful and unsuccessful *eligible* episodes with denominator and provenance, not only "completed" trade embeds. Event IDs deduplicate; later revisions cannot retroactively certify old offers.
3. **Storage**: existing Discord bot fetches those events into the controlled, private, append-only ledger with source ID and revision; no public inventory exports. Never train on exact ALT testing as a real market/counterparty preference.
4. **Learner (S2.7)**: acceptance/decline/cancel/timeout/unknown separated; true success and gain labels only when independent settlement and item attribution exist. Rejections may inform shadow strategy only when actor/offer bound. Unknown stays censored, never labeled profit or a decline; chat indirectness stays uncertain.
5. **Validation**: train/holdout splits by distinct player/server/time and offer revision; guard against five repeated similar trades being "five different features." Evaluate bilateral seller appeal, demand/stability, growth route, conservative risk and calibration against meaningful alternatives; deploy only after separate authorization and verified current market prices.

User hardware is **NOT needed for this bridge research step**. Five previous client-delta gift cycles are DONE/CLOSED. The sixth trade's actual item is still UNKNOWN; separate offline taxonomy exists and its Lune tests pass, but cannot claim live item mapping is fixed.

## Accept boundary (not widened)
User explicitly reiterated **automatic FINAL ACCEPT currently permitted only for the exact MAIN + authorized ALT account in supervised trade sessions**; public/unknown counterpart final Accept remains DISABLED. This Discord learner work changes NO Roblox script, P3/P4 send/offer logic, Accept button input, or reporting service. Do not infer any new final Accept authorization from a Discord receipt or successful offline test. Existing sessionwide policy and per-trade safety checks remain separate.

## Current tests / handoff
- Historical Discord importer original source commit `95e8946ba5c348cbaf548ba0db0c0a465a692ae0` exact blobs `d7524156702623b450e3195099a91f4679ac6524` and audit `702d5924b870c0893c8a155d14b58e021afa4a29`.
- Original S2.7 event replay Git blob `31208dab4de3c5e348ad7f0f571d2dce70123eaa`.
- New bridge source initial commit `ab3e1a8320d18bbfd3939e099b41e5571efc1f47` blob `b79aa47cbc7e8b4f2c01347b3aae7db695aaeb6b`.
- New focused Python suite `pdiddler/ci/test_discord_learning_evidence_bridge.py` imports REAL original `build_record` and tests clean claim/test ALT/quarantine; duplicate/mutated receipts; forged settlement/learning/public authority; source ID misuse; 160 synthetic Discord notifications; 4 DIFFERENT future behavior categories and changed offer revision. Runs with inherited original Discord bot and S2 behavior/strategy tests in pinned dedicated CI `.github/workflows/gingerscope-system2-discord-learning-bridge.yml`. **Verify exact final code HEAD CI before claiming PASS.**
- Next step AFTER this: actual private Discord bot service/feed/event schema review; don't ask user to repeat five transfers or to paste bot secrets. Then resume a distinct S2.7 verified outcome integration and S2.8 strategy behavior calibration, not another isolated trade controller.

## Previous plan supersession note
The S2.7 synthetic `counterparty_response_learning_lab.py` was created to model outcomes but, if presented as an independent live learner, that framing was WRONG. It remains the testable **state machine UNDER the Discord bot evidence pipeline**. Current `discord_learning_evidence_bridge.py` connects the real historical archive schema to that pipeline while denying false outcome labels. The learner's real feedback must come from the existing Discord bot/webhooks once the underlying trade events can be trusted and privately ingested.
