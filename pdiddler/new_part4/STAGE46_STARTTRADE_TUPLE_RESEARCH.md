# Stage46 — Classify StartTrade table + string as CLIENT tuple hypothesis only

## Native input, already observed (do not rerun Stage45)
User-provided first successful revised [PR84 Stage45 Delta JSON](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/84#issuecomment-6715431343):
`stopReason=ONE_START_TRADE_TYPE_CENSUS_MATCHED`,
`argumentCount=2`, `argumentTypes=["TABLE","STRING"]`,
`eventBeforeVisibleGui=true`, `receiptCount=1`,
`clientWindowContextStable=true`, listener teardown 1/1.
No callback argument CONTENT, raw names, session IDs, or nested-table keys was captured. All server/session/settlement/Accept/profit authority false. Prior genuine Stage45 had GUI already visible when the callback arrived; both orders happen in native observations. There is NO video for this JSON.

## Independent source assessment
Official [Roblox RemoteEvent documentation](https://create.roblox.com/docs/scripting/events/remote) says server->client RemoteEvent callback arguments are forwarded, reliable/ordered on the same direction, but may be queued and table payloads are copied. The documentation makes **no claims about MM2's private StartTrade protocol**. A separate unverified public MM2 script [example](https://pastein.ru/t/eRT) uses a heuristic `StartTrade.OnClientEvent(function(arg1,arg2))` and considers a STRING possible partner name; the script is **third-party and unaudited**, uses unsafe game-mutating methods and must NEVER be executed or imported. This is a hypothesis-generating clue only, not an authenticated source of MM2 payload semantics.

**Single Stage46 hypothesis:** In a fresh empty trade, StartTrade's first argument might be the same finite four-key `{LastOffer,Locked,Player1,Player2}` trade-state layout earlier seen in real UpdateTrade; the second STRING might be exactly the GUI-bound partner's **Name** or **DisplayName**. String *types* are not unique IDs. Even matching these shapes doesn't prove same-session causality; a stale matching snapshot could be delivered.

## Verification technique, no secrets / no guessing
The pure `p4_stage46_starttrade_tuple_semantics.lua` accepts only exactly `{n=2,[1]=TABLE,[2]=STRING}`, strict key sets/finite numbers, table metatable rejection, exact Player object reference comparisons in both P1/P2 orientations, both offers empty, both Accepted flags false, and a <=256-byte string. It compares the string privately against current `LocalPlayer.Name`, `LocalPlayer.DisplayName`, GUI-bound `partner.Name`, and `partner.DisplayName`. It emits **only fixed enums and booleans**, never the original names, string or table contents. String classifications distinguish partner username, partner display, local username, local display, both-actor ambiguity and other/unclassified. When both a partner match AND a known table match hold, only `clientTupleHypothesisMatched=true` is set, never any authority flag.

The separate `STAGE46_READONLY_STARTTRADE_TUPLE_PROBE.lua` is a narrow fork of the previously CI-verified Stage45 passive loader. It retains the same strict owner, unique StartTrade remote, single callback, GUI-before/after ordering support, stable **both offers empty**, neither Accepted, exact partner/root/label object and text stability, and full listener teardown. Source pins are checked before execution. It does not fire any remote or click any GUI, insert/trade an item, run a scanner, report a profit or post to Discord.

## Adversarial failures that MUST be tested
- Known table + partner name in either actor orientation, display-name-only string, string/actor mismatch, unknown table/side keys, wrong Locked/LastOffer, nonempty offers, unexpected Accepted flags, wrong item/order/length.
- No arguments or callback, extra callback, stale/pre-arm callback, visible GUI with wrong partner, multiple GUI roots, root/partner change, forgotten/trailing listener, data leak, lost/altered current Roblox job, conflicting owner.
- Source reviewed from exact pinned GitHub commit. Both whole-loader fake-Roblox Lua and 300+ randomized real Lua payload tests must be launched through Python. **A green CI is NOT a native MM2 validation.** No Delta script should be given before exact-head CI and logs pass.

## How to interpret real native results (not yet observed)
- `tableLayout=EMPTY_TRADE_TABLE_CLIENT_LAYOUT_MATCH` and `stringClassification=PARTNER_USERNAME_EXACT`: corroborates tuple hypothesis **on that one client callback**, not transaction ID, unique server session, actual trade/settlement or permission to Accept.
- `OTHER_STRING_UNCLASSIFIED` is not evidence of a transaction nonce; raw string is deliberately excluded.
- A table mismatch disproves **this specific known layout assumption**, not all possible session tokens or MM2 transport structures. Do not dump raw data or immediately escalate to deep recursion.
- Keep all event-session, causality, raw item, server completion, trade, Accept, webhook and profit flags false. Market strategy + Gingerscope goal are entirely separate; no inherited old +15/90%/fixed sweeten logic.

**Only one optional manually opened read-only trade after exact-head CI:** fresh MM2 Delta Tablet, run pinned Stage46 before any trade invitation, wait `[STAGE46] READY`, trusted OTHER account sends invitation, Delta opens invitation only, keep both offers empty and neither final Accept. Copy `[GINGERSCOPE STAGE46 STARTTRADE TUPLE]` complete anonymized JSON, manually decline after; do not repeat upon failure without diagnosis. There is no item cost, Batwing action or completed trade in this test.
