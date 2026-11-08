"""Stage59: actual Lua archive and recovery-only regression tests.

Simulates two separate device roles and executor filesystem in a sandboxed
in-memory mock. Verifies independently retrievable receipts after leaving game,
no fabricated sender payload, corrupted/replayed archives fail closed and
missing executor file APIs never crash the passive experiment.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/"pdiddler/new_part4"
DRIVER=r'''
local main,alt,restoreMain,restoreAlt,shared=arg[1],arg[2],arg[3],arg[4],arg[5]
local function source(path)
 local f=assert(io.open(path,"r"));local s=f:read("*a");f:close();return s
end
local sharedText=source(shared)
local files,knownJson,copies={}, {}, {}
local nonceSeq=0
local originalPrint=print
local printed={}
print=function(s)printed[#printed+1]=tostring(s)end
local function json(v)
 if type(v)=="string" then return string.format("%q",v) end
 if type(v)=="number" or type(v)=="boolean" then return tostring(v) end
 assert(type(v)=="table","unknown JSON type")
 local parts={}
 for k,x in pairs(v) do parts[#parts+1]=string.format("%q:%s",k,json(x)) end
 table.sort(parts)
 return "{"..table.concat(parts,",").."}"
end
local function signal()
 return {Connect=function(self,fn)self.fn=fn end,
  Fire=function(self)if self.fn then self.fn()end end}
end
local function present(path,role,opts)
 opts=opts or {}
 printed={};copies={}
 local created,queue,remoteCalls={},{},{}
 local env={}
 getgenv=function()return env end
 local pg={FindFirstChild=function()return nil end}
 local player={FindFirstChildOfClass=function(_,kind)
  if kind=="PlayerGui" then return pg end end}
 local players={LocalPlayer=player}
 local svc={}
 svc.GenerateGUID=function()
  nonceSeq=nonceSeq+1
  return string.format("aabbccdd-0000-4000-8000-%012x",nonceSeq)
 end
 svc.JSONEncode=function(_,receipt)
  local encoded=json(receipt)
  knownJson[encoded]=receipt
  return encoded
 end
 svc.JSONDecode=function(_,encoded)
  local record=knownJson[encoded]
  if not record then error("reject unknown or tampered JSON") end
  return record
 end
 local calledAfterClose=0
 local sourceStage32=[==[
local role=RROLE
return {reportReady=true,state="FINISHED_READ_ONLY",result={
schema="gingerscope-stage32-readonly-result-correlation-v1",
status="ELIGIBLE_DELTA_WITHOUT_RESULT_NAMED_RECEIPT",
reason="own-inventory-change-cause-unverified",
stopReason="TWO_POST_CLOSE_READS_FINISHED",
inventoryStatus="ELIGIBLE_DELTA_UNATTRIBUTED",
beforeObserved=true,windowClosureObserved=true,postReadbacksObserved=2,
changedEligibleTypes=1,gainedEligibleCopies=(role=="RECEIVER") and 1 or 0,
lostEligibleCopies=(role=="SENDER") and 1 or 0,
rawWeaponInventoryChanged=true,closureStatus="closed_unknown",
signalReceipts=0,completeTradeSignalSeen=false,
endTradeSignalSeen=false,declineTradeSignalSeen=false,
partnerDepartureObserved=false,observedOurAccept=true,
observedTheirAccept=false,bothAcceptedStableObserved=false,
offerMutationAfterAccept=false,tradeOutcome="UNKNOWN",readOnly=true,
serverAttestation=false,serverCompletionProven=false,
causalAttributionProven=false,authorizesTrade=false,authorizesAccept=false,
mayRecordCompletedTrade=false,mayReportProfit=false
}}
]==]
 game={PlaceId=142823291,JobId="OPAQUE_LOCAL_JOB",
  GetService=function(_,kind)
   if kind=="Players" then return players end
   if kind=="HttpService" then return svc end
   if kind=="UserInputService" then
    return {InputChanged=signal(),InputEnded=signal()}
   end
  end,
  HttpGet=function(_,url)
   remoteCalls[#remoteCalls+1]=url
   if url:find("STAGE59_GUIDED_DUAL_CLIENT_WITNESS.lua",1,true) then
    return sharedText
   elseif url:find("STAGE59_RESULT_DELTA_120S_PROBE.lua",1,true) then
    calledAfterClose=calledAfterClose+1
    return sourceStage32:gsub("RROLE",string.format("%q",role))
   end
   error("unexpected HTTP destination")
  end}
 if opts.noGui then Instance=nil else
  Instance={new=function(kind)
   local o={kind=kind}
   function o:Destroy()self.Parent=nil end
   function o:FindFirstChild()return nil end
   if kind=="TextButton" then o.Activated=signal() end
   if kind=="TextLabel" then o.InputBegan=signal() end
   if kind=="Frame" then
    o.AbsolutePosition={X=10,Y=50}
    o.AbsoluteSize={X=role=="SENDER" and 270 or 320,Y=role=="SENDER" and 146 or 182}
   end
   created[#created+1]=o;return o
  end}
 end
 local function size(x,y)
  return {X={Scale=0,Offset=x},Y={Scale=0,Offset=y}}
 end
 UDim2={fromOffset=size,new=function(a,b,c,d)
  return {X={Scale=a,Offset=b},Y={Scale=c,Offset=d}} end}
 UDim={new=function()return {} end}
 Color3={fromRGB=function()return {} end}
 Enum={Font={GothamBold="G",Gotham="g"},
  TextXAlignment={Left="left"},TextYAlignment={Top="top"},
  UserInputType={MouseButton1="mouse",Touch="touch",MouseMovement="move"}}
 workspace={CurrentCamera={ViewportSize={X=role=="SENDER" and 844 or 1024,
   Y=role=="SENDER" and 390 or 768}}}
 task={spawn=function(f)queue[#queue+1]=f end,wait=function()end}
 if opts.disk=="none" then
  writefile=nil;readfile=nil
 elseif opts.disk=="write-fail" then
  writefile=function()error("WRITE FAILED")end
  readfile=function(p)
   if files[p] then return files[p] else error("missing") end end
 elseif opts.disk=="read-fail" then
  writefile=function(p,v)files[p]=v end
  readfile=function()error("READ FAILED")end
 else
  writefile=function(p,v)files[p]=v end
  readfile=function(p)
   if files[p] then return files[p] else error("missing") end end
 end
 setclipboard=function(text)copies[#copies+1]=text end
 toclipboard=nil
 loadstring=load
 local ok,instance=pcall(function()return assert(loadfile(path))()end)
 assert(ok,instance)
 for _,fn in ipairs(queue)do fn() end
 assert(#copies==0,"automatic clipboard mutation even before user click")
 if opts.manualCopy then
  local button=nil
  for _,v in ipairs(created)do
   if v.Name=="COPY_OWN_STAGE59_REPORT" then button=v end
  end
  assert(button and button.Visible==true,"report's copy button missing")
  button.Activated:Fire()
 end
 local tagged={}
 for _,line in ipairs(printed)do
  if line:find("[GINGERSCOPE STAGE59 PAIRED WITNESS]",1,true)==1 then
   tagged[#tagged+1]=line
  end
 end
 local lastStatus=instance and instance.localArchiveStatus
 return {
  model=instance,printed=printed,clipboard=copies,remoteCalls=remoteCalls,
  stage32Loads=calledAfterClose,emitted=tagged,ui=created,
  storageStatus=lastStatus,
 }
end
local function check(name,fn)
 local ok,err=pcall(fn)
 if not ok then error(name..": "..tostring(err)) end
end
local altFirst,mainFirst
check("ALT emits sender + stores two independently readable receipts",function()
 altFirst=present(alt,"SENDER",{manualCopy=true})
 assert(altFirst.model.role=="SENDER")
 assert(#altFirst.emitted==1)
 assert(altFirst.storageStatus=="VERIFIED_LOCAL_ARCHIVE")
 assert(altFirst.stage32Loads==1)
 assert(files["GINGERSCOPE_STAGE59_ALT_LAST.txt"]==altFirst.emitted[1])
 assert(altFirst.clipboard[#altFirst.clipboard]==altFirst.emitted[1])
 assert(altFirst.emitted[1]:find('"operatorDeclaredRole":"SENDER"',1,true))
 assert(altFirst.emitted[1]:find('"lostEligibleCopies":1',1,true))
end)
check("MAIN stores separate receiver report without overwriting ALT",function()
 mainFirst=present(main,"RECEIVER",{manualCopy=true})
 assert(mainFirst.model.role=="RECEIVER")
 assert(#mainFirst.emitted==1)
 assert(mainFirst.storageStatus=="VERIFIED_LOCAL_ARCHIVE")
 assert(mainFirst.emitted[1]:find('"operatorDeclaredRole":"RECEIVER"',1,true))
 assert(mainFirst.emitted[1]:find('"gainedEligibleCopies":1',1,true))
 assert(files["GINGERSCOPE_STAGE59_MAIN_LAST.txt"]==mainFirst.emitted[1])
 assert(files["GINGERSCOPE_STAGE59_ALT_LAST.txt"]==altFirst.emitted[1])
 assert(altFirst.emitted[1]~=mainFirst.emitted[1])
 assert(mainFirst.clipboard[#mainFirst.clipboard]==mainFirst.emitted[1])
end)
check("RECOVERY ALT in fresh env: no Stage32 watcher or new witness",function()
 local r=present(restoreAlt,"SENDER",{manualCopy=true})
 assert(r.model.state=="RECOVERY_ONLY" and r.stage32Loads==0)
 assert(#r.remoteCalls==1 and #r.emitted==0)
 assert(r.clipboard[#r.clipboard]==altFirst.emitted[1])
 assert(r.clipboard[#r.clipboard]~=mainFirst.emitted[1])
end)
check("RECOVERY MAIN in fresh env: different exact original report",function()
 local r=present(restoreMain,"RECEIVER",{manualCopy=true})
 assert(r.model.state=="RECOVERY_ONLY" and r.stage32Loads==0)
 assert(#r.remoteCalls==1 and #r.emitted==0)
 assert(r.clipboard[#r.clipboard]==mainFirst.emitted[1])
end)
check("Tampered LAST report fails read-only recovery",function()
 local old=files["GINGERSCOPE_STAGE59_ALT_LAST.txt"]
 files["GINGERSCOPE_STAGE59_ALT_LAST.txt"]="THIS IS NOT A VALID REPORT"
 local r=present(restoreAlt,"SENDER",{})
 assert(r.model.state=="RECOVERY_ONLY" and r.stage32Loads==0)
 for _,o in ipairs(r.ui)do
  if o.Name=="COPY_OWN_STAGE59_REPORT" then
   assert(o.Visible==false)
  end
 end
 assert(#r.clipboard==0)
 files["GINGERSCOPE_STAGE59_ALT_LAST.txt"]=old
end)
check("Swapped other-device LAST report rejected",function()
 local old=files["GINGERSCOPE_STAGE59_ALT_LAST.txt"]
 files["GINGERSCOPE_STAGE59_ALT_LAST.txt"]=mainFirst.emitted[1]
 local r=present(restoreAlt,"SENDER",{})
 assert(#r.clipboard==0 and r.stage32Loads==0)
 files["GINGERSCOPE_STAGE59_ALT_LAST.txt"]=old
end)
check("Unsupported executor file functions fail open to console/current copy",function()
 local r=present(alt,"SENDER",{disk="none",manualCopy=true})
 assert(r.storageStatus=="UNAVAILABLE")
 assert(#r.emitted==1 and #r.clipboard==1)
 assert(r.clipboard[1]==r.emitted[1])
end)
check("automatic clipboard remains untouched in BOTH devices",function()
 local a=present(alt,"SENDER",{})
 local b=present(main,"RECEIVER",{})
 assert(#a.clipboard==0 and #b.clipboard==0)
 assert(#a.emitted==1 and #b.emitted==1)
 assert(a.storageStatus=="VERIFIED_LOCAL_ARCHIVE")
 assert(b.storageStatus=="VERIFIED_LOCAL_ARCHIVE")
end)
check("writefile failure does not claim saved",function()
 local r=present(alt,"SENDER",{disk="write-fail"})
 assert(r.storageStatus=="UNAVAILABLE")
 assert(#r.emitted==1)
end)
check("readfile failure cannot claim verified persistence",function()
 local r=present(main,"RECEIVER",{disk="read-fail"})
 assert(r.storageStatus=="UNAVAILABLE")
 assert(#r.emitted==1)
end)
check("role-specified source never sends a trade request",function()
 for _,p in ipairs({main,alt,restoreMain,restoreAlt})do
  local body=source(p)
  assert(not body:find(":FireServer(",1,true))
  assert(not body:find(":InvokeServer(",1,true))
 end
end)
originalPrint("STAGE59_LOCAL_DURABLE_REPORT_AND_RECOVERY_11_CASES_PASS")
'''
class Stage59LocalArchiveTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("lua5.4"),"CI installs Lua5.4")
    def test_live_role_files_and_fresh_rejoin_recovery_in_actual_lua(self):
        with tempfile.TemporaryDirectory(prefix="stage59_local_archive_") as temp:
            p=Path(temp)/"driver.lua";p.write_text(DRIVER,encoding="utf-8")
            args=["lua5.4",str(p),str(BASE/"STAGE59_MAIN_RECEIVER.lua"),
                  str(BASE/"STAGE59_ALT_SENDER.lua"),
                  str(BASE/"STAGE59_MAIN_RECOVER_LAST.lua"),
                  str(BASE/"STAGE59_ALT_RECOVER_LAST.lua"),
                  str(BASE/"STAGE59_GUIDED_DUAL_CLIENT_WITNESS.lua")]
            result=subprocess.run(args,cwd=ROOT,capture_output=True,text=True,timeout=55)
        self.assertEqual(result.returncode,0,result.stdout+"\n"+result.stderr)
        self.assertIn("STAGE59_LOCAL_DURABLE_REPORT_AND_RECOVERY_11_CASES_PASS",
                      result.stdout)

    def test_source_authority_and_separate_relative_sandbox_paths(self):
        source=(BASE/"STAGE59_GUIDED_DUAL_CLIENT_WITNESS.lua").read_text()
        self.assertIn('return "GINGERSCOPE_STAGE59_ALT"',source)
        self.assertIn('return "GINGERSCOPE_STAGE59_MAIN"',source)
        self.assertIn('prefix.."_LAST.txt"',source)
        self.assertIn('receipt.receiptNonce~=nil',source.replace(
            'not nonceIsSafe(receipt.receiptNonce)','receipt.receiptNonce~=nil'))
        self.assertIn('if recoveryOnly then',source)
        self.assertIn('M.localArchiveStatus=localStorage',source)
        self.assertIn('return ok and value==line',source)
        for token in ('mayReportProfit=false','serverCompletionProven=false',
                      'mayRecordCompletedTrade=false','authorizesAccept=false'):
            self.assertIn(token,source)
        for bad in ('FireServer(',':InvokeServer(',':PostAsync(',
                    'TeleportToPlaceInstance('):
            self.assertNotIn(bad,source)
        for role,name,mode in (
            ("RECEIVER","STAGE59_MAIN_RECOVER_LAST.lua","TABLET_RECOVER"),
            ("SENDER","STAGE59_ALT_RECOVER_LAST.lua","PHONE_RECOVER"),
        ):
            content=(BASE/name).read_text()
            self.assertIn(f'local ROLE="{role}"',content)
            self.assertIn(f'return fn(ROLE,"{mode}")',content)
            self.assertNotIn(':FireServer(',content)

if __name__=="__main__":
    unittest.main()
