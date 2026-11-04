# Independent community, wiki and guide evidence — November 4, 2026

Research scope: new underlying MM2 pages and original non-Reddit discussion material, complementing the separate video/TikTok and public trading-platform investigations. Existing PR13 ledgers were read before searching. No runtime file changed. No new Supreme price extraction, authenticated message access, public posting, provider execution or autonomous crawl occurred.

## Conclusions that can inform the implementation

1. **Keep exact numeric safety separate from market appeal.** Three newly read guides distinguish value from demand, trend and resale usefulness, and two original WFL discussions judge similar-looking offers differently. This supports evaluating the retained/received inventory; it does not calibrate a demand multiplier or show that a quality-first plan always earns more.
2. **Do not donate additional items merely because the other player says an item gets overpays.** RPGStash explicitly challenges blind extra adds and asks what sort of overpay occurs, from whom and how often. A shared trade-wide budget and verified action accounting are defensible engineering responses. No page establishes an optimal budget fraction,60% opener or acceptance uplift.
3. **Preserve both upgrade and downgrade alternatives.** The guides describe compact upgrades and useful-denomination downgrades, with demand/exit concerns on either side. Their goals differ. There is no evidence to universally maximize compactness, diversification, knife count, Chroma exposure or set retention.
4. **Preserve the native cooldown and approval checks.** The MM2 wiki says an item addition requires a six-second wait; a newly inspected real screenshot still shows “Please wait (2) before accepting.” This independently corroborates a cooldown, but cannot replace PR14's actual native-ready nine-second wait plus 2.5-second buffer. No community source proves a shorter universal safe timer.
5. **Four unique slots and stack support are separate facts.** The wiki says four unique items can contain multiples. A screenshot actually shows four distinct offered items. Neither establishes our executor's raw quantity/add/remove/reconciliation semantics. Keep the conservative four-copy implementation until native stack tests prove more.
6. **Do not copy human loss-taking exceptions.** Some guides permit a list loss to obtain better demand, a collection or a desired upgrade. Those choices conflict with the approved every-leg Supreme+15/no-overpay requirement. Preserve that requirement; use qualitative evidence only within safe candidates.
7. **“Accepted” titles are not completion evidence.** Both inspected public accepted-claim screenshots show a pre-completion state, not a transaction receipt or before/after inventory. This is direct evidence of the limits of public WFL labels, not evidence that their posters lied or that the trades never later finished.

The sources support these principles and counterarguments, not measured acceptance rates, liquidation discounts, guaranteed returns or a proven globally optimal strategy.

## Source-by-source underlying reads

### C1 — RPGStash, Murder Mystery 2 Trading Guide

URL: https://www.rpgstash.com/blog/mm2-trading-guide

Observed 2026-11-04. Author displayed:Jonas. Created/updated date printed as 04.07.2026; the image path includes 2026-07-04. The full main guide text was read through ordinary Firecrawl scrape, not inferred from search excerpts.

Relevant contents:

- Describes community values as estimates rather than official developer prices.
- Separates raw value, demand, rarity and trend. Explains that collector-specific utility may differ from ordinary trading utility.
- Warns that receiving several low-demand items can make an equal-value trade hard to exit.
- Suggests comparing sources to investigate large disagreements, not picking whichever source makes a trade look favorable.
- Says a seller's claimed overpays need evidence rather than blind extra adds.
- Describes small consistent wins, quality-conscious upgrades and patient collector matching as different approaches.
- Allows human overpay for demand/sets/dream items; that portion is incompatible with the bot's strict+15 rule.

Limitations: commercial item seller with shop links, generic guidance and no transaction-level dataset, failed-attempt denominator, subsequent exits or measured acceptance. Several confident generalizations about future demand/event supply are not independently validated. This is qualitative commentary, not market calibration or an approved purchase route.

Scrape ID:`01a1a58b-3aa6-719e-a862-179606d9d59e`; HTTP200; receipt 1credit.

### C2 — Game Value Hub, How MM2 Trading Works

URL: https://gamevaluehub.com/mm2-trading-works/

Observed 2026-11-04. Metadata:published 2026-03-13T12:44:53Z; modified 2026-10-21T21:31:53Z. Byline:James, whose biography claims active MM2 trading experience; that claim is not independently checked. Full returned main text was read, including WFL, “Real Experience,” strategic upgrades/downgrades and advanced concepts.

Relevant contents:

- Distinguishes list WFL from whether received items are useful in later trades.
- Describes both compact upgrades and downgrades for flexibility when the small items are easier to trade onward.
- Recommends diversity among desirable items and avoiding large unstable/low-demand exposure, rather than diversity for its own sake.
- Describes negotiation as understanding the other person's wants while avoiding unnecessary overpay.
- Says final trade contents should be checked again because an initially proposed offer can change.

