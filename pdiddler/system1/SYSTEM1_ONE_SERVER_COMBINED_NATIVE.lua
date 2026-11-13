-- System1 one-original-MM2-JobId combined test: controlled 3/3 ALT recovery
-- then frozen three-contact public P3/P4 client handoff. Two separate ARMs,
-- one LOAD, one SERVER, exactly one live controller at any time.
-- No final Accept, no settled item transfers, no bot avoider or server hop.
local E=(type(getgenv)=="function" and getgenv()) or _G
local KEY="PDIDDLER_SYSTEM1_ONE_SERVER_COMBINED_OWNER"
local USED="PDIDDLER_SYSTEM1_ONE_SERVER_COMBINED_USED_JOB"
local PLACE=142823291
local FIRST="b24661781e72e3dec759960d2f4b423841961c8b"
local SECOND="b7d98b9b0815f72bff63fe7b58b8c92c59c3e0d7"
local CONTROL="833590724cf42e377599b79c61eea48fe87410b8"
local PREFIX="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local THIS_JOB=game.JobId
local Player=game:GetService("Players").LocalPlayer
local PG=Player and Player:FindFirstChildOfClass("PlayerGui")
local Http=game:GetService("HttpService")
if game.PlaceId~=PLACE or not Player or not PG or
 type(THIS_JOB)~="string" or #THIS_JOB==0 or
 E[KEY]~=nil or E[USED]==THIS_JOB or
 E.PDIDDLER_OUTGOING_SESSION~=nil or
 E.PDIDDLER_PART4_SESSION~=nil or
 E.PDIDDLER_SYSTEM1_STEP1_RECOVERY_OWNER~=nil or
 E.PDIDDLER_SYSTEM1_STEP2_PUBLIC_OWNER~=nil or
 E.PDIDDLER_SYSTEM1_COMBINED_TRANSITION_TOKEN~=nil then
 warn("[SYSTEM1 ONE SERVER] fresh original MM2 job without other trading controllers required")
 return nil
end
local function pinned(rev,path,min,max)
 local ok,src=pcall(function()
  return game:HttpGet(PREFIX..rev.."/pdiddler/"..path)
 end)
 if not ok or type(src)~="string" or
  #src<(min or 80) or #src>(max or 70000) then
  return nil
 end
 return src
end
local sourceController=pinned(
 CONTROL,"system1/system1_one_server_transition_controller.lua",2000,15000)
local compiler=loadstring or load
if not sourceController or type(compiler)~="function" then
 warn("[SYSTEM1 ONE SERVER] reviewed transition module unavailable")
 return nil
end
local okModule,Controller=pcall(function()
 return assert(compiler(sourceController))()
end)
if not okModule or type(Controller)~="table" or
 type(Controller.new)~="function" then
 warn("[SYSTEM1 ONE SERVER] transition module refused")
 return nil
end
local owner={job=THIS_JOB,running=true,phase="STARTING"}
E[KEY]=owner
local firstRunner=nil
local secondRunner=nil
local lastJson=nil
local runNonce="GUID_UNAVAILABLE"
pcall(function()runNonce=Http:GenerateGUID(false) end)
local function jobMatches()
 return game.JobId==THIS_JOB and game.PlaceId==PLACE and
    E[KEY]==owner and PG.Parent==Player
end
local function visible(obj)
 local ok,yes=pcall(function()
  local p=obj
  while p do
   if p:IsA("ScreenGui") and not p.Enabled then return false end
   if p:IsA("GuiObject") and not p.Visible then return false end
   p=p.Parent
  end
  return true
 end)
 return ok and yes==true
