# Gingerscope cross-chat recovery CI gate (research only)

This gate exists because the old `manager.py verify` can PASS with a valid *but stale* November 11 manifest. The new gate does not rewrite the old history or alter any MM2 code. It requires a reviewable, explicitly scoped `pdiddler/continuity/recovery_receipt.json` on non-gate pull requests.

Canonical recovery archive: [Google Drive entrypoint](https://docs.google.com/document/d/1QQkA5PHgm8yGk-go-J0_SNzeAEqQZjDpHPwiWzIwfqU/edit). Follow its companion 01 current-state and 02 failure register, then inspect original GitHub code and PRs.

A valid receipt must record task ID, prior Git head SHA, exact entrypoint name, mission/matrix read confirmations, PARTIAL_NOT_ALL_STAGES_AUDITED coverage, linked PR evidence, prior failures, falsification tests, new findings, and non-live authorization. See `test_recovery_gate.py` for the format. Unknown or absent receipt blocks.

**Limits:** The receipt is self-attested and cannot prove the model read everything or that sources are current. The GitHub workflow runs on PRs, but does not protect main until a repository administrator makes `Gingerscope Recovery Gate / recovery` a required status check with branch protection/rulesets and prevents bypass. This workflow excludes edits to its own gate files so it can bootstrap; this exception MUST be removed or restricted with independent code-owner review before claiming strong enforcement. The workflow does not grant trading or live game authorization.

**Next security hardening:** Fetch/verify latest source heads and immutable evidence digests independently; check source commit ancestry and source recency; require independently reviewed per-component history coverage; enforce gate file ownership and protected main. Until then, status is **PROTOTYPE, NOT ENFORCED**.
