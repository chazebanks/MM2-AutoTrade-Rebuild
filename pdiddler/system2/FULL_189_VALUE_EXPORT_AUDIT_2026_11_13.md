# System2: first completed 189-value operator capture — audit 2026-11-13

## Result
A user-uploaded complete `gingerscope_supreme_189_values.json` was parsed and independently checked, with 189 valid records and no duplicate category/image IDs. **Do not mistake the earlier 53-record incomplete browser run for this successful 189-record run.**

- Export schema: `gingerscope-supreme-189-offline-export-v1`
- Export size: 64,793 bytes
- **SHA-256:** `bb91b545637a0fe8d7dcceebef9070ee9a76210015bdc1737fd78f068acaeb4f`
- Catalog capture: `2026-11-13T23:24:06.802Z`
- First detail observed: `2026-11-13T23:54:11.648Z`
- Last detail observed: `2026-11-14T00:24:04.910Z`
- Export finished: `2026-11-14T00:28:09.127Z`
- 15 Ancients, 128 Godlies, 46 Chromas; **all 189 match (category,image) pairs** in immutable Stage83 Git blob `40e2a0ff01b70b2d0181c62cae347a08da82bcb8` at commit `25b48b60fdb2f971bbb6b2a2020f3c7c4432f7ae`.
- 0 missing, 0 unexpected, 0 duplicate website weapon image IDs; 0 invalid structural/numeric/range/timestamp values.
- Only two benign case-only website-label differences: `BattleAxe` -> `Battleaxe` and `BattleAxe II` -> `Battleaxe II`. **Never change MM2 raw game keys based on website labels alone.**
- **21** `previousDecimalValue:null` (legitimate missing prior value), **5** starred original `valueDisplay` fields, **20** non-point value ranges.
- Example protected acquisition target: `Gingerscope` decimal value 16000, demand 5/10, stability Stable, observed `2026-11-13T23:54:11.648Z`.
- `publisherVersion:null`, therefore the source update/version has **not** been authenticated. This is a complete operator-captured calculator snapshot, not authoritative proof of the live publisher edition.

## Data retention
The **full operator-provided JSON is in the user's ChatGPT conversation attachment**, identified by the SHA-256 above. It is deliberately **not committed into this public repository**. Do not fabricate a copy from 189 isolated screenshots or old snapshots: retrieve the exact user attachment or ask the operator to provide the original JSON for ingestion. Preserve original display strings, null previous values, range endpoints, timestamps, and source identity separately from the historical raw-game-key mapping.

## Gates
- This capture is **OFFLINE_REVIEW_ONLY** and has no offer, accept, trade, profit/Discord completion, or strategic-learning authority.
- Does not prove current MM2 client-owned raw item IDs or live inventory settlement.
- Does not change System1 supervised verified mechanics, Part3/P4 runtime, auto-final-accept status, or protected outgoing Gingerscope policy.
- Next **separate** issue: build and test a deterministic offline ingestion adapter with an immutable source-file hash and strict identity checks. Keep publisher version/authentication and future refresh as separate research gates.
