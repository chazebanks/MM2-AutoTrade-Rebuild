# Issue 1 integration fix implementation plan

Goal: deliver a separate reviewed test build; preserve existing modules byte for byte.
Spec: https://github.com/chazebanks/MM2-AutoTrade-Rebuild/issues/1

Architecture: one V3 bootstrap owns startup and monitoring; P5 V2 alone owns
HTTP discovery and teleports. Retain immutable P2, Fast Gate V5, scanner v6.8,
outgoing v15, and P4 v2.3 EXTREME GUARD. No final trade acceptance.

1. Add a deterministic Lua scheduler/Roblox boundary fixture. Reproduce V1
   missing Container path, silent async failure, and permanent startup lock.
2. Add V3 integration tests before implementation: nil-returning gate, failed
   fetch/compile/execute, bounded P2/scanner initialization, stale gate generation,
   ten-second observation after download, bot vs animation uncertainty, missing
   and recreated UI, active trade/request, joins, authoritative scanner records,
   45-second exhaustion, duplicate and partial-init reruns.
3. Implement V3 with explicit phases/reasons, cancellable bounded calls,
   fetch-only retry, immutable source pins, fail-stop/dirty-server lock, shared
   legacy-controller guards, exact dynamic GUI paths, and final scanner recheck.
4. Add P5 V2 tests then implement bounded serialized discovery/teleport work,
   late-failure handling, visited persistence, and terminal hold on ambiguous
   teleport progress. Never issue another teleport after uncertain progress.
5. Run all isolated suites and syntax checks, verify pinned sources exist and
   preserved files match baseline. Review independently, document diagnosed
   defects and Delta-only uncertainties, open a PR against the issue branch.

Review focus: suspended calls resuming after timeout; unsafe retries after
scanner initialization; request UI reconstruction; unknown records during joins;
teleport Started without completion/failure. Include regression tests for each.

Execution: continue inline under the user's investigate/fix/verify/PR instruction.
The GitHub connection supplies source and publication because local proxy fails.
No merge, production loader replacement, or existing-module edits.

Live follow-up: console screenshot confirms a strong bot verdict followed by
request-ui-loading. Source-backed desktop/tablet and phone layouts differ.
Extend only the V3 resolver to inspect both and report discovered request paths;
add failing regressions before the change, preserve unknown-UI/request blocking,
rerun the full suite and independent review, then update the existing draft PR.
