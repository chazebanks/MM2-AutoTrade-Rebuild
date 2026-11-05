# Existing standalone JobId boundary

The ordering change does **not** add a direct JobId fence. A separate probe changes `game.JobId` after the first Immortal insertion while deliberately keeping the old trade root, target, profile and Part 4 session alive. Both controllers continue the same selected 310-value plan:

| Controller | Sends before JobId change | Later sends | Full native call sequence |
| --- | ---: | ---: | --- |
| P4 v10 baseline | 3 | 1 | Boneblade, Iceblaster, Immortal, Immortal |
| P4 v11 value first | 1 | 3 | Immortal, Immortal, Iceblaster, Boneblade |

Both finish with offered value 310, one verified quote reservation commit and **zero completed trades** in the fixture. This shows an inherited standalone context limitation; it does not demonstrate a native teleport, VM lifetime, or completed inventory gain.

Reproduce the intentionally failing direct-fence investigation:

```sh
python3 pdiddler/tests/run_insertion_runtime.py --baseline --jobid-investigation
python3 pdiddler/tests/run_insertion_runtime.py --jobid-investigation
```

Each command runs only this probe and exits nonzero because additional sends occur. Captured outputs are [JOBID_BASELINE_RED.txt](JOBID_BASELINE_RED.txt) and [JOBID_SUCCESSOR_RED.txt](JOBID_SUCCESSOR_RED.txt).

The normal suite labels this continuation explicitly as inherited behavior. A distinct boundary test changes JobId together with invalidating the owner session or closing the native root; it verifies that v11 stops after the first 135, commits no quote and reports no completion. Username/UserId proof changes, expiry, native close, controller stop and stale session have separate stopping checks. No stronger readiness shim or production JobId guard was introduced to make these tests pass.
