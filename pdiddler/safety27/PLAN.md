# Issue27 — immediate unsafe-quote safety

Base PR26 6652869abc6461d11d919f836f05e2fd1e57c568. Read Issues27/28; implement27 and independently verify/publish draft first;28 remains blocked until then. Source P4 blob20d0545e69fe0405f197132da091d8e5201dd6ee matches pin54c9ff4b999f67b2a257be10747c32916051bdd4.

Cause: opponent canonical-signature change unconditionally continues before0.65s stability wait and before +15/acceptance decisions. Replacement abort adds0.75s recovery delay then another stability wait. Current vulnerable quote can remain during both. Native recordings show transient405/115 and33/33; no completed loss established.

Plan:
- [x] Actual full-controller RED timing repro405/1295→405/115 and33/101→33/33, plus native acceptance/mutation races.
- [x] Versioned P4 successor evaluates real current physical quote before voluntary debounce and at every transaction validation boundary. Track complete raw identity/qty/layout signature for approval fencing, independently of economic watermark. Never treat unknown slots as0.
- [x] Invalidate approval/readiness/candidate immediately on raw change while preserving BOUND root/session ownership and acceptanceObserved. No unverified automatic Accept exists/enabled.
- [x] On confirmed unsafe single-copy/one-slot offer, local accepted exactlyfalse and partnernotaccepted: one emergency clear with max0.24s verification and no retries. Any uncertainty/change escalates to one identity-bound decline. Multi-slot/stacked exposure or accepted/unknown accepted state declines immediately before planner. Post-clear restoration uses existing lastverifiedledger and cannot grant new generosity.
- [x] Unknown opponent entries keep failclosed hold, preserving separate Common-item issue. Initial empty speculative quote retains12s rule. After a verified safe quote, removing everything must protect our quote before ordinary empty waiting.
- [x] Run inherited suites, exact predecessor hash checks and independent review. Publish isolated V15.6 draftPR stacked on26 withimmutablepins. Then, and onlythen, begin28 in separate branch/PR.

All existing+15/identity/quantity/slot/native readiness/concession protections remain. No P1/P2/P3/P5, scanner/profile/expiry/Common/finalAccept/Discord changes. Native client/serverlatency cannot be atomic; measure action-initiation latency, neverclaim native completedgain/loss from offline fixtures.

Review also reproduced and fixed unanchored speculative restoration, changed-opponent ceiling replay, and native acceptance history lost before malformed-layout/identity/expiry exits. A restoration reward requires an exact previously committed evaluation; unresolved partial quotes cannot become new economic baselines.
