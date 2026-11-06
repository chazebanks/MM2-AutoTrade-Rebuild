# Stage 27 — Controlled manual Delta ADD and REMOVE test

**Status: native testing candidate, not a live autonomous trader.** No final Accept, no P3 outgoing rotation, no automatic trading, no server hopping, and no completed-trade webhook.

## Purpose

Verify one actual MM2 weapon ADD using the existing Stage22 one-shot ledger, then one physical REMOVE using the existing Stage10 native removal ledger. Both actions are manually initiated; successful command dispatch alone is never considered proof. The old +15 balancer remains excluded.

## Files

- p4_stage27_lab_core.lua: pure operator intent and state machine, based on the actual Stage22 ADD and Stage10 REMOVE modules; cannot automatically Accept, retry uncertain commands, or modify strategy.
- p4_stage27_native_transport.lua: explicit one-shot known MM2 OfferItem remote and one physical removal-slot button click via VirtualInputManager. No redundant firesignal and no automatic fallback or retry. A click blocked by the test UI is rejected.
- STAGE27_CONTROLLED_DELTA_LAB.lua: single Delta test launcher using the existing Stage25 scanner-only boot, Stage26 dated market, and Stage9 observer. Displays a movable BIND/NEXT/ADD ONCE/REMOVE/STOP panel.

## Native test sequence

1. Rejoin MM2, select Tablet, and execute the Stage27 launcher BEFORE opening a trade.
2. Let the existing scanner find players. Open a manual trade with a trusted test partner. Neither participant presses Accept. The partner must offer at least one eligible Godly/Ancient/Chroma knife or gun first.
3. Tap BIND. This re-reads own inventory and checks the exact trade partner, cached opponent scanner completion evidence (within 30 seconds), quote freshness, offer identities, and both native ADD and REMOVE APIs. A failed BIND cannot touch items.
4. Tap NEXT to select one of your eligible weapons valued 200 Supreme or less. The panel never chooses an item above the cap.
5. Tap ADD ONCE. The Stage22 ledger attempts a single physical add and requires a later GUI read with exactly one copy of that item. No resend.
6. After ADD VERIFIED, tap REMOVE. Stage10 checks the exact offered item slot and quantities before one simulated physical mouse click. The independent later GUI read must show an empty local offered side.
7. Copy or send the anonymized final JSON. STOP / REPORT on failure; if an item remains offered, remove it manually and decline the trade. Never press Accept. Rejoin after testing to clear scanner listeners.

## Safety and source limitations

- The Stage26 Supreme source is from a browser-backed retrieval on November 5 Eastern, with official publication November 4 and fixed expiry November 6, 2026, at 7:47 PM Eastern. The lab refuses a NEW ADD after market expiry; a protective REMOVE can still be attempted.
- Scanner proof is local client evidence, not server authenticated completion. The output never claims successful trade completion or profit.
- A Delta executor may lack VirtualInputManager mouse simulation. If input is unavailable, the lab must refuse the add at BIND. If an actual click becomes uncertain afterward, no automatic retry is allowed.
- This manual test is not an automatic strategy approval. Stage23 still requires independent policy authority for trading.
- No existing Part3, old balancer, bot detection or Part5 files are modified.

## Tests

Two new Lua tests run actual Stage22 and Stage10 modules with simulated native send/click interfaces: test_stage27_lab_transaction.lua and test_stage27_native_transport.lua. Python test_stage27_native_lab.py checks the real source and runs the Lua tests through Lua5.4. Full Python/Lua regression is required prior to native testing. Tests do not substitute for Delta observations.

This stage must remain a draft until native evidence is reviewed.
