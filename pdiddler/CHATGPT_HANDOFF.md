# PDIDDLER / MM2 AUTOTRADE — CHATGPT HANDOFF & CONTINUITY NOTES

**Last updated:** 2026-11-02  
**Repository:** `chazebanks/MM2-AutoTrade-Rebuild`  
**Purpose:** This file is the canonical handoff for continuing the same project in a new ChatGPT conversation without reconstructing the history from scratch.

> IMPORTANT: Read this entire file before changing code. Preserve known-good files exactly. Do not patch-stack blindly. Compare failures against the last working build and isolate the regression point.

---

## 1. User / environment / workflow

- Device: **iPad**
- Executor: **Delta**
- MM2 client behavior must be treated as mobile/tablet UI with delayed replication, GUI recreation, and executor limitations.
- User often tests with an alt account, especially **`venossgaming90190`**.
- User wants reliability/root-cause debugging over speed.
- Before code changes, check:
  - duplicate/conflicting logic,
  - stale callbacks,
  - race conditions,
  - old code overriding new code,
  - missing/nil GUI objects,
  - delayed UI replication,
  - wrong execution order,
  - duplicate sends/declines/rebalances,
  - retry limits and recovery paths.
- If repeated fixes fail, backtrack to the last known-good build instead of stacking more patches.
- Keep known-good files immutable.
- Prefer one authoritative subsystem per responsibility:
  - scanner
  - resolver/value system
  - planner
  - executor
  - verifier
- User prefers concise diagnostics and no console spam.
- When reviewing recordings, treat the video/logs as evidence and isolate the exact divergence before changing code.
- When delivering test builds, a short `loadstring(game:HttpGet(...))()` loader is preferred.

---

## 2. Critical safety / test rule

Until the user explicitly authorizes real trade completion:

**NEVER press final Accept inside an active item trade.**

Current allowed behavior:
- send outgoing trade requests,
- detect trade-open,
- inspect offers,
- place/remove our offered items,
- decline/cancel trades,
- rotate to the next player.

Do not add `AcceptTrade`, final Accept button clicking, or any equivalent final-completion logic.

Current Part 4 files have been statically checked and contain no final `AcceptTrade` or `AcceptRequest` path.

---

## 3. Project architecture

Current pipeline:

```text
Part 1 bot avoider
    ->
Part 2 startup/tablet selector
    ->
Part 3 scanner/value system
    ->
Part 3 outgoing request/rotation
    ->
Part 4 active-trade balancer/executor
```

Conceptually:

```text
scanner -> resolver -> planner -> executor -> verifier
```

One primary state should own each responsibility.

---

# 4. Frozen known-good components

## Part 1 — bot avoider — SUCCESSFUL / FROZEN

File:
`pdiddler/pdiddler1_KNOWN_GOOD.lua`

Commit:
`af4a646aa751571bace8eeb2b305ba16cebcad2f`

Blob:
`193d0319d54a3309fda338bdd054eb2f94b9190b`

Behavior:
- old T3.6 bot gate,
- scans avatar simplicity/name traits/clustering,
- blocks obvious bot-farm servers.

**Do not alter.**

---

## Part 2 — startup/tablet selection — SUCCESSFUL / FROZEN

File:
`pdiddler/pdiddler2_KNOWN_GOOD.lua`

Commit:
`b097c1862db4cff7394d6a5e6764d34191df3283`

Blob:
`463915e34d509b55b1a17634ec74396e7d82b76c`

Behavior:
- physically selects **Tablet**,
- handles optional “Joining a friend?” prompt,
- chooses **Play / Play Anyway**,
- never chooses Join Friend.

**Do not alter.**

---

## Part 3 scanner/value subsystem — original SUCCESSFUL / FROZEN

Original scanner:
`pdiddler/pdiddler3_scanner_KNOWN_GOOD_v6.lua`

Commit:
`ab6582d3576c3a9fed95dd5e17360fcc9c3f4d89`

Do not modify.

Styled scanner bridge:
`pdiddler/pdiddler3_scanner_MODULE_KNOWN_GOOD_v6_3_PURPLE.lua`

Commit:
`f4289133d58d57d37a5fef04676dd7e4ab204a31`

Blob:
`38c4e5eb717a2b60c8e6d7dfd96775fa0b4a258c`

API:
- `getRecord(userId)`
- `isWhitelisted(userId)`
- `getWhitelist()`
- `hasPendingWork()`
- `setStatus(text)`
- `setRequestState(player,state,extra)`
- `clearRequestState`
- `restoreWhitelist`

Scanner rules:
- real MM2 target scan remote:
  `ReplicatedStorage.Remotes.Extras.GetFullInventory:InvokeServer(p.Name)`
- whitelist only if target has at least one trade-eligible Godly/Ancient/Chroma weapon.
- complete verified none => blacklist.
- incomplete/unreadable => Unknown/retry, never false blacklist.
- nonempty inventory requires 2 identical complete snapshots.
- empty inventory requires 3 stable reads.
- malformed quantity => incomplete/Unknown, never silently use quantity 1.
- serialized inventory RF with pacing and bounded timeout.
- no fuzzy value matching.
- embedded numerical MM2Values snapshot.
- explicit exclusions for Evo stages, ??? placeholders, untradables.
- successful audit:
  - rarityWeapons: 200
  - tradeEligible: 190
  - excludedNonTrade: 10
  - resolved: 190 / 190
  - unresolved: 0
- canonical identity retains internal id/key/type/rarity/chroma/year/event/image/etc.

GUI:
- purple main background/accent
- black player/list boxes
- statuses:
  - whitelist/accepted green
  - blacklist/declined/failed red
  - sending/requesting blue
  - ignored/unavailable orange
  - unknown yellow
  - left gray

---

## Original Part 3 outgoing — SUCCESSFUL / FROZEN

File:
`pdiddler/pdiddler3_outgoing_KNOWN_GOOD_v5.lua`

Commit:
`5d71e1f4c0a4eb1e0715c75601e7e64cdf78ccc2`

Blob:
`d29dd8d44833b153e160c4364dd04ad354666f67`

Known-good behavior:
- sequential whitelisted targets,
- physically click leaderboard player -> correct player card -> physically click Trade,
- one outgoing request at a time,
- confirmed pending waits 15 seconds,
- ignored => cancel, mark ignored, next,
- declined => mark declined, next,
- accepted/trade-open => pause for Part 4,
- one confirmed outgoing request per player per server session,
- incoming requests during outgoing phase physically declined,
- final item-trade Accept disabled,
- “Trade tapped but no pending proof” was historically broad UNAVAILABLE,
- unavailable retry 15s, max 3,
- tablet physical clicks use GuiInset,
- request decline signal treated provisionally; trade-open precedence,
- incoming popup requires visible Accept+Decline proof,
- stale player-card refs are not reused.

Do not modify the frozen file.

Stable Parts 1–3 baseline:
`pdiddler/pdiddler_KNOWN_GOOD_PARTS_1_2_3.lua`

Commit:
`967fffb2c8549aa30d651182d2e2df2f0e050fa9`

---

# 5. External MM2 mechanics that were verified

External decompiled repo:
`tlredz/decompiledGames`

Useful MM2 v1456 files:
- `ReplicatedStorage/Modules/TradeModule.lua`
- `Trading.lua`
- `Trading_Phone.lua`
- `Leaderboard_Phone.lua`

Verified request behavior:
- `TradeModule.SendTradeRequest(name)`
  -> `trade.SendRequest:InvokeServer(game.Players[name])`
- sender pending UI depends on local client request-window state.
- target request handling uses `SendRequest.OnClientInvoke`.
- trades-off/busy/loading can look identical from sender.
- no safe replicated per-player “trades enabled” flag.

Verified phone leaderboard structure:
```text
MainGUI
└── Lobby
    └── Leaderboard
        ├── Container
        │   ├── PlayerList
        │   │   └── <username>
        │   │       └── UsernameFrame.PlayerLabel
        │   └── OverlayMenu
        │       └── TradeRequest
        │           ├── SendingRequest
        │           └── ReceivingRequest
        └── Popup
            └── Container
                ├── Username
                └── Action
                    └── Trade
```

Verified request UI:
- `SendingRequest.Username`
- `ReceivingRequest.Username`
- `ReceivingRequest.Accept`
- `ReceivingRequest.Decline`
- `SendingRequest.Cancel`

Verified trade offer mechanics:
- add item:
  `ReplicatedStorage.Trade.OfferItem:FireServer(itemId,"Weapons")`
- trade GUI:
  `TradeGUI_Phone` / `TradeGUI`
  -> `.Container.Trade`
- sides:
  - `YourOffer`
  - `TheirOffer`
- visible slots:
  `Container.NewItem1..4`
- shown item name:
  `ItemName.Label`
- Chroma marker:
  `Tags.Chroma`
- remove our item:
  physically click slot `Container.ActionButton`
- decline active trade:
  `ReplicatedStorage.Trade.DeclineTrade:FireServer()`
  with UI decline fallback.
- accepted state:
  direct expected node:
  `TheirOffer.Accepted.Visible`
  plus old text fallback:
  “OTHER PLAYER HAS ACCEPTED”

Important MM2 native behavior:
- offer changes reset the game’s Accept cooldown.
- This is **normal game behavior** and should not be “fixed.”

---

# 6. Part 4 strategy and rules

## Opening

When trade opens:
1. verify partner/session,
2. refresh own inventory using same canonical scanner/value system,
3. offer exactly **one highest-value eligible own item**,
4. verify it visibly in YOUR OFFER,
5. only then start empty-offer logic.

Unknown/unpriced own items are not guessed.

---

## Empty/Case rules

### Case 1 — accepted-empty
If opponent presses Accept while THEIR OFFER has zero visible items:
- immediate decline/close.

This currently overrides the 60-second Case 3 timer.

### Case 2 — never offers
After our opening item is visibly verified:
- THEIR OFFER empty
- wait 15 seconds
- final recheck
- decline if still empty.

### Case 3 — starts offering
On first nonempty THEIR OFFER:
- start one authoritative **60-second** timer.
- changes do not reset the timer.
- if they remove all items later, do NOT start a new 15-second empty timer.
- if trade closes/cancels before 60s, return immediately to Part 3.
- at 60s, decline/cancel and rotate.

The 60-second timer has already been live-tested successfully.

---

# 7. Balancer strategy

Community strategy researched:
**upgrade -> acquire desirable/liquid item -> downgrade for overpay -> repeat**

Distinguish:
- raw profit,
- effective/liquidity profit,
- strategic upgrade.

