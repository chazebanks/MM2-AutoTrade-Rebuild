# V9 — early market-aware counteroffer (supervised iPad Delta test)

**Status:** versioned, draft, source-pinned code. The market-aware pure planner and the real Luau P4 fixture pass in GitHub CI. **No live V9 outcome has been observed yet.** V8/PR #9 remains the rollback. No old source or bot/scanner/startup/hopping files are modified.

## What changed, exactly
- Existing opening step: watch 2.5s for opponent-first, or select a reachable opener. Existing 0.65s opponent-offer stability check remains.
- **New early counter stage:** After a stable priced opponent offer becomes visible, if our current offer is verified safe but weakly desirable, a pure scoring policy gets **one decision per unchanged opponent offer**. It can select a more appealing safe combination **during native Accept cooldown**. The one rebalancer/transaction executor still applies the actual offer and verifies final slots.
- **Late stage remains V8:** After the early counter (or a keep decision), the native countdown/green Accept readiness gate, 2.5s ready buffer, minimum 9s offer window, two sweeten cap and separate final five seconds remain intact.
- A partner offer edit resets early decision eligibility. Local or partner Accepted freezes voluntary changes. Existing safety rebalancing is never blocked by the one early adjustment quota.
- **Profit floor is +15 Supreme**, no unknown or missing-priced weapon is silently valued at zero. Up to 4 copies per safe plan, 4 slots, exact verified raw identities.
- The early policy **does not model acceptance probabilities**. Candidate market appeal uses verified value-weighted Supreme demand and stability. Early concession budget is a **conservative engineering choice** (up to 40% of profit headroom above +15, capped at 40 value); it is not a statistically supported optimum.
- After the *first* early counter decision, no repeated early edits are attempted on unchanged partner offers. A later sweetener is a different stage. If no demonstrably better candidate exists, keep the current already-safe offer.
- **Manual final Accept, completion accounting and Discord webhook remain OFF in V9**. The older Discord HTTP sender was successfully tested in a different build; do not rebuild it.

## Test environment
- **Before November 4, 2026, 4:42 PM America/New_York**, when the currently pinned 190-item Supreme snapshot expires. After that V9 is intentionally blocked until a newly verified dated catalog is published and pinned.
- Fresh MM2 JobId and **one** V9 auto-execute entry (or paste once manually; never both). Stop old V5/V6/V7/V8 owners first by rejoining fresh.
- Use the **exact immutable V9 GitHub commit SHA** given with the final loader; do not paste or run a moving branch alias.
- Trusted partner / low-value tradable items; keep one screen recording showing native trade slots, green ACCEPT countdown and small console if possible.

## Acceptance test matrix
1. **Opener-first early counter:** Let pdiddler make a small plausible opener, then partner reveals higher-value eligible items. Watch whether our first safe but unattractive proposal is promptly replaced **before cooldown completes**, if the planner finds meaningful demand/stability improvement. The real fixture verified +94 -> +65 with a +30 low-appeal alternative rejected; this is an illustrative scenario, not a guaranteed live outcome.
2. **No unnecessary giveaway:** If existing offer is already appealing, leave it unchanged. Big theoretical profit is not itself a reason to sweeten or decline.
3. **One-shot:** The same unchanged opponent offer must not cause repeated early adjustments or endless cooldown resets.
4. **Opponent change:** Remove/add an item; require fresh exact-value evaluation and a new eligible single early decision for that new their-offer signature. Unsafe changes must halt actions.
5. **Acceptance:** If the opponent or user Accepts, no voluntary early/late sweetening; manual approval identity and +15 safety remain intact. No auto final Accept action should occur.
6. **Late stage:** Only after green ACCEPT has been continuously visible for its ready buffer and the conservative interval has passed, consider up to two further safe improvements.
7. **Negative cases:** Unknown Chroma or missing prices, stale profile, partial rebalancing/recovery, copy overflow, unverified ownership, player leaves, GUI closes, and bot-server hopping. Existing checks remain; report any regression.

## Test result gates, not assumptions
- The source compile/runner and old regressions are offline mocks. Real Delta must validate UI wiring, timing and inventory reading. Do not interpret the planned projected profit as a completed trade.
- Log what was offered, what the other player offered, each *verified* offer mutation and why, elapsed timings, and whether Accept was pressed. Recording + relevant console is enough; no need to paste webhook secrets.
- If V9 fails startup, compare the phase and old V8 status; do not patch unrelated modules until root cause found.
