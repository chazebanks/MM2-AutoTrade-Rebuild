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
   clientWindowClosed=true}
 end
 return{
  status="CLIENT_TEST_SEQUENCE_COMPLETE",phase="DONE",
  reason="ALL_THREE_RECOVERY_CLIENT_SCENARIOS_VERIFIED",
  completedRounds=3,maxRounds=3,recoveryBatchAuthorized=true,
  authorizesAccept=false,finalAcceptEverAttempted=false,
  serverCompletionProven=false,verifiedCompletedTrades=0,
  possibleSideEffect=false,rounds=rounds,
  actions={requestsStarted=3,offersClientVisible=6,
   removalsAttempted=6,declinesAttempted=3,clientClosedWindows=3,
   adaptiveReoffersAttempted=3},
 }
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
 local api={
  launchStep1=function()
   f.launchedFirst+=1
   if cfg.rejectStep1 then return false end
   return true
  end,
  step1Status=function()return f.first end,
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
print("SYSTEM1_ONE_SERVER_TRANSITION_CONTROLLER_PASS",tests)
