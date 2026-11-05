# Gingerscope Intelligence — Stage 1 (offline Python lab)

This is **new, isolated trading-decision research**. It does **not** modify or
execute the existing Pdiddler Luau trader, scanning, bot avoidance, GUI,
teleport/Delta control, HTTP/webhooks, or native acceptance. There are no live
trade actions. No old `+15`, concession, or proposer rules are inherited.

## Run the tests

```sh
python -m unittest -v test_evaluator.py
```

Python 3.10+ and standard library only. All supplied prices in the tests are
**synthetic fixtures**, not a live trading database. The example Gingerscope
price is fixture data, not a live market claim.

## What the evaluator does

- Verifies exact **type:item:variant** identity and quantities on both sides.
- Refuses to price unknown, ambiguous, zero-valued, nontradable or expired
  assets as if their value were confirmed. Portfolio totals with unknown items
  are explicitly **lower bounds**; no unknown item becomes zero by default.
- Computes exact listed-value change with no arbitrary fixed-profit floor.
  It does **not** automatically accept negative-value offers either.
- Separates value, stable-value concentration, and ordinal demand profiles.
  Demand ratings are **not** likelihoods of opponent acceptance or a currency
  that can be added to value.
- Computes a conservative theoretical **best four copies** and an optimistic
  **four distinct types with stacked copies** ceiling. Neither proves the MM2
  native UI will allow the requested quantities. Source-specific item caps and
  native execution are deferred until evidence is available.
- Reads the target Gingerscope value from the same verified, nonexpired
  catalogue, not a hardcoded amount. Reports both gaps to the listed target.
- Returns warnings, evidence, and `human-review-only`. `compare()` only
  returns a winner if all comparable metrics Pareto-dominate the alternative;
  otherwise it reports `incomparable`.

## The next integration boundary

Stage 2 will require a **verified item identity adapter** for live Supreme data,
including year/variant, the live owner's quantities, partner quantities, price
validity timestamps, and MM2's actual slot/stack semantics. Stage 3 will
validate offer generation and decisions by replaying native recordings. Only
then should a versioned Luau strategy replace the old one. Preserve the old
working code as a frozen rollback; never have old and new economic rule
sets both authorizing the same trade.

## Deliberate limitations

- No current Supreme feed; no inferred demand from trade-board post counts.
- No acceptance probability, recommendation to auto-Accept, or market-liquidity
  claims based on synthetic tests.
- No claim the current inventory equals its listed subtotal when low-tier or
  year-ambiguous items are unpriced.
- No positive prediction of Gingerscope tradeability from merely reaching the
  item's listed value in four slots.
- The old live trader remains unchanged. Its dated price snapshot is not
  silently extended by this laboratory.

---

## Stage 2 — real Supreme snapshot and read-only inventory adapter

This branch adds a new `market_bridge.py` module, a source-linked
`supreme_snapshot_2026_11_04.json` with **all 190** existing
Supreme checker-ID records, a 16-row source excerpt fixture, 14 provisional
high-tier screenshot observations, and 16 new tests.

**Pinned market provenance.**
The normalized catalogue is derived directly from the immutable Luau
source commit `11537dfd47f8df72aec7aeba9ecaffdfc5c879d4`
(`snapshots/pdiddler_supreme_snapshot_2026_11_04.lua`). It retains
the original Supreme update timestamp, publication source URLs, source
SHA-256 page digests, and expiry of **2026-11-05 21:55:32 UTC
(4:55:32 PM EST)**. Importing it never extends freshness; after
expiry the market adapter fails closed until a genuinely new source
is verified.

**Exact identity matching.**
The adapter uses `page:checkerId:checker-id`, plus the exact
verified item name, and checks quantities, ownership provenance,
incomplete scanner flags, JobId, playerUserId, placeId and snapshot
capture time. It handles all five native Supreme status labels without
misrepresenting `Doing Well` as `Stable`. Priceless weapons have no
numeric trade price.

**Screenshot assessment versus native authority.**
Fourteen higher-tier inventory rows transcribed from the user's
screenshots can be matched provisionally to catalogue identities,
with a known priced subtotal of **4,548** at the pinned date. This
excludes Emberknife and other unverified, lower-tier or pet items;
it is **not** a complete portfolio valuation. The screenshot's
checker IDs were inferred from labels and are **never** accepted as
native scanner evidence. The parser cannot currently verify the
actual MM2 scanner export shape or a full, contemporary live inventory.
For two-side comparison, fresh, complete `source=native_scanner`
records with matching job IDs are required.

**Pure Python; no trade actions.** The bridge performs offline
analysis only. It contains no Roblox services, UI clicks,
server hopping, webhook, trade acceptance, trade offers, HTTP
requests or mutation of existing trading modules. It returns
`human-review-only`, not executable decisions. The older trading
policy is still present only in the untouched live code; the
new intelligence does not inherit that old policy.

### Run the 34 tests

From `pdiddler/intelligence_lab`:

```bash
python -m unittest discover -v
```

The tests include market expiry, exact identity mismatch, duplicated
items, invalid quantities, cross-server data, incomplete inventory
proof, native-versus-screenshot evidence and the original 2,500
seeded mathematical scenarios. Native scanner fixtures in tests are
**synthetic**, not evidence that the real iPad executor export
has been implemented or verified.

### Integration input contract (future native capture)

```json
{
  "source": "native_scanner",
  "captured_at": "2026-11-05T13:53:00Z",
  "jobId": "real-Roblox-server-job-id",
  "playerUserId": "player-id",
  "placeId": 142823291,
  "fingerprint": "actual-scanner-inventory-fingerprint",
  "unmapped": 0,
  "unpriced": 0,
  "badQty": 0,
  "items": [
    {
      "id": "raw-item-id",
      "checkerId": "810",
      "page": "chroma",
      "name": "Chroma Watergun",
      "qty": 1,
      "type": "Gun",
      "cat": "Weapons"
    }
  ]
}
```

The JSON is a **contract example**, not a captured native response.
A future read-only exporter will need to fill and verify it from the
actual scanner without modifying its logic. The existing code and
source snapshot must not be repinned simply to satisfy tests.

**Next:** capture and replay the actual scanner's raw inventory
structure from both parties; refresh expired prices with source
evidence, then design and test candidate ranking on confirmed
trade outcomes. Do not connect any automatic final Accept here.
