# MM2 Bot Pattern Study — 2026-11-03

## Purpose

Cross-video + external-research profile for PDIDDLER Part 1 bot avoidance.

This document deliberately separates:
1. evidence visible in the user's recordings,
2. corroborating public reports / public MM2 autofarm feature descriptions,
3. detector implications.

Do not turn a single weak trait into an automatic bot label. The target is group-level confidence.

---

## Video corpus reviewed

Available recordings reviewed:
- ScreenRecording_11-02-2026 19-22-11_1.mp4
- ScreenRecording_11-02-2026 19-43-55_1.mp4
- ScreenRecording_11-02-2026 19-58-40_1.mp4
- ScreenRecording_11-02-2026 20-08-29_1.mp4
- ScreenRecording_11-02-2026 20-26-44_1.mp4
- ScreenRecording_11-02-2026 21-45-48_1.mp4
- ScreenRecording_11-02-2026 21-52-13_1.mp4
- ScreenRecording_11-02-2026 22-37-04_1.mp4
- ScreenRecording_11-03-2026 00-34-11_1.mp4
- ScreenRecording_11-03-2026 00-49-20_1.mp4
- ScreenRecording_11-03-2026 01-15-59_1.mp4
- ScreenRecording_11-03-2026 01-42-17_1.mp4

The 11/02 recordings are primarily trade/UI tests and are not clean positive bot samples.
The 00:34 recording is primarily the hopper transport test.
The strongest user-labeled positive bot samples are 00:49, 01:15, and 01:42.

---

## Positive sample A — 00:49 recording

The user manually typed `Botted` and then spectated / opened the People panel.

### Population pattern

Visible leaderboard:
- Tristan11jx — 100
- fatboy21tf — 100
- swlffnhlja1179vc2 — 100
- Fir3OuV3nom135 — 100
- qosmlqqyr5vq2cku — 100
- 89128scg89128m — 100
- Wu_Gail34 — 100
- aspirine10m — 100
- lumi13lzi — 100
- bluejay990t — 73

Therefore 9/10 visible non-local accounts were exactly level 100.

### Name pattern

The accounts are not one obvious username template. They use several generator styles:
- normal-looking word/name + short junk suffix: `bluejay990t`, `aspirine10m`, `Tristan11jx`
- consonant/random alphanumeric strings
- repeated numeric material: `89128scg89128m`
- family-like stem: `Fir3OuV3nom135`

Running the existing Part 1 generated-name logic over the visible names gives approximately:
- trait >= 1: 10/10
- trait >= 2: 3/10

This is important: the farm does not need every account to be strongly random. A group can look generated because almost everyone has one weak sign.

### Avatar pattern

People panel showed varied but mostly simple/blocky avatars.
They were not a single clone skin.
Several look like free/basic combinations with low cosmetic complexity.

### Behavior

While spectating, multiple different accounts appeared in black void / below-map-looking space.
This happened across more than one account, so it is much stronger evidence than one transient render glitch.

---

## Positive sample B — 01:15 recording

The user manually typed `Botted` after Part 1 v2 approved the lobby.

### Identity-family masking

Visible leaderboard included multiple accounts in the `SoulV_3nom...` family.
The People panel showed that some of those usernames had unrelated-looking display names.

Examples visible in the recording:
- display `We5tog...` -> username `@SoulV_3nom255`
- another unrelated display -> another `@SoulV_...` account

This means display-name diversity can hide an underlying username family.

### Avatar pattern

The People panel again showed diversified simple avatars rather than one giant clone cluster.
There were still repeated/similar avatar subgroups.

### Behavior

Spectating showed:
- a normal-looking account near map geometry,
- `SoulV_3nom255` below/inside map geometry,
- another `SoulV_3nom...` account with camera/character positioning intersecting geometry.

This is consistent with a farm that uses underground/void/noclip positioning rather than normal pathing.

---

## Positive sample C — 01:42 recording

This is the most important regression sample because it ran Part 1 v3 and was STILL manually marked `Botted`.

### Exact Part 1 v3 diagnostic

Developer console showed:

- score: 0
- players: 11
- avatars loaded: 11
- largest identical-avatar cluster: 2
- generated-name trait >=1: 9/11
- generated-name trait >=2: 0/11
- repeated-avatar members: 4
- result: APPROVED

