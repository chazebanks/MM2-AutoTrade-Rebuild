# Stage76 — exact public Supreme website slug ↔ game-catalogue research (Nov 9, 2026)

**Scope: ONE independent identity-namespace issue from #122. No live MM2 or production price/trade code.**

## Result and sources

We confirmed four **first-party** item-detail URLs and displayed headings by fetching the existing Supreme pages directly (Firecrawl, maxAge=0; acquisition Nov 9, 2026; source intermediary not cryptographically server-signed). The game fields in this comparison are the 13-key Stage75 probe's public EXPECTED attributes, which the user's cropped native JSON screenshot broadly corroborated at 13/13 but did **not** publish as raw per-item fields. Do not elevate this research contract into authenticated owned-item identity.

| Expected game raw key | Expected game metadata | First-party Supreme URL slug / canonical item name |
|---|---|---|
| `Gingerscope` | Ancient Gun, not Chroma | [`ancients?item=Gingerscope`](https://supremevalues.com/mm2/ancients?item=Gingerscope), Gingerscope |
| `EmberscytheChroma` | Ancient Knife, Chroma true | [`chromas?item=CEmberscythe`](https://supremevalues.com/mm2/chromas?item=CEmberscythe), Chroma Emberscythe (class Ancient on chroma listing) |
| `BattleAxe` | Godly Knife, not Chroma | [`godlies?item=Battleaxe`](https://supremevalues.com/mm2/godlies?item=Battleaxe), Battleaxe |
| `BattleAxe2` | Godly Knife, not Chroma | [`godlies?item=BA2`](https://supremevalues.com/mm2/godlies?item=BA2), Battleaxe II |

Critical: website *query slug*, website *display name*, MM2 *raw catalogue key*, art `ItemID`, and Supreme's historic **numeric** site-local checker index are distinct identity namespaces. The website's visible slug `BA2` is not `BattleAxe2`; Gingerscope happens to share the same text in both namespaces but that does not establish equivalence generally. Site display capitalization differences for Battleaxe are explicitly reviewed case-by-case, not a general fuzzy alias rule.

Supreme's primary Gingerscope public page displays 16,000 as of a Nov 6 global update; its item was last changed Nov 4. Chroma Emberscythe's item detail says Nov 6; Battleaxe entries have older item-level update dates. **These differences are precisely why page retrieval cannot substitute for a publisher freshness policy**. The conservative 72-hour Nov6 source-age gate has expired on Nov9. No numeric current quote is eligible from this research.

## Implementation

- `pdiddler/intelligence_lab/stage76_first_party_slug_audit.py` is a pure Python fail-closed four-case *PUBLIC source consistency contract*, not a live source fetcher. Inputs are caller-supplied public catalogue metadata and first-party webpage observations; its success is **not authentication**. All four must uniquely match reviewed URL, exact headline, market category, game ItemName/ItemType/Rarity/Chroma and Chroma Ancient class. No normalization, fuzzy matching or marketplace slug = game raw ID.
- `pdiddler/tests/test_stage76_first_party_slug_audit.py`: nine offline `unittest` groups plus 400 seeded adversarial cases, including wrong/duplicated URL parameters, hostile hostnames, case/alias drift, subtype drift, Chroma Ancient misclassification, duplicate/missing records, and order permutations.
- Workflow `.github/workflows/gingerscope-stage76-first-party-slug.yml` executes actual Python tests in a focused CI job.
- Local Python: **9 test groups PASS, 400 injected cases rejected**. Exact GitHub CI must also be reviewed; no claim that a separate website crawl is included in CI.

All outputs explicitly retain `sourcePublisherFresh=false`, `currentPricesVerified=false`, `numericSupremeCheckerIdVerified=false`, `authenticatedOwnedInventory=false`, `serverAttestation=false`, `authorizesTrade=false`, `authorizesAccept=false`, `mayReportProfit=false`, `mayRecordCompletedTrade=false`, `maySendDiscordWebhook=false`, `mayUseForStrategyLearning=false`.

## Next, and what not to do

1. Validate the independent public source **canonical item identity** at larger scope only with reviewed original source evidence, and separate it from the website-local numeric checker index. No website URL can prove actual **owned** Roblox raw keys or server-side settlement; that needs another evidence path. Avoid re-running Stage75 solely for the same 13/13 counts.
2. Once identity scope is independently evaluated, tackle **freshness** as its own workstream. The 72h policy may be restrictive for a community value list but should not silently be bypassed or patched by changing expiry alone.
3. Keep PR75/74/70 and this Stage76 research branch DRAFT/UNMERGED until reviewed. Do not connect this Python research function to live scanner, P4, outgoing, automatic final Accept, profit tracking or Discord learner.

**This work answers a narrow design question: whether the first-party website has separately verifiable stable public slug/name/category labels. It does, for these four examples. This does NOT solve the broader price, inventory or settlement blockers.**
