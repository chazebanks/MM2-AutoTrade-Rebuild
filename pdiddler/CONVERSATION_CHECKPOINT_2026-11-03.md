# PDIDDLER Conversation Checkpoint — 2026-11-03

This is the durable handoff for the current MM2 AutoTrade rebuild conversation.
Resume from this file plus `pdiddler/CHATGPT_HANDOFF.md`.
Do not re-derive or overwrite known-good behavior unless new evidence requires it.

---

# 1. Project / environment

User:
- iPad + Delta executor for Roblox/MM2.
- Delta Auto Execute is available and works with .txt files.
- User wants reliability/root-cause debugging over patch stacking.
- Preserve confirmed working behavior.
- One authoritative implementation per responsibility.
- Use session/generation IDs so stale callbacks cannot mutate current state.
- Never invent MM2 remotes, object names, level APIs, return values, or game behavior.
- When testing, inspect successes AND failures.
- User prefers direct copy/paste or .txt delivery for Delta tests.

Repo:
`chazebanks/MM2-AutoTrade-Rebuild`

Current branch:
`feature/mm2-server-hopper-design`

Primary handoff:
`pdiddler/CHATGPT_HANDOFF.md`

Known-good full market baseline:
`pdiddler/pdiddler_KNOWN_GOOD_MARKET_AWARE_v2_6_3.lua`
Never modify in place.

---

# 2. Modular project status

Part 1 — bot avoider:
- v1 known-good historical baseline:
  `pdiddler/pdiddler1_KNOWN_GOOD.lua`
- v2 readiness experiment:
  `pdiddler/pdiddler1_BOT_DETECTOR_v2_READINESS.lua`
- v3 persistent-diversified experiment:
  `pdiddler/pdiddler1_BOT_DETECTOR_v3_PERSISTENT_DIVERSIFIED.lua`
- IMPORTANT: v1/v2/v3 are NOT sufficient as final production bot detection.
- Latest v3 produced a confirmed false negative.

Part 2 — startup/device clicks:
- complete / known-good.
- Click Tablet on device chooser.
- If friend prompt appears, click Play, not Join.

Part 3 — scanner / whitelist / blacklist / outgoing rotation:
- considered completed/known-good before Part 5 integration.
- production integration should not begin until bot detection phase is resolved.

Part 4 — market-aware planner/rebalancer:
- completed / known-good.
- final trade Accept remains manual unless explicitly requested otherwise.

Part 4.5 — manual Accept observer + completed-trade webhook/inventory tracking:
- completed.
- webhook fires only after a completed trade.
- webhook requirements: both sides' traded items, value, demand, liquidity, gained/profit value, updated total inventory value.
- real webhook URL must never be copied into repo/context.
- runtime configuration only.

Post-trade auto-claim:
- live-proven.

Part 5 — server hopper:
- core transport is live-proven.
- standalone masked P1+P5 observation loop is live-proven.
- do NOT modify proven hopper transport casually.

---

# 3. Part 5 live-proven transport behavior

Policy:
`pdiddler/pdiddler5_server_hopper_policy_v1.lua`

Runtime:
`pdiddler/pdiddler5_server_hopper_v1.lua`

Runtime commit:
`fa288984552e95fc13be01ec9c9b58bf7c9fb914`

Approved production semantics:
- true Part3 exhaustion starts 45s.
- only new confirmed actionable tradable player resets.
- unknown/scanning does not reset but blocks actual hop.
- deadline -> canonical Part3 final scan.
- final scan actionable -> cancel hop.
- final scan clear -> hop.
- no hop while trade/outgoing/pending/claim/unresolved scan active.
- target only 11/12 or 10/12 public servers.
- prefer 11/12.
- no 9/12 or lower.
- no candidate -> refresh every 5s.
- current JobId excluded.
- visited/attempted JobId excluded.
- mark attempted JobId visited BEFORE teleport.
- visited state persists across same Delta Auto Execute teleport chain.
- full/failed candidate -> try next candidate immediately.
- one authoritative hopping session.
- Part1 BOT rejection -> immediate rehop.
- Delta built-in Auto Execute is sole relaunch mechanism.
- no queue_on_teleport.

Live hopper-only recording:
`ScreenRecording_11-03-2026 00-34-11_1.mp4`

Proven:
- 30s standalone test delay behaved correctly.
- real 11/12 discovery and selection.
- visited count persisted/grows across teleports.
- real GameFull failure recovered by trying next candidate.
- current/visited servers were not intentionally reselected.
- landing 12/12 after choosing 11/12 is expected join-race behavior.

Still not naturally exercised:
- live 10/12 fallback because hundreds of 11/12 candidates existed.
- no-candidate 5s refresh for same reason.

