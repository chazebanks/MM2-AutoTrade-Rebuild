# Project Gingerscope — five-scenario supervised Supreme-only iPad test preparation (Nov 17, 2026)

## Canonical current work

DRAFT, UNMERGED PR **#315** https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/315, new research branch `research/system2-supreme-five-scenario-manual-test-nov17`, stacked on #314 (one-tap Supreme Preview), #313 (original protected Stage119 launcher), #312 (original protected C3/P4 scanner bridge), #311 (single Supreme-only valuation policy). Read the actual PR HEAD, file changes and exact HEAD CI runs before claiming success. This is one new testing task. The original frozen Stage119 runner, previous Supreme-only single-Preview source and legacy dual/MM2Values research remain unmodified for historical audit. New test path **does not import MM2Values or hybrid price source**.

## Concrete bug fixed

The prior single-preview launcher required `plan.noWeaponAddOrRemoveTests=true` and told the user **never add/remove weapons**. Yet the proposed five-scenario live test needed manually adding/removing items on MAIN and consenting ALT accounts, including a two-sided offer and a changed stack. This was a real contradictory policy. Do not reactivate the old restrictive launcher for these tests.

**NEW launcher**: `pdiddler/supervised/STAGE119_C9_SUPREME_ONLY_FIVE_SCENARIO_START.lua` uses **only** `getgenv().GINGERSCOPE_C9_SUPREME_FIVE_TEST_PLAN` and refuses to start unless all are explicitly true:
- `explicitOperatorWantsC9Research`, `understandsArmSendsP3TradeRequest`, `consentVerifiedForNamedAlt`, `supremeOnlyResearchRequested`, `understandsCurrentSourceMayExpire`;
- `operatorApprovedManualItemChanges`, `manualWeaponChangesSupervisedOnly`, `noAutomaticWeaponOffers`, `neverFinalAcceptDuringTest`;
- `finalAcceptMustRemainManual`, `automaticP3ArmForbidden`, `operatorConfirmedReadOnlyInventoryRpc`, `explicitOwnInventoryReadRpcConsent`;
- exact in-server `targetName` identifying the consenting ALT (NO account hardcoded).
It explicitly refuses `noWeaponAddOrRemoveTests=true`, unlike the superseded single-preview launcher. The operator manually taps original P3 **ARM**, which sends ONE real P3 trade REQUEST. ALT may accept this *request*, but **neither party should tap FINAL ACCEPT or claim an item**; all weapon changes are manual in their own Roblox trade UI. The test harness never calls an active game remote to add/remove items, send a second request, auto Accept/Decline, teleport, report profit, or train a strategy.

**Early source-age gate:** the launcher verifies actual Roblox `DateTime.now().UnixTimestamp` is within the **original captured UTC** `2026-11-17T14:06:51Z` through `2026-11-17T20:06:51Z`. A missing/future/expired clock blocks BEFORE fetching original Stage119 or enabling a trade request, avoiding wasted ALT sessions. The source remains the genuine Firecrawl-mediated/public Supreme Values capture with 189 regular weapons (15 Ancient/128 Godly/46 Chroma), raw JSON SHA256 `48107d3039caf620bcad2c08831c9ca7fe206780dfb0e2d96d8161e3c9210f4a`, Git blob `1497e9644ae271ff7a144aa5de43c30609f5c722`, publisher edition last updated Nov 15 11:59:41 EST. It is unsigned and NOT a live feed; a later run past cutoff requires a GENUINE NEW four-page source capture and freshly pinned code, **never timestamp restamping**.

## Five distinct stages in ONE manually supervised protected trade

Native pure stateful recorder: `pdiddler/system2/native_supreme_only_five_scenario_recorder.lua` (immutable source pin `851205f28790b17f410292637ad9449eff0303bc`), built into separate original protected host `pdiddler/supervised/STAGE119_C9_SUPREME_ONLY_FIVE_SCENARIO_NATIVE.lua` pinned by standalone launcher at host commit `5a0e2a4f096970bcb3ff9b1f029efe3f92813688`.

