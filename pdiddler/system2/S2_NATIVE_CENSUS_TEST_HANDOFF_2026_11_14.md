# REAL MAIN iPad read-only two-census test — CLIENT PASS (Nov 13/14, 2026)

The operator returned one sanitized `gingerscope-system2-native-own-census-v1` JSON receipt from the immutable native loader. `status=CLIENT_TWO_READS_STABLE`, `reason=LOCAL_CENSUS_EQUALITY_ONLY_NO_SERVER_PROOF`, `readAttempts=2`, `clientCensusChanged=false`, observation gap within the programmed 2–60 second window, and both distinct-key and total-copy aggregates matched across the two reads. The pasted 31-field report was checked for consistent field types, matching counts, denied authority flags and zero script offers/accepts/declines/teleports. **No inventory counts, raw IDs, game JobId or other private runtime values are reproduced in this PUBLIC repo.** Source evidence is user-provided client-only, not independently server-authenticated; do not treat a pasted receipt as cryptographically genuine. No server settlement, game-instance identity, price, official market edition or revision source proven. Hardware task CLOSED: **do not ask to rerun this same two-census test.**

Next distinct task: native catalog/metadata coverage and raw-key identity-confidence measurement, with privacy-safe aggregates and no invented market valuation, followed independently by genuine fresh publisher source verification. The old 189 catalog is NOT the user's total weapons census. No P3/P4/Delta changes, source secrets, automatic offers, Accept or profit claims.

---

# System2 native own-census witness — isolated MAIN-only iPad test candidate

**Date:** Nov 13/14, 2026 (NYC). **Draft PR #266** https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/266, stacked on unmerged System2 PR #265. **Not merged, not an active production feature.** This is the next distinct System2 evidence test, NOT a repetition of closed original Stage119 two-event ALT offer or Stage101 identity tests.

## What this proves (and does not prove)

The new native witness independently exercises an actual *client-origin* **own inventory read-only RPC** (`ReplicatedStorage.Remotes.Inventory.GetProfileData:InvokeServer()`) with exactly two **manual MAIN taps**, in the same original-MM2 job, 2–60 monotonic seconds apart. It validates a strictly bounded own `Weapons.Owned` census, counts raw keys and copies including formerly excluded/unpriced weapon types, and compares exact sorted raw-key/quantity pairs **locally**. It never copies, uploads or prints item names/raw IDs, JobId, player identifiers, actual inventory or server profile. A local equality/difference is not independently authenticated server ownership; no trusted offer revision, market edition, item instance, asset transfer or completed trade is proven.

A Lua-only, noncryptographic **local** checksum is supplemented by exact sorted pair comparison; it is not an identity, cryptographic digest or authentication token and must never be promoted to price/trading authority. This cannot yet feed the untrusted P3 scanner envelope or PR265 source/market gate as *verified native trading data*. It is evidence to decide whether a bounded native own-census source is even available.

**Authority stays denied:** no P3/P4/Delta production changes, no offer/request/Decline/Accept/teleport, no chat, auto trading, market price refresh, profit, Discord or learning. Protected Gingerscope never outbound.

## Exact files and pinned source

- `pdiddler/system2/native_own_census_core.lua`: immutable runtime file Git commit **`8e0d3312404e8a1557545e81df351b7c55633451`**, blob **`b39f10fd47c6a2df6a206142b8b4c7b3dd39f3cf`**.
- `pdiddler/system2/SYSTEM2_OWN_CENSUS_READONLY_NATIVE.lua`: immutable user-facing runtime file Git commit **`e72fa4df21fe6f8a2c4da83087097be708ccbcc0`**, blob **`069579ded6fe4f34630ce8abbc7d07d6e70b81ab`**.
- Runner itself SHA pins its core by immutable Git commit and the original Stage100 safe geometry at `5b8ee35d7f281c23d9c2181abd97a063e59a0660`.
- `pdiddler/ci/system2_native_own_census_mocks.luau`: executes REAL runner in a mocked Roblox UI, read-only remote, clock and inventory, with new oversized-zero-count cap regression.
- `.github/workflows/gingerscope-system2-native-own-census.yml`: proves both source exact pinned blob hashes **and checkout equality**, continuity `verify`/`recover`, actual Lune native mock, source-level denial of trade remotes, and the **311 inherited original pinned Stage83/PR106/PR182 Python regressions**. **Before a real device run, independently verify this exact final documentation HEAD CI, including all six general workflows.**

## One NEW user-visible, read-only hardware test (only once CI is green)

User: MAIN iPad Delta, ORIGINAL MM2 place, fresh job. **No ALT is required.** Make sure no trade window and no other pdiddler script or auto trader is active. The exact immutable test command is:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/e72fa4df21fe6f8a2c4da83087097be708ccbcc0/pdiddler/system2/SYSTEM2_OWN_CENSUS_READONLY_NATIVE.lua"))()
```

The purple/black panel appears safely outside any trade controls; if safe on-screen placement is unavailable, it fails closed. Step 1: MAIN taps **CAPTURE 1**, triggers one read-only own-profile RPC. Step 2: once at least two seconds passed, MAIN taps **CAPTURE 2**. Do NOT trade, accept, change servers or run additional scripts during the two reads. The result is `CLIENT_TWO_READS_STABLE` if the local raw-key/quantity census matched, `CLIENT_TWO_READS_DIFFERENT` if it changed, or `BLOCKED`/STOP if something failed; no status means server-authenticated ownership. After completion tap **COPY / CLOSE** and paste the **sanitized** clipboard JSON; if copy fails, the same sanitized JSON is printed to the console and saved as `getgenv().PDIDDLER_S2_CENSUS_LAST_JSON` (still do not paste raw profile payload). Do not rerun in the same JobId.

**Never press final Accept or open a trade; this test requires no ALT.** The panel instruction is the source of truth. Any request failure/inventory service missing, unexpected trade UI or loss of safe screen position stops; do not bypass the protection.

## What happens after the one hardware test

Check the actual sanitized return values, compare to the current source contract and independently identify missing metadata/catalog correspondence. A passing local two-read result would prove only that the client RPC and UI workflow operate. System2 would still need a separately authenticated fresh publication source (original Stage111→110→104→69), actual P3 offer-state revision witness and independent server settlement authority before any live strategy or final Accept.

**Do not confuse PR #266's Lune mock with actual device evidence.** User hardware test is pending until an actual user receipt is provided.
