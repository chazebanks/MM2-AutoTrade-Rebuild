-- Five distinct supervised scenarios, one actual original host lease in mocks.
-- Real manual item changes ONLY: this test never invokes OfferItem or Accept.
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local luau=require("@lune/luau")
local path="pdiddler/system2/native_supreme_only_five_scenario_recorder.lua"
local M=luau.load(fs.readFile(path))()
local n=0
local function eq(x,y,name)
 n+=1
 assert(x==y,tostring(name).." expected="..tostring(y).." actual="..tostring(x))
end
local function truth(x,name)n+=1;assert(x,name)end
local function clone(x)return serde.decode("json",serde.encode("json",x))end
local base={
 clientOnly=true,contextOK=true,tradeOpen=true,rootBound=true,
 doubleReadStable=true,clientRawCaptureSignature="original-protected-lease-p4-sig",
 jobId="PRIVATE_JOB_C9_NOV17",tradeLeaseId="PRIVATE_LEASE_17",
 partnerUserId=998877666,ourAccepted=false,theirAccepted=false,
 ourSlots={},theirSlots={}
}
local ours={slot=1,rawId="Harvester",label="Harvester",rawIdObserved=true,
 amountText="",chromaTag=false}
local theirs={slot=1,rawId="FlowerwoodKnife",label="Flowerwood",rawIdObserved=true,
 amountText="x2",chromaTag=false}
local function f(oursArr,theirsArr)
 local x=clone(base)
 x.ourSlots=clone(oursArr or {})
 x.theirSlots=clone(theirsArr or {})
 return x
end
local function blocked(reason)
 return {
  schema="gingerscope-supreme-only-intrade-button-research-v1",
  status="BLOCKED",reason=reason,valueSource="SUPREME_ONLY",
  readOnly=true,clientOnly=true,researchOnly=true,
  authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
  mayReportProfit=false,maySendDiscordWebhook=false,
  mayUseForStrategyLearning=false
 }
end
local good={
 schema="gingerscope-supreme-only-intrade-button-research-v1",
 status="SUPREME_ONLY_CURRENT_OFFER_CLIENT_PREVIEW",
 sourceStatus="SUPREME_ONLY_PAPER_RESEARCH_NOT_EXECUTABLE",
 valueSource="SUPREME_ONLY",listedDelta=195,
 readOnly=true,clientOnly=true,researchOnly=true,
 authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
 mayReportProfit=false,maySendDiscordWebhook=false,
 mayUseForStrategyLearning=false
}
local empty=f({},{}),one=f({ours},{}),both=f({ours},{theirs})
local recorder=M.new()
eq(recorder.progress().completedCount,0,"start 0/5")
eq(recorder.progress().nextStep,1,"first stage")
eq(recorder.progress().authorizesOffer,false,"no scripted offer controller")
eq(recorder.record(empty,empty,blocked("BOTH_PHYSICAL_OFFERS_MUST_BE_NONEMPTY"),false).status,
 "SCENARIO_BLOCKED","cannot start without original lease")
eq(recorder.progress().completedCount,0,"invalid lease never passes startup")
local result=recorder.record(empty,empty,blocked("BOTH_PHYSICAL_OFFERS_MUST_BE_NONEMPTY"),true)
eq(result.status,"SCENARIO_PASS","first button passes startup + empty")
eq(result.completedCount,2,"startup and empty distinct stage receipts")
eq(result.results[1].code,"S1_PASS","startup receipt")
eq(result.results[2].code,"S2_PASS","empty offer receipt")
eq(result.results[3].status,"NOT_PASSED","no phantom stage3")
eq(recorder.record(empty,empty,blocked("BOTH_PHYSICAL_OFFERS_MUST_BE_NONEMPTY"),true).status,
 "SCENARIO_BLOCKED","empty again does not pass one-sided stage")
