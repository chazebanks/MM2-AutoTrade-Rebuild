# Pdiddler V11 isolated Delta test build

This is a draft, unmerged successor to PR12 (ca09aaddd7982fcfd794d4aa8cecea79a91c41f7). All 199 files in that baseline are byte-identical. New versioned files supply the fixes. Frozen Tablet/friend Play, scanner, outgoing v16 physical clicks, native-ready gate, early policy and P5 transport remain pinned.

## Run this exact build

Disable older pdiddler Auto Execute entries and begin a clean MM2 session with only this build. Do not run several versions in one server. The duplicate-owner locks deliberately require a rejoin after a partial initialization or a build switch.

```lua
local e=(getgenv and getgenv()) or _G
local u="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/e8957cd4d17cf569e52ad4f62b0442ededa50577/pdiddler/pdiddler_V11_TELEPORT_AUTOBOOT_v1.lua"
e.PDIDDLER_V11_AUTOBOOT_URL=u
loadstring(game:HttpGet(u,true))()
```

The wrapper pins the integration/probe to e6472342ca39df0f6cd5217c368631bd06613c20. New P4/gate/readiness modules are pinned to 962dcafe2b5c535ed7c94293ebb812693404d4e7; verified-step policy to 43c59d3eac0acbb9e94f35170adf77b4c2be2845. Every remaining dependency retains its existing approved immutable pin. No moving branch or main URL is used.

If a real executor queue-on-teleport API is available, the wrapper queues this exact bootstrap for each next hop. If it reports unsupported/rejected, use Delta's built-in Auto Execute with the same snippet. No executor folder guessing, stateful file edits or global teleport-queue clearing is performed. Native Delta queue compatibility remains a live test.

**Price deadline:** the preserved snapshot expires 2026-11-04 at21:42:28UTC. It is not extended by this build. After that, a legitimately refreshed/approved snapshot and new immutable build are required before trading. Unknown/unmapped values remain unusable. Read-only readiness diagnostics can still be used after price expiry.

## What changed

- One verified opponent-first quote consumes its early response; no immediate second price concession.
- Late steps commit only after exact actual slots and +15 safety verification. A failed replacement cannot turn an empty recovery into a larger new opening quote.
- Visible-lifetime fencing rearms correctly after replacement/reopened windows, while stale inventory callbacks cannot act.
- Both Accepted indicators stop voluntary mutation only after exact unchanged profitable verification. A changed/unsafe offer still invalidates approval. An unresolved pair is held after15seconds with outgoing/hopping stopped; it never counts as completion.
- Bot V6 rejects unreadable appearance fields and stale roster/character snapshots, fences delayed scans and corrects two-window missing-animation diagnostics. Existing scoring and10-second observation remain.
- Readiness observes character/UI/loading conditions after unchanged P2, before workers and at mutation boundaries. Startup observation is bounded to60seconds, runtime unresolved loading to15seconds. No character/world/native UI mutation is added.

Research and strategy comparisons are separately preserved in [draft PR13](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/13). Market demand/stability are proxies, not an acceptance probability model. The script remains general-purpose; the personal Gingerscope roadmap is outside runtime.

## Offline verification

Run with Lua5.3/5.4 and official Luau0.745:

```sh
LUAU_BIN=/path/to/luau LUAU_COMPILE=/path/to/luau-compile python3 pdiddler/tests/run_v11_checks.py
```

All 17 verification commands passed locally. All 199 baseline blobs and 12 immutable dependency blobs match; six complete new runtime sources compile. [Complete command output](audit-notes/V11_TEST_RESULTS.txt) and [remote GitHub blob checks](audit-notes/V11_REMOTE_PIN_CHECKS.json) are committed. CI repeats these checks and retains its log artifact.

| Suite | Passing behavioral cases |
|---|---:|
| Original integration/hopper |58|
| Original trading, including unchanged outgoing v16 |118|
| Original snapshot refresh |13|
| Issue4 additional policy/lifecycle/integration/P4 |63|
| V6/V7/V8/V9/V10 historical policy/UI/selection/bootstrap/runtime |83|
| V11 verified-step policy |3|
| V11 full production-P4 fixture |16 (7 inherited +9 new)|
| V11 full production bot gate |9|
| V11 read-only readiness |10|
| V11 loader integration |16|
| V11 teleport wrapper |9|

These are offline tests across versioned suites, not 398 independently observed MM2 trades. The full production P4 and gate execute in official Luau; Roblox instances, inventory RPCs, executor APIs, UI rendering and scheduling are boundary fixtures. Passing mock tests cannot verify native behavior.

## Exact remaining iPad tests

