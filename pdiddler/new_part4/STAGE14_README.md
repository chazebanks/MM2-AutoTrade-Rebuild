# Stage 14 — stable identity-matched preflight before native withdrawal

**DRAFT: no production activation, auto-accept, new offer insertion, pricing decisions,
or live clicks.** This branch stacks on Stage 13 (native blank-quantity correction),
Stage 12 probe, and the Stage 11 defensive coordinator.

## Why

Stage 12 live Delta evidence proved `Iceblaster[] -> Iceblaster[x2] -> Iceblaster[]`
in a single manual trade. A quantity parser can now interpret an existing
Amount TextLabel with `Text==""` as one copy, but a GUI may still be
partially rendered between updates. A single read is not enough to authorize
a native slot-removal attempt.

Stage 10 previously re-checked only **our** offer signature before sending a
removal click. If the opponent changes the quote between coordinator read and
native click, that read could be inconsistent with the preflight evidence.

## Changes

- New pure `p4_stability_gate.lua`: requires at least **3 distinct timed reads**,
  spanning **>=0.20 seconds** by default, of the **same session**, **both** raw
  offer signatures, and **the same resolved local item IDs/slots/quantities**.
  Samples with a gap over 0.30 seconds reset the proof.
- Invalid context, stale market, unknown/true acceptance, missing local item
  identities, duplicate physical slots, changed signatures, regressed clock, and
  changes occurring at the *same timestamp* reset/deny stability. The guard
  refuses configurations below 0.16 seconds or fewer than 3 samples.
- Stage 11 coordinator now **requires** this guard dependency. It does not
  dispatch a newly requested `REMOVE_ONE` until the guard passes. Stage 8's
  existing `AWAIT_REMOVAL` safety state holds the pending withdrawal request
  between samples; proof resets after a verified removal and before any next
  click. No trade action is authorized by this gate itself.
- Stage 10 intent is now bound to **both** `ourSig` and `theirSig`.
  `p4_native_removal.lua` makes one fresh bound observation immediately before
  clicking and refuses any mismatch. The ledger checks the signature on dispatch.
- Regression tests: pure timing/identity tests, native click-boundary opponent
  quote swap, tampered intent, and integrated timing/revalidation tests.
  Existing Stage 11 scenarios use an explicit test-only pass-through gate to
  preserve coverage of the older mechanics, while new Stage 14 tests use the
  **real** gate. No production configuration supplies the test double.

## Limitations

- Multiple identical snapshots are not independent server confirmations and
  cannot eliminate a race between the last GUI read and input injection.
- An opponent editing continuously can starve the stability gate; Stage 8 then
  escalates via its bounded withdrawal timeout. A `DECLINE` from these modules
  remains **intent only**; there is no native decline action implemented here.
- The Stage 9 scanner can be stale; successful name reconciliation proves
  consistency with that cache, not current server inventory authority.
- The prior Stage 12 probe is unchanged. No automatic withdrawal has been
  demonstrated on a real iPad/Delta MM2 client.
- `quoteSafe=false` still prevents using the observer for authorized pricing,
  item insertion or final acceptance; no strategy planner is integrated.

## Run all offline Lua tests

From repo root, with Lua 5.4 installed:

```sh
set -eu
for name in test_p4_safety_core test_p4_observer_contract test_p4_native_mock \
            test_p4_removal_executor test_p4_native_removal \
            test_p4_stage8_stage9_stage10_integration test_p4_coordinator \
            test_p4_stability_gate; do
  lua pdiddler/new_part4/tests/${name}.lua pdiddler/new_part4
done
lua pdiddler/new_part4/stage12/tests/test_stage12_probe.lua pdiddler/new_part4/stage12
```

No branch deployment or live user-executable loader is included. The next
gate is a controlled on-device **read-only** verification of timing and root
stability before any real actuator testing.
