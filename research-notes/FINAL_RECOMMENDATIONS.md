# Finished research: what Pdiddler should take from it

Research cutoff: November 3, 2026. This completes the research shown in the
screenshots. It does not implement or approve changes to the trader.

## Recommended baseline

| Topic | Recommendation | Evidence status |
|---|---|---|
| Prices | Use fresh Supreme values, exact identities and one frozen price version per trade. Never fill an unknown value with a guess. | Primary-source definitions; current-code price/identity problems separately reproduced in the audit. |
| Profit | Keep the user's strict +15 floor. Also examine the incoming bundle's demand, stability and published range before accepting a nominal win. | Demand/range distinctions supported; no validated universal risk haircut or resale probability. |
| Inventory growth | Favor usable inventory: desirable items, useful concentration and compact bundles. Avoid trading one liquid item for several unwanted items just to show green profit. | Repeated qualitative advice; no guaranteed improvement rate. |
| Knives/guns | Actual item demand and quality come first. Keep knife preference only as the user's tie-breaker. | No universal knife advantage established. |
| Opener | Keep the requested immediate highest-item opener for the baseline. Compare a realistic, partner-appropriate offer-first variant later if authorized. | No reviewed source tests which GUI opener has a better completion rate. |
| Negotiation | Recompute before an improvement; never append items merely because five seconds passed. Preserve +15 and actual-slot verification. | General negotiation advice; exact delay and improvement size unvalidated. |
| Timers | Retain the proposed 5-second negotiation/final waits, 12-second empty timeout and nonresetting 60-second backstop as initial settings. | Engineering choices, not empirically established market optima. |
| Servers | Evaluate eligible counterparties and genuine completed trades, not occupancy alone. Keep P5 as the only hop owner and never hop during a request/trade. | Dedicated servers exist, but creator advice about public versus dedicated servers conflicts. |
| Performance | Measure all attempts and confirmed completions, including declines/timeouts. Separate gifts and price-list changes from gains caused by trading. | Engineering inference supported by observed selection bias in creator examples. |

Supreme's guide explicitly distinguishes base value, range, demand and stability;
it does not equate a demand score with a guaranteed resale price.
[Primary guide](https://supremevalues.com/use)

The transcript-based upgrade/downgrade advice explains why some traders overpay
to consolidate inventory. A loss-taking upgrade leg conflicts with the user's
+15-every-trade requirement and must remain excluded rather than silently enabled.
[Neblio](https://www.youtube.com/watch?v=nbvaa_Erjww&t=135s)
[MrMoogma](https://www.youtube.com/watch?v=kJ1X08FKdQg&t=175s)

## Conclusions not justified by this research

- A universally best highest-item opener, knife preference or server type.
- An optimal numeric +15 floor or exact 5/12/60-second timing.
- Guaranteed creator-style growth, fixed upgrade/downgrade premiums or reliable
  automatic event-price predictions.
- Treating advertised offers or a posted asking premium as completed-trade data.
- Proof that the existing script's acceptance, completion or webhook is correct.

MM2 Trade Hub explicitly says its activity figures are posted offers, not
completed trades. Those records may be an interest signal, not executable prices.
[Methodology](https://mm2tradehub.com/editorial-policy)

## Coverage and remaining limits

The completed notes contain nine YouTube transcript sources, three TikTok indexed
text records, twelve Reddit thread leads available only as indexed excerpts,
and twelve primary/reference page captures. Videos were not manually watched.
TikTok focused-guide retrieval was sparse. Reddit full threads, comments and
publication dates could not be verified because retrieval was blocked.
These limits are part of the result, not hidden pending research jobs.

See [full synthesis](MM2_TRADING_RESEARCH_2026-11-03.md),
[YouTube](youtube.md), [TikTok](tiktok.md), [Reddit](reddit.md), and
[source manifest](source_manifest.json).

## Next work, separate from research

Before a new automatic-trading implementation, address the existing audit's stale
prices, older loaded trading version, exact partner identity and UI ownership.
Then implement the reviewed specification in new files with behavioral tests.
The research does not authorize changing the highest-item rule, permitting losses
or turning on final acceptance in the current bot-test loader.

No runtime code or loader was changed by this research; no merge was performed.
