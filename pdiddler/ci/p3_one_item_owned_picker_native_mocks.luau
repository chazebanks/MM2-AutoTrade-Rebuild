-- Mock actual read-only owned-selector iPad UI, game catalog and own-profile
-- RPC. PR216 complete native runner separately tested in its original suite.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local actualPicker=fs.readFile(
 "pdiddler/supervised/SUPERVISED_P3_ONE_ITEM_OWNED_PICKER.lua")
local model=fs.readFile(
 "pdiddler/supervised/p3_one_item_owned_selection.lua")
local geometry=fs.readFile(
 "pdiddler/new_part4/stage100_screen_prompt_overlay.lua")
local pass=0
local function eq(a,b,reason)
 pass+=1
 assert(a==b,tostring(reason)..": "..tostring(a).." != "..tostring(b))
end
local function vec(x,y) return {X=x,Y=y} end
local function signal()
 local callbacks={}
 local x={}
 function x:Connect(fn)
  callbacks[#callbacks+1]=fn
  return {Disconnect=function()end}
 end
 function x:Fire()
  for _,fn in ipairs(callbacks) do fn() end
 end
 return x
end
local function node(class,name)
 local o={ClassName=class,Name=name or class,children={},
  Visible=true,Enabled=true,Text="",Active=false,
  Activated=signal(),AbsolutePosition=vec(0,0),AbsoluteSize=vec(0,0)}
 function o:IsA(kind)return self.ClassName==kind end
 function o:FindFirstChild(n)return self.children[n]end
 function o:FindFirstChildOfClass(n)
  for _,v in pairs(self.children)do
   if v.ClassName==n then return v end
  end
 end
 function o:GetFullName()return self.Name end
 function o:Destroy()
  self.Parent=nil
  self.Visible=false
 end
 return setmetatable(o,{
  __index=function(self,k)
   if k=="Parent" then return rawget(self,"_parent")end
  end,
  __newindex=function(self,k,v)
   if k=="Parent" then
    local old=rawget(self,"_parent")
    if old then old.children[self.Name]=nil end
    rawset(self,"_parent",v)
    if v then v.children[self.Name]=self end
   else rawset(self,k,v)
   end
  end,
 })
end
local function fixtures(options)
 options=options or {}
 local clock=0
 local server=node("Players","Players")
 local me=node("Player","MainAccount")
 me.UserId=1
 me.Parent=server
 local alt=node("Player","venossgaming90190")
 alt.UserId=2
 if not options.noAlt then alt.Parent=server end
 local pg=node("PlayerGui","PlayerGui")
 pg.Parent=me
 server.LocalPlayer=me
 function me:FindFirstChildOfClass(c)
  if c=="PlayerGui" then return pg end
 end
 function server:GetPlayerByUserId(id)
  if id==2 and alt.Parent==server then return alt end
 end
 local RS=node("ReplicatedStorage","ReplicatedStorage")
 local remotes=node("Folder","Remotes")
 remotes.Parent=RS
 local inventory=node("Folder","Inventory")
 inventory.Parent=remotes
 local getProfile=node("RemoteFunction","GetProfileData")
 getProfile.Parent=inventory
 local ownCalls=0
 local own=options.profile or {
  ProfileData={Weapons={Owned={
   Iceblaster=3,ChromaFang=1,CommonKnife=1,Gingerscope=1
  }}}
 }
 function getProfile:InvokeServer()
  ownCalls+=1
  if options.profileError then error("mock profile unavailable") end
  return own
 end
 local db=node("Folder","Database")
 db.Parent=RS
 local syncModule=node("ModuleScript","Sync")
 syncModule.Parent=db
 local sync=options.sync or {Weapons={
  Iceblaster={ItemName="Iceblaster",Rarity="Godly",ItemType="Gun"},
  ChromaFang={ItemName="Fang",Rarity="Godly",ItemType="Knife",Chroma=true},
  CommonKnife={ItemName="Default",Rarity="Common",ItemType="Knife"},
  Gingerscope={ItemName="Gingerscope",Rarity="Ancient",ItemType="Gun"},
 },Item={}}
 local gameEnv={
  PlaceId=options.badPlace and 0 or 142823291,
  JobId="TEST_SELECT_JOB",
  GetService=function(_,k)
   if k=="Players" then return server end
   if k=="ReplicatedStorage" then return RS end
   if k=="Workspace" then
    return {CurrentCamera={ViewportSize=vec(options.width or 1024,
                                                options.height or 768)}}
   end
  end,
 }
 local envShared={}
 if options.concurrent then envShared.PDIDDLER_SUPERVISED_P3_NATIVE_OWNER={}end
 local sources={}
 local stub="-- mock downstream runner; full code is tested in PR216's native Lune suite\n"..
   string.rep("-",12500)..'\nreturn {prepared=true}'
 function gameEnv:HttpGet(url)
  sources[#sources+1]=url
  if url:find("p3_one_item_owned_selection.lua",1,true) then return model end
  if url:find("stage100_screen_prompt_overlay.lua",1,true) then return geometry end
  if url:find("SUPERVISED_P3_ONE_ITEM_OFFER_NATIVE.lua",1,true) then return stub end
  error("unrecognized source URI")
 end
 local instances={}
 local builtin=type(require)=="function" and require
 local scheduledSpawns=0
 local env={
  game=gameEnv,require=function(x)
   if x==syncModule then return sync end
   return builtin(x)
  end,
  getgenv=function()return envShared end,
  Instance={new=function(typ)
   local o=node(typ)
   instances[#instances+1]=o
   return o
  end},
  Color3={fromRGB=function(...)return{...}end},
  UDim={new=function(...)return{...}end},
  UDim2={fromOffset=function(...)return{...}end},
  Enum={
   Font={GothamBold="BOLD"},
   TextXAlignment={Left="LEFT"},
   ZIndexBehavior={Sibling="SIBLING"},
  },
  task={
   spawn=function(fn)
    scheduledSpawns+=1
    -- The first spawn is the picker bootstrap itself; only the nested
    -- GetProfileData RPC simulates a hung/uncancellable remote.
    if not options.mockHungSpawn or scheduledSpawns==1 then fn() end
   end,
   wait=function(seconds)clock+=(seconds or 0.05)end,
  },
  os={clock=function()return clock end},
  warn=function()end,
  print=function()end,
 }
 env.loadstring=function(s)
  return luau.load(s,{environment=env,injectGlobals=true})
 end
 local function run()
  return luau.load(actualPicker,{environment=env,injectGlobals=true})()
 end
 local function named(n)
  for _,v in ipairs(instances) do
   if v.Name==n then return v end
  end
 end
 return {run=run,instances=instances,gen=envShared,
  named=named,sources=sources,pg=pg,rs=RS,
  me=me,alt=alt,server=server,profileCalls=function()return ownCalls end,
  clock=function()return clock end,
  advance=function(seconds)clock+=seconds end,
  remotes=remotes}
end

do
 local x=fixtures()
 local instance=x.run()
 eq(type(instance),"table","read-only iPad picker booted")
 eq(instance.status(),"READY","reads current owned Sync keys")
 eq(x.profileCalls(),1,"exactly one preflight own-profile read")
 eq(#x.sources,2,"no downstream P3 runner before item selection")
 eq(x.named("OwnedOption_1")~=nil,true,"first physical item choice exists")
 eq(x.named("OwnedOption_2")~=nil,true,"second eligible item choice exists")
 eq(x.named("OwnedOption_3"),nil,"ordinary and protected items NOT offered")
 eq(x.named("UseSelectedItem"),nil,"no implicit prior selection")
 eq(x.named("ConfirmOwnedOne").Visible,false,"cannot confirm without user selecting")
 eq(x.named("OwnedOption_1").Text:find("Fang",1,true)~=nil,true,
  "first choice is Chroma Fang sorted by display")
 eq(x.named("OwnedOption_2").Text:find("Iceblaster",1,true)~=nil,true,
  "second choice preserves actual raw Iceblaster")
 eq(x.named("OwnedOption_1").Text:find("Gingerscope",1,true),nil,
  "Gingerscope cannot appear in selection")
 x.named("OwnedOption_1").Activated:Fire()
 eq(x.named("ConfirmOwnedOne").Visible,true,"only explicit item click enables confirm")
 eq(#x.sources,2,"choosing item STILL does not start P3")
 x.named("ConfirmOwnedOne").Activated:Fire()
 eq(#x.sources,3,"one downstream immutable runner loads after physical selection confirm")
 eq(x.sources[3]:find("73c4a72843d818d08f8212c74d9db0fdad59acea",1,true)~=nil,
  true,"tested PR216 runner exact SHA source loaded")
 local cfg=x.gen.PDIDDLER_SUPERVISED_P3_ONE_ITEM_NATIVE
 eq(type(cfg),"table","exact approved selection sent to original runner")
 eq(cfg.approvedRawKey,"ChromaFang","current original game raw key")
 eq(cfg.approvedDisplayName,"Fang","base GUI name; separate Chroma tag")
 eq(cfg.approvedChromaFlag,true,"Chroma choice not guessed")
 eq(cfg.targetName,"venossgaming90190","original ALT remains only target")
 eq(cfg.allowOneItemPilot,true,"guarded original operator enabled")
 eq(cfg.finalAcceptMustRemainManual,true,"no final Accept")
 eq(x.profileCalls(),1,"one read only in picker; PR216 rechecks before offer")
 eq(x.gen.PDIDDLER_P3_OWNED_PICKER_OWNER,nil,"picker cleans its owner")
 eq(x.gen.PDIDDLER_P3_OWNED_PICKER_USED_JOB,"TEST_SELECT_JOB","picker one-shot job consumed")
 eq(x.run(),nil,"second picker run prohibited same JobId")
end
do
 local x=fixtures()
 x.run()
 x.named("OwnedOption_2").Activated:Fire()
 x.named("ConfirmOwnedOne").Activated:Fire()
 eq(x.gen.PDIDDLER_SUPERVISED_P3_ONE_ITEM_NATIVE.approvedRawKey,
  "Iceblaster","user can pick second item instead")
 eq(x.gen.PDIDDLER_SUPERVISED_P3_ONE_ITEM_NATIVE.approvedChromaFlag,false,
  "normal item correctly non-Chroma")
end
do
 local x=fixtures()
 local instance=x.run()
 x.named("CancelOwnedOne").Activated:Fire()
 eq(instance.status(),"OPERATOR_CANCELLED","STOP before selecting")
 eq(#x.sources,2,"no new runner ever fetched after cancel")
 eq(x.gen.PDIDDLER_SUPERVISED_P3_ONE_ITEM_NATIVE,nil,
  "cancellation does not arm any trade")
end
for _,opts in ipairs({
 {badPlace=true},{noAlt=true},{concurrent=true},
}) do
 local x=fixtures(opts)
 eq(x.run(),nil,"unsafe original environment prevents any picker")
 eq(#x.sources,0,"no URLs on blocked startup")
 eq(x.profileCalls(),0,"no own-profile RPC on unsafe startup")
end
do
 local x=fixtures({profile={ProfileData={Weapons={Owned={Gingerscope=1}}}}})
 local s=x.run()
 eq(s.status(),"BLOCKED","no eligible offer choices")
 eq(x.named("ConfirmOwnedOne").Visible,false,"no confirmation after all protected")
 eq(#x.sources,2,"no downstream runner loaded on empty candidate list")
end
do
 local x=fixtures({profile={ProfileData={Weapons={Owned={Iceblaster=1,UnknownWeapon=1}}}}})
 local s=x.run()
 eq(s.status(),"BLOCKED","unmapped owned key fails closed")
 eq(#x.sources,2,"no runner when ownership metadata incomplete")
end
do
 local x=fixtures({profileError=true})
 local s=x.run()
 eq(s.status(),"BLOCKED","own-profile remote failure blocks")
 eq(x.profileCalls(),1,"one failed RPC, no retries")
 eq(#x.sources,2,"no downstream trade runner after RPC failure")
end
do
 local x=fixtures({mockHungSpawn=true})
 local s=x.run()
 eq(s.status(),"BLOCKED","read-only profile timeout blocks")
 eq(s.status()~="READY",true,"timed-out profile never selectable")
 eq(x.clock()>=8,true,"bounded single read deadline")
 eq(#x.sources,2,"no trade runner on timeout")
end
do
 local x=fixtures({width=280,height=240})
 eq(x.run(),nil,"tiny viewport cannot fit safe item picker")
 eq(x.profileCalls(),0,"no profile read if no usable safe screen")
end
do
 local x=fixtures()
 local s=x.run()
 x.named("OwnedOption_1").Activated:Fire()
 x.alt.Parent=nil
 x.named("ConfirmOwnedOne").Activated:Fire()
 eq(#x.sources,2,"ALT departure blocks pinned P3 launch")
 eq(x.gen.PDIDDLER_SUPERVISED_P3_ONE_ITEM_NATIVE,nil,
  "ALT departure leaves P3 disabled")
end
do
 local x=fixtures()
 local s=x.run()
 x.named("OwnedOption_1").Activated:Fire()
 x.named("ConfirmOwnedOne").Activated:Fire()
 eq(s.status(),"CONSUMED","cannot re-use old confirmed picker")
end
do
 local x=fixtures()
 x.run()
 x.named("OwnedOption_1").Activated:Fire()
 local public=x.gen.PDIDDLER_P3_OWNED_PICKER_OWNER
 public.selected=2
 public.choiceResult={choices={{raw="Gingerscope",
   display="Gingerscope",chroma=false}}}
 x.named("ConfirmOwnedOne").Activated:Fire()
 eq(x.gen.PDIDDLER_SUPERVISED_P3_ONE_ITEM_NATIVE.approvedRawKey,
  "ChromaFang","public mutable owner cannot swap the human selection")
 eq(x.gen.PDIDDLER_SUPERVISED_P3_ONE_ITEM_NATIVE.approvedChromaFlag,
  true,"protected forged Gingerscope never becomes approved")
end
do
 local x=fixtures()
 local s=x.run()
 x.named("OwnedOption_1").Activated:Fire()
 x.advance(181)
 x.named("ConfirmOwnedOne").Activated:Fire()
 eq(s.status(),"BLOCKED","stale selection expires after three minutes")
 eq(#x.sources,2,"expired profile never starts PR216 native runner")
 eq(x.gen.PDIDDLER_SUPERVISED_P3_ONE_ITEM_NATIVE,nil,
  "expired selection cannot authorize P3 setup")
end
do
 local x=fixtures()
 local s=x.run()
 x.named("OwnedOption_1").Activated:Fire()
 local activeGUI=node("ScreenGui","TradeGUI")
 activeGUI.Enabled=true
 activeGUI.Parent=x.pg
 local container=node("Frame","Container")
 container.Parent=activeGUI
 local trade=node("Frame","Trade")
 trade.Parent=container
 x.named("ConfirmOwnedOne").Activated:Fire()
 eq(s.status(),"BLOCKED","picker aborts if a trade unexpectedly opens")
 eq(#x.sources,2,"never boot PR216 over an existing trade")
end
print("[PASS] original MM2 iPad owned-choice / confirm / immutable P3 handoff:",pass)
print("[PASS] no request, OfferItem, Accept, or default selection in picker")
