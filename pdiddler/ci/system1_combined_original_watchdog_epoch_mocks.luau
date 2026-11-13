-- Run the REAL original supervised Part3 watchdog implementation, not
-- the simplified native GUI mock. Verify heartbeat and first BLOCKED
-- reason semantics after a retired (not reset) Step1 session epoch.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local src=fs.readFile(
 "pdiddler/supervised/supervised_p3_continuous_watchdog.lua")
local module=luau.load(src)()
local assertions=0
local function eq(a,b,label)
 assertions+=1
 assert(a==b,label..": "..tostring(a).." ~= "..tostring(b))
end
local function fixture()
 local state={
  now=1.0,stage1Epoch=8,stage2Epoch=9,currentEpoch=9,
  job="ORIGINAL_MM2_SAME_JOB",live=true,
  phase="P3_SUPERVISOR_PREPARED_NOT_ARMED",
  onScreen=true,lastObserved=nil,spawns=0,stopCount=0,
  delivered=0,paused=false,
 }
 local supervisor={}
 function supervisor.status()return {status=state.phase}end
 function supervisor.arm()return true end
 function supervisor.poll()
  if not state.onScreen then
   return {status="BLOCKED",reason="P3_ONSCREEN_INSTRUCTIONS_LOST"}end
  return {status=state.phase,reason="SUPERVISED_CLIENT_REQUESTS_ONLY"}
 end
 function supervisor.resumeAfterClose()return false,"NO_BOUND_TRADE"end
 function supervisor.stop()
  state.stopCount+=1
  return true
 end
 local p3={isPaused=function()return state.paused end}
 local io={trade=function()return nil end}
 local ctx={
  getJobId=function()return state.job end,
  isLive=function()
   return state.live and state.currentEpoch==state.stage2Epoch
  end,
  onStatus=function(r)
   state.lastObserved=r
   state.delivered+=1
  end,
 }
 local scheduler={
  now=function()return state.now end,
  spawn=function(fn)
   state.spawns+=1
   state.asyncLoop=fn -- do not run a second loop in a pure test
  end,
  wait=function(t)end,
 }
 local watcher,why=module.new(supervisor,p3,io,ctx,scheduler)
 eq(type(watcher),"table","original watchdog constructed")
 eq(why,nil,"watchdog was not default closed for valid dependencies")
 return state,watcher
end
do
 local x,w=fixture()
 eq(x.stage1Epoch,8,"old Stage1 session stays retired")
 eq(x.stage2Epoch,9,"new Part3 is exactly later numeric epoch")
 eq(w.isReady(),false,"original watchdog not ready before start")
 eq(w.start(),true,"original watchdog starts after fresh Part3 epoch")
 eq(x.spawns,1,"one original watchdog loop, no duplicate")
 eq(w.isReady(),false,"start without heartbeat is NOT readiness")
 local pulse=w.tick()
 eq(pulse.status,"P3_SUPERVISOR_PREPARED_NOT_ARMED",
  "pre-arm original watchdog polls protected supervisor")
 eq(w.isReady(),true,"real watchdog ready after first heartbeat")
 eq(x.lastObserved.status,"P3_SUPERVISOR_PREPARED_NOT_ARMED",
  "original status callback reports health")
 x.now+=0.60
 eq(w.isReady(),false,
  "real original watchdog heartbeat expires at 0.55s")
 eq(w.status().status,"P3_SUPERVISOR_PREPARED_NOT_ARMED",
  "heartbeat lapse is NOT the same as explicit supervisor BLOCKED")
 eq(w.tick().status,"P3_SUPERVISOR_PREPARED_NOT_ARMED",
  "new supervisor poll refreshes watchdog heartbeat")
 eq(w.isReady(),true,"fresh heartbeat only if real poll runs")
 x.currentEpoch=10
 eq(w.tick().reason,"P3_WATCHDOG_SESSION_LOST",
  "old or externally replaced session strictly stops watchdog")
 eq(w.isReady(),false,"stopped watchdog cannot mask an epoch mismatch")
 eq(x.stopCount,1,"original watchdog stopped supervisor once")
end
do
 local x,w=fixture()
 eq(w.start(),true,"original watchdog starts for block test")
 w.tick()
 x.phase="P3_SUPERVISOR_ARMED_CLIENT_ONLY"
 x.onScreen=false
 local result=w.tick()
 eq(result.status,"BLOCKED","real watchdog blocks on lost GUI supervision")
 eq(result.reason,"P3_ONSCREEN_INSTRUCTIONS_LOST",
  "specific supervisor reason can be copied before shutdown")
 eq(x.lastObserved.reason,"P3_ONSCREEN_INSTRUCTIONS_LOST",
  "onStatus callback receives exact supervisor block cause")
 eq(w.isReady(),false,"blocked original watchdog never stays ready")
 eq(x.stopCount,1,"blocked watchdog stops the supervisor")
end
do
 local x,w=fixture()
 eq(w.start(),true,"watchdog starts in distinct changing-job test")
 w.tick()
 x.live=false
 eq(w.tick().reason,"P3_WATCHDOG_SESSION_LOST",
  "unsafe owner transitions cannot be recovered as healthy")
 eq(w.isReady(),false,"no recovery without a fresh authorized session")
end
print("SYSTEM1_COMBINED_ORIGINAL_WATCHDOG_EPOCH_PASS",assertions)
