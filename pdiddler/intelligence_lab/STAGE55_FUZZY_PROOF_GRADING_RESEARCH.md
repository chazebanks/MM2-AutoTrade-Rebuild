# Stage55 — Clarify whether Stage54's 164 "fuzzy" mappings are exact text matches or weak guesses

## Native evidence and limited conclusion

The user ran Stage54 through iPad Delta and sent the complete anonymized clipboard JSON to ChatGPT. Recorded independently in [Stage54 PR99 native comment](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/99#issuecomment-6718325577).

Actual result: 1,040 client catalogue entries, 850 filtered out, **190 eligible**; all 190 found one checker row under the existing legacy resolver, of which **164 use the score-based "fuzzy" path**, 19 manual name aliases, 7 internal-key map entries. Zero unresolved, ambiguity, or duplicated checker targets; 46 eligible Chromas. There were **2 generic `coming.png` image matches**, and just **5 comparable pairs with years encoded in the checker image**, of which zero disagreed. Thus nothing remotely proves all 190 third-party checker IDs match the game's true raw keys, nor that the remaining 185 item years are correct.

The term "fuzzy" is imprecise. Stage51's code grants 430 base points for **exact normalized internal key vs legacy filename stem**, 360 for **exact normalized display name vs filename stem**, as well as lower scores for progressively transformed similarities. All score-based assignments take the same `match:<score>` route, so Stage54's 164 figure alone cannot distinguish close textual agreement from risky transformations. The latter may be wrong even if the matching is one-to-one.

Supreme Values' official FAQ explicitly says there is no *official* MM2 value list, and Supreme publishes fan-made market value information rather than an independently authenticated raw `Sync.Weapons` key↔external checker-ID crosswalk: https://supremevalues.com/faq. The current online site must not be inferred from this frozen checker image reference or used to silently refresh the scanner.

## One new read-only question

What fraction of the **164 score-based native resolutions** have exact raw-key text or display-name text agreement with a selected checker artwork stem? What is the score distribution and margin over the highest-scoring alternative *within the same source tier*?

`pdiddler/new_part4/STAGE55_READONLY_FUZZY_PROOF_GRADING.lua` inherits the Stage54 **read-only** local-catalogue census and clipboard logic. It includes a second **independent read-only calculation** that replicates the Stage51 scoring logic for each selected fuzzy record and independently scores all *other* checker rows of that tier to derive a runner-up margin. It only adds aggregate counters, never prints raw item names, keys, checker IDs, usernames, artwork references, individual similarities, player inventories, or source payloads. There is **no trade/Accept/offer/remote call** or valid prices. All source numeric values stay `0` because this is a frozen **identity-hypothesis** study, not a market source.

Counts include:
- `fuzzyScoreBelow300`, `300to399`, `400to499`, `500Plus` — not acceptance thresholds, just distribution.
- `fuzzyDirectRaw`, `fuzzyDirectName`, `fuzzyBothDirect`, `fuzzyTransformedOnly`. Exact here means text canonicalized by the resolver's level-0 function, **not** independent item authentication.
- `fuzzyNonUniqueBestScore`, runner-up gap `1to20`, `21to99`, `100Plus`.
- `fuzzyScoreReproductionErrors`; any replay disagreement or score tie/higher competitor yields `FUZZY_SCORE_REPRODUCTION_OR_TIE_ANOMALY`. The report remains nonauthoritative even when no anomalies occur.

The status and all trading/profit/mapping authority fields remain false. The existing Stage54 direct source is untouched. Stage55 is **stacked only on PR99**, which itself is based on the current post-Stage52 main, NOT the older frozen Stage50/51/53 branch. The frozen images and copied resolver are *not* being merged into production.

## Testing / next manual boundary

An isolated GitHub Actions workflow executes the **actual full Stage55 Lua** using Lua5.4 with fake replicated game catalogue and clipboard, 20 mapping scenarios plus inherited clipboard/encoding failures and 400 reproducible mutations. It also runs the entire Python intelligence suite from the branch, including Stage54 and Stage52 regression tests. No real Delta test or live market price fetch occurs in CI.

After the exact-head workflow passes, **ONE** Delta run of the exact SHA-pinned Stage55 loader is justified, no trade, second account, or inventory interaction needed. It will automatically copy the anonymized `[GINGERSCOPE STAGE55 FUZZY PROOF GRADING]` JSON. This is a *new* source-confidence question, not an unnecessary repetition of Stage54. Based on result, next action is either targeted ID/year/Chroma provenance review (if most direct high-margin) or focused mapping correction/quarantine (if weak/conflicting).
