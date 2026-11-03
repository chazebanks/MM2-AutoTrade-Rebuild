# MM2 P1 + P5 Observation Lab Design

Date: 2026-11-03
Status: Proposed for approval
Branch: `feature/mm2-server-hopper-design`

## Intent

Improve the standalone Part 1 + Part 5 live test so screen recordings contain useful evidence about:
- what Part 1 decided,
- which real servers Part 5 is considering,
- what players in the current server visibly look like,
- what basic character actions they are performing,
- and whether the user manually identified a Part 1 false negative.

This remains a **test-only observation lab**. It does not modify the full PDIDDLER trader.

## Selected approach

Keep the known-good Part 1 bot detector completely unchanged.

Part 1 remains the only automatic bot-lobby authority.

The lab adds a separate recording-friendly GUI and observation layer around Part 1 + Part 5. This avoids modifying the detector under test and prevents a second bot classifier from competing with it.

## Server flow

### Part 1 returns BOT

- Show a brief GUI state: `BOT DETECTED — REHOPPING`.
- Do not start the 30-second observation countdown.
- Part 5 immediately re-hops to another valid 11/12 or 10/12 server.
- Delta Auto Execute relaunches the same lab after teleport.

### Part 1 returns APPROVED

- Show the observation GUI.
- Start a **30-second** observation countdown.
- Show the current server occupancy.
- Show real Part 5 server candidates.
- Show current players with avatar thumbnails and observable action state.
- At 0 seconds, invoke the existing Part 5 transport hopper.

The 30-second timer is test-only and does not claim the lobby is trade-exhausted.

## Manual `botted` marker

During an approved-server observation window, if the local user sends the exact chat message:

`botted`

the lab records a manual false-negative marker.

Behavior:
- Do **not** immediately hop.
- Do **not** reset the 30-second timer.
- Keep the remaining countdown running.
- Change the GUI status to `MANUALLY CONFIRMED BOTTED`.
- Capture a visible snapshot state for the recording:
  - current JobId short form,
  - current player count,
  - player names,
  - avatar thumbnails,
  - current observable action labels,
  - remaining countdown time,
  - Part 1 result = APPROVED,
  - manual result = BOTTED.

Repeated `botted` messages in the same server are deduped and do not create duplicate snapshots.

## GUI

The GUI is:
- movable,
- minimizable,
- compact enough for iPad screen recording,
- read-only except its minimize/move controls,
- destroyed/recreated safely on each Delta Auto Execute session.

Suggested layout:

```text
PDIDDLER P1 + P5 OBSERVATION LAB

PART 1: APPROVED
CURRENT: 11/12
HOP IN: 24s
MANUAL: type "botted" if Part 1 missed this lobby

NEXT REAL SERVERS
11/12  a82f...
11/12  c10b...
10/12  91de...

CURRENT SERVER
[avatar] Player1   Moving
[avatar] Player2   Idle
[avatar] Player3   Jumping
...
```

If manually marked:

```text
MANUALLY CONFIRMED BOTTED
Snapshot captured at 18s remaining
```

## Real server candidates

The GUI must display real candidate results from Part 5's actual public-server discovery path.

Candidate display order:
1. 11/12
2. 10/12

Never show 9/12 or lower as a valid candidate.

Only display a bounded number of rows so the GUI stays compact.

The transport layer remains authoritative for actual selection. The GUI only mirrors the candidate list.

## Player avatar thumbnails

Use Roblox avatar thumbnail URLs obtained through the documented thumbnail endpoint / supported thumbnail loading path.

The GUI should not attempt to render 3D character models.

Thumbnail loading is best-effort:
- missing thumbnail -> placeholder,
- slow thumbnail -> placeholder until available,
- thumbnail failure must never block hopping.

## Observable player action labels

Only show states that can be inferred from local character state without guessing intent.

Allowed examples:
- `Idle`
- `Moving`
- `Jumping`
- `Freefall`
- `Sitting`
- `Dead`
- `Character Loading`

Do not label a player as:
- botting,
- farming,
- collecting,
- exploiting,
- or any other inferred intent/activity unless a future verified subsystem proves that behavior.

Action labels update periodically at a low frequency suitable for recording, not every frame.

## Chat detection

The lab listens for the local user's chat message `botted`.

Compatibility should prefer supported local chat signals and handle both current TextChatService and legacy player chat behavior when available.

Only the local user's exact normalized message `botted` triggers the manual marker.

No remote chat messages from other players trigger it.

## State/lifecycle safety

- One GUI session per lab session.
- Duplicate Delta execution must reuse or replace safely without stacking duplicate GUIs, timers, chat listeners, or action-update loops.
- Old callbacks must be invalidated by a lab session ID.
- The existing Part 5 hopper controller remains the only teleport owner.
- Manual `botted` marking never calls teleport directly.
- Part 1 BOT path remains immediate re-hop.
- Approved path remains exactly one scheduled hop at the end of the 30-second window.
- Failed/full teleport handling remains Part 5 transport responsibility.

## Non-goals

This lab does not:
- alter Part 1 bot scoring,
- add a second automatic bot classifier,
- add Part 3 inventory scanning,
- add trade logic,
- add market logic,
- add webhook logic,
- add final Accept,
- change the visited-server policy,
- change 11/12 -> 10/12 priority,
- claim player intent from movement alone.

## Existing transport remains frozen

The live-test observation layer should call the already-tested Part 5 transport instead of duplicating server fetching/teleport code.

If the GUI needs candidate data, expose a read-only discovery/snapshot method from Part 5 or a thin lab-only observer around the same discovery source. Do not fork the server-selection algorithm.

## Approaches considered

### A. Keep Part 1 unchanged + separate observation GUI
**Selected.**

Pros:
- tests the exact known-good detector,
- manual false negatives are meaningful evidence,
- no competing classifier,
- easiest to compare recordings against Part 1 behavior.

### B. Modify Part 1 to expose internal scoring data
Rejected because it would mean the lab is no longer testing the exact known-good Part 1 artifact.

### C. Add a second diagnostic classifier
Rejected because conflicting automatic verdicts would make recordings ambiguous and duplicate bot-analysis logic.

## Approval gate

After approval, implementation should:
1. write RED tests for GUI/session/chat/candidate-view contracts,
2. create a new observation-lab version rather than overwriting the existing P1+P5 transport lab,
3. keep Part 1 and Part 5 transport commits pinned,
4. compile/test in CI,
5. provide a new Delta Auto Execute loader specifically for this observation lab.
