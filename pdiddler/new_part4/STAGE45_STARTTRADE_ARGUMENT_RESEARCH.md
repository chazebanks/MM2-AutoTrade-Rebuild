# Stage45 — Investigate native StartTrade argument types before claiming session attribution

## Prior native evidence (not to repeat)
- [Stage44 PR83 native result](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/83#issuecomment-6715064528): two distinct incoming UpdateTrade snapshots match manual Batwing ADD/REMOVE under same client root + partner, Player2 local. All server-session, causality, identity, settlement, trade/Accept/profit authority FALSE.
- [Stage33 PR72 native result](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/72#issuecomment-6678311257): ONE incoming StartTrade **before TradeGUI bind**, but Stage33 deliberately collected event NAMES only and did not inspect StartTrade callback arguments. It recorded later UpdateTrade and AcceptTrade callbacks, still no settlement receipt proof.
- Native UpdateTrade root observed: exactly LastOffer (number), Locked (boolean), Player1/Player2. This root does NOT have any observed named session token. Do not treat Player references, same GUI instance, event chronology or "LastOffer" as session identity.

## External constraints and independent assessment
- Official Roblox [RemoteEvent class docs](https://create.roblox.com/docs/reference/engine/classes/RemoteEvent) establish StartTrade/UpdateTrade callbacks are received from server-side fired RemoteEvents, and may be queued until a handler connects. No MM2 trade transaction ID is guaranteed.
- [Unofficial myCompiler MM2 script](https://www.mycompiler.io/view/4ySHMGgjq9h) assigns LastOffer=os.time() on offer changes. This is **untrusted client-side reconstruction/spoof code**, not evidence of actual MM2 server semantics. Consequently LastOffer is a plausible edit timestamp, **not** an authenticated nonce.
- A source-independent impossibility: if two trade sessions have the same player pair and same offer snapshot, and no fresh session identifier or authenticated server result is supplied, a delayed event from session A is observationally indistinguishable from an identical current event from session B. More GUI polls do NOT solve this.

## One falsifiable Stage45 question
A player reference or a scalar field is **not a session identifier** without evidence of uniqueness, freshness and server-provided association. Does **native StartTrade.OnClientEvent** supply structured callback arguments containing player references or any scalar candidate that might later help discriminate sessions? Stage33 did not record argument payloads, so this is genuinely new evidence rather than repetition.

NEW purely functional module `p4_stage45_start_trade_payload.lua` records ONLY a bounded list of primitive TYPE enums (up to six arguments), count of exact local/partner player object references and counts of unclassified string/number primitives. It does not inspect nested table contents, disclose raw names, keys, numbers, userdata, account IDs, session values, or declare any scalar a session token. Every authority field remains FALSE.

**GATE:** Do NOT ship an iPad loader from this pure helper alone. A native read-only launcher must connect to the single known StartTrade RemoteEvent **before any manual invitation**, bind exactly one later GUI/partner, select exactly one temporally nearby StartTrade callback, fail closed on zero/multiple/stale events, enforce clock/job/root/owner safety and listener cleanup, and report anonymized types only. It must never emit or call outgoing remotes, click GUI, read inventory or webhook, or touch production trading. Build real whole-launcher native mock tests and verify exact-head CI logs before providing a pin.

An observed scalar candidate would justify a *separate* test of **cross-session uniqueness and linkage to UpdateTrade**; it would not itself prove a server transaction ID. If StartTrade has zero relevant scalars, stop this line of inquiry. No new claim about auto trading, acceptance or profit is permitted.
