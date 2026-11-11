# Stage58 — Versioned crosswalk candidate review (display metadata only)

**Review snapshot:** 2026-11-08 UTC. **Status:** PUBLIC DISPLAY FIELDS CORROBORATED; **raw weapon key ↔ Supreme numeric checker ID UNATTESTED**; no trade, settlement, or profit authorization.

## Native evidence and limits

The actual [Stage57 Delta native report in PR102](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/102#issuecomment-6718604313) delivered exactly **10 game-catalogue candidates** selected from 1,040 local `Sync.Weapons` rows; 190 passed the broad eligibility filter. The 10 correspond to seven level-2-transformed names, two checker entries with generic `coming.png` artwork, and one smaller runner-up score gap. `evidenceTruncated=0`, `evidenceUnsafeFields=0`. This observation does **not** inspect anyone's live owned inventory.

The source `ItemID` is **client-side metadata**, NOT a unique instance or an authenticated server-settlement token. The raw `Sync.Weapons` key is not the same namespace as the externally assigned checker `page:id`, and high lexical similarity is not server authentication.

## Ten-item review findings

| Local raw key | Display weapon | Community-supported origin | Provisional checker | Review caveat |
|---|---|---|---|---|
| `Icewing` | Ancient knife Icewing | Christmas **2018** | `ancient:4` | Level-2 normalization `IcewingknifeUp.png`; checker number still not attested |
| `Bloom` | Godly knife Bloom | Easter **2025** | `godly:890` | Local year blank; `sourceEvent=1` is generic |
| `Flora` | Godly gun Flora | Easter **2025** | `godly:891` | Local year blank; `sourceEvent=1` is generic |
| `Blossom_G` | Godly gun Blossom | Valentine's **2023** | `godly:696` | Local year blank; `sourceEvent=1` is generic |
| `Ocean_G` | Godly gun Ocean | Summer **2023** | `godly:728` | Local year blank; `sourceEvent=1` is generic |
| `Waves_K` | Godly knife Waves | Summer **2023** | `godly:727` | Local year blank; `sourceEvent=1` is generic |
| `Icecream` | Godly knife Icecream | Summer **2026** | `godly:1005` | Level-2 suffix transformation; game-year agrees |
| `MortalChroma` | Chroma Mortal, Godly **knife** | Halloween **2026** | `chroma:1033` | `coming.png` generic art; `alias` not independently proven |
| `ImmortalChroma` | Chroma Immortal, Godly **gun** | Halloween **2026** | `chroma:1034` | Same generic `coming.png` art; must not infer ID from image |
| `Gingermint_K` | Cookiecane, Godly **knife** | Christmas **2022** | `godly:660` | Legacy key name resembles **Gingermint, a different Godly gun**; also close runner-up score |

The last item is the most important naming trap: **Cookiecane and Gingermint are separate weapons**. The game-catalogue record displayed `Cookiecane` despite the raw key `Gingermint_K`. Both the [Cookiecane wiki entry](https://mm2wiki.org/wiki/cookiecane/) and [Gingermint wiki entry](https://mm2wiki.org/wiki/gingermint/) distinguish their weapon types and acquisition methods. The [Supreme Cookie Set](https://supremevalues.com/mm2/sets) also lists them as **two items**. Do not change the inferred `godly:660` checker mapping to Gingermint based only on the internal-key spelling, and do not treat the raw key as independently attested.

Other source links are recorded per entry in the machine-readable ledger. As of the review, the main [Supreme Godly](https://supremevalues.com/mm2/godlies), [Chroma](https://supremevalues.com/mm2/chromas.php) and [Ancient](https://supremevalues.com/mm2/ancients) listings provided current **public display identity and event origin** but do not publish a trusted server-certified `Sync.Weapons.rawKey → numeric checkerId` mapping. MM2 Wiki weapon pages corroborate names, Godly/Ancient/Chroma class, knife/gun type, public event and year. This is **cross-source identity corroboration, not official checker-ID verification**. No trading economic values are imported into this ledger.

## Schema and fail-closed gates

Structured source: [`STAGE58_CROSSWALK_REVIEW_ONLY_LEDGER.json`](./STAGE58_CROSSWALK_REVIEW_ONLY_LEDGER.json).

A reviewer may only claim:
- Display name, rarity/class, knife/gun type and public event origin were corroborated from two independent websites **at the time of review**.
- Local client year agrees where directly present (5 rows). For five records, the game source year was **missing**, and the external year is kept **separately** without silently backfilling the game metadata.
- Two chroma placeholder artworks and the unusual `Gingermint_K` to Cookiecane naming remain explicitly flagged, not "fixed" by heuristics.

A reviewer **may not** claim:
- A raw game key is authenticated by the community wiki or checker website.
- An old checker numeric ID, item copy/instance, marketplace price, demand, liquidity, or market value is independently verified by the client metadata.
- A user-owned item is present or a trade was accepted, settled, completed, profitable or authorized.
- An unknown field `sourceEventRaw="1"` is a year or a verified seasonal event.

Validator: `scripts/validate_crosswalk_review.py` rejects authority promotion, missing/duplicated candidates, changed checker/display fields without native provenance, unsafe source URLs, source-year backfill, missing event/placeholder/legacy-name flags, item ID instance claims, source domain mismatch, and accidental price/profit/inventory fields. Offline tests use **600 deterministic adversarial mutations**, plus named edge and regression checks; GitHub Actions runs them alongside the existing merged intelligence tests. The validator does **not** fetch external websites live; the review is explicitly dated/versioned and must be redone if metadata or sources change.

## Next engineering issue after this bounded identity review

Do not run another fuzzy-score census. Work on **transaction settlement evidence** separately from item display identity: reconstruct actual trade session binding, both accept states, offer-state stability, post-close inventory changes and authoritative result receipts where available. All failures/unknowns must remain `UNKNOWN`, not implied wins. No live automatic final Accept, no profit assertions, and no old +15 rule. Existing safe Stage52 `main` updater remains research-only and unchanged.
