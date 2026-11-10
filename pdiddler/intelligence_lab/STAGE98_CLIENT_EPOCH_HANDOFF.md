# Stage98 — Client GUI revision token and immutable guard invalidation (research-only)

## Native foundation already established

**User's actual original MM2 iPad Stage97 PASS (Nov 9, 2026 ET):** `CLIENT_PARTNER_EVENT_GUI_NAME_QTY_CONSISTENT_UNATTRIBUTED`, exactly one partner-side `UpdateTrade` receipt, correct visible trade partner, original Stage9 observer bound, 11 frames, one ALT item add, matched name and quantity, own offer unchanged, zero script input. Stage95/96 previously established original Stage9 physical slot/name/quantity interface and strict callback↔GUI comparison. Stage43–50 own raw-key Batwing (`Scythe`) and Stage83 69/69 eligible types /76 copies also previously passed native, and must **not** be repeated.

**Unresolved:** a client callback has no authenticated server trade nonce; actual physical GUI `rawId` absent (`clientNameOnlyUnbound=true`). Even a good callback does not independently prove server settlement, item instance identity, actual offer eligibility or price.

## Distinct engineering gap / root cause

The existing independently reviewed [PR105 four-slot snapshot guard](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/105) knows how to reject changed offered items, quantities, offer revisions, publisher timestamps and stale apparent profits — but its `offerRevision` and exact observation binding are **synthetic supplied values**, not derived from the actual Stage9 GUI samples. [Stage86 planner→guard](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/156) is deliberately synthetic and MUST NOT be fed live-account data or historical Stage94 prices for execution.

This Stage98 experiment supplies a small **client-local observed GUI revision counter**, not a game-server version:
- Accepts only snapshots with the SAME original client-local player references, GUI trade root, JobId, local observation session, explicit contextOK, both complete sides, acceptance flags false, max four visible slots **and conservatively four total copies per side**.
- Reuses the **ACTUAL unchanged Stage9 `parseQuantity`** for blank=1, x2=2 / ×2=2 and validates slot order, duplicate indices, labels, chroma and optional raw text; labels and raw strings remain PRIVATE inside the module, never exported.
- Requires an initially empty client trade. Any GUI add, removal, visible quantity change, position shift, chroma or optional raw GUI text change **increments a local epoch and revokes prior preview tokens**. Exactly equal subsequent samples at least 150 ms apart are marked stable RESEARCH-ONLY, never server-evidenced.
- A callback note (not privileged and not a session-authenticated remote) instantly invalidates prior preview and marks `pendingClientCallback`; if a matching GUI change does not follow within 3s, observation is terminal INCONCLUSIVE. Even if one follows, the output retains `callbackCausalityProven=false` and `eventSessionAssociationProven=false`.
- `freezePreview` produces an opaque **RESEARCH-ONLY** local token after two stable captures with at least one item and no pending callback; `checkPreview` revokes tokens on an epoch or local client-session change, missing stability, callback uncertainty or >2s observation age. It NEVER yields authority to send offers, Accept, report profit or conclude a trade.

## Actual previously reviewed code tested

Focused GitHub Actions retrieves **two unchanged Git-blob pinned original modules**: Stage9 `p4_observer_contract.lua` `7c84456006bd684dacb0217d0ae092d6d67575a4` and PR105 `offer_snapshot_guard.lua` `c5b87f159de5224d231b111da2541b8b23ac6284`. Real Lua5.4 test suite and Python runner exercise:
- empty initial baseline; add, remove, extra slots, sorted indices, changed stack/Chroma, altered physical raw text, changed partner/root/job and acceptance flags;
- duplicate/stale/unattributed callbacks, pending timeouts and late replay;
- 700 adversarial mutations;
- one ACTUAL original PR105 guard research fixture where positive synthetic +5 is revoked when the opponent removes its weapon and the local offer revision changes; original guard must return `REJECTED`, not stale positive research gain.

All five inherited Luau/Lune/Selene+StyLua/sanitized replay/Hypothesis workflows need exact-head green as well. The independent synthetic guard is NOT reimplemented; the experiment is the missing client observation → local revision handoff. It does not establish true server revision number, real price/independently verified exact checker ID, accepted settlement, strategy authority or item action.

## Future implementation boundary

Remain a DRAFT research branch; no automatic trading, no production `pdiddler/loader.lua`, no executable iPad script. A future opt-in, manual final Accept or autonomous trade policy would require separate review of real current market quote, exact raw item/account holdings, player consent, own offer click/withdrawal and revision invalidation, server completion proof, realistic item desirability/liquidity, and actual in-game code paths. The user's overarching goal remains acquiring Gingerscope through a compounding, upgrade/downgrade and liquidity-aware strategy; old blanket +15 rule is obsolete.

No new iPad test is needed for this offline-only Stage98. When ready, code should be integrated into a strictly read-only version of the actual Part4 observer for multi-slot and removal observations, then separately native-tested only for that *new* behavior (not Stage97 one-off callback reproof). Keep PRs #165–167 and #164 unmerged without independent review.
