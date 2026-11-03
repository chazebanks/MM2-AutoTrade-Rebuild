# TikTok research for Pdiddler — 2026-11-03

Read-only research for the proposed Supreme-valued trader. No runtime, design, loader, or trading-policy changes were made.

## Result and access limits

TikTok supplied **useful anecdotal context, but no validated automated trading strategy**. Direct Firecrawl retrieval of the existing @villianhello guide returned an explicit unsupported-site 403. The supported Oriane provider returned actual dated TikTok captions, machine transcripts and OCR for several MM2 clips. Its index did not contain the focused trading guides/value posts looked up, including @villianhello, @bigboycoobs, @rp_profits, @yvlastromm2 and the latest event-value-drop posts. Empty provider records do not mean a post was deleted or never existed.

I did not watch these videos. The observations below are from the provider's returned text fields. Transcription/OCR can be wrong, especially item names. Web-search snippets are kept separately and labeled as excerpts; many TikTok descriptions explicitly contain AI-generated summaries, so their prose is not treated as creator testimony.

A broad indexed-caption search for “mm2” reported 563 records. Offsets 0, 100, 200 and 500 returned records; offsets 300 and 400 produced uncertain-provider-outcome errors and were not retried. This is incomplete coverage and is not a representative sample of all MM2 traders.

## Retrieved primary-source records

