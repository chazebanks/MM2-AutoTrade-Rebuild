# Project Gingerscope — LastOffer client-only protocol research

## Research question (Nov 11, 2026)

**Does the original MM2 client's `UpdateTrade.LastOffer` provide useful evidence that an offer was updated?** This is NOT a claim that the field is a server-authenticated nonce, revision counter, or safe argument for automatic Accept.

**Actual latest MAIN iPad milestone remains PR221 Stage101 CLIENT ONLY PASS**: [sanitized native receipt](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/221#issuecomment-6788471060). Original protected P3/P4 lease and original Stage9 GUI matched one own + one ALT offered weapon and exactly one client `UpdateTrade` event. `eventSessionAssociationProven=false`, `callbackCausalityProven=false`, `serverTradeRevisionProven=false`, `rawItemIdConfirmed=false`, `tradeOutcome=UNKNOWN`, zero script offers/accepts. Do not retest this completed identity milestone or older PR214/206/216/217/218.

## Source-proven **historical client behavior**, not current MM2 server behavior

[Archived decompiled MM2 v1456 TradeModule.lua](https://github.com/tlredz/decompiledGames/blob/0552a0f3502217a1cf89df66be9bd0f153e47fa4/murder-mystery-2/v1456/ReplicatedStorage/Modules/TradeModule.lua), immutable Git blob `2785b13c0deb4ddd37942a5e85a5f5c35897d0f6`:
- The *old client* `UpdateTrade(data)` assigns `lastOffer = data.LastOffer` after matching an active partner; original source ~line 185.
- When the human presses the second-stage Confirm, that client sends `AcceptTrade:FireServer(game.PlaceId * 3, lastOffer)` ~line 366.
- It also has two client-side acceptance/GUI states, but **there is no server handler source here**, and no proof that `LastOffer` is monotonically updated, server-signed, unique to a session, or even the same type in current MM2. The archived version cannot justify implementing or sending an `AcceptTrade` call in our project.
- Previous Stage60 current native census saw `GetTradeStatus` and `SendRequest` RemoteFunctions, not a verified authenticated settlement path. Prior Stages61/63/66 saw client Accept callback and inventory changes but not server-trade nonce/settlement. Stage98 corrected draft PR179 already supplies local GUI offer epoch, **not** authenticated server revision. Stage112/113/115 code is merged offline replay safety; do not reimplement it.

## New bounded research code: no live connector or device action

`pdiddler/intelligence_lab/trade_lastoffer_client_audit.lua` is a pure dependency-free Lua 5.4-compatible **client-only equality audit**. It accepts caller-supplied scope (local client session/job, exact Player object references, root), one historical-shaped `UpdateTrade` table and monotonic local clock. It validates the strict original Stage101-tracked root/player/offer shape, one to four physical rows per side with original Stage9 stack parser's defensive 1..1,000,000 bound (not claimed game max), no accepted/locked state, no foreign fields, same exact player and local scope. It supports numeric finite or bounded non-control string `LastOffer` as *opaque PRIVATE values* and snapshots full offered rows privately, with no return of player IDs, job, raw keys, offered items, or token values. It compares successive *candidate* client packets and emits only four sanitized equality categories:

1. `CLIENT_LASTOFFER_CHANGED_WITH_DIFFERENT_OFFER`
2. `CLIENT_LASTOFFER_UNCHANGED_WITH_DIFFERENT_OFFER`
3. `CLIENT_LASTOFFER_CHANGED_WITH_SAME_OFFER`
4. `CLIENT_LASTOFFER_UNCHANGED_WITH_SAME_OFFER`

The first packet is a baseline `CLIENT_LASTOFFER_FIRST_EVENT_UNATTRIBUTED`. A changed LastOffer plus a changed offer is **only a client correlation**, not a server revision proof. An unchanged LastOffer with changed offer weakens the hypothesis that it uniquely identifies each revision, but cannot determine server policy by itself. Any invalid packet, scope/clock change, >120s window, >12 client packets, accepted state or unsafe token fails closed. It does not query UI or server; `clientGuiCrossChecked=false` on all outputs. All session/causality/revision/authenticated identity/offer/Accept/settlement/profit/Discord/learning flags remain **FALSE** and `tradeOutcome=UNKNOWN`.

**Not yet wired into the physical iPad or production `SUPERVISED_P3_STAGE101_IDENTITY_NATIVE.lua`**, known-good merged PR221 and PR218 runtime unchanged. Even if it were integrated with original Stage98 GUI epochs, a stale earlier event with identical player references and offers could be indistinguishable from the current event. Failclosed authority flags remain essential.

## Verification

`pdiddler/ci/test_trade_lastoffer_client_audit.lua` executes actual Lua 5.4 contract: 11 named groups covering all four equality classes; empty/current offer, stacked x5 and reversed Player1/Player2 orientation; frozen packet mutation; exact scope rejection; malformed/extra fields, nil/table/boolean/negative/NaN/∞ and control-char token rejection; accepted/locked state; timing/session lifetime and bounded event count; and a **delayed packet indistinguishability counterexample** that never authorizes Accept.

`pdiddler/ci/test_trade_lastoffer_source_audit.py` statically prevents Roblox network/game actions and false authority results, checks existing Stage101/PR221 denied-authority source. `.github/workflows/gingerscope-lastoffer-client-provenance.yml` downloads the historical archived file via **immutable full commit**, verifies Git blob and both source lines, installs actual Lua 5.4, runs original Lua groups and Python source audits, plus existing repo CI via PR. **Local Lua5.4 C-library runner passed 11/11 before GitHub submission.** CI must pass exact final PR head; never call offline PASS an iPad or current MM2 source PASS.

## Next decision, one issue at a time

After exact-head CI review: determine whether a **new purely read-only client observation** of *LastOffer type and equality transitions across real offer changes* is worthwhile. A future original MM2 iPad adapter, if built, must use the existing non-overlapping purple MAIN/ALT screen safety policy, exact consenting ALT, strict one-shot fresh-job start, no final Accept/offer/teleport/Discord, and show number-labeled actions on-screen. It must compare actual current token equality across ≥2 bounded `UpdateTrade` callbacks under fresh P3/P4 root/partner and independent Stage9 GUI. It must **never log the literal LastOffer value** and preserve all authority=false outputs. A local equality observation still cannot prove server validation or settlement; never claim it does.

After this source-proven protocol question, still outstanding: independently fresh and correctly mapped market quotes, actual liquidity/attractiveness of offered items, inventory compounding, intelligent four-slot upgrade/downgrade/rebalance, Gingerscope permanent outgoing protection once acquired, and eventually safe autonomous negotiation/Accept only upon independently defensible state and completion evidence. No obsolete universal +15 minimum or forced highest-item opener.

**Status of this branch: RESEARCH ONLY / NO DEVICE TEST / NO TRADING AUTHORITY.**