Core invariant:
**prevent us from overpaying, not them.**

Current balanced-aggressive thresholds:
- normal/equal-ish:
  theirs >= ours + max(15, 3%)
- downgrade:
  max(20, 6%)
- big downgrade:
  max(30, 8%)
- strict upgrade:
  raw loss up to 3% only if market quality improves enough and effective value is nonnegative.

The planner was fixed after video evidence showed a bad “cheapest profitable item” objective.

Current planner rule:
- prefer a real profitable plan,
- choose the **highest-value safe combination** that still preserves required profit,
- controlled quality-upgrade overpay is fallback only,
- preferred profit band avoids absurd 80-vs-8 style offers when a closer safe offer exists.

Examples from successful live tests:
- +17 raw profit repeatedly,
- +20 raw profit in upgrade-type scenario,
- previous +72 / +167 pathological behavior was corrected.

---

# 8. Part 4 transactional executor

The old failure:
`remove-verify-timeout`

was addressed by transactional execution.

Current executor rules:
- every rebalance has a transaction id,
- opponent offer signature/generation is checked throughout,
- if opponent changes mid-plan => transaction abort,
- stale partial plan is not continued,
- partial/unverified mutations enter RECOVERY,
- recovery clears OUR OFFER,
- recovery is verified,
- after recovery, opponent offer must stabilize again before fresh planning,
- bounded recovery retries,
- repeated uncertainty => PROTECTED HOLD,
- final Accept remains impossible in ADJUSTING/UNVERIFIED state.

Removal verification:
- uses exact offer signature and raw-value decrease,
- not just visible slot count,
- supports x2 -> x1 in the same visible slot,
- first remove click gets a late-replication guard,
- one bounded fresh-button retry,
- avoids accidental double remove from a late first click.

Duplicate stack verification:
- exact item counts are authoritative,
- visible slot count is not assumed to equal copy count.

---

# 9. Current performance fixes

Performance work was added because game became choppy on iPad.

Confirmed hotspots that were reduced:
- repeated whole-`PlayerGui:GetDescendants()` scans,
- repeated GUI text/layout writes,
- 5 Hz request-row repair,
- Part 4 high-frequency accepted-state scanning,
- scanner inventory refreshes running during active trades.

Current behavior:
- exact MM2 phone paths used normally,
- descendant scanning is fallback-only,
- repeated GUI writes are deduplicated,
- request-row repair reduced to 1 Hz,
- Part 4 normal poll interval reduced from 0.08 to 0.12,
- accepted state checks direct `TheirOffer.Accepted` first,
- scanner periodic/new-player/retry inventory reads pause during:
  - active outgoing request work,
  - Part 4 status ownership,
  - visible active trade GUI.
- if a scanner refresh already started and a trade begins, it pauses before the next inventory RPC.

This scanner/Part 4 contention fix was visibly confirmed in recordings.

---

# 10. Trade-close vs stale-session fix

Old bug:
normal trade GUI disappearance was being reported as:
`stale-session`

Root cause:
session liveness incorrectly included `tradeRoot() ~= nil`.

Fixed model:
- session validity = module generation still current,
- trade existence = separate condition.

Current expected results:
- old callback/module generation => `stale-session`
- trade GUI closes => `trade-closed`
- partner leaves => partner-left path.

Normal closure now updates player row to processed/closed before returning to Part 3.

This was confirmed in later recordings.

---

# 11. Late pending / outgoing ownership history

A major MM2 behavior was discovered:

A successful physical Trade tap can send the server request, then MM2’s local request UI can fail to render/update.

Observed local MM2 error:
`ReplicatedStorage.Modules.TradeModule:42: attempt to index nil with 'GetChildren'`

This means:

**no local pending UI does NOT prove no request was sent.**

Old bad behavior:
- physical Trade tap,
- 4.5s no pending UI,
- mark target UNAVAILABLE,
- release ownership,
- later trade opens anyway,
- target remains unprocessed,
- Part 3 can send another request to same player.

This produced duplicate venoss requests in an earlier recording.

---

# 12. Current authoritative outgoing ownership model

Current design:
- successful physical Trade tap creates one authoritative outgoing session tied to:
  - exact target UserId,
  - target object,
  - request serial,
  - tap timestamp.
- the 4.5s pending-proof window is now **diagnostic only**.
- target ownership survives for the full **15-second response window**.
- no second Trade tap is allowed after a successful physical tap.
- pending UI, trade-open, or decline signal resolve back to that exact target.
- if a trade opens without pending UI, exact `TheirOffer.Username` is used to verify ownership.
- at the 15-second boundary, trade-open is checked one final time.
- if nothing is proven:
  - target gets `UNCERTAIN TIMEOUT`
  - **NO RESEND THIS SERVER**

Important logs:
- `OUTGOING OWNED`
- `PENDING UI NOT PROVEN`
- `PENDING CONFIRMED`
- `UNCERTAIN RESOLVED TRADE`
- `UNCERTAIN TIMEOUT`
- `FOREIGN TRADE DURING OUTGOING`

Old paths removed:
- no `deferred-unavailable` after a successful Trade tap,
- no `TARGET UNAVAILABLE` retry after successful physical tap.

---

# 13. Incoming request behavior

During outgoing/queue phases:
- incoming requests are physically declined.
- exact request UI is used where possible.
- repeated incoming requests from venoss were observed; popup visibly disappeared/reappeared, so these were real repeated new requests, not one stuck stale popup.
- queue continued after declining them.

A remaining controlled test is still desirable:
- while an outgoing request to player A is actively owned/counting down, have player B send an incoming request.
- expected:
  - incoming B declined,
  - ownership/timer for A survives,
  - no timer restart,
  - no target switch.

---

# 14. Current active/test files

## Current scanner performance build

File:
`pdiddler/pdiddler3_scanner_MODULE_v6_8_CRITICAL_PAUSE.lua`

Commit:
`3c48b49c1e750d91bfbf088fbc737185bddf39be`

Behavior:
- same canonical scanner/value system,
- direct GUI write dedupe,
- critical request/trade pause,
- pauses in-progress retries before next inventory RPC.

---

## Current Part 3 outgoing build

File:
`pdiddler/pdiddler3_outgoing_ROTATING_v15_UNCERTAIN_OWNER.lua`

Commit:
`9f0637b063c2f65cb1cf6fc1f6ce4ab08b5dda87`

Key features:
- exact `MainGUI.Lobby.Leaderboard` paths,
- exact `PlayerList` and `Popup`,
- pending username ownership,
- authoritative outgoing session after physical Trade tap,
- no duplicate resend after tap,
- final 15s trade boundary recheck,
- stale-target revalidation before physical clicks,
- correct processed counter diagnostics,
- exposes critical outgoing busy state for scanner pause.

---

## Current Part 4 build

File:
`pdiddler/pdiddler4_balancer_ROTATING_v2_1_CLOSE_FIX.lua`

Commit:
`83670f3a9da06a07f1b9f67ca1e0467ea3714d8b`

Key features:
- closest-safe-profit planner,
- preferred profit band,
- partial market-quality layer,
- 15s empty rule,
- 60s Case 3 timer,
- accepted-empty immediate decline,
- transactional rebalance/recovery,
- correct trade-close classification,
- final item-trade Accept disabled.

---

## Current combined test stack

File:
`pdiddler/pdiddler_OUTGOING_OWNERSHIP_FIX_TEST_STACK_v2_3.lua`

Commit:
`0f8bb3536d3a073f3001e1759c07dca44fc5cbd1`

Loader:

```lua
loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/main/pdiddler/pdiddler_OUTGOING_OWNERSHIP_FIX_TEST_STACK_v2_3.lua",
    true
))()
```

Pins:
- Part 1:
  `af4a646aa751571bace8eeb2b305ba16cebcad2f`
- Part 2:
  `b097c1862db4cff7394d6a5e6764d34191df3283`
- Scanner:
  `3c48b49c1e750d91bfbf088fbc737185bddf39be`
- Part 3:
  `9f0637b063c2f65cb1cf6fc1f6ce4ab08b5dda87`
- Part 4:
  `83670f3a9da06a07f1b9f67ca1e0467ea3714d8b`

---

# 15. Test evidence / chronological conclusions

## Earlier Part 4 recording
Confirmed:
- opening Chroma Watergun 2350 first,
- Case 3 timer armed,
- planner initially chose overly cheap item (80 vs 8) -> identified as planner objective bug,
- status ownership conflict between P3/P4,
- stale-player click attempt after player left,
- accepted-empty logic worked.

Fixes:
- closest-safe-profit planner,
- Part 4 status ownership,
- stale player revalidation.

---

## Next Part 4 recording
Confirmed:
- +17 / +20 style realistic trades,
- no “80 vs 8” behavior,
- full 60-second Case 3 expiration path,
- stale-player recovery,
- no final Accept.

Found:
- `remove-verify-timeout`,
- partial plan race when opponent changes during executor actions.

Fix:
- transactional executor + recovery.

---

## Transactional build recording
Confirmed:
- `REBALANCE VERIFIED` transactions,
- old remove timeout no longer reproduced,
- trade-close cleanup works,
- pending/orphan state bugs discovered.

Fixes:
- exact pending ownership,
- late-pending adoption,
- clean trade-close vs stale-session.

---

## Performance recordings
Confirmed:
- scanner refreshes were running during Part 4 and causing contention.
- Part 3 had wrong fast leaderboard path (`Game.Leaderboard` instead of `Lobby.Leaderboard`) and could fall back to full GUI scans.

Fixes:
- verified exact `Lobby.Leaderboard` path,
- scanner pause during active request/trade,
- corrected processed diagnostics.

---

## 11:19 / 11:23 pair
Discovered:
- local TradeModule request-window nil error can happen after physical Trade tap.
- request can still reach target/server despite missing pending UI.
- old code could later trade the same player again.

Fix:
- authoritative outgoing ownership.

---

## 11:45 recording using v2.3
Confirmed:
- uncertain no-pending request counted down full 15s instead of immediate retry,
- target protected from resend,
- normal pending requests use same 15s flow,
- venoss pending -> trade-open correctly,
- venoss not immediately re-requested afterward,
- scanner stays paused during active Part 4 work,
- post-trade queue resumes correctly,
- no major new regression.

Important:
The exact rare path:
`physical tap -> no pending UI -> later correct trade opens`
was not reproduced in that recording, so `UNCERTAIN RESOLVED TRADE` without prior pending proof was still not live-proven there.

---

