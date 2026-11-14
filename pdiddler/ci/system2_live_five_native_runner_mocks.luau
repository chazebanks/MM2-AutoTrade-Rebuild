-- Native System2 FIVE launcher integration smoke using actual runtime source and
-- real pure controller/interpreter. Inherited IO/P3 implementations are replaced
-- with strict contract mocks here; source pins and original tests run separately.
-- No Roblox, network, item remote, Discord or real account access in this test.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local native=fs.readFile("pdiddler/system2/SYSTEM2_LIVE_FIVE_MAIN_NATIVE.lua")
local controller=fs.readFile("pdiddler/system2/system2_live_five_controller.lua")
local interpreter=fs.readFile("pdiddler/system2/system2_live_strategy_evidence.lua")
local passed=0
local function eq(a,b,msg)
 assert(a==b, (msg or "mismatch")..": "..tostring(a).." != "..tostring(b))
 passed+=1
end
local function event()
 local h={}
 return {Connect=function(self,f) h[#h+1]=f;return {Disconnect=function()end}end,
  Fire=function(self,...)for _,f in ipairs(h)do f(...)end end}
end
local function vec(x,y)return{X=x,Y=y}end
local function node(kind,name)
 local children={}
 local n={ClassName=kind,Name=name or kind,Visible=true,Enabled=true,Active=false,
   Text="",AbsolutePosition=vec(300,200),AbsoluteSize=vec(300,300),
   children=children,Activated=event()}
 local meta={
  __newindex=function(t,k,v)
   rawset(t,k,v)
   if k=="Parent" and type(v)=="table" and v.children then
    v.children[t.Name]=t
   end
  end
 }
 setmetatable(n,meta)
 function n:FindFirstChild(k)return self.children[k] end
 function n:FindFirstChildOfClass(k)
  for _,c in pairs(self.children)do if c.ClassName==k then return c end end
 end
 function n:IsA(k)return k==self.ClassName end
 return n
end
local function fakeEnvironment(opts)
 opts=opts or {}
 local q={}
 local instances={}
 local asyncFault=nil
 local warnings={}
 local E={PDIDDLER_SYSTEM2_ALT_NAME="venossgaming90190"}
 if opts.badAltConfig then E.PDIDDLER_SYSTEM2_ALT_NAME=nil end
 if opts.competingOwner then E.PDIDDLER_SYSTEM1_MAIN_AUTO_OWNER={} end
 local players={};local pg=node("PlayerGui","PlayerGui")
 local LP={Name="MAIN",UserId=101,Parent=players}
 local ALT={Name="venossgaming90190",UserId=202,Parent=players}
 players.LocalPlayer=LP;pg.Parent=LP
 function LP:FindFirstChildOfClass(k)if k=="PlayerGui"then return pg end end
 function players:FindFirstChild(k)
  if k==ALT.Name and not opts.noAlt then return ALT end
 end
 function players:GetPlayerByUserId(id)
  if id==ALT.UserId and not opts.noAlt then return ALT end
 end
 local RS=node("ReplicatedStorage","ReplicatedStorage")
 local remotes=RS:FindFirstChild("Remotes")
 if not remotes then
  remotes=node("Folder","Remotes")
  RS.children["Remotes"]=remotes
 end
 local inventory=node("Folder","Inventory");remotes.children.Inventory=inventory
 local profile=node("RemoteFunction","GetProfileData")
 function profile:InvokeServer()return {owned={}} end
 inventory.children.GetProfileData=profile
 local db=node("Folder","Database");RS.children.Database=db
 local sync=node("ModuleScript","Sync");sync.MockValue={}
 db.children.Sync=sync
 local Http={
  GenerateGUID=function()return "00000000-0000-4000-8000-000000000000" end,
  JSONEncode=function(_,x)return serde.encode("json",x)end
 }
 local times=0
 local world={CurrentCamera={ViewportSize=vec(1024,768)}}
 local services={Players=players,Workspace=world,
  HttpService=Http,ReplicatedStorage=RS}
 local MODS={
  ["new_part4/stage100_screen_prompt_overlay.lua"]=[[
   return {choose=function(v,t,b)
    if v.x<360 or v.y<240 then return nil end
    return {x=10,y=10,w=340,h=216}
   end}
  ]],
  ["supervised/pdiddler4_tradeio_supervised_v2.lua"]=[[
   return {new=function(_,gate)
    return {trade=function()return nil end,
     partnerName=function()return "venossgaming90190"end,
     offerItem=function()return false end,
     decline=function()return false end,
     removeOne=function()return false end}
   end}
  ]],
  ["supervised/supervised_p3_p4_handoff.lua"]=[[
   return {bind=function()return true end}
  ]],
  ["supervised/supervised_real_p3_rotation_handoff.lua"]=[[
   return {new=function()return {} end}
  ]],
  ["supervised/supervised_p3_startup_supervisor.lua"]=[[
   return {new=function(scanner,outgoing,coordinator,bridge,io,players,lp,ctx)
    local E=getgenv()
    E.__NATIVE_P3_BOOT_COUNT=(E.__NATIVE_P3_BOOT_COUNT or 0)+1
    local sup={isP3Paused=function()return false end,
       currentBoundReadOnly=function()return nil end,
       stop=function()end}
    function sup.arm(opt)
     if opt.explicitUserAuthorization~=true or
        opt.finalAcceptMustRemainManual~=true or
        not ctx.readyCheck() then return false end
     E.__NATIVE_P3_ARM_COUNT=(E.__NATIVE_P3_ARM_COUNT or 0)+1
     return true
    end
    return sup
   end}
  ]],
  ["supervised/supervised_p3_continuous_watchdog.lua"]=[[
   return {new=function(sup,p3,io,ctx,sched)
    local ready=false
    return {start=function()ready=true;return true end,
      isReady=function()return ready end,
      stop=function()ready=false end}
   end}
  ]],
  ["pdiddler3_scanner_MODULE_v6_5_PART4_STATUS_BRIDGE.lua"]=[[
   return {
    getOwnInventory=function()
     return {unmapped=0,badQty=0,rawOwned=2,items={
       {id="SampleA",name="SampleA",cat="Weapons",qty=1,page="normal"},
       {id="SampleB",name="SampleB",cat="Weapons",qty=1,page="normal"}
     }}
    end,
    isWhitelisted=function(uid)return uid==202 end,
    getRecord=function(uid)
      if uid==202 then
       return {player=game:GetService("Players"):GetPlayerByUserId(202),state="whitelist"}
      end
    end,
    getWhitelist=function()
      return {game:GetService("Players"):GetPlayerByUserId(202)}
    end
   }
  ]],
  ["supervised/p3_one_item_owned_selection.lua"]=[[
   return {build=function()
    return {status="CLIENT_ELIGIBLE_OWN_CHOICES",
      authorizesOffer=false,authorizesAccept=false,
      serverCompletionProven=false,choices={
       {raw="SampleA",display="SampleA",chroma=false,qty=1},
       {raw="SampleB",display="SampleB",chroma=false,qty=1},
      }}
   end}
  ]],
  ["system1/pdiddler3_outgoing_single_send_epoch.lua"]=[[
   return {run=function()return true end}
  ]],
  ["supervised/supervised_four_slot_operator_plan_aba_draft.lua"]=[[
   return {run=function()return {status="BLOCKED"}end}
  ]],
  ["intelligence_lab/p3_shadow_aba_offer_lease.lua"]=[[
   return {new=function()return {}end}
  ]],
  ["system2/system2_live_five_controller.lua"]=controller,
  ["system2/system2_live_strategy_evidence.lua"]=interpreter,
 }
 local sourceReads={}
 local game={
  PlaceId=opts.badPlace and 1 or 142823291,
  JobId="S2_MOCK_JOB",
  GetService=function(_,k)return services[k] end,
  HttpGet=function(_,url)
   sourceReads[#sourceReads+1]=url
   local path=url:match("/pdiddler/(.+)$")
   local src=MODS[path]
   if not src then error("UNEXPECTED_SOURCE") end
   if (path=="system2/system2_live_five_controller.lua" and
        not url:find("bf72128813fd00992221f3c4e985958d81c5cb5c",1,true))
        or (path=="system2/system2_live_strategy_evidence.lua" and
        not url:find("9c4d75c4a38faf555a356eae6901ae4ec5ecb5b7",1,true)) then
    error("PIN_MISMATCH")
   end
   return src.."\n-- source bounded mock padding "..string.rep("-",200)
  end,
 }
 local function enqueue(fn)
  q[#q+1]=coroutine.create(fn)
 end
 local sched={spawn=enqueue,
  wait=function() coroutine.yield("wait") end}
 local env={
  game=game,getgenv=function()return E end,
  Instance={new=function(k)
   if opts.badGui and k=="ScreenGui" then error("GUI_BLOCKED") end
   local n=node(k);instances[#instances+1]=n;return n end},
  Enum={ZIndexBehavior={Sibling="Sibling"},
   TextXAlignment={Left="Left"},Font={GothamBold="BOLD",
     GothamSemibold="SEMIBOLD"}},
  UDim={new=function(...)return {...}end},
  UDim2={fromOffset=function(...)return {...}end},
  Color3={fromRGB=function(...)return {...}end},
  require=function(obj)return obj.MockValue end,
  setclipboard=function(txt)
   E.__COPIED=txt
   return true
  end,
  warn=function(...)
   local xs={...};local out={}
   for _,v in ipairs(xs)do out[#out+1]=tostring(v)end
   warnings[#warnings+1]=table.concat(out," ")
  end,
  print=function(...)end,
  os={clock=function()times+=0.1;return times end},
  task=sched,
 }
 env.loadstring=function(code)
  return luau.load(code,{environment=env,injectGlobals=true})
 end
 local function run()
  return luau.load(native,{environment=env,injectGlobals=true})()
 end
 local function pump(count)
  for _=1,count do
   local snapshot={}
   for _,co in ipairs(q)do
    if coroutine.status(co)~="dead"then snapshot[#snapshot+1]=co end
   end
   q=snapshot
   for _,co in ipairs(snapshot)do
    if coroutine.status(co)~="dead"then
     local ok,err=coroutine.resume(co)
     if not ok then asyncFault=tostring(err);error(err) end
    end
   end
  end
 end
 local function button(prefix)
  for _,obj in ipairs(instances)do
   if obj.Name:sub(1,#prefix)==prefix then return obj end
  end
 end
 return {run=run,pump=pump,button=button,instances=instances,
  E=E,LP=LP,ALT=ALT,PG=pg,reads=sourceReads,warnings=warnings,
  getFault=function()return asyncFault end}
end

do
 local x=fakeEnvironment()
 local runner=x.run()
 eq(type(runner),"table","native launcher warnings="..table.concat(x.warnings," | "))
 eq(#x.reads,13,"all pinned source modules")
 eq(x.E.__NATIVE_P3_BOOT_COUNT,nil,"no implicit request startup")
 eq(x.button("ArmFiveIntelligence").Visible,false,"ARM hidden without selections")
 x.pump(4)
 local a=x.button("OwnedChoice_1")
 local b=x.button("OwnedChoice_2")
 eq(type(a),"table","owned picker 1")
 eq(type(b),"table","owned picker 2")
 a.Activated:Fire()
 b.Activated:Fire()
 local arm=x.button("ArmFiveIntelligence")
 eq(arm.Visible,true,"one real five ARM visible")
 eq(arm.Active,true,"five ARM enabled")
 eq(x.E.__NATIVE_P3_BOOT_COUNT,nil,"no request before human ARM")
 arm.Activated:Fire()
 eq(x.E.__NATIVE_P3_BOOT_COUNT,nil,"ARM queues, not duplicate send")
 x.pump(2)
 eq(x.E.__NATIVE_P3_BOOT_COUNT,1,"first fresh P3 epoch started")
 eq(x.E.__NATIVE_P3_ARM_COUNT,1,"first supervised P3 request ARM")
 local r=runner.status()
 eq(r.round,1,"correct first scenario")
 eq(r.phase,"WAIT_OPEN","waiting exact ALT request acceptance")
 eq(r.actions.requestsStarted,1,"one request attempt")
 eq(r.actions.finalAccepts,0,"no final Accept")
 eq(r.livePassedStages,0,"no client evidence yet")
 local stop=x.button("StopAuto")
 stop.Activated:Fire()
 local status=runner.status()
 eq(status.phase,"STOPPED","STOP revokes session")
 eq(status.firstFailureScenario,"DISCORD_EVENT_PROVENANCE","explicit first scenario fail-stop")
 eq(x.E.PDIDDLER_SYSTEM2_LIVE_FIVE_OWNER,nil,"owner released")
 eq(type(x.E.__COPIED),"string","STOP copies report")
 eq(x.E.__COPIED:find("SampleA",1,true),nil,"no owned item leaks")
 eq(x.E.__COPIED:find("venossgaming90190",1,true),nil,"no ALT leaks")
end
for _,opt in ipairs({
 {badPlace=true},{noAlt=true},{badAltConfig=true},
 {competingOwner=true},{badGui=true},
})do
 local x=fakeEnvironment(opt)
 eq(x.run(),nil,"invalid startup never authorizes runner")
 eq(x.E.__NATIVE_P3_BOOT_COUNT,nil,"no P3 on invalid startup")
end
print("SYSTEM2_LIVE_FIVE_NATIVE_LUNE_LAUNCHER_PASS "..tostring(passed).." assertions")
