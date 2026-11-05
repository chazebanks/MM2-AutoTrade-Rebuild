# V15.8 — selected contributions first

This isolated successor changes physical insertion order only. V15.7's planner, selected combination, canonical item identities, quantities, prices, preferred profit, +15 floor and concession ledger are unchanged. The current base is draft PR30 at9b4d78572cec606885e8f1d72f13cf277bc226f3.

## Cause and correction

Policy10 sorts inventory rows by ascending value while constructing deterministic owned combinations. The selected plan's picks retain that traversal order. P4v10 iterates those picks directly, so cheap filler requests precede the main contribution.

P4v11 builds a separate array of wrappers referencing the original selected rows, validates finite positive unit prices and positive integer quantities, and sorts wrappers by `value * qty` descending. Equal contributions retain the original index order. The original plan, key, row references, picks order and quantities remain intact for reservation and final proof. Invalid ordering metadata aborts before any clear or insertion; it is never replaced with zero or guessed.

Each duplicate remains an individual native OfferItem call. The per-copy context/identity/opponent-signature/acceptance checks,0.15-second pauses, slot restrictions, immediate safety inspection, recovery limits and final exact multiset verification remain byte-identical. The new order does not add an insertion retry or treat remote invocation as success. Only verified final slots may commit the existing reservation.

## Exact380/310 example

The pinned snapshot verifies Ocean245 + Mortal135 =380 and Boneblade7 + Iceblaster33 + Immortal135×2 =310. The unchanged preference is57 base +13.5 source-condition premium =70.5; selected profit is70. The temporary40-value display was a construction prefix, not the selected economic plan.

| Native request number | Previous item | Previous cumulative value | New item | New cumulative value |
| ---: | --- | ---: | --- | ---: |
| 1 | Boneblade | 7 | Immortal | 135 |
| 2 | Iceblaster | 40 | Immortal | 270 |
| 3 | Immortal | 175 | Iceblaster | 303 |
| 4 | Immortal | 310 | Boneblade | 310 |

These cumulative values describe immediate, successful acknowledgements in the actual-controller boundary fixture. Real MM2 may delay, reject or reorder visible acknowledgements. The exact expected final quantities and70 profit remain the same in both versions. The test freezes original picks, records the selected/reserved/committed plan and verifies its original identity/order/key and ledger values.

For unchanged verified380, every positive prefix remains at least+70 profitable. Clearing or waiting for replication can show an empty side; that is incomplete and never establishes an acceptable or completed trade. A partial construction is not a final committed quote even when its arithmetic is profitable.

## Correctness trade-offs

Putting more value in earlier also exposes more value earlier if the opponent removes items during construction. Existing V15.6 safety checks run at the same boundaries before subsequent additions; exact partner, transaction ownership, price freshness and offered-item signatures still fence the mutation. An unsafe verified quote triggers the existing withdrawal/decline protection. No client-side ordering can make a sent native remote atomic with a simultaneous opponent change, or cancel a request already in flight. Delayed acknowledgement remains an uncertain outcome until observed and verified.

Existing removal chooses the highest visible slot index. If native slots follow insertion order, a later replacement may therefore remove cheap fillers before the main contribution. This fix leaves that removal path intact and verifies that an opponent removal during such a clear still invokes immediate safety rather than ordinary retry waits.

This change still requests four copies with the same0.15-second pauses. It does not reduce native cooldown resets or prove a shorter transaction. Earlier credible presentation and fewer premature declines are hypotheses for native testing, not measured acceptance gains.

## Scope and verification

The release gate protects all431 predecessor files by Git blob hash and normalizes the new P4 against v10 to permit only the helper/preflight/execution-list change and its version identity. The strategy policy and19 other loader dependencies retain their exact immutable pins. Scanner, incoming/outgoing rotation, bot detection, readiness, hopping, Supreme snapshot, Common-item behavior, native final Accept and Discord completion are unchanged.

A separate artificial JobId-only probe still fails in both baseline and successor when the old GUI/root/session are deliberately retained. [JOBID_BOUNDARY.md](JOBID_BOUNDARY.md) records this inherited limit and the stopping tests for actual owner/root invalidation; this release does not add or claim a direct JobId fence.

The complete production controller runs against the real policy10 and early policy5. Tests compare baseline and successor insertion requests and cover duplicate contributions, stable ties, frozen plans, delayed/failed native calls, identity/opponent/acceptance changes, partial verification and subsequent clearing. Inherited44 immediate-safety,14 strategy and15 economic-controller cases run against the successor. Results and immutable pins are recorded alongside this document.

The November4 Supreme snapshot keeps its original expiry: November5,2026 at21:55:32UTC /4:55:32PM EST. It remains fresh during this investigation. Historical clocks are confined to fixture tests and do not extend live trading. Expired prices still block new work.

## Native check

Use exactly one pinned Auto Execute entry and rejoin before switching builds. Capture the selected plan and actual slots during the380/310 construction; check whether Immortal appears before the fillers and whether duplicate acknowledgement remains correct. Observe cancellation and protection when the partner changes items, accepts or closes during construction. Compare the same quantities, final310 total and70 quoted profit; distinguish requests, visible partial offers, verified final quotes and authoritative inventory completion. Do not infer a completed trade from window closure.

Measure opponent declines and native rendering over comparable sessions before claiming an acceptance improvement. Preserve the build SHA, fresh value profile, action timestamps and confirmed outcome evidence. Automatic final Accept and completed-trade Discord delivery remain disabled.
