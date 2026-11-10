## Actual first Stage97 iPad report: blocked BEFORE trade observation (2026-11-09 ET)

User's original MM2/Delta report `[GINGERSCOPE STAGE97 PARTNER EVENT]`: `status=INCONCLUSIVE`, `reason=EXACT_TRADE_WINDOW_NOT_OPEN`, `elapsedSeconds=0`, `targetClientBound=true`, `exactPartnerGuiObserved=false`, `stage9ObserverBound=false`, `stage9Frames=0`, `eventReceiptCount=0`, `actualRequestTaps=actualOffers=actualAccepts=actualDeclines=actualTeleports=0`. No callback identity, market or trade conclusion can be drawn; the initial exactRoot() check had returned before the original reader/listener could attach. Do not infer the user forgot to open the trade; Delta/executor visibility timing or a closed window are alternatives.

**Isolated correction in SAME Stage97 PR167, not a new identity stage:** after exact target client binding, print `[STAGE97] WAIT_FOR_MANUAL_TRADE_WINDOW`, poll for at most 30s for exactly one visible original MM2 trade GUI with exact consenting ALT username. Only `EXACT_TRADE_WINDOW_NOT_OPEN` may be retried by a passive timer. Wrong partner, ambiguous GUI, changed target, job or ownership still fail immediately without attaching listener. Once manually opened, retain original two clean baseline checks, original source imports, exactly one remote callback receipt, no item placement or final Accept. On deadline, `MANUAL_TRADE_WINDOW_NOT_OBSERVED_WITHIN_30S`, no listener and no request. Update manual instructions: **RUN Stage97 FIRST, THEN manually open a trade during 30-second wait**; when `[STAGE97] READY` appears, ALT manually adds ONE expendable eligible item. No final Accept. This is only a UI startup timing fix; Stage43/44/50,79–83,91–93 completed proof preserved.

# Stage97 — ONE manual read-only partner-side UpdateTrade witness (draft)

## Why this is distinct

Stage50 native MAIN Batwing own-offer raw-key / local owned / Sync / UpdateTrade match has already passed; Stage83 native 69/69 eligible weapon key types and 76/76 copies match historical public source; Stage93 native request→correct partner trade GUI→original Stage9 Part4 observer saw alt add a weapon; Stage95 original source compatibility and Stage96 partner-side actor orientation/GUI consistency are offline green. **Do not rerun those prior probes.**

Stage97 is a **new narrow observation**: does the MAIN iPad receive exactly ONE partner-side `ReplicatedStorage.Trade.UpdateTrade.OnClientEvent` with the two exact current Player objects and a raw `[weaponKey, quantity, "Weapons"]` tuple whose displayed name, Chroma and stack quantity are consistent with ONE ALT item manually added to the current exact-partner GUI?

## Architecture

New standalone `pdiddler/new_part4/STAGE97_READONLY_PARTNER_EVENT_WITNESS.lua`:
- The operator runs Stage97 while consenting test-alt is in the same server, then **manually opens MM2 trade during its 30-second wait** (an already-open, visible exact trade is also accepted). Stage97 **never sends a request or clicks any GUI**, unlike Stages91–93. Single explicit `PDIDDLER_STAGE97_READONLY_ARMED=true` and exact username are required.
- Requires original MM2 PlaceId 142823291, only one visible TradeGUI root, exactly matching `TheirOffer.Username`, stable current Player instance, current JobId/PlayerGui and no other script transaction owner. Both offers must be empty, Stage9 visible accept indicators must be false, and two baseline captures stable.
- Downloads unchanged **commit-pinned** original Stage9 native+contract (one original physical GUI slot capture), unchanged original Stage83 historical PUBLIC registry, Stage95 no-ID-boundary and Stage96 pure partner-event/GUI comparator. No priced scanner. Reads `Sync.Weapons` only for client catalogue metadata. Identifies exactly one `ReplicatedStorage.Trade.UpdateTrade` RemoteEvent, connects a read-only `OnClientEvent` listener, and disconnects on any exit.
- Prints `[STAGE97] READY`. Only **after** this, the consenting ALT operator manually adds one expendable Ancient/Godly/Chroma weapon to THEIR offer (MAIN offer stays empty; both accounts do NOT press final Accept). Stage97 captures at most one client event packet locally, one before/after GUI transition, two stable offer samples ≥0.15s apart, and invokes original Stage96 pure comparator. It never returns raw key, item name, actor identities, session/JobId or network payload to stdout/clipboard.
- On malformed/duplicate/delayed/wrong-partner/ambiguous/missing event, changed GUI/session, unmapped Chroma/quantity, or any Accept state, it returns INCONCLUSIVE and never retries input. Even positive match returns `CLIENT_PARTNER_EVENT_GUI_NAME_QTY_CONSISTENT_UNATTRIBUTED` or `CLIENT_PARTNER_EVENT_GUI_RAW_TEXT_CONSISTENT_UNATTRIBUTED`; no server transaction nonce or callback causality can be proven.

**Hard invariant:** all `actualRequestTaps/Offers/Accepts/Declines/Teleports=0`, `authorizesTrade/Accept=false`, `eventSessionAssociationProven=false`, `callbackCausalityProven=false`, `serverAttestation/completion=false`, `currentPricesVerified=false`, `mayRecordCompletedTrade/Profit/Discord/Learning=false`. The older `+15` minimum profit rule remains superseded.

## Operator procedure — ONLY after exact-SHA CI success

1. MAIN iPad/Delta and consenting ALT `venossgaming90190` join a fresh original MM2 server (no other pdiddler scripts). Tablet mode if prompted.
2. Execute the one-shot Stage97 loader on MAIN first, with both players present. On `[STAGE97] WAIT_FOR_MANUAL_TRADE_WINDOW`, **manually** send/accept a trade invitation between MAIN and ALT within 30 seconds. Keep BOTH offers empty and never press final Accept. An already visible exact trade also works; no automated request tap takes place.
3. Wait for `[STAGE97] READY` before the ALT manually adds exactly ONE expendable eligible Ancient/Godly/Chroma weapon, leaving MAIN offer empty. If it reports INCONCLUSIVE (e.g. wrong partner or manual-window timeout), stop and share that report. Do not press final Accept on either side. Keep the GUI open until the test ends.
4. Send one `[GINGERSCOPE STAGE97 PARTNER EVENT]` JSON output. If it says no callback, do NOT infer a missing item; the single client event may not be delivered or wrapper may fail to attach. No re-test in same game JobId.

The two previous native reports do not already answer this **partner callback** question, so this is an acceptable new manual diagnostic, not an inventory rescan or Batwing proof repeat.

## Test gate

- Exact original Stage9 native+contract and Stage83 original Git blobs and Stage95/96 sources verified at existing reviewed SHA.
- The **actual Stage97 Lua wrapper** (not merely pure Stage96) executed by Python/Lua5.4 with mocked Roblox trade window, player refs, UpdateTrade signal, one manual partner item add, duplicate, absent, malformed, wrong actor/partner, incorrect Chroma/name/quantity, changing job and listener cleanup. All five existing baseline Luau/Lune/Selene+StyLua/replay/Hypothesis workflows must pass at the final source SHA.
- PR remains DRAFT and unmerged; no production P3/P4/Accept/hopper/Discord changes.

## Current canonical references

Stage96 draft [PR166](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/166), Stage95 draft [PR165](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/165), Stage93 native evidence and newer price Stage94 research preserved in `pdiddler/GINGERSCOPE_LATEST_CHECKPOINT.md`. Never infer price authorization from a callback match.
