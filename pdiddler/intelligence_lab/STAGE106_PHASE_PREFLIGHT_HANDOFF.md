# Stage106 — two-sided UpdateTrade phase preflight (pure Lua, research-only)

## Why this is a new boundary and NOT a repeat of prior stages

- Stage97 native confirmed exactly one ALT-side client UpdateTrade callback correlated with ONE GUI offer; server session/causal attribution not proven.
- Stage100 and Stage103 native confirmed stable TWO-sided Part4 GUI and on-screen-safe instructions; callback raw keys for both physical slots were NOT proven.
- Stage101 raw-game-key/GUI-slot candidate matcher already exists in DRAFT PR171 and stack-fixed DRAFT PR176. Do NOT recreate.
- Stage106 Copilot [Issue177](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/issues/177) and [WIP PR178](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/178) own the **future native iPad GUI+listener wrapper**. This standalone PR183 is a NEW **pure preflight stage** to validate the event timing and both-sided phase sequence before allowing the original Stage101 matcher to report even a client-only match.

## Exact read-only input sequence

1. Two original Stage9 GUI captures with BOTH sides EMPTY, separated >=0.15s.
2. ALT manually adds exactly ONE test weapon. Two stable original GUI captures show ALT 1 slot and MAIN empty, >=0.15s apart.
3. The native event listener must arm AFTER the stable ALT-only baseline. Exactly ONE subsequent local `ReplicatedStorage.Trade.UpdateTrade.OnClientEvent` packet is captured. **A late old ALT callback still cannot be attributed**; the complete current actor-relative two-sided packet must independently match all current GUI slots.
4. MAIN manually adds exactly ONE expendable Ancient/Godly weapon, **never protected Gingerscope**. ALT offer must remain unchanged. Two >=0.15s-apart original Stage9 captures show exact 1 MAIN slot and 1 ALT slot, with exact frozen client Player/root/session/job references.
5. Call immutable stack-fixed Stage101 `M.inspect` using ALT-only `before`, one callback, and both stable AFTER frames, with current Sync.Weapons metadata and the original Stage83 public historical registry.
6. Return only a sanitized aggregate `CLIENT_TWO_SIDED_RAW_KEY_GUI_CANDIDATES_UNATTRIBUTED`, or `INCONCLUSIVE`, with all trade/Accept/market/profit/Discord/server-completion authority **FALSE**. **Never return Stage101's private candidate raw keys**, print full packet, use those candidates for offer placement or infer a server-authenticated trade session.

Pure Lua module: `pdiddler/intelligence_lab/stage106_two_sided_phase_preflight.lua`. It is NOT a native iPad script: no Roblox globals, no GUI, no remotes, no clicks, no hooks, no network.

## Test and provenance plan

Dedicated `.github/workflows/gingerscope-stage106-phase-preflight.yml` downloads and Git-blob checks immutable, original:
- Stage9 `p4_observer_contract.lua` from `1971b93d324f0275e6a9affb472ac3e804439ed8`, blob `7c84456006bd684dacb0217d0ae092d6d67575a4`;
- Stage83 `stage83_public_slug_registry.lua` from `25b48b60fdb2f971bbb6b2a2020f3c7c4432f7ae`, blob `40e2a0ff01b70b2d0181c62cae347a08da82bcb8`;
- Stack-fixed Stage101 `stage101_multiweapon_raw_key_match.lua` from `29889595b5e80c788ade75fbb97880b736fc8cb2`, blob `c15afe8077d544534e0f122ce2f4a5081cb2ac90`.

Tests execute actual Lua5.4 via Python: 12 named groups plus 360 deliberate adverse phase mutations, including swapped Player1/2, x5 stacked one slot, protected own Gingerscope, delayed ALT callback, duplicate/missing callback, listener armed too early, wrong partner/root/job, accepted flags, GUI-after mutation, ALT changing, and stale clocks. Static check forbids all live-action and authority paths. No new Stage97/99/100/103 manual test is justified for this *pure* preflight.

## Critical known limits

This is a client **candidate** consistency test, not a proof that the callback belongs to this trade. Neither protected item type, current price, account ownership, market liquidity, raw unique weapon instance, server revision, final settlement, nor automatic Accept becomes verified by success.

The corrections in DRAFT PR176/179/180/181/182 are not merged or deployed. Old Stage99/100/103 SHA-pinned scripts still use old Stage98 (and Stage103 old Stage102) code. Stage106 pure preflight needs the corrected PR176 matcher, but not Stage98/102/105 market modules. The future native wrapper must keep the purple/black, non-overlapping, numbered on-screen instructions, be tested on original Roblox mock interfaces and must never call game actions.

**Completion condition**: all six inherited workflows and the focused original-Lua Stage106 workflow pass on EXACT final source/README SHA, then code review of the native wrapper, then at most ONE genuinely new consenting ALT+MAIN iPad probe. No auto trade/accept at any point.