## 12:19 controlled recording
Confirmed clean run:
- manual/partner trade close path:
  `P4 TRADE RESULT trade-closed`
  -> `P3 OUT RESUME`
  -> no immediate resend to same player.
- venoss and Boba request flows:
  - OUTGOING OWNED
  - PENDING CONFIRMED
  - trade opened
  - Part 4 handled trade
  - clean close/resume.
- no errors in console.
- no uncertain timeouts in that run.
- no duplicate resend.
- scanner refreshes stayed out of active trades.
- repeated venoss incoming requests were declined and queue continued.
- Part 4 tx 1 rebalances succeeded around +17 raw profit.

No major bug found worth patching from that recording.

---

# 16. Remaining controlled tests

Do not add speculative code just to force these. Test them first.

## A. Incoming request while an outgoing request is owned
Setup:
- script has outgoing request to player A and 15s timer is active.
- alt/player B sends incoming request.

Expected:
- B declined,
- A remains authoritative outgoing owner,
- A timer continues,
- no restart,
- no switch.

## B. Rapid opponent changes during active rebalance
Setup:
- active Case 3,
- opponent quickly adds/removes eligible Godly/Ancient/Chroma items while OUR offer is being modified.

Expected:
- if change happens mid-transaction:
  `TX ABORT`
  then possibly
  `RECOVERY VERIFIED`
- no stuck partial offer,
- no double remove,
- no stale plan continuing.

## C. Duplicate eligible quantity x2 -> x1
Setup:
- opponent or our planned side includes two copies of the same eligible item,
- one copy is removed so visible slot remains but quantity changes x2 -> x1.

Expected:
- exact signature/quantity mutation detected,
- no false `remove-verify-timeout`,
- no false `plan-verify-timeout`.

## D. Rare missing-pending -> later exact trade-open
If naturally reproduced:
- physical Trade tap succeeds,
- local pending UI never appears,
- later exact target trade opens.

Expected:
- `PENDING UI NOT PROVEN`
- then
  `UNCERTAIN RESOLVED TRADE`
- target marked processed,
- target not re-requested after trade closes.

---

# 17. Value system notes

Embedded known-good numerical examples used in the project:
- Chroma Blizzard 5500
- Chroma Snowstorm 4250
- Chroma Watergun 2350
- Raygun 1825
- Chroma Treat 1800
- Chroma Sweet 1750
- Chroma Embersickle 1100
- Sunrise 775
- Snowcannon 680
- Bauble 675
- Sunset 650
- Heart Wand 350
- Emberbow 325
- Emberscythe 300
- Snowstorm 250
- Snow Dagger 170
- Icepiercer 165
- Icecream 155
- Watergun 150
- Immortal 140
- Mortal 140
- Bat 120
- Candy 90
- Embersickle 80
- Icebreaker 70
- Heartblade 65
- Ornament 60
- Chroma Lightbringer 55
- Chroma Luger 48
- Batwing 45
- Elderwood Scythe 40
- Chroma Laser 40
- Chroma Deathshard 35
- Chroma Elderwood Blade 35
- Chroma Swirly Gun 35
- Candleflame 35
- Darkbringer 35
- Elderwood Revolver 35
- Iceblaster 35

Important:
- do not infer uncertain entries from memory.
- use the embedded canonical source in the scanner.
- if enabling real completed trades later, refresh/verify current market data first.

Partial market-quality snapshot used in Part 4 was dated 2026-11-02.
Unlisted items defaulted Stable for testing, but this table is **not complete enough for real trade completion**.

---

# 18. Rules for future code changes

Before any code change:
1. fetch exact current source from GitHub,
2. compare with the last known-good/tested file,
3. identify root cause,
4. avoid unrelated changes,
5. create a **new version file**,
6. never overwrite frozen known-good files,
7. static check:
   - syntax,
   - nil paths,
   - duplicate/conflicting logic,
   - stale callbacks,
   - loops/retries/timeouts,
   - final Accept absence,
   - old logic overriding new logic,
   - recovery paths,
   - exact UI/remotes already verified.
8. package a fresh test stack with exact pinned commits.

If a recording shows something “wrong,” do not assume the first visible symptom is the cause. Trace:
- request target,
- physical tap,
- pending owner,
- trade partner,
- session serial,
- processed state,
- Part 4 session,
- scanner pause,
- UI disappearance,
- queue resume.

---

# 19. What NOT to change without evidence

Do not change these just because they look unusual:
- MM2 Accept cooldown resetting when offers change — normal.
- 0.65s offer stabilization solely because cooldown resets — not a bug by itself.
- scanner canonical values/identity system unless a concrete mapping bug is proven.
- Part 1 / Part 2 frozen code.
- original known-good scanner/outgoing files.
- current closest-safe-profit planner unless a real bad-plan example is captured.
- current 15s empty timeout.
- current one-time 60s Case 3 window.
- accepted-empty immediate decline, unless user explicitly changes that rule.
- final Accept disabled.

---

# 20. New-conversation startup instruction

When starting a new ChatGPT conversation, tell ChatGPT:

> Read `pdiddler/CHATGPT_HANDOFF.md` in my GitHub repo `chazebanks/MM2-AutoTrade-Rebuild` before making any MM2 script changes. Continue from the exact current state in that file and preserve all frozen known-good files.

Then the new conversation should fetch this file plus the current source files listed in section 14 before changing anything.

---

# 21. Current status summary

At the end of this conversation:

- Parts 1 and 2 are frozen known-good.
- Original Part 3 scanner and outgoing versions remain frozen known-good.
- Current experimental/advanced Part 3 outgoing = v15 authoritative outgoing ownership.
- Current scanner = v6.8 critical-phase pause.
- Current Part 4 = v2.1 close-state/transactional balancer.
- Current combined stack = v2.3.
- Performance is materially improved from earlier versions.
- Duplicate resend after missing pending proof was redesigned around authoritative request ownership.
- Latest controlled recording was clean.
- No major new patch is justified until one of the remaining controlled tests exposes a real failure.
- Final trade Accept remains disabled.

**Do not freeze Part 4 / v2.3 as final known-good unless the user explicitly says it is successful/final.**


---

# 22. Continuity / note-maintenance rule

From this point forward, keep this file updated whenever the project materially changes.

Update this handoff after:
- a new script/build is created,
- a bug is confirmed,
- a bug is fixed,
- a test passes or fails in a way that changes confidence,
- a component is frozen as known-good,
- the active loader/commit changes,
- a requirement/rule changes,
- a new unresolved risk or next test is identified.

Each update should preserve:
- exact file paths,
- exact commit SHAs,
- which behavior is confirmed vs assumed,
- what must not be changed,
- remaining tests,
- the single next recommended step.

Do not rely only on chat memory for project state.

## Current continuation point

The current active stack is:

`pdiddler/pdiddler_EXTREME_GUARD_TEST_STACK_v2_5.lua`

Commit:
`2a5d116786e9651df59e150e7958822ee9696e21`

Latest controlled recording was clean.

Current next step is **testing**, not speculative patching.

Priority remaining tests:
1. incoming request while another outgoing request is actively owned,
2. rapid THEIR OFFER changes during an in-progress rebalance,
3. duplicate eligible quantity x2 -> x1,
4. rare no-pending-UI -> later exact trade-open, if it naturally occurs.

Do not change the request/rotation or transactional rebalance core unless one of these tests exposes a concrete failure.


---

# 23. 2026-11-02 12:23 controlled rapid-offer-change test

Recording reviewed:
`ScreenRecording_11-02-2026 12-23-35_1.mp4`

Current build under test remained:
`pdiddler/pdiddler_OUTGOING_OWNERSHIP_FIX_TEST_STACK_v2_3.lua`
commit:
`0f8bb3536d3a073f3001e1759c07dca44fc5cbd1`

## What was confirmed

- Normal outgoing ownership path worked:
  - target `venossgaming90190`
  - pending UI was visibly confirmed around 25-26s
  - exact trade opened around 27s
  - therefore this was NOT the rare no-pending -> late-trade-open case.

- Rapid THEIR OFFER changes were exercised heavily during the active trade.

Observed opponent-side sequence included:
- repeated composition changes,
- repeated quantity changes on the same visible duplicate slot,
- notably `x3 -> x2 -> x3` style quantity changes while the slot remained present,
- adding/removing other eligible items such as Immortal / Green Luger.

Observed OUR OFFER behavior:
- old offer was cleared/rebuilt repeatedly as THEIR OFFER changed,
- no stale old plan visibly continued through the opponent changes,
- no stuck partial offer was visible,
- no repeated uncontrolled remove loop was visible,
- no final Accept was pressed.

This gives strong live evidence that:
- THEIR OFFER signature/generation reacts to quantity changes, not just visible slot count,
- rapid stable offer changes trigger replanning correctly,
- the executor can clear/rebuild repeatedly without visibly corrupting state.

Important limitation:
- the recording did not include console output proving an explicit `TX ABORT` or `RECOVERY VERIFIED` during a change that landed exactly mid-transaction.
- therefore the dedicated stale-transaction abort/recovery path is still not considered fully live-proven.
- this is still a successful rapid-replan stress test.

## Duplicate quantity test status

Partially covered:
- opponent-side duplicate quantity changes were observed on the same slot (`x3 -> x2 -> x3`).
- the script visibly reacted/replanned.

Still NOT fully covered:
- OUR SIDE exact remove verification where our own duplicate stack changes `x2 -> x1` while slot count remains unchanged.

That remains the preferred duplicate/removal verifier test.

## Other behavior

- Opponent accepted with a nonempty offer around the later portion of the trade.
- Script correctly did NOT treat nonempty accepted state as accepted-empty.
- MM2 Accept cooldown reset naturally after offer changes; no workaround was attempted.
- trade closed before the 60s Case 3 deadline and Part 3 recovered/continued.
- no duplicate resend to venoss was visible after closure.
- scanner performance pause remained intact during the active trade.
- no new bug was identified that justifies a code patch.

## Remaining priority tests after this recording

1. Incoming request from player B while an outgoing request to player A is actively owned/counting down.
2. Explicit mid-transaction opponent mutation that produces console evidence of `TX ABORT` and, if OUR side was partially modified, `RECOVERY VERIFIED`.
3. OUR SIDE duplicate stack removal `x2 -> x1` to live-test exact mutation verification.
4. Rare physical Trade tap -> no pending UI -> later exact target trade-open, if naturally reproduced.

Current recommendation remains:
**Do not modify the core from this recording. Continue controlled testing.**


---

# 24. Profit-hold strategy change — v2.4

Date: 2026-11-02

