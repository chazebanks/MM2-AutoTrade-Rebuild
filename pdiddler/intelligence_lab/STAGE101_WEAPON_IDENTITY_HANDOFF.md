# Stage101 — Close the actual missing raw game-weapon key ↔ multi-slot GUI identification interface

## Why the user redirected the work

After actual Stage99 iPad native PASS (`CLIENT_MULTI_SLOT_ADD_REMOVE_EPOCH_OBSERVED`, 100 Stage9 GUI frames, 0→1→2→1 ALT offer, 4 local visual revisions, 2 research-preview revocations), user asked: **"Ok but what about indentifying the wepon"**. This is the right priority correction. Stage99 knows WHERE/HOW MANY GUI slots changed, but **not the raw game key for each slot**. A visually nice plan cannot safely price, assess desirability, or rebalance without raw-key identification. Do not present one more GUI-only epoch test as progress on identity.

Existing native proofs, already completed:
- Stage50 controlled MAIN own-side Batwing `Sync.Weapons` raw game key `Scythe` ↔ local Owned ↔ actor-relative UpdateTrade add/remove client claim.
- Stage83 69/69 eligible currently owned weapon types and 76/76 copies to historical public (name, category, rarity, Chroma) references, without verified numeric Supreme checker IDs.
- Stage97 exactly ONE ALT-side UpdateTrade `[rawKey, quantity, "Weapons"]` client tuple and one physical GUI name/quantity/Chroma match, `clientNameOnlyUnbound=true`.
- Stage99 multiple ALT-side GUI slots/changes, but no raw event listener.

Stage96 only handled ONE opponent raw weapon row while MAIN offer empty. Stage95 correctly refused to guess missing GUI raw keys from their display names. Stage100 began a two-sided visual-epoch branch but is **NOT** a weapon identity solution and should stay unverified/not advised for device execution while this identity question is in focus.

## Stage101 first correct implementation — PURE, no MM2/Delta gameplay

`pdiddler/intelligence_lab/stage101_multiweapon_raw_key_match.lua` is a self-contained, client-only **full two-sided** reconciliation over already observed interfaces:
1. ONE actor-relative `ReplicatedStorage.Trade.UpdateTrade` snapshot with exact Lua `Player` instance objects (`Player1` can be MAIN or ALT), exact one callback packet root/shape, `Locked=false`, both Accepted=false and up to four `[rawGameKey,quantity,"Weapons"]` rows per side.
2. Original unchanged Stage9 raw GUI `our.slots` and `their.slots`, with exact current client-local root/session/job/Player refs and bounded before/one callback/stable after1+after2 samples, each side 0–4 slots, with each stacked quantity independently parsed by original Stage9 `parseQuantity` (positive integer at most 1,000,000 in the original parser) for blank=1, x2=2, x5=5, Chroma and optional GUI raw text. This number is a **defensive parser bound**, not a claimed verified in-game maximum stack.
3. Same-session LOCAL `ReplicatedStorage.Database.Sync.Weapons` game metadata and exact original Stage83 **archival 189-entry public raw key→display-name/type/rarity/Chroma correspondence**. Reject if any client metadata disagrees; do not use historical numeric Supreme checker IDs or assume current publisher values.
4. Match the COMPLETE client raw offer to COMPLETE GUI slots by a bounded (4! or fewer) bipartite assignment on side, visible display name, Chroma variant and explicit quantity; an existing GUI `rawId` also must match. Any partial/unknown event key, slot/multiset mismatch, conflicting partner/session/Accept, variant/stack mismatch or unstable after GUI ⇒ INCONCLUSIVE.
5. **Ambiguous identity handling:** if two DIFFERENT raw game keys could occupy one GUI slot, reject even when a complete matching exists. Two identical raw keys in two identical slots may still yield a UNIQUE *per-slot raw weapon type*, but NOT unique item instances; `uniqueWeaponInstanceProven=false`.
6. Return (a) **privacy-safe aggregate report** with no raw keys/names/ids, and only on a unique client-side match (b) a **PRIVATE in-memory candidate binding** with each slot's raw game key and quantity. Binding is explicitly `clientOnly=true`, `validForAutomatedTrade=false`, `validForAutomatedAccept=false`, `rawKeyServerAuthenticated=false`; caller must NEVER print it or hand it to a live trade executor.

**Critical limits:** GUI often has no raw ID; the callback raw key may have been delivered late from another trade. No server-signed transaction nonce, no independent item/ownership/settlement proof. The matcher is a **client consistency / candidate** mechanism; it cannot promote `eventSessionAssociationProven` or `rawItemIdConfirmed` or `authorizesTrade/Accept` to true. The Stage83 public registry is archival and current source prices are expired; price/demand/liquidity is a separate gate. A branch that can resolve a raw game key is NOT equivalent to an authenticated current Supreme numeric checker ID (Stage70 still unverified).

## PR176 — stack count is NOT physical slot count (2026-11-10)

New audit found Stage101's initial pure matcher incorrectly limited each per-slot quantity and total copies to four, despite original Stage9 quantity parser accepting stacked quantities and MM2's 4-**unique-slot** limit. Regression-first draft [PR176](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/176) is stacked on unmerged PR171. Its test-only commit `334c65d07b81408280b0ca71f5a594ea17893c87` produced a confirmed **RED** original Lua5.4 test failure on one Batwing `x5`: `GUI_SLOT_STACK_QUANTITY_UNVERIFIED` (focused Actions [42775975212](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42775975212)). Existing Stage9 parser and Stage83 registry Git blobs were verified before the failing behavior. The code correction changes only quantity bounds to the original Stage9 range and retains `dense(...,4)` per-side slot cap. Separate negative tests retain rejection of five distinct physical slots and quantities beyond the original parser's maximum. This correction is **client-only**, no native evidence or trade authority.

## Test plan

- Dedicated GitHub Actions verifies original immutable Stage9 `p4_observer_contract.lua` blob `7c84456006bd684dacb0217d0ae092d6d67575a4` and original Stage83 189-entry `stage83_public_slug_registry.lua` blob `40e2a0ff01b70b2d0181c62cae347a08da82bcb8`.
- Actual Lua5.4 two-sided/stacked/Chroma/Batwing raw `Scythe` and full offer matching using those original modules, strict swapped Player1/2, identical duplicate key slots, fabricated second key with identical visible name marked AMBIGUOUS unless both GUI raw IDs independently distinguish, unknown key, changed accepted/job/root, stale callback/unstable GUI, misshapen/partial item rows, copy limits and 500 deterministic adversarial cases.
- Python unittest launches the real Lua corpus and checks no game input, no market/trading/Discord permission in code. Five inherited CI workflows must also pass at the exact final commit.
- This task is pure/offline; **NO new iPad test yet**. Only after offline verification consider one combined *read-only* native Stage101 follow-up that samples BOTH a current two-sided `UpdateTrade` event offer and stable GUI. That native test should establish the candidate matcher can handle two-sided data; not repeat single own Batwing (Stage50), one partner item (Stage97) or GUI-only 0→1→2→1 (Stage99).

The strategic goal remains accumulating desirable, liquid weapons to acquire Gingerscope. Obsolete mandatory +15 profit threshold does not return. Do not enable final automatic Accept or Discord claimed settlement without separate rigorous evidence.
