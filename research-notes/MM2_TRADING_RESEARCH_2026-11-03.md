# MM2 trading research for Pdiddler — November 3, 2026

Status: research findings and proposed experiments, **not implemented policy**.
The user's strict Supreme +15 floor, eligibility, acceptance checks and current
bot-test loader are unchanged. The separate trading design remains unapproved.

## What was actually inspected

- **YouTube:** descriptions and actual transcript text from nine videos, including
  six timed English caption records. These include 2026 guides by Neblio, Maria
  and Inspecter, older strategy explanations, and a common-to-godly challenge.
  This was text retrieval, not manual video/frame inspection.
- **TikTok:** three indexed caption/transcript/OCR records, plus trading-post
  discovery excerpts. Direct TikTok retrieval was unsupported, and focused guide
  lookups, including the previously cited Villianhello video, returned no record.
  The useful primary records mainly illustrate gifts or personal preferences;
  they do not validate an autonomous trading strategy.
- **Reddit:** relevant indexed excerpts from twelve thread leads. Full page,
  JSON/RSS and supported-provider retrieval were unavailable. These are not fully
  read threads, verified dated comments, or evidence of Reddit-wide consensus.
- **Primary/reference sites:** Supreme's use guide, current category pages and
  trading-server page; MM2Values' trading guide; MM2 Trade Hub's guides, original
  posted-offer statistics and methodology. General merchant-promotional guides
  were screened but not used to set numerical policy.

Source-specific notes: [YouTube](youtube.md), [TikTok](tiktok.md),
[Reddit](reddit.md). [Source manifest](source_manifest.json) records provenance
and retrieval limits. Strategy videos from earlier years are not current prices.
No source establishes a guaranteed profitable bot or validates our implementation.

## Findings that should influence the script

### 1. A listed-value win can leave worse inventory