Reason:
During the 12:23 rapid-offer-change recording, THEIR OFFER increased from approximately 245 to 270 while OUR OFFER remained 230. The previous code happened to hold because +40 equaled its preferred downgrade-profit ceiling. Review showed the preferred maximum-profit normalization rule was strategically backwards for a profit-growth trader: if THEIR OFFER voluntarily increases and OUR existing offer is still safe/profitable, automatically increasing OUR OFFER gives away part of their overpay.

Current public MM2Values data continues to expose value, demand, rarity and stability/status separately, reinforcing that raw equality is not the only trade criterion. Recent MM2 community discussion also describes the common growth loop as upgrade into desirable/liquid items, then downgrade for overpay.

## Strategy decision

Remove the preferred maximum-profit normalization trigger.

New authoritative rule:
- THEIR OFFER changes are always re-read/re-evaluated.
- If OUR current offer remains valid under:
  - minimum raw-profit requirement,
  - effective/quality requirement,
  - downgrade premium,
  - big-downgrade premium,
  - controlled quality-upgrade rules,
  then KEEP OUR OFFER.
- Do not voluntarily add value merely because THEIR OFFER increased.
- Only run the combination planner when the current live offer is unsafe/underpaying or otherwise fails the trade-decision rules.

This also reduces unnecessary planner work on iPad because the 1-4 item combination DP is skipped while a current profitable offer is already valid.

## Removed obsolete logic

Removed from Part 4:
- preferredProfitCeiling()
- NormalProfitBandExtraFlat/Pct
- DowngradeProfitBandExtraFlat/Pct
- BigDowngradeProfitBandExtraFlat/Pct
- RebalanceMinValueStep
- P4 NORMALIZE PROFIT path

Retained unchanged:
- Normal minimum: max(15, 3%)
- Downgrade minimum: max(20, 6%)
- Big downgrade minimum: max(30, 8%)
- controlled quality-upgrade raw-loss cap: 3%
- transactional executor/recovery
- exact offer verification
- accepted-empty immediate decline
- 15s empty timeout
- 60s Case 3 timer
- final item-trade Accept disabled

## New Part 4 file

`pdiddler/pdiddler4_balancer_ROTATING_v2_2_PROFIT_HOLD.lua`

Commit:
`8d7d2a3ce1b543ef8cc6e7b65b4f5718fe36497c`

## New current combined stack

`pdiddler/pdiddler_PROFIT_HOLD_TEST_STACK_v2_4.lua`

Commit:
`4197968629960fd98068df9b4fac5f72cf903d50`

Current loader:

```lua
loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/main/pdiddler/pdiddler_PROFIT_HOLD_TEST_STACK_v2_4.lua",
    true
))()
```

Pins:
- Part 1 known-good unchanged
- Part 2 known-good unchanged
- scanner v6.8 critical pause unchanged
- Part 3 v15 authoritative outgoing ownership unchanged
- Part 4 v2.2 PROFIT HOLD

## Next tests

1. Confirm when THEIR OFFER increases but OUR current offer remains profitable, log/status shows PROFITABLE HOLD and OUR OFFER does not voluntarily increase.
2. Confirm when THEIR OFFER decreases enough that OUR current offer becomes unsafe, the planner still rebalances downward immediately.
3. Remaining prior tests:
   - incoming B while outgoing A is owned,
   - explicit mid-tx mutation with TX ABORT / RECOVERY VERIFIED console proof,
   - OUR duplicate x2 -> x1 removal verification,
   - rare no-pending -> late exact trade-open if naturally reproduced.

Do not freeze v2.4 until live-tested.


---

# 25. 2026-11-02 13:16 v2.4 PROFIT-HOLD live test — PASSED

Recording reviewed:
`ScreenRecording_11-02-2026 13-16-52_1.mp4`

Build under test:
`pdiddler/pdiddler_PROFIT_HOLD_TEST_STACK_v2_4.lua`

Commit:
`4197968629960fd98068df9b4fac5f72cf903d50`

Part 4:
`pdiddler/pdiddler4_balancer_ROTATING_v2_2_PROFIT_HOLD.lua`

Commit:
`8d7d2a3ce1b543ef8cc6e7b65b4f5718fe36497c`

## Main result

The new profit-hold strategy was live-proven.

In the long venoss trade:
- outgoing ownership/pending/trade-open resolved normally,
- Part 4 opened with its normal highest-item behavior,
- initial safe rebalance verified,
- then THEIR OFFER changed repeatedly,
- Part 4 repeatedly re-read/evaluated the new offer,
- OUR existing offer was kept whenever it remained safe/profitable,
- no preferred-profit normalization gave value back to the other player.

Console repeatedly showed:

`[PDIDDLER P4] PROFITABLE HOLD ... | THEIR EXTRA VALUE RETAINED | ACCEPT DISABLED`

Observed profitable-hold raw-profit examples included approximately:
- +52
- +87
- +122
- +262
- +97
- +167
- +27

The hold classification also changed appropriately as THEIR copy count/composition changed:
- DOWNGRADE
- BIG DOWNGRADE
- NORMAL

This proves the new rule is not simply ignoring THEIR OFFER changes; it is re-evaluating them and intentionally holding OUR offer when the current trade still passes safety/profit rules.

## Underpay/no-plan behavior

An earlier trade in the same recording showed the opposite safety condition:
- OUR opening offer remained much larger than THEIR offered value,
- Part 4 logged `P4 NO PLAN`,
- no unsafe replacement/final Accept occurred.

This is evidence that removing the preferred maximum-profit ceiling did not remove minimum-profit/no-plan protection.

## Performance / state-machine observations

- scanner refreshes did not run through active Part 4 trade work,
- scanner refresh resumed after trade close,
- Part 3 resumed normally after trade close,
- no duplicate resend was observed,
- final item-trade Accept remained disabled,
- no script-originating functional error was identified.

Roblox produced unrelated asset/sound load warnings/errors in the developer console; these were not from the pdiddler state machine and did not affect the tested flow.

## Still not fully live-proven

The reverse rebalancing case is still desirable:
- start from a safe/profitable OUR OFFER,
- then have THEIR OFFER drop far enough that OUR current offer no longer passes minimum-profit/quality safety,
- expected: Part 4 must stop PROFITABLE HOLD and run the planner/rebalance downward immediately.

Other remaining controlled tests:
1. incoming B while outgoing A is actively owned,
2. explicit mid-transaction mutation with console proof of `TX ABORT` / `RECOVERY VERIFIED`,
3. OUR duplicate stack x2 -> x1 exact remove verification,
4. rare no-pending UI -> later exact target trade-open if naturally reproduced.

## Confidence update

v2.4 PROFIT-HOLD behavior is now **live-tested and passed** for the intended “THEIR OFFER adds extra value” case.

Do not yet freeze the entire v2.4 stack as final known-good; remaining edge-path tests above are still outstanding.


---

# 26. Correction to 13:16 v2.4 interpretation — EXTREME PROFIT-HOLD BUG CONFIRMED

This section supersedes the earlier conclusion in section 25 that the v2.4 profit-hold behavior fully passed.

After re-reviewing the later Venoss trade frame-by-frame, a real strategy regression was confirmed.

## Exact sequence

Embedded scanner values:
- Boneblade = 8
- Green Luger = 25
- Iceblaster = 35

Observed:
1. OUR opening item was initially Chroma Watergun.
2. Venoss offered Green Luger (25).
3. Planner correctly replaced the opening item with Boneblade (8):
   - THEIR 25 - OUR 8 = +17
   - valid normal-profit trade.
4. Venoss then kept increasing THEIR eligible offer while OUR OFFER remained Boneblade (8).

Examples:
- Green Luger 25 + Iceblaster 35 = 60 -> OUR 8 -> +52
- Green Luger 25 + Iceblaster x2 70 = 95 -> OUR 8 -> +87
- Green Luger 25 + Iceblaster x3 105 = 130 -> OUR 8 -> +122

Console profits such as +52, +87, +122, +167, +262 align with this behavior.

A green-label Sunset was also visible in some frames but is outside the current Godly/Ancient/Chroma eligible pool, so it was not the cause of the hold.

## Root cause

v2.4 removed the preferred-profit normalization path entirely and changed the logic to:

- if OUR current offer is still technically safe/profitable,
- immediately PROFITABLE HOLD,
- skip alternate-plan search.

That is too broad.

It correctly preserves moderate overpay, but it also preserves absurd one-sided trades such as THEIR 130 vs OUR 8.

The script DID detect THEIR OFFER changes. The bug is the strategy decision after detection.

## Correct direction

Do NOT simply restore the old preferred-profit ceiling unchanged, because that would again give back moderate overpay such as OUR 230 vs THEIR 270 (+40).

Instead introduce an **extreme-overpay / participation guard**:

- moderate extra value from THEIR side -> keep OUR offer,
- extreme ratio / implausibly tiny OUR side -> run planner again,
- planner should move OUR side upward to the highest safe plan while still preserving required profit/downgrade premium,
- minimum-profit, demand/quality, transaction recovery, and final-Accept lock remain unchanged.

Preferred implementation direction:
- use a relative ratio / extreme-one-sided threshold rather than the old small fixed profit ceiling,
- e.g. detect when OUR raw offer is only a small fraction of THEIR eligible raw offer,
- then re-run the safe-plan search.

Do not choose the exact threshold without reviewing the current planner and testing representative cases.

## Status correction

v2.4 is **NOT ready to freeze**.

The new profit-hold rule passed moderate-overpay intent but failed the extreme-overpay case.

Next coding task, once authorized:
replace unconditional profitable hold with:
1. safe/profitable check,
2. extreme-one-sided check,
3. HOLD if moderate,
4. REPLAN upward if extreme.


---

# 27. v2.5 EXTREME GUARD fix for Boneblade-stuck regression

Date: 2026-11-02

This fixes the regression confirmed in section 26 where OUR OFFER could remain Boneblade = 8 while THEIR OFFER grew from 25 to 60/95/130+.

## Root cause

v2.4 treated any technically profitable current offer as a permanent PROFITABLE HOLD and skipped alternate-plan search.

That correctly preserved moderate overpay, but it also let absurdly one-sided trades persist.

## New rule

Moderate overpay still holds.

A technically profitable trade becomes an **EXTREME REPLAN** candidate only when BOTH are true:

1. THEIR raw value is at least 2.0x OUR raw value.
2. Raw and effective profit are each at least:
   `max(50, requiredProfit * 2.5)`

