# Mandatory in-game instructions for manual MM2/Delta tests

**User request, November 10, 2026:** When a pdiddler / Gingerscope test requires the user to perform a sequence of actions inside Murder Mystery 2 on iPad/Delta, show the next action **directly on the game screen**. Do NOT rely on ChatGPT chat instructions or Delta console messages alone.

## Non-negotiable requirements for subsequent conversations and coding agents

1. **Use an in-game `PlayerGui` ScreenGui overlay** for every interactive manual/native test with multiple user actions. Keep it compact, high-contrast, and legible on iPad. Position it automatically in a verified safe area outside live trade/inventory controls; if manual dragging is offered, constrain movement so it cannot cover those controls. Refuse or adapt safely when no suitable placement is available. A small purple/black panel matches the established pdiddler aesthetic. It must not fabricate data or intercept/simulate trade-item clicks.
2. Display **the single current action**, which account performs it (**MAIN or ALT**), any expected slot count or offer state, and an explicit "**DO NOT FINAL ACCEPT**" warning for observation-only tests. Start with a manually-open-window/wait instruction where applicable.
3. **Advance the on-screen step only when the actual observer verifies the previous step**, not merely because a timeout elapsed or because text was printed. Preserve sanitized console and clipboard diagnostics as a secondary audit trail.
4. On terminal success or error, show an understandable **COMPLETE** or **STOPPED/INCONCLUSIVE** panel and tell the operator to paste the sanitized report. Keep terminal results visible until the operator dismisses the panel. Allow panel dismissal only after the diagnostic finishes; do not obstruct or change the trading UI.
5. **Fail closed if the panel cannot be created or updated** for a manual multi-step test. Do not silently continue a sequence with console-only prompts; show a diagnostic status when possible.
6. Add **real Lua native-wrapper + mocked Roblox GUI regression tests** for overlay creation, ordered transitions, final/error states, actual viewport positioning, non-overlap with trade controls, and any bounded drag feature, no overlay before arming, and failure to create UI. Python/Lua CI and baseline workflows must be green at the exact commit, and one real iPad confirmation is required before claiming live overlay effectiveness.
7. Screen instructions do NOT imply permission to automate an item offer, press Accept, trade with arbitrary players, teleport, or send completed-trade webhooks. Existing identity, immutable revision, live price, settlement and consent gates stay separate. Do not claim client-local offer observations prove server settlement.
8. At each new conversation, **read `pdiddler/GINGERSCOPE_LATEST_CHECKPOINT.md` and this file**, plus current stage-specific handoff and code, before modifying the script. Keep the latest prompt/UI behavior and exact CI/native evidence recorded in GitHub. A script only belongs in the user-facing next-step instructions after its exact pinned source and UI tests have passed.

## Concrete first implementation

The Stage100 two-sided ALT-add → MAIN-add → ALT-remove native diagnostic in [draft PR #170](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/170) has a compact purple `PDIDDLER_STAGE100_ONSCREEN_GUIDE` panel that is automatically docked in a tested non-overlapping area of the live trade screen (not freely draggable). It displays the current step, distinct MAIN/ALT actions, warning against final Accept, and terminal PASS/STOP reason. The script remains read-only and emits `[GINGERSCOPE STAGE100 TWO SIDED EPOCH]` aggregates. **This document is a durable requirement for ALL future native multi-step pdiddler tests**, not just Stage100.

Any future changes to GUI style or positioning should be grounded in the user's actual iPad screenshot and tested without degrading trade controls.
