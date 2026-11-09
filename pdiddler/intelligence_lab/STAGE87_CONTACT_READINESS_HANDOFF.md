# Stage87 — Separate P3 request-contact eligibility from untrusted prices

**Scope:** Only the real Stage51 P3 feasibility module and its real outgoing evidence controller. No Part4 permit, offer placement, final Accept, server hop, scanner source, or Discord modification.

## Actual root cause

Existing `P3_ELIGIBILITY_NO_LEGACY_PROFIT.lua` is named request eligibility but its original `validateInventory/evaluate` path insists on numeric-string `checkerId`, positive prices, `unpriced=0`, `profile.isFresh()` and `strict.reprice()`. The existing `pdiddler3_outgoing_eligibility_v2_SCANNER_EVIDENCE.lua` independently repeats `profile.isFresh()` as a global request hold. Stage83 native MAIN client established 69/69 eligible local weapon types / 76 copies have historical public game key ↔ website slug references, but those are **NOT** independently authenticated numeric checker IDs or current prices. Thus the unpriced constraint improperly prevents **request-only prospecting**, even where the scanner sees eligible weapons; removing just one gate would not fix the controller.

## Change made

Copied the TWO actual reviewed source files to a CLEAN branch based on main (because original Stage51 PR90 is stacked on another unmerged branch). Changes:
- **Preserve** old `validateInventory/evaluate` code *byte-for-byte* as a priced compatibility path (not execution authority).
- Add `validateContactInventory`/ `evaluateContact`: strictly typed string `id`, exact unique weapon IDs, correct Ancient/Godly/Chroma knife/gun pages, positive integral copies, dense array, scanner fingerprint, **zero `unmapped` and `badQty`**. Positive `unpriced` counts are allowed; values, names, numeric site-local `checkerId`, price freshness, demand, liquidity are **not** consulted. Empty opponent becomes non-requestable; ambiguous inventory remains `unknown`.
- Update the **actual outgoing evidence controller** to call these new methods in both own inventory refresh and opponent `assess()`; delete its stale-price contact hold while retaining current session/job/GUI/active-transaction global context lock, in-flight read invalidation, scanner's complete whitelist/blacklist requirement, retry/scanning hold, own-proof age (<10s) and own/opponent fingerprints. Contact authorization tokens explicitly `contactOnly=true,authorizesTrade=false,authorizesAccept=false` and revalidate before physical request. Still no trade/offer or final Accept permission.
- Existing user-facing outgoing state remains `reachable` for the preserved Part3 rotation API; `reason=CLIENT_ELIGIBLE_FOR_CONVERSATION_ONLY` and witness deny market/settlement authority. **No guarantee opponent will accept a trade request.**
- Refuse contradicting scanner state: whitelist with zero eligible types or blacklist with nonempty eligible types => `unknown`. Own profile and opponent verification must be same-session/current; no hardcoded +15 price floor.

## Tests and boundaries

Dedicated `.github/workflows/gingerscope-stage87-contact-reachability.yml` installs Lua5.4, syntax-checks both ACTUAL modules and test harness, runs **17 named behavioural groups + 400 mutated inventory cases**. It also downloads SHA-pinned ORIGINAL Stage51 P3 and the unchanged ORIGINAL Part4 `p4_strategy_permit.lua`, checks old priced implementation is byte-identical, and checks no Roblox trade/Accept/webhook calls were added to contact path. Baseline five project workflows must also pass on the exact branch head.

## IMPORTANT remaining preview-loader dependencies

This PR does **NOT** yet turn on runtime requests. The existing separate unmerged `REPLACEMENT_INTEGRATION_PREVIEW.lua` has its own pinned **OLD** P3/outgoing modules, a **startup `assert(I.profile.isFresh())`**, a later `PRICE_HOLD` shutdown in its monitor, `I.scanner.isWhitelisted` gated on `I.profile.isFresh()`, and `getRecord` / `getOwnInventory` override via `I.strict.reprice`. Those must be reviewed separately before this implementation can reach iPad. Blindly replacing the loader pins will do NOTHING useful while these other price-dependent paths remain and may be dangerous. The scanner itself may still be source-gated; see exact original source for any additional `profile` guards.

**Next ONE issue after offline green:** change only the replacement preview's *contact/read-only* boot and scanner contact view while preserving Part4 economic-price gate, controller ownership checks, no automatic offers/final Accept. Test that no fresh quote leads to a global `PRICE_HOLD` **only for priced trading**, not for basic scanner/requests; do not bypass session/GUI/unknown-player safeguards. That is separate from Stage87. No iPad test for Stage87 alone.

## Non-authority

Even a `reachable` result means only locally observed client eligibility for starting a conversation, NOT authenticated user inventory, market price, executable offer, counterparty willingness, game-server settlement, profit, Discord strategy learning or automatic final acceptance. Stage85 replay session-collision patch and Stage86 Python planner→guard offline integration remain separately DRAFT/UNMERGED. Do not repeat Stage79/80/83 or old ALT transfers; price research Stage84 expires independently.

