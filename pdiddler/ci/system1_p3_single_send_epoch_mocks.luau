-- Run the REAL full 1,800-line outgoing P3 fork under a strict Lune
-- fake-Roblox environment. This checks the actual task.spawn queue not
-- a reconstructed policy. No game network, trade requests, or remotes.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local source=fs.readFile("pdiddler/system1/pdiddler3_outgoing_single_send_epoch.lua")
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
 function players:GetPlayers()return {player} end
 function players:GetPlayerByUserId(uid)return nil end
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

print("SYSTEM1_MAIN_AUTO_P3_FRESH_EPOCH_FORK_PASS",tests)
print("[PASS] no outgoing loop, incoming decline, or whitelist work until approved supervisor")
