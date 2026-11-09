# Stage60 — no-trade census of MM2 Trade remote surface (research only)

**Question (one scope):** Is there a promising named RemoteFunction or other directly replicated trade endpoint that earlier Stage30/33 client-RemoteEvent censuses omitted, which might justify a *future* investigation of transaction-specific result evidence?

This is NOT a test of actual settlements and does not solve server authentication. The only live request, if the reviewed CI is green, is one **MAIN iPad / Delta no-trade read** of `ReplicatedStorage.Trade` direct child names and classes. The program NEVER invokes or subscribes to any remote, clicks/opens a trade, reads a player's inventory, exports user IDs/JobIds/item IDs, sends Discord data, or changes a gameplay state.

## Exact earlier evidence, not assumptions

- Native Stage30 PR69: 16 **RemoteEvent** names under `ReplicatedStorage.Trade`: AcceptRequest, AcceptTrade, CancelAccept, CancelRequest, CompleteTrade, DeclineRequest, DeclineTrade, EndTrade, GetRequest, OfferItem, RemoveOffer, RequestSent, SetRequestsEnabled, StartTrade, UpdateOffers, UpdateTrade. One inbound DeclineTrade was observed on a manual local decline, **not** evidence that the event includes initiator identity. Stage31 observed the same name on partner-initiated decline.
- Native Stage33 PR72: inbound StartTrade (before bound GUI), UpdateTrade, and two AcceptTrade receipts on a manually finished exchange; **no inbound CompleteTrade/EndTrade/DeclineTrade** in its finite census; post-close Claim appeared per operator. Their labels alone do not prove settlement.
- Native Stage46 PR85: StartTrade callback tuple `TABLE, STRING`, with a client trade-table-shaped first argument and exact partner username second argument. No unique server transaction ID in the observed interpretation. `LastOffer` was not proven a nonce or result.
- Native Stage50 PR89: client raw Sync weapon key appeared in the owner's inventory/pre-offer and own UpdateTrade during a Batwing add/remove, but no unique weapon instance/settlement/profit proof.
- Latest Stage59 PR104: independently recovered ALT SENDER -1 and MAIN RECEIVER +1 eligible with distinct receipt nonces, equal local recorded second, two post-close reads, and user explicitly reports one manually completed ALT→MAIN trade. This is **operator-corroborated reciprocal CLIENT inventory evidence**, *not* a server authenticated transaction. No result-named completion receipt. Do not repeat a transfer for this Stage60 question.

## Source interpretation

Roblox's [official RemoteEvent docs](https://create.roblox.com/docs/scripting/events/remote) specify transport/delivery properties: reliable RemoteEvents are ordered per client connection while connected, but queues can deliver later, handlers can yield, and RemoteFunctions do not share ordering guarantees with RemoteEvents. The documentation does **not** define any MM2-private settlement semantics, transaction key or source of truth. A remote named `CompleteTrade` is NOT evidence that its `OnClientEvent` fires on success. An MM2-sounding third-party script or a generic developer's trading implementation does not authenticate MM2's private backend.

## Stage60 implementation and proof limits

The read-only Lua source enumerates at most 64 **direct children** of the existing `ReplicatedStorage.Trade` folder. It reports an allowlisted fixed class count and sanitized `RemoteEvent` / `RemoteFunction` names with strict ASCII regex and maximum name length; rejects unsafe names, duplicate name+class, too many children, wrong game, absent folder or missing encoder. It optionally highlights names containing words such as result/receipt/history/complete, but **never infers semantics**. Unknown endpoints elsewhere, remotes dynamically created later, and true server code are all outside the census. A negative result means "no obvious named function in this one snapshot", NOT "no MM2 backend transaction record exists".

A local in-game purple **READ-ONLY / NO TRADE NEEDED** panel has a manually pressed COPY REPORT button, while Delta console always prints the sanitized report. No automatic clipboard writes: earlier Stage59 device-to-device clipboard confusion was observed. GUI failure does not prevent console fallback. The full script is intentionally standalone, does not load Stage59/Stage32 or old MM2 trading controllers, and does not start any observer/session.

**Every outcome retains** `serverCompletionProven=false`, `serverTransactionIdAuthenticated=false`, `eventSessionAssociationProven=false`, `authorizesAccept=false`, `authorizesTrade=false`, `mayRecordCompletedTrade=false`, `mayRecordRejectedTrade=false`, `mayReportProfit=false`, `mayUseForStrategyLearning=false`, and `tradeOutcome=UNKNOWN`.

## Independent tests and handoff

- Standalone source: `pdiddler/new_part4/STAGE60_READONLY_TRADE_REMOTE_SURFACE.lua`
- Native-simulated Python/Lua 5.4 regression: `pdiddler/intelligence_lab/test_stage60_remote_surface.py`; fixed 16-event baseline, hypothetical GetTradeHistory, unsafe/duplicate/truncated/missing names, non-MM2, 300 deterministic malformed/varied inventories, exact false authority on every result and static forbidden-mutator scan.
- Workflow: `.github/workflows/mm2-stage60-remote-surface-tests.yml`, plus entire inherited Stage59 intelligence suite. Run current HEAD CI before passing a pinned Delta loader to user.
- Base: PR104 Stage59 draft exact head `d6f4657101db8e9b42d0f27ad112d646f15faffb`. New Stage60 remains independently DRAFT; **do not merge** a PR104 stack blindly into main.

**Next manual step only if GitHub Actions green:** On MAIN iPad in original MM2, after lobby/UI loaded, run the single SHA-pinned Stage60 loader. **No second device, no trade, no weapon expense.** Tap COPY REPORT on the purple guide or paste the bounded Delta console marker. From the result, decide one next narrow evidence question (e.g. whether a specifically named function is actually a read-only public result endpoint). Never call unfamiliar RemoteFunctions in hopes of a receipt. A missing function requires investigation of alternative *trusted* sources or a deliberate trust-policy decision, not additional wasteful transfers.
