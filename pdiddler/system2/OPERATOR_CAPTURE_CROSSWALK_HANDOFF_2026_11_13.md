# System2: immutable operator capture -> historical candidate-key adapter (Nov 13, 2026)

## What was actually finished
- New read-only adapter: `pdiddler/system2/operator_capture_adapter.py`.
- Original user-uploaded 189-row file: `gingerscope_supreme_189_values.json`, **SHA256 `bb91b545637a0fe8d7dcceebef9070ee9a76210015bdc1737fd78f068acaeb4f`**, 64,793 bytes, schema `gingerscope-supreme-189-offline-export-v1`.
- Strict original historical source reference: Stage83 commit `25b48b60fdb2f971bbb6b2a2020f3c7c4432f7ae`, Git blob `40e2a0ff01b70b2d0181c62cae347a08da82bcb8` at `pdiddler/intelligence_lab/stage83_public_slug_registry.lua`. Historical six-field rows are **candidate game keys**, never cryptographically proven current game identity.
- Exact identity coverage: 15 Ancient + 128 Godly + 46 Chroma = 189/189, 0 unknown or duplicate (category,image) keys. Two known case-only name drift records: `BattleAxe` / `BattleAxe II` vs published `Battleaxe` / `Battleaxe II`. Neither changes raw game keys.
- Per-record field integrity: 21 null previous values preserved, five starred publisher value displays, 20 ranged values, source labels, demand, stability, capture timestamps untouched. Gingerscope **incoming target** observed listed 16000, demand 5/10, Stable; protected against any outgoing offer.
- User's original JSON is preserved in conversation and locally; **never committed into public GitHub**. Locally generated `gingerscope_supreme_189_mapped_offline.json` contains all 189 historical raw-game-key candidates + original values; also not committed.
- Local adapter code and 31 synthetic regression tests: **30 passed, 1 source-archive integration test skipped locally**, because original immutable Lua was not automatically available in local container. Separate actual-file smoke used the earlier SHA256-pinned Stage83 compact six-field fixture `bbebfe87e602f1a5eb41a639a283a1f8238f44ecb3c111337d9f48d1811b37a5`, and the real uploaded export: **189/189 records processed**. The compact fixture is derived from, but not byte-identical to, original Stage83 Lua; do not call this an original Git blob runtime execution.
- GitHub CI fetches the ORIGINAL historical Stage83 commit and recomputes its exact Git blob SHA before running **all 31 operator tests** and the 16 earlier catalog-diff tests. Review exact workflow result at the PR head; do not infer green from local tests.

## To run the strict full-source CLI in an authorized local checkout
```sh
git fetch --no-tags --depth=1 origin 25b48b60fdb2f971bbb6b2a2020f3c7c4432f7ae
git show FETCH_HEAD:pdiddler/intelligence_lab/stage83_public_slug_registry.lua > /tmp/gingerscope-stage83-original.lua
python3 -m pdiddler.system2.operator_capture_adapter \
  --export /path/to/gingerscope_supreme_189_values.json \
  --stage83-lua /tmp/gingerscope-stage83-original.lua \
  --output /private/path/gingerscope_supreme_189_mapped_offline.json
```
The CLI requires the exact pinned export SHA256, exact original Stage83 Git blob, complete 189 rows and original no-authority flags. It refuses a changed file or additional/renamed weapons without explicit separate research.

## What is NOT proven
The browser capture has `publisherVersion:null`, so even a complete quote list does **not** prove publisher-version authenticity, scheduled refresh, current live value, current client MM2 raw item instance/ownership, user inventory, practical liquidity, server settlement or trade authorization.

All source-to-strategy, trade, final Accept, Discord-profit, verified learning, and unattended deployment flags are false. This is **not** a Stage120 trading bridge or an approval to merge into live Part3/P4. Never restore forced highest-value opener or mandatory +15; four physical slots and outgoing Gingerscope protection remain.

## Next distinct issue
Independent publisher-version/source authentication and refresh/expiry policy for these browser-captured values, using existing Stage121 source-to-strategy firewall and original provenance chain. Avoid re-running closed System1 tests or re-collecting the already complete 189-value snapshot without a new source revision.
