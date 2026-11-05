# Stage 19 — Python-only Gingerscope two-account ledger

**Scope: offline read-only accounting, with synthetic tests.** No live trade code, scanner rewrite, Roblox hook, clicks, autoaccept, webhook, or production deployment.

## What this adds beyond Stages 5 and 18

Stage 5 computes Gingerscope purchasing power from one theoretical portfolio. Stage 18 connects existing candidate generation and bilateral review. Neither handles *separately held assets across the owner's multiple accounts* or distinguishes value earned through completed trades from a rise in Supreme's market quotes.

Stage 19 reuses Stage 1's exact Decimal pricing and four-copy metrics to add:

1. Main and alt inventories as separate local account snapshots (pseudonymous labels, no public account IDs). Calculate current **best single-account** conservative four-copy bundle separately from a clearly labeled **theoretical consolidated** bundle. Consolidation is NOT achieved until a separately evidenced in-game transfer.
2. An explicit Gingerscope ownership flag. If any account owns the exact checked target, the goal is acquired; a resale or liquidity score must not make the final acquisition appear to be a failure.
3. A rigorous before/after accounting equation:

       Listed change = verified completed external-trade deltas at old market prices
                     + repricing of final inventory between old and new market snapshots

   Value neutral **internal transfers** between two owned accounts are NOT trading profit. Unknown inventory movements fail rather than silently being classified as profitable trading.
4. Provenance labels. Provisional screenshot inventories may calculate **listed lower bounds** but cannot substantiate a completed-trade profit report. A caller-supplied claim that an inventory is native, or a supplied event reference, is **not** independently verified by this module.
5. Still no trade authorization, recommendation, predicted acceptance, invented market price, or native execution.

## Trust boundary

The ledger requires **matching complete eligible-weapon snapshots** on both sides of any claimed completed event, and matching event item-quantity deltas. A false or repeated completion reference, a missing account, unpriced asset, nonconserving transfer, impossible intermediate ownership, or unexplained movement is rejected.

This is a structural contract. The actual Delta scanner and completed-trade verifier must independently establish that the source, inventory captures, and completion evidence are authentic. Stage 19 never sets authorizes_trade or authorizes_accept true.

The original November 4 Supreme JSON source remains expired. Do not extend it by changing valid_until; official fresh publication and ID mapping must be independently established.

## Validation

Python is the primary test runner:

    cd pdiddler/intelligence_lab
    python3 -m unittest discover -q

The test suite includes inherited strategy evaluation and Stage 18 Python-to-Lua contract tests, and **19 new Stage 19 Python tests** on synthetic data.

The separate Lua 5.4 suite remains in CI to test the boundary interacting with the actual Roblox-script modules. A passing Python simulation does not prove a native Delta click, item transfer or trade completion.

## What remains for live use

The same-session opponent scanner timestamp, fresh item price authority and final trade-completion proof remain distinct release gates. If a subsequent test proves any of them already exists, reuse that implementation; do not create another scanner or verifier.
