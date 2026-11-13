local fs=require("@lune/fs")
local luau=require("@lune/luau")
local mod=luau.load(fs.readFile(
 "pdiddler/system1/system1_one_server_transition_controller.lua"))()
local tests=0
local function eq(a,b,why)
 tests+=1
 assert(a==b,why..": "..tostring(a).." != "..tostring(b))
end
local function step1()
 local names={"ALT_REPLACES_ITEM","ALT_STACK_X1_TO_X2","ALT_CLEAR_THEN_NEW"}
 local rounds={}
 for i,name in ipairs(names)do
  rounds[i]={round=i,scenarioId=name,status="CLIENT_SEQUENCE_PASS",
   clientWindowClosed=true,closedBy="MAIN_GUARDED_DECLINE"}
 end
 return{
  status="CLIENT_TEST_SEQUENCE_COMPLETE",phase="DONE",
  reason="ALL_THREE_RECOVERY_CLIENT_SCENARIOS_VERIFIED",
  completedRounds=3,maxRounds=3,recoveryBatchAuthorized=true,
  -- Real original Step1 raw controller.status() omits these two
  -- fields. They exist ONLY in the serializer's separate JSON.
  authorizesAccept=false,serverCompletionProven=false,
  possibleSideEffect=false,rounds=rounds,
  actions={requestsStarted=3,offersClientVisible=6,
   removalsAttempted=6,declinesAttempted=3,clientClosedWindows=3,
   adaptiveReoffersAttempted=3},
 }
end
local function serializedStep1(raw)
 local actions={}
 for k,v in pairs(raw.actions or {})do actions[k]=v end
 local rounds={}
 for i,v in ipairs(raw.rounds or {})do
  rounds[i]={}
  for k,value in pairs(v)do rounds[i][k]=value end
 end
 local exported={}
 for k,v in pairs(raw)do exported[k]=v end
 exported.actions=actions
 exported.rounds=rounds
 exported.schema="gingerscope-system1-step1-alt-recovery-native-v1"
 exported.runNonce="00000000-0000-0000-0000-SERIALIZED_STEP1"
 exported.finalAcceptEverAttempted=false
 exported.verifiedCompletedTrades=0
 exported.noServerSettlementProof=true
 exported.clientOnly=true
 return exported
end
local function step2()
 return{
  status="PUBLIC_CLIENT_ROTATION_HANDOFF_PASS",phase="DONE",
  reason="TWO_DISTINCT_CONTACTS_AND_BOUND_CLIENT_CLOSE_PROVEN",
  targetBudget=3,attemptedDistinctContacts=3,
  provenBoundClientCloses=2,
  publicRequestDiagnostic={originalP3SentConfirmed=3},
  authorizesAccept=false,authorizesOffer=false,
  finalAcceptEverAttempted=false,actualOffers=0,actualTeleports=0,
  serverCompletionProven=false,verifiedCompletedTrades=0,
  possibleSideEffect=false,
 }
