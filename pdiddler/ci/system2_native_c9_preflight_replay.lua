-- C9 real-original-source native preflight replay, executed through C8 mock.
-- Separate test chunk prevents large inherited test exceeding 200 locals.
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local luau=require("@lune/luau")
local M={}
function M.run(d)
 local base="pdiddler/system2/"
 local eq,ok=d.eq,d.ok
 local game,players,scope=d.game,d.players,d.scope
 local growthScanner,sync,market=d.growthScanner,d.sync,d.market
 local sourceEpoch,core,capture=d.sourceEpoch,d.core,d.capture
 local glue,resolver=d.glue,d.resolver
 local nativeBilateral,nativeBilateralBridge=d.nativeBilateral,d.nativeBilateralBridge
 local c9Source,c9RealOptions=d.c9Source,d.c9RealOptions
 local localPlayer,opponent,ours,theirs=d.localPlayer,d.opponent,d.ours,d.theirs
 local job,lease=d.job,d.lease
 local tick,now=d.tick,d.now
-- Component 9 original-source preflight. Uses ORIGINAL P3/P4-style
-- GUI reader, C3 scanner, C4 bilateral and C9 growth-first shadow modules.
-- Actual game APIs are mocked in Lune, never claim real iPad operation.
local preflightFactory=luau.load(fs.readFile(base..
 "native_c9_device_readonly_preflight.lua"))()
localPlayer.Parent=players
local preflightArgs={
 game=game,players=players,scope=scope,scannerApi=growthScanner,
 sync=sync,crosswalk=market,sourceRetrievedEpoch=sourceEpoch,
 nameResolver=resolver,isBoundSession=d.isBoundSession,
 utcNow=tick,monoNow=now,
 isoToEpoch=function(s)
  if s==market.sourceRetrievedUtc then return sourceEpoch end
  return nil
 end,
 marketCore=core,captureAdapter=capture,marketBridgeModule=glue,
 bilateralCore=nativeBilateral,
 bilateralBridgeModule=nativeBilateralBridge,
 growthFirstModule=c9Source,
}
local clientPreflight,preflightWhy=preflightFactory.new(preflightArgs)
ok(clientPreflight~=nil,"C9 P3/P4 original-source read-only preflight factory")
local onlyInventory=clientPreflight:run()
eq(onlyInventory.status,"C9_LOCAL_READONLY_INVENTORY_AND_GUI_OBSERVED",
 "C9 original P3/P4 scanner + GUI native snapshot, no trade requests")
eq(onlyInventory.actualDeviceExternallyVerified,false,
 "C9 Lune original source test never masquerades as real iPad")
eq(onlyInventory.authorizesTrade,false,"C9 preflight cannot initiate trade")
eq(onlyInventory.authorizesAccept,false,"C9 preflight cannot accept trade")
local nativePreview=clientPreflight:run(c9RealOptions)
eq(nativePreview.status,"C9_LOCAL_READONLY_STRATEGY_RESEARCH_OBSERVED",
 "C9 original P3/P4 C3 C4 strategy preview can read same bound session")
eq(nativePreview.reviewedOptionCount,2,
 "C9 native strategy compares two different visible trade alternatives")
eq(nativePreview.maySendDiscordWebhook,false,"C9 never reports fake profit")
eq(nativePreview.liveLossBudgetApproved,false,"C9 cannot approve negative trades")
eq(nativePreview.serverSettlementProven,false,
 "C9 native GUI research is NOT server settlement")
local exported=serde.encode("json",nativePreview)
for _,secret in ipairs({job,lease,tostring(localPlayer.UserId),
 tostring(opponent.UserId),"MainTestUser_Alpha",
 "Frostsaber","Harvester","Icepiercer","SnowDagger"}) do
 eq(exported:find(secret,1,true),nil,
  "C9 native preflight summary excludes private user/weapon data")
end
d.setUtc(sourceEpoch+21601)
local expiredNative=clientPreflight:run()
eq(expiredNative.reason,"C9_SOURCE_TOO_OLD_OR_CLOCK_INVALID",
 "C9 six-hour price expiry blocks read-only device strategy")
