# Stage 13 — native quantity semantics (evidence-based contract patch)

**Draft-only; do not merge into the active Pdiddler loader or enable physical trade actions.**
This change builds on Stage 12 / PR #50 and does not change legacy Part 4, bot avoidance,
server hopping, accept, market/strategy authorization, inventory fetches, or Discord.

## Source evidence

Two separate anonymized live Stage 12 Delta logs show single items as
`ItemName#NO_ID[]` (an **existing** Amount TextLabel whose Text is exactly `""`).
The later manual Iceblaster stack test is decisive:

- 50.70s: `OURS=1:Iceblaster#NO_ID[]` (one visible offered copy).
- 52.45s: `OURS=1:Iceblaster#NO_ID[x2]` (two offered copies in the same slot).
- 59.20s: `OURS=1:Iceblaster#NO_ID[]` (one copy after manually removing one).

All were in one `TradeGUI` session with an exact partner match and no Accept.
The read-only probe itself is unchanged. The log does **not** prove that
automated slot clicking removes exactly one copy.

## Exactly what changes

- In Stage 9 `p4_observer_contract.lua`, an Amount node with `Text == ""`
  now parses as quantity **1**, matching the native representation.
- Explicit `x2`, `×2`, and numeric labels retain their existing parser
  and integer bounds. A missing Amount node (`amountText == nil`),
  whitespace-only, malformed text, absent item name, unverifiable chroma,
  nonunique scanner names, and scanner ownership shortfalls **remain unverified**.
- A named, visible occupied slot must still reconcile with its inventory
  identity; a blank amount alone never proves an item exists.
- Stage 9 read-only contract and native mock tests cover blank/missing/invalid
  labels and `NO_ID` scanner fallback. Stage 11 integration test replays the
  actual `x2 -> ""` transition while checking one-at-a-time removal intent.

## Boundaries / next validation

Stage 9 and Stage 12 are read-only; Stage 11 remains a separate unapproved,
defensive mock integration. No live physical-click test has succeeded.

A slot may be temporarily incomplete or re-rendered between GUI updates.
Before authorizing a real one-shot removal, implement a stability/identity
revalidation gate and verify actual click outcome on-device in a controlled
session. The trade GUI's lack of item IDs makes unique scanner matching
necessary but still not a current inventory/market proof.

Do **not** treat this change as authorization for price quotes, item addition,
trade acceptance, or automated removal. Existing `quoteSafe=false` and
fail-closed safety boundaries remain unchanged.
