-- Run the REAL full 1,800-line outgoing P3 fork under a strict Lune
-- fake-Roblox environment. This checks the actual task.spawn queue not
-- a reconstructed policy. No game network, trade requests, or remotes.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local source=fs.readFile("pdiddler/supervised/pdiddler3_exact_alt_outbound_requeue.lua")
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
 local alt={Name="AltFixture",UserId=202}
 local pg={}
 function pg:FindFirstChild(name)return nil end
 function pg:GetDescendants()return {} end
 function player:FindFirstChildOfClass(kind)
  if kind=="PlayerGui" then return pg end
 end
 player.Name="MainAccount"
 player.UserId=101
 local players={LocalPlayer=player,PlayerAdded=event(),PlayerRemoving=event()}
 function players:GetPlayers()return {player,alt} end
 function players:GetPlayerByUserId(uid)
  if uid==202 then return alt end
 end
 alt.Parent=players
 local storage={}
 function storage:FindFirstChild()return nil end
 local service={Players=players,ReplicatedStorage=storage,
   GuiService={},VirtualInputManager={}}
 local fakeGame={}
 function fakeGame:GetService(s)return service[s]end
 local scanner={}
 function scanner.getWhitelist()
  whitelistReads+=1
  return {}
 end
 function scanner.getRecord()return nil end
 function scanner.isWhitelisted()return false end
 function scanner.hasPendingWork()
  pendingChecks+=1
  return false
 end
 function scanner.setStatus()
  statuses+=1
 end
 function scanner.setRequestState()end
 local controller
 local deltaCount=0
 local fakeTask={}
 function fakeTask.spawn(fn)
  spawnCalls[#spawnCalls+1]=fn
 end
 function fakeTask.wait(seconds)
  ticks+=1
  if ticks>=8 and controller then controller.stop() end
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
  print=function()end,warn=function()end}
 local lib=luau.load(source,{environment=env,injectGlobals=true})()
 local function start()
  controller=lib.run(scanner,{
   requiresExplicitStart=true,readyCheck=readyCheck,
   exactAltMultiTrade=true,exactAltUserId=202,noIncomingAutoDecline=true,
   verifiedClientDeltaCount=function()return deltaCount end,
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
  readyCheck=readyCheck,
  setDelta=function(n)deltaCount=n end}
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
-- Exact ALT-only requeue after independently verified client deltas.
do
 local x=setup({ready=true})
 local c=x.start()
 local okay=c.arm()
 eq(okay,true,"explicit ARM")
 eq(c.requeueVerifiedExactAlt(),false,"no trade cannot be requeued")
 c.state.processed[202]="trade-open";c.state.paused=true
 eq(c.requeueVerifiedExactAlt(),false,"no client delta proof cannot requeue")
 x.setDelta(1)
 local yes,why=c.requeueVerifiedExactAlt()
 eq(yes,true,"first verified client delta releases next outbound")
 eq(why,"NEXT_EXACT_ALT_OUTBOUND_AFTER_CLIENT_DELTA","explicit reason")
 eq(c.state.processed[202],nil,"exact ALT processed cleared only on proof")
 eq(c.state.paused,false,"P3 requests can resume after verified own census")
 eq(c.requeueVerifiedExactAlt(),false,"duplicate requeue must fail")
 c.state.processed[202]="trade-open";c.state.paused=true
 x.setDelta(2)
 eq(c.requeueVerifiedExactAlt(),true,"SECOND fresh ALT trade can be scheduled")
 eq(c.state.verifiedClientDeltaCycles,2,"distinct client deltas counted")
 c.state.processed[999]="declined"
 c.state.processed[202]="trade-open";c.state.paused=true
 x.setDelta(3)
 eq(c.requeueVerifiedExactAlt(),true,"THIRD distinct ALT trade may follow")
 eq(c.state.processed[999],"declined","cannot reset or requeue public traders")
 eq(c.state.verifiedClientDeltaCycles,3,"3 separate client checks")
 c.stop()
 eq(c.requeueVerifiedExactAlt(),false,"stopped session cannot requeue")
end
do
 local x=setup({ready=true})
 local c=x.start()
 c.arm()
 c.state.processed[202]="trade-open";c.state.paused=true
 x.setDelta(2)
 eq(c.requeueVerifiedExactAlt(),false,"client receipt rollback or gap blocked")
 c.state.processed[202]="ignored"
 x.setDelta(1)
 eq(c.requeueVerifiedExactAlt(),false,"ignored request cannot be requeued as completed")
end
do
 local x=setup({ready=true})
 local optionsMissing={
  requiresExplicitStart=true,readyCheck=x.readyCheck,
 }
 eq(pcall(x.lib.run,x.scanner,optionsMissing),false,
   "existing legacy P3 startup shape cannot instantiate new exact ALT requeue fork")
end
do
 local x=setup({ready=true})
 local c=x.start()
 c.arm()
 c.state.fatalReason="UNEXPECTED_INCOMING_REQUEST_DURING_OUTBOUND"
 eq(c.requeueVerifiedExactAlt(),false,"unexpected incoming must halt all requeues")
 eq(c.fatalStatus(),"UNEXPECTED_INCOMING_REQUEST_DURING_OUTBOUND","incoming stop reason")
end
print("[PASS] source-derived exact ALT P3 outbound requeue multi-trade:",tests)
