# Stage 15 — cross-tier item identity guard (Laser)

**Isolated safety fix; not a production loader update.** This branch stacks on
Stage 14 and keeps its three-sample stability gate, Stage 8 safety state,
Stage 10 one-click ledger, and `quoteSafe=false` contract unchanged.

## Problem verified independently

The new user's MM2 screenshots show multiple distinct items named **Laser**:

- **Vintage Laser** under Classic's Vintage section.
- **Godly Laser** with two copies.
- **Chroma Laser**.

The Vintage Laser and Godly Laser both display `Laser`, but their Supreme
reference entries differ (Vintage 8, Godly 22 on 2026-11-05). Live Stage 12
trade slots consistently returned `#NO_ID`. Stage 9's inventory scanner
intentionally only indexes Godly/Chroma/Ancient weapons, which means matching
the visible `Laser` text to its only eligible scanner record is **not proof**
that the offered weapon is the Godly one.

Source references:
- https://supremevalues.com/mm2/vintages
- https://supremevalues.com/mm2/godlies
- https://mm2wiki.org/wiki/laser-vintage/
- https://mm2wiki.org/wiki/laser-godly/

## Exact resolution

Stage 9's `resolve()` now rejects **non-chroma, name-only**
`Laser` with `cross-tier-display-name-ambiguous`, on either side of
a trade. This is independent of whether the currently filtered scanner
contains a unique eligible Laser. A verifiable, scanner-matched *raw item ID*
can still resolve the item, subject to the ordinary ID, name, quantity,
category, and ownership checks; no such raw ID was observed in live Stage 12.
`Chroma Laser` remains distinct when the GUI explicitly supplies a verified
chroma indicator or literal Chroma name.

- Our ambiguous slot => `contextOK=false`; removal cannot execute on it.
- Their ambiguous slot => `theirResolved=false`, `quoteSafe=false`;
  market/strategy planning cannot count it as a Godly.
- Other unambiguous items and the original Stage 13 `"" -> 1`
  quantity behavior are unaffected.
- The module is still read-only; this patch does not enable any active trader.

## Important follow-up

This patch addresses **one specifically proven collision**, not an exhaustive
MM2 cross-rarity collision catalog. Future safety work should compare the
authoritative complete weapons catalog (including excluded rarities) and
capture a validated item subtype from the native trade GUI if available.
Different weapon IDs must also be verified on-device before relying on the
raw-ID exception as native proof. Additional ambiguous display names must
be added when confirmed, not guessed.

## Tests

- Stage 9 contract: reject no-ID Laser on **our** and **their** sides,
  allow scanner-verified raw ID, allow uniquely identified Chroma Laser.
- Stage 9 mocked native GUI: reject `Laser#NO_ID[]` despite a matching
  eligible Laser scanner record.
- Existing Stage 8–14 and Stage 12 test suite remains in the CI workflow.

No value snapshot is refreshed and no actual trade completion is claimed.