d.setUtc(sourceEpoch+20)
local invalidSource=preflightFactory.new({
 game=game,players=players,scope=scope,scannerApi=growthScanner,
 sync=sync,crosswalk=market,sourceRetrievedEpoch=sourceEpoch+1,
 isBoundSession=preflightArgs.isBoundSession,
 utcNow=tick,monoNow=now,
 isoToEpoch=preflightArgs.isoToEpoch,
 marketCore=core,captureAdapter=capture,marketBridgeModule=glue,
 bilateralCore=nativeBilateral,
 bilateralBridgeModule=nativeBilateralBridge,
 growthFirstModule=c9Source,
})
local invalidSourceResult=invalidSource:run()
eq(invalidSourceResult.reason,"C9_SOURCE_TIMESTAMP_NOT_BOUND_TO_MARKET",
 "C9 cannot fake fresh source epoch independently from JSON timestamp")
d.setCurrentProtectedLease("C9_FOREIGN_P3_LEASE")
local revokedNative=clientPreflight:run()
eq(revokedNative.reason,"C9_REVIEWED_P3_P4_LEASE_INACTIVE",
 "C9 lost original protected lease blocks scanner before any strategy")
d.setCurrentProtectedLease(lease)
opponent.Parent=nil
local missingPartnerNative=clientPreflight:run()
eq(missingPartnerNative.reason,"C9_PROTECTED_PARTNER_NOT_PRESENT",
 "C9 user leaves job before observation; fail closed")
opponent.Parent=players
ours.Attributes.ItemId=nil
local missingRawIdNative=clientPreflight:run()
eq(missingRawIdNative.reason,"C9_OFFER_RAW_INSTANCE_IDENTITY_UNPROVEN",
 "C9 original P4 attribute absent is not a deployable exact item proof")
ours.Attributes.ItemId="Frostsaber"
eq(clientPreflight:run().status,"C9_LOCAL_READONLY_INVENTORY_AND_GUI_OBSERVED",
 "C9 recovers client preview after missing raw attr resolved")
-- RED: exact same C3 clientRevision=1 across an OWN census refresh,
-- while the partner changes OFFER x1->x2 after C9 finished planning.
-- Guard must double-reconcile FULL original C3 GUI + owned contents even
-- if P3/partner/job/source/offer revision number appear the same.
local raceSource={new=function(params)
 local realNative=c9Source.new(params)
 return {preview=function(_,opts)
  local result=realNative:preview(opts)
  theirs:FindFirstChild("Container"):FindFirstChild("Amount").Text="x2"
  eq(params.marketBridge.refreshOwn().status,"READONLY_OWN_MARKET_BOUND",
    "C9 race original C3 reset after x1->x2 opponent GUI")
  return result
 end}
end}
local raceArgs={}
for k,v in pairs(preflightArgs) do raceArgs[k]=v end
raceArgs.growthFirstModule=raceSource
local racePreflight=preflightFactory.new(raceArgs)
local staleDecision=racePreflight:run(c9RealOptions)
eq(staleDecision.status,"BLOCKED",
 "C9 mid-preflight x1->x2 opponent GUI must invalidate research")
eq(staleDecision.reason,"C9_NATIVE_FINAL_GUI_OR_SESSION_CHANGED",
 "C9 same local clientRevision after refresh cannot conceal offer mutation")
theirs:FindFirstChild("Container"):FindFirstChild("Amount").Text=""

-- Cross-language receipt is ONLY the sanitized local native mock output.
-- No real game, user identity, raw inventory, trade request or Discord event.
local c9Fixture={schema="gingerscope-c9-test-receipt-v1",
 syntheticRobloxServices=true,originalSourceModulesExecuted=true,
 actualNativeIpadRun=false,transportNeverSent=true,
 observations={
  inventoryAndGui=onlyInventory,
  growthPreview=nativePreview,
  sourceExpired=expiredNative,
  sourceEpochForgery=invalidSourceResult,
  leaseRevoked=revokedNative,
  partnerLeft=missingPartnerNative,
  rawItemIdMissing=missingRawIdNative,
  clientOfferAba=staleDecision,
 }}
local c9Payload=serde.encode("json",c9Fixture)
for _,raw in ipairs({job,lease,tostring(localPlayer.UserId),
 tostring(opponent.UserId),"MainTestUser_Alpha","Frostsaber",
 "Harvester","Icepiercer","SnowDagger"}) do
 eq(c9Payload:find(raw,1,true),nil,
 "C9 Python fixture cannot export private weapon, session or client identity")
end
fs.writeFile("pdiddler/ci/.generated_system2_c9_native_preflight_synthetic.json",
 c9Payload)


end
return M
