# Stage119 V2 — strict protected P3/P4 parity corrective work (DO NOT RUN ANY DEVICE LOADER)

## Identified failure of development process

The original MAIN iPad PR221 Stage101 test truly operated under the ORIGINAL protected P3 supervisor to P4 live trade:
- Purple ARM P3 user tap, then only P3's already-reviewed ALT-only outgoing trade request
- Exact consenting ALT accepts request, exact partner Player instance
- Original P3 paused on active trade and P4 read-only lease from supervisor.currentBoundReadOnly()
- Original Stage9 physical GUI independently cross-checked against protected P4 TradeIO
- Purple step-by-step panel plus STOP/COPY always available and disjoint from MM2 Trade GUI
- Failclosed on owner/epoch/lease changes and prior old missing interface, without automated final Accept

PR225 Stage119 departed from that architecture despite 6/6 green offline CI. It replaced P3 auto-request and P4 bound lease with a manually opened trade and root/header client observations. Its narrower Lune mock could not catch those omitted protections; startup only denied Stage119's own owner, and it hid the step overlay on errors instead of exposing STOP/COPY. The correct approach preserves the PR221 P3/P4 integration and changes only the novel LastOffer observer.

**Withdrawal recorded** in [PR225 review comment](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/225#issuecomment-6789682775) and canonical/latest/strategy/Stage119 handoffs. Old immutable SHA-pinned PR225 Delta URL cannot be revoked by changing main. DO NOT RUN. No real Stage119 iPad result exists.

## One issue to fix first: restore P3/P4 parity

1. Use exact original successful PR221 P3/TradeIO/coordinator/boot/watchdog/scanner, not substitute mocks or manual trade.
2. Purple panel displays ARM P3 and STOP/COPY on MAIN BEFORE any trade request. Single ARM P3 user action passes supervisor.arm with explicitUserAuthorization=true, allowRealP3RequestRotation=true, finalAcceptMustRemainManual=true.
3. ALT manually ACCEPTS incoming original P3 request. No request, offer or Accept before ARM; never request a stranger.
4. Each callback and Stage9 capture verifies current protected P3/P4 lease via supervisor.currentBoundReadOnly(), including P3_BOUND_CANDIDATE_READ_ONLY, part3Paused=true, part4TradeVisible=true, partnerExactClientBound=true, exact root/Player/JobId/epoch. Reuse original PR219 physical cross-check against protected P4 TradeIO.
5. After protected session with BOTH offers empty and unique listener attached show ALT ADD ONE. Once stable show ALT REMOVE ONE. MAIN offers nothing. Exactly two bounded callbacks, no token/value logging and all server revision/Accept/profit/Discord authority false.
6. STOP/COPY visible at every on-screen step. On inconclusive keep safe on-screen status/stop until dismissed; if no safe geometry hide and copy sanitized receipt but do not prompt for actions.
7. Reuse original Stage100 safe iPad geometry and recheck continuously while user must interact, including AFTER local-positive result before manual Decline/STOP. Never cover trade controls.
8. Do not expose production test-only dependency injection to override frozen sources; tests need a segregated harness.
9. Lune tests MUST exercise exact pinned real P3 supervisor/coordinator/TradeIO, negative missing-bound-lease, changed epoch, wrong ALT, ARM never tapped, duplicate/delayed callbacks, stale GUI, viewport movement, unsafe prompt placement and hidden STOP. Verify frozen original sources by Git blob as PR221. Run Python and inherited CI at exact HEAD. Green from a mock skipping P3 is not enough.

## Current checkpoint

New pdiddler/ci/test_stage119_p3_parity_release_gate.py is intentionally RED: it rejects PR225 and fails until NEW pdiddler/supervised/STAGE119_P3_BOUND_READONLY_NATIVE.lua, its immutable loader, and pdiddler/ci/stage119_p3_bound_original_mocks.luau exist and pass. A dedicated workflow runs the gate; no device loader approved while this is RED.

No new hardware test authorization yet. Original Stage101 iPad client-identity proof remains CLOSED. Preserve user objective of attractive/liquid market-aware inventory compounding, upgrades/downgrades and protected Gingerscope, but solve missing P3/P4 parity first.
