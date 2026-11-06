# Stage42 — Read-only incoming UpdateTrade player orientation

## Native Stage41 evidence driving this check

On November 6, 2026 the real iPad Stage41 diagnostic for one manual, no-Accept Batwing offer reported:
- Raw Batwing `Database.Sync` key is `STRING`, differs from visible `Batwing` label, found **once** as a primitive depth4 string in one locally nearby `UpdateTrade` event.
- Exact known root keys `Locked,LastOffer,Player1,Player2` and root types were **verified TRUE**. Both player-side maps' three-field keysets `Player,Accepted,Offer` were **verified TRUE**.
- First failed check `PLAYER_OBJECT_MISMATCH`; `rawequal(Player1.Player,LocalPlayer)==false` AND `rawequal(Player2.Player,boundPartner)==false`. Both *opposite* comparisons were **NOT TESTED**.
- Our GUI gained exactly one Batwing in first offer, their GUI offer empty, one event arrived before render; read-only finished, 12/12 listeners disconnected. The two depth2 USERDATA values were never otherwise dereferenced. No video was attached to the Stage41 result.

This supports one narrow competing possibility: **the two player-side maps may be in the reverse order**. Another possibility is that neither value is the expected Player object (a different userdata reference, stale identity, or nonmatching encoding). The failed original check **does not prove** that reverse orientation exists.

## One experimental rule

New `p4_stage42_player_orientation.lua` is a pure, bounded **read-only** inspector for a packed one-argument table with exactly the native-confirmed root and player-side fieldsets. It compares, privately using Lua `rawequal`, precisely four identities:

- `Player1.Player` vs the current `Players.LocalPlayer`.
- `Player1.Player` vs the trade-window-verified partner.
- `Player2.Player` vs the local player.
- `Player2.Player` vs the partner.

Only **unique complementary pairs** are reported as `LOCAL_FIRST` or `LOCAL_SECOND`. A single partial/duplicate reference yields `PARTIAL_OR_DUPLICATE`; no exact matches yields `NO_EXACT_PAIR`; schema/context errors remain `UNTESTED`. Each field's coarse `type()` is reported as a fixed TYPE enum only. No names, user IDs, raw references, strings, values, hashes, URLs, or other payload fields are exported. Only private object-reference comparisons; no `Player` properties or methods are accessed.

Even a complementary pair is **only locally observed event-player ordering**, not proof the trade server authenticated the payload for this session, nor proof which side's `Offer` contains Batwing, nor individual item instance or completed transaction. All raw-key/side/slot/session/Accept/trade/completion/profit authorizations stay FALSE. We deliberately **do not parse Offer or move to settlement** in this stage.

The new module is invoked only inside the previous Stage41 passive one-Batwing/no-accept/one-unique-nearby-UpdateTrade launcher, which remains bounded to an initially empty manual trade, verified live partner, and listener cleanup. Previous Stage41 pure core, Stage40 guessed strict schema and Stage39 key presence remain immutable and unchanged; their output remains included for comparison. Source pin `9fcd2ae45d8ae3ee2c5292d794097703df24206d`.

## Verification and next use

New pure tests must cover both orientation orders; unrelated/duplicate/partial identities; key in opposite offer with no authority; string/numeric/non-Player field values; missing context; table metatables and extra keys. Native test cases must exercise the **real launcher** using synthetic remotes and show no type/identity leak, no outbounds, stable local GUI correlation, and no selected mapping on ambiguous receipts/cancellation.

Run targeted GitHub Actions and inspect logs **before** offering one Delta loader. If passed, perform one screen-recorded manual no-transfer test: fresh server and Tablet, run exact commit pinned loader, open empty trade, wait `[STAGE42] LISTENING_UPDATE_TRADE`, manually add exactly ONE Batwing to YOUR offer, never Accept, copy `[GINGERSCOPE STAGE42 PLAYER ORIENTATION]` JSON, manually decline when done. Return the JSON/video for next analysis. If `LOCAL_SECOND`, the reverse is locally supported; if `NO_EXACT_PAIR`, do not retry blindly—investigate reference semantics. Do not claim a complete trading/ID/slot solution regardless of result.

Previous evidence: [Stage41 genuine native checkpoint](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/80#issuecomment-6690990706).
