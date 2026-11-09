-- Stage72: ONE standalone scanner-only presentation experiment.
-- No auto trading, OfferItem, AcceptTrade, incoming-trade replies,
-- hopping, price authority, Discord or market learner.
-- The T4.4 scanner's existing GetProfileData read is reused; NO second
-- scanner, no extra profile reads, and no fallback to fuzzy reprice in UI.
local E=(getgenv and getgenv()) or _G
local KEY="PDIDDLER_STAGE72_CONFIDENCE_ONLY"
local JOB=game.JobId
if game.PlaceId~=142823291 then
 warn("[GINGERSCOPE STAGE72] WRONG_GAME; nothing loaded")
 return nil
end
local old=E[KEY]
if old~=nil then
 warn("[GINGERSCOPE STAGE72] already loaded or partial; REJOIN before retry")
 return old
end
for _,key in ipairs({
 "PDIDDLER_STAGE25_SCANNER_ONLY",
 "PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW",
 "PDIDDLER_INTEGRATION_V15_8_VALUE_FIRST",
 "PDIDDLER_INTEGRATION_V15_7_INVENTORY_GROWTH",
 "PDIDDLER_INTEGRATION_V15_6_IMMEDIATE_SAFETY",
 "PDIDDLER_PART4_CONTROLLER",
 "PDIDDLER_PART5_CONTROLLER",
 "PDIDDLER_OUTGOING_CONTROLLER",
 "PDIDDLER_OUTGOING_SESSION",
 "PDIDDLER_PART4_SESSION",
 "PDIDDLER_HOPPING_SESSION",
}) do
 if E[key]~=nil then
  warn("[GINGERSCOPE STAGE72] conflicting scanner/trader session; REJOIN")
  return nil
 end
end
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local OWN_PIN="cf8c55fff64ae3e702bf8dd01a76fbf44ac66b1a"
local PINS={
 profile={"snapshots/pdiddler_supreme_snapshot_2026_11_06.lua",
    "d9d7970f281f725ff21d1a409495fcc197e3d2dc"},
 strict={"new_part4/P4_REPRICE_ONLY.lua",
    "daf42166b9a713b69b0a8c93708ff13e86b36283"},
 scanner={"presentation/pdiddler3_scanner_MODULE_v6_10_CURRENT_PRESENTATION.lua",
    "001d228a407076d3cc411a5a7132b0076ec4c027"},
 proof={"intelligence_lab/stage70_raw_checker_proof_gate.lua",OWN_PIN},
 confidence={"presentation/stage71_inventory_price_confidence_view.lua",OWN_PIN},
 adapter={"presentation/stage72_scanner_confidence_adapter.lua",OWN_PIN}
}
local S={
 schema="gingerscope-stage72-scanner-confidence-only-v1",
 jobId=JOB,status="LOADING_READONLY_PRESENTATION",
 readOnly=true,tradeOutcome="UNKNOWN",
 sourceCurrent=false,
 authorizesTrade=false,authorizesAccept=false,
 mayReportProfit=false,mayUseForStrategyLearning=false,
 maySendDiscordWebhook=false,
 noOutgoing=true,noHopping=true,noTradeInteraction=true
}
E[KEY]=S
local function source(name,...)
 local pair=PINS[name]
 assert(type(pair)=="table","unknown scanner-only dependency")
 local url=ROOT..pair[2].."/pdiddler/"..pair[1]
 local text=game:HttpGet(url,true)
 assert(type(text)=="string" and #text>40,
   "read-only dependency missing: "..name)
 local fn,why=loadstring(text,"=gingerscope-stage72-"..name)
 assert(fn,why)
 local module=fn(...)
 assert(type(module)=="table","read-only dependency invalid: "..name)
 return module
end
local ok,why=pcall(function()
 local profile=source("profile")
 assert(type(profile.isFresh)=="function"
   and type(profile.coverage)=="function"
   and profile.coverage().total==190,"immutable old profile shape invalid")
 S.sourceCurrent=profile.isFresh()==true
 local legacyStrict=source("strict")
 local proof=source("proof")
 local confidence=source("confidence")
 local adapter=source("adapter")
 assert(type(proof.evaluate)=="function"
   and type(confidence.describe)=="function"
   and type(adapter.new)=="function","read-only proof chain unavailable")
 local view,whyView=adapter.new(proof,confidence)
 assert(type(view)=="table" and type(view.inventory)=="function"
   and type(view.row)=="function" and type(view.summary)=="function",
   whyView or "read-only UI adapter invalid")
 -- The legacy strict repricer is passed only to satisfy the old scanner API.
 -- The NEW adapter deliberately never calls strict.reprice and never draws
 -- the scanner's old heuristic numeric values, even if its profile is fresh.
 assert(type(legacyStrict.reprice)=="function")
 local scanner=source("scanner",profile,legacyStrict,view)
 assert(type(scanner.getRecord)=="function"
   and type(scanner.getVerificationState)=="function",
   "scanner-only record API unavailable")
 S.scanner=scanner
 S.status="READONLY_SCANNER_CONFIDENCE_DISPLAY"
end)
if not ok then
 S.status="PARTIAL_INITIALIZATION_REJOIN_REQUIRED"
 S.reason="READONLY_DEPENDENCY_FAILURE"
 warn("[GINGERSCOPE STAGE72] source/presentation failed; REJOIN; no trading")
 return S
end
print("[GINGERSCOPE STAGE72] Inventory observation separate from price proof"
 .." | old Supreme source freshness="..tostring(S.sourceCurrent)
 .." | Outgoing PAUSED | Auto Accept DISABLED | Discord learner DISABLED")
return S