eq(recorder.progress().completedCount,2,"stalled at stage3 until actual change")
local oneSide=recorder.record(one,one,blocked("BOTH_PHYSICAL_OFFERS_MUST_BE_NONEMPTY"),true)
eq(oneSide.completedCount,3,"one-sided stage3 passed")
eq(oneSide.reason,"S3_PASS","one-sided signature")
local falseTwo=recorder.record(both,both,blocked("GUI_RAW_WEAPON_ID_OR_SLOT_NOT_PROVEN"),true)
eq(falseTwo.status,"SCENARIO_BLOCKED","missing game ID does not pass 2-sided valuation")
eq(falseTwo.completedCount,3,"cannot skip valid quote")
local wrongSource=clone(good)
wrongSource.valueSource="MM2VALUES"
eq(recorder.record(both,both,wrongSource,true).status,"SCENARIO_BLOCKED","other source cannot pass")
local fakeAuth=clone(good)
fakeAuth.authorizesAccept=true
eq(recorder.record(both,both,fakeAuth,true).status,"SCENARIO_BLOCKED","no Accept authority")
local forged=clone(good)
forged.sourceStatus="BLOCKED_UNAPPROVED_SUPREME_LOSS"
eq(recorder.record(both,both,forged,true).status,"SCENARIO_BLOCKED","rejected loss is not valid quote")
local stale=clone(both)
stale.theirSlots[1].amountText="x3"
eq(recorder.record(both,stale,good,true).status,"SCENARIO_BLOCKED","offer race between reads rejected")
eq(recorder.progress().completedCount,3,"race does not pass stage4")
local accepted=clone(both)
accepted.theirAccepted=true
eq(recorder.record(accepted,accepted,good,true).status,"SCENARIO_BLOCKED","manual Accept state refused")
local renamed=clone(both)
renamed.partnerUserId=123456789
eq(recorder.record(both,renamed,good,true).status,"SCENARIO_BLOCKED","partner switch refused")
local valid=recorder.record(both,both,good,true)
eq(valid.status,"SCENARIO_PASS","two-sided source verified")
eq(valid.reason,"S4_PASS","stage4 recorded separately")
eq(valid.completedCount,4,"four completed")
eq(recorder.record(both,both,good,true).reason,"STAGE5_OFFER_NOT_CHANGED","reclick not manual change")
local altered=clone(both)
altered.theirSlots[1].amountText="x1"
local changedWrong=recorder.record(altered,altered,blocked("SUPREME_ONLY_SOURCE_EXPIRED_OR_UNVERIFIED"),true)
eq(changedWrong.status,"SCENARIO_BLOCKED","expired market cannot pass changed-offer test")
eq(changedWrong.completedCount,4,"stale source blocks stage5")
local changed=recorder.record(altered,altered,good,true)
eq(changed.status,"SCENARIO_PASS","stage5 verifies manual physical offer change")
eq(changed.reason,"S5_PASS","stage5 receipt")
eq(changed.completedCount,5,"all five")
eq(changed.done,true,"complete")
eq(changed.authorizesOffer,false,"still no offers")
eq(changed.authorizesAccept,false,"still no final Accept")
eq(changed.mayReportProfit,false,"no live profit")
eq(changed.mayUseForStrategyLearning,false,"no learning from synthetic tests")
local resultSummary=recorder.summary()
eq(resultSummary.completedCount,5,"five distinct completed stages persist")
eq(resultSummary.results[5].code,"S5_PASS","final milestone")
truth(resultSummary.blockedAttempts>=6,"adversarial refusals counted")
local serialized=serde.encode("json",resultSummary)
for _,secret in ipairs({"Harvester","FlowerwoodKnife","PRIVATE_JOB","PRIVATE_LEASE",
 "998877666","sourceKey","rawItemId","rawId","x2","ItemId"}) do
 truth(not serialized:find(secret,1,true),"no private ids/item data exported: "..secret)
end
local replay=recorder.record(altered,altered,good,true)
eq(replay.status,"ALL_FIVE_SCENARIOS_PASSED","no duplicate stage6")
eq(replay.completedCount,5,"no duplicates after success")
local oneOther=f({},{theirs})
local altRec=M.new()
altRec.record(empty,empty,blocked("BOTH_PHYSICAL_OFFERS_MUST_BE_NONEMPTY"),true)
eq(altRec.record(oneOther,oneOther,blocked("BOTH_PHYSICAL_OFFERS_MUST_BE_NONEMPTY"),true)
 .reason,"S3_PASS","either party can be sole offerer")
local source=fs.readFile(path)
for _,forbidden in ipairs({"FireServer","InvokeServer","TeleportService","PostAsync",
 "AcceptTrade","DeclineTrade","MM2VALUES","mm2Listed","game:HttpGet","getgenv"}) do
 truth(not source:find(forbidden,1,true),"no side-effect/source mixing "..forbidden)
end
print("GINGERSCOPE_FIVE_SCENARIO_MANUAL_RECORDER_LUA_PASS assertions="..tostring(n))