| Test | Action | Expected result |
|---|---|---|
| Clean startup/click preservation | Run only the snippet above on a clean join. Let existing selectors run, then allow one outgoing request. | Tablet and optional friend Play behave as before. WAIT_READINESS finishes before GATE. Ten-second gate precedes workers. Leaderboard/card/Trade physical taps still work. No blind extra clicks. |
| Delayed character/world | Start while the native loading screen is visible; observe whether it resolves naturally. | No scanner/outgoing/offer starts during unresolved readiness. Visible matching loading text logs its real path. Resolving conditions proceeds once, without rerunning P2. At60s unresolved, READINESS_HOLD and no hop. This does not prove a native hang was repaired. |
| Actual first offer | Let a verified whitelisted partner accept our request. Observe both blank-first and opponent-first cases. | One real opening item/quote appears and is verified. Adaptive opener may observe up to2.5s or skip an unreachable speculative opener. An opponent-first verified quote does not immediately receive another early concession. |
| Opponent changes | Have the partner add/remove a known eligible item, including clearing all slots. | Full revaluation/replanning; no unknown value guesses. Actual planned slots match before verification. Empty offer declines after12s; accepted-empty declines immediately. Profit always at least15 when a plan is treated as safe. |
| Native cooldown/negotiation | Leave a profitable offer unaccepted and watch the normal countdown. | No late change before native ACCEPT is clearly available, the2.5s ready buffer and9s verified-offer wait. At most two verified late improvements. Failed physical replacement does not silently buy another budget. |
| Manual approval change | Use normal native controls yourself; change the partner offer before completion. | Prior approval is invalidated; unsafe/changed offers decline, not reused. Pdiddler never sends automatic Accept/Confirm. |
| Manual pair pending | Manually reach both native Accepted indicators and leave the window unresolved. | No offer change or overall60s timeout decline races the valid pair. After15s unresolved, OUTCOME_HOLD; new requests/hops stop. Changed/unsafe pair is still rejected. No profit/webhook claim. |
| Closure/rotation | Decline/cancel a trade and let requests resume. Reopen/recreate the GUI between sessions. | Closed window is not reported as completed. Player remains processed for outgoing rotation; raw eligibility remains available. Next unprocessed eligible player is considered. Old session callbacks never offer into the new window. |
| Bot/real evidence | Try independently labelled bot and real-player servers; record state, elapsed, appearanceScans/score and coverage. | Only fresh two-positive valid appearance evidence authorizes P5 rejection. Animation/partial/unknown outcomes do not authorize bot hops. Real accuracy is not established by two examples or this test table. |
| Runtime respawn/loading | Let a normal respawn or loading transition occur while idle; do not run another script copy. | New work pauses; transient recovery reuses one owner. After15s unresolved: READINESS_HOLD, no hopping. Readiness loss during initial inventory retrieval safely closes before offering or explicitly holds if closure cannot be verified. |
| Hop reentry | After a genuine eligible queue is exhausted, let P5 hop. | No hop while trade/request/uncertain outcome owns the UI. One pinned bootstrap starts in the next JobId; one queue registration. Unsupported Delta queue requires built-in Auto Execute. |

Use existing read-only native trade probe logs for real control identities, countdowns, acceptance events and raw pre/post inventory evidence. A disappearing trade window or AcceptTrade boolean event is insufficient proof of completion.

## Capture a loading blocker without changing the game

Run this read-only diagnostic once while the screen is actually stuck. It does not press selectors, reset a character, close UI or teleport.

```lua
local u="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/962dcafe2b5c535ed7c94293ebb812693404d4e7/pdiddler/pdiddler_readiness_v1.lua"
local r=loadstring(game:HttpGet(u,true))()
local p=game:GetService("Players").LocalPlayer
local s=r.read(game,p)
local c=p and p.Character
print("[PDIDDLER READY]",s.reason,"character",c~=nil,"root",c and c:FindFirstChild("HumanoidRootPart")~=nil,"PlayerGui",p and p:FindFirstChildOfClass("PlayerGui")~=nil,"CoreGui",s.coreGuiObserved)
if s.loading then print("[PDIDDLER LOADING]",s.loading.path,s.loading.text) end
if s.detail then print("[PDIDDLER READY ERROR]",s.detail) end
```

A readiness snapshot stops at the first unmet condition; an unvisited field is not proof that the object is missing. The snippet checks character/root/PlayerGui presence independently.

Needed native evidence: exact overlay path/text, whether character/parts/request widgets exist at that moment, the last native exception, and whether a clean client with only this build reproduces it. Split/localized labels, inaccessible CoreGui or unexposed engine state may not be observable from this observer. No cause is invented for those cases.

## Capabilities deliberately OFF

Automatic final Accept/Confirm; completed-trade counting; whole-inventory reconciliation; and Discord network reporting remain disabled. The precise blocker is still an unproved native acceptance/confirmation sequence and transaction-correlated completion plus exact stable raw inventory deltas. Existing pure completion/outbox contracts remain preserved; GUI closure does not enable them. No new MM2 gameplay verification, native loading repair, measured bot accuracy, webhook success or live profit is claimed.