---

# 4. Masked P1 + P5 observation test

Goal:
- keep rejoining for observation.
- BOT verdict -> immediate rehop.
- APPROVED verdict -> show GUI and wait 30s.
- GUI shows real next server candidates.
- GUI shows current player avatars + observable action labels.
- user types exact/case-insensitive `botted` to mark a false negative.
- `botted` must NOT reset the timer.
- `botted` must NOT hop early.
- timer continues; user can spectate/show evidence; normal hop at deadline.
- Delta Auto Execute relaunches after teleport.

Observation modules:
- `pdiddler/pdiddler_p1_p5_observation_policy_v1.lua`
- `pdiddler/pdiddler5_server_candidate_observer_v1.lua`
- `pdiddler/pdiddler_p1_p5_observation_gui_v1.lua`

GUI behavior:
- movable/minimizable.
- real server list.
- avatar headshots.
- action labels:
  - Character Loading
  - Dead
  - Sitting
  - Jumping
  - Freefall
  - Moving
  - Idle
- handles joins/leaves.
- local chat `botted` capture.
- manual snapshot captures players/actions/remaining time.
- no teleport authority in GUI itself.

Masked live recording:
`ScreenRecording_11-03-2026 00-49-20_1.mp4`

Live-proven together:
- Delta Auto Execute relaunches automatically across teleports.
- APPROVED path -> GUI + 30s.
- real candidate display.
- avatars/actions display.
- manual `Botted` works.
- timer did NOT reset after manual mark.
- no early hop after manual mark.
- Part1 BOT path -> immediate rehop.
- combined BOT-path GameFull failure recovered.
- repeated multi-hop loop works without visible duplicate stacked controllers.

---

# 5. Confirmed Part 1 false-negative history

## v1 problem

v1 static detector:
- BotWaitForLobby 6s
- BotConfirmDelay 2.5s
- BotMinPlayers 6
- BotThreshold 60
- several avatar cluster / simple avatar / generated name rules.

Bug:
- first scan below 60 immediately approved.
- some avatar-data thresholds used `math.floor(total * 0.80)`.
- for 11 players, floor(8.8)=8, which is only ~73% loaded.

## v2 readiness fix

File:
`pdiddler/pdiddler1_BOT_DETECTOR_v2_READINESS.lua`

Changes:
- BotAvatarReadyRatio = 0.80
- BotAvatarReadyRetries = 4
- BotAvatarReadyRetryDelay = 0.75
- uses `math.ceil(total * 0.80)`
- bounded readiness retry before below-threshold approval.
- no movement classifier.
- no level rule.
- no global threshold reduction.

TDD:
- RED run: `41588241844`
- implementation commit: `f4da596e8f3543d2a831fcc0d94f5c719d43d9b6`
- compile/CI commit: `dcfd0a950f01fab1e1c91542c4a440f70b58b20d`
- GREEN run: `41588347324`
- job: `125758984355`

But v2 still missed a confirmed bot lobby.

## v3 persistent-diversified fix

Reason:
existing medium rule literally called `possible diversified farm` added 45 points.
Global bot threshold remained 60.
Below-60 first scan could approve despite stable 45-point diversified pattern.

v3 behavior:
- clean low-score lobby -> approve normally.
- >=60 bot -> confirm as before.
- possibleDiversified -> force second scan.
- if still possibleDiversified on second scan -> reject with `persistent-diversified`.
- if second scan clears -> approve.
- preserves v2 readiness behavior.
- does not lower global 60 threshold.
- no movement/level guessing.

File:
`pdiddler/pdiddler1_BOT_DETECTOR_v3_PERSISTENT_DIVERSIFIED.lua`

TDD:
- RED run: `41590139530`
- v3 implementation commit: `7071ef9dfe789d4588985edebc1bc5d780a06862`
- CI compile commit: `abcca99c38a9fe94148eec1242e044751e9156dc`
- GREEN run: `41590234993`
- job: `125765048991`
- v3 persistent diversified regression: PASS 7/7

But v3 still produced a confirmed false negative.

---

# 6. Latest bot-profile study

Research document:
`docs/research/mm2-bot-pattern-study-2026-11-03.md`

Research commit:
`559ff4406c620ed8744e83aad67a24fb6b17ecb6`

Handoff commit recording v3 false negative:
`847fd4eb310f8c1e6d1728161eec248bed8c228e`

## Strong positive bot sample A — 00:49 recording

Recording:
`ScreenRecording_11-03-2026 00-49-20_1.mp4`

Manual `Botted` false negative.

