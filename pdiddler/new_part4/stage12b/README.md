# Stage 12b — native MM2 quantity-evidence diagnostic (READ ONLY)

Stacked draft on Stage 12 (PR #50); **not** a production Part 4 modification.

## Evidence behind this stage

The first native Stage 12 report (November 5, 2026) showed 16 opponent offer changes in a single session. Every occupied slot was displayed as `#NO_ID[]`. A blank bracket means the expected Amount label existed but its Text was empty; it does **not** prove one copy. The Stage 9 quantity reader intentionally rejects blanks pending live stack evidence.

## New scoped probe

`p4_stage12b_quantity_probe.lua` keeps the successful Stage 12 real-trade GUI reader and adds `amountAudit` to each offered weapon slot. It reports:
- Amount label missing/empty/present, exact text, and effective visibility.
- Additional text nodes **within the item slot only** (up to 12 nodes; length limited).
- Numeric-only quantity-related attributes on the slot, its Container and Amount node.
- Both local and opponent offer changes. No player usernames, UserIds, JobIds or other unscoped attributes in clipboard output.

The existing on-screen panel still provides COPY, MIN and STOP. It polls about every 80ms; brief changes may be missed. The probe does not use any MM2 trading remote, injected click, automated offer, acceptance, decline, price lookup or completion claim.

## Local tests

51 executable Lua 5.4/mock-UI tests passed for the new pinned module, including all 45 previous Stage 12 tests plus six new quantity-evidence tests. These do **not** prove actual Delta stack label behavior.

## Native manual test

Disable old Pdiddler Auto Execute, rejoin MM2 and run the pinned Stage12b loader from PR. In a manual trade, show one known one-copy item, then a known two-copy stack if supported (optionally 3), preferably the same weapon. Do not accept or complete the trade. Press COPY and send the anonymized output. A local-side item is useful as an additional check.

**Do not** modify Stage 9 to assign blank=1 until the actual paired one-copy / stacked observations demonstrate that display rule. Do not enable Stage 10 native removal or a strategy/Accept engine based on this audit. Previous Supreme profile expires 2026-11-05 21:55:32 UTC; no automatic extension is permitted.

No old loader, existing Parts 1–5, trading strategies or webhook configuration is changed.
