# Issue24 Problem A — implementation and evidence ledger

Spec: user's master handoff and Issue24, including both supplements. Work is authorized through a separate draft PR; stop after Problem A. The Common-item P4 defect is deferred.

Base: PR23 a4d68f5b6a4dd7b4bd20bc99660a5600d04a0311 (fresh isolated clone/feature branch).

Design: retain scanner eligibility and incoming APIs. Add a pure strict-price feasibility module, a scanner-facade outgoing-only classification, and a v18 outgoing queue that consumes it at selection and immediately before physical Trade input. The successor V15.4 loader uses the same classification for hopper availability. Unknown/incomplete reads block requests; after a fixed30s verification window they cease blocking exhaustion while remaining unknown. Global holds never age out. Negative decisions never enter the processed ledger. Existing periodic scans reconsider changed inventories. All prior files remain byte-identical.

Approaches: filtering the whitelist would also alter P4/incoming semantics; filtering only outgoing would strand hopper exhaustion. Shared outgoing classification avoids both. Because all verified values are positive, checking each actually owned single giveaway against the complete opponent eligible inventory (negative bound only); a separate <=4 distinct-row single-copy witness excluding its canonical identity is a complete economic existence test for 1–4 giveaway copies: any valid multi-item giveaway contains a cheaper valid single. No probabilistic acceptance claim.

Tasks:
- [x] Reproduce Seer3 using actual scanner parser, current repricer/planner and actual queue; preserve failing output.
- [x] Implement pure feasibility and strict incomplete/expired/quantity/canonical boundaries; test exact +15, slots and quantities.
- [x] Version outgoing and loader/bootstrap; cache bounded own reads outside trades; recheck before send; use shared reachability for exhaustion/final hop gates.
- [x] Run production queue/loader regressions: reachable/incomplete/rescan/join/processed/request ownership/incoming/hop countdown/late final check; run inherited suites and preserve every predecessor blob.
- [ ] Review, publish immutable dependency→loader→bootstrap chain, fetch matching blobs, open unmerged draft PR; report native limitations and stop.

Review focus: interrupted own reads; stale classification during yielding card navigation; mirrored identity eliminating apparent profitability; partial inventories mistaken for complete; processed players rediscovered by rescan; unknown players preventing unsafe hopping.

Baseline: full inherited 37-command V14 suite PASS before any production change (/tmp/issue24-baseline.txt). Official Luau0.745 archive checksum verified. texlua supplies Lua5.3-compatible test execution.

Ruling: user's explicit execution/isolated-PR instructions supply authorization; no redundant design/worktree approval. Use this fresh feature checkout, no extra worktree. Keep +15, native final Accept/Discord OFF, unchanged snapshot expiry and P1/P4/P5 runtimes.

Approved safeguards: fixed unknown30s; own retries0/5/15 then45/90/... with no catch-up; only proven upper-bound impossibility returns unprofitable; final exact-user/fingerprints/own-read/job/price/GUI/ownership fence at mouse-down. Stacking-only opportunities remain unknown. All prior files preserved.

Verification ruling: inherited V14 named-objective text guard flags unchanged Gingerscope catalog data in a new root scanner copy. Keep scanner derivative in reachability/ alongside its scope record; compile it explicitly and require removing only additive API to reproduce exact v6_8 bytes. No inherited test or source/catalog content changed.

Final review: independent review found incomplete-own retry and suppressed-row rendering issues, both reproduced RED and fixed GREEN. Transaction cache invalidation moved before lifecycle early return. Added full unchanged outgoing-worker runtime fixture after review identified extracted-helper coverage gap: original v17 physically requests Seer3 (RED); v18 six scenarios GREEN. Current full gate25 top-level checks (including inherited37-command suite) PASS, all342 predecessor files unchanged. Scanner rows use existing distinct WHITELIST/UNAVAILABLE/UNKNOWN styles plus explicit outgoing classification/reason.
