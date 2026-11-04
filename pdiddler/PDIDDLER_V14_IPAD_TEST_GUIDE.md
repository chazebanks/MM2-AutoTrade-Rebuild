# V14 workflow build — supervised Delta verification

This separate draft successor preserves every one of PR15's248 files. Do not run
multiple builds in the same server. Disable older Auto Execute entries and join
MM2 cleanly. Final Accept/Confirm and completed-trade Discord activation still
require a native contract captured from this game; no environment flag substitutes
for it. The new acceptance, reconciliation and delivery paths run end to end in
offline fixtures, which do not establish native MM2 behavior.

## Immutable entry

```lua
local e=(getgenv and getgenv()) or _G
local u="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/0de09a34efa91fae85c4f8069c9321a7db5aa3fc/pdiddler/pdiddler_V14_TELEPORT_AUTOBOOT_v1.lua"
e.PDIDDLER_V14_AUTOBOOT_URL=u
loadstring(game:HttpGet(u,true))()
```

Module pin:b23138cc769a632b8791fe1d50776faf1c7ac1dd. Loader/probe pin:461f8fc0e6a3392460922e28f54bc178967647ad. The17 dependencies have
exact local Git-blob hashes in `tests/integration_sources_v14.json`. The queued
entry uses the same immutable bootstrap. Native Delta queue support remains a
live test; the built-in Auto Execute fallback uses this same entry.

The preserved Supreme snapshot expires **2026-11-04 21:42:28 UTC**. Expiry is
not extended. After that, trading requires an authorized, source-verified new
immutable snapshot/build. Read-only probe/readiness inspection does not refresh
prices. An already submitted transaction retains its verified valuation version
for accounting; this does not authorize new acceptance at stale prices.

## Changes and expected behavior

| Test | Exact expected result |
|---|---|
| Startup and the reported V12 hold | Tablet and optional friend Play retain their existing clicks. Hidden inventory branches do not consume the loading-text scan. `WAIT_READINESS` records examined/pruned counts; actual visible loading or missing prerequisites still hold. Then one10s gate and one outgoing owner start. |
| Matching items | If they offer an item we own, our planner excludes every copy of that canonical item. Normal/Chroma variants remain distinct. If they add a matching item after our opener, our quote is replaced or safely declined; no profitable-looking mirrored quote is approved. |
| First safe quote | Opponent-first and reduction of an unsafe opener use the same selection policy. Exact planned quantities appear in the actual slots before verification. No automatic highest-value opener is restored. |
| Negotiation | A market-tied early offer remains unchanged. A genuine early appeal improvement uses the least costly comparable candidate. Deliberate late value concessions still require the existing native-ready buffer and bounded two-step budget. Opponent changes invalidate the old generation. |
| Accepted closure | A manual Accepted indicator and subsequent closed window do not release the workflow as a success. Pending/unconfirmed completion prevents new requests and hops. |
| Rotation and hopping | An ordinary unaccepted closure retains the processed-player ledger and outgoing rotation. Active trades, pending requests and outcome ownership continue blocking P5. Only P5 teleports. |
| Queue re-entry | A real hop starts this same pinned build once. The queue contains only the public loader URL. Private webhook configuration must be supplied separately before each session; it never enters queued code or the report journal. |

The native workspace `WaitForChild("Buy")` warning in the screenshot is not our
readiness reason. This build does not modify that game script or claim to repair
every native character/world initialization failure. A genuinely unresolved active
UI scan remains bounded and reports its limit path; do not bypass it.

## Required native evidence

Use a known, supervised profitable trade whose actual offers satisfy the existing
rules. Automatic acceptance is OFF during collection. When the trade window is
open, the partner is resolved and both offers are known, run:

```lua
local p=getgenv().PDIDDLER_NATIVE_EVIDENCE_V2
p.inspectButtons()
p.capture("before")
```

Wait for the probe's inventory-read success message. Complete the trade yourself
through MM2's normal controls; record the actual button/countdown/Accepted sequence
and console server-event observations. After the window closes, run:

```lua
getgenv().PDIDDLER_NATIVE_EVIDENCE_V2.capture("after")
```

Wait for its success message, run that same after-capture once more, wait for
success, then run:

```lua
getgenv().PDIDDLER_NATIVE_EVIDENCE_V2.report()
```

Expected: structured **UNCONFIRMED observations**, one bound lifetime and two equal
complete raw inventories. This observation token is local, not a native transaction
ID. A boolean AcceptTrade event or stable inventory alone is not relabelled a
verified completion. Request-time context fences late responses and reopened GUIs.
Raw holdings remain local in the probe; do not publish a full inventory dump.

On separate supervised attempts, record a cancellation and an offer change around
native acceptance. Expected: cancellation never counts as profit; offer changes
invalidate approval; no repeated automatic action occurs. An unpriced item, a
different partner, unexpected confirmation screen, unresolved quantity or price
expiry is a stop condition for that live test.

## Acceptance and Discord activation blockers

The production loader's `approvedNativeContract` is deliberately nil. The missing
evidence is the exact native action sequence/control identity, cooldown/reset
behavior, completion correlation and complete raw-inventory read timing. It also
needs a native adapter that binds that evidence before submission and survives
closure. The generic controller and fixture adapter are not that native proof.

Discord additionally requires the private runtime variable
`PDIDDLER_DISCORD_WEBHOOK_URL`, executor HTTP/JSON APIs and working read/write/isfile
storage. Supply the variable privately before loading each session, including through your own Delta Auto Execute configuration when hopping. This build does not copy credentials into queued code. Do not put the URL in GitHub or console output. The two fixed journal
files store account-scoped reports/receipts, never credentials. Corruption,
account mismatch or uncertain delivery is reported, not silently overwritten or
resent. A real webhook send has not been performed from this environment.

The verified report contains given/received items, Supreme values, demand,
available liquidity, totals, profit, valuation version/time, priced inventory
subtotal and unpriced counts. Whole-inventory value is unavailable if incomplete.
Only a completed raw-delta report can enter the outbox; an open-offer candidate
cannot. Delivery uses Discord `wait=true` and a returned message receipt.

## Offline reproduction and performance limits

```sh
LUAU_BIN=/path/to/luau LUAU_COMPILE=/path/to/luau-compile python3 pdiddler/tests/run_v14_checks.py
```

Use official Luau0.745 and Lua5.4/5.3. Full results are saved in
`audit-notes/V14_TEST_RESULTS.txt`. The exhaustive oracle and controller simulations
are not observed traders, native completions or an economic backtest. Compare
verified Supreme gains per whole session-hour, failures/timeouts, concessions,
mutations and subsequent exits only after actual outcomes exist. No optimal
acceptance percentage, liquidity probability, guaranteed growth or personal item
objective is claimed.