end
local function noTradeOrPending()
 local guiNames={"TradeGUI","TradeGUI_Phone"}
 for _,name in ipairs(guiNames)do
  local g=PG:FindFirstChild(name)
  if g and g:IsA("ScreenGui") and g.Enabled then
   local c=g:FindFirstChild("Container")
   local t=c and c:FindFirstChild("Trade")
   if t and visible(t) then return false end
  end
 end
 local roots={PG}
 if type(gethui)=="function" then
  local ok,root=pcall(gethui)
  if not ok then return false end
  if root then roots[#roots+1]=root end
 end
 for _,root in ipairs(roots)do
  local ok,desc=pcall(function()return root:GetDescendants()end)
  if not ok or type(desc)~="table" then return false end
  for _,v in ipairs(desc)do
   if visible(v) and
     (v:IsA("TextLabel") or v:IsA("TextButton") or
      v:IsA("TextBox")) then
    local yes,txt=pcall(function()return tostring(v.Text or "") end)
    if not yes then return false end
    local upper=txt:upper()
    if upper:find("TRADE REQUEST PENDING",1,true) or
       upper:find("TRADE REQUEST FROM",1,true) or
       upper:find("INCOMING TRADE REQUEST",1,true) or
       upper:find("SENT YOU A TRADE REQUEST",1,true) then
      return false
    end
   end
  end
 end
 return true
end
local function quiescent()
 if not jobMatches() or not firstRunner then return {safe=false}end
 local r=firstRunner.status()
 if type(r)~="table" or r.phase~="DONE" or
    r.completedRounds~=3 or
    E.PDIDDLER_SYSTEM1_STEP1_RECOVERY_OWNER~=nil or
    E.PDIDDLER_SYSTEM1_STEP1_RECOVERY_USED_JOB~=THIS_JOB or
    E.PDIDDLER_PART4_SESSION~=nil or
    E.PDIDDLER_SYSTEM1_STEP2_PUBLIC_OWNER~=nil then
  return {safe=false}
 end
 local epoch=E.PDIDDLER_OUTGOING_SESSION
 if type(epoch)~="number" or epoch<1 or
    epoch~=math.floor(epoch) or not noTradeOrPending() then
  return {safe=false}
 end
 return {safe=true,epoch=epoch}
end
local function loadScript(rev,path,min,max)
 local src=pinned(rev,path,min,max)
 if not src then return nil end
 local okay,res=pcall(function()
  return assert(compiler(src))()
 end)
 return okay and type(res)=="table" and res or nil
end
local function emit(r)
 local data={}
 for k,v in pairs(r)do data[k]=v end
 data.runNonce=runNonce
 data.gameJobIdNeverReported=true
 data.oneServerOnly=true
 data.finalAcceptEverAttempted=false
 data.serverCompletionProven=false
 data.verifiedCompletedTrades=0
 data.tradeOutcome="UNKNOWN"
 local ok,json=pcall(Http.JSONEncode,Http,data)
 if not ok or type(json)~="string" then
  warn("[SYSTEM1 COMBINED] unable to encode sanitized report")
  return false
 end
 lastJson=json
 E.PDIDDLER_SYSTEM1_ONE_SERVER_LAST_JSON=json
 print("[SYSTEM1 COMBINED JSON] "..json)
 local clipboard=type(setclipboard)=="function" and setclipboard or
   type(toclipboard)=="function" and toclipboard or
   type(E.setclipboard)=="function" and E.setclipboard
 if clipboard then pcall(clipboard,json) end
 return true
end
local function launchStep1()
 if not jobMatches() or firstRunner or
    E.PDIDDLER_OUTGOING_SESSION~=nil then return false end
 firstRunner=loadScript(
  FIRST,"system1/SYSTEM1_STEP1_ALT_DYNAMIC_RECOVERY_NATIVE.lua",
  15000,70000)
 return type(firstRunner)=="table" and
    type(firstRunner.status)=="function" and
    type(firstRunner.stop)=="function"
end
local function launchStep2(retiredEpoch)
 if not jobMatches() or secondRunner or
    type(retiredEpoch)~="number" or
    retiredEpoch~=E.PDIDDLER_OUTGOING_SESSION or
    not quiescent().safe then return false end
 -- Part3's last epoch is a retired tombstone. Never clear it or
 -- revert it; this token lets ONLY the pinned combined Step2 fork
 -- advance to a fresh epoch after the old request owner stopped.
 local permit={
  source="SYSTEM1_COMBINED_PINNED",
  job=THIS_JOB,
  status="STEP1_VERIFIED_CLOSED",
  used=false,retiredP3Epoch=retiredEpoch,
 }
 E.PDIDDLER_SYSTEM1_COMBINED_TRANSITION_TOKEN=permit
 secondRunner=loadScript(
   SECOND,"system1/SYSTEM1_COMBINED_STEP2_BOUND_EPOCH_NATIVE.lua",
   15000,70000)
 E.PDIDDLER_SYSTEM1_COMBINED_TRANSITION_TOKEN=nil
 if not secondRunner or permit.used~=true or
    type(secondRunner.status)~="function" or
    type(secondRunner.stop)~="function" or
    E.PDIDDLER_OUTGOING_SESSION~=retiredEpoch then
  return false
 end
 -- Hide Step1 presentation after its successful terminal ledger, not
 -- its controller/receipts; the original Step2 GUI now owns the screen.
 pcall(function()
  local gui=PG:FindFirstChild("PDIDDLER_System1_Step1_ALT_Recovery")
  if gui and gui:IsA("ScreenGui") then gui.Enabled=false end
 end)
 print("[SYSTEM1 ONE SERVER] STEP 1 3/3 locked; Step2 panel now available. ARM MAX 3 once.")
 return true
end
local function stopActive()
 if secondRunner then
  pcall(secondRunner.stop)
 elseif firstRunner then
  pcall(firstRunner.stop)
 end
 E.PDIDDLER_SYSTEM1_COMBINED_TRANSITION_TOKEN=nil
 owner.running=false
 E[USED]=THIS_JOB
 return true
end
local api={
 launchStep1=launchStep1,
 step1Status=function()return firstRunner and firstRunner.status()end,
 quiescent=quiescent,
 launchStep2=launchStep2,
 step2Status=function()return secondRunner and secondRunner.status()end,
 jobMatches=jobMatches,
 stopActive=stopActive,
 emit=emit,
}
local engine,why=Controller.new(api,{
 oneServerOnly=true,noFinalAccept=true,
 noItemTransfer=true,noServerHop=true,
})
if not engine then
 E[KEY]=nil
 warn("[SYSTEM1 ONE SERVER] transition controller default closed",why)
 return nil
end
local ok,begin=pcall(engine.start,os.clock())
if not ok or begin~=true then
 E[KEY]=nil
 E[USED]=THIS_JOB
 warn("[SYSTEM1 ONE SERVER] Step1 source missing or startup denied")
 return nil
end
local started=pcall(function()
 task.spawn(function()
  while owner.running and jobMatches() do
   local good,r=pcall(engine.tick,os.clock())
   if not good or type(r)~="table" then
    engine.stop()
    break
   end
   if r.phase=="STOPPED" or r.phase=="DONE" or
      r.phase=="INCONCLUSIVE" then
    print("[SYSTEM1 ONE SERVER] Final phase",r.phase,r.reason)
    break
   end
   task.wait(0.2)
  end
  if owner.running and not jobMatches() then
   engine.stop()
  end
 end)
end)
if not started then engine.stop()end
E.PDIDDLER_SYSTEM1_ONE_SERVER_RUNNER={
 status=function()return engine.status()end,
 stop=function()return engine.stop()end,
 copy=function()return engine.copy()end,
}
print("[SYSTEM1 ONE SERVER] Step1 ALT ARM3 panel is active. Same-job Step2 automatically appears AFTER exact Step1 PASS.")
return E.PDIDDLER_SYSTEM1_ONE_SERVER_RUNNER