Visible leaderboard examples:
- Tristan11jx — level 100
- fatboy21tf — 100
- swlffnhlja1179vc2 — 100
- Fir3OuV3nom135 — 100
- qosmlqqyr5vq2cku — 100
- 89128scg89128m — 100
- Wu_Gail34 — 100
- aspirine10m — 100
- lumi13lzi — 100
- bluejay990t — 73

Therefore:
- 9/10 visible non-local accounts exactly level 100.

Name styles:
- normal word/name + junk suffix
- random alphanumeric strings
- repeated numeric material
- mixed generated styles rather than one template.

Existing generated-name logic approximately:
- trait>=1: 10/10
- trait>=2: 3/10

Avatar pattern:
- varied but mostly simple/blocky.
- not one giant clone cluster.

Behavior:
- while spectating, multiple different accounts appeared in black void / below-map-looking space.
- repeated across more than one player, so stronger than one render glitch.

## Strong positive bot sample B — 01:15 recording

Recording:
`ScreenRecording_11-03-2026 01-15-59_1.mp4`

Manual `Botted` after v2 APPROVED.

Pattern:
- multiple underlying usernames in `SoulV_3nom...` family.
- unrelated-looking DisplayNames hide common username family.
- diversified simple avatars.
- some repeated/similar avatar subgroups.

Behavior:
- spectated accounts below/inside map geometry.
- geometry intersection / under-map-looking positioning.

Important:
- analyze BOTH Player.Name and Player.DisplayName.
- display-name diversity cannot be treated as identity diversity.

## Strong positive bot sample C — 01:42 recording

Recording:
`ScreenRecording_11-03-2026 01-42-17_1.mp4`

This is the most important regression sample.

P1 v3 APPROVED it, then user manually identified it as botted.

Exact v3 console evidence:
- score 0
- players 11
- avatars loaded 11
- largest identical-avatar cluster 2
- generated-name trait>=1: 9/11
- generated-name trait>=2: 0/11
- repeated avatar members: 4
- result: APPROVED
- flagged repeated-avatar pair account ages roughly 2,158–2,168 days

Therefore:
- NOT a readiness/loading problem.
- NOT primarily a new-account farm.
- old account age cannot be considered proof of humanity.
- current trait2 dependence is a blind spot.

Visible names included:
- grtfhnhmic
- Tranquilityuw
- awthznmmmvf
- 1w2w3u4w50m
- 1252001ps
- 3windows1so
- flubber12d
- roblox22uvl
- rgg08iy
- allystahgym
- luv4lifewlv

Existing name logic approximately:
- 9/11 have one weak generated trait.
- 0/11 have two traits.

All 11 visible non-local players were exactly level 100.

That is a major missing GROUP signal.

Avatars:
- randomized/diversified low-complexity outfits.
- no giant clone group.
- some repeated subgroups.

Lobby snapshot action labels were `Idle`.
This proves one-frame lobby movement is insufficient.

---

# 7. External MM2 bot research findings

Current public/community evidence corroborates the recordings.

Reported/advertised farm patterns include:
- randomized free-item outfits,
- default/simple Xbox/bacon-style accounts,
- newer Robux-dressed bots,
- shorter/human-looking names,
- older/main accounts used for farming,
- high/max-level bots,
- instant teleport-to-coin,
- nearest-coin teleport,
- tween/glide farming,
- float while collecting,
- noclip,
- underground farming,
- void teleport,
- teleport under coin with vertical offset,
- reset when bag full,
- return to lobby when bag full,
- auto shoot murderer,
- auto knife/kill behavior,
- auto pickup gun,
- rejoin/server hop.

Important detector implications:
- fancy avatar does NOT prove human.
- old account does NOT prove human.
- walking normally does NOT prove human.
- standing still does NOT prove human (farm can be off/broken/lobby state).
- identical clone group is only one bot generation.
- newer farms diversify avatars and names specifically to evade naive rules.

Research sources are documented in:
`docs/research/mm2-bot-pattern-study-2026-11-03.md`

---

# 8. Why current detector architecture is insufficient

Current detector overweights individually strong indicators:
- huge identical avatar cluster,
- many accounts with trait>=2,
- new account ratios,
- strong repeated groups.

Newer farms can evade by:
- distributing one weak naming trait across almost every account,
- using old accounts,
- using diverse simple outfits,
- using several repeated pairs instead of one huge clone cluster,
- hiding username families behind unrelated DisplayNames,
- being idle in lobby but farming abnormally during rounds.

Newest confirmed bot lobby:
- 9/11 weak-name accounts,
- 0/11 two-trait names,
- 11/11 level 100,
- repeated subgroup evidence,
- score 0.

Do NOT keep patching `trait2` thresholds.

---

# 9. Recommended Part 1 v4 architecture

Do NOT immediately create final reject logic from guessed thresholds.

First create an evidence/telemetry build.

