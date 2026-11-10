# Stage91 REAL iPad request-pending checkpoint (Nov 9, 2026 ET)

**Actual, not mocked:** User sent `[GINGERSCOPE STAGE91 SINGLE REQUEST]` with `status=CLIENT_PENDING_OBSERVED`, `reason=NOT_SERVER_AUTHENTICATED`, `cardLayout=ALTERNATIVE_EMBEDDED_CARD`, `requestTapCount=1`, `clientPendingExactTargetObserved=true`, `exactTargetClientBound=true`, `visibleCardExactNameMatched=true`, `ownContactEvidenceReady=true`, `tradeWindowObserved=false`, `elapsedSeconds=12`; **all scripted offers/Accepts/Declines/Teleports zero**. `serverAttestation=false`, `serverCompletionProven=false`, `authorizesTrade=false`, `authorizesAccept=false`, `tradeOutcome=UNKNOWN`, price and Discord/learning unverified. This is a PASS for the **narrow native single Trade-button tap and client pending-UI proof**; it is NOT evidence of alt receipt or actual trade-open/settlement. **Do not repeat Stage89–91 solely to reprove request UI**.

**Next single milestone:** read-only exact trade-partner identity after consenting alt manually accepts an explicitly sent single request. Code must not auto-accept/offer, retry uncertain requests, auto-decline or hop. [Issue #122 evidence](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/issues/122#issuecomment-6756031306).

---

# Latest Gingerscope checkpoint — Stage91 request-only diagnostic

Date: November 9, 2026 Eastern. This short file supplements the historical `GINGERSCOPE_ACTIVE_HANDOFF.md` and `GINGERSCOPE_READ_FIRST_NEXT_CONVERSATION.md`. Read the latest stage-specific handoff, open PRs and Issue #122 as well before editing anything. **Do not revert to older Stage89/90 instructions or superseded +15 trade rules.**

## Real native evidence

- Stage88 original MM2 main iPad/Delta contact-only preview succeeded: nine locally reachable, two without eligible, zero actions; source prices are still unverified.
- Stage89 exact-target request diagnostic **did not click**: `EXACT_TARGET_CARD_NOT_OPENED`, zero request taps. Wrong hard-coded direct-popup assumption.
- Stage90 original MM2 main iPad/Delta read-only test **passed**: `CARD_LAYOUT_OBSERVED`, `ALTERNATIVE_CARD_CONTAINS_EXACT_USERNAME`, one visible Profile/Trade card, one Trade control, exact username inside card and near button, no direct popup. 13 samples, elapsed 2 seconds, zero requests/offers/Accept/Decline/hop. Local 36.6s screen recording visually supports alternative blue Profile/Trade panel. Not hosted in repo.

## Stage91 implementation — still DRAFT

[PR161](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/161) is stacked on [PR159](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/159), preserving one request, no retry, exact target instance and contact-eligibility proof. The only new live-code function binds exactly one alternative Trade button to one nearby exact username and paired Profile button inside a bounded non-leaderboard card ancestor. Denies previous Stage89/90 active probe owners and all ambiguous GUI cases. The other relevant [Stage90 PR160](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/160) remains separate. None merged to main. No final Accept, offers, webhook, hop, market-profit claims or strategic learning authorized.

**Pinned Stage91 tested SHA:** `28858d1d0694f806376667e2107ad5997a988a39`. [Stage91 focused Actions 42733501149](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/actions/runs/42733501149) SUCCESS **16/16 Lua5.4 mock groups**, with 4 immutable source checks. All five baseline Luau/Lune/StyLua+Selene/replay/Hypothesis checks also passed on the exact SHA. This proves offline mocked code only, not native Delta physical request.

## Exactly one next action

Only after the user chooses to perform **one real request** to their consenting alt, run this pinned snippet **once** in a new original MM2 Tablet server on main iPad Delta, with that alt present and NO previous pdiddler scripts:

```lua
getgenv().PDIDDLER_STAGE91_TARGET_USERNAME = "venossgaming90190"
getgenv().PDIDDLER_STAGE91_ONE_REQUEST_ARMED = true
loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/28858d1d0694f806376667e2107ad5997a988a39/pdiddler/new_part4/STAGE91_ONE_EMBEDDED_CARD_REQUEST.lua"))()
```

Then close Delta, manually open the consenting alt's Profile/Trade card and keep it open through the scripted 20s card observation. Return ONE `[GINGERSCOPE STAGE91 SINGLE REQUEST]` JSON marker. `requestTapCount=0` means no attempt; `requestTapCount=1` means one physical input was attempted but server delivery is **NOT attested**, even if `CLIENT_PENDING_OBSERVED`. On `UNCERTAIN`, do not retry in the same server. No automatic item trading or Accept. See [PR161's detailed handoff](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/blob/integration/gingerscope-stage91-embedded-card-one-request/pdiddler/intelligence_lab/STAGE91_EMBEDDED_CARD_HANDOFF.md) and [Issue #122 latest comment](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/issues/122#issuecomment-6755970208).
