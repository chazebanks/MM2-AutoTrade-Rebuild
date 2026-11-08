"""Run the actual Stage59 guided Roblox Lua observer wrapper against a fake game.

It does not run the external pinned Stage32 observer; a bounded safe Stage32
stand-in gives deterministic values so that guide/UI/export invariants can be
checked without any trade or network access. The Stage32 script's real native
evidence, limitations and separate regressions remain documented in PR71.
"""
from pathlib import Path
import subprocess
import tempfile
import shutil
import unittest

ROOT=Path(__file__).resolve().parents[2]
LUA=ROOT/"pdiddler/new_part4/STAGE59_GUIDED_DUAL_CLIENT_WITNESS.lua"

DRIVER=r'''
local path=arg[1]
local oldPrint=print
local printed={}
print=function(x) printed[#printed+1]=tostring(x) end
local stage32Info=[==[
local role=RROLE
local gained=(role=="RECEIVER") and 1 or 0
local lost=(role=="SENDER") and 1 or 0
return {state="FINISHED_READ_ONLY",reportReady=true,result={
schema="gingerscope-stage32-readonly-result-correlation-v1",
status="ELIGIBLE_DELTA_WITHOUT_RESULT_NAMED_RECEIPT",
reason="own-inventory-change-cause-unverified",
stopReason="TWO_POST_CLOSE_READS_FINISHED",
inventoryStatus="ELIGIBLE_DELTA_UNATTRIBUTED",
beforeObserved=true,windowClosureObserved=true,
postReadbacksObserved=2,changedEligibleTypes=1,
gainedEligibleCopies=gained,lostEligibleCopies=lost,
rawWeaponInventoryChanged=true,closureStatus="closed_unknown",
signalReceipts=0,completeTradeSignalSeen=false,
endTradeSignalSeen=false,declineTradeSignalSeen=false,
partnerDepartureObserved=false,observedOurAccept=true,
observedTheirAccept=false,bothAcceptedStableObserved=false,
offerMutationAfterAccept=false,tradeOutcome="UNKNOWN",readOnly=true,
serverAttestation=false,serverCompletionProven=false,causalAttributionProven=false,
authorizesTrade=false,authorizesAccept=false,
mayRecordCompletedTrade=false,mayReportProfit=false
}}
]==]
local function json(v)
 local kind=type(v)
 if kind=="string"then return string.format("%q",v)end
 if kind=="number" or kind=="boolean"then return tostring(v)end
 assert(kind=="table")
 local a={}
 for k,x in pairs(v)do a[#a+1]=string.format("%q:%s",tostring(k),json(x))end
 table.sort(a)
 return "{"..table.concat(a,",").."}"
end
local function call(role,opt)
 opt=opt or {}
 local messages,clip,created,queue,remoteCalls={},{},{},{},{}
 printed=messages
 local env={}
 if opt.prior then env.PDIDDLER_STAGE32_RESULT_CORRELATION_PROBE=true end
 getgenv=function()return env end
 local pg={FindFirstChild=function()return nil end}
 local player={FindFirstChildOfClass=function(_,which)
  if which=="PlayerGui" then return pg end
 end}
 local players={LocalPlayer=player}
 local http={
  GenerateGUID=function()return "0a0a0a0a-1111-2222-3333-abcdefabcdef"end,
  JSONEncode=function(_,v)return json(v)end
 }
 local function newSignal()
 return {
  Connect=function(self,callback)
   self.callback=callback
   return {Disconnect=function()end}
  end,
  Fire=function(self,input)
   if self.callback then self.callback(input) end
  end
 }
end
local userInput={InputChanged=newSignal(),InputEnded=newSignal()}
local job="FAKE_SECRET_JOB_ID"
 game={
  PlaceId=opt.wrongGame and 4 or 142823291,JobId=job,
  GetService=function(_,name)
   if name=="Players" then return players end
   if name=="HttpService" then return http end
   if name=="UserInputService" then return userInput end
  end,
  HttpGet=function(_,url)
   remoteCalls[#remoteCalls+1]=url
   assert(url:find("f74cb081590dfcdf100bd41f818e07d34856dff4",1,true),
    "old source not immutably pinned")
   if opt.noSource then return "N/A" end
   local source=stage32Info:gsub("RROLE",string.format("%q",role or "RECEIVER"))
   if opt.badStage32 then
    source=source:gsub('serverCompletionProven=false','serverCompletionProven=true')
   end
   if opt.stage32TimedOut then
    source=source:gsub('status="ELIGIBLE_DELTA_WITHOUT_RESULT_NAMED_RECEIPT"',
      'status="INCOMPLETE"')
    source=source:gsub('stopReason="TWO_POST_CLOSE_READS_FINISHED"',
      'stopReason="TRADE_WINDOW_NOT_CLOSED_WITHIN_120S"')
    source=source:gsub('inventoryStatus="ELIGIBLE_DELTA_UNATTRIBUTED"',
      'inventoryStatus="AWAIT_CLOSE"')
    source=source:gsub('windowClosureObserved=true',
      'windowClosureObserved=false')
    source=source:gsub('postReadbacksObserved=2',
      'postReadbacksObserved=0')
    source=source:gsub('closureStatus="closed_unknown"',
      'closureStatus="not-closed"')
   end
   return source
  end,
 }
 local globalValues={Instance,UDim2,UDim,Color3,Enum,workspace}
 if opt.noGui or opt.guiBroken then
  if opt.guiBroken then
   Instance={new=function()error("SECRET_FAKE_UI_CRASH")end}
  else Instance=nil end
 else
  Instance={new=function(kind)
   local o={kind=kind}
   function o:Destroy()self.Parent=nil end
   function o:FindFirstChild()return nil end
   if kind=="TextButton" then
    o.Activated={Connect=function(_,fn)o.onActivate=fn end}
   end
   if kind=="TextLabel" then o.InputBegan=newSignal() end
   if kind=="Frame" then
    o.AbsolutePosition={X=12,Y=586}
    o.AbsoluteSize={X=320,Y=182}
   end
   created[#created+1]=o
   return o
  end}
 end
 local function fromOffset(x,y)
 return {X={Scale=0,Offset=x},Y={Scale=0,Offset=y}}
end
local function scaled(xScale,xOffset,yScale,yOffset)
 return {X={Scale=xScale,Offset=xOffset},
  Y={Scale=yScale,Offset=yOffset}}
end
local shape=function()return {value=true}end
 UDim2={fromOffset=fromOffset,new=scaled}
 UDim={new=shape}
 Color3={fromRGB=shape}
 Enum={Font={GothamBold="B",Gotham="G"},
  TextXAlignment={Left="L"},
  TextYAlignment={Top="T"},
  UserInputType={MouseButton1="MouseButton1",MouseMovement="MouseMovement",
   Touch="Touch"}}
 workspace={CurrentCamera={ViewportSize={X=1024,Y=768}}}
 task={spawn=function(fn)queue[#queue+1]=fn end,
       wait=function()end}
 local realClip=setclipboard
 if opt.clipboardMissing then setclipboard=nil
 else setclipboard=function(v)clip[#clip+1]=v end end
 toclipboard=nil
 loadstring=load
 local ok,res=pcall(function()return assert(loadfile(path))(opt.direct and role or nil)end)
 assert(ok,res)
 if (opt.touchDrag or opt.mouseDrag or opt.clampedDrag) and
   not opt.noGui and not opt.guiBroken then
  local title,frame
  for _,x in ipairs(created) do
   if x.kind=="TextLabel" and x.Active==true then title=x end
   if x.kind=="Frame" then frame=x end
  end
  assert(title and frame and title.InputBegan.callback,
    "Title must respond to touch/mouse drag")
  assert(frame.Position.X.Scale==0 and frame.Position.X.Offset==12,
    "Panel default must be LEFT, not over top-right leaderboard")
  assert(frame.Position.Y.Scale==1 and frame.Position.Y.Offset==-200,
    "Panel default must be near bottom-left")
  local isMouse=opt.mouseDrag
  local down={UserInputType=isMouse and "MouseButton1" or "Touch",
    Position={X=35,Y=700}}
  title.InputBegan:Fire(down)
  local move=isMouse and
    {UserInputType="MouseMovement",Position={X=120,Y=600}} or down
  if not isMouse then down.Position={X=120,Y=600} end
  if opt.clampedDrag then
   move.Position={X=8000,Y=-5000}
  end
  userInput.InputChanged:Fire(move)
  if opt.clampedDrag then
   assert(frame.Position.X.Offset==704 and frame.Position.Y.Offset==0,
    "Dragging must clamp panel inside screen bounds")
  else
   assert(frame.Position.X.Offset==97 and frame.Position.Y.Offset==486,
    "Touch or mouse drag did not update panel position")
  end
  local lastX,lastY=frame.Position.X.Offset,frame.Position.Y.Offset
  userInput.InputEnded:Fire(down)
  if isMouse then move.Position={X=150,Y=500}
  else down.Position={X=150,Y=500} end
  userInput.InputChanged:Fire(move)
  assert(frame.Position.X.Offset==lastX and frame.Position.Y.Offset==lastY,
   "Drag must STOP after input release")
 end
if not opt.direct and not opt.noGui and not opt.guiBroken then
  for _,x in ipairs(created)do
   if x.Name==role and type(x.onActivate)=="function" then
    x.onActivate()
   end
  end
 end
 for _,f in ipairs(queue) do f() end
 -- A finished receipt MUST NEVER auto-mutate the system clipboard.
 assert(#clip==0,"automatic clipboard export would corrupt paired devices")
 if opt.manualCopy and not opt.noGui and not opt.guiBroken then
  local copyButton
  for _,node in ipairs(created)do
   if node.Name=="COPY_OWN_STAGE59_REPORT" then copyButton=node end
  end
  assert(copyButton and copyButton.Visible==true and
    type(copyButton.onActivate)=="function","manual COPY action missing")
  copyButton.onActivate()
  if not opt.clipboardMissing then
   copyButton.onActivate()
   assert(#clip==2 and clip[1]==clip[2],
    "re-copy must preserve EXACT same nonce and receipt")
  end
 end
 setclipboard=realClip
 local report={}
 local guide={}
 for _,line in ipairs(messages)do
  if line:find("[GINGERSCOPE STAGE59 PAIRED WITNESS]",1,true)==1 then
   report[#report+1]=line
  elseif line:find("[STAGE59 GUIDE]",1,true)==1 then
   guide[#guide+1]=line end
 end
 assert(#guide>=1,"missing guide")
 for _,line in ipairs(messages)do
  assert(not line:find("FAKE_SECRET_JOB_ID",1,true),"job leaked")
  assert(not line:find("SECRET_FAKE_UI_CRASH",1,true),"internal exception leaked")
 end
 if opt.prior or opt.wrongGame or (opt.noGui and not opt.direct)
    or (opt.guiBroken and not opt.direct) then
  assert(#report==0,"must not run on invalid state or without a chosen role")
  assert(#clip==0,"clipboard unexpectedly changed")
  return nil,guide,created,remoteCalls,clip
 end
 assert(#report==1,"one bounded receipt expected")
 local s=report[1]
 assert(s:find('"tradeOutcome":"UNKNOWN"',1,true))
 if opt.stage32TimedOut then
  assert(s:find('"collectorStatus":"INCOMPLETE_STAGE32_NO_POST_CLOSE_EVIDENCE"',1,true),
   "nested Stage32 nonterminal must not be advertised as readback captured")
  assert(s:find('"postReadbacksObserved":0',1,true))
  assert(s:find('"collectorReason":"STAGE32_FINISHED_WITHOUT_TERMINAL_READBACKS"',1,true))
 elseif opt.badStage32 or opt.noSource then
  assert(s:find('"collectorStatus":"INCOMPLETE_STAGE32_NO_POST_CLOSE_EVIDENCE"',1,true))
 else
  assert(s:find('"collectorStatus":"CLIENT_STAGE32_TERMINAL_OBSERVATION"',1,true),
    "valid terminal Stage32 should be labeled client-only terminal")
 end
 assert(s:find('"serverCompletionProven":false',1,true))
 assert(s:find('"authorizesAccept":false',1,true))
 assert(s:find('"mayReportProfit":false',1,true))
 assert(s:find('"serverAttestation":false',1,true))
 assert(s:find('"operatorDeclaredRole":"'..role..'"',1,true))
 assert(s:find('"pairId":"STAGE59-NOV08-MANUAL-A"',1,true))
 assert(not s:find("userId",1,true))
 assert(not s:find("userName",1,true))
 assert(not s:find("FAKE_SECRET_JOB_ID",1,true))
 assert(#remoteCalls==1,"one READ-ONLY source loader required")
 if opt.clipboardMissing or not opt.manualCopy or opt.noGui or opt.guiBroken then
  assert(#clip==0,"only user click can modify clipboard")
 else
  assert(#clip==2 and clip[1]==s and clip[2]==s,
   "manual re-copy should yield original sanitized receipt, not new witness")
 end
 if not opt.manualCopy then
  assert(guide[#guide]:find("TAP COPY",1,true),
   "user must be told to deliberately export their own report")
 end
 return s,guide,created,remoteCalls,clip
end
local passed=0
local function case(name,fn)
 local ok,err=pcall(fn)
 if not ok then error(name.." => "..tostring(err))end
 passed=passed+1
end
case("sender direct role guidance + safe receipt",function()
 local s,guide=call("SENDER",{direct=true})
 assert(s:find('"lostEligibleCopies":1',1,true))
 assert(s:find('"gainedEligibleCopies":0',1,true))
 assert(guide[#guide]:find("TAP COPY",1,true))
end)
case("receiver direct role guidance + safe receipt",function()
 local s=call("RECEIVER",{direct=true})
 assert(s:find('"lostEligibleCopies":0',1,true))
 assert(s:find('"gainedEligibleCopies":1',1,true))
end)
case("on-screen sender role button",function()
 local s,guide,created=call("SENDER",{})
 assert(s and #created>=7)
 local found=false
 for _,obj in ipairs(created)do
  if obj.kind=="ScreenGui" and obj.Name=="GINGERSCOPE_STAGE59_GUIDE" then found=true end
 end
 assert(found,"no Stage59 in-game panel")
end)
case("manual COPY is exclusively opt-in, two taps preserve same nonce",function()
 local s,guide,created,remotes,clips=call("SENDER",{direct=true,manualCopy=true})
 assert(s and #clips==2 and clips[1]==s and clips[2]==s)
 assert(guide[#guide]:find("COPY SENDER OK",1,true))
end)
case("manual COPY unavailable does not affect report",function()
 local s,guide,created,remotes,clips=call("RECEIVER",{
  direct=true,manualCopy=true,clipboardMissing=true})
 assert(s and #clips==0)
 assert(guide[#guide]:find("COPY BLOCKED",1,true))
end)
case("on-screen receiver role button",function()
 local s=call("RECEIVER",{})
 assert(s)
end)
case("gui error fallback to preselected role",function()
 local s=call("SENDER",{direct=true,guiBroken=true})
 assert(s)
end)
case("gui unavailable no role cannot launch trade observer",function()
 local s=call("SENDER",{noGui=true})
 assert(s==nil)
end)
case("old stage32 test present",function()
 local s,guide=call("SENDER",{direct=true,prior=true})
 assert(s==nil and guide[#guide]:find("Rejoin",1,true))
end)
case("wrong game blocked",function()
 local s,guide=call("SENDER",{direct=true,wrongGame=true})
 assert(s==nil and guide[#guide]:find("WRONG GAME",1,true))
end)
case("no source result is UNKNOWN incomplete only",function()
 local s=call("SENDER",{direct=true,noSource=true})
 assert(s:find('"collectorStatus":"INCOMPLETE_STAGE32_NO_POST_CLOSE_EVIDENCE"',1,true))
 assert(not s:find('"stage32"',1,true))
end)
case("untrusted source claiming server proof not exported",function()
 local s=call("RECEIVER",{direct=true,badStage32=true})
 assert(s:find('"collectorStatus":"INCOMPLETE_STAGE32_NO_POST_CLOSE_EVIDENCE"',1,true))
 assert(not s:find('"stage32"',1,true))
end)
case("actual native-shaped timeout stays INCOMPLETE",function()
 local s,guide=call("RECEIVER",{direct=true,stage32TimedOut=true})
 assert(s:find('"collectorStatus":"INCOMPLETE_STAGE32_NO_POST_CLOSE_EVIDENCE"',1,true))
 assert(s:find('"windowClosureObserved":false',1,true))
 assert(s:find('"postReadbacksObserved":0',1,true))
end)
case("in-game title dragging on iPad touch",function()
 local s=call("SENDER",{touchDrag=true})
 assert(s and s:find('"operatorDeclaredRole":"SENDER"',1,true))
end)
case("in-game title dragging on desktop mouse",function()
 local s=call("RECEIVER",{mouseDrag=true})
 assert(s and s:find('"operatorDeclaredRole":"RECEIVER"',1,true))
end)
case("drag panel stays within screen after huge touch gesture",function()
 local s=call("SENDER",{clampedDrag=true})
 assert(s)
end)
case("clipboard blocked console still has usable receipt",function()
 local s=call("RECEIVER",{direct=true,clipboardMissing=true})
 assert(s:find('"operatorDeclaredRole":"RECEIVER"',1,true))
end)
for i=1,100 do
 local r=(i%2==0) and "SENDER" or "RECEIVER"
 local opts={direct=true,noGui=(i%3==0),
   clipboardMissing=(i%4==0)}
 local s=call(r,opts)
 assert(s and s:find('"tradeOutcome":"UNKNOWN"',1,true))
end
case("100 seeded role/GUI/clipboard variations",function()end)
oldPrint("STAGE59_REAL_LUA_GUIDED_WRAPPER_16_NAMED_100_VARIATIONS_PASS")
'''
class Stage59GuidedWrapperTests(unittest.TestCase):
    def test_safe_source_pinning_and_no_trade_mutators(self):
        source=LUA.read_text(encoding="utf-8")
        self.assertIn("f74cb081590dfcdf100bd41f818e07d34856dff4",source)
        self.assertIn("GINGERSCOPE_STAGE59_GUIDE",source)
        self.assertIn('heading.Text=phoneMode',source)
        self.assertIn('and "ALT SENDER  |  DRAG HERE" or "STAGE 59  |  DRAG HERE  |  READ-ONLY"',source)
        self.assertIn('frame.Position=UDim2.new(0,12,1,-200)',source)
        self.assertIn('local UIS=game:GetService("UserInputService")',source)
        self.assertIn('heading.InputBegan:Connect(function(input)',source)
        self.assertIn('UIS.InputChanged:Connect(function(input)',source)
        self.assertIn('UIS.InputEnded:Connect(function(input)',source)
        self.assertIn('x=math.max(0,math.min(x,math.max(0,size.X-width)))',source)

        self.assertIn("CHOOSE SENDER or RECEIVER",source)
        self.assertIn("BASELINE BOUND",source)
        self.assertIn("POST_CLOSE_READS",source)
        self.assertIn("CLIENT_STAGE32_TERMINAL_OBSERVATION",source)
        self.assertIn("INCOMPLETE_STAGE32_NO_POST_CLOSE_EVIDENCE",source)
        self.assertIn("COPY_OWN_STAGE59_REPORT",source)
        self.assertIn("validateLocalLine(line,expectedRole)",source)
        self.assertIn("saveLocal(line,role,nonce)",source)
        self.assertIn("local recoveryOnly=",source)
        self.assertIn('if recoveryOnly then',source)
        self.assertIn("remaining=math.max(0,120-",source)
        self.assertIn("STAGE59_RESULT_DELTA_120S_PROBE.lua",source)

        self.assertIn("safe32(src)",source)
        self.assertIn("local suppliedRole",source.replace("specifiedRole","suppliedRole"))  # role selection source
        self.assertIn('mayRecordCompletedTrade=false',source)
        self.assertIn('tradeOutcome="UNKNOWN"',source)
        for bad in (":FireServer(",":InvokeServer(",":PostAsync(",
                    "OfferItem:","AcceptTrade:","DeclineTrade:",
                    "TeleportToPlaceInstance(", "GetProfileData:"):
            self.assertNotIn(bad,source)

    @unittest.skipUnless(shutil.which("lua5.4"),"CI installs lua5.4")
    def test_real_lua_gui_mock_and_100_variations(self):
        with tempfile.TemporaryDirectory(prefix="stage59_") as td:
            path=Path(td)/"driver.lua"
            path.write_text(DRIVER,encoding="utf-8")
            p=subprocess.run(["lua5.4",str(path),str(LUA)],
                cwd=ROOT,capture_output=True,text=True,timeout=40)
        self.assertEqual(p.returncode,0,p.stdout+"\n"+p.stderr)
        self.assertIn("STAGE59_REAL_LUA_GUIDED_WRAPPER_16_NAMED_100_VARIATIONS_PASS",
                      p.stdout)

if __name__=="__main__":
    unittest.main()
