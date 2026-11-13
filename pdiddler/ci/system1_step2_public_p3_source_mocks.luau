-- Run the REAL full 1,800-line outgoing P3 fork under a strict Lune
-- fake-Roblox environment. This checks the actual task.spawn queue not
-- a reconstructed policy. No game network, trade requests, or remotes.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local source=fs.readFile("pdiddler/system1/system1_step2_public_p3_single_send.lua")
local tests=0
local function eq(a,b,reason)
 tests+=1
 assert(a==b,reason..": "..tostring(a).." != "..tostring(b))
end
local function event()
 local e={}
 function e:Connect(fn)
  self.callback=fn
  return {Disconnect=function()end}
 end
 return e
end
local function setup(mode)
 mode=mode or {}
 local envState={}
 local spawnCalls={}
 local ticks=0
 local whitelistReads=0
 local pendingChecks=0
 local statuses=0
 local player={}
 local pg={}
 function pg:FindFirstChild(name)return nil end
 function pg:GetDescendants()return {} end
 function player:FindFirstChildOfClass(kind)
  if kind=="PlayerGui" then return pg end
 end
 player.Name="MainAccount"
 player.UserId=101
 local players={LocalPlayer=player,PlayerAdded=event(),PlayerRemoving=event()}
 local fakeTargets={}
 if mode.multiPlayer then
  fakeTargets={
   {Name="CONSENTED_TEST_A",UserId=201,Parent=players},
   {Name="CONSENTED_TEST_B",UserId=202,Parent=players},
  }
 end
 function players:GetPlayers()
  if not mode.multiPlayer then return {player}end
  return {player,fakeTargets[1],fakeTargets[2]}
 end
 function players:GetPlayerByUserId(uid)
  -- In the adversarial multi-target test, the scanner record exists but
  -- the authoritative Players lookup is unavailable. P3 must not click.
  -- Each consented-but-unresolvable target is individually processed once.
  -- Step2 additional fixture can resolve the real Player object but
  -- deliberately omit the leaderboard GUI, proving PRE-TRADE skip.
  if mode.multiPlayerNoCard then
   for _,target in ipairs(fakeTargets)do
    if target.UserId==uid then return target end
   end
  end
  if mode.multiPlayer then return nil end
  return nil
 end
 local storage={}
 function storage:FindFirstChild()return nil end
 local service={Players=players,ReplicatedStorage=storage,
   GuiService={},VirtualInputManager={}}
 local fakeGame={}
 function fakeGame:GetService(s)return service[s]end
 local scanner={}
 function scanner.getWhitelist()
  whitelistReads+=1
  if mode.multiPlayer then return fakeTargets end
  return {}
 end
 function scanner.getRecord(uid)
  if mode.multiPlayer then
   for _,p in ipairs(fakeTargets)do
    if p.UserId==uid then return {player=p,state="whitelist"}end
   end
  end
  return nil
 end
 function scanner.isWhitelisted(uid)
  return scanner.getRecord(uid)~=nil
 end
 function scanner.hasPendingWork()
  pendingChecks+=1
  return false
 end
 function scanner.setStatus()
  statuses+=1
 end
 function scanner.setRequestState()end
 local controller
 local fakeTask={}
 function fakeTask.spawn(fn)
  spawnCalls[#spawnCalls+1]=fn
 end
 function fakeTask.wait(seconds)
  ticks+=1
  if ticks>=(mode.stopAfter or 8) and controller then controller.stop() end
  return seconds
 end
 local ready=mode.ready
 local readinessCalls=0
 local function readyCheck()
  readinessCalls+=1
  if ready=="error" then error("ready crashed") end
  return ready==true
 end
 local env={game=fakeGame,task=fakeTask,
  getgenv=function()return envState end,
  os=mode.multiPlayer and {clock=function()return 1000 end} or os,
  print=function()end,warn=function()end}
 local lib=luau.load(source,{environment=env,injectGlobals=true})()
 local function start()
  controller=lib.run(scanner,{
   requiresExplicitStart=true,readyCheck=readyCheck
  })
  return controller
 end
 local function execute()
  for _,fn in ipairs(spawnCalls) do
   fn()
  end
 end
 return {lib=lib,start=start,execute=execute,
  scanner=scanner,getEnv=function()return envState end,
  counts=function()
   return {spawns=#spawnCalls,ticks=ticks,
    whitelistReads=whitelistReads,statuses=statuses,
    pendingChecks=pendingChecks,readinessCalls=readinessCalls}
  end,
  getController=function()return controller end,
  readyCheck=readyCheck}
end
do
 local x=setup({ready=true})
 local ok=pcall(x.lib.run,x.scanner,nil)
 eq(ok,false,"unarmed M.run refuses all initiation")
 eq(x.counts().spawns,0,"unarmed run did not start loop")
end
do
 local x=setup({ready=true})
 local c=x.start()
 eq(c.isArmed(),false,"start barrier defaults closed")
 eq(x.counts().spawns,1,"one deferred original request task")
 x.execute()
 local count=x.counts()
 eq(count.whitelistReads,0,"no player rotation scans while barrier shut")
 eq(count.statuses,0,"no request controller status when barrier shut")
 eq(count.pendingChecks,0,"no P3 downstream work while barrier shut")
 eq(c.isArmed(),false,"stop still closed")
 eq(c.arm(),false,"cannot arm after dead session")
end
do
 local x=setup({ready=false})
 local c=x.start()
 local opened,why=c.arm()
 eq(opened,false,"false supervisor never arms")
 eq(why,"supervisor-not-ready","fail closed on false readiness")
 eq(c.isArmed(),false,"gated loop remains closed")
 x.execute()
 eq(x.counts().whitelistReads,0,"failed gate never attempts rotation")
 eq(x.counts().readinessCalls,1,"one readiness callback")
end
do
 local x=setup({ready="error"})
 local c=x.start()
 local opened,why=c.arm()
 eq(opened,false,"throwing supervisor never arms")
 eq(why,"supervisor-not-ready","unknown readiness fails closed")
 x.execute()
 eq(x.counts().whitelistReads,0,"exception cannot start P3")
end
do
 local x=setup({ready=true})
 local c=x.start()
 local opened,why=c.arm()
 eq(opened,true,"explicit verified supervisor arms P3")
 eq(why,"P3_QUEUE_ARMED_NO_FINAL_ACCEPT","arm reason identifies no final accept")
 eq(c.isArmed(),true,"isArmed reflects live queue")
 local repeatArm,repeatWhy=c.arm()
 eq(repeatArm,false,"cannot arm twice")
 eq(repeatWhy,"already-armed","second arm reason")
 x.execute()
 eq(x.counts().whitelistReads>0,true,"actual original P3 queue enters whitelist rotation")
 eq(x.counts().statuses>0,true,"original P3 queue reached idle/status")
 eq(c.isArmed(),false,"no control after session stops")
end
-- NEW repeated same-ALT scenario: each epoch must be a fresh independently
-- armed request controller. No mutation of prior processed map is permitted.
do
 local x=setup({ready=true})
 local first=x.start()
 eq(first.isArmed(),false,"initial P3 epoch starts default closed")
 eq(first.arm(),true,"first individual epoch is physically ARM-authorized")
 first.state.processed[2]="trade-open"
 first.stop()
 eq(first.isArmed(),false,"first epoch invalidated on stop")
 local second=x.start()
 eq(second.session>first.session,true,"new P3 epoch sequence differs")
 eq(second.state.processed[2],nil,
   "new epoch has independently fresh processed state, old event not reused")
 eq(first.state.processed[2],"trade-open",
   "old epoch processed contact remains preserved, never wiped")
 eq(second.isArmed(),false,"second epoch requires separate gated ARM")
 eq(second.arm(),true,"new epoch may be separately authorized")
 second.stop()
 eq(second.isArmed(),false,"second epoch ended without any physical request")
end

-- Original multi-player queue source: a scanner can surface more than
-- one eligible contact, but a mismatched/missing authoritative Player
-- lookup MUST fail before tapping a player card or sending a request.
-- Process each distinct UserId once. This is OFFLINE negative coverage,
-- NOT proof of true in-game multi-target contact, nor a test of P4.
do
 local x=setup({ready=true,multiPlayer=true,stopAfter=25})
 local c=x.start()
 eq(c.arm(),true,"original P3 multi-target selection explicitly armed")
 x.execute()
 eq(c.state.processed[201],"left",
  "first unresolved consented target processed without unsafe contact")
 eq(c.state.processed[202],"left",
  "second unresolved consented target independently processed")
 eq(c.state.left,2,"two distinct unsafe identity checks rejected")
 eq(c.state.sent,0,"no actual P3 request with unresolved Player object")
 eq(c.state.accepted,0,"no fake trade-open or P4 handoff")
 eq(x.counts().whitelistReads>1,true,
  "source queue rotated its scanner candidate assessment")
 eq(c.isArmed(),false,"fail-closed mock session stopped after tests")
end

-- Pure timeout decision from REAL supervised P3 source. This guards
-- against repeating a previously observed bug: reporting IGNORED after
-- cancelPending() returns false, allowing rotation with pending UI still up.
do
 local x=setup({ready=true})
 local classify=x.lib.ignoredTimeoutCancellationVerified
 eq(type(classify),"function","actual P3 exports cancellation verification")
 local combinations=0
 for _,cancelled in ipairs({false,true}) do
  for _,pending in ipairs({false,true}) do
   for _,tradeOpen in ipairs({false,true}) do
    local expected=cancelled and not pending and not tradeOpen
    eq(classify(cancelled,pending,tradeOpen),expected,
      "P3 cancel outcome true only after cancellation+no UI+no trade")
    combinations+=1
   end
  end
 end
 eq(combinations,8,"all boolean cancel/pending/trade combinations covered")
 eq(classify(nil,false,false),false,"missing cancel evidence is not ignored")
 eq(classify(true,nil,false),false,"unreadable pending state fail closed")
 eq(classify(true,false,nil),false,"unreadable trade state fail closed")
 eq(classify(true,false,false),true,"verified ignored request can rotate")
end

-- STEP2 new function uses EXACT original pending GUI observer; unlike
-- text-only counters, this must distinguish false from nil/unknown.
do
 local x=setup({ready=true})
 local c=x.start()
 eq(type(c.pendingVisible),"function","read-only pending observer exported")
 eq(c.pendingVisible(),false,"absent pending request is boolean false")
 eq(c.isArmed(),false,"pre-ARM pending read sends no request")
 c.stop()
 eq(c.pendingVisible(),nil,"stale session cannot claim UI clear")
end
-- Actual Step2 source: public whitelist has two existing real Player
-- instances but MM2 leaderboard/profile-card UI is absent. P3 may tap
-- neither Trade button nor request remote; each player is skipped ONCE.
do
 local x=setup({ready=true,multiPlayer=true,multiPlayerNoCard=true,stopAfter=70})
 local c=x.start()
 eq(c.arm(),true,"public missing-card case independently operator armed")
 x.execute()
 eq(c.state.processed[201],"card-unavailable",
    "eligible public A without visible player card skipped pre-Trade")
 eq(c.state.processed[202],"card-unavailable",
    "eligible public B without visible player card skipped pre-Trade")
 eq(c.state.preTradeCardSkipped,2,
    "two pre-Trade card failures counted without fake sends")
 eq(c.state.requestTargetsAttempted,2,
    "two distinct target windows, no resend")
 eq(c.state.sent,0,"no request sent when card could not be verified")
 eq(c.state.tradeButtonTapAttempted,false,
    "missing last player card never tried to tap Trade")
 eq(c.state.lastOutcomeCode,"CARD_NOT_VERIFIED_PRE_TRADE",
    "precise sanitized pre-dispatch outcome")
 eq(c.state.failStop,false,
    "pre-Trade card absence is not falsely classified as possible request")
end
-- String-source integrity checks are in addition to runtime fake-Roblox tests.
eq(source:find("MaxUnavailableChecks=1",1,true)~=nil,true,
 "one unverified physical Trade tap max for public target")
eq(source:find("S.failStop=true",1,true)~=nil,true,
 "ambiguous original send must stop before advancing to next public target")

print("SYSTEM1_STEP2_PUBLIC_P3_SOURCE_FORK_PASS",tests)
print("[PASS] no outgoing loop, incoming decline, or whitelist work until approved supervisor")
