# System2 — read-only market research lookup and hypothetical Gingerscope gap (Nov 13)

## Functional offline capability (not the trading runtime)
This draft implements `pdiddler/system2/market_research_reader.py`, an actual research-mode consumer of the user's **complete 189-item** Supreme calculator export. It calls the existing `operator_capture_adapter.ingest` on the **exact SHA256-pinned original operator JSON** and **exact immutable Stage83 Git source**, then retrieves records by **exact historical raw game-key candidate**. It never accepts caller-submitted values, changes the Supreme data, or feeds stage120 as a verified market.

- Original operator source SHA256 `bb91b545637a0fe8d7dcceebef9070ee9a76210015bdc1737fd78f068acaeb4f`
- Original Stage83 Git blob SHA `40e2a0ff01b70b2d0181c62cae347a08da82bcb8`
- Extra prior independent page parity: 189/189 published values, range, demand, stability matched on three official category pages with visible publication **Nov 13 2026 1:20 PM Eastern**. See `PUBLISHER_PARITY_2026_11_13.md`, drafted separately in PR252.
- Source `publisherVersion:null` is not rewritten; source edition authentication for *live* trading remains false.

### Locally verified (real user-supplied 189-mapped research export)
- `Gingerscope` historical key candidate → **16,000**, demand **5**, stability **Stable**, `outgoingProtected=true`.
- `TravelerAxe` → Traveler's Axe, **6,800**, demand **5**, **Underpaid For**.
- `BattleAxe2` → Battleaxe II, **17**, demand **1**, Stable (historical key preserved exactly despite case-only publisher label).
- `EmberbowChroma` → Chroma Emberbow **6,000**, demand **6**, Fluctuating, range **5,750–6,250**. Chroma is a distinct exact game-key candidate from non-Chroma.
- `Immortal` → 125, demand 2, Fluctuating. No fabricated market data or adjustments.
- **Hypothetical** 2× Celestial + 3× Emberbow: listed total **5,850**, listed range **5,775–5,925**, gap to one listed Gingerscope **10,150**. This is **not a proposed MM2 offer** and may not fit a physical four-slot trade.

### CLI (no credentials or live calls)
```bash
python3 -m pdiddler.system2.market_research_reader \
  --export /private/gingerscope_supreme_189_values.json \
  --stage83-lua /private/original_stage83_pinned.lua \
  --raw-key TravelerAxe
# Or inspect a HYPOTHETICAL inventory:
python3 -m pdiddler.system2.market_research_reader \
  --export /private/gingerscope_supreme_189_values.json \
  --stage83-lua /private/original_stage83_pinned.lua \
  --inventory-json /private/research_inventory.json
```
Hypothetical inventory input example: `[{"rawGameKey":"Celestial","quantity":2},{"rawGameKey":"Emberbow","quantity":3}]`. Every key must be exact; unknown/fuzzy/duplicate IDs, Boolean or zero quantities, changed export SHA or spoofed authority fail closed. Counts represent portfolio quantities; the **four physical offer-slot** bound remains a distinct controller/planner gate, not a portfolio size cap. No source file or inventory is written to public repo.

### Evidence and boundaries
- **20 new focused Python tests passed locally**, plus **21 inherited publisher-parity tests**; source-addressed CI re-fetches original Stage83 Git SHA and runs a combined **88-test suite** (20 reader +21 parity+31 pinned adapter+16 catalog discovery). Verify exact-head Actions before claiming all green.
- `readOnly=true`, `verifiedMarketQuote=false`, `sourceEditionAuthenticated=false`, `authorizesTrade/Offer/Accept=false`, `serverCompletionProven=false`, `mayUseForStrategyLearning=false`, `maySendDiscordWebhook=false`. Portfolio input is hypothetical and never a verified live MM2 inventory.
- No executor, Delta, Part3/P4, actual offer, game settlement, Stage120 live feed, automatic final Accept or auto negotiation changes.
- Protect outgoing Gingerscope permanently. Do not revive mandatory +15 or forced highest opener. Demand 5/10 is *not* empirical trade acceptance probability.
- Price data ages, a new publication or unseen item requires discovery + fresh complete operator export + new reviewed source hash/version. Never silently refresh/mutate the pinned export.

## NEXT distinct issue
Read-only exact candidate-identity binding to a **fresh supervised MM2 client inventory snapshot** (not stale webhooks), with exact raw keys, variants, quantities, source revision, session lease and game-side provenance. Do not alter live offers or Accept while mapping/settlement gates remain UNKNOWN. In parallel, future pricing refresh can be planned but must not be claimed automatic from this local reader.
