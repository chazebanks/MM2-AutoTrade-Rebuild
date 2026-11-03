# Pdiddler trading research and audit notes

Saved November 3, 2026. Documentation only; no script changes or merge.

Start with [the finished recommendations](FINAL_RECOMMENDATIONS.md), then
[the detailed research synthesis](MM2_TRADING_RESEARCH_2026-11-03.md).

## Research

- [Finished recommendations and explicit limits](FINAL_RECOMMENDATIONS.md)
- [Cross-source findings and proposed experiments](MM2_TRADING_RESEARCH_2026-11-03.md)
- [YouTube transcript-based notes](youtube.md)
- [TikTok evidence and retrieval limits](tiktok.md)
- [Reddit indexed leads and access limits](reddit.md)
- [Source/provenance manifest](source_manifest.json)

## Existing-system audit

- [Trading correctness audit](../audit-notes/TRADING_AUDIT_2026-11-03.md)
- [All 24 stale-price differences](../audit-notes/value_changes.csv)
- [190-row numeric/identity comparison](../audit-notes/mm2values_comparison.json)
- [Audit source provenance](../audit-notes/source_manifest.json)
- [Isolated trading-function reproduction outputs](../audit-notes/reproduction_results.txt)

The price audit describes the current loader's embedded MM2Values snapshot.
It is not a replacement Supreme price list for the proposed new trader.

## Proposed target design — not approved

[Supreme-valued automatic trading proposal](../docs/superpowers/specs/2026-11-03-pdiddler-supreme-auto-trading-design.md).
It predates this additional research and has not been silently rewritten to adopt
the research proposals. The user's highest-item opener, strict +15 floor, 12-second
empty handling and five-second negotiation remain requirements until reviewed.
The user delegated the overall limit decision; the proposal recommends a
nonresetting sixty-second backstop.

## How to read the evidence

Primary guide definitions, creator opinions, posted offers and confirmed native
trade outcomes are different evidence types. Reddit full threads were blocked;
TikTok focused trading lookups were sparse. Source-specific notes mark those
limits. None of this is an exhaustive survey or a proven autonomous-profit model.

The archived material is authored notes, factual comparisons, source links,
timestamps and limited supporting quotations. Full third-party video transcripts
and website HTML are not mirrored in this documentation archive. Use source URLs
and timestamp links to inspect the originals. No webhook secret is included.

The separate bot integration remains draft PR #2. This documentation branch does
not enable final acceptance, change loader pins, edit frozen modules or merge it.
