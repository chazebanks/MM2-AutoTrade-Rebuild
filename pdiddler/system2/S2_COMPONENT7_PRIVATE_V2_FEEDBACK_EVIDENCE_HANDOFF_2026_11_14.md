# Gingerscope System 2 — C7 V2 feedback provenance, denominators and abstaining learner
**November 14, 2026 NY | Read-only source-backed engineering checkpoint | ONE authorized component**

## Authority and source of truth
The user authorized **Component 7 only** after C6 draft PR #288. Do not silently proceed to component 8, native iPad, live webhook sending, active chat, public automatic Accept or independent model deployment.

Read FIRST:
- `pdiddler/START_HERE.md`
- `pdiddler/system2/SYSTEM2_MISSION_LOCK_AND_TEST_GOVERNANCE_2026_11_14.md`
- `pdiddler/system2/SYSTEM2_MODULAR_PLANNING_AND_TESTING_MATRIX_2026_11_13.md`
- `pdiddler/system2/S2_COMPONENT6_PASSIVE_PARTNER_INTENT_HANDOFF_2026_11_14.md`
- THIS file, actual C7 code+tests and workflows, public stacked PRs and **private** draft PRs #3/#4 plus their exact CI.

Original five MAIN–ALT completed local inventory delta test iterations CLOSED; sixth identity failure UNKNOWN; do not ask to re-run five window transfers.

## Task classification and scope
- **System:** System2 adaptive evidence and Discord V2 feedback, not P3/P4 mechanics.
- **Distinct new capabilities:** native P3/P4 client event → standardized V2 body (without network); existing independent private bot receives/validates V2; privacy-contained private response evidence auditor distinguishes request acceptance, decline, timeout, cancellation, changed offer, client indicators and UNKNOWN; exposes sanitized denominators and a partner-group-disjoint future holdout feasibility check. No item/offer features or server settlement available from V2; real learning MUST abstain.
- **Critical falsifiers:** duplicate webhook counted twice; forged `completed=true`; client Accept counted server settlement; old V1 historical self-report promoted to reward; unknown close or timeout counted a decline; P3 source switch or revision jump becomes same session; MAIN–ALT test partners leak into real denominator; holdout includes same opponent digest in training; raw usernames/weapon names/chat or transport IDs published to logs/public repo.
- **Source verification:** existing `discord_v2_event_intake.py` public v1 V2 schema, exact `GINGERSCOPE_S2_EVENT_V2` private embed consumer, private collector `scripts/discord_v2_private_archive.py`, private current legacy history and actual V2 archive existence checked, no private data exported.

## Actual implementation

**Public research branch** `research/system2-verified-feedback-v2-gate-nov14`, stacked on C6 PR #288:
1. `pdiddler/system2/private_v2_response_learning_gate.py` — parses ONLY explicit V2 private-bot envelope schema already vetted by strict `discord_v2_event_intake.review` before categorization. De-dupes Discord message IDs, rejects mutated/replayed events, rejects per-episode transport timestamp rollback, requires baseline and original partner/job/lease/offer revision identity. Provides exact **client request** denominators (request accepted by partner, explicit declined, censored pending/timeout), distinct client Accept indicators at final visible revision, client inventory delta claims, chat evidence and cancellation/UNKNOWN separate. MAIN–ALT test sessions excluded. A unique partner digest cannot appear in both tentative chronological train/holdout groups; 12 distinct public partner digests and four disjoint holdout partners needed even to say a future holdout is available. All output is nonidentifying counts, not raw session/partner/Discord IDs.
2. `pdiddler/system2/native_v2_client_response_envelope.lua` — pure read-only native Luau **sender-neutral staged payload** producer from caller-supplied protected P3/P4 client event receipts. The payload body has exactly the 13 non-transport fields expected by private `decode_message`, with source `PRIVATE_BOT_CLIENT_EVENT_CLAIM_NOT_SERVER_SETTLEMENT`. Checks pending→in-trade→terminal phase, current lease/job/local+partner binding before/after, sequential event numbers and offer revisions, separates chat evidence (requires C6 proven direct classification) from client Accept, and marks no verified settlement or sending authorization. It requires externally injected SHA-256 function and per-session private salt/nonce; it does NOT attest that such function is secure or deliver events. The Lune fixture hash function is an INSECURE TEST STUB and MUST NOT be used in a live client.
3. `pdiddler/ci/system2_native_v2_feedback_staging_mocks.luau` — real native engine constructed with synthetic guarded P3/P4 input. Writes temporary local simulated envelope bodies, not real player data, no Discord sender.
4. `pdiddler/ci/test_system2_native_to_private_v2_compatibility.py` — cross-language integration: receives **actual native Luau-produced V2 body**, attaches synthetic Discord transport IDs/timestamps, verifies original existing strict V2 Python receiver and new response gate accept schema and still deny completed trade/profit/training authority.
5. `pdiddler/ci/test_system2_private_v2_response_learning_gate.py` — 19 named adversarial tests, same event split and client-only label behavior, holdout leakage and client-reaction denominator checks. No actual Discord data or game user data.