Constants:
- `ExtremeReplanRatio = 2.0`
- `ExtremeProfitFlat = 50`
- `ExtremeProfitMultiple = 2.5`
- `ExtremeMinReplanStep = 5`

If extreme:
- run the existing safe 1-4 item planner,
- only move OUR side upward if the new plan adds at least 5 raw value and reduces the excessive profit gap by at least 5,
- still require all normal safety / downgrade / quality rules,
- if no higher safe plan exists, keep the current safe offer and log `EXTREME HOLD`.

## Representative cases

Expected:
- THEIR 25 vs OUR 8 = +17 -> HOLD
- THEIR 270 vs OUR 230 = +40 -> HOLD
- THEIR 60 vs OUR 8 = +52 -> EXTREME REPLAN
- THEIR 95 vs OUR 8 = +87 -> EXTREME REPLAN
- THEIR 130 vs OUR 8 = +122 -> EXTREME REPLAN

This avoids restoring the old small preferred-profit ceiling.

## New Part 4 file

`pdiddler/pdiddler4_balancer_ROTATING_v2_3_EXTREME_GUARD.lua`

Commit:
`41372d75f053cb125c12847188966a10d51d1f10`

## New current test stack

`pdiddler/pdiddler_EXTREME_GUARD_TEST_STACK_v2_5.lua`

Commit:
`2a5d116786e9651df59e150e7958822ee9696e21`

Loader:

```lua
loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/main/pdiddler/pdiddler_EXTREME_GUARD_TEST_STACK_v2_5.lua",
    true
))()
```

## Regression audit

Confirmed unchanged in Part 4:
- normal minimum: max(15, 3%)
- downgrade minimum: max(20, 6%)
- big downgrade minimum: max(30, 8%)
- controlled quality-upgrade cap: 3%
- 15s empty timeout
- 60s Case 3 window
- transaction abort / protected recovery
- accepted-empty immediate decline
- no `AcceptTrade`
- no `AcceptRequest`
- final item-trade Accept disabled.

## Next live test

Highest priority:
reproduce the Boneblade sequence.

Expected progression:
- Green Luger 25 vs Boneblade 8 -> HOLD
- add Iceblaster so THEIR total becomes 60 -> EXTREME REPLAN
- OUR side should visibly increase to the highest safe planner result instead of remaining Boneblade 8.

Also verify that a moderate case such as OUR 230 vs THEIR 270 stays held.

Do not freeze v2.5 until this exact behavior is confirmed live.


---

# 28. Recording-review rule — regressions first, not success-only

Date: 2026-11-02

From this point forward, every MM2 test recording must be reviewed as a **regression/error hunt**, not merely as confirmation that expected behavior occurred.

For every video:
1. Confirm the intended test behavior.
2. Independently scan the entire recording for unrelated regressions.
3. Compare against the last known-good behavior/build.
4. Inspect moments where:
   - OUR OFFER does not change when THEIR OFFER changes,
   - THEIR OFFER changes but planner state appears stale,
   - values/quantities/classification do not match visible items,
   - pending/request ownership appears inconsistent,
   - trade partner/session changes,
   - scanner refreshes during critical phases,
   - duplicate send/decline/rebalance/remove actions occur,
   - timers reset unexpectedly or fail to reset,
   - old callbacks act on a new trade/session,
   - UI disappears/reappears and state does not recover,
   - a transaction partially modifies OUR OFFER,
   - a plan remains technically profitable but strategically wrong,
   - an error/warning appears in console even if the visible flow continues.

Do not treat a passing target scenario as proof that the whole build passed.

For each recording, explicitly separate:
- confirmed successes,
- confirmed bugs/regressions,
- suspicious behavior requiring more evidence,
- untested paths.

If a suspicious behavior is visible, trace the full pipeline:
visible UI -> parsed identity/quantity -> value resolution -> trade classification -> planner decision -> executor mutation -> verification -> recovery.

Do not patch until the root cause is identified, but do not dismiss anomalous behavior merely because the main test passed.

The 13:16 v2.4 recording is the example motivating this rule:
the intended PROFITABLE HOLD behavior appeared to pass, but a deeper review showed OUR OFFER could remain Boneblade 8 while THEIR OFFER grew to 60/95/130+, exposing the extreme-profit-hold regression.


---

# 29. 2026-11-02 13:48 v2.5 EXTREME GUARD live test — PASSED

Recording reviewed:
`ScreenRecording_11-02-2026 13-48-51_1(1).mp4`

Build under test:
`pdiddler/pdiddler_EXTREME_GUARD_TEST_STACK_v2_5.lua`

Commit:
`2a5d116786e9651df59e150e7958822ee9696e21`

Part 4:
`pdiddler/pdiddler4_balancer_ROTATING_v2_3_EXTREME_GUARD.lua`

Commit:
`41372d75f053cb125c12847188966a10d51d1f10`

## Main result — EXTREME GUARD passed

The exact v2.5 strategy change was live-proven.

Console evidence during the Venoss trade included:

- `EXTREME REPLAN ... ours 20 theirs 105 rawProfit 85 ratio 5.25 ... newOur 90 targetProfit 15`
  -> followed by `REBALANCE VERIFIED ... kind NORMAL ... rawProfit 15`.

- `EXTREME REPLAN ... ours 90 theirs 270 rawProfit 180 ratio 3 ... newOur 250 targetProfit 20`
  -> followed by `REBALANCE VERIFIED ... kind DOWNGRADE ... rawProfit 20`.

- Later extreme cases also triggered replanning, including approximately:
  - ours 120 vs theirs 245 -> newOur 230
  - ours 113 vs theirs 245 -> newOur 230

This proves OUR OFFER no longer stays stuck at an implausibly tiny item when THEIR OFFER grows far beyond it.

Moderate overpay was still retained:
- `PROFITABLE HOLD` appeared at approximately +52 and +62 raw profit when the extreme ratio/threshold combination was not met.
- Therefore v2.5 preserves the intended distinction:
  - moderate extra value -> HOLD,
  - extreme one-sided trade -> REPLAN upward.

## Transaction abort / recovery path — now live-proven

This recording also provided the previously missing explicit transactional evidence.

Observed console sequences included:
- `TX ABORT ... opponent offer changed | modified true`
- `RECOVERY VERIFIED ... our offer cleared`
- fresh `REBALANCE VERIFIED` afterward.

This happened multiple times during rapid Venoss offer changes.

Therefore the stale-transaction protection is now live-proven for:
1. detecting opponent mutation during an active transaction,
2. aborting the stale transaction,
3. clearing OUR partially modified offer,
4. verifying recovery,
5. replanning from the new opponent state.

No stuck partial plan, uncontrolled double-remove loop, or stale plan continuation was observed.

## Reverse/downward replanning evidence

The recording also showed THEIR OFFER dropping/changing enough to invalidate the currently planned state.

Part 4 stopped holding the prior plan and produced fresh verified rebalances, including NORMAL / UPGRADE / DOWNGRADE classifications as the opponent composition changed.

This gives strong live evidence that v2.5 is not only adding value upward on extreme overpay; it also re-evaluates and reduces/rebuilds OUR OFFER when THEIR OFFER moves the other direction.

## 60-second Case 3 boundary

The Venoss trade reached the authoritative 60-second Case 3 boundary.

Console showed:
- `DECLINE 60s Case 3 rotation boundary`
- `TRADE RESULT offer-window-timeout-declined`
- Part 3 resumed the queue afterward.

The timer did not visibly restart because of intermediate offer changes.

## Other regression checks

Confirmed:
- scanner critical-phase pause remained intact during active Part 4 work,
- Part 3 resumed after trade close,
- subsequent players were processed,
- no duplicate resend regression was observed,
- final item-trade Accept remained disabled,
- accepted UI state was never automatically pressed,
- no pdiddler-originating runtime error was visible.

Developer Console showed 0 errors from the tested script. A separate MM2/game warning about an Infinite Yield / missing `Buy` child was visible and is not part of the pdiddler state machine.

## Remaining unproven / priority tests

Still not fully live-proven:
1. incoming player B while outgoing player A is actively owned/counting down,
2. OUR SIDE duplicate stack exact removal x2 -> x1 while the visible slot remains,
3. rare physical Trade tap -> no pending UI -> later exact target trade-open with no prior pending confirmation.

The previous rapid-opponent-quantity test already covered THEIR-side quantity changes; the remaining duplicate test is specifically OUR-side removal verification.

## Confidence update

v2.5 EXTREME GUARD is now live-tested and passed for its primary regression:
- moderate profitable overpay is retained,
- extreme one-sided profitable states trigger a safe upward replan.

The transactional `TX ABORT -> RECOVERY VERIFIED` path is also now live-proven.

No code patch is justified from this recording.

Do not yet freeze the entire stack as final known-good until the remaining ownership and OUR-side duplicate-removal edge tests are covered, unless the user explicitly chooses to freeze it sooner.


---

# 30. MM2 request-window behavior correction

Date: 2026-11-02

User clarified an important native MM2 behavior:

- While OUR outgoing trade request is actively pending/owned, another player cannot meaningfully overwrite that request by sending us a new incoming trade request.
- The incoming-request window only becomes available after our outgoing request is canceled/resolved and MM2 returns to a state where incoming requests can be shown.

Therefore the previously listed controlled test:
"player B sends an incoming request while outgoing request to player A is actively owned/counting down"

is not a valid MM2 live scenario and should be removed from the priority test list.

This is a game-level UI/state restriction, not something Part 3 needs to defend against during an active outgoing request.

Updated remaining priority edge tests:
1. OUR SIDE duplicate eligible quantity x2 -> x1 removal verification while the visible slot remains.
2. Rare physical Trade tap -> no pending UI -> later exact target trade-open, if naturally reproduced.
3. Continue regression-first review of any future recordings for request/rotation, stale callbacks, trade-close recovery, planner/executor, and scanner contention.

Do not add speculative code for an impossible incoming-overwrites-active-outgoing case.


---

# 31. Wide trading-profit research pass

Date: 2026-11-02

Before any further trading-logic changes, a broad research pass was completed across:
- Supreme Values current use guide / godly list / changelog,
- MM2Values.com,
- MM2 Trade Hub current trade feed, demand guides, weekly market reports and item activity,
- Neblio's 2026 trading guide,
- Reddit MM2 trading discussions from 2024-2026,
- recent YouTube MM2 trading-guide content and older demand/overpay guides,
- Traderie/current community trade-list context where available.

No code was changed from this research alone.

## Core strategy conclusions

1. Raw value is only the starting point.
   Demand, stability, rarity, current trading range, list disagreement, and actual trade activity materially affect whether an item is good inventory.