Counterarguments and limits: its “Real Experience” section is a generalized narrative, not an auditable chronological log. Phrases suggesting high-demand items are never stuck overstate what the page demonstrates. Its broad category table (e.g. Chroma demand) cannot replace individual exact-variant records. Some examples use Legendary items, outside our approved universe. Its allowance for strategic list losses is excluded. The page promotes its own calculators and contains no controlled acceptance/turnover data.

Scrape ID:`01a1a58b-39bf-76fb-93b6-d194a6efd486`; HTTP200; receipt 1credit.

### C3 — GameBoost, MM2 Trading Guide (2026)

URL: https://gameboost.com/blog/mm2-trading-guide

Observed 2026-11-04. Metadata:published 2026-06-23T10:14:16+02:00; modified 2026-10-20T14:28:39+02:00. Byline:Mustafa Atteya; an internal “Verified By” Muhammad Nagi credit is not an independent transaction audit. Full main article was read.

Relevant contents:

- Describes high-demand items as easier to trade and often attracting better offers.
- Explains upgrading several smalls into one item, then downgrading into greater combined nominal value.
- Frames counterparty discovery as part of trading performance, mentioning server changes and external advertising.
- Recommends reading the entire actual offer before accepting and resisting pressure to rush.

Limits: commercial seller; repeated store links and promotion of Neblio. Describing a profitable cycle is not proof that every leg satisfies+15 or that a matched exit is available. Its claim that trading sites are “most efficient” has no comparative timing data. Its short account of both players accepting is not native protocol verification. No direct messaging, offsite purchase, new server-selection rule or native acceptance was performed/adopted.

Scrape ID:`01a1a58b-3bac-71b8-b2f6-caa25008e835`; HTTP200; receipt 1credit.

These three articles are separate domains, but similar SEO narratives are not three independent empirical studies. Their agreement corroborates common terminology/heuristics only.

### C4 — Murder Mystery 2 Wiki, Trading

URL: https://murder-mystery-2.fandom.com/wiki/Trading

Observed 2026-11-04. Main wiki body and its available links were read. Publication/current-revision date was not established; page screenshots are from different historical dates. Community-edited reference, not official game source.

Specific statements inspected:

- Trade requests use the player-list profile/menu and native Trade control.
- Each item insertion incurs a six-second acceptance wait.
- Four unique items can be traded, with multiple copies.
- Effects/emotes/radios are untradable; other listed classes such as pets are still outside our user's approved offer scope.
- Lists historical/undated reports of stuck trades, both accepted without completion and data-loss/duping issues.

Implications: preserve known-good native controls, cooldown checks, raw class/identity validation and proof of outcome. The uncorrelated vulnerability allegations do not establish a current exploit or authorize deleting UI, resetting characters or guessing completion. The phone toggle statement is layout-specific and cannot override our tested tablet/phone resolver. Its market-share assertion about Supreme is unmeasured. No item prices or private comments were scraped. The page states CC-BY-SA community licensing; this note paraphrases with attribution and does not mirror the page or its images.

Scrape ID:`01a1a58b-bdd1-708e-a210-41f45576ff10`; HTTP200; receipt 1credit.

### C5 — Actual Fandom discussion: upgrade/downgrade definitions

URL: https://murder-mystery-2.fandom.com/f/p/4400000000000059593

Observed 2026-11-04. The returned public reply text was read. It contains mutually inverted definitions:one reply calls upgrade making an inventory better, another calls downgrade trading for something better, another uses higher/lower value. Original question header, complete dates and all attribution were not returned; one edit credit is visible.

Conclusion: **reject as authoritative terminology or strategy advice**. It demonstrates that naive parsing of words such as upgrade/downgrade can infer the wrong intent. It does not justify any hardcoded premium or behavior rule.

Scrape ID:`01a1a58b-be00-72d1-ab72-094ab4d1bbdb`; HTTP200; receipt 1credit.

### C6 — Actual Fandom advertised inventory and counteroffer

URL: https://murder-mystery-2.fandom.com/f/p/4400000000000130361

Observed 2026-11-04. Underlying public post/reply text lists two Handsaws, Pumpking, Luger, Snowflake, Eggblade and Legendary sets. It seeks a Godly downgrade for Handsaw and a Legendary upgrade to Seers, explicitly says “NLF: Bad demands, Pets,” and receives a Prince-for-Pumpking-and-Snowflake counteroffer.

What this establishes:one poster expresses inventory-shape and demand preferences; one counteroffer was posted. It is neither an accepted trade nor a representative demand sample. Dates and complete identities were not exposed. No current item prices were inferred. Legendary/Pet/Vintage examples remain outside this bot's eligibility and do not broaden its scope.

Scrape ID:`01a1a58b-bdcd-7761-ae20-051f93d52d07`; HTTP200; receipt 1credit.

### C7 — Claimed accepted WFL, Golden→Handsaw