1. **STARTUP:** the original human-armed bound P3/P4 client GUI and private lease are genuine and stable. First tap on empty Preview may mark Stage 1 and Stage 2 simultaneously, but the report retains **two distinct** PASS codes.
2. **EMPTY:** *both offers empty*, tap same in-game TEST button; successful safety behavior is BLOCKED valuation and `S2_PASS` (after startup `S1_PASS`).
3. **ONE SIDED:** human manually adds ONE cheap eligible weapon to only MAIN **or** ALT offer. Tap Preview; must identify exactly one nonempty side, block incomplete valuation, record `S3_PASS`.
4. **TWO SIDED:** human manually adds a second inexpensive eligible weapon on the other account; tap Preview. Only passes `S4_PASS` after exact raw game weapon IDs, nonempty physical offers on both sides, source-verified same Supreme edition and positive/allowed listed economics. If raw `ItemId` attribute isn't present in the real MM2 GUI, it **BLOCKS** instead of using display names, hidden Batwing prices, or guessed identity.
5. **MATERIAL CHANGE:** human changes an offered **weapon raw key or numeric stack quantity**, keeps both sides offered, taps Preview. Merely pressing again, moving the same item to a different GUI slot, or switching the visible notation `''` ↔ `x1` does **NOT** count. Same original partner/session/lease and a NEW verified Supreme-only quote are required for `S5_PASS`. A stale source, offer mutation during measurement, Acceptance indicator, session loss or unknown raw identity leaves this stage BLOCKED.

Every stage checks the original P4 client double-read before/after, and the protected C3 Supreme-only bridge adds two original own inventory reads and additional P4 frames for two-sided scenarios. Stage results are **client-only**, not proof of a real accepted trade or server settlement.

The in-game panel reuses the existing safe ARM position for TEST n/5 only AFTER protected P3/P4 is bound. The STOP/COPY button remains available; tapping STOP copies the five sanitized milestone codes, completed count and blocked-attempt count, but NO username, JobId, trade lease, raw weapon IDs, quantities or private inventory. No second Delta Execute is intended while the MM2 trade is open.

## Adversarial CI evidence and remaining boundary

- Python: `pdiddler/ci/test_supreme_five_scenario_manual_policy.py` checks required explicit consent, snapshot raw SHA/source count, no legacy no-change gate, no second price list, STOP receipt sanitization, all five independent stage conditions, and **source expiry before P3 request**.
- Pure Lune: `pdiddler/ci/system2_supreme_only_five_scenario_recorder_mocks.luau` validates five distinct stages, 63+ assertions, missing raw ID, wrong publisher, forged Accept authority, expired source, offer changes mid-capture, re-clicked unchanged offer, changed exact stack, acceptance, partner swap, reported privacy, correct blocked-attempt counts. Extra tests reject cosmetic slot-position and `x1` label changes.
- True native original host mock: `pdiddler/ci/stage119_c9_supreme_only_five_scenario_original_host_mocks.luau` runs a single original P3/ALT request session with mocked Roblox GUI, manually inserts two client offer GUI items, clears raw ID to ensure Stage4 BLOCKED, restores it to pass Stage4, re-clicks unchanged offer to fail Stage5, changes a numeric quantity to pass Stage5, then presses original STOP/COPY and verifies all five sanitized passes and **zero actual OfferItem/Accept/Decline**. These synthetic mocked item additions are NOT live game offers.
- New startup Lune `pdiddler/ci/stage119_c9_supreme_only_five_scenario_loader_mocks.luau` rejects unapproved manual changes, auto item offers/final Accept, source expired/future/missing clock **before any network or manually ARM-ed P3 action**.
- Dedicated CI `.github/workflows/gingerscope-c9-supreme-only-five-scenario.yml` and full inherited seven-workflow suite must be checked at latest exact HEAD before device instructions. Workflow runtime uses pinned Lune 0.11.1, real Python 3.12 and immutable original dependency blobs.
- **NOT YET RUN ON USER'S ACTUAL iPad / Delta.** A hardware receipt is needed to confirm the real MM2 GUI exposes the raw `ItemId` attributes. If none, the five-stage test will stop at Stage4; do not claim success from mock results. No final Accept, completed MM2 trade, real inventory settlement, autonomous bot trading or learning is authorized.

## Next one action

Once exact current HEAD CI green and the public Supreme source still within its verified six-hour cutoff, provide the user ONE copy-paste operator-plan startup for their explicitly identified consenting ALT, run once on the MAIN iPad, press in-game manual ARM, then follow stages and use STOP/COPY. If source expired, refresh actual four official pages and repin instead of reusing old fixture. Do not ask the user to repeat unrelated original Stage119 gift/lease hypotheses.
