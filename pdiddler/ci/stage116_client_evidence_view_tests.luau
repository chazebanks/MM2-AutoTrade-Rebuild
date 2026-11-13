-- Stage116 ORIGINAL Lune runtime tests for REAL pure Luau diagnostics modules.
-- No Roblox game, inventory, GUI, executor, remotes, transfers, or webhook.
local view = require("../new_part4/stage116_client_evidence_view")
local safe = require("../new_part4/stage116_safe_panel_geometry")

local function stage106()
 return {
    schema="gingerscope-stage106-two-sided-update-trade-readonly-v1",
    status="CLIENT_MULTISLOT_RAW_KEY_CANDIDATES_MATCH_GUI_UNATTRIBUTED",
    readOnly=true,clientOnly=true,bothSidesReconciled=true,
    ourMatchedSlotCount=1,theirMatchedSlotCount=1,
    clientPerSlotRawKeyCandidateUnique=true,guiTwoStableSamples=true,
    eventSessionAssociationProven=false,callbackCausalityProven=false,
    rawItemIdConfirmed=false,uniqueWeaponInstanceProven=false,
    serverAttestation=false,serverCompletionProven=false,
    currentPricesVerified=false,priceForTradeVerified=false,
    authorizesTrade=false,authorizesAccept=false,
    mayRecordCompletedTrade=false,mayReportProfit=false,
    maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
    tradeOutcome="UNKNOWN",
    username="SECRET_NEVER_OUTPUT",rawWeaponKey="SECRET_NEVER_OUTPUT",
 }
end
local function stage115(tier)
 local n,changed,unchanged,distinct=1,1,0,1
 if tier=="NO_TERMINAL_CLIENT_EVIDENCE" or
    tier=="CLIENT_WINDOW_CLOSED_ONLY" then
    n,changed,unchanged,distinct=0,0,0,0
 elseif tier=="CLIENT_POSTCLOSE_NO_CHANGE" then
    n,changed,unchanged,distinct=1,0,1,1
 elseif tier=="CLIENT_POSTCLOSE_READBACKS_CONFLICT" then
    n,changed,unchanged,distinct=2,2,0,2
 end
 return {
  schema="gingerscope-offline-event-replay-v1",
  status="CLIENT_REPLAY_ONLY",readOnly=true,simulationOnly=true,
  clientEventsAreUntrusted=true,clientEvidenceTier=tier,
  tradeOutcome="UNKNOWN",serverCompletionProven=false,
  serverAttestation=false,serverTransactionIdAuthenticated=false,
  eventSessionAssociationProven=false,causalTradeAttributionProven=false,
  exactWeaponIdentityConfirmed=false,mayRecordCompletedTrade=false,
  mayRecordRejectedTrade=false,mayReportProfit=false,
  mayUseForStrategyLearning=false,authorizesTrade=false,
  authorizesAccept=false,discordWebhookSent=false,
  operatorCorroborationProven=false,
  postCloseDeltaObservations=n,
  postCloseChangedReadbacks=changed,
  postCloseUnchangedReadbacks=unchanged,
  postCloseReadbackRepeats=0,
  postCloseDistinctReadbackPatterns=distinct,
  accountName="SECRET_NEVER_OUTPUT",rawItemId="SECRET_NEVER_OUTPUT",
 }
end
local denied={
 "authorizesTrade","authorizesAccept","mayRecordCompletedTrade",
 "mayReportProfit","maySendDiscordWebhook","mayUseForStrategyLearning",
 "serverCompletionProven","serverAttestation","serverTransactionIdAuthenticated",
 "eventSessionAssociationProven","relationProven","operatorCorroborationProven",
}
local tests=0
local function check(actual,expected)
 tests+=1
 assert(actual==expected, tostring(actual).." ~= "..tostring(expected))
end
local function noAuthority(result)
 for _,field in ipairs(denied) do check(result[field],false) end
 check(result.readOnly,true)
 check(result.tradeOutcome,"UNKNOWN")
 check(result.outcomeText,"OUTCOME UNKNOWN")
 local flat=tostring(result.offerText).." "..tostring(result.readbackText)..
            " "..tostring(result.linkText).." "..tostring(result.outcomeText)
 check(string.find(flat,"SECRET_NEVER_OUTPUT",1,true)==nil,true)
end
local function sampleOfferAndReport()
 local result=view.build(stage106(),stage115("CLIENT_POSTCLOSE_CHANGE_UNATTRIBUTED"))
 noAuthority(result)
 check(result.offerText,"Client offer-key candidates matched GUI (not authenticated)")
 check(result.readbackText,"Separate client readback changed (unattributed)")
 check(result.linkText,"These records are NOT linked to one confirmed trade")
 check(result.status,"CLIENT_EVIDENCE_DISPLAY_ONLY")
