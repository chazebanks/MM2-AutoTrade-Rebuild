# New Part 4 — Stage 11 defensive-only coordinator

**Draft integration only. DO NOT add to Delta Auto Execute.** No active trade-loader pin changed. This builds on Stage 8 (safety), Stage 9 (read-only native observer), Stage 10 (single-action removal executor).

## Changes

- `p4_coordinator.lua`: one session-bound, dependency-injected coordinator; one monotonic clock; one observation and at most one removal dispatch per poll. No Roblox APIs, game remotes, native built-in clicker, offering, accepting, or decline execution.
- `tests/test_p4_coordinator.lua`: real Stage 8/9/10 modules wired together under a mocked native MM2 trade GUI. Explicitly tests the historical Chroma Watergun case where 3 local slots are present, including stacked Immortal ×2.
- Transitions: fresh Stage 9 `capture()` -> Stage 8 `step()` -> if protective `REMOVE_ONE`, Stage 10 `prepare()` -> bound native adapter `execute()` exactly once -> Stage 10 `dispatched()` -> later independently captured Stage 10 `observe()` -> Stage 8 validates removal proof. A subsequent removal is deferred until the **next** capture, and Stage 8 is rechecked for intervening acceptance/closure.
- `REQUEST_PLAN` is deliberately held; no offer planner is wired. `DECLINE` is a one-time **intent**, never a sent remote or native Decline click. After either terminal intent or STOP, subsequent calls do not click again.
- Errors, uncertain click delivery, or unverified removal fail closed; a fresh read distinguishes an already-closed trade before emitting a decline intent. Observations after root/job/session change cannot inherit a previous action.

## Important production limitations

1. Stage 9 `quoteSafe` is **always false**, even when the market timestamp says fresh. It cannot authorize a proposed trade. The coordinator therefore currently serves **only protective withdrawal and review**, not a profitable trading bot.
2. Market freshness is explicitly required and rechecked on every poll; Stage 11 does NOT verify or refresh Supreme prices. The prior snapshot has a fixed expiry of 2026-11-05T21:55:32Z, after which a fresh, independently sourced dataset and strategy evidence are necessary.
3. Stage 9's real native amount/acceptance nodes and the Stage 10 injected physical click callback have not been validated on the user's live Delta/MM2 interface. Mock tests are not real in-game evidence.
4. A future verified trade arbiter must handle `DECLINE` intents, ensure current root/partner/acceptance, and independently confirm completed/cancelled trades. Stage 11 intentionally never clicks Decline or final Accept.
5. Stage 7 attractiveness/growth code remains research-only. No actual item insertion, economic-plan authorization, auto-accept, webhook, inventory change, or server-hop integration.
6. The existing integrated V15.8 script and Parts 1/2/3/5 remain unchanged. Never merge this draft into the active loader until live read-only diagnostics, monitored click validation, new market data and full trade-replay acceptance tests pass.

## Testing

Tested using a Lua 5.4 library-backed runner, for pure logic and synthetic Roblox GUI only:

```sh
lua pdiddler/new_part4/tests/test_p4_safety_core.lua pdiddler/new_part4
lua pdiddler/new_part4/tests/test_p4_observer_contract.lua pdiddler/new_part4
lua pdiddler/new_part4/tests/test_p4_native_mock.lua pdiddler/new_part4
lua pdiddler/new_part4/tests/test_p4_removal_executor.lua pdiddler/new_part4
lua pdiddler/new_part4/tests/test_p4_native_removal.lua pdiddler/new_part4
lua pdiddler/new_part4/tests/test_p4_stage8_stage9_stage10_integration.lua pdiddler/new_part4
lua pdiddler/new_part4/tests/test_p4_coordinator.lua pdiddler/new_part4
```

Existing 114 tests + 23 new tests = **137/137 passed**, including one regression discovered and fixed in Stage 11: the next `REMOVE_ONE` request must be queued between independent observations instead of discarded after a previous removal is verified.

## Next safe milestone

Stage 12: add a **read-only** Delta diagnostic for real trade-root layout/amount/acceptance and optionally `REMOVE_ONE` verification in a deliberately controlled test trade. Do not deploy this coordinator or old scripts simultaneously. Strategy/market adapter and independently verified acceptance remain later milestones.
