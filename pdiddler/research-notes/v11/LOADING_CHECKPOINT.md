# V11 loading-readiness checkpoint — 2026-11-04

## What is and is not established

Confirmed source defect: V10's initial game:IsLoaded()/PlayerGui check plus P2 returning true is insufficient to establish readiness. P2 deliberately returns true when no tablet picker is observed for25 seconds and when the optional friend prompt is absent for3 seconds. These are valid selector outcomes, not native world/character completion signals.

The repository contains neither MM2's native Loading Character/Loading World loader scripts nor the exact paths of those overlays. There is no evidence here establishing whether a user's persistent screen is a backend delay, native local-script exception, failed character replication, or interference from another injected script. The new code prevents premature automation and bounds observation; it cannot claim to repair an unobserved native loader failure. The earlier TradeModule:42 GetChildren error happened after a physical Trade tap and concerns request ownership; it is separate and outgoing v16's proven15-second/no-resend handling is preserved.

## Documented engine guarantees

Roblox's [DataModel:IsLoaded documentation](https://create.roblox.com/docs/reference/engine/classes/DataModel#IsLoaded), corroborated through the official [creator-docs source](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/DataModel.yaml), states: “When all initial Instances in the game have finished replicating to the client, this function returns true.” This says nothing about a later custom loading routine finishing. The first Firecrawl targeted extraction returned an unrelated teleport sample and was rejected; the official source supplied the actual passage.

The [Player CharacterAdded documentation](https://create.roblox.com/docs/reference/engine/classes/Player#CharacterAdded) states it fires before the character is parented to Workspace; appearance can arrive later. Character existence is insufficient. We do not wait for a server-only appearance event or infer readiness from avatar accessories.

## Implemented boundary

- Frozen P2 still owns Tablet and friend Play actions, unchanged. No blind extra presses or selector re-execution.
- One read-only readiness module checks initial replication; LocalPlayer/PlayerGui; an alive Humanoid and BasePart HumanoidRootPart in the current character under Workspace; the known phone/tablet request-widget structure; and the trade-window structure. This is readiness for the automation's dependencies, not a claim all streamed world assets are loaded.
- Visible labels whose full normalized text is Loading Character or Loading World block readiness, with the exact observed text/path retained. Hidden ancestors and invisible text do not count. CoreGui inspection is optional and its unavailability is recorded; unreadable PlayerGui inspection fails closed. Unknown/native UI paths, split/localized labels or hidden engine state can still require a live capture.
- Startup waits for stable same-character/GUI/parts for0.35 seconds, up to60 seconds after selectors. It then observes for10 seconds using the existing gate. After scanner startup it checks readiness again (up to15 seconds) before arming P4/outgoing.
- Request-widget structural discovery is shared with the loader's pending/hopping safety check, rather than another competing resolver.
- During operation, readiness gates only scanner facade copies and new work: raw eligibility records remain intact. A brief delay recovers without another outgoing owner. After15 seconds unresolved, outgoing stops, the integration holds, and hopping remains blocked. P4 rechecks this same readiness function at offer/removal boundaries, including after inventory yields. Identity-bound safe decline is still available. If readiness disappears during initial inventory retrieval, P4 safely declines before offering, or enters the shared terminal hold if identity-bound closure cannot be verified. It does not retire into an indefinite visible-window wait.
- No character reset, LoadCharacter RPC, camera/world change, GUI deletion, teleport workaround, global queue clearing, or physical Trade-click edit is introduced. Stop/rejoin is the recovery for unresolved native state; the automation never pretends that waiting repaired the game.

## Verification and live blocker

Offline:8 readiness tests,14 revised-loader integration tests, and two additional full production-P4 inventory-yield/readiness regressions pass. All are mocked Roblox/scheduler tests. The original outgoing v16 suite's34 cases pass unchanged. Exact loading UI/hang cause and physical interactions still need native MM2/iPad validation.

Precise capture needed if it holds: integration stage/reason, readinessState.loading.path/text if present, readinessState.character/root/playerGui presence, CoreGui observation availability, and the last native console exception. Compare an ordinary clean join, a delayed join that resolves, and a stuck join with only this one pinned build. Do not execute several versions in the same JobId. This separates normal delayed readiness from reproducible interference without attributing a cause from a screenshot alone.
