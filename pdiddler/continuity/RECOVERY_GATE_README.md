# Gingerscope cross-chat recovery

Start at the [Google Drive recovery entry point](https://docs.google.com/document/d/1QQkA5PHgm8yGk-go-J0_SNzeAEqQZjDpHPwiWzIwfqU/edit). It links to the current checkpoint and original evidence for the active task. Search the decision and failure records for the current issue as needed. Preserve dated records and keep the startup checkpoint short.

## Verify a receipt

Update `pdiddler/continuity/recovery_receipt.json` for the current task. Record the current main SHA as `baseHead`, the active source PR number as `sourcePullRequest`, and its current head SHA as `sourceHead`. Provide one object with `url` and exact `head` for each public Gingerscope PR in `priorEvidence`, including the source PR. Record actual recovery work, applicable failures, a falsification plan, partial coverage and the scope approved for this task.

```sh
python -m unittest discover -s pdiddler/continuity -p test_recovery_gate.py -v
python pdiddler/continuity/recovery_gate.py pdiddler/continuity/recovery_receipt.json
```

The validator matches every cited PR head and the current main ref against GitHub. It blocks stale or unknown refs, malformed input, missing evidence and unsupported authority. If a ref advances, inspect the new source and refresh the receipt. The checked-in receipt records the bootstrap review and becomes stale when its refs advance. PR identity and ref freshness are independently checked. Relevance, reading and history coverage still require review. Receipt success grants no game actions.

## Merge enforcement

The PR workflow runs candidate tests and validates the receipt, including for gate changes. Once this workflow is on main, the separate `workflow_run` verifier starts from the default branch after the candidate workflow completes. It independently binds the run head to an open main-target PR and verifies the receipt as data using code from main. The checkout, receipt and current main ref must agree. It publishes `gingerscope/recovery-evidence` on the submitted head. It never checks out or executes the submitted code. The check attests to that run's snapshot. Recheck cited refs before merge when an associated PR changes independently.

Repository protection determines whether the check is mandatory. After the reviewed bootstrap merge, test the base workflow against both a valid and an invalid receipt. Require up-to-date pull requests and gate ownership on main using rules suited to the repository. The workflow publishes an advisory status from the shared GitHub Actions identity. A mandatory check with independent provenance requires a dedicated status publisher or a rule that binds the specific trusted workflow. Verify rejection of an invalid receipt and direct push on a disposable branch governed by the same rules before relying on enforcement.
