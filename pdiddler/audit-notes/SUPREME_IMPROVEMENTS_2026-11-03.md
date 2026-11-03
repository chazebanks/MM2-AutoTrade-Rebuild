# Implementation and verification notes — November 3, 2026

User authorized the highest-impact improvements within a limited credit budget,
after research. No additional paid search was used. All changes are new files;
the V3 loader and every original GitHub base blob remain unchanged. Do not merge
automatically.

## Root causes and changes

The supplied bot-test screenshot shows a corroborated detector verdict followed
by `BOT_HOLD request-ui-loading`, not a failed detector classification. The V3
fix in PR #2 handles both native request layouts. This build retains it and
also fixes hidden-phone masking and stale ancestry in outgoing and Part 4.

The old trading system mixed MM2Values arithmetic, a separate Supreme profile
and permissive quality-loss rules. The new policy has one Supreme numeric basis
and an unconditional +15 floor. Explicit item-ID contradictions can no longer
fall back to a matching name. Unknown partner slots no longer become zero-value
ineligible items. Quantities and sums across repeated slots must fit inventory.

P4 was copied from the later identity-corrected nonadaptive v2.4.5 file at
`837bf387e5cc75469b1e43a5e74be02c19a5f742` (blob
`fa8259495fe3d27985f3908c651ea4d769d7090c`), rather than reverting the known later
raw-ID/checker-ID fix. New outgoing v16 derives from preserved v15. Their exact
identities remain distinct from price/checker identities throughout execution.

The old 15-second/Case-3 empty behavior and profitable indefinite hold have been
replaced by the user-specified 12/5-second behavior with a 60-second backstop.
The old last-balanced shortcut was removed because it bypassed later negotiation.
The dynamic planner caches by exact opponent signature and fails closed at a
bounded state budget. No second planner or hopper is introduced.

Independent review identified additional races, all addressed with regressions:
acceptance during removal waits; missing inventory bypassing deadlines; dependency
replacement on duplicate run; same-root GUI close/reopen; expiry preventing
decline, including expiry during opener retrieval/verification; operations past
the overall deadline; initialization before a pre-existing-offer decline; decimal
+15 comparison; hidden phone trade roots; stale/duplicate outgoing cancellation.

## Evidence

- Test-first pricing policy: absent implementation initially failed; boundary,
  unknown, non-finite, quantity and exhaustive-search comparisons now pass.
- Actual extracted P4 helpers: original later baseline had 9 failures and 2
  passes; the new identity/quantity helpers pass all 11.
- Outgoing identity/restart tests exposed old v15 failures. Additional cancellation
  regressions exposed nine failures before their fix. Current suite passes 34.
- New complete P4 source runs in official Luau, unchanged inside an injected
  Roblox/scheduler fixture. 21 runtime scenarios cover real opener, mutation,
  timer, stop, partner, GUI, expiry, duplicate-owner and acceptance-race paths.
- 46 pure-policy tests, 6 new-loader integration tests, 13 snapshot/parser/Lua
  freshness tests. Original 44 integration +14 hopper regressions still pass.
  **189 behavioral tests total**, plus native Luau compilation and dependency
  source/hash checks. These are offline verifications, not live MM2 evidence.

## Explicit scope limits

This is a supervised manual-Accept test build. Native automatic acceptance,
completion/delta proof, durable totals and webhook delivery are not implemented
in this PR. The loader supplies no completion sender or verified telemetry
candidate publisher. Closing a trade does not imply a successful completed trade.

Supreme has 189 finite mapped prices, not 190; Priceless is unpriced. Fixed expiry
is November 4, 2026, 20:29:14 UTC. Four total copies are deliberately conservative
relative to native stacking. Frozen scanner whitelist/UI arithmetic remains its
old basis; only the trading API's copied inventories and trade totals are Supreme.
These limits are documented in `SUPREME_TEST_BUILD.md` and must remain visible.