The flagged avatar group included accounts roughly 2,158–2,168 days old.

Therefore:
- this was NOT an avatar-loading timing problem,
- this was NOT primarily a new-account farm,
- old account age does not prove a player is human,
- v3's persistent-diversified rule did not activate because its medium rule requires trait2 >=30%, while this farm engineered trait2=0%.

### Level pile-up

Every one of the 11 visible non-local accounts on the MM2 leaderboard was level 100.

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

Level 100 is MM2's normal per-prestige cap.
An entire 11-player non-local population sitting at exactly the cap is a strong GROUP feature even though level 100 alone is not evidence against an individual.

### Name-evasion pattern

Existing `generatedTraits()` gives approximately:
- 9/11 with exactly one weak generated trait,
- 0/11 with two traits.

This is a direct blind spot in the current classifier.

Examples:
- vowel-poor consonant strings: `grtfhnhmic`, `awthznmmmvf`
- internal digit weaving: `1w2w3u4w50m`
- number-heavy prefix/suffix: `1252001ps`
- plausible word + tiny suffix: `Tranquilityuw`, `flubber12d`
- brand/common word + junk suffix: `roblox22uvl`

The farm is distributing weak suspicious features across the group instead of making individual accounts extremely suspicious.

### Avatar pattern

People panel showed randomized, mostly low-complexity outfits.
There was no single huge clone group.
This defeats an identical-avatar-first detector.

### Lobby behavior

At the moment the manual snapshot was captured, the observer labeled the accounts `Idle`.
This is expected and is NOT evidence of humanity: lobby-state snapshots are insufficient for movement-based bot detection.

---

## External research findings

### Current bot appearance/name evolution

Recent MM2 community reports (Oct 2026) describe:
- classic bots using randomized outfits built from free items,
- usernames built from random word combinations,
- teleporting between coins,
- newer bots that glide instead of snap-teleport,
- newer bots with shorter/more human-looking usernames,
- some bots wearing Robux items,
- some bots at unusually high or max level,
- real/main accounts also being used for autofarming.

Source:
https://www.reddit.com/r/mm2/comments/1xdvtot/has_anybody_noticed_something_different_abt_these/

This matches the user's recordings: cosmetic diversity and realistic-looking account age/appearance cannot be used as a human guarantee.

### Old/simple clone style still exists

Community reports also describe:
- free Xbox/default bundles,
- bacon/default-like avatars,
- slight username variations,
- full or nearly full bot lobbies.

Source:
https://www.reddit.com/r/MurderMystery2/comments/1olf95o

So the detector must support BOTH clone farms and diversified farms.

### High/max levels

Current community reports explicitly mention newer bots being unusually high level / max level.

Source:
https://www.reddit.com/r/mm2/comments/1xdvtot/has_anybody_noticed_something_different_abt_these/

MM2 prestige documentation confirms normal level caps at 100 before prestige.

Source:
https://mm2wiki.org/wiki/prestige/

Implication:
- one level-100 player is normal,
- 9/10 or 11/11 unrelated-looking accounts all exactly level 100 is a strong group anomaly.

### Movement / teleport modes

Current public MM2 autofarm descriptions expose several movement styles:
- nearest-coin teleport,
- instant teleport,
- tween/glide movement,
- float while collecting,
- noclip while collecting,
- underground farming,
- void teleport,
- teleport under the coin with a vertical offset.

Sources:
https://github.com/RabbitCoreHub/MM2/blob/main/MM2_Main.lua
https://scriptblox.com/script/Murder-Mystery-2-Best-MM2-Zero-Point-Kill-All-Coin-farm-Live-Trade-Helper%21-226629
https://www.youtube.com/watch?v=YNTcKXQ_JzQ

This directly explains why the user's spectated bots can appear:
- under the map,
- in black void,
- intersecting geometry,
- gliding rather than walking,
- snapping between distant positions.

### End-of-bag / role automation

Public MM2 automation feature lists include:
- reset when bag is full,
- return to lobby when bag is full,
- fling/kill murderer,
- auto shoot murderer,
- auto knife throw / kill all,
- auto pick gun,
- server hop / rejoin.

