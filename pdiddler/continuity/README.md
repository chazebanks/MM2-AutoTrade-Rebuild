# Gingerscope Black Box / Execution Manager / Memory Recovery (v1)

**Start new conversations at `pdiddler/START_HERE.md`, then the pinned `pdiddler/NEXT_CONVERSATION_HANDOFF_2026_11_11.md` and this continuity contract.** This directory is a **metadata-only control plane**. It does not change MM2 scripts, perform trades, authenticate server settlement, contact Discord, auto-retry a job, or provide automatic iPad runtime uploads.

## Startup contract

1. Read manifest.json, policy.json, current_state.json, history_index.json from the **latest main branch**, not prior chat memory. Run the Python module's verify and recover commands in a checked-out repository. A PASS is an anchor/hash and schema check, **not** proof every stage was read.
2. Inspect any changes to main and changed source anchors since the checkpoint's sourceCommit. When an anchor changes, the gate **fails closed** until a separately reviewed update refreshes its Git blob and associated checkpoint.
3. Read the original relevant historical sources, PRs, source modules and test receipts for the task. Index coverage is explicitly **partial**: stages 1–118 and branch-only PRs must still be examined when relevant. Do not claim full-history audit based on a passing gate or the mere existence of stage headings.
4. Respect permanent critical rules in policy.json, and recheck actual current code, CI, market sources and device evidence independently before making claims.
5. Before writing a new job, check whether the relevant branch/PR/check already exists. Start metadata with a unique job ID, retain its exact source SHA, and **never re-execute side effects after a timeout merely because status is RUNNING/UNKNOWN**.

## Commands

~~~sh
python3 -m pdiddler.continuity.manager verify
python3 -m pdiddler.continuity.manager recover
python3 -m pdiddler.continuity.manager job-start --id job-continuity-demo --task 'Verify one exact source change' --source-commit 7216c4db84a5a7c95227ff09fb97b27106f44406
python3 -m pdiddler.continuity.manager job-status --id job-continuity-demo
~~~

The job-start command creates a PLANNED **metadata-only** JSON file under pdiddler/continuity/records/. It does not execute. Commit sanitized job metadata deliberately if persistent history is desired; it is not durable remotely until committed and pushed. A repeated job ID returns EXISTS_NO_REPLAY, not a new execution.

To record a completed *metadata* phase (only after reviewing the linked evidence):

~~~sh
python3 -m pdiddler.continuity.manager job-progress --id job-continuity-demo \
  --status RUNNING --evidence https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/228
python3 -m pdiddler.continuity.manager job-progress --id job-continuity-demo \
  --status COMPLETE --evidence https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/228
~~~

Each transition is a new numbered, Git-friendly, hash-chained file; no existing job record is overwritten. A completed or blocked job cannot be silently reopened. An interrupted job requires an explicit new RUNNING transition with a relevant evidence URL after inspection; no code is automatically rerun. GitHub PR/commit/action URLs are *pointers* for human verification, not cryptographic proof of their content.

## Private evidence recorder

The existing repository is PUBLIC. **Never put actual Discord messages, usernames, opaque item IDs, game instance IDs, private screenshots, runtime packets or client logs in this repository.** Only curated data with a strict allowlist may be saved outside it:

~~~sh
mkdir -p /path/to/private-evidence
: > /path/to/private-evidence/.gingerscope_private
python3 -m pdiddler.continuity.manager event-save \
  --id evt-example123 --private-dir /path/to/private-evidence \
  --event-file /path/to/curated-allowed-fields.json
~~~

An event requires exactly stage, status, reason, clientCallbacks, guiTransitions, scriptOffers, scriptAccepts, scriptDeclines, tradeOutcome. All numeric counters are nonnegative integers; reason is an uppercase code; tradeOutcome must be UNKNOWN. Exact-id duplicates are idempotent and differing payloads fail closed. Source is marked SANITIZED_CLIENT_OBSERVATION, never settled/verified. This is **not yet automatically connected to iPad/Delta** and not a full event stream. Automation requires separate verified private collection infrastructure and real-device permissions.

## Public PR navigation snapshot

The read-only public GitHub pull-request catalog at pdiddler/continuity/public_pr_catalog.json was fetched from the project PR API on November 11, 2026. It contains **215 PR entries** (41 merged as of capture) and title-based pointers for **117 of 121 numbered stages**. Stages **37, 38, 73, and 117** have no exact Stage-number reference in PR titles. A PR title does not verify its code, tests, merge safety, device outcome or stage completion. Entries include OPEN and CLOSED_UNMERGED records; do not treat them as merged.

The catalog is blob-pinned in manifest.json alongside critical rules, current state and the narrow historical evidence index. Its counts are a snapshot, not a live PR tracker. New conversations use it to locate original PRs and then read the relevant evidence, not to claim all stages were reread.

## Agent startup hooks

The repository root AGENTS.md and .github/copilot-instructions.md direct source-aware agents to run verify/recover before Gingerscope changes. This applies when those agents actually load the repository. It cannot force a completely new ordinary ChatGPT chat to fetch GitHub without being instructed or having tools available.

## Known limitations and non-negotiable follow-up

- No platform can guarantee ChatGPT request latency or eliminate server-side retries. This design makes job *state* recoverable; it does not remotely execute pending jobs in the background.
- The current history index contains verified **pointers**, not a 121-stage source audit. Build a complete stage/branch evidence catalog with independent PR hashes as follow-up before claiming total coverage.
- The job ledger currently supports immutable metadata creation and hash-chained transitions, not an automated GitHub Actions dispatcher/result harvester. Do not claim jobs automatically finish or resume.
- The sanitized evidence writer stores private curated input only. It does not prove source authenticity or automatic trading safety.
- Future updates must atomically reconcile source blob pins, current checkpoint, indexed evidence and critical-rule changes in a reviewed PR. A changed policy must never silently override established rules.
