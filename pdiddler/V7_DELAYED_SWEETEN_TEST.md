# V7 — Longer sweetening interval after MM2 Accept cooldown

## Why the change
The November 3 Delta recording showed a roughly **six-second native Accept countdown**, but V6 could sweeten after **five seconds**, restarting cooldown just as Accept became available. The user clarified the Tablet-picker state after server transition came solely from **Delta Auto Execute being disabled**, not a P2 defect. No P2 or hop-code changes are made.

## V7 negotiation policy
- Observe 2.5 seconds at trade start; retain adaptive reachable opener.
- Wait **9 seconds** from the most recently verified offer/planning generation before the first optional sweeten. This is ~3 seconds beyond the countdown seen in the recording. The timing is approximate: **button-ready has not yet been proven as a machine-readable UI signal**.
- Wait a fresh **9 seconds after each verified sweetening mutation**, not nine seconds from the original opener. The second sweeten is the maximum.
- After the second sweeten, wait a fresh **9 seconds** for the newly restarted Accept cooldown, then allow a separate **5-second final decision window**. If no better safe plan exists earlier, the same 9-second initial wait is followed by the final 5 seconds.
- On partner offer/signature change or unexpected own-offer total change, invalidate stale timers. While either side Accepted, freeze voluntary mutations; on clearing Accepted, start a fresh wait.
- Preserve **strict +15 Supreme, absolute 60-second first-nonempty window**, 12-second empty, accepted-empty immediate decline, 4-copy guard and old regression tests.
- **Final auto-Accept and completion/Discord integration remain OFF.** Use a supervised low-value test. Never merge automatically.

## Live test
1. Start the V7 combined loader once on a fresh server, optionally enable Delta Auto Execute **before** hopping. Do not run it together with V5/V6.
2. Have a trusted player offer a priced, resolvable item (e.g., controlled small Godly/Chroma trade).
3. Once V7 offers our first item, watch the game's native Accept cooldown. When it reaches a usable button, **V7 should still leave the item unchanged for roughly three more seconds** before any possible improvement.
4. Watch the full second cooldown after a first sweeten; do not allow a second sweeten until nine more seconds from its verified mutation.
5. Verify no more than **two improvements** and +15 Supreme on each proposed exchange.
6. If the other side accepts, the script must freeze rebalancing; if offer changes, previous timers are stale.
7. Record the live offer/cooldown with the read-only probe console. Do not automatically Accept; use manual acceptance only for safe profitable controlled trades.

## Rollback
- PR #5: baseline source `4b5c6d9095d21643349cee32d43719e515e294d1`
- PR #7: V6 source `80e45f18ade35de68a7d46c50c50657adb8c2884`
- V7 new code belongs to its **separate draft PR** and will be pinned by commit SHA in the final instruction.
