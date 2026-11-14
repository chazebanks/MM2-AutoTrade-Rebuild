# System2 independent QA: replayed inventory freshness vulnerability and limited-scope fix (Nov 13–14 2026)

## Confirmed bug before patch
The original `client_inventory_shadow.evaluate(...,evaluated_at_utc=...)` validates a **caller-supplied** current inventory envelope against a strict 60-second source timestamp and returns `snapshotCapturedAt` and `snapshotAgeSeconds`. But original **Parts 3–5** `trade_scenario_lab.inspect`, `attractiveness_evidence_lab.compare`, and `multitrade_growth_replay.simulate` accepted the previously returned shadow **without any new current-time parameter or source age check**. A shadow that was only 10 seconds old when initially built could therefore be reused indefinitely for allegedly fresh strategy arithmetic, although own items may have changed. All original outputs still denied actual Offer/Accept, so this was a **strategy integrity defect**, not proof an unsafe live trade occurred.

## Narrow repair
- Mandatory explicit `evaluated_at_utc` (optional argument defaults to **BLOCKED**, never silently uses the old timestamp) at each original Part3/4/5 public research interface.
- Recheck `snapshotCapturedAt` against that supplied time in `trade_scenario_lab._owned_from_shadow`, which all three modules use. Valid observation age **0–60 seconds inclusive**, initial reported `snapshotAgeSeconds` numeric and 0–60. Reject invalid UTC strings, missing as-of timestamps, future observations and expired shadows.
- Existing source and all session-trust flags remain **unverified**. The caller-provided clock is not an independently authenticated Roblox runtime; fresh arithmetic is not proof of server-owned game items. Native supervised capture will need a proper trusted clock/session anchor.
- Regression updates: Part3 +3, Part4 +2, Part5 +2 targeted new tests; expected **219 total** source-bound Python tests including 212 inherited tests and original frozen Stage120 source.
- Full GH Actions run on exact PR SHA required before green claim.

## Other audit results (NOT falsely declared fixed by this PR)
1. The 189-value snapshot and its original SHA256 pin were rechecked directly: `bb91b545637a0fe8d7dcceebef9070ee9a76210015bdc1737fd78f068acaeb4f`; 189 unique (15 Ancient/128 Godly/46 Chroma), 21 null previous values, five starred displays, 20 ranged prices. `publisherVersion:null` still **not a cryptographic publisher edition proof**; previous independent item-card parity was research corroboration.
2. `multitrade_growth_replay` **evaluates caller-supplied 2–8 hypothetical trades**. It does **not search for or choose optimal trading paths**, and does not call Part4 `attractiveness_evidence_lab.compare` at each hypothetical step. Thus 212 (soon 219) passing tests are not end-to-end strategy optimization tests.
3. These input modules accept *mutable in-memory* `mapped` and `shadow` dictionaries. They check source label, original file SHA declaration, and selected fields, but do not freshly re-ingest the original private bytes at every call or authenticate a game-side instance. They must not be treated as a trust boundary for live deployment. A separate, explicit source-to-decision immutable interface with regression coverage is needed.
4. No real counterparty acceptance/settlement receipts, independent executed retrade liquidity, approved numeric loss budget, actual native iPad capture for this bridge or authorized autonomous final Accept exists. Original frozen Stage120 planner limits candidate total copies to 4 despite corrected physical-slot guard supporting stacks.
5. Previous descriptions of the product as *growth planning* referred to **synthetic supplied-path replay**, not a usable optimizer. Correct terminology and plan distinct tested integration into strategy search and empirical appeal evidence. Do not merge the entire draft research stack or enable live trading based solely on green offline tests.

All changes are research-only; no production P3/P4/Delta, remote calls, webhooks or player data added.

## Verified repair result
- Tested QA implementation at commit `f5d1f2eac25256c47342afbccc6649514a80d420` (draft PR #258) with **219/219** exact-focused Python tests passed, **no skips**, in original-source-bound GitHub run [43542475432](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/43542475432). The workflow verifies historical Stage83 + original PR106 planner + corrected PR182 guard Git blob IDs before tests.
- Same commit's **8/8 GitHub workflow runs completed SUCCESS**. No existing trade runtime/Delta/P3/P4 files changed.
- Source original user export bytes were independently inspected locally again: **64,793 bytes**, source SHA256 `bb91b545637a0fe8d7dcceebef9070ee9a76210015bdc1737fd78f068acaeb4f`, **189 distinct categories+images**, 15/128/46 weapon classes, 21 null historical prices, five starred value displays, 20 range-valued items.
- **No real game identity, partner acceptance probability, settled transfer, or autonomous trading claim is supported by these tests.** The 60-second as-of parameter is caller-supplied, so this is a fail-closed offline freshness check, not a cryptographically trusted clock or replay-proof native receipt.
