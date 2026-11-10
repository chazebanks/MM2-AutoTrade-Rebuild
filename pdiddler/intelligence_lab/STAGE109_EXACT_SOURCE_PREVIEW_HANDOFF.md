# Stage109 — exact original public-source value reference for client raw-key candidates (research only)

## Purpose and the correct trust boundary

Earlier Stage70 treated raw MM2 key→legacy *numeric Supreme checker ID* as a required crosswalk and deliberately left its reviewed table EMPTY because the old Stage54 collector used **164 fuzzy / 19 alias / 7 internal** resolutions. The numeric IDs are **website-local**, not game raw keys. Stage108 then established **189/189 historical PUBLIC raw game references** matched exactly one first-party Supreme 2026-11-09 source `(category, casefold(name), Chroma)` record, without numeric checker IDs. Stage106 original iPad tested **1+1 CLIENT-ONLY** physical offer raw-key candidate agreement, not a current authenticated item instance/server trade or price.

This Stage109 code is a *NEW PURE RESEARCH PREVIEW*: it accepts hypothetical/client-only raw game keys + stacked quantities + same-client `Sync.Weapons` metadata, then performs a **direct, strict name+category+Chroma** lookup against the real original published Supreme HTML. It can compute **ILLUSTRATIVE HISTORICAL** source subtotals from publicly reported numbers while **NEVER** granting strategy, trading, final acceptance, settled trade, price-for-trade, Discord or profit authority. No Roblox executable, game remotes, inventory enumeration, player identity export, networking or real item transfer. User's long-term protected Gingerscope cannot be offered outbound even in a research candidate.

## Exact immutable public research sources

- Stage83 registry Git blob `40e2a0ff01b70b2d0181c62cae347a08da82bcb8` from `25b48b60fdb2f971bbb6b2a2020f3c7c4432f7ae`, 189 public-key/name/category/variant entries.
- Original Stage69 Supreme HTML parser Git blob `d5843a57f34078cbe7213aa78a4aa12a5775c016` from `af4fee60ab9db45f9f018bc0fc691f025e2fbd5f`. Stage109 hashes the actual parser source bytes BEFORE executing it; no caller-injected `parse_page` function may replace it.
- Original Stage84 full Nov9 2026 Supreme Ancients/Godlies/Chromas HTML Git blobs `ce8178ab9579e8782d8f72a6dac051756a728506`, `d3cf222a8e10cff3a9fb051b16188192389c4b2d`, `6c77624cac3df96168b008e9bc8eca68a2d78cf9`. Category counts 16+128+46=190, site publisher `2026-11-09T18:58:33Z`.
- The historical capture expiry is FIXED at `2026-11-10T22:26:48Z`, not reissued on each request/fetch. A requested pre-expiry timestamp cannot override the genuine wall-clock after expiry. After expiry **NO numeric totals**, requiring independently reviewed newly published sources. These Nov9 values are not a guarantee of actual trades, liquidity or future prices.

## Functional boundaries (no identity promotion)

`pdiddler/intelligence_lab/stage109_exact_source_price_preview.py`:
- Requires ALL five immutable original Git blobs in input; executes only the hash-verified original Stage69 parser; independently checks the Stage108 all-189 strict name/category/variant coverage.
- Validates 1–4 physical slots per side, stacked quantities 1..1,000,000 **per slot** (the original Stage9 parser DEFENSIVE maximum, NOT an MM2-enforced quantity claim). Duplicate raw keys across distinct slots, unknown keys, invalid quantities or total overflow fail closed.
- Compares client metadata `ItemName/ItemType/Rarity/Chroma` exactly against public historical key metadata. Normal non-Chroma items may omit the false Chroma field, matching original Stage101. Other original game metadata such as `ItemID` may be present and are IGNORED, including any caller `checkerId`/`verified` flags (never trust them as proof). No fuzzy aliases, Chroma/base mixing, punctuation substitutes or arbitrary unreviewed IDs.
- Returns **sanitized aggregate totals and counts ONLY**, no raw game keys, site checker IDs, unique item instance IDs, owner account identities or individual item pricing records. Positive means `PUBLIC_SOURCE_INDICATIVE_TOTALS_CLIENT_UNATTRIBUTED`; all current-game/server/price-for-trade/trading/profit/Discord/learning flags always FALSE, `tradeOutcome=UNKNOWN`.
- Outgoing raw game key `Gingerscope` always rejects, even hypothetically. Receiving it is allowed for illustrative research.
- No production loader and no new iPad test. Stage102/103 already did GUI NAME-ONLY archived public value display; Stage109 instead proves the strict **RAW GAME KEY+SAME-CLIENT METADATA→SOURCE NAME** numeric research join offline, which is different. Do NOT rerun Stage102/103/106 to prove it again.

### Tested examples with pinned Nov9 official sources

- Synthetic raw game key `Scythe` (public Batwing 42), quantity x5 in ONE physical slot, vs incoming `Gingerscope` (public Nov9 16,000) in ONE: illustrative 210 offered / 16,000 received / +15,790 difference. **Do NOT treat this as a real quote, fair trade, recommendation or liquidity evidence.**
- `Scythe` x3 + `Emberbow` x4 (two physical slots / seven copies), hypothetical listed 3×42 + 4×650 = 2726 from Nov9 source. No four-copy artificial limit.
- `Immortal` base vs Chroma Immortal resolve to distinct Chroma/category public source items, without relying on old checker numeric IDs.
- Source expired, malformed/altered original blob, unknown raw key, mismatch to local Sync metadata, protected outgoing Gingerscope, duplicate physical slot key, quantity overflow, 5th physical slot—all return `INCONCLUSIVE` and NO numerical subtotals.

## Test-first provenance and CI

[DRAFT PR187](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/187), stacked on independently green Stage108 [PR186](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/186). Initial test-only RED commit `1599dff9fe6401dc2140d29b21736ffe192c94a6` correctly hash-verified five original public source Git blobs and failed module import because production source was not written yet; [Actions #42789646391](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42789646391). First source implementation `d43ba2976689af3c760a42da0954a335b74fa3a2` passed 11 real original-source unit groups plus 250 seeded negative scenarios and all 6 inherited/focused CI workflows. Additional independent red regression `907e69b8e761932b4b4d12ed35246d3d1bac9c1e` caught two bugs: (1) over-restricting Sync metadata to exactly four fields rejects authentic extra game asset/display fields, (2) caller could set a prior observation date and revive expired historical numbers; [RED run #42790161134](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42790161134). Source subsequently fixed to ignore unrelated metadata while rigorously matching the four identity fields and require wall clock + caller observation to be below original expiry. Tests patch the wall clock only for deterministic SOURCE replay; production `_wall_epoch` uses actual process time.

**Final exact SHA / Actions must be reviewed after this document is committed**. This is DRAFT and cannot merge any unapproved prior Stage70/71/102/103/108 branches blindly, nor enable trading, Accept, user-facing 'verified current price' or realized portfolio profit.

## Next missing evidence

To show even a real client-read-only *indicative* portfolio figure, a future native diagnostic would have to feed genuinely observed local `Sync.Weapons` and *current owned* keys into the reviewed research gate, with strict privacy and onscreen UI, and only while publication/capture is inside its fixed validity window. That would still not certify server inventory, transfer outcome, signed trade-session attribution or marketplace transaction liquidity. As of this document **no such Stage109 native test has been conducted or requested**; Stage80/83 owned source-key coverage and Stage106 offered-slot candidate match are already complete and must NOT be repeated. If the source expires before integration, choose a new reviewed first-party capture instead of rewinding its date.
