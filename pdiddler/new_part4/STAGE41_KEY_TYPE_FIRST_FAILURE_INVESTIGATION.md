# Stage 41 — Numeric raw-key compatibility and first-failure disclosure

**Purpose:** Diagnose exactly why the prior Stage40 *untrusted* named-table hypothesis returned `HYPOTHESIS_NOT_MATCHED` during a genuine manual Batwing offer. Stage40 produced a single false result for its whole hypothesis, but many downstream fields were default `false` and might never have been checked.

## Verified root-cause candidate, not yet confirmed on device

The same raw `Database.Sync` Batwing key is passed to two pure modules. Stage39 accepts private Sync keys that are `STRING` or finite `NUMBER` and found one exact same-type literal match at depth4. Stage40 **only accepts string raw keys** at its very first input guard. A numeric Batwing key therefore produces `HYPOTHESIS_NOT_MATCHED` and misleading default false booleans even when subsequent table/actor/offer structure might otherwise fit. Whether the real Batwing key is numeric is unknown from previous anonymized outputs; the event triple has two strings and one number, but their values/positions were never observed. Guessed `LastOffer`/`Locked` field names are another possible mismatch.

**Do not claim Stage40 `candidateKeyEqualsVisibleLabel=false` proves inequality**; on any early return before the equality statement that field was untested.

## Exact narrowly scoped intervention

New pure `p4_stage41_key_type_first_failure.lua` is invoked inside the existing **passive, read-only**, one-manual-Batwing, one-nearby-`UpdateTrade` observer on this separate branch (prior PR79 is unchanged). It:
- Reports `candidateKeyType` as one of `STRING|NUMBER|UNSUPPORTED` without ever exporting raw key strings or numeric values. It never coerces numeric IDs to strings.
- Reports `candidateKeyEqualsVisibleLabel` as `TRUE|FALSE|UNTESTED`, clearly distinguishing a measured comparison from an early default.
- Reports a single `firstFailedStage` fixed enum, with every downstream predicate `UNTESTED` until the relevant check has actually executed. Tests top-level argument pack; key; visible label; live player/partner context; the *unverified* legacy exact top-level fieldset; root value types; Player1/Player2 fieldsets; identity object equality; accepted flags; offer list shapes; three-element row structure; row literal contents.
- Allows finite numeric keys to proceed through the *hypothesis*, and if it reaches the candidate three-element row, reports exact same-type key position `1|2|3`, `0` if absent or not tested. More than one matching position is explicitly ambiguous.
- Emits fixed booleans/strings/numbers only. Uses `rawget`, `next`, bounded keyset sizes and `rawequal` on opaque player references without inspecting or stringifying their properties. No arbitrary raw values, field names, accounts, IDs, asset references, hashes, external endpoints, or secrets are emitted.
- Keeps every ID, side, slot, session, server completion, trade, Accept, profit, webhook authority **false** regardless of output. A perfect match still means **hypothesis fits untrusted client payload**, not a verified server identity.

Stage39 primitive key presence, original Stage40 strict parser, Stage9 local observer/partner binding and timing, ambiguity controls, 12-listener cleanup, and no outgoing RemoteEvent calls are all preserved. A first failure at `ROOT_FIELDSET_MISMATCH` does **not** imply the Player1/Player2 fields are absent; they were not inspected by this strict sequence. The independent 2024 third-party `UpdateTrade` listener supports testing Player1/Player2/Offer as a later, separate step if needed.

## Negative regression controls

Pure Lua covers both string and numeric keys; a numeric key in positions 1,2,3; a numeric key equal to quantity (ambiguous); root named-field mismatch; missing partner; metatables; malformed/extra packed args; first-failure ordering; unknown row layout; unexpected Accept; boolean tri-state; no raw data export. Native Delta mock covers numeric Sync key rejected by old Stage40 but permitted to pass corrected schema hypothesis, root mismatch leaving owner UNTESTED, numeric position3, no event, multiple events, and manual cancellation.

Run `Staged Part 4 Lua regression tests` against the exact new branch head, review actual logs and pin SHA before any iPad run. Older legacy workflows can remain red due baseline hashes; do not label repository-wide CI green.

**Next ONE live test only after reviewed CI:** start recording and join fresh MM2, choose Tablet, launch one pinned read-only Stage41 probe, open manual trade initially empty, wait for `[STAGE41] LISTENING_UPDATE_TRADE`, place one Batwing in **YOUR** offer, do not press Accept or transfer, copy anonymized `[GINGERSCOPE STAGE41 KEY TYPE FIRST FAILURE]` JSON, manually decline afterward, send JSON and optional recording. Stop and analyze first failure; do not reflexively repeat.

Context: [true Stage40 native JSON/recording + test bug](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/79#issuecomment-6689328361), [Stage41 source type mismatch](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/79#issuecomment-6689651493).
