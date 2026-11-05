# Issue24 scanner evidence correction — V15.5

Base: PR25 cf69d7e82f81f2867a39ede6e18d64b97a9d8fcb (368 files). Source: Issue24 newest native audit, comment6646587255. User requests analyze, plan and fix; execute this bounded P3 follow-up and stop.

Confirmed source causes: eligibility_v1 uses own cache/global send eligibility before zero-eligible opponent proof; loader writes outgoing feasibility through setRequestState and overwrites raw rarity heading; raw summary counts only rarity; scanner formats historical embedded prices rather than current P4 profile. The reported reward Claim/manual Accept is stronger evidence than closure, but authoritative reconciliation and post-trade delay remain separate P4 tasks.

Design: pure scanner view uses the same fresh canonical profile/strict policy passed by the loader BEFORE scanner initial render. Keep raw rarity/inventory records and scanning unchanged. Distinct outgoing display state and counters must not alter true request/processed states. Empty, fully verified blacklisted opponent is economically unprofitable without own proof; partial/unpriced/malformed/stale/active-scan records remain unknown. None of this authorizes sending while context, own proof, or price state is unsafe.

Approaches considered: changing scanner raw inventory values risks eligibility/identity drift; reusing request-state UI repeats the ownership bug. Chosen: current-price presentation only, separate outgoing channel, narrow coordinator ordering fix. No price refresh, arbitrary expiry extension, P4 negotiation or completion changes.

Tasks:
- [x] Reproduce old native-reported row/summary and price contradictions with actual scanner helpers/current strict policy; preserve RED.
- [x] Add pure view module + successor scanner (v6.10), with pre-initialization dependency injection, separate outgoing row API/counters and existing request-status priority.
- [x] Add successor economic coordinator v2: rigorous empty opponent proof independent of owned proof, distinguish own-proof-pending/paused, report unprocessed counts even during global holds; preserve final send fences and bounded verification.
- [x] Integrate successor V15.5 loader/bootstrap using new immutable pins, same P4/P1/P2/P5/profile; run inherited complete gate and new actual scanner/loader/outgoing-runtime tests.
- [x] Independent review; all368 prior files byte-identical; publish isolated unmerged draft PR on PR25, verify all pinned blobs and CI; provide one build entry and remaining iPad checks.

Constraints: +15 floor; opponent-added MAX(10,5%) /25%target/50%cap unchanged; own TTL10s, guarded fresh pre-click read, exact Player/UserId/fingerprints/job/price/GUI/controller/lifecycle fences unchanged; unknown30s allowance +45s exhaustion unchanged; auto final Accept/Discord OFF; fixed price expiry2026-11-05T21:55:32Z. Common-item stall and manual-completion detection explicitly deferred.

Verification focus: initial startup must never render old140/80 values; dropped unpriced rows cannot become zero; confirmedBLACKLIST remainsBLACKLIST while own proof pauses; true request/processed status cannot be overwritten by economics or periodic repaint; global holds never age into request/hop permission; current price expiry removes misleading current values.

Independent review findings: completed result/start redraws bypassed composer; expired stored economics retainedREACHABLE. Both reproduced with actualscannerhelpers and fixed RED→GREEN. Finalreview found no remaining major issue. Targeted verification14view+34economics+8actualGUI+20loader+32bootstrap+6fulloutgoing passes; full8-check successor gate including25preserved checks and37-command suite passes.

Pinned release gate PASS. Published22 immutable blobs independently fetched/matched via GitHub. Chain0230ed1481768e7b8ddfee87e9022f6d27462674 →22521aa80b8cb1a45114ab6a4791065bb7bd56c7 →cd9e4d71deea1ecf30cf0845d4cd558cd807b397. Native iPad execution NOT RUN.
