-- Combined-only real pure controller: P4 successful close, then frozen
-- third target can disappear or queue may stall. No forged PASS, no retries.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local M=luau.load(fs.readFile(
 "pdiddler/system1/system1_combined_step2_handoff_controller.lua"))()
local tests=0
local function eq(a,b,why)
 tests+=1
 assert(a==b,why..": "..tostring(a).." vs "..tostring(b))
end
local function obs(props)
 local v={
  safe=true,frozenTargets=3,processedTargets=2,distinctContacts=2,
  acceptedRequests=1,ignoredRequests=1,declinedRequests=0,
  incomingDeclined=0,autoDeclines=1,exhausted=false,
  preTradeCardSkips=0,requestTargetsAttempted=2,
  originalP3SentConfirmed=2,pendingUiEverConfirmed=true,
  boundActive=false,pendingVisible=false,p3Paused=false,
  clientTradeSettled=false,noFinalAccept=true,
  noItemsOffered=true,noServerHop=true,
  remainingFrozenUnprocessed=1,remainingEligibleNow=1,
  scannerPendingWork=false,p3Active=false,tradeRootVisible=false,
  watchdogStatus="P3_RESUMED_AFTER_CLIENT_TRADE_CLOSED",
 }
 for k,value in pairs(props or {})do v[k]=value end
 return v
end
local tradeRoot={}
local bound=obs({
 boundActive=true,p3Paused=true,tradeRootVisible=true,
 root=tradeRoot,partnerUserId=202,ourPhysicalSlots=0,
 authenticatedP3Lease=true,safeP4Snapshot=true,
 unchangedTradeRoot=true,
})
local function fixture()
 local f={now=10,starts=0,declines=0,stops=0,reports={},
  current=bound}
 local api={
  start=function()f.starts+=1;return true end,
  inspect=function()return f.current end,
  declineBound=function(v)
   f.declines+=1
   return v.partnerUserId==202 and v.ourPhysicalSlots==0
  end,
  stop=function()f.stops+=1;return true end,
  copyReport=function(r)f.reports[#f.reports+1]=r end,
 }
 local controller,why=M.new(api,{
  explicitArm=true,maxTargets=3,noItemOffers=true,
  noFinalAccept=true,noServerHop=true,testDurationSeconds=220,
 })
 eq(type(controller),"table","actual combined controller loaded")
 eq(why,nil,"guarded construction")
 f.c=controller
 function f.startAndClose()
  eq(controller.arm(10),true,"one operator public ARM")
  eq(controller.tick(11).status,"RUNNING","P4 first bound snapshot")
  eq(controller.tick(12).status,"RUNNING","second unchanged bound root")
  eq(f.declines,1,"exact one verified P4 decline")
  eq(controller.status().provenBoundClientCloses,1,"closed count proven")
  f.current=obs()
  eq(controller.tick(13).status,"RUNNING","P3 unpauses after close")
  eq(controller.status().publicProgressDiagnostic.p3UnpausedAfterClose,
     true,"P3 unpaused observed after exact client close")
 end
 return f
end
do
 local f=fixture()
 f.startAndClose()
 f.current=obs({remainingEligibleNow=0})
 local r=f.c.tick(44)
 eq(r.status,"CLIENT_ROTATION_ONLY_HANDOFF_NOT_PROVEN",
  "third frozen target unavailable is not success")
 eq(r.phase,"INCONCLUSIVE","ineligible target ends bounded test")
 eq(r.reason,"PUBLIC_FROZEN_TARGET_UNAVAILABLE_INCOMPLETE",
  "third de-whitelisted/left explicitly identified")
 eq(r.attemptedDistinctContacts,2,"two real contacts never fabricated to three")
 eq(r.provenBoundClientCloses,1,"original protected close survives")
 eq(r.publicProgressDiagnostic.remainingFrozenUnprocessed,1,
   "third remains frozen but unprocessed")
 eq(r.publicProgressDiagnostic.remainingEligibleNow,0,
   "third actually no longer eligible, no remote attempted")
 eq(r.publicProgressDiagnostic.p3UnpausedAfterClose,true,
   "P3 queue did resume, target unavailable")
 eq(r.finalAcceptEverAttempted,false,"no final Accept")
 eq(r.serverCompletionProven,false,"no falsely settled trade")
 eq(f.declines,1,"no second guarded decline")
 eq(f.stops,1,"terminal INCONCLUSIVE cleans up")
 eq(#f.reports,1,"single terminal COPY")
end
do
 local f=fixture()
 f.startAndClose()
 f.current=obs({remainingEligibleNow=1})
 local r=f.c.tick(74)
 eq(r.status,"CLIENT_ROTATION_ONLY_HANDOFF_NOT_PROVEN",
  "eligible third but no processing after 60 seconds is not PASS")
 eq(r.reason,"PUBLIC_POST_CLOSE_QUEUE_STALLED_INCOMPLETE",
  "next-target dispatch stall distinct from absent player")
 eq(r.publicProgressDiagnostic.remainingEligibleNow,1,
  "remaining eligible target recorded")
 eq(r.publicProgressDiagnostic.p3Paused,false,
  "P3 not stuck paused in this scenario")
 eq(f.declines,1,"no unauthorized new action")
end
do
 local f=fixture()
 f.startAndClose()
 f.current=obs({remainingEligibleNow=0,scannerPendingWork=true})
 local r=f.c.tick(74)
 eq(r.reason,"PUBLIC_SCANNER_UNRESOLVED_INCOMPLETE",
  "original scanner pending cannot cause forever RUNNING")
 eq(r.phase,"INCONCLUSIVE","scanner unresolved not passed")
 eq(f.stops,1,"stop protected after incomplete")
end
do
 local f=fixture()
 f.startAndClose()
 f.current=obs({remainingEligibleNow=1,pendingVisible=true,p3Active=true})
 local r=f.c.tick(74)
 eq(r.status,"STOPPED","active unclassified pending request is unsafe")
 eq(r.reason,"P3_POST_CLOSE_ACTIVE_REQUEST_STALLED",
  "ongoing request is not harmless inactivity")
 eq(r.possibleSideEffect,true,"possible outgoing request retained")
 eq(f.declines,1,"never retries click, offer or close")
 eq(f.stops,1,"releases queue on unknown active outcome")
end
do
 local f=fixture()
 f.startAndClose()
 f.current=obs({frozenTargets=3,processedTargets=3,
  distinctContacts=3,ignoredRequests=2,originalP3SentConfirmed=3,
  requestTargetsAttempted=3,remainingFrozenUnprocessed=0,
  remainingEligibleNow=0,exhausted=true})
 local r=f.c.tick(14)
 eq(r.status,"PUBLIC_CLIENT_ROTATION_HANDOFF_PASS",
  "third successfully processed wins before idle timer")
 eq(r.provenBoundClientCloses,1,"exact safe decline counted once")
 eq(r.attemptedDistinctContacts,3,"three actual distinct contacts")
 eq(f.stops,1,"clean terminal pass")
end
do
 local f=fixture()
 f.startAndClose()
 f.current=obs({remainingEligibleNow=0})
 local r=f.c.tick(28)
 eq(r.phase,"RUNNING","do not prematurely terminate transient scanner change")
 eq(f.stops,0,"no timeout too early")
 f.current=obs({remainingEligibleNow=1})
 eq(f.c.tick(29).phase,"RUNNING",
    "eligible third returned before timeout")
end
print("SYSTEM1_COMBINED_POST_CLOSE_PROGRESS_PASS",tests)