end
sampleOfferAndReport()
for tier,expected in pairs({
 NO_TERMINAL_CLIENT_EVIDENCE="No terminal client readback evidence",
 CLIENT_WINDOW_CLOSED_ONLY="Client trade window closed; result unknown",
 CLIENT_POSTCLOSE_NO_CHANGE="Separate client readback shows no change",
 CLIENT_POSTCLOSE_CHANGE_UNATTRIBUTED="Separate client readback changed (unattributed)",
 CLIENT_POSTCLOSE_READBACKS_CONFLICT="Separate client readbacks conflict",
}) do
 local r=view.build(stage106(),stage115(tier))
 noAuthority(r)
 check(r.readbackText,expected)
 check(r.relationProven,false)
end
local noInputs=view.build(nil,nil)
noAuthority(noInputs)
check(noInputs.offerText,"No Stage106 candidate report available")
check(noInputs.readbackText,"No Stage115 sanitized replay report available")
local stageOnly=view.build(stage106(),nil)
noAuthority(stageOnly)
check(stageOnly.offerText,"Client offer-key candidates matched GUI (not authenticated)")
check(stageOnly.readbackText,"No Stage115 sanitized replay report available")
local replayOnly=view.build(nil,stage115("CLIENT_POSTCLOSE_NO_CHANGE"))
noAuthority(replayOnly)
check(replayOnly.offerText,"No Stage106 candidate report available")
check(replayOnly.readbackText,"Separate client readback shows no change")
for _,bad in ipairs({
 {from="106",field="serverCompletionProven",value=true},
 {from="106",field="authorizesAccept",value=true},
 {from="106",field="readOnly",value=false},
 {from="106",field="tradeOutcome",value="COMPLETED"},
 {from="106",field="rawItemIdConfirmed",value=true},
 {from="106",field="ourMatchedSlotCount",value=5},
 {from="106",field="status",value="PASS"},
 {from="115",field="serverTransactionIdAuthenticated",value=true},
 {from="115",field="operatorCorroborationProven",value=true},
 {from="115",field="mayReportProfit",value=true},
 {from="115",field="clientEvidenceTier",value="COMPLETED"},
 {from="115",field="simulationOnly",value=false},
 {from="115",field="tradeOutcome",value="COMPLETED"},
 {from="115",field="postCloseReadbackRepeats",value=20},
}) do
 local a,b=stage106(),stage115("CLIENT_POSTCLOSE_CHANGE_UNATTRIBUTED")
 if bad.from=="106" then a[bad.field]=bad.value else b[bad.field]=bad.value end
 local r=view.build(a,b)
 noAuthority(r)
 if bad.from=="106" then check(r.offerText,"Stage106 client evidence rejected")
 else check(r.readbackText,"Stage115 replay evidence rejected") end
end
for _,bad in ipairs({false,0,"hello",{}}) do
 local ok,r=pcall(view.build,bad,bad)
 check(ok,true)
 noAuthority(r)
end
local function overlap(a,b,g)
 g=g or 0
 return a.x < b.x+b.w+g and a.x+a.w>b.x-g and
        a.y < b.y+b.h+g and a.y+a.h>b.y-g
end
for _,v in ipairs({{x=1024,y=768},{x=1366,y=1024},{x=800,y=600}}) do
 for _,trade in ipairs({
  {x=280,y=180,w=460,h=380},{x=0,y=80,w=410,h=430},
  {x=550,y=80,w=450,h=430},{x=0,y=50,w=1000,h=700}
 }) do
  local p=safe.choose(v,trade,{w=304,h=144})
  if p then
    check(p.x>=14 and p.y>=72,true)
    check(p.x+p.w<=v.x-14,true)
    check(p.y+p.h<=v.y-34,true)
    check(not overlap(p,trade,12),true)
  end
 end
end
for _,arg in ipairs({
 {v={x=0,y=0},t=nil},
 {v={x=800,y=600},t={x=0,y=0,w=0,h=0}},
 {v={x=100,y=300},t=nil},
 {v={x=1024,y=768},t={x=0,y=0,w=1024,h=768}},
}) do
 local p,why=safe.choose(arg.v,arg.t,{w=304,h=144})
 check(p,nil)
 check(type(why),"string")
end
print("[PASS] Stage116 actual Luau view/geometry tests:",tests)
print("[PASS] unlinked offer vs readback never grants settlement, transfer, profit, Accept, or Discord")
