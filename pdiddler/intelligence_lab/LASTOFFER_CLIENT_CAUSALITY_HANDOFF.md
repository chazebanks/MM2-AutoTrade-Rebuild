# Gingerscope — LastOffer client causality / revision research (NOV 11 2026)

## What prompted this **one** new experiment

The MAIN iPad's corrected PR221 Stage101 **CLIENT-ONLY PASS** is archived at [device receipt](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/221#issuecomment-6788471060): one UpdateTrade callback; both physical GUI weapon candidates matched, but `eventSessionAssociationProven=false`, `callbackCausalityProven=false`, `serverTradeRevisionProven=false`, and `authorizesAccept=false`. **Do not repeat** PR221 or earlier successful weapon placement/identity iPad tests.

Do not confuse this with already built [Stage98 PR168](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/168) and [stack-fix PR179](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/179): those supply a *local observed GUI revision* and revocable research preview, **not** an MM2 server revision. [Merged Stage112/113 PR192](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/192) rejects duplicate accepted-side observations and reused client session tokens in a **sanitized Python replay**, not the actual game network. Earlier Stages30–33 and 59–68 investigated trade remote names, Accept callbacks and inventory changes; none authenticated a server-side completed trade. These are distinct, do not rewrite or claim them new.

## New external code fact, narrowly established

A **historical decompiled** MM2 v1456 client module at [immutable repository commit](https://github.com/tlredz/decompiledGames/blob/0552a0f3502217a1cf89df66be9bd0f153e47fa4/murder-mystery-2/v1456/ReplicatedStorage/Modules/TradeModule.lua) (Git blob `2785b13c0deb4ddd37942a5e85a5f5c35897d0f6`) contains:
- `UpdateTrade(data)`: when local partner name matches, records `lastOffer = data.LastOffer`.
- An Accept UI confirmation route that sends `AcceptTrade:FireServer(game.PlaceId * 3, lastOffer)`.
- `StartTrade.OnClientEvent` calls the same UI updater from its initial payload.

**LIMIT:** These are call sites from an older client-side archive, not an audited MM2 server handler, not the current 2026 live build, and not proof of `LastOffer` uniqueness, monotonicity, session binding, or authorization. The first argument is a known client expression, not a discovered server-signed nonce. The current Stage101 frozen client packet permits `LastOffer` but does not validate it as a server revision.

## Research-only change

`pdiddler/intelligence_lab/trade_lastoffer_client_audit.lua` accepts bounded synthetic or caller-provided snapshots from one frozen *client-local* session/job/GUI/Player pair. No Roblox dependencies. It requires current Player1/2 orientation, unlocked/unaccepted trade, up to four physical weapon slots per side, strict raw tuple shapes/positive stack quantities; copies all comparison inputs privately to reject later mutation. Compares a preceding and new `LastOffer` (opaque numeric/string, never emitted) with the two offer lists; **all four combinations are possible observations**:
- token changed / weapons changed
- token unchanged / weapons changed
- token changed / weapons unchanged
- neither changed

Statuses are only client descriptive evidence; all server revision, callback causality, session association, raw ID authentication, exact instance, settlement, price/profit, trade/offer/final Accept, Discord and learning authority fields are FALSE. A same-token changed-offer synthetic regression **does not claim it happened on live MM2**; it is an adversarial falsification case. An identical-looking late callback and fresh callback can produce the exact same accessible snapshot and must remain unattributed. Neither the `LastOffer` value nor raw weapon key is exported.

Module caps 12 callbacks, 120 seconds and rejects scope changes, nonmonotonic local clock, missing/unknown token types, accepted/locked payloads, malformed quantities/slots, unknown extra data. It does **not** inspect real iPad GUI and explicitly says `clientGuiCrossChecked=false`. Never use this module to trade or to elevate a Stage101 client match.

## Verification and deployment boundary

- `pdiddler/tests/test_trade_lastoffer_client_audit.lua`: 11 named Lua behavior groups plus 1,000 deterministic adversarial comparisons including swapped orientation, stack x5, invalid/mutated payloads, wrong scope, timeouts, identical-history ambiguity and mandatory denied authority on every result.
- `pdiddler/ci/test_lastoffer_client_integrity.py`: launches actual Lua module, asserts existing proven **PR221 native runner** Git blob `46cff56b9f58fa8590a275dfd26f46cea0c5c9a6` and launcher blob `a1430dc26fc3d85fe2268a84a5fea475812b5002` unchanged; denies remote/clipboard/game APIs and authority promotion.
- `.github/workflows/gingerscope-lastoffer-client-audit.yml` verifies **exact historical archive blob and two original client call sites**, Lua5.4 syntax/native pure unit tests, Python no-mutation tests. GitHub CI must be read at the **exact final PR head**; local Lua passing is NOT CI or real iPad proof.
- **Research branch only**. No live game source modified. No iPad loader/automatic Accept/price/Discord/market learner. Keep it draft until tests and source review.

**Next after reviewing exact CI:** decide what, if anything, historical `LastOffer` comparisons can add to client observability without making unwarranted server trust claims. The actual unproven requirement remains current-game session/event/revision causality. If data is fundamentally unattributed in exposed client signals, preserve `UNKNOWN`, invalidate stale or changed offers, and pursue separate authenticated completion evidence only if the game actually exposes it. Longer-term trade attractiveness, liquidity, upgrades/downgrades, protected Gingerscope and portfolio growth remain user requirements; old mandatory +15/forced highest opener are retired.