2. The strongest repeated profit loop remains:
   upgrade -> acquire a desirable/liquid item -> downgrade for overpay -> repeat.

3. A small paper loss can be strategically correct when consolidating low-demand pieces into a materially more liquid item.
   Conversely, a raw-value win can be strategically bad if it leaves us holding hard-to-move, falling, or over-supplied items.

4. "Value" and "exit quality" must be separated.
   A trade should be evaluated not only on what we gain immediately, but on how easily the received inventory can be moved again.

5. Demand should influence both:
   - how much we are willing to pay to upgrade into an item,
   - how much premium we require when downgrading out of an item.

6. Stability/status must affect risk:
   - Rising / Overpaid For / Doing Well / Improving are generally desirable acquisition states.
   - Stable is neutral.
   - Fluctuating requires extra caution and current verification.
   - Underpaid For / Decreasing / Unsafe should not be treated as equal to stable inventory merely because the base number is high.

7. Current market activity is a useful liquidity signal beyond static demand scores.
   "Asked for" vs "Offered" counts and typical solo asking premiums can reveal whether holders have bargaining power.

8. Do not average conflicting value lists.
   Compare both sides consistently on MM2Values and Supreme. If the trade verdict changes materially between lists, treat it as uncertain/risky and require a larger safety margin.

9. New-event items are especially dangerous during initial hype.
   The Halloween 2026 Ember items collapsed rapidly after supply entered the game:
   - Emberbow fell from 1,700/1,900 territory to ~325,
   - Emberscythe fell from ~1,900 to ~300,
   - related chromas also fell sharply.
   This is a strong live example that fresh event scarcity should not be treated as durable value.

10. Current 2026 examples of liquid/desired trade material include items with strong ask activity such as:
   - Harvester,
   - Icepiercer,
   - Snowcannon,
   - Bat,
   - Candy,
   while some recently released/falling items show much more supply than demand.

11. The current planner should eventually distinguish:
   - RAW PROFIT,
   - LIQUIDITY/EXIT QUALITY,
   - STABILITY RISK,
   - UPGRADE QUALITY,
   - DOWNGRADE PREMIUM,
   rather than compressing everything into one number.

12. For low-tier items, demand differences are often weak enough that raw value matters more.
   For mid/high-tier items, demand/stability/marketability matter much more and can justify small controlled deviations from base-value equality.

13. Negotiation/offer logic from experienced-trader guides consistently favors:
   - begin with the lowest reasonable offer,
   - preserve room to move,
   - do not voluntarily give away opponent overpay,
   - when upgrading, pay only the minimum necessary premium,
   - when downgrading a desirable item, seek stronger overpay.

14. More items is not automatically better.
   A downgrade into many low-demand pieces can be worse than receiving fewer liquid pieces.
   "Inventory growth" should mean more usable trade material, not merely a larger item count.

15. Sets can carry extra practical demand because some traders specifically seek complete sets, but set desirability is market-dependent and should not be hard-coded without current evidence.

16. Server hopping / broad exposure remains an important practical profit driver.
   Community advice repeatedly notes that better trades often come from seeing more traders rather than forcing a marginal deal with the current partner.

## Current market observations relevant to future planner changes

- Harvester:
  high trade volume; often asked for more than offered; strong practical liquidity despite only moderate static demand.
- Icepiercer:
  asked for substantially more often than offered; holder has meaningful bargaining power.
- Snowcannon:
  stable, healthy demand, strong ask activity, relatively easy to move.
- Bat:
  relatively strong ask activity compared with supply, often listed with a premium.
- Heart Wand:
  balanced offer/ask activity and stable market behavior.
- Emberbow / Emberscythe:
  recently crashed, marked Underpaid For, and show buyer-favorable market conditions.
  Their listed value should not be treated as equally safe inventory to a stable/liquid item at the same number.
- Raygun / Alienbeam:
  current stable/high-demand examples with recent positive movement.
- Darkshot / Darksword:
  high headline value but currently Underpaid For; do not treat them as equivalent-quality inventory to stable items at the same base value.

## Implication for the script

Do NOT immediately patch the planner from this research alone.

Before code changes:
1. inspect the exact current Part 4 planner,
2. identify what market-quality data is already available in the canonical value system,
3. decide which signals can be sourced reliably at runtime without introducing brittle web dependencies,
4. preserve deterministic behavior on iPad/Delta,
5. avoid making a second independent value system,
6. prefer a small, explicit market-quality layer over a large opaque scoring formula,
7. keep all final-Accept protection unchanged.

Likely future direction:
- keep canonical MM2 numeric value as the hard safety floor,
- add a bounded quality/liquidity modifier for comparing otherwise-safe plans,
- apply stronger penalties to falling/underpaid/fluctuating inventory,
- reward stable/high-demand/high-liquidity inventory,
- require more overpay when accepting a downgrade into weaker exit-quality items,
- allow small controlled raw loss only when the received side is materially better quality/liquidity.

This research changes strategy confidence, but does not itself authorize a code patch.


---

# 32. Expanded Reddit / YouTube trading research

Date: 2026-11-02

A second wide research pass was completed across additional Reddit threads and YouTube trading/challenge content.

No code changed from this research alone.

## Additional conclusions

1. The largest practical bottleneck is not arithmetic; it is finding counterparties.
   Multiple current Reddit threads describe MM2 trading as patience-heavy:
   - repeated server hopping,
   - checking many inventories,
   - waiting for someone whose goals line up with yours.
   The script should therefore prefer declining mediocre/no-plan situations and moving on rather than forcing a marginal trade.

2. Mid-tier inventory is a known friction zone.
   Community reports commonly describe fast early gains from low tiers, then slower progress once players reach roughly 30-40+ value because counterparties are more value-aware.
   This supports having different strategy behavior by inventory tier rather than one universal profit rule.

3. Low-tier acceptance is partly aesthetic / quantity-driven.
   Several traders report that attractive-looking items, stacks, and multiple small adds can be easier to move than mathematically equivalent unattractive pieces.
   This is evidence for a bounded "marketability" concept, but aesthetics should not be hard-coded without reliable data.

4. "Never settle for less" has an important exception:
   if an owned item is actively dropping, a small loss to escape it can be strategically correct.
   Likewise, a small loss to upgrade into a much more liquid item can be recoverable later.

5. Community advice repeatedly converges on:
   - slight overpay to acquire a strong/liquid upgrade,
   - then seek overpay when downgrading that strong item,
   - keep part of the spread/profit,
   - repeat.

6. Creator / montage bias is real.
   Many YouTube MM2 trading videos are explicitly framed as:
   - "only wins",
   - "insane overpays",
   - "huge profit",
   - common-to-godly / godly-to-harvester challenges.
   These are useful for seeing possible trade structures, but are not reliable estimates of normal acceptance rates or average achievable profit.
   The script should not tune thresholds to spectacular montage trades.

7. Famous-creator / launch-day trades can be especially misleading.
   Current Reddit discussion around newly released Beachy items notes massive first-hours overpays collapsing within a day.
   Therefore:
   - early event hype must be treated as unstable,
   - YouTube clips recorded near launch are not durable market evidence.

8. Current community examples reinforce "exit value":
   - items that are technically wins can still be called bad because they are hard to trade,
   - traders sometimes deliberately accept a slight underpay to exit a hard-to-move item,
   - "flippable" inventory is repeatedly valued above static arithmetic.

9. Value trajectory risk matters.
   Community traders describe:
   - buying underpaid items cheaply and flipping if they stabilize,
   - avoiding items that have sat in "Doing Well" for several updates if they appear near a peak,
   - preferring stable staples when they do not want directional risk.
   This supports treating trend/status as risk, not as guaranteed future value.

10. List values are not enough to estimate acceptance.
    A trade can be mathematically fair and still repeatedly fail because:
    - the desired item has higher demand,
    - the offered pieces are hard to move,
    - the counterparty prefers one large item or multiple small items,
    - current market sentiment differs from the list.

11. The planner should eventually distinguish between:
    - theoretical W,
    - executable W,
    - strategic W.
    A theoretical W is positive raw value.
    An executable W uses items people actually accept.
    A strategic W leaves inventory easier to trade again.

12. Community "server hopping" advice directly supports the existing rotation architecture.
    If no safe plan exists, skipping that partner and seeing more players can have higher expected profit than relaxing safety rules.

13. Some community methods rely on exploiting players who do not know values.
    This should NOT become an automated targeting rule.
    The bot should evaluate the offer itself, not profile or deliberately seek inexperienced players.

14. More research also strengthens the rule that low-demand pieces should require a larger downgrade premium.
    If we exchange one liquid item for several weak pieces, raw +15/+20 may not adequately compensate for the future trading friction.

## YouTube-specific lessons

Useful categories observed:
- Common-to-Godly challenges:
  demonstrate many sequential small upgrades and the importance of repeated exposure.
- Godly-to-Harvester / Common-to-Gingerscope style challenges:
  show that long growth paths are usually chains of flips, not one giant trade.
- "What do people offer for X" videos:
  useful as historical examples of willingness-to-pay, but only when time-aligned with the current market.
- Trading montages:
  useful for trade structure ideas, but strongly selected toward wins and should not be used to set expected-profit thresholds.

## Strategy refinement candidate

Before any implementation:
- keep raw-value rules as hard safety constraints,
- classify received inventory by exit quality,
- require more profit when downgrading into weaker / harder-to-move pieces,
- allow tiny controlled losses for clearly stronger/liquid upgrades,
- add stronger caution for falling, underpaid, new-release, and highly fluctuating items,
- do not use YouTube montage outcomes as baseline expected returns,
- preserve server rotation as a core profit strategy when no good counterparty exists.

No patch authorized yet.


---

# 33. Current value recheck

Date: 2026-11-02

A fresh public-value recheck was completed before any further planner changes.

## MM2Values authoritative project source

MM2Values currently reports:
`VALUES UPDATED: 10/31/2026 12:31:12pm EST`

The active scanner:
`pdiddler/pdiddler3_scanner_MODULE_v6_8_CRITICAL_PAUSE.lua`

contains:
`VALUE_SNAPSHOT_UPDATED="2026-10-31 12:31:12 EST"`

and its embedded canonical values match the latest MM2Values publication for the checked high-tier/trade-eligible rows.

