# Supervised trading — one operator-selected item pilot (no final Accept)

**Goal:** move from 116 client diagnostics to a tangible, manually supervised, single-item offer. This is NOT the complete Gingerscope auto trading strategy.

## Current baseline

[PR195](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/195) was **MERGED** to main at `a599c31c53d25e6799b9d631f45f282b445dcda0`: a separate `pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua` from the original known-good source. Every physical `OfferItem:FireServer(rawId,"Weapons")` is default locked without a local `supervisedGate.checkOutbound`, blocked for outgoing Gingerscope in raw ID, display and identity fields, and rechecks item and original visible trade GUI after authorizing. Exact CI prior 98 actual Lune remote mocks and 6/6 GitHub Actions passed. The original (stale) `pdiddler_PART4_BALANCER_TEST_v1.lua` must NOT be run unchanged.

## New main-based PR196 — actual selected offer, not another read-only UI

Files:
- `pdiddler/supervised/supervised_one_item_policy.lua`: PURE one-shot check-and-arm module with NO game APIs, no server remotes and no price valuation.
- `pdiddler/supervised/SUPERVISED_ONE_ITEM_MANUAL_PILOT.lua`: physical original-MM2 iPad/Delta runner, only exact prior audited PR195 I/O module and one committed pure policy module loaded through immutable GitHub source GETs, no item/partner data upload.
- `pdiddler/ci/supervised_one_item_pilot_tests.luau`: pure adversarial operator, current trade & partner test cases.
- `pdiddler/ci/supervised_one_item_native_runner_mocks.luau`: executes the **ACTUAL iPad runner** against original TradeGUI/YourOffer/TheirOffer hierarchy and the actual protected TradeIO source with fake Roblox `OfferItem`, never a real server.
- `.github/workflows/gingerscope-supervised-one-item-pilot.yml`: checksum-pinned Lune + static original safe-fork Git blob + no final Accept/no auto request/no price/Discord.
- Existing registered `.github/workflows/gingerscope-lune-offline.yml` extended to run both pure and native mock tests so the independent CI exercises actual code.

## Operator safety state machine

1. Operator manually opens a real trade with ONE consenting, exact known Roblox username. The script does **NOT** click a player, send a request or auto-select a partner.
2. The operator explicitly configures `getgenv().PDIDDLER_SUPERVISED_ONE_ITEM_PILOT` with `armed=true`, `manualOfferOnly=true`, `targetName` (exact Roblox username), `weaponKey` (exact manually selected owned low-value raw MM2 weapon key). It is the operator's responsibility to inspect value/demand and **never press final Accept merely because one item appears**; the bot does not have verified fresh pricing.
3. Policy verifies exact players, local PlayerGui's currently OPEN trade, `TheirOffer.Username` exactly matching target's actual Roblox Name (not display-name fallback), both offer sides structurally present, own `YourOffer.Accepted.Visible == false`, partner's accepted flag false, and own offer has zero physical slots. All conditions rechecked at exact outgoing remote authorization callback. Any missing or ambiguous UI/identity state => BLOCK with no offer.
4. The arm is consumed **BEFORE** calling the guarded `OfferItem`, and the gate is immediately cleared afterward. At most one item is attempted. If the GUI shows it after a short delay, status `CLIENT_OFFER_VISIBLE_UNATTRIBUTED`; otherwise `OFFER_REMOTE_FIRED_GUI_UNCONFIRMED`. Both are only client observations with `tradeOutcome=UNKNOWN`.
5. No retry, no automatic final Accept, no decline, no hopping, no market lookup, no suggested gain, no webhook, no inventory value claim. The runner optionally uses a short on-screen status notification and also returns a redacted report (no target username, weapon name, account IDs or JobId in report/log).

## Important limitations

- The script does **NOT** verify server-owned inventory before selecting the item. Operator must manually choose one real, nonprotected, low-value item they possess. The server may reject a nonexistent item; a fired client remote does not prove item was added or transferred.
- A single physical remote attempt does not guarantee GUI replication in 350ms. A failed GUI readback is explicitly UNCONFIRMED and will NOT be retried automatically.
- The older price source is expired; this is a **device/physical item-placement pilot**, not an intelligent profit-making trade.
- An exact visible `TheirOffer.Username` and hidden `YourOffer.Accepted` UI are required; if original MM2 mobile layout differs, the pilot blocks and returns a reason. Do not add a fuzzy DisplayName fallback that could act in the wrong player's trade.
- No proof of server-attested trade completion or realized gain. All outcome/profit/Discord/learning authority false.

## Tests and review

Tests are committed FIRST at `2db81d6985f514b8c387df60cc67bbb07a83d207` (pure tests), then implementation `ee1bb98264963bbfaa9e760f21a613ba4ffe7d77` and mock runner. No CI RED is claimed without a real failed run. **Before delivering any real iPad loader**, require the pure controller, native checked-in runner mocks and six baseline CI all green on the exact PR head; preserve Git blob and specific Action links in the canonical handoff. If tests remain inconclusive, no manual live offer should be requested.

After tests, one narrow consenting-alt iPad test should be enough: manually open the trade yourself, run exact pinned loader for a known low-value non-Gingerscope item, report whether the item visibly appears. Do NOT repeat old Stage106/116 diagnostic experiments or manually Accept the test trade unless the user independently decides after verifying its contents.

## Next after successful real one-item pilot

Integrate fresh exact values, desirability and slot-aware balancing into a supervised controller, and only then aim for automatic multi-player requests/rotation. Manual final Accept remains user-controlled. Permanently forbid Gingerscope outbound; do not restore the obsolete mandatory +15 rule.
