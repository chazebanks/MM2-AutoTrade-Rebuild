# Stage 16 — Risk-adjusted candidate review (research only)

**No live offer selection, proposal construction, item insertion, acceptance,
or trade completion is enabled.** This stage sits on the Stage 15 identity
guard and Stage 14 safety gate as a **separate pure Lua module**. The output
cannot set `quoteSafe=true` and cannot authorize the Stage 8/11 controller.

## Why this is a separate component

Stage 7 already contains bounded candidate search with seller-side
attractiveness and four-copy research. Replacing it would duplicate working
research and conceal its known limits. Stage 16 instead reviews a candidate
that a separate engine has generated, using independent dimensions:

1. **Listed value delta**: sum of receive base values minus give base values.
2. **Conservative range delta**: sum of verified receive *minimums* minus give
   *maximums*. When any one item lacks a confirmed range, report `nil`,
   never fill the missing range with its base value.
3. **Demand relationship**: first-order dominance of **base-value-weighted
   ordinal demand threshold distributions**, not an acceptance probability.
4. **Flippability relationship**: if every item has a source-proven
   Flippability extra feature, compare that ordinal feature separately.
   If missing on either side, `unknown`. This is at best a resale proxy,
   **not measured liquidity**, realized spread, or trade speed.
5. **Stability exposure**: compare proportions of listed value tied to
   fluctuating/receding/underpaid/decreasing/unsafe statuses and separately
   flag serious negatives.

This follows Supreme's Use Guide and calculator cautions:
- https://www.supremevalues.com/use
- https://www.supremevalues.com/mm2/calculator

## Input contract

`local Review = require("p4_risk_review")` in an offline Lua test. A future
Delta-specific loader would inject this module and *independently validated*
market/scanner data; no native hook is implemented in Stage 16.

```lua
local context={
    now=1000, -- Unix seconds; synthetic only
    market={
        sourceId="synthetic-fixture-do-not-deploy",
        verified=true,
        observedAt=900,
        validUntil=2000,
        items={
            ["godly:11:checker-id"]={
                valueCents=10000,lowCents=10000,highCents=10000,
                demand=2,stability="stable",flippability="flippable",
                tradable=true,verified=true,
            },
            ["chroma:12:checker-id"]={
                valueCents=12000,lowCents=11500,highCents=13000,
                demand=5,stability="doing_well",flippability="highly_flippable",
                tradable=true,verified=true,
            },
        },
    },
    ownInventory={["godly:11:checker-id"]=1},
    opponentInventory={["chroma:12:checker-id"]=1},
}
local candidate={
    give={{id="godly:11:checker-id",qty=1}},
    receive={{id="chroma:12:checker-id",qty=1}},
}
local review=Review.assess(context,candidate)
-- review.lane == "REVIEW_FAVORABLE"; still:
assert(review.authorizesTrade==false and review.quoteSafe==false)
```

All quoted numbers above are **synthetic**, not actual MM2 item prices. Market
values use integer **hundredths of one Supreme listed-value unit** to avoid
floating-point rounding in profit arithmetic. Source demand is ordinal 0..11.
Stability uses canonical Supreme labels:
`rising, overpaid, doing_well, improving, fluctuating, receding, stable,
underpaid, decreasing, unsafe`. Flippability uses only source labels
`rarely_flippable, flippable, highly_flippable` and is optional; missing
does not get invented.

The caller must supply a genuine source ID, actual pinned publication/observation
and expiry evidence, verified item identities and scanner ownership. Merely
setting `verified=true` in caller-supplied data does **not** prove any of those
things. Stage 16 itself never retrieves source data or establishes such proof.

## Output lanes (all research-only)

- `BLOCKED`: malformed input, unverified or expired market, unknown identity,
  invalid quantity, missing catalog metadata, or unproven ownership.
- `REVIEW_LOSS`: nominal loss, even if the acquired item has better demand.
  No loss is silently converted into a recommended trade.
- `REVIEW_CAUTION`: nominal gain with uncertain ranges, weaker/mixed demand,
  unknown/weaker flippability, higher volatility, or severe negative stability.
- `REVIEW_FAVORABLE`: positive nominal **and conservative** gain, no worsening
  demand distribution, source-confirmed non-worsening flippability, no increasing
  volatility share, and no received severely negative stability.

These labels are **review priorities**, not execution recommendations, fill
probabilities, values from live trades, or guarantees. As part of every output
`reviewOnly=true`, `quoteSafe=false`, `nativeReady=false`,
`authorizesTrade=false`, `authorizesAccept=false`.

## Conservative limits and failure modes

- Do not accept screenshots as authoritative item quantities, IDs or source
  timestamps. Stage 15 blocks the known Godly/Vintage Laser ambiguity. Other
  cross-tier name collisions are not fully inventoried.
- Maximum 4 **copies** total per side and maximum 4 distinct slots are still
  enforced. Stage 12 demonstrated stacked `Iceblaster x2` in one visible
  slot, but Stage 7's conservative 4-copy budget is **not** expanded here.
- Both inventories are validated only against **supplied records**, and the
  opponent scan may be stale. Nothing here establishes a current server-side
  holding or a counterparty's desire to accept our offer.
- Invalid/sparse Lua arrays and missing source evidence fail closed. The
  ranking routine refuses input beyond its explicit maximum instead of silently
  truncating candidate lists.
- Even a `REVIEW_FAVORABLE` result does not imply that an opponent will accept
  a losing trade or that the weapon can be resold promptly.

## Regression tests

```sh
lua5.4 pdiddler/new_part4/tests/test_p4_risk_review.lua pdiddler/new_part4
```

The new test suite runs as an additional job step in the existing
`stage14-part4-tests.yml` GitHub workflow, alongside Stages 8–15. Do not
claim the tests passed until the GitHub Actions run result is confirmed.

## Follow-on work (separate stage)

Do not wire `REVIEW_FAVORABLE` to `authorizePlan` or Accept. First verify
a current published market snapshot and prove a trustworthy evidence bridge
from Stage 9 resolved IDs to catalog keys; model counterparty-side
attractiveness with Stage 7's separate research; and validate actual native
proposal placement and post-trade completion.
