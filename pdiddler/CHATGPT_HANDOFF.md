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

The current active stack remains:

`pdiddler/pdiddler_OUTGOING_OWNERSHIP_FIX_TEST_STACK_v2_3.lua`

Commit:
`0f8bb3536d3a073f3001e1759c07dca44fc5cbd1`

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