| Source and date | Retrieved format and direct evidence | Practical implication and strength |
| --- | --- | --- |
| [@nitronuke — 7694799049664384286](https://www.tiktok.com/@nitronuke/video/7694799049664384286), **2026-10-09** | Creator caption: “I may have meet the most adorable player on mm2.” Provider transcript includes: “I have a ice wing. What will you add?” and later “I don't want the ice wing. Take it out. You can just have this.” OCR includes trade UI labels and acceptance countdown text. | A request to add can occur during negotiation, but this example ends as a **gift**. It supports separating gifts/content-driven generosity from ordinary profitable trades. It does not establish that adding increases completion probability, that the item values were correct, or that the shown trade completed. |
| [@shark.boi41 — 7693302069762985230](https://www.tiktok.com/@shark.boi41/video/7693302069762985230), **2026-10-05** | Creator caption explicitly says “Gifting streamers the RAREST ITEMS IN MM2.” Provider transcript: “I don't have an offer. I'm not going to lie.” / “No, no, no. Have it.” | Receiving a rare item for no return in a creator clip is not evidence of repeatable trading profit. A trading model should not learn expected returns from gifts, streamer interactions or relationship incentives. Strong evidence about this clip's purpose; no quantified market inference. |
| [@.brawnilla — 7671665676464983316](https://www.tiktok.com/@.brawnilla/video/7671665676464983316), **2026-08-08** | Portuguese machine transcript says the creator has been trading frequently, acquired several knives they wanted, and is looking for difficult-to-find **common knives** as a personal challenge: “Ultimamente eu tô indo só atrás de facas comuns ... que é difícil de conseguir ... gosto de me desafiar.” It also contains uncertain item-name recognition (“Habster”, “Germstone”, “Icewind”). | Counterparty preferences can be specific and unrelated to maximum list value or rarity. A personal wishlist is stronger evidence of intent than assuming everyone wants the highest-valued opener. This is one person's preference, **not** evidence that knives universally outperform guns. Common knives remain outside the user's eligible offer universe. Never convert transcript item names into runtime aliases or values. |

Source links, returned evidence formats and reported dates are preserved in `source_manifest.json`. Full third-party transcripts are not mirrored here.

## Relevant discovery excerpts requiring verification

The following are **web-search excerpts only**. Full captions/transcripts and publication dates were unavailable through the supported retrieval routes. Do not treat their titles, generic summaries, apparent profits or item numbers as verified facts.

| Discovery source | Actual excerpt available | Bounded implication |
| --- | --- | --- |
| [@yvlastromm2 — 7656715263806623006](https://www.tiktok.com/@yvlastromm2/video/7656715263806623006) | Caption-style excerpt: “trading those sets for a upgrade! i have more stuff to add to!!” | Some people seek upgrades and offer adds. This supports recording explicit intent and evaluating multi-item combinations, but does not justify a universal upgrade premium. |
| [@jaxn_sleep — 7678815795463425311](https://www.tiktok.com/@jaxn_sleep/photo/7678815795463425311) | Caption-style excerpt: “Lf Sakura set and small add #trading #downgrade #mm2 #roblox #fair.” | Set-specific preferences and “small add” requests appear in public offers. A matched set may be desired; no verified fixed set bonus follows. |
| [@sabersab342 — 7667266938678168862](https://www.tiktok.com/@sabersab342/photo/7667266938678168862) | Caption-style excerpt: “Mm2 downgrading soul gun! Huge op!” A generated title claims 210 value gained. | Downgrade-for-overpay is a strategy people advertise. The claimed gain and realized resale value are unverified. Do not calibrate thresholds from it. |
| [@antagonistawaken — 7395432244443237662](https://www.tiktok.com/@antagonistawaken/video/7395432244443237662) | Title/caption excerpt begins “yes i did overpay by like 140… but watergun is so trash that its losin…” | A trader may accept paper loss to exit a declining item. This is only a truncated anecdote and **does not override strict +15/no-overpay**. It flags value-trend risk for investigation. |
| [@villianhello — 7589012728535125270](https://www.tiktok.com/@villianhello/video/7589012728535125270) | Search excerpt: “Players who trade underpaid items often end up getting underpaid again.” | Consistent with a liquidity-risk hypothesis. The previously recorded project transcript was not independently retrieved here. Keep that prior evidence distinct. |
| [@theofficialcliplife — 7699580111963639053](https://www.tiktok.com/@theofficialcliplife/video/7699580111963639053) and [@evvxanii — 7699097146913525014](https://www.tiktok.com/@evvxanii/video/7699097146913525014) | Search titles discuss new Halloween weapons dropping in value; surrounding descriptions are generic/generated and provider lookups were empty. | Leads for checking official Supreme history around an event. They do not prove current drops, exact prices, or a sell deadline. |

Publication dates in the discovery table are **unverified**; no numeric post-ID timestamp was substituted for source metadata. The source URLs and evidence formats are recorded in `source_manifest.json`.

## Implications for the proposed trader

1. **Keep Supreme as the numerical source.** TikTok speech, captions, OCR, listed requests and claimed wins cannot establish current Supreme prices. A valid identity, fresh authoritative value and explicit unknown-value rejection remain necessary.
2. **Treat demand, liquidity, trends and wishlist intent as separate considerations.** The returned evidence supports heterogeneous preferences and illustrates why a paper win or a content-creator gift is not a resale-profit estimate. No reliable TikTok-derived numerical liquidity multiplier was found.
3. **Do not hard-code a universal knife advantage, set bonus, downgrade premium or event forecast from these sources.** The evidence is anecdotal or inaccessible. Existing user preferences can be tie-breakers; stronger weights need actual offer/completion observations.
4. **Highest-item-first remains a product requirement, not a verified best strategy.** Nothing retrieved tests its completion rate against smaller relevant openers. Record trade size, counterparty changes, offered combinations and confirmed outcomes to evaluate it later.
5. **An “add” request is a reason to reevaluate, not an instruction to append blindly.** The retrieved gift clip and discovery excerpts cannot determine the optimal delay or amount. Replanning still has to preserve the user's +15 floor, identity/value confidence and four-slot limit.
6. **Keep the user's safety/timer rules unchanged.** These TikToks provide no validation for 5-second negotiation intervals, a 12-second empty-offer timeout or a 60-second cap. They also provide no evidence for relaxing acceptance verification, completion verification or the exactly-once webhook rule.

## Retrieval record

Used Firecrawl search with the shared objective:

> [deep-research] Identify evidence-backed MM2 trading strategy improvements for a Supreme-valued automated trader while separating anecdotes from validated rules.

Inspected Oriane's published contracts before execution. Ran only declared `caption`, `url`, `projection`, `sort`, `limit` and `offset` options. Provider descriptions and illustrative contract examples were not counted as evidence. Search feedback was submitted for all eight searches; Alexandria feedback was submitted once for TikTok. The source manifest records the unsupported-site and empty-lookup limitations. Provider contract examples were not treated as source evidence.
