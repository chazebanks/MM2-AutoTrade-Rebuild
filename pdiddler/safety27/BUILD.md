# V15.6 — Issue27 immediate unsafe-quote safety

This is an isolated draft successor to PR26 (`6652869abc6461d11d919f836f05e2fd1e57c568`). Its independently verified immutable chain is:

- P4: `c26562f37fd53ee5c773356115a56f600d3cdf7f`.
- Loader: `d32950c3fa2341ad4662a67a2cecfb4e0c7f797a`.
- Delta teleport bootstrap: `35899fab02e9dfb9a4ec44cadf15aee8cd8bbc9e`.

All22 published runtime blobs match the tested local Git hashes in RUNTIME_PINS.json. The combined entry will be supplied after the separately isolated Issue28 strategy passes; this document records the independently tested safety build.

The successor changes Part 4 protection of a currently visible unsafe quote. It inspects the actual current quote before the existing 0.65-second voluntary planning debounce and at transaction validation boundaries. A verified single-copy withdrawal has one total 0.24-second deadline and no retry. Multiple slots, stacked quantity, unsafe acceptance state, or uncertain withdrawal require one bound decline. Emergency withdrawal retains the previous economic ceiling and concession ledger.

The predecessor's canonical identity and pricing policy, +15 minimum, addition thresholds and concession limits remain in force. Unknown opponent entries remain unpriced and unresolved. Local acceptance must be exactly false to hold such an offer. The separate Common-item classification change is not included.

The loader and teleport bootstrap select this P4 successor and reject an existing predecessor owner. Their scanner, outgoing rotation, bot gate, price profile, hopping, readiness and transport dependencies remain pinned to their predecessor versions. All 390 predecessor files are protected by their original Git blob hashes.

**Automatic native final Accept, authoritative completion and completed-trade Discord delivery remain disabled.** No offline test proves that a native transaction completed or gained inventory value.

This is not a value refresh. The preserved November 4 snapshot expires November 5, 2026 at 21:55:32 UTC (4:55:32 PM EST); expired prices must continue to block new trading.

Before switching a future pinned test entry, disable older Pdiddler Auto Execute entries and join a fresh MM2 JobId. Native iPad validation still needs to measure visible unsafe exposure, action acknowledgement, cooldown behavior and partner changes during replacement. See RESULTS.md for reproducible offline verification and its limits.
