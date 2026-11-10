# Stage96 — opponent-side UpdateTrade client correlation with actual Stage9 physical GUI

## Why this is new, without repeating completed investigations

The user's original iPad tests already proved **one own-side Batwing** raw key/callback/pre-offer owned correspondence in Stage43/44/50; Stage83 aggregate **69/69 eligible types, 76/76 copies** match historical current-client metadata; Stage93 original P4 observer saw the alt manually add an item. Stage95 isolated source-level **physical GUI ID may be absent**; it does not invent a key from displayed names. Do not rerun those prior questions.

Stage96 asks **one different question**: can ONE partner-side `UpdateTrade` tuple be found consistent with ONE exact partner current GUI item addition, accounting for swapped Player1/Player2, bounded capture timing, stacked quantity and current client Chroma metadata? This is an **observational consistency** question, not proof of client callback causality.

## Architecture

Draft PR166 is stacked on draft PR165 (Stage95), not merged into main. New pure `stage96_partner_event_gui_correlation.lua`:
- Reuses original pinned `p4_stage42_player_orientation.lua` and compares exact Lua Player reference objects in the callback, rather than assuming LocalPlayer=Player1. Does **not** feed partner offer to `p4_stage43_dynamic_own_offer.lua` or `p4_stage44_client_offer_state.lua` as if it were an own-side Batwing test; they intentionally reject partner-side nonempty offers.
- Checks the actual original `p4_observer_contract.parseQuantity` (blank 1, x2 2), original Stage83 189 historical PUBLIC key→name/type/rarity/Chroma reference, and Stage95 physical-slot status. A callback `[raw key, bounded quantity, "Weapons"]` is checked against current local Sync metadata and the actual GUI label/Chroma/quantity. If physical GUI ID is missing, output labels this as **NAME+QUANTITY CONSISTENT, UNBOUND**. Even if the GUI raw text also equals the client callback key, this is a **CLIENT RAW TEXT CONSISTENCY**, never server item-ID proof.
- Requires one exact callback receipt count, valid `LastOffer` NUMBER (not authenticated nonce), `Locked=false`, two distinct complementary Player references, both Accepted=false, own event offer empty and partner exactly one weapons row, GUI before empty and after one partner slot, two physical captures stable at least 0.15s apart, same root/JobId/client-side session/Player instance context from caller, and 3-second bounded receipt and sample timings.
- Fails closed for wrong, repeated, stale, reordered, changed root/partner/job/GUI, accepted, duplicated or 2+ rows, stacked qty disagreement, wrong Chroma/name/cross-page reference or missing provenance.
- **No account data, key, weapon name, UserId, raw callback payload or job ID is serialized.** All return flags preserve `eventSessionAssociationProven=false`, `callbackCausalityProven=false`, `rawItemIdConfirmed=false`, no server attestation/completion, no price/trading/Accept/Discord/learning authority.

## Honest limitations

This module is currently **pure/offline**. The original Stage9 GUI observer would need a small temporary read-only wrapper to deliver privately held before/event/after snapshots; no production scanner, P4 executor, Discord learner or final Accept integration is made here. Inputs from Roblox client cannot be independently server-attested. **Even a callback that arrives during the same visible GUI revision could have been delayed from a previous trade with indistinguishable event metadata.** The module therefore reports `CLIENT_PARTNER_EVENT_GUI_NAME_QTY_CONSISTENT_UNATTRIBUTED` or `CLIENT_PARTNER_EVENT_GUI_RAW_TEXT_CONSISTENT_UNATTRIBUTED` — never `ownerSideSlotBound` or `eventSessionAssociationProven`.

The first native partner-event test, if eventually justified, must be isolated and read-only with consenting alt, one request/no retries, alt manual one-item offer add, no item transfer or final Accept, no raw keys in printed logs. It tests **callback presence and actor-relative partner tuple**, which Stage93 did NOT test; it is not another generic offer-GUI detection test.

## Tests

A GitHub Actions workflow pins actual original Stage9,42,43,44,83 and Stage95 modules by checked Git blob SHA. Python unittest launches the real Lua5.4 test suite, including valid LocalPlayer first/second, former own-only module rejection, raw `Scythe`↔Batwing display alias, Chroma ×2, empty→single transitions, physical GUI ID absent/present, delayed/reordered/multiple callbacks, root/partner/accept/own mutation and 500 deterministic corruptions. Five baseline Luau/Lune/Selene+StyLua/replay/Hypothesis workflows must pass at the exact reviewed code SHA before any native testing.

No mandatory old +15 rule, no pricing from archived Stage94 source and no verified trade outcome is implied. Target remains acquiring Gingerscope through desirability/liquidity-aware strategies after separate evidence gates.