Thread: https://murder-mystery-2.fandom.com/f/p/4400000000000295144

Original attached image: https://static.wikia.nocookie.net/87643d0d-851d-4912-9b27-a8695074dedf/scale-to-width/755

Observed 2026-11-04. Read the public post/replies and **visually inspected the actual attached screenshot**, downloaded only for private inspection. The image shows YOUR OFFER Golden, THEIR OFFER Handsaw, OTHER PLAYER HAS ACCEPTED, and our green Accept button. Replies call it a win and criticize Vintages. Search metadata suggests April 18,2022, but the scraped main body does not establish the date independently.

This is a real observed pre-completion offer image plus a poster's accepted claim. It does not show both final approvals or inventory deltas. Golden is a Vintage, so this is not a candidate trade for our bot. It is useful evidence against training on “accepted” titles as transaction proof. No screenshot is redistributed in the repository.

Scrape ID:`01a1a58d-8fd9-7318-b0b4-6f50a77d109e`; HTTP200; receipt 1credit.

### C8 — Claimed accepted WFL, four-item bundle→Evergun

Thread: https://murder-mystery-2.fandom.com/f/p/4400000000000332967

Original attached image: https://static.wikia.nocookie.net/9f95fdef-a545-41fe-80f3-c240695fc8a8/scale-to-width/755

Observed 2026-11-04. Read the actual replies and **visually inspected the source screenshot**. It shows our Sakura, Rainbow Gun, Rainbow and Candy against their Evergun. Native text says “Please wait (2) before accepting.” Replies judge it a loss because the sacrificed Sakura/Rainbow items were described as rising, while Evergun was described as stable. A commenter quotes 1350 versus 1445; those are unverified historical numbers, not November 2026 operational values.

This directly shows a four-distinct-item native offer and an unfinished cooldown, plus contrary feedback about surrendered quality. It does not establish final completion, actual price direction at posting time, an obtainable exit, or a repeatable profit rate. The accepted title may describe a later event, but the attached image itself is not proof. No image is mirrored in the repository.

Scrape ID:`01a1a58d-8ff6-70bc-b90a-f3828ab82356`; HTTP200; receipt 1credit.

## What the implementation must not infer

- No optimal 60% replacement fraction, generic premium, concession probability or exact five-second negotiation timer was measured.
- No source establishes that receiving better ordinal demand always compensates for surrendered raw profit.
- Different-player wants are real but cannot be read from entire inventory value alone.
- New exact identity always requires offer/approval revalidation; a fresh signature is not automatically a fresh economic spending allowance.
- Advertised cross-list comparison does not authorize mixing price scales within an offer. Supreme remains the sole operational scale.
- Four unique UI slots do not independently prove safe >4-copy executor behavior.
- The two inspected accepted-claim screenshots add **zero independently verified completed trades**. No before/after inventory or later resale was obtained.
- No new native Accept/Confirm or Discord capability should be enabled from these articles/screenshots.

The evidence supports implementing consistent risk metrics, inventory-distinct candidates, controlled concessions and exact verified execution as conservative structural improvements. Numeric quote-region choices remain explicit policy choices that need supervised testing, not claimed learned market optima.

## Discovery and access accounting

Five focused Firecrawl searches were used:

| Query | Search ID |
|---|---|
|`MM2 trading guide upgrade downgrade demand low demand -site:reddit.com -site:youtube.com -site:tiktok.com`|`01a1a58a-f22f-7370-be1b-2bb79e1a9e42`|
|`site:devforum.roblox.com trading economy demand items limited value player trading`|`01a1a58a-f21d-7586-8771-1e18f0d1db15`|
|`MM2 trading wiki demand trading value trading upgrade forum -site:reddit.com -site:youtube.com -site:tiktok.com`|`01a1a58b-8271-77ca-882b-b9ac3d7532a3`|
|`site:murder-mystery-2.fandom.com/f/p trading demand godlies downgrade`|`01a1a58b-8296-733b-b326-f790b7325f65`|
|`site:murder-mystery-2.fandom.com/f/p "accepted" "overpay"`|`01a1a58d-398c-756c-b061-de023196d74f`|

The DevForum search returned Roblox Limited/UGC Marketplace discussions, not MM2's item economy. Those mechanics were rejected, not counted as evidence for MM2 native holds/quantities. Rolimon's general Limited glossary was likewise not imported. Reddit's known unsupported route was not retried. New commercial guide dates do not refresh any publisher's prices.

Receipts:5searches×2credits +8ordinary scrapes×1credit =18gross Firecrawl credits. All five searches received 1credit feedback refund each, for 13net documented credits. Two original image downloads used ordinary public CDN retrieval outside Firecrawl and have no Firecrawl charge. These figures are tool receipts, not the user's Codex credit balance. No paid provider, login, comments/messages, purchase or extra agent was used.
