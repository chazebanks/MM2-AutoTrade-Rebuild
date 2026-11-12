-- Pure P3/P4 Step2 adversarial controller proof: no actual request/offer.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local src=fs.readFile("pdiddler/system1/system1_step2_public_handoff_controller.lua")
local mod=luau.load(src)()
local tests=0
local function eq(actual,want,why)
 tests+=1
 assert(actual==want,why..": "..tostring(actual).." != "..tostring(want))
end
local function snapshot(override)
 local base={
  safe=true,frozenTargets=3,processedTargets=0,distinctContacts=0,
  acceptedRequests=0,ignoredRequests=0,declinedRequests=0,
  incomingDeclined=0,autoDeclines=0,exhausted=false,
  boundActive=false,pendingVisible=false,p3Paused=false,
  clientTradeSettled=false,noFinalAccept=true,
  noItemsOffered=true,noServerHop=true,
 }
 for k,v in pairs(override or {})do base[k]=v end
 return base
end
local function fixture(steps,flags)
 local out={starts=0,declines=0,stops=0,copies={},index=0,reads=0}
 local scriptSteps=steps or {}
 local api={}
 function api.start()
  out.starts+=1
  return not (flags and flags.failStart)
 end
 function api.inspect()
  out.reads+=1
  if flags and flags.inspectThrows then error("untrusted client crash") end
  local next=scriptSteps[out.index+1]
  if not next then
   return snapshot()
  end
  out.index+=1
  return next
 end
 function api.declineBound(v)
  out.declines+=1
  if flags and flags.declineThrows then error("unsafe side effect") end
  return not (flags and flags.failDecline)
 end
 function api.stop()out.stops+=1;return true end
 function api.copyReport(r)out.copies[#out.copies+1]=r;return true end
 local c,why=mod.new(api,{
  explicitArm=true,maxTargets=3,noItemOffers=true,
  noFinalAccept=true,noServerHop=true,testDurationSeconds=220,
 })
 eq(type(c),"table","controller created with exact explicit ARM")
 eq(why,nil,"no setup denial")
 return c,out
end
local tradeRoot={}
local ready1=snapshot({frozenTargets=3,processedTargets=1,
 distinctContacts=1,ignoredRequests=1})
local ready2=snapshot({frozenTargets=3,processedTargets=2,
 distinctContacts=2,ignoredRequests=1,acceptedRequests=1,
 boundActive=true,p3Paused=true,partnerUserId=202,
 root=tradeRoot,ourPhysicalSlots=0,authenticatedP3Lease=true,
 safeP4Snapshot=true,unchangedTradeRoot=true})
local ready3=snapshot({frozenTargets=3,processedTargets=2,
 distinctContacts=2,ignoredRequests=1,acceptedRequests=1,
 autoDeclines=1})
local endGood=snapshot({frozenTargets=3,processedTargets=3,
 distinctContacts=3,ignoredRequests=2,acceptedRequests=1,
 autoDeclines=1,exhausted=true})
do
 local c,o=fixture({ready1,ready2,ready2,ready3,endGood})
 eq(c.status().status,"PREPARING","no automatic request before ARM")
 eq(o.starts,0,"start not called on construction")
 eq(c.arm(10),true,"single explicit ARM starts exact source")
 eq(c.arm(10),false,"no second ARM/replay")
 eq(c.tick(11).status,"RUNNING","first ignored contact processed")
 eq(c.tick(12).status,"RUNNING","first exact bound P4 snapshot")
 eq(o.declines,0,"one snapshot never triggers decline")
 eq(c.tick(13).status,"RUNNING","second matching root checks")
 eq(o.declines,1,"exact one validated P4 guarded decline")
 eq(c.tick(14).status,"RUNNING","P3 queue resumes after closure")
 local r=c.tick(15)
 eq(r.status,"PUBLIC_CLIENT_ROTATION_HANDOFF_PASS","2+ contacts and 1 bound close proves Step2")
 eq(r.provenBoundClientCloses,1,"exact 1 valid P4 bound client close")
 eq(r.attemptedDistinctContacts,3,"three unique client contacts reported")
 eq(r.acceptedRequests,1,"one public accepted request")
 eq(r.ignoredRequests,2,"two ignored requests");
 eq(r.guardedP4DeclinesAttempted,1,"one guard decline")
 eq(r.processedTargets,3,"no contact skipped")
 eq(r.actualOffers,0,"no P4 item offers")
 eq(r.actualTeleports,0,"no server hops")
 eq(r.finalAcceptEverAttempted,false,"never final Accept")
 eq(r.serverCompletionProven,false,"no server settlement")
 eq(r.verifiedCompletedTrades,0,"no invented game trade")
 eq(r.maySendDiscordWebhook,false,"no false webhook outcome")
 eq(r.mayUseForStrategyLearning,false,"no learning on client window")
 eq(o.starts,1,"exactly one ARM")
 eq(o.stops,1,"stops original P3 and P4 on DONE")
 eq(#o.copies,1,"copies sanitized receipt once")
 eq(c.tick(16).status,"PUBLIC_CLIENT_ROTATION_HANDOFF_PASS","DONE terminal")
 eq(o.declines,1,"no duplicate guarded decline after done")
end
do
 local c,o=fixture({snapshot({frozenTargets=2,processedTargets=1,
 distinctContacts=1,ignoredRequests=1}),snapshot({
 frozenTargets=2,processedTargets=2,distinctContacts=2,
 ignoredRequests=2,exhausted=true})})
 eq(c.arm(0),true,"ARM allowed with two candidates")
 c.tick(1)
 local r=c.tick(2)
 eq(r.status,"CLIENT_ROTATION_ONLY_HANDOFF_NOT_PROVEN",
   "zero accepted root cannot count full P3/P4 integration")
 eq(r.provenBoundClientCloses,0,"no fake P4 handoff")
 eq(o.declines,0,"no side effects without a bound trade")
 eq(o.stops,1,"graceful inconclusive stops all further requests")
end
do
 local c,o=fixture({ready2,ready2},{failDecline=true})
 eq(c.arm(5),true,"unsafe decline case armed")
 c.tick(6)
 local r=c.tick(7)
 eq(r.status,"STOPPED","decline uncertainty terminal")
 eq(r.reason,"P4_DECLINE_FAILED_OR_UNCONFIRMED","precise first error")
 eq(r.possibleSideEffect,true,"uncertain remote side effect retained")
 eq(o.declines,1,"never retry uncertain P4 decline")
 eq(o.stops,1,"P3 halted after P4 failed")
 eq(#o.copies,1,"first fault recorded")
end
for _,bad in ipairs({
 snapshot({frozenTargets=3,processedTargets=1,distinctContacts=1,
  boundActive=true,p3Paused=true,root={},partnerUserId=203,
  ourPhysicalSlots=1,authenticatedP3Lease=true,
  safeP4Snapshot=true,unchangedTradeRoot=true}),
 snapshot({frozenTargets=3,processedTargets=1,distinctContacts=1,
  boundActive=true,p3Paused=true,root={},partnerUserId=203,
  ourPhysicalSlots=0,authenticatedP3Lease=false,
  safeP4Snapshot=true,unchangedTradeRoot=true}),
 snapshot({frozenTargets=3,processedTargets=1,distinctContacts=1,
  boundActive=true,p3Paused=true,root={},partnerUserId=203,
  ourPhysicalSlots=0,authenticatedP3Lease=true,
  safeP4Snapshot=false,unchangedTradeRoot=true}),
 snapshot({frozenTargets=3,processedTargets=1,distinctContacts=1,
  boundActive=true,p3Paused=false,root={},partnerUserId=203,
  ourPhysicalSlots=0,authenticatedP3Lease=true,
  safeP4Snapshot=true,unchangedTradeRoot=true}),
 snapshot({frozenTargets=3,processedTargets=3,distinctContacts=3,
  acceptedRequests=1,ignoredRequests=2,exhausted=true,
  pendingVisible=true}),
})do
 local c,o=fixture({bad})
 eq(c.arm(5),true,"negative case ARM")
 local r=c.tick(6)
 eq(r.status,"STOPPED","missing root, identity, lease, safety or pending must stop")
 eq(o.declines,0,"no unauthorized P4 Decline")
 eq(o.stops,1,"P3 stopped")
end
do
 local changed=snapshot({frozenTargets=3,processedTargets=2,
  distinctContacts=2,acceptedRequests=1,ignoredRequests=1,
  boundActive=true,p3Paused=true,root={},partnerUserId=202,
  ourPhysicalSlots=0,authenticatedP3Lease=true,
  safeP4Snapshot=true,unchangedTradeRoot=true})
 local c,o=fixture({ready2,changed})
 eq(c.arm(0),true,"root mutation test ARM")
 eq(c.tick(1).status,"RUNNING","first root recorded")
 local r=c.tick(2)
 eq(r.status,"STOPPED","root switch must STOP not silently rebind")
 eq(r.reason,"P4_ROOT_REPLACED","precise root switch fault")
 eq(o.declines,0,"no Decline on changed root")
end
do
 local c,o=fixture({snapshot({safe=false})})
 eq(c.arm(0),true,"unreadable source test ARM")
 eq(c.tick(1).status,"STOPPED","untrusted snapshot fail closed")
 eq(o.stops,1,"stop after untrusted snapshot")
end
do
 local c,o=fixture({}, {failStart=true})
 eq(c.arm(1),false,"refused original P3 gate prevents start")
 eq(c.status().status,"STOPPED","failed ARM final STOP")
 eq(o.stops,1,"cleanup on ARM failure")
 eq(o.declines,0,"no P4 action when startup denied")
end
do
 local c,o=fixture({})
 eq(c.arm(0),true,"timeout test ARM")
 local r=c.tick(221)
 eq(r.status,"CLIENT_ROTATION_ONLY_HANDOFF_NOT_PROVEN",
  "220s bounded expiration cannot be a PASS")
 eq(r.reason,"PUBLIC_TEST_TIMEOUT_INCOMPLETE",
  "exact incomplete deadline")
 eq(o.stops,1,"P3 stopped at timeout")
end
do
 local c,o=fixture({ready2,ready2})
 eq(c.arm(0),true,"manual-stop test ARM")
 c.tick(1)
 eq(c.stop().status,"STOPPED","operator STOP terminal")
 eq(o.stops,1,"STOP halts P3")
 eq(o.declines,0,"operator stop prevents P4 decline")
end
print("SYSTEM1_STEP2_PUBLIC_HANDOFF_CONTROLLER_PASS",tests)