Verified examples:
- Gingerscope 15,250
- Travelers Axe 7,700
- Celestial 1,950
- Vampires Axe 1,375
- Emberbow 325
- Emberscythe 300
- Harvester 250
- Icepiercer 165
- Icebreaker 70
- Batwing 45
- Chroma Alienbeam 23,000
- Chroma Raygun 12,500
- Chroma Emberscythe 10,000
- Chroma Sunset gun/internal duplicate 8,250
- Chroma Snowcannon 7,650
- Chroma Sunset knife 5,500
- Chroma Blizzard 5,500
- Chroma Emberbow 4,450
- Chroma Snowstorm 4,250
- Chroma Heart Wand 3,400
- Chroma Snow Dagger 2,400
- Chroma Watergun 2,350
- Chroma Icecream 1,875
- Chroma Treat 1,800
- Chroma Sweet 1,750
- Chroma Sands 1,325
- Chroma Beachy 1,275
- Chroma Embersickle 1,100
- Alienbeam 1,850
- Raygun 1,825
- Darkshot 1,550
- Darksword 1,525
- Sunrise 775
- Snowcannon 680
- Bauble 675
- Sunset 650
- Heart Wand 350
- Immortal 140
- Mortal 140
- Bat 120
- Candy 90
- Embersickle 80
- Heartblade 65
- Ornament 60
- Green Luger 25

Conclusion:
The active v6.8 scanner value snapshot is not stale relative to MM2Values' latest published update. No value-table patch is justified at this time.

## Supreme Values cross-check

Supreme currently disagrees on several important items, including:
- Gingerscope 15,750 vs MM2Values 15,250
- Travelers Axe 7,500 vs 7,700
- Vampires Axe 1,425 vs 1,375
- Emberbow 375 vs 325
- Emberscythe 375 vs 300
- Harvester 250 vs 250
- Icepiercer 160 vs 165
- Chroma Watergun 2,300 vs 2,350
- Alienbeam 1,900 vs 1,850
- Raygun 1,875 vs 1,825
- Darkshot 1,500 vs 1,550
- Darksword 1,475 vs 1,525

Project rule remains:
MM2Values is the canonical numeric source for trade math.
Supreme/current market data may inform quality/liquidity/risk, but must not silently overwrite canonical MM2Values numbers.

No code changed from this recheck.


---

# 34. v2.5 planner audit before market-aware redesign

Date: 2026-11-02

Exact source audited:
`pdiddler/pdiddler4_balancer_ROTATING_v2_3_EXTREME_GUARD.lua`

No code changed during this audit.

## Existing planner architecture

The current Part 4 already has a small market-quality layer:

- `exactQuality(it)`
- `evaluateSide(...)`
- `qualityRatio(...)`
- `tradeDecision(...)`
- `buildPlans(...)`

Current quality modifiers:
- Overpaid For: +5%
- Doing Well: +3%
- Stable: 0%
- Fluctuating: -2%
- Underpaid For: -8%

Only a small explicit item set is profiled.
All other eligible items currently default to:
`{mult=1, tag="Stable", verified=true}`

That default is now considered too optimistic for the proposed market-aware planner.

## What already works and should be preserved

1. Canonical scanner identity/value resolution.
2. MM2Values numeric values from the scanner.
3. Exact offer identity/quantity evaluation.
4. Raw-value minimum profit floors.
5. Controlled <=3% quality-upgrade exception.
6. 1-4 item planner.
7. Planner preference for highest safe raw offer rather than cheapest exploitable offer.
8. Moderate profitable hold.
9. v2.5 EXTREME GUARD.
10. Transaction generation/signature checks.
11. TX ABORT / recovery / protected hold.
12. Exact remove/apply verification.
13. 15s empty and 60s Case 3 timers.
14. Final Accept disabled.

The executor/verifier/recovery path should not be redesigned for market-awareness.

## Exact places market-aware work belongs

Primary planner changes should be isolated to:
- market profile lookup replacing/expanding `exactQuality`,
- side evaluation metadata inside `evaluateSide`,
- safety/quality decision inputs in `tradeDecision` / `requiredProfit`,
- plan candidate ranking in `buildPlans`,
- EXTREME GUARD may consume the new conservative decision totals but its behavioral rule should remain unchanged.

## Current strengths confirmed by offline cases

- A real quality upgrade can already pass with a small raw loss:
  example: OUR 100 effective 100 -> THEIR 98 effective 102.9, 2 copies -> 1 copy, passes as quality-upgrade.
- Known Underpaid-For inventory already receives some protection:
  OUR stable 100 -> THEIR 130 raw spread across 3 underpaid pieces at 0.92 effective multiplier fails because effective profit is only 19.6 while 30 is required.
- Moderate overpay remains valid:
  OUR 230 -> THEIR 270 remains a profitable hold candidate.
- Extreme one-sided profit remains detected:
  OUR 20 -> THEIR 105 passes base profit and is eligible for EXTREME REPLAN.

## Main gaps found

### A. Missing market metadata is incorrectly treated as verified Stable

Example:
OUR stable 100 -> THEIR 130 across 3 unprofiled items currently passes a BIG DOWNGRADE at +30 because unprofiled items default to Stable.

The same trade with known Underpaid-For metadata fails.

This means missing information can currently be treated as safer than known negative information.

Future rule:
unprofiled != Stable.
Use neutral numeric behavior for raw safety, but mark quality metadata unverified and never grant positive quality-upgrade credit from missing metadata.

### B. No Supreme/MM2Values disagreement model

Current Part 4 receives only scanner MM2Values numeric value plus the small stability multiplier table.

It cannot distinguish:
- Supreme higher than MM2Values,
- Supreme lower than MM2Values,
- major source disagreement.

Future profile should retain both numbers rather than average them.

### C. Downgrade premium is mostly copy-count based

`requiredProfit` currently classifies:
- NORMAL,
- DOWNGRADE,
- BIG DOWNGRADE

based primarily on our/their eligible copy counts.

Weak received inventory affects effective profit through multipliers, but there is no explicit additional downgrade premium based on exit-quality weakness, volatility, or source disagreement.

Future design should allow weaker received inventory to increase the required premium.

### D. Quality table coverage is sparse

The current table was intentionally partial.
Most eligible items are not explicitly characterized by demand, liquidity, trend, or list disagreement.

### E. Current "effective value" compresses too much into one multiplier

Research now supports keeping separate concepts:
- canonical/MM2Values value,
- Supreme market value,
- demand/liquidity,
- stability/status,
- source disagreement/confidence.

These should not all be hidden inside one opaque multiplier.

## Proposed market-profile shape

Part 4 can remain separate from the scanner and key profiles by the scanner's canonical item ID/name.

Candidate fields:
- supremeValue
- demand
- status
- liquidity
- sourceUpdated
- profiled
- disagreementPct
- trend/risk class

Scanner `item.value` remains canonical MM2Values and canonical identity stays untouched.

## Conservative cross-source safety direction

Do not average MM2Values and Supreme.

For trade safety, candidate future logic:
- OUR item: protect against giving away too much by considering the higher supported valuation.
- THEIR item: protect against over-crediting what we receive by considering the lower supported valuation.
- Missing Supreme data falls back to MM2Values but carries lower market-confidence, not a fake Stable classification.

Supreme can be used as the primary market reference/ranking context while MM2Values remains the canonical scanner number and safety cross-check.

Exact thresholds must be tested before implementation.

## Required pre-build test matrix

Before creating v2.6, validate at least:
1. same raw value, different liquidity,
2. <=3% raw-loss upgrade into clearly stronger inventory,
3. profitable downgrade into weak/underpaid pieces,
4. large Supreme/MM2Values disagreement,
5. falling/new-event item,
6. moderate opponent overpay,
7. extreme opponent overpay,
8. THEIR OFFER decrease after profitable hold,
9. missing market metadata,
10. mixed good/bad bundle,
11. multiple equal-raw plan candidates with different exit quality.

Current conclusion:
market-awareness can be added without touching the proven transactional executor.
The next implementation step should be a complete, frozen market-profile snapshot plus offline decision-matrix validation, not an immediate live-script patch.


---

# 35. Complete 190-item market snapshot audit

Date: 2026-11-02

A complete audit-only market profile snapshot has now been created.

File:
`pdiddler/pdiddler_market_snapshot_2026-11-02_AUDIT_v2_COMPLETE.lua`

Commit:
`9bd3b528a681e8a2215aa84b61271fdd3e5d6acd`

Important:
- `liveReady=false`
- not wired into v2.5,
- does not alter scanner/planner/executor behavior,
- intended only for offline audit and decision-matrix work.

## Coverage

Exact scanner-eligible population:
- Ancient: 16 / 16
- Chroma weapons: 46 / 46
- Godly: 128 / 128
- Total: 190 / 190

Static coverage audit:
- 190 scanner rows,
- 190 snapshot rows,
- 190 unique profile keys,
- 0 missing,
- 0 duplicate keys,
- 0 extra keys,
- 0 MM2Values-value mismatches versus the active v6.8 scanner.

Key format:
`page:id`

This prevents accidental cross-page ID collisions.

## Source timestamps

MM2Values values:
- active scanner snapshot: 2026-10-31 12:31:12 EST.

Supreme:
- current Ancient/Godly/Chroma pages report:
  2026-11-02 12:34 PM.

Supreme therefore changed after the earlier value-recheck work and is currently the fresher market snapshot.

## Snapshot fields

Each profiled item currently stores:
- scanner page,
- canonical scanner id,
- canonical/profile name,
- MM2Values value,
- Supreme value or label,
- Supreme demand,
- Supreme stability/status,
- calculated MM2Values/Supreme disagreement percentage,
- verified/profiled flags.

No market multiplier is applied yet.

## Audit distribution