**Private repo** `chazebanks/MM2-Trade-Research-Private`:
- Existing draft PR #3 `research/system2-discord-v2-ingress-nov14` holds the prior private Discord bot V2 receiver with strict webhook pin, atomic append-only ledger and no settlement inference. Its real collection workflow is **main-only/manual and that PR is not merged**.
- New child research branch `research/system2-private-v2-response-analysis-nov14` (child draft PR #4) adds `scripts/private_v2_response_research.py`, 7 synthetic private tests, and read-only `.github/workflows/private-v2-response-learning-preflight.yml`. It reads ONLY an **already captured** private `events_v2.jsonl`, derives the historically approved transport source without publishing it, invokes immutable SHA-pinned public C7 source and logs only category counts. Does not poll Discord, read bot secret, send webhook, create an archive or train a model. Private-only repository guard.
- **Observed private current reality:** V2 archive file absent on PR #3 branch and private C7 run #43655991958 printed **`PRIVATE_C7=NO_V2_EVENTS_NO_LEARNING`**. No actual V2 delivery, real counterpart episodes, bot ACK, confirmed transaction or holdout evidence obtained. Do not claim otherwise.

## Exact evidence and tested failures
**Public C7 code/test head** `e07584c66862dbe74b71e542b03950ccac85889f`: [public workflow #43655765536](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/43655765536), SUCCESS.
- Actual independent public market refresh with 190 unique site rows → 189 historical Stage83 game-key matches; this is only supporting C3–C6 tests, NOT fresh MM2 server proof.
- **68 inherited Python + 10 C4 Python + 10 C5 Python + 14 C6 Python + 34 C7 V2 strict/evidence Python + 4 C7 cross-language Python = 140 Python tests PASS**.
- **50 C4 Luau + 61 C3→C4 Luau + 179 C5 Luau + 78 C6 Luau + 104 new C7 staging assertions = 472 native Luau assertions PASS**.
- C7 cross-language native→Python checks actual V2 body parser and zero trade/learning permissions. No transport call or Discord webhook sent.
- A first C7 run failed Python syntax (unparenthesized multiline condition), fixed and rerun. No fake green status.

**Private test head** `dcf3a804049f68e1b19a6f2a6e2c0ff26bdbf938`: [private workflow #43655991958](https://github.com/chazebanks/MM2-Trade-Research-Private/actions/runs/43655991958), SUCCESS.
- **7/7 private synthetic tests** and exact public Git SHA `e07584c...` plus C7 source blob `4203cc258d4a8c062adbcdb8a9ab5ab7a8aabe6b` and old V2 blob `20d8a0e8fda75c10a7101b242bfbd9a00d20cb7f` verified.
- The private test initially failed because its generic public test helper used a fabricated test channel, not the private collector's original approved channel. Fixed to bind synthetic records to the APPROVED_CHANNEL imported from the original private collector (without disclosing that ID). Reran to green.

## What C7 does NOT solve
1. The existing V2 schema has **NO raw item/bundle features, value/listing snapshot, preference vector, actual purchase/settlement ID**. Therefore: **cannot train a dependable item-sensitive acceptance model**, and no feature-level strategy improvement is measured. All C7 outputs have `mayUseForStrategyLearning=false`; zero training rows.
2. Client Accept indicator, inventory delta, trade window close and Discord webhook transport claim are not authenticated MM2 server settlement. Completed trades verified: 0. Actual acceptance probability: not measured.
3. The Luau client only STAGES sanitized event bodies. **No reviewed P3/P4 event hook connected, no authorized secure live SHA256 salt/hash injection, no network sender to existing private bot, no bot transport ACK**. Public and private cross-language tests use synthetic transport metadata and insecure test-only digest.
4. Existing private bot collector lives in unmerged PR #3; its only live collection workflow is gated to private `main` and manual dispatch. Component 7's private analysis PR is also draft. There are currently no V2 archived event rows.
5. Actual counterparty refusal, settled trade and retrading outcomes remain unknown; no zero-data real learner can be declared finished. To advance, a distinct later authorized task must prove actual sender→private bot capture and safe offer-feature provenance, without changing game trading or final Accept.
6. Nontrivial game player identifiers, Discord IDs, exact current private owner inventory and trade receipt contents have not been copied into public repo or workflow artifacts.

## STOP
Component 7 offline **collector/evidence gate engineering** is done only when final draft PR tests are exact-commit green. No application/game/device test needed just to rerun old gifts. Wait for authorization for **component 8: full read-only original-P3/P4/market/partner-chat/V2/strategy supervised integration replay, with explicit feature-level training data acceptance plan**. Do not begin before user approval.
