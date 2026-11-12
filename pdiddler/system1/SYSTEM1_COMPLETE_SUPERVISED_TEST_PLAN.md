# System 1 — Supervised Trading Engine: one integrated MAIN/ALT test program

**Status: DRAFT.** The four-round native manual-client GUI script is a **diagnostic**, not the finished trading engine. It does NOT automate Part 3 requests, Part 4 offers, final Accept or trade settlements. The purpose is to exercise **multiple distinct trade windows with the same consenting ALT in one server**, with a step-by-step purple GUI and an immutable, sanitized per-round report.

**Source:** `chazebanks/MM2-AutoTrade-Rebuild` / `pdiddler/system1/`; dedicated consolidated draft PR #241, base verified main `a3c209659942e8b45eec5da3555f7cfb83059c59`. This workstream is intentionally consolidated instead of creating one issue/stage/PR per tiny test.

## What is reused, not rewritten

- **PR195 protected TradeIO** — `pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua`, verified original Git blob `eb4dc6342d1d6dda6292490cd8fa00314199d589`. Only `trade()`, `partnerName()` and the original bound read path are used. **No outbound API called.**
- **PR199 original guarded P3/P4 bridge** — `pdiddler/supervised/supervised_p3_p4_handoff.lua`, blob `d496d6311dc6c5e24e059fcd71014e274a4be76b`. Each newly opened trade gets a fresh **manual-consent** client-only bound session. Its GUI roots, ALT username, four physical slots, quantity labels, accepted flags and exact ancestry must pass. Manual binding is NOT an actual Part3 request/rotation/processed-event authority.
- **Stage100 collision-safe overlay** — `pdiddler/new_part4/stage100_screen_prompt_overlay.lua`, blob `e0eac8e039655999bd7bbac1f12da179db7c22ed`. New purple instructions refuse to overlap original MM2 trade controls rather than force-screen buttons into unsafe space.
- **PR237/239 client-only receipts** proved one user-preapproved automated placement, ALT add/remove and read-only ABA revocation on MAIN iPad. Those tests are **closed**; do not repeat them. **PR240** draft candidate rejects a second approved item after an observed A→B→A, but remains offline and is **not** integrated into the read-only four-round manual runner.

**Known single-user P3 limitation:** the original real outgoing coordinator holds both `processed[userId]` and a consumed-event map for its P3 epoch. This is essential anti-replay. It cannot reissue multiple independent automatic requests to the same ALT by simply clearing old `processed` entries. This test program instead uses fresh manually requested trade windows; actual same-ALT P3 rearm/epoch regeneration requires a separately proven integration within System 1, preserving anti-replay.

## Setup for MAIN iPad + consenting ALT

Both accounts join the **original** Murder Mystery 2 experience in the **same fresh Roblox server**. Exact ALT username is `venossgaming90190`. No other legacy pdiddler/Delta controller is running on MAIN. MAIN needs **two inexpensive, separate non-Gingerscope weapons** available in inventory for round 4; ALT needs two inexpensive weapons. Duplicate copies may appear as **one** stacked slot, so use two visibly distinct weapons when testing the two-slot case. **Do not use expensive, rare or protected weapons.** The script never presses final Accept, and neither human should press final Accept. No items need to transfer. Use **manual Decline** on MAIN at the end of every trade window.

Execute the exact-head reviewed `SYSTEM1_MULTITRADE_GUIDED_NATIVE.lua` on **MAIN only** after CI release. It creates a purple collision-tested, unmoving `SYSTEM 1 | TRADE n/4` panel with **DoThis** (who acts next), **Evidence** (current phase and physical slot counts), **Safety** (NEVER FINAL ACCEPT), **COPY** (sanitized progress, stays active), **STOP** (terminal plus copy), and **NEXT ROUND** (enabled ONLY after the trade window closed and the prior round was recorded). The GUI advances on **two consecutive safe actual P3/P4-compatible GUI snapshots** at each mutation step; a one-frame flicker will not advance.

### Trade 1 / 4 — handshake and empty close

1. The purple panel says **ALT: send MANUAL trade request to MAIN**. ALT uses the normal MM2 request controls.
2. **MAIN accepts the incoming REQUEST only**; neither user touches the trade's **final Accept**.
3. Both item offers stay empty. Wait until the purple panel says **MAIN: verify BOTH offers empty. Manually DECLINE trade 1.** The protected client bridge must see two stable empty reads before this appears.
4. MAIN manually taps **Decline** in MM2. Once the original trade window has closed, the purple panel says **REVIEW** with `CLIENT_SEQUENCE_PASS` (or a specific INCOMPLETE reason). Tap **NEXT ROUND** only once.

Checks: exact ALT username, one visible trade root, original P4 protected empty snapshot, accepted flags unset, client GUI close. **Not** server settlement or actual P3 rotation.

### Trade 2 / 4 — ALT add and remove

1. ALT sends **a NEW manual trade request**; MAIN accepts REQUEST only. Both offers empty. Wait for the panel `R2_ALT_ADD`.
2. ALT manually puts **ONE cheap weapon** in **ALT's** offer. MAIN leaves its offer empty. Wait for the panel `R2_ALT_REMOVE`.
3. ALT removes the **same** weapon, leaving ALT's side empty. Wait for `R2_CLOSE`.
4. MAIN manually **Declines**, waits for **REVIEW**, then taps **NEXT ROUND**.

Checks: actual ALT physical slot 0→1→0 with two stable samples each, MAIN stays at 0, P4 original bridge still safe.

### Trade 3 / 4 — two-sided offer and observable ABA