Stability/status counts across the 190 eligible entries:
- Stable: 174
- Underpaid For: 5
- Fluctuating: 8
- Doing Well: 2
- Overpaid For: 1 (Nik's Scythe)

Demand distribution:
- D1: 112
- D2: 4
- D3: 15
- D4: 7
- D5: 38
- D6: 9
- D7: 3
- D8: 1
- D11: 1

## Source disagreement findings

80 / 190 items differ by at least 5% between MM2Values and Supreme.
46 / 190 differ by at least 10%.

Important caveat:
percentage disagreement alone is misleading at low values.
Examples like 5 vs 7 produce a 40% difference while changing the trade by only 2 raw value.

Therefore future disagreement-risk logic should consider BOTH:
- percentage difference,
- absolute value difference / material effect on the trade.

Material examples with at least 25 absolute value and >=5% disagreement include:
- Chroma Mortal: MM2 1800 vs Supreme 1600
- Chroma Immortal: MM2 1800 vs Supreme 1600
- Chroma Embersickle: MM2 1100 vs Supreme 1300
- Chroma Sands: MM2 1325 vs Supreme 1225
- Chroma Beachy: MM2 1275 vs Supreme 1175
- Emberscythe: MM2 300 vs Supreme 375
- Emberbow: MM2 325 vs Supreme 375

These are stronger candidates for explicit uncertainty handling than tiny low-tier disagreements.

## Current next step

Run the offline decision matrix using this complete snapshot before any new Part 4 build.

Required cases remain:
1. same raw value, different liquidity/demand,
2. <=3% raw-loss upgrade into clearly stronger inventory,
3. profitable downgrade into weak/underpaid pieces,
4. material Supreme/MM2Values disagreement,
5. falling/new-event item,
6. moderate opponent overpay,
7. extreme opponent overpay,
8. THEIR OFFER decrease after profitable hold,
9. missing metadata fallback behavior,
10. mixed good/bad bundle,
11. equal-raw candidate plans with different exit quality.

Do not wire this snapshot into live trading until those decisions are explicitly validated.


---

# 36. v2.6 market-aware planner design approved approach / pending design approval

Date: 2026-11-02

The user selected Approach C: Hybrid Market-Aware Planner.

Design document:
`docs/superpowers/specs/2026-11-02-mm2-market-aware-planner-design.md`

Design commit:
`f0d83656c05cc66a1b550544c7554e5041fbc0d9`

No live code changed.

The design preserves:
- Parts 1-3,
- scanner canonical identity/MM2Values baseline,
- Part 4 transaction executor,
- TX ABORT/recovery,
- 15s/60s timers,
- moderate profitable hold,
- EXTREME GUARD,
- FINAL ACCEPT disabled.

The design defines a 14-case offline decision matrix covering:
- same raw/different quality,
- controlled <=3% quality upgrade,
- weak downgrade,
- material list disagreement,
- unstable event inventory,
- moderate overpay,
- extreme overpay,
- opponent decrease after hold,
- missing metadata,
- mixed bundles,
- equal-raw candidate ranking,
- low-tier high-percentage/tiny-absolute disagreement,
- high-value absolute disagreement,
- unknown/ambiguous market identity.

Next required step after explicit design approval:
use the Superpowers writing-plans workflow, then implement the offline matrix/tests before any live planner integration.


---

# 37. Offline market decision matrix implementation plan

Date: 2026-11-02

User approved the v2.6 Hybrid Market-Aware Planner design.

Implementation plan:
`docs/superpowers/plans/2026-11-02-mm2-market-decision-matrix-plan.md`

Plan commit:
`e37b4a13e099c1884e6023fd2567eead09f7e624`

Scope is intentionally limited to offline market logic and deterministic tests.

Pinned candidate rules include:
- material list disagreement only when absolute difference >=25 AND percentage difference >=5%,
- OUR disputed items protect high; THEIR disputed items credit low,
- demand/status scoring,
- downgrade risk premium capped at +10% of OUR protected value,
- quality-upgrade exception remains <=3% raw loss,
- no positive quality credit from missing/incomplete metadata,
- deterministic plan ranking,
- no live Part 4 integration in this plan.

Planned new files:
- `pdiddler/pdiddler_market_profile_2026-11-02_v1_CANDIDATE.lua`
- `pdiddler/pdiddler4_market_logic_v1_TEST.lua`
- `pdiddler/tests/pdiddler_market_profile_audit_v1.lua`
- `pdiddler/tests/pdiddler4_market_logic_matrix_v1.lua`
- `pdiddler/MARKET_MATRIX_RESULTS_v1.md`

Explicit stop condition:
after offline matrix verification, stop. Do not wire the model into v2.5 until a separate integration plan is approved.


---

# 38. Offline market matrix implementation results

Date: 2026-11-02
Branch: `feature/mm2-market-matrix-v1`

Results:
`pdiddler/MARKET_MATRIX_RESULTS_v1.md`

Key implementation files:
- `pdiddler/pdiddler_market_profile_2026-11-02_v1_CANDIDATE.lua`
- `pdiddler/pdiddler4_market_logic_v1_TEST.lua`
- `pdiddler/tests/pdiddler_market_profile_audit_v1.lua`
- `pdiddler/tests/pdiddler4_market_logic_evaluator_v1.lua`
- `pdiddler/tests/pdiddler4_market_logic_matrix_v1.lua`

Verified offline:
- candidate source audit: 190/190 canonical rows, 0 duplicates, 0 missing/extra, 0 MM2 baseline mismatches,
- evaluator tests PASS,
- decision matrix 14/14 PASS,
- deterministic ranking tests PASS,
- forbidden trade/UI/network/final-Accept scan PASS.

Independent Firecrawl recheck matched the critical Supreme/MM2Values fields used in the disagreement tests.

Important TDD ruling:
the controlled <=3% quality-upgrade exception requires both raw and protected loss to stay within 3%, with material disagreement forbidden. A literal protectedProfit>=0 requirement made the approved small-loss upgrade impossible whenever the lists agree.

Important ranking ruling:
profit similarity uses deterministic anchored bands rather than pairwise comparisons to prevent non-transitive sort results.

Remaining limitation:
the committed stack has not yet been executed inside Delta/Roblox from pinned raw GitHub URLs.

**LIVE PART 4 INTEGRATION HAS NOT STARTED.**
Do not wire this into v2.5 until target-runtime test evidence is accepted and a separate integration design/plan is approved.


Target-runtime matrix runner added:
- `pdiddler/tests/pdiddler_market_matrix_DELTA_RUNNER_v1.lua`
- commit `62c3c6f5fc0e5e9528e6fbbfd1cee754c44eec6d`
- pins candidate profile `7ec3398582d565d423bdb00ac66d7ad6f26ad06e`
- pins market logic `aca1dc23a1cbda074faf9c00b039fd212a0830b4`
- read-only: no trade/remotes/GUI/server-hop/final-Accept behavior
- pending user Delta execution before any Part 4 integration.


---

# 39. Delta target-runtime matrix gate PASSED

Date: 2026-11-02

Recording evidence:
`ScreenRecording_11-02-2026 15-43-30_1.mp4`

Verified on the user's actual iPad + Delta + Roblox environment:
- target profile audit 190/190 PASS,
- Cases 1-14 PASS,
- matrix 14/14 PASS,
- deterministic ranking tests PASS,
- no runner-specific console errors observed.

Visible warning:
`Infinite yield possible on Workspace.Lobby.Elite.Screen.Surface.Frame.Frame:WaitForChild("Buy")`

Stack identifies MM2's own Workspace script, not the market matrix runner. Treat as unrelated unless future evidence shows interaction.

This closes the target-runtime verification requirement for the offline market model.

**LIVE PART 4 INTEGRATION HAS NOT STARTED.**

Next step:
create a separate v2.6 Part 4 integration design/plan against the exact current v2.5 planner extension points while preserving request ownership, TX abort/recovery, timers, EXTREME GUARD, scanner scheduling, and FINAL ACCEPT disabled.


---

# 40. v2.6 market-aware Part 4 pre-live gate

Date: 2026-11-02

Branch:
`feature/mm2-market-aware-part4-v2_6`

Evidence:
`pdiddler/MARKET_PART4_INTEGRATION_RESULTS_v1.md`

New components:
- `pdiddler/pdiddler_market_profile_2026-11-02_v1_VALIDATED.lua`
- `pdiddler/pdiddler4_market_planner_v1.lua`
- `pdiddler/pdiddler4_balancer_ROTATING_v2_4_MARKET_AWARE.lua`
- `pdiddler/pdiddler_MARKET_AWARE_TEST_STACK_v2_6.lua`

Immutable v2.6 live-test stack commit:
`bc2deeeffbd7d77bd933d2f11b2e0bea9c13de15`

The stack pins its market integration modules to:
`7809aa8c8d210d8005c223eb9fd3a6b3ea716ba5`

Architecture:
`scanner -> exact page:id profile -> pure market engine -> standalone planner -> existing transaction executor/verifier`

Validated profile:
- 190/190 exact rows versus the tested candidate,
- 0 decision-row changes,
- liveReady=true.

New Part 4:
- requires injected marketProfile, marketLogic, marketPlanner,
- old MARKET_QUALITY/exactQuality/multiplier system removed,
- duplicate old planner thresholds removed,
- local duplicate planner removed,
- protected terminology replaces effective terminology,
- canonical page:id used in live/plan counts, ambiguity checks, duplicate-slot verification, and signatures.

Preserved:
- P1 -> P2 -> scanner execute before market preload/preflight,
- opening highest eligible item,
- accepted-empty immediate decline,
- 15s empty timeout,
- 60s Case 3 timer,
- txValidate,
- offer mutation verification,
- bounded remove retry,
- clear/recovery/protected hold,
- request ownership / scanner pause,
- EXTREME semantics (2.0x / 50 / 2.5x / >=5 step),
- Part 3 rotation,
- FINAL ACCEPT disabled.

CI:
- workflow `.github/workflows/mm2-market-integration-ci.yml`
- official Luau 0.745,
- run `41526118216` on head `bc2deeeffbd7d77bd933d2f11b2e0bea9c13de15`,
- compile PASS,
- pure integration tests PASS,
- static regression guards PASS.

Important integration hardening:
bare item-id offer identity was changed to canonical `page:id` because the market snapshot/scanner pages can contain colliding IDs. This prevents cross-page identity aliasing.

Current status:
**PRE-LIVE GATE PASSED. NOT FROZEN KNOWN-GOOD YET.**

Next required action:
run the immutable v2.6 stack on the user's iPad + Delta and send a recording. Review the recording for failures/regressions as aggressively as successes.

Loader:
```lua
loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/bc2deeeffbd7d77bd933d2f11b2e0bea9c13de15/pdiddler/pdiddler_MARKET_AWARE_TEST_STACK_v2_6.lua",
    true
))()
```

Startup-order correction:
- P1 runs first,
- P2 runs second,
- scanner loads,
- only then do market modules/preflight run,
- Part 4/outgoing arm afterward.
This preserves the known-good v2.5 startup order. Corrected stack commit `bc2deeeffbd7d77bd933d2f11b2e0bea9c13de15` passed CI run `41526118216`.

Expected early success marker:
`[PDIDDLER TEST] MARKET PREFLIGHT PASS | profile 190/190 | planner fixtures PASS`

Expected active marker:
`[PDIDDLER TEST] MARKET-AWARE v2.6 ACTIVE`

FINAL ITEM-TRADE ACCEPT remains disabled.
