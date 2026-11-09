# Stage67 — real Stage66 raw-receipt report audit and Discord learner boundary

## Real 2026 Stage66 result

The MAIN iPad provided one real `[GINGERSCOPE STAGE66 SAME WINDOW]` report:

- One stable client MM2 trade GUI, callback `AcceptTrade(false)` at **+12.0s** inside the GUI, then `AcceptTrade(true, one received-item table)` at **+14.2s** immediately around the GUI close. Two samples, zero unbound or discarded callbacks, listener disconnected.
- Actual current game callback row type layout **string / number / string** and received row count **1**.
- Native in-memory, privacy-safe Stage65 comparator returned **PRIVATE_RAW_PRIMITIVE_EQUALITY_CLIENT_ONLY**: row[1] string is literally equal to the sole raw `Weapons.Owned` key that increased by 1 in the same MAIN scanner baseline and both consistent post-close full raw weapon maps. Names and item identifiers were **never exported**. Stage29's separately reported eligible copy count was also **+1 gained, 0 lost**, one changed eligible type.
- Report status `CLIENT_RAW_RECEIPT_EQUALS_OWN_GAIN_UNATTRIBUTED`, `privateRawKeyEqualityObserved=true`, coreTerminal true, sameBoundWindowClientOnly true.
- All settlement, server ID, causal event-to-trade proof, exact weapon instance/semantic identity, automatic Accept, realized profit, completed/rejected Discord learning **false**, `tradeOutcome=UNKNOWN`.

[Native result recorded in PR118](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/118#issuecomment-6731722842). This is an **important advance** over Stage63's checker-ID-based count change. It confirms a current 2026 client-side exact string match between the callback receipt and full raw owned inventory. It is NOT cryptographically server-authenticated proof of an atomic transaction and cannot verify the partner's inventory or the single offer revision. The operator has **not separately confirmed a Claim Weapon prompt on this particular Stage66 attempt**. The user's prior affirmative manual confirmation was for the **distinct Stage63** trade. Do not conflate them or silently transfer Stage63 operator testimony.

## Stage66 memory-lifetime security fix after native result

The Stage66 source audited after the native report held all three raw `Weapons.Owned` snapshots in `E[KEY]` (shared `getgenv()`) beyond the report's finish. Although the output never contained these keys and there is NO evidence of exfiltration, the old result's raw keys could remain accessible to other executor scripts until the Roblox session ends.

Stage66 **DRAFT PR118** source was updated for future use with an idempotent `releasePrivateRawSnapshots()` core hook and wrapper logic that calls it on every finished/error path and sets the private callback row to nil. If cleanup fails, the client-positive status becomes `INCOMPLETE`. This is a **future code fix**, not retroactively run by the user's older SHA-pinned test. New source pin and CI are in [PR118 audit](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/118). The current user can simply leave/rejoin their original MM2 session if they want those prior executor-shared raw keys cleared.

## Stage67 offline evidence gate

`scripts/stage67_native_raw_receipt_learning_gate.py` validates the EXACT reported Stage66 JSON shape with type-strict checks: report schema/status, every authority flag false, exact normal client callback sequence and phase, reasonable finite time gap, triplet field types, private equality evidence flag, one preowned and two post-close readbacks, +1/-0 eligible and stable partner label. Extra source fields, changed keys, stale/malformed callbacks, duplicate reports, session merges with Stage59/Stage61/Stage63 or caller-asserted "verified" claims fail closed.

Successful output is **CLIENT_RAW_CALLBACK_AND_GAIN_MATCH_UNATTRIBUTED** with confidence tier **CLIENT_RAW_PRIMITIVE_CORROBORATION** — not a completed trade journal row. All trade, profit, server-authenticity, negative-trade reason, Discord learning and auto Accept permissions are **always false**. It does not serialize source item/player identifiers or make any network calls. Synthetic tests replay the actual native-shape values plus 1,000 adversarial mutations. No user action needed for this offline stage.

## Separating evidence from learning

The owner explicitly wants Discord to become a learner for both **completed and rejected trades** to improve trade efficiency, not just notify successes. That requires distinct sources and labels:

- **Client success-like evidence** (Stage66): allowed in an isolated, non-training research/audit pool with provenance, never an authoritative production completion webhook. If manually confirmed on the same transaction, track operator testimony separately; do not conflate with game-server attestation.
- **Operator-/partner-caused rejection vs own decline vs timeout vs UI failure vs offer modification:** do not infer from `DeclineTrade` event name alone. Stage31 observed same event label for both actors. All rejection types must retain their true reason and the offer revision at decision time; do not label a timeout "unpopular item".
- **Test ALT and self-trades:** explicitly excluded from behavior/value/demand learning even if technically successful and logged as tests.
- **Economics:** Supreme prices in the screenshot expired/unavailable; never interpret an old value or a client-side offer display as verified profit, market price or demand. Missing current values are `UNVERIFIED`.
- **Private data:** the separate private `chazebanks/MM2-Trade-Research-Private` repo retains only a minimized historical Discord webhook archive, currently unverified. Keep historical raw Discord IDs, receipts, partner metadata, and bot secrets OUT of public GitHub. The public Stage67 tests are synthetic, no real private archive exported.
- A future learner can study **reviewed, correctly attributed outcomes** and interaction features for acceptance tendencies, success rates and retradability, while keeping raw prices/IDs out of automatic trust elevation. Do not impose the old mandatory +15 rule or a rigid opener.

**Next one offline issue:** define and test a **rejection actor/evidence taxonomy** and replay-safe per-offer-revision learning intake; native actor identity and final settlement are unresolved. No next transfer is required simply to repeat the known raw-key result. Don't request user intervention until a specific, tested new device diagnostic needs it.
