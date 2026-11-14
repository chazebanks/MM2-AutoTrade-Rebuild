# System2 — original-byte-sealed source-to-decision research gate (Nov 13–14 2026)

## Why this was necessary
A previous source adapter `operator_capture_adapter.ingest` correctly checked SHA256 of the **original 189-record JSON** and exact Stage83 Git blob. But downstream Parts3/4/5 allowed **mutable in-memory mapped dictionaries** to be passed directly as input. `market_research_reader._index` checks the *declared* source file checksum string, but it was not tied to each downstream supplied mapping's fields. In particular, an unowned **incoming target's** price could be altered while retaining the original source SHA label and pass checks that only validated current owned-row subtotals. All live permissions still remained false, but research comparisons could be corrupted.

## Independent hashes derived from exact private operator files (NOT copied to public GitHub)
- Operator original user JSON: **64,793 bytes**, SHA256 `bb91b545637a0fe8d7dcceebef9070ee9a76210015bdc1737fd78f068acaeb4f`.
- Independently generated local `gingerscope_supreme_189_mapped_offline.json` contains exactly 189 full mapped rows, with pinned original Stage83 historical raw-key *candidates*.
- Canonical digest over **all 189 mapped row objects** in their original sorted output order, using Python `json.dumps(rows, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode('utf-8')`: **SHA256 `a33d2bace80b1375bd062cb634ee0dc0dff33962bac174814ce7a490dc184c16`**. This is an independently pinned fixed expected constant, not a new caller-supplied digest field.
- Original frozen Stage83 registry source Git blob SHA `40e2a0ff01b70b2d0181c62cae347a08da82bcb8` under `25b48b60fdb2f971bbb6b2a2020f3c7c4432f7ae`.

## New strict research entrypoint
- `pdiddler/system2/sealed_decision_source.py:inspect_sealed(export_bytes=..., stage83_lua_bytes=..., client_envelope=..., evaluated_at_utc=..., mode=..., payload=...)` has **NO** parameter for an arbitrary prevalidated mutable `mapped` dictionary or saved shadow output.
- Calls the exact existing immutable-source `ingest` **fresh at each request**, then hashes **every full mapped row** and compares to the fixed independently pinned digest, then builds a new read-only client inventory shadow from the supplied scanner envelope and as-of UTC. Only afterward calls existing S2.3 scenarios, S2.4 evidence comparison, or S2.5 multitrade replay.
- Input replay, fake market bytes, changed unused/incoming item price, demand/stability/timestamp, altered 189 row count/order, stale client census, false trade permissions, or unknown mode MUST fail closed. All results deny Offer/Trade/Accept/Discord profit/learning. Protected research decisions cannot become executor actions.
- A listed-value loss scenario now also returns a top-level **BLOCKED** decision instead of wrapping it in a successful sealed research result.
- **20 new synthetic+negative tests** using the original immutable adapter's separate source tests. Synthetic successful tests explicitly patch both the expected rows SHA and the pinned loader in a test-only scope; they are NOT claims of source attestation. Original adapter's real SHA and historical blob checks are re-run in inherited CI.

## Independent market research relevant to decisions
- First-party Supreme trade calculator (https://supremevalues.com/mm2/calculator) uses **value-weighted demand** and warns that one item's **five-or-more stack** worth >1 may not equal quantity×base listed value. PR #260 corrected both and had **230/230** research tests and 9/9 CI workflows green on exact previous head `13e7e4d5d38de8f2d88ef320a37c8545bf8eaab7`.
- First-party Supreme use guide (https://supremevalues.com/use) emphasizes demand, rarity, stability, ranges and extra **Flippability** features that are **not in the captured 189-price export**.
- MM2Index method (https://mm2index.com/methodology) explicitly derives observations from *public trade posts*, **not cryptographically verified MM2 server settlements**. Never use such post counts to produce invented completed-trade fill rates or real profit labels.

## THIS IS NOT LIVE CLIENT OR MARKET AUTHENTICATION
The new gate proves all data fields match the pinned **Nov13 research source bytes**, not that they are still up-to-date, independent completed trades, or server-certified game item instances. The scanner envelope and as-of clock are **caller-supplied**; accepted only as `UNVERIFIED_CALLER_SUPPLIED_CLIENT_SNAPSHOT`. Original `publisherVersion:null` remains research-only. This gate also doesn't autonomously generate counterpart-specific growth paths or authentic trade settlement. Original P3/P4/Delta and final Accept unchanged.

## Tests and next priority
New dedicated GitHub Actions `gingerscope-system2-sealed-source.yml` fetches immutable Stage83+PR106+corrected PR182 source bytes, runs **20 added tests + 230 inherited tests = 250** original-source-bound Python tests. Check exact-branch CI **before claiming passed**.

Next one distinct issue after source-gate tests: **test counterparty attractiveness/quality over time** and a bounded genuine path-generation optimizer with honest evidentiary ranks. Do not generate impossible one-sided profitable trades as if a real opponent would accept them. Then supervised source/client witnesses and genuine observed completed-trade learning; budgets for controlled loss remain unapproved.
