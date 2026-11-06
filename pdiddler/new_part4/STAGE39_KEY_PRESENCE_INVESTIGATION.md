# Stage39: Batwing raw Sync key exact primitive literal presence in one nearby UpdateTrade

**Experimental, read-only; NOT a server weapon identity/slot resolver.** Separate draft PR stacked on PR #77. The user's next real test will be screen recorded.

## Why this is necessary

Actual Stage37 empty-offer `UpdateTrade` and Stage38 manually added Batwing `UpdateTrade` had **identical structural counts**: 1 TABLE argument, 6 nested tables, 14 entries, depth4, two opaque USERDATA. Stage38 however showed **one** timestamp-near event, delivered **before** the GUI showed a Batwing in **our** offer; no completed trade or Accept. Shape tells us nothing about actual primitive values.

## Narrow experiment

Inspect one local source: `ReplicatedStorage.Database.Sync` (already used by Stage36) and find exactly one `Sync.Weapons` or distinct `Sync.Item` row with `ItemName == "Batwing"` or `Name == "Batwing"`. Skip only physically identical table aliases. Reject ambiguous duplicates, Chroma, malformed/colliding keys, invalid metadata, overly large catalogue, missing module. Construct a **private** table of known raw Sync keys, without logging any key.

Stage39 keeps the proven Stage38 read-only timing window and one event candidate. It requires both offers initially empty, only **our** side gain exactly one stable slot and physical slot 1 label precisely `Batwing`, no Chroma tag and Amount empty (one copy). No other-side addition and no Accept. Recheck GUI after `Sync` read before attaching listener.

At each bounded incoming `UpdateTrade` event, `p4_stage39_literal_key_presence.lua` checks *only raw same-type equality* between the unique Batwing Sync **catalogue key** and primitive **table values/map keys**. It also counts matches for other catalogue weapon keys as negative controls. It walks at most 8 incoming arguments, 4 table depths, 32 distinct tables, 128 entries and 4096 bytes per scalar string; no userdata indexing, decompilation, remote sends or event injections. Unknown userdata is counted as opaque; this leaves the legacy shape report `INCOMPLETE` but can permit a complete **primitive-only** equality scan, clearly marked `PRIMITIVE_LITERAL_COUNTS_UNBOUND`. No uninspected opaque object semantics are inferred. The callback retains **only bounded sanitized shape/count summaries**, never the raw payload.

Only after exactly **one** receipt in a ±1.5 second local GUI addition window, output a nested sanitized `literalPresence` report with candidate string/number key equality counts and matches to other catalogue keys. A positive count is a **literal candidate**, not proof an item payload field identifies a slot. A zero count means no equality among traversed primitives in this bounded event; it does not rule out userdata, encoded IDs, other events or real source mapping.

All old safety gates and `rawItemIdConfirmed`, `rawKeyPresentConfirmed`, `ownerSideSlotBound`, `eventSessionAssociationProven`, `serverCompletionProven`, `authorizesTrade`, `authorizesAccept`, `mayReportProfit` remain **false** even when candidate matches. No game-mutating API, automatic offer, trade, Accept, webhook or hop. Prior PRs remain unchanged/draft. No server transaction claim.

## Required test

Use a fresh MM2 server and run only the immutable Stage39 launcher before opening a manual trade. Record the iPad screen from before the script starts through the final JSON, ideally including the trade window and readable Delta console (do not expose webhook secrets). Open a trade with **both offers empty**, wait for `LISTENING_UPDATE_TRADE`, then manually place **exactly one Batwing in your own offer**, never Accept. Let the script finish; manually decline the trade. Send both the anonymized JSON and screen recording. If a test ends early, do not blindly repeat it: inspect exact stop reason first.

## Why the output remains incomplete evidence

Even a same-type key match can be incidental: a payload might contain the *entire inventory*, a saved key map, the display label when identical to the raw key, or another player's unrelated weapon. Stage39 intentionally cannot prove actor/side/slot/server session. The next mechanism—if justified—must find which payload field actually refers to the offered weapon from grounded causal contrasts or game source; it must not simply label a coincident key as identity.

## Verification

The pure core and actual native mock launcher are covered by new Lua regressions; CI must pass on the final head before an iPad test is issued. No live Stage39 output exists at creation. Earlier Stage38 on-device JSON and the exact next-boundary checkpoint are logged in PR77.