1. ALT sends a **third NEW manual request**; MAIN accepts the request only. Both offers empty. Wait for `R3_MAIN_ADD`.
2. MAIN manually puts **ONE cheap non-Gingerscope weapon** into MAIN's offer. Wait for `R3_ALT_ADD`.
3. ALT adds **ONE cheap weapon**. Wait for `R3_ALT_REMOVE`.
4. ALT removes its weapon while MAIN **does not change** its item. Wait for `R3_MAIN_REMOVE`.
5. MAIN manually removes its own test weapon. Wait for `R3_CLOSE`. MAIN manually Declines and clicks NEXT ROUND after REVIEW.

Checks: original P4 exact partner and two-sided physical slots; ALT's 0→1→0 while own remains one; own eventually returns 0. This is client-observed ABA, NOT proof of authenticated server revision or a second scripted physical placement.

### Trade 4 / 4 — two slots per side with stepwise withdrawal

1. ALT sends a **fourth NEW manual request**; MAIN accepts the request only. Both offers empty. Wait for `R4_MAIN_TWO`.
2. MAIN adds **TWO distinct inexpensive, non-Gingerscope weapons**, resulting in **TWO visible physical slots** (not a single x2 stack). Wait for `R4_ALT_TWO`.
3. ALT adds **TWO distinct inexpensive weapons**, also two physical slots. Wait for `R4_ALT_ONE`.
4. ALT removes **ONE** offered weapon. Wait for `R4_ALT_EMPTY`.
5. ALT removes its **remaining** offered weapon. Wait for `R4_MAIN_EMPTY`.
6. MAIN removes **BOTH** own test weapons. Wait for `R4_CLOSE`. MAIN manually Declines.
7. Once **REVIEW** appears, tap **NEXT ROUND**. GUI should say **DONE**. Tap **COPY** or **STOP** to copy the single report covering **all four trade windows**.

Checks: original P4 physical-slot count vs quantity, absence of accidental extra slots, correct two-sided withdrawal sequence and clean closure in fourth fresh client root event.

### If a round fails

A prematurely closed or incorrectly changed trade is recorded as `INCOMPLETE`, **not a fake success**. If GUI instructs to **MANUALLY DECLINE** after a failed step, close the original trade; **NEXT ROUND** appears only after closure and allows the remaining separate test rounds. **COPY** can be used at any time to inspect a partial report. Missing partner, multiple visible TradeGUI roots, accepted-state ambiguity, protected Gingerscope on outgoing side, malformed slot text, camera/GUI overlap, unexpected change to the other side, changed original Roblox JobId, stale owner or observer exception triggers a **global STOP** instead of letting unsafe observations continue. Once stopped, do **not** try to restart in the same job; use the saved error receipt and review source.

### What to send back

Paste the single native JSON report with `schema="gingerscope-system1-supervised-multitrade-native-v1"`, a new `runNonce`, `completedRounds`, `passedRounds`, `failedRounds`, `openedTradeWindows`, `observedStepTransitions`, and each entry of `rounds` with its `reason`. Successful client-only outcomes should report **four completed/passed rounds** and four opened windows. No weapon names, values, user IDs, GUI paths, inventories or private webhook content are serialized. `tradeOutcome="UNKNOWN"`, `serverCompletionProven=false`, `p3RequestOriginAuthenticated=false`, `authorizesOffer=false`, `authorizesAccept=false` and `mayUseForStrategyLearning=false` remain mandatory for every result.

## System 1 integrated acceptance matrix — beyond these four manual tests

| Engine function | Existing proof | What will certify subsystem completion |
|---|---|---|
| GUI partner, slot and accepted-state safety | Original PR195/199 + native guided tests | Four-round repeated manual native GUI receipt with no false passes |
| P3 contact selection, request, and queue | Supervised P3 one-shot and actual first ALT contact | Fresh provable P3 session/epoch + distinct new request for same ALT, anti-replay maintained |
| One-shot MAIN approved offer | PR218 native true `offerAttempts=1` | Preserve exact-user preapproval, no duplicate offers, correct item ownership |
| 1–4 approved physical offers / ABA | Original 4-slot tests + PR240 draft guard offline | Real guarded multi-item integration, original P4 bound session + continuous active mutation witness |
| ALT dynamic mutations and replan | PR237/239 native observed client changes | Continuous watcher covers inter-item gap, aborts on missed freshness, safe removal/rebalancing separately reviewed |
| Cancel/timeout/decline | Partial original guided tests | Full original GUI close, per-round no-repeat, P3 resume/re-request independently verified |
| Recovery and safety | Watchdog tests | ALT leaves/rejoins, wrong-root spoof, UI overlay loss, two concurrent roots, stale job, duplicates, no manual Accept ambiguity |

Only after these pass should the **supervised trading engine** be called functionally complete. It still cannot be labeled autonomous economic trading or independently settled. Market source, inventory binding, bilateral attractiveness, final acceptance and strategy learning remain separate release blockers.

## Script / test files

- `pdiddler/system1/system1_multitrade_client_walkthrough.lua` — pure four-round strict state/step observer.
- `pdiddler/system1/SYSTEM1_MULTITRADE_GUIDED_NATIVE.lua` — one-session purple GUI, read-only original P4, fresh *manual* bound per trade, STOP/COPY/NEXT.
- `pdiddler/ci/system1_multitrade_walkthrough_mocks.luau` — four rounds plus negative paths.
- `pdiddler/ci/system1_multitrade_native_original_mocks.luau` — actually load original guarded P4 IO and bridge in mocked Roblox, open/close four separate trade windows, no remote.
- `pdiddler/ci/check_system1_multitrade_integration.py` — protected blob/source/safety checks.
- `.github/workflows/gingerscope-system1-multitrade.yml` — source-pinned Lune and Python CI.

**Do not invent an iPad loader or claim a real-device pass before exact PR-head CI succeeds and verified native revision is shared.**
