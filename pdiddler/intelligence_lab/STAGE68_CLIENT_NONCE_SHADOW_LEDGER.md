# Stage68 — Client run nonce and replay-safe shadow observation ledger (NO trading)

## Trigger

The user submitted the *same Stage66 read-only native JSON twice*. It reported `AcceptTrade(false)` at +12.0s then `AcceptTrade(true, TABLE_1)` at +14.2s around GUI closure, a single exact private raw received-key string equal to the one gained raw `Weapons.Owned` key, and two own postclose reads showing +1 eligible copy. This is a strong **client-local consistency observation**, not a server transaction ID/settlement or confirmed trade economics. The Stage66 JSON lacks a client-run nonce, so automatic deduplication cannot distinguish a repeated copy from a coincidentally identical second run. In the existing conversation, it is one repasted observation.

Stage67 [draft PR120](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/120) validated the exact Stage66 native evidence fields and rejects forged/completed/learner flags; [exact-head CI 42559204035](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42559204035) passed 7/7 tests with 1200 corruptions and 98/98 inherited intelligence tests.

## This one issue

**Stage68 source:** `pdiddler/new_part4/STAGE68_READONLY_CLIENT_NONCE_OBSERVER.lua` derives from the post-audit privacy-scrubbed Stage66 wrapper, with no change to its core scanner, passive event observation, in-memory equality, or trading permissions. On valid original-MM2 startup only, it calls `HttpService:GenerateGUID(false)` exactly once, validates a canonical 36-character hexadecimal-hyphen UUID shape, lowercases it and stores `clientRunNonce` with `schema=gingerscope-stage68-client-run-id-observation-v1`. If unavailable or malformed it finishes `INCOMPLETE` before any trade listener/scan and refuses to mint an ID. The nonce is **client-generated, not signed by MM2**, not a Roblox-server settlement identifier, and can be copied or forged by other local scripts.

All previously verified Stage66 privacy and safety invariants remain: same one scanner, baseline and two postclose reads, passive `AcceptTrade` arguments, private raw comparison, shared-environment raw snapshot cleanup after every exit, zero automatic trades, offers, Declines, Accepts, hops, market valuations, webhooks or Discord learner.

**Stage68 shadow intake:** `scripts/stage68_shadow_client_run_ledger.py` is a pure Python in-memory example which stores **only a set of source-run GUIDs**, not payloads/accounts/items, without any persistent store or Discord connection. Identical pasted copies with the same nonce produce `DUPLICATE_CLIENT_RUN`; a fresh nonce produces `SHADOW_CLIENT_OBSERVATION_ONLY`. It deliberately cannot prove different *trades* were completed even with distinct client nonces, and does not claim production-durable idempotence or provenance authentication. Inputs with forged server/Accept/learning flags, missing private raw-data cleanup, unverified callback match, invalid GUID or incomplete status are `QUARANTINED`. All shadow outputs set `distinctTradeCount=0`, completed/rejected counts=0, market training examples=0, profits=0, server transactions=0 and all learner/webhook/auto Accept flags FALSE.

**Explicit limitation:** Shadow intake checks its own nonce and safety-flag subset, not the complete Stage67 native evidence schema. A future integrated ingestion layer MUST run strict Stage67-style source field validation too before even quarantined archival, and must never trust self-attested attributes. The in-memory seen set cannot guarantee durable replay protection across process restarts; later Supabase or another durable persistence layer could enforce a unique `source_run_nonce` constraint once authorized, separately from `server_transaction_id`.

**ALT test account:** `venossgaming90190` is the user's controlled test ALT. Exclude these trades from Discord market learning regardless of how good client evidence appears. Distinguish opponents' actual rejections from our declines, closed GUI, stale value prompts and timeouts. A real rejected-trade learner requires proven actor/offer/session attribution. The user ultimately wants strategic learning from both completed and rejected trades; Stage68 is a nonce/idempotence prerequisite, not a learner activation.

## Tests and manual work

Actual Lua5.4 Stage68 wrapper under fake Roblox GUI/RemoteEvent/JobId with a fake `HttpService:GenerateGUID`, including invalid/missing GUID negative cases, no extra scanner call, private key non-export, stale partner/GUI/invalid terminal readbacks and 160 seeded interleavings. The same pinned Stage66 core and Stage65 equality helper are validated by Git blob identity and syntax. Python shadow-ledger tests check 1,200 corrupted entries, repeated copy, different client run IDs and zero trade/learner permissions. Full inherited Python intelligence tests run in CI.

This is a DRAFT stacked on PR118, **not merged or enabled**. It does **not** require a repeat user ALT→MAIN item transfer to prove its offline idempotence contract. A future real non-transfer diagnostic could check whether the client generates the expected nonce, but no live gameplay test is justified merely to restate earlier Stage66 callback equality. If a native Stage68 observation is later required for a distinct purpose, use only its exact audited immutable commit and only after green CI.

## Current source references

- Stage66 native evidence and future raw-map scrub [PR118](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/118).
- Stage67 strict offline evidence validator [PR120](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/120).
- Local client GUID is not authenticated backend settlement; Roblox's general HttpService API does not define MM2-specific trade outcome semantics.