Supreme explicitly says value is only the **base** value; demand, stability,
rarity and the published range also matter. Its Underpaid For/Decreasing/Unsafe
states are not interchangeable with Stable. It also explicitly says Fluctuating
does **not** automatically mean dying: it means variable outcomes and uncertainty.
These are the publisher's definitions, not measured probabilities of our resale.
[Supreme use guide](https://supremevalues.com/use)

Compatible proposal: retain the user's +15 Supreme requirement as a necessary
condition, then separately check received-item risk and future tradability.
Reject a weak/unsafe downgrade when nominal +15 does not compensate for the
inventory deterioration. Do not invent a guaranteed resale value, a fixed -8%
haircut or a liquidity probability from a demand score.

For ranged items, a conservative scenario can expose a nominal win that would
be a loss near the published lower range. This is a proposed risk check, not a
new authorized price formula. A published range is not a guaranteed executable
bid/ask quote. [Supreme ranges](https://supremevalues.com/use)

### 2. Upgrade/downgrade shape affects what people will accept

Neblio's guide describes demand premiums and why four native trade slots make
larger concentrated items useful to buyers who want expensive items. Maria also
emphasizes demand over nominal total. These are qualitative creator claims;
they supply no audited acceptance-rate dataset.
[Neblio, 2:15–4:33](https://www.youtube.com/watch?v=nbvaa_Erjww&t=135s)
[Maria, 0:21](https://www.youtube.com/watch?v=CQQ589ACJvQ&t=21s)

Compatible proposal: distinguish upgrade, downgrade and sidegrade, and compare
inventory quality before and after. A single desirable item should not be
automatically exchanged for four unwanted items merely because the sum clears
+15. Prefer a compact, appealing safe bundle over padding with unnecessary adds.
Keep a useful mix of desirable items and small eligible adds for later matching.
The latter inventory-reserve proposal is an inference, not a proven optimal ratio.

Several creators recommend temporarily overpaying to acquire a desirable upgrade
and recovering profit on a later downgrade. That **conflicts** with strict +15
on every trade. Pdiddler should skip those opportunities rather than silently
reintroduce the old loss exception. No reviewed source validates a universal
premium. [MrMoogma, 2:55–3:49](https://www.youtube.com/watch?v=kJ1X08FKdQg&t=175s)

### 3. Demand should outrank a blanket knife/gun preference

No reviewed source proves knives universally trade better than guns. Both types
appear among sought-after items. TikTok also contains personal collecting goals
that do not follow value/rarity. That supports item-specific intent and demand,
not an automatic type premium.
[Supreme demand definition](https://supremevalues.com/use)
[TikTok primary-record limits and examples](tiktok.md)

Keep the user's knife preference only as a tie-breaker between otherwise
comparable safe choices. Do not let it override a desirable gun, verified price,
quantity, or the +15 floor. No invented aesthetic score or fixed set bonus.

### 4. Highest-item-first has not been shown to be optimal

None of the retrieved guides compares completion rates for GUI opener policies.
Advice to ask for offers on a listing is not a test of what to put in MM2's trade
slots. A creator's advice to leave listing intent open cannot prove our highest
item opener is right or wrong.
[Swirly Blox, 5:22–5:58](https://www.youtube.com/watch?v=mRZxbl0TWGI&t=322s)

Recommendation: preserve immediate highest-item opening as requested, but make
it an explicit experiment. A future alternative worth comparing is **offer
first with a realistic, desirable item that fits the partner's eligible trade
capacity**, rather than always expose our most expensive item. This changes the
user's highest-item rule and needs review before implementation. Inventory does
not prove willingness to trade every owned item; do not confuse capacity with
intent or count hidden/unpriced goods as affordability.

### 5. No acceptance yet does not automatically justify another add

Sources describe negotiation and asking for adds, but do not establish that
periodic automatic additions cause better trades. A counterparty may be reading
values, waiting for native cooldown, looking for a set or simply not interested.
The retrieved TikTok clip with an add request ends as a gift, not a measured
negotiation success. [TikTok evidence](tiktok.md)

Recommendation: each improvement needs a fresh, genuinely better safe plan and
actual-slot verification. Do not voluntarily give back every opponent increase,
append low-demand filler, or sweeten while they are already accepting. Keep the
bounded negotiation rule and final wait; measure its effect rather than assume it.

### 6. The +15 floor and exact timers are choices, not discoveries

No reviewed source empirically validates +15 on every trade, five-second adds,
twelve-second empty waits or the sixty-second cap. General advice to be patient
does not tell us which number of seconds is best. [YouTube evidence table](youtube.md)
[Reddit retrieval limitations](reddit.md)

Arithmetic alone shows why the floor has different effects: +15 is 75% of a
20-value offer, but 1.5% of a 1,000-value offer. These are illustrative calculations,
not observed acceptance rates or current item quotes. Keep the user's floor;
log both absolute and percentage profit so skipped/unfilled opportunities are
visible. Do not relax the rule without an explicit strategy change.

Keep 5/12/60 as the proposed initial settings, with native acceptance and safety
timers taking precedence. Later compare observed waiting, abandonment and
completion outcomes. Never tune away stale-session or final-confirmation checks
to make a headline success rate look better.

### 7. Posted interest can inform candidates, not establish sale price

MM2 Trade Hub explicitly describes its own figures as **posted offers, not
completed trades**. At retrieval its 30-day dataset contained 4,010 posts:
Harvester appeared offered in 200 and requested in 254; Embersickle appeared
offered in 340 and requested in 61. This is site-specific interest, not the whole
MM2 market, unique traders, verified sales or a probability of getting our offer
accepted. [Methodology](https://mm2tradehub.com/editorial-policy)
[Harvester](https://mm2tradehub.com/values/harvester)
[Embersickle](https://mm2tradehub.com/values/embersickle)

Harvester's reported median solo **asking** premium was +36% from twenty posts.
Do not turn that into an assumed achievable 36% gain. Absurd or incomplete wishes
can be posted, and the feed can contain them. The third-party value snapshot also
lagged the fresh primary-source update already observed in our audit; it must not
silently replace Supreme pricing.
[Source definitions](https://mm2tradehub.com/editorial-policy)

Possible later feature: source-labelled, sample-size-aware interest as a weak
ranking input. Missing/sparse activity remains unknown. Do not scrape social
platforms inside an active trade or make a trade depend on brittle feed latency.

### 8. A full server is not necessarily the best trading server

Supreme publishes dedicated trading servers, including high-tier rooms intended
for high-tier items. Creator recommendations conflict: Inspecter favors public
servers for smaller inventories, while other guides favor dedicated rooms or
segment by trading goal. No controlled comparison establishes a universal winner.
[Supreme server purposes](https://supremevalues.com/mm2/trading)
[Inspecter, 1:39–2:52](https://www.youtube.com/watch?v=8BjBWt8M6TE&t=99s)
[dysaiina](https://www.youtube.com/watch?v=wEPZkxIo2rk)

Measure eligible counterparties, responses, genuine completed trades and time
spent. Do not hardcode a creator's 500-value boundary or change the existing
11/12→10/12 public-server policy without review. Respect server access rules;
never hop during a pending request, active trade or uncertain completion.

## What should not be learned from social clips

Sudon's common-to-godly challenge explicitly uses friends, gifts, fame and Discord
help. Those advantages are not evidence of repeatable anonymous trading profit.
TikTok primary records also include explicit gifting. Separate gifts from ordinary
trade performance rather than train expected returns on them.
[Sudon, 4:18 and 6:54](https://www.youtube.com/watch?v=K07Mg8sm-ng&t=258s)
[TikTok source records](tiktok.md)

Do not encode guaranteed crash/rise predictions, market manipulation, false
rarity, trust/multi-round promises, third-party item purchasing, or special
targeting of inexperienced players. Do not calibrate current prices from older
video narration, search excerpts or AI-generated social summaries. Preserve exact
Chroma/item/quantity checks and normal native confirmation.

## Recommended order before coding

1. Keep the existing read-only audit findings visible: stale values, older loaded
   P4, identity and UI guards need correction independently of trading tactics.
2. Retain Supreme +15, eligibility and verified acceptance/completion requirements.
3. Specify a transparent quality/range risk check and safe-plan ranking from
   current metadata; do not claim an unvalidated numeric resale model.
4. Keep the requested opener/timers initially, but record them as hypotheses.
   Review a realistic-opener alternative before changing the highest-item rule.
5. Build isolated behavior tests before a new versioned implementation, then
   evaluate complete outcome logs rather than a few successful recordings.

Suggested measurements, explicitly engineering proposals: attempts, requests,
opened trades, verified completions, declines/cancels/timeouts/unconfirmed results,
time to first offer/acceptance/completion, offered bundle and item demand/status,
source age/version, inventory quality before/after, +value and +% per trade and
per hour. Separate market repricing from value gained by exchanging items.
Change one strategy variable at a time and compare comparable inventory/server
segments; these sources do not justify a universal sample size or expected return.

The strongest conclusion is to optimize for **completed profitable trades that
leave useful inventory**, not merely green list-value totals. Research informs
the design; it does not certify that automation is correct or profitable.
