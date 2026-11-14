# System2 — November 13 independent publisher page parity (research only)

## What actually happened
The user submitted the complete `gingerscope_supreme_189_values.json` browser calculator export (SHA-256 `bb91b545637a0fe8d7dcceebef9070ee9a76210015bdc1737fd78f068acaeb4f`, immutable 189 numeric weapon rows; see prior `FULL_189_VALUE_EXPORT_AUDIT_2026_11_13.md`).

**Independent current public-source research (November 13, 2026 Eastern):**
- Four first-party pages `https://supremevalues.com/`, `/mm2/ancients`, `/mm2/godlies`, `/mm2/chromas` and `/mm2/calculator` consistently displayed **"Values Last Updated - November 13th, 2026 at 1:20 PM"** (Eastern time; `2026-11-13T18:20:00Z`).
- First-party homepage November 13 changelog listed concrete values **matching** the browser export (e.g., Traveler's Axe 6800 [6700–6800]; Vampire's Axe 1350 [1300–1350], Underpaid For; Chroma Alienbeam 18500; Chroma Beachy 900; Snowcannon 800, demand 6).
- Separate **live Firecrawl rawHtml GETs** to three canonical categories returned `statusCode=200` and expected `sourceURL` for each.
- Original website `div.itemcolumn` / `data-image` / `data-value` / `data-demand` / `data-stability` / `b.itemrange` were compared **across all 189 operator-captured weapon records**. Result **189/189 identical** image identities, value, demand, stability, and range; zero missing and zero mismatches. Direct observed breakdown Ancient 15, Godly 128, Chroma 46.
- Site contained one special Ancient nonnumeric `Nik's Scythe`, two Godly special site entries `mm2godlies/Batwing` and `mm2godlies/Black_Luger` absent from the numeric historical registry, plus seven Chroma Fire pets. The calculator catalog had a third special `Mortal Blade` which the rendered numeric Godly cards did not expose. None is automatically admitted as an ordinary weapon.
- Quick **noncryptographic** normalized displayed-record checksums (FNV32): Ancients `e7acfd06`, Godlies `47fe3a57`, Chromas `01f2d0c9`. These are diagnostic fingerprints, **not raw HTML SHA-256 or trusted-source attestation**. The actual raw HTML bytes were not archived into the repository.

**Important distinction:** the independently observed site and calculator field parity materially corroborates the November 13 published edition. It does **not** prove historical MM2 raw game-key candidates are current server-verified item identities, nor does it independently prove operator inventory, settlement, or sustained price freshness. The user export's `publisherVersion:null` is unchanged; source-page metadata cannot retroactively mint trusted canonical Stage111 HTTPS/transport attestations.

## New code
- Add-only offline `pdiddler/system2/publisher_page_parity.py` compares a **SHA256-pinned** operator export and the **exact original Git blob pinned Stage83 registry** to three independently supplied raw HTML page files under exact canonical URL and status 200. Requires 189 exact identities, numeric values, demands, stability labels, range boundaries, consistent publisher update timestamps in America/New_York, and publisher version not later than first operator observation.
- No fuzzy mapping, estimated prices, fabricated liquidity or demand. Unknown/new weapons, missing/duplicate items, changed values, a later or inconsistent publication timestamp, incomplete pages or damaged source data **fail closed**.
- It computes SHA-256 of actual supplied page HTML bytes for **future** reproducible archived checks; it cannot establish transport authenticity itself. `RESEARCH_PARITY_CORROBORATED` is a descriptive **offline research** status only.
- 21 Python synthetic tests passed locally. Focused CI tests the parity gate plus all earlier 31 operator adapter and 16 catalog-diff tests against original Stage83 Git source recovered from its SHA-pinned commit; check exact PR-head Actions before claiming CI pass.

## Reproducible local invocation (raw publisher pages must first be saved separately)
```bash
python3 -m pdiddler.system2.publisher_page_parity \
  --export /private/gingerscope_supreme_189_values.json \
  --stage83-lua /private/original_stage83_pinned.lua \
  --ancients-html /private/ancients.html \
  --godlies-html /private/godlies.html \
  --chromas-html /private/chromas.html
```

## Absolute release boundaries
No production PR, no Part3/Part4/Delta runtime changes, no outbound Gingerscope, no automatic final Accept, no profit or webhook settlement claim, no learning. All market-live and trading authorities remain false. **Do not pretend that three self-supplied URL/status fields authenticate a network TLS origin.** True live source admission still requires the separately reviewed original Stage111→110→104→69 provenance and a bounded refresh/expiry policy, independent game key proof and observed actual liquidity. For System2 development, build a separate *read-only* market lookup/research preview using the pinned snapshot, never call it a live quote or bypass Stage121.
