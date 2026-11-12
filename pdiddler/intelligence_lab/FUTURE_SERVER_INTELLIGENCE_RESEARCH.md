# Future server intelligence — offline, not a running bot avoider

**Scope:** prepare independent server shortlisting and cautious ten-second behavioral signals for the later MM2 server-hopping subsystem. No executor, Roblox server-list API, player account identification, automatic teleport or game actions are included.

## Cautious 10-second bot-like signal gate

The classifier can emit:
- BOT_HEAVY_SIGNAL_ONLY if enough **different observed players** show repeated routes, default-only animation and repetitive farming across at least six seconds of sampling; this is an **unverified behavior pattern, not a proven bot identity**.
- HUMAN_LIKE_SIGNAL_ONLY for sufficient independent movement and varied-animation clues; this is also not identity proof.
- INCONCLUSIVE if too little, contradictory or weak evidence. Refuse malformed samples and observation windows longer than 10 seconds.

**Voice-chat availability is deliberately ignored.** Its absence does not establish bot behavior. The threshold uses at least four adequately sampled players and multiple signal dimensions. These are research hypotheses; actual classification accuracy must be compared with separately labeled native recordings before relying on them to hop.

## Server shortlisting

If the future runtime supervisor reports eligible review context, no trade is open, world loading is false and combat is known false:
- Filter the current server and every previously visited server. Duplicate or malformed IDs produce a visible failure rather than a silently corrupted visited list.
- Filter full servers and servers with confident **bot-heavy *signals***. This is a conservative provisional policy, not an authoritative classification.
- Prefer observed **11/12**, then **10/12**, then 9/12 and other population counts. A **11/12** observed server has higher risk of filling before joining. Explicitly expose this in the output instead of inventing a real-time availability guarantee.
- Sort deterministically, expose only small read-only shortlists. Never teleport.

A server's observed population is not real-time joinability. Roblox's own current [TeleportService docs](https://create.roblox.com/docs/reference/engine/classes/TeleportService) specify **server-only TeleportAsync** for new developer workflows, legacy TeleportToPlaceInstance is deprecated, and TeleportInitFailed is a separate failure path. None of these API assumptions are bypassed or exercised here. Real Delta integration must be proven independently; no new unsupported API invocation is proposed.

## Safe output contract

Every output explicitly sets authorizesTeleport=false, authorizesTrade=false, authorizesAccept=false, botIdentityVerified=false, realPlayerIdentityVerified=false, serverJoinabilityVerified=false, serverCompletionProven=false, mayReportProfit=false. No server IDs are sent anywhere: all data supplied and returned is in-memory.

## Future integration

- Connect to [PR107 runtime supervisor](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/107) only after a reliable adapter supplies live event epochs, verified no-combat state, no trade and stable UI.
- Use existing real labeled bot-vs-real screenshots and native recordings for thresholds; avoid converting 'no voice chat' into bot labels. This branch doesn't claim trained accuracy.
- Address failed joins and visited-server persistence as separate future modules, never blindly retry/rejoin the same server.
- This prototype does not alter the original bot avoider or any Stage59/Part3/Part4 production code.

**Testing:** 1,000 malformed behavioral samples, named ten-second and server-population edge cases, and inherited Python intelligence regressions. No user testing necessary.
