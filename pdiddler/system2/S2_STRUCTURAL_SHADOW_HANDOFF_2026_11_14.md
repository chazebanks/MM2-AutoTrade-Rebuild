# NEXT REAL MULTI-FEATURE MAIN TEST — STRUCTURAL SHADOW PLANNING (NOV 14, 2026)

**This is the NEXT NEW device test, not a re-run of three completed MAIN witnesses.** Draft research-only [PR #269](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/269), stacked on draft #268, #267, etc. Original main/P3/P4/Delta unmodified. This research batch prepares structural **offline** planning, not a live trading strategy or finished System 2.

## What it actually checks — six separately marked subsystems from one operator tap

1. **Nonprice 1–4 physical slot layouts** using currently observed MAIN owned Ancient, Godly, Chroma inventory; protected Gingerscope is never selected. Indicates only whether at least 1/2/3/4 distinct non-target keys exist, not any real trade match, suggested item or buyer.
2. **Quantity/stack concentration vs slot distinction**: singleton/two-to-four/five-plus non-target stack categories, top-four distinct-key copy count *upper bound*; flags non-linear price uncertainty for five-plus copies, never treats extra copies as separate slots or assumes the game can execute them.
3. **Independent synthetic bilateral scenario fixture regression**: ten synthetic pure scenarios cover positive upgrade, positive downgrade, sidegrade with +5 gain, losing downgrade and listed-loss rejection, five physical slots rejected, duplicate slots rejected, outgoing Gingerscope protected and nonlinear stack-price uncertainty. These artificial value numbers do **not** come from Supreme, represent NO real items, are not offer proposals, and cannot produce a trade action.
4. **Always-protected target**: no outbound Gingerscope candidate even if MAIN owns it; report does not expose whether the user owns the target.
5. **Market/source policy**: pinned Stage83 public 189-key registry **expired 2026-11-09T15:56:07Z**, current Supreme edition not admitted through original Stage111→110→104→69 chain, so no listed-value delta, negotiation, source price, market liquidity or approved loss risk is claimed. This source denial does not negate the separately observed 189/189 public page parity.
6. **Live-client local freshness and composition safety**: original MM2 place, MAIN-only one read-only profile `GetProfileData:InvokeServer()`, prior source-pinned 189-key native auditor must pass in the same read, no overlapping owner/trade GUI or unsafe UI, no network writes/teleports/Accept or trade actions. No server authenticated lease or item-instance ownership claimed.

All six outcomes get a distinct status in a sanitized JSON report; no raw weapon names/IDs, user/ALT identifiers, copy of the private 189 current-price browser export, JobId, target possession or per-item holdings leave the device. The test may report **aggregate non-target counts** only. Our account's previous 181/452 & 67/71 witnesses are **closed and not rerun**. This new feature concerns physical-slot structural readiness rather than classification.

## Immutable tested modules
- `pdiddler/system2/native_structural_shadow_core.lua` immutable source commit `95139f6c05f8c186239017ca19f50dbd33cff029`, Git blob `beec3f85712c48ad4cba41d291a89bfc31ecf90a`.
- User's ONE-tap purple/black `pdiddler/system2/SYSTEM2_STRUCTURAL_SHADOW_READONLY_NATIVE.lua` immutable source commit `e4d8728a4402e1a6048b584879475b385e42541b`, blob `dfba5b33602154616dceb5c619acc00fe44e8db6`.
- In the native wrapper: previous frozen 189-key auditor `pdiddler/system2/native_key_reconciliation_core.lua` at commit `eea9d6f5da3dfac8599e2f3e7b9fe1764d6ba288`, Git blob `6d6d5760930c284317b7cee3980b50880ea642fc`.
- Original historical Stage83 `pdiddler/intelligence_lab/stage83_public_slug_registry.lua` at commit `25b48b60fdb2f971bbb6b2a2020f3c7c4432f7ae`, Git blob `40e2a0ff01b70b2d0181c62cae347a08da82bcb8`.
- Original safe Stage100 geometry `pdiddler/new_part4/stage100_screen_prompt_overlay.lua` pinned to reviewed commit `5b8ee35d7f281c23d9c2181abd97a063e59a0660`.

## Test suite
- `pdiddler/ci/system2_structural_shadow_native_mocks.luau`: actually executes pure core plus real original-MM2 native GUI runner and 4 pinned modules in Lune, observes no inventory RPC before button press, exactly one read after, validates expected six features, blocked corrupted historical audit, target owner privacy, bad stack/key, stale session, trade overlay, missing source, prior owner and double taps.
- `pdiddler/ci/test_structural_shadow_oracle.py`: independent Python deterministic 900-case randomized four-distinct-slot stack upper-bound oracle, source/authority/static audits and 4-slot test.
- `.github/workflows/gingerscope-system2-structural-shadow.yml`: pins ORIGINAL bytes to exact Git commits and validates continuity; real Lune **113 assertions PASS**, new Python oracle **7 tests PASS**, inherited **311 original pinned Python regressions PASS** at updated code HEAD `1faa7554a170e8903c761f26a74891323d3895b7`. [Dedicated CI run #43559569699](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/43559569699). Final handoff doc HEAD needs **separately verified exact-head CI** before releasing the runtime instruction to the user. No full live-game test has happened on this NEW batch yet.

## ONE next supervised user action — release ONLY after final CI gate

On MAIN iPad with Delta, join a **fresh ORIGINAL Murder Mystery 2 server**. No ALT needed, no active trade window, no other Gingerscope trading code. Run this one immutable copy-paste line:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/e4d8728a4402e1a6048b584879475b385e42541b/pdiddler/system2/SYSTEM2_STRUCTURAL_SHADOW_READONLY_NATIVE.lua"))()
```

Purple/black panel displays **MAIN — STRUCTURAL SHADOW TEST**, then tap **RUN SHADOW BATCH** once. This one tap reads your own profile, invokes the previously proven game-key auditor in the same read, then checks new 4-slot/stack/synthetic-risk/target/source/freshness rules. When it finishes, tap **COPY / CLOSE** and paste the sanitized JSON in ChatGPT. If clipboard unavailable, a sanitized console `[S2 SHADOW SAFE RESULT]` and `getgenv().PDIDDLER_S2_SHADOW_LAST_JSON` can be used. Do not paste raw inventory, secret keys or per-item account data. If BLOCKED/STOPPED, send the one sanitized report; do NOT force reruns in same JobId.

**Do not authorize any Offer, Accept, Decline, auto trade, Discord profit, real-market strategy learning or approved loss budget** based on this result. No true source authenticity, completed settlement or partner demand/interest is proven. PR remains DRAFT until separately reviewed and approved. After operator's result, next non-redundant task is offline source-admission and isolated hypothetical proposal-quality arbitration, not another catalog census.