end
local function fixture(cfg)
 cfg=cfg or {}
 local f={now=1,jobOk=true,epoch=18,quiescentSafe=true,
  first=step1(),second=step2(),launchedFirst=0,launchedSecond=0,
  stopped=0,reports={},log={},isStage2=false}
 f.export=serializedStep1(f.first)
 local api={
  launchStep1=function()
   f.launchedFirst+=1
   if cfg.rejectStep1 then return false end
   return true
  end,
  step1Status=function()return f.first end,
  step1VerifiedReceipt=function()
   if cfg.dropExport then return nil end
   return f.export
  end,
  quiescent=function()
   return {safe=f.quiescentSafe,epoch=f.epoch}
  end,
  launchStep2=function(epoch)
   f.launchedSecond+=1
   f.log[#f.log+1]=epoch
   if cfg.rejectStep2 then return false end
   f.isStage2=true
   return true
  end,
  step2Status=function()return f.second end,
  stopActive=function()f.stopped+=1 end,
  emit=function(report)f.reports[#f.reports+1]=report end,
  jobMatches=function()return f.jobOk end,
 }
 local c,why=mod.new(api,{
  oneServerOnly=true,noFinalAccept=true,
  noItemTransfer=true,noServerHop=true,
 })
 eq(type(c),"table","source controller constructed")
 eq(why,nil,"source controller allowed only test adapters")
 f.engine=c
 function f.advance(steps)
  local r=nil
  for i=1,(steps or 1)do
   f.now+=0.21
   r=c.tick(f.now)
  end
  return r
 end
 return f
end
do
 local f=fixture()
 eq(f.engine.status().status,"PREPARING","does not auto-run")
 eq(f.launchedFirst,0,"no offer script before start")
 eq(f.engine.start(f.now),true,"one ARM starts source-pinned Step1 only")
 eq(f.launchedFirst,1,"Step1 started once")
 eq(f.launchedSecond,0,"Step2 cannot start before Step1 proof")
 eq(f.advance(1).phase,"QUIESCENCE","exact 3/3 ledger arms quiescence")
 eq(f.advance(3).phase,"QUIESCENCE","requires stable multiple samples")
 eq(f.launchedSecond,0,"no early P3 epoch transition")
 eq(f.advance(2).phase,"STEP2","quiescence and elapsed threshold verified")
 eq(f.launchedSecond,1,"exactly one combined Step2 launch")
 eq(f.log[1],18,"previous retired P3 epoch preserved")
 local report=f.advance(1)
 eq(report.status,"ONE_SERVER_SYSTEM1_CLIENT_INTEGRATION_PASS",
  "complete integration needs BOTH exact independent client outcomes")
 eq(report.step1ClosedWindows,3,"prior ALT closures preserved")
 eq(report.step2AttemptedDistinctContacts,3,"public rotation separate")
 eq(report.step2VerifiedBoundCloses,2,"actual protected close count")
 eq(report.combinedScriptsSerialized,true,"no simultaneous controller")
 eq(report.originalP3EpochNeverReset,true,"no epoch ABA reset")
 eq(report.serverCompletionProven,false,"no invented settlement")
 eq(report.finalAcceptEverAttempted,false,"no final Accept")
 eq(report.verifiedCompletedTrades,0,"zero actual settled weapon trades")
 eq(f.stopped,1,"controllers released after final")
 eq(#f.reports,1,"one combined terminal COPY")
 eq(f.advance(2).status,"ONE_SERVER_SYSTEM1_CLIENT_INTEGRATION_PASS",
  "terminal state cannot restart")
 eq(f.launchedSecond,1,"no duplicate Step2 transition")
end
for _,kind in ipairs({
 "WRONG_CLOSED","WRONG_FOURTH","WRONG_ACCEPT","WRONG_SETTLED",
 "MISSING_ROUNDS","NO_REOFFER","UNSAFE_SIDE_EFFECT",
})do
 local f=fixture()
 if kind=="WRONG_CLOSED" then f.first.actions.clientClosedWindows=2
 elseif kind=="WRONG_FOURTH" then f.first.completedRounds=4
 elseif kind=="WRONG_ACCEPT" then f.first.finalAcceptEverAttempted=true
 elseif kind=="WRONG_SETTLED" then f.first.serverCompletionProven=true
 elseif kind=="MISSING_ROUNDS" then f.first.rounds[2]=nil
 elseif kind=="NO_REOFFER" then f.first.actions.adaptiveReoffersAttempted=2
 else f.first.possibleSideEffect=true end
 eq(f.engine.start(f.now),true,"ALT unverified case initially starts")
 local r=f.advance(1)
 eq(r.status,"STOPPED","never transition on invalid ALT client proof "..kind)
 eq(r.reason,"COMBINED_STEP1_LEDGER_NOT_VERIFIED",
  "precise first-fault Step1 validation "..kind)
 eq(f.launchedSecond,0,"Step2 not launched after ALT mismatch "..kind)
 eq(f.stopped,1,"safety stop owner "..kind)
end
do
 local f=fixture()
 eq(f.engine.start(f.now),true,"start after exact PIN")
 eq(f.advance(1).phase,"QUIESCENCE","valid ALT client proof")
 f.quiescentSafe=false
 eq(f.advance(12).phase,"QUIESCENCE",
  "no controller transition while pending request or root can remain")
 eq(f.launchedSecond,0,"no unsafe epoch override")
 f.now+=13
 eq(f.advance(1).reason,"COMBINED_PRE_STEP2_QUIESCENCE_TIMEOUT",
  "fail closed on ambiguous handoff")
 eq(f.stopped,1,"timeout stops all")
end
do
 local f=fixture()
 f.engine.start(f.now)
 f.advance(1)
 f.advance(2)
 f.epoch=19
 f.advance(1)
 eq(f.engine.status().reason,"COMBINED_P3_EPOCH_CHANGED_DURING_QUIESCENCE",
  "P3 epoch ABA/mutation cannot be silently accepted")
 eq(f.launchedSecond,0,"P3 not restarted after epoch mismatch")
end
do
 local f=fixture({rejectStep2=true})
 f.engine.start(f.now)
 f.advance(10)
 eq(f.engine.status().status,"STOPPED","Step2 loader missing => STOP")
 eq(f.engine.status().reason,"COMBINED_STEP2_TRANSITION_DENIED",
  "never fallback to moving/latest sources")
end
do
 local f=fixture()
 f.engine.start(f.now)
 f.advance(6)
 f.second.publicRequestDiagnostic.originalP3SentConfirmed=1
 eq(f.advance(1).reason,"COMBINED_STEP2_LEDGER_NOT_VERIFIED",
  "do not count unconfirmed contacts")
 eq(f.engine.status().status,"STOPPED","invalid Step2 ledger STOP")
end
do
 local f=fixture()
 f.engine.start(f.now)
 f.advance(6)
 f.second.authorizesAccept=true
 eq(f.advance(1).status,"STOPPED","unexpected Accept authority is unsafe")
end
do
 local f=fixture()
 f.engine.start(f.now)
 f.advance(6)
 f.second={phase="INCONCLUSIVE",status="CLIENT_ROTATION_ONLY_HANDOFF_NOT_PROVEN"}
 eq(f.advance(1).status,"INCONCLUSIVE",
  "no actual accept/handoff cannot count a complete integration")
 eq(f.launchedSecond,1,"Step2 did launch")
end
do
 local f=fixture()
 f.engine.start(f.now)
 f.jobOk=false
 eq(f.advance(1).reason,"COMBINED_JOB_CHANGED_OR_INVALID_CLOCK",
  "server change forbidden even before Stage1 completes")
 eq(f.launchedSecond,0,"no second controller after server change")
end
do
 local f=fixture()
 f.engine.start(f.now)
 eq(f.engine.stop().status,"STOPPED","operator abort stops")
 eq(f.launchedSecond,0,"operator abort prevents all public attempts")
 eq(f.stopped,1,"stop called once")
end
do
 local f=fixture({rejectStep1=true})
 eq(f.engine.start(f.now),false,"fail-safe when pinned Step1 not loadable")
 eq(f.engine.status().status,"STOPPED","no unverified fallback")
 eq(f.launchedSecond,0,"never run Step2 after first launch failed")
end

-- Real combined-device report COMBINED_STEP1_STOPPED originally discarded
-- Step1's actionable reason. Never discard it, never "repair" a STOP,
-- and never change original ALT/Part4 mechanics.
do
 local f=fixture()
 f.first={
  status="STOPPED",phase="STOPPED",
  reason="ALT_CHANGED_WHILE_CLEARING_FOR_REOFFER",
  round=2,scenarioId="ALT_STACK_X1_TO_X2",
  completedRounds=1,lastAction="MAIN_REMOVE_OWN_ONE",
  copyAttempted=true,possibleSideEffect=false,
  actions={requestsStarted=2,offersClientVisible=3,
   removalsAttempted=3,declinesAttempted=1,
   clientClosedWindows=1},
 }
 eq(f.engine.start(f.now),true,"actual failed Step1 starts under launcher")
 local r=f.advance(1)
 eq(r.status,"STOPPED","original Step1 failure remains a STOP")
 eq(r.reason,"COMBINED_STEP1_STOPPED","combined first-fault category stable")
 eq(type(r.step1Failure),"table","nested child reason is retained")
 eq(r.step1Failure.reason,"ALT_CHANGED_WHILE_CLEARING_FOR_REOFFER",
  "exact original Step1 reason not hidden by combined wrapper")
 eq(r.step1Failure.phase,"STOPPED","original phase copied")
 eq(r.step1Failure.scenarioId,"ALT_STACK_X1_TO_X2","original scenario retained")
 eq(r.step1Failure.round,2,"original round retained")
 eq(r.step1Failure.completedRounds,1,"completed window count retained")
 eq(r.step1Failure.lastAction,"MAIN_REMOVE_OWN_ONE","last action retained")
 eq(r.step1Failure.requestAttempts,2,"request count retained")
 eq(r.step1Failure.possibleSideEffect,false,"uncertainty unchanged")
 eq(r.step1Failure.childCopyAttempted,true,"prior child COPY was attempted")
 eq(f.launchedSecond,0,"no stage2 launches on child STOP")
 eq(#f.reports,1,"one combined terminal report")
 eq(f.reports[1].step1Failure.reason,r.step1Failure.reason,
  "terminal clipboard includes actual child reason")
end

do
 local f=fixture()
 f.first={
  status="PREPARING",phase="SELECT_TWO_OWN_ITEMS",
  reason="OWNED_PICKER_NOT_READY",
  completedRounds=0,round=0,lastAction="NONE",
 }
 eq(f.engine.start(f.now),true,"pre-ARM diagnostic fixture starts")
 local r=f.advance(1)
 eq(r.status,"STOPPED","stale pre-arm setup is not allowed to hang")
 eq(r.reason,"COMBINED_STEP1_PREARM_STOPPED","specific pre-arm wrapper cause")
 eq(r.step1Failure.reason,"OWNED_PICKER_NOT_READY",
  "pre-arm original setup reason preserved")
 eq(f.launchedSecond,0,"no public requests after setup failure")
end

do
 local f=fixture()
 f.first={
  status="STOPPED",phase="STOPPED",round=7,completedRounds=0,
  reason="USER_123_REVEALS_DETAIL_<PRIVATE>",
  lastAction="RAW_WEAPON_ID",
  actions={requestsStarted=2,offersClientVisible=2},
 }
 f.engine.start(f.now)
 local r=f.advance(1)
 eq(r.step1Failure.reason,"UNKNOWN","never copy arbitrary untrusted strings")
 eq(r.step1Failure.lastAction,"RAW_WEAPON_ID",
  "safe enum-shaped action code retained")
 eq(r.step1Failure.round,7,"bounded numeric round retained")
 eq(r.step1Failure.firstFailureEvidence.sameVisibleName,false,
  "no user data or names copied from empty proof")
end

do
 local f=fixture()
 f.first={
  status="STOPPED",phase="STOPPED",
  reason="ALT_LEFT_OR_REPLACED",round=1,
  completedRounds=0,possibleSideEffect=true,
 }
 f.engine.start(f.now)
 local r=f.advance(1)
 eq(r.step1Failure.possibleSideEffect,true,
  "uncertain child side effect never reclassified safe")
 eq(f.launchedSecond,0,"no Step2 after uncertain stop")
end


-- Reproduce exact device issue: live Step1.status() has no serialized-only
-- fields even after 3/3, while the separately exported original Step1 JSON
-- contains explicit false/zero. Matching both is a PASS; no safety bypass.
do
 local f=fixture()
 eq(f.first.finalAcceptEverAttempted,nil,
  "real controller.status omits finalAcceptEverAttempted")
 eq(f.first.verifiedCompletedTrades,nil,
  "real controller.status omits verifiedCompletedTrades")
 eq(f.export.finalAcceptEverAttempted,false,
  "original JSON explicitly asserts no final Accept")
 eq(f.export.verifiedCompletedTrades,0,
  "original JSON explicitly asserts no settled trade")
 eq(f.engine.start(f.now),true,"real raw/export mismatch test starts")
 eq(f.advance(1).phase,"QUIESCENCE",
  "verified source JSON closes raw status safety-field gap")
 eq(f.launchedSecond,0,"no Step2 before old-session barrier")
end

-- Missing or contradictory original serializer evidence FAILS CLOSED,
-- regardless of the raw Step1 report's 3/3 completion.
for _,mode in ipairs({
 "NO_EXPORT","FINAL_ACCEPT_TRUE","SETTLED_NONZERO",
 "SERIALIZER_NOT_CLIENT","STALE_ROUND","ALTERED_SLOT",
 "NO_GUARDED_DECLINE","SAFETY_FLAG_MISSING",
})do
 local f=fixture({dropExport=mode=="NO_EXPORT"})
 if mode=="FINAL_ACCEPT_TRUE" then
  f.export.finalAcceptEverAttempted=true
 elseif mode=="SETTLED_NONZERO" then
  f.export.verifiedCompletedTrades=1
 elseif mode=="SERIALIZER_NOT_CLIENT" then
  f.export.clientOnly=false
 elseif mode=="STALE_ROUND" then
  f.export.completedRounds=2
 elseif mode=="ALTERED_SLOT" then
  f.export.actions.offersClientVisible=5
 elseif mode=="NO_GUARDED_DECLINE" then
  f.export.rounds[2].closedBy="UNKNOWN"
 elseif mode=="SAFETY_FLAG_MISSING" then
  f.export.noServerSettlementProof=nil
 end
 f.engine.start(f.now)
 local r=f.advance(1)
 eq(r.status,"STOPPED","export mismatch terminal "..mode)
 eq(r.reason,mode=="NO_EXPORT" and
  "COMBINED_STEP1_SERIALIZED_RECEIPT_UNAVAILABLE" or
  "COMBINED_STEP1_LEDGER_NOT_VERIFIED",
  "precise mismatch classification "..mode)
 eq(f.launchedSecond,0,"never start public requests from bad proof "..mode)
 eq(f.stopped,1,"STOP after original proof mismatch "..mode)
end

-- Even with a good serialized report, unexpected non-nil raw security
-- fields must never be silently accepted.
for _,field in ipairs({"finalAcceptEverAttempted","verifiedCompletedTrades"})do
 local f=fixture()
 f.first[field]=field=="finalAcceptEverAttempted" and true or 1
 f.engine.start(f.now)
 local r=f.advance(1)
 eq(r.reason,"COMBINED_STEP1_LEDGER_NOT_VERIFIED",
  "raw report safety contradiction not authorized "..field)
 eq(f.launchedSecond,0,"no public requests on raw mismatch "..field)
end

print("SYSTEM1_ONE_SERVER_TRANSITION_CONTROLLER_PASS",tests)
