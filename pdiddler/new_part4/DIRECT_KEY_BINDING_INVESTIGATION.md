# Direct weapon-key binding: evidence boundary and one payload-shape observation

2026-11-06 UTC. User-approved direction: abandon image/asset investigations. Stage36 and PR75 remain historical evidence. This work does not implement weapon identification, modify Stage34, or enable any trading action.

## Candidate and verified source facts

The best single candidate is **`ReplicatedStorage.Trade.UpdateTrade.OnClientEvent`**. A genuine Stage33 report recorded one receipt while its trade GUI was open, at local elapsed +9.039 seconds. `UpdateOffers` was only catalogued in that run. Receipt of an event does not establish what its arguments mean.

The investigation read both canonical handoffs at main `5bee470`, [PR75's latest strategy-pivot comment](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/75#issuecomment-6681602510), Stages9/27/33/34/35 and their test evidence. Source/history audit at task start covered **962 reachable commits, 1,325 unique blobs, 27,349,478 blob bytes**. It found no real update-payload decoder or native trade-state schema binding a raw key to owner/side, slot and session.

| Source | What it actually establishes |
| --- | --- |
| `p4_native_observer.lua`, `slotId` / `readSide` | Reads five ID-like slot attribute/ValueBase aliases and physical GUI slots. Native Stage35 found none of its candidate IDs. |
| `p4_observer_contract.lua` | Makes private physical offer signatures, parses displayed quantities and distinguishes raw-ID resolution from name-only fallback. Signatures and names are not direct identity evidence. |
| Presentation scanner, `indexItems` / `inventoryFromProfile` | Real Sync/Weapons.Owned keys are available in catalogue/inventory data. No offered-slot ownership link follows. |
| `p4_stage27_native_transport.lua`, `add` | Sends `OfferItem(id,"Weapons")`; explicitly not placement proof. The new diagnostic sends nothing. |
| `STAGE33_READONLY_TRANSPORT_DELTA_PROBE.lua` | Its incoming callbacks take zero arguments and forward only event names/times. |
| `p4_stage33_transport_window.lua`, `received` | Accepts event name and local time only. Its session name is application-created, not a server transaction identifier. |
| `p4_stage34_offer_delta_reconcile.lua` | Preserves client-only quantity reconciliation and `AMBIGUOUS_NAME_ONLY_OFFER_IDENTITY` without directly bound raw IDs. |

Older native probes contain handwritten TradeId/TransactionId/partner aliases, synthetic test payloads and guessed completion booleans. These are not observed UpdateTrade schemas. Stage12 repeats the GUI ID aliases. None supplies new binding evidence.

**Unknown:** argument count; whether any argument contains keys; raw-key field semantics; owner/player representation; side; slot versus array order; quantity versus physical instances; session identifier; revision/freshness; and correspondence to the specific displayed slot. No reliable binding exists in the available evidence. Technical achievability remains an open question.

## Narrow implementation and branch scope

Dedicated branch `feature/gingerscope-direct-key-update-shape` starts at immutable known-good `35ec2d9a47048910a464a2ef6eb9b9f52ae306b1`. Its PR is stacked on the unchanged Stage36 branch to keep the diff limited; PR75 is not the implementation PR and is not merged.

`p4_trade_update_shape.lua` inspects **types and structure only**. It does not recognize schema field names, compare values to catalogue keys, interpret quantities or owners, or resolve an identity. It receives a private packed argument list and emits bounded argument-type positions and aggregate table key/value types/layouts by depth. No arbitrary key, scalar value, string length, player object property, payload table, name, ID, token or fingerprint is exported.

Bounds are eight arguments, four table depths, 32 distinct tables, 128 total entries and 4,096 bytes per string/key. Nil argument holes are preserved. Dense arrays are distinguished from sparse numeric maps without relying on Lua's ambiguous length operator. Shared references at the same depth are counted once plus an alias count. Cross-depth aliases conservatively return ALIAS_DEPTH_UNVERIFIED rather than hide a deeper path or claim complete traversal; cycles, metatables, unsupported keys, opaque values, nonfinite numbers and exceeded bounds also remain INCOMPLETE. Sanitized partial type counts may explain why inspection was incomplete; zero default counters are not proof of a zero-argument event.

`DIRECT_KEY_READONLY_UPDATE_SHAPE_PROBE.lua` uses the existing **Stage9 native observer and contract** for private GUI capture/signatures and quantity/accept-indicator reading, without scanner calls. A thin injected contract carries the reader's verified local window/partner context separately from inventory-dependent identity resolution. Existing modules are not rewritten.

The observer's physical signature can be produced without resolved inventory IDs; the normalizer's identity-dependent `contextOK` is never promoted into identity authority. All private raw labels/signatures/player objects stay in local context and are never included in the report.

The launcher:

- Requires one visible trade root and one actual username-matched partner; stabilizes the local window/frame before listening. Does not substitute DisplayName, infer a payload session, or attach to every Trade event.
- Connects only the unique allowlisted UpdateTrade RemoteEvent after binding the local window. No UpdateOffers fallback, trade send/invoke, automatic item action, source bypass, metatable interception, decompilation or image work.
- Observes the **first** receipt only. Validates local context before and after bounded inspection, then disconnects. A locally stable window is not authentication that a delayed payload belongs to that session.
- Uses passive GUI/context invalidation signals and polling so cancellation, root reuse, partner/account/job changes, Accept indicators, competing owners and timeouts terminate observation. It retains no raw event arguments in global state or report.
- Disconnects listeners on all terminal paths, including partial attachment and synchronous receipt during Connect. Explicit stop and no-event timeout are supported. If Disconnect itself fails, all other teardown attempts still run, cleanupComplete=false and INCOMPLETE are reported, and terminal guards refuse later payload processing. No post-close receipt grace or second-session rebinding occurs.

A normal result is `PAYLOAD_SHAPE_OBSERVED_UNBOUND`, not a valid weapon identity. `payloadSchemaKnown=false`, `rawKeyPresentConfirmed=false`, `ownerSideSlotBound=false`, `eventSessionAssociationProven=false`, `eventOrderingKnown=false`, `rawItemIdConfirmed=false`, `exactWeaponIdentityConfirmed=false`, `serverCompletionProven=false`, `tradeOutcome=UNKNOWN`; all trade/Accept/completed-journal/profit permissions remain false.

## Failure cases and interpretation

| Failure case | Boundary retained |
| --- | --- |
| Equal display names, Chromas, different rarities | Names/Chroma are private GUI context only. Payload scalar values are never resolved to weapons. |
| Multiple physical copies / quantity fields | A number's type does not identify a quantity, slot or instance. Existing quantity parser remains unchanged; no payload quantity schema is guessed. |
| Duplicate keys / repeated data structures | Key types/layouts and aliases are structural observations only. Distinct numeric/string keys are not stringified into a weapon map. |
| Add/remove/reorder while trading | Private GUI signatures can report that the visible offer changed; no payload row is assigned to a GUI slot. Equal displayed signatures can still hide distinct same-name items. |
| Delayed/out-of-order receipt | Only local observation timing is known (elapsedSinceBind is sampled after bounded inspection, not a server generation timestamp or exact network-arrival timestamp). No server revision/session token is assumed; a delayed event in a stable window remains unbound. |
| Cancel/reopen/reused root or partner change | Terminate and disconnect; do not inherit the previous local observation epoch. |
| Opposite player's offer | No owner/side interpretation of event fields exists, so neither side is assigned an ID. |
| Malformed, incomplete, opaque or oversized payload | INCOMPLETE with fixed structural counts/reasons; no guessed fallback or automatic retry. |
| No UpdateTrade receipt | This means no qualifying receipt was observed during the bounded window, not that direct binding is impossible. |

## Exact next checkpoint

No additional completed trade is required. If the user elects a new device measurement, one manually controlled, no-Accept trade window can supply the first bounded UpdateTrade argument-shape report. Merely opening an empty window might not emit UpdateTrade; an operator-controlled offer change may be needed, with no transfer. The script never adds/removes an item itself.

This report is provided **before requesting execution**. A shape report may reveal whether the candidate is structurally useful; it cannot alone establish the meanings of unknown fields or prove key/player/side/slot/session binding. Identity resolution remains prohibited until real source or independently validated schema supplies every link. If shape is insufficient, seek that source/schema rather than fabricate a resolver or return to image matching.

## Verification

Offline fixtures are synthetic. They can validate bounds, privacy and lifecycle, not MM2's real argument schema. Actual Lua 5.4.8 tests pass **29 pure cases** and **77 actual-launcher mock cases**; both suites demonstrated RED before implementation. Independent review found a cross-depth alias completeness defect and native exception/clock lifecycle edges; regressions reproduced them before fail-closed corrections. Final inherited regressions and inspected GitHub Actions are recorded in the new PR. Both canonical main handoff documents receive the verified checkpoint separately, without merging implementation code to main.
