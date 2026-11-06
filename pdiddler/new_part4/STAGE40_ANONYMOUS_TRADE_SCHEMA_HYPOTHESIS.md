# Stage40 — anonymous trade-table candidate schema, NEVER authenticated

2026-11-06. **One narrow read-only candidate hypothesis**, stacked on historical draft PR78. No trading actions or production modifications.

## Verified native evidence
Actual iPad Stage39 Batwing manual offer and separate screen recording: one UpdateTrade event before the GUI displayed Batwing in the first **YOUR OFFER** slot; **THEIR OFFER** stayed empty; one exact primitive same-type match between a unique Batwing Database.Sync catalogue key and an element of a depth4 3-element array (two strings + a number). The primitive match was reported exactly once. This alone does not prove the key represented the actual offer entry; key text could equal visible Batwing label; no user identity field/schema captured.

## New independent but untrusted external research lead
A publicly posted **anonymous third-party MM2 Lua script**, [myCompiler "mm2"](https://www.mycompiler.io/view/4ySHMGgjq9h), defines a *locally manipulated* `TradeTable` shaped as:
```lua
{
  LastOffer = <number>,
  Locked = <boolean>,
  Player1 = {Player = <player object>, Accepted = <boolean>, Offer = {{ItemName,1,ItemType}}},
  Player2 = {Player = <player object>, Accepted = <boolean>, Offer = {}},
}
```
This concrete shape is **isomorphic** to the real Stage39 structural counts: root 4 string fields, 2 side maps of 3 fields each, 2 userdata values, 2 booleans, one empty nested Offer, one Offer array with a single triple, 6 total tables, 14 total entries. But its author/source/game version are **UNVERIFIED**; the script hooks/manipulates the interface and does NOT authenticate MM2's actual `UpdateTrade` transport. **Never execute or import that external script**, never describe the structure as official Roblox/MM2 schema.

## Stage40 test contract
Only for the ONE already timed, user-manual **our-side Batwing** offer, the existing Stage39 read-only diagnostic loads a new strictly pinned, pure Lua hypothesis inspector `p4_stage40_trade_schema_hypothesis.lua`. It privately checks:
- One packed argument, root exactly `LastOffer,Locked,Player1,Player2`, expected primitive types.
- Each player map exactly `Player,Accepted,Offer`, with accepted indicators false.
- Root `Player1.Player == LocalPlayer` **object identity**, root `Player2.Player == current manual trade partner` **object identity**, with NO names, IDs, properties or userdata exported.
- The `Player1.Offer` array has exactly 1 row of exactly 3 elements: `[1] == unique private Batwing Sync key`, `[2] == 1`, `[3] == "Weapons"`. `Player2.Offer` empty.
- `candidateKeyEqualsVisibleLabel` as a privacy-safe boolean to distinguish a raw key that is literally the displayed "Batwing" name.
- Any mismatch simply reports `HYPOTHESIS_NOT_MATCHED`, NOT a negative claim about the actual MM2 schema. A match reports `ANONYMOUS_LAYOUT_HYPOTHESIS_FITS_UNAUTHENTICATED` and fixed booleans only; **server session/slot/identity still unproven**.

No arbitrary payload values, names, player/account IDs, raw weapon keys, hashes or URLs exported. No outgoing events, no Add/Remove/Accept, no webhook, no game state writes. Strict pass/fail does not alter original Stage39 read-only code, source/GUI verification, one-event timing selection or authoritative flags; prior PR78 remains immutable. Source code of external third-party script is NOT executed.

Offline Lua pure and native launcher mock cases include correct local-side structure, reversed player references, wrong quantity/category, key==visible label, early unrelated event, two ambiguous events, metatables, packed event extra arguments and no server authority. **These are synthetic, not evidence the schema exists in real MM2.** Run targeted CI and inspect exact-head logs before ANY further iPad observation.

## Stop rule
Do not mark `rawKeyPresentConfirmed`, `ownerSideSlotBound`, `exactWeaponIdentityConfirmed`, `eventSessionAssociationProven`, `serverCompletionProven` true even if every candidate bool is true. Still need independent server-session/freshness and opponent-side validation before considering automatic trades.

Latest real Stage39 evidence and privacy boundary: [PR78 native checkpoint](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/78#issuecomment-6688851943).