Recommended state machine:

`STATIC_SCAN -> STRONG_REJECT / CLEAN_APPROVE / BORDERLINE_CONFIRM`

If borderline:
`STATIC_CONFIRM -> if still borderline -> BEHAVIOR_PROBE`

Then:
`BEHAVIOR_PROBE -> BOT / APPROVE`

One session/generation owns all callbacks.
Old callbacks are stale after server/session change.

Evidence families:

## Identity-group evidence
- Player.Name + Player.DisplayName.
- weak generated-name ratio.
- either-name weak ratio.
- repeated username families/prefixes.
- number weaving.
- repeated numeric blocks.
- consonant-heavy strings.
- normal word + short junk suffix.
- avoid requiring each account to have multiple strong traits.

## Population evidence
Need a VERIFIED MM2 level source first.
Do not invent `leaderstats` or a remote path.

Once verified:
- exact level-100 ratio across non-local players.
- 80–100% level-100 saturation can be strong GROUP evidence when combined with other suspicious signals.
- never flag one player solely for level 100.

## Avatar evidence
- <=1 accessory ratio.
- <=2 accessory ratio.
- repeated subgroup members.
- largest cluster.
- overall avatar diversity.
- support evidence only; fancy/Robux appearance cannot clear a lobby.

## Account-age evidence
- very new accounts can add suspicion.
- old accounts should be neutral.
- do not subtract suspicion for old accounts.

## Temporal round behavior
Only for borderline cases.
Observe over time during a stable active round.

Potential signals:
- impossible displacement / instant teleport,
- repeated large jumps without respawn,
- sustained glide/tween motion inconsistent with normal walking,
- repeated below-map/void positioning,
- noclip-like geometry traversal if measurable reliably,
- multiple accounts using same movement mode,
- synchronized reset/death patterns.

Must exclude:
- lobby -> round transition,
- respawn,
- death,
- map loading,
- legitimate game teleports.

## Diagnostics to preserve
For every reject/manual false negative:
- JobId
- player count
- level-cap ratio
- username weak ratio
- display-name weak ratio
- avatar simplicity ratios
- repeated member count
- account-age summary
- movement/teleport counts
- reason codes

---

# 10. Agreed calibration strategy

The user proposed a better calibration workflow and it is now the plan.

## Phase 1 — BOT-ONLY evidence collection

User will intentionally join ONLY lobbies they personally know are botted.

User is the ground truth for this phase.

For each bot lobby:
- record/spectate players,
- show leaderboard,
- show People panel when useful,
- show bot movement/teleport/void behavior,
- show usernames/display names/avatars/levels,
- mark false negatives if needed,
- collect as much behavior evidence as possible.

Goal:
- collect multiple different bot families/styles.
- ideally ~5–10 clearly botted servers before locking final classifier.

Important:
during bot-only evidence collection, immediate auto-hop is counterproductive because it destroys the evidence window.

Therefore next test build should be an **evidence build**:
- join known bot lobby,
- P1 scans,
- GUI shows raw detector evidence,
- NO immediate auto-hop,
- hold ~60s observation window,
- user spectates/opens leaderboard/People panel,
- behavior telemetry records,
- user manually leaves when finished.

Do NOT use normal production hopping semantics during evidence collection.

## Phase 2 — REAL-SERVER false-positive protection

Only after bot detection is strong against collected bot corpus.

Then intentionally test normal/human servers.

For every detector BOT verdict:
- manually inspect.
- if genuinely normal -> false positive -> adjust.

Goal:
maximize bot recall first, then measure and improve precision on real lobbies.

Do not tune both sides simultaneously after every single server.

---

# 11. Latest user directive

User explicitly said:
"How bout this I’ll join only bot lobby’s and show u them as evidence then once we get of the bot problem then we can move on to the real servers to make sure they aren’t getting flagged"

Accepted plan:
1. bot-only positive dataset first.
2. solve recall / missed-bot problem.
3. then normal-server dataset.
4. solve false-positive problem.
5. only then proceed toward Part3 production integration.

User then said:
"Save everything in this conversation"

This checkpoint is the durable response to that request.

---

# 12. Do not regress these points

- Do not claim P1 v3 is fixed. It has a confirmed false negative.
- Do not move to Part3 yet.
- Do not lower thresholds blindly.
- Do not invent a level API.
- Do not treat account age as a human guarantee.
- Do not treat fancy avatars as human guarantees.
- Do not treat one-frame Idle as human evidence.
- Do not remove the proven P5 transport behaviors.
- Do not alter known-good market/trade logic while solving bot detection.
- Keep v1/v2/v3 historical baselines unchanged.
- Next work should be bot-only evidence instrumentation / v4 evidence collector.