Sources:
https://saiops.cc/mm2-script
https://delta-scripts.org/scripts/murder-mystery-2-script-auto-farm-coin-farm-esp-teleports/

Community reports also describe rounds ending when bots reset and bots floating/glitching.

Source:
https://www.reddit.com/r/MurderMystery2/comments/1v9bild/bots/

### Bots can appear human or broken

Community reports describe bots that:
- walk around enough to look human,
- use main/older accounts,
- can stand still when their farm is off/broken.

Sources:
https://www.reddit.com/r/MurderMystery2/comments/1ukpj4j/bots_in_my_server/
https://www.reddit.com/r/MurderMystery2/comments/1vb6u6l/whats_the_point_of_farm_bots/

Implication:
neither "walks normally" nor "old account" nor "fancy outfit" may clear suspicion by itself.

---

## Detector redesign implications

### 1. Stop requiring individual accounts to be strongly generated

The current trait2 gate is obsolete for newer diversified farms.

Add group-level weak-name evidence:
- weak username ratio,
- weak display-name ratio,
- either-name weak ratio,
- family/prefix groups,
- repeated numeric blocks,
- internal digit weaving,
- consonant-heavy names,
- word + short junk suffix patterns.

A lobby with 80–90% weak-name evidence should be suspicious even when every account has only ONE weak trait.

### 2. Add a verified level-cap group signal

Do not hard-code an invented remote/object path.

First discover and prove one reliable client-visible MM2 level source.

Once verified:
- compute level-100 ratio across non-local players,
- treat >=80% exact-level-100 as a strong GROUP signal when combined with weak names / simple avatars / repeated subgroups,
- do not reject an individual merely for being level 100.

### 3. Keep avatar simplicity supportive, not mandatory

Track:
- <=1 accessory ratio,
- <=2 accessory ratio,
- repeated subgroup members,
- largest cluster,
- avatar diversity.

But newer bots can use Robux cosmetics, so expensive/fancy appearance must not clear a lobby.

### 4. Old account age is neutral

Very new accounts can add suspicion.
Old accounts should never subtract suspicion.

The newest positive sample had ~6-year-old accounts in its flagged subgroup.

### 5. Add temporal ROUND behavior for borderline lobbies

A single lobby snapshot saying `Idle` is nearly useless.

For a borderline static lobby, observe positions over time during a stable active round.

Potential behavior features:
- impossible displacement / instant teleport,
- repeated large position jumps without respawn,
- sustained glide/tween speed inconsistent with ordinary walking,
- repeated below-map / void positioning relative to the active player population,
- noclip-like geometry traversal if measurable reliably,
- multiple accounts exhibiting the same movement mode,
- synchronized reset/death patterns.

Exclude:
- map loading,
- lobby -> round transition,
- respawn,
- death,
- legitimate game teleport transitions.

### 6. Use a multi-stage state machine

Recommended Part 1 v4 shape:

`STATIC_SCAN -> STRONG_REJECT / CLEAN_APPROVE / BORDERLINE_CONFIRM`

For borderline:
`STATIC_CONFIRM -> if still borderline -> BEHAVIOR_PROBE`

Then:
`BEHAVIOR_PROBE -> BOT / APPROVE`

One session/generation must own all callbacks.
No stale round observer can reject a later server.

### 7. Preserve evidence

For every rejected or manually-labeled lobby, save concise diagnostics:
- JobId,
- player count,
- level-cap ratio,
- username/display-name weak ratios,
- avatar simplicity ratios,
- repeated members,
- account-age summary,
- movement/teleport counts,
- reason codes.

This lets future false positives/false negatives improve the detector instead of accumulating blind threshold patches.

---

## Immediate conclusion

P1 v3 is NOT sufficient.

The latest false negative proves the current detector can score an obvious diversified farm at 0 because:
- 9/11 names have one weak generated trait,
- 0/11 have two traits,
- avatars are diversified enough to avoid a giant cluster,
- accounts may be old,
- lobby movement is idle,
- level-cap pile-up is not currently modeled.

Do not keep patching `trait2` thresholds.

Next engineering step should be a v4 evidence collector / classifier built around:
1. group weak-name distribution,
2. verified exact-level-100 pile-up,
3. avatar subgroup/simplicity evidence,
4. bounded behavior telemetry for borderline cases.
