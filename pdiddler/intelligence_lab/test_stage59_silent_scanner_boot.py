"""Stage59 silent Stage25 scanner: real Lua source behavior and structural parity.

The original Stage25 boot schedules a separate auto-copied inventory diagnostic;
the isolated Stage59 fork must load the same scanner dependencies WITHOUT that
clipboard mutation, even when the user has two Apple devices.
"""
from pathlib import Path
import hashlib
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
P=ROOT/"pdiddler/new_part4"
ORIG=ROOT/"pdiddler/intelligence_lab/fixtures/STAGE25_SCANNER_ONLY_BOOT_ORIGINAL.lua"
SILENT=P/"STAGE59_SCANNER_SILENT_BOOT.lua"
EXPECTED_ORIGINAL_GIT_BLOB="92cd0cb482524d7c6ca6de0962ec57b6a69522ca"
DRIVER=r'''
local original,silent=arg[1],arg[2]
local realPrint=print
local function run(script,isSilent)
 local calls,clips,queues={},{},0
 local env={PDIDDLER_ALLOW_SCANNER_ONLY_TEST=true}
 getgenv=function()return env end
 loadstring=load
 setclipboard=function(x)clips[#clips+1]=x end
 print=function()end
 warn=function()end
 local t=0
 os.clock=function()t=t+0.4;return t end
 local me={UserId=101}
 local players={LocalPlayer=me,GetPlayers=function()return {me}end}
 local modules={
  snapshots=[==[return {isFresh=function()return false end,
    coverage=function()return {total=190}end}]==],
  repricer=[==[return {reprice=function()end}]==],
  view=[==[return {inventory=function()end}]==],
  scanner=[==[local profile,reprice,view=...
    return {getRecord=function()return {}end,
      getVerificationState=function()return {scanning=false}end,
      getOwnInventory=function()return {items={}}end}
    ]==],
  probe=[==[
   if type(setclipboard)=="function"then
    setclipboard("UNSOLICITED_OLD_STAGE25_CLIPBOARD_MUTATION")
   end
   return {report="AUTO"}
  ]==]
 }
 game={PlaceId=142823291,JobId="SANDBOX_STAGE59",
  GetService=function(_,name)
   if name=="Players"then return players end
  end,
  HttpGet=function(_,url)
   calls[#calls+1]=url
   if url:find("snapshots/pdiddler_supreme_snapshot",1,true) then
    return modules.snapshots.."\n--"..string.rep("a",90)
   elseif url:find("new_part4/P4_REPRICE_ONLY",1,true)then
    return modules.repricer.."\n--"..string.rep("a",90)
   elseif url:find("presentation/pdiddler3_scanner_view_v1",1,true)then
    return modules.view.."\n--"..string.rep("a",90)
   elseif url:find("presentation/pdiddler3_scanner_MODULE_",1,true)then
    return modules.scanner.."\n--"..string.rep("a",90)
   elseif url:find("STAGE25_READONLY_DIAGNOSTIC",1,true)then
    return modules.probe.."\n--"..string.rep("a",90)
   end
   error("unexpected source fetch "..tostring(url))
  end}
 task={
  wait=function()end,
  spawn=function(fn) queues=queues+1;fn()end
 }
 local ok,owner=pcall(function()return assert(loadfile(script))()end)
 assert(ok,owner)
 assert(type(owner)=="table")
 assert(owner.status=="SCANNER_ONLY_NO_TRADE_AUTHORITY",
  "scanner status="..tostring(owner.status).." failure="..tostring(owner.failure)..
  " calls="..tostring(#calls))
 assert(owner.marketFresh==false and owner.noOutgoing==true)
 assert(owner.authorizesTrade==false and owner.authorizesAccept==false)
 assert(#calls>=4 and #calls<=5)
 if isSilent then
  assert(queues==0 and #calls==4,"silent scanner must not spawn extra diagnostic")
  assert(#clips==0,"silent Stage59 source wrote OS clipboard")
  assert(owner.probeStatus=="STAGE59_DIAGNOSTIC_AUTO_COPY_DISABLED")
 else
  assert(queues==1 and #calls==5,"legacy Stage25 control no longer exports diagnostic")
  assert(#clips==1 and clips[1]=="UNSOLICITED_OLD_STAGE25_CLIPBOARD_MUTATION")
 end
 return owner
end
run(original,false)
run(silent,true)
realPrint("STAGE59_SILENT_SCANNER_REAL_LUA_2_CONTROL_AND_FIX_PASS")
'''
class Stage59SilentScannerBootTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("lua5.4"),"GitHub Actions installs Lua5.4")
    def test_original_legacy_copy_and_silent_stage59_scanner(self):
        with tempfile.TemporaryDirectory(prefix="stage59_silent_scanner_") as d:
            driver=Path(d)/"driver.lua";driver.write_text(DRIVER,encoding="utf-8")
            run=subprocess.run(
                ["lua5.4",str(driver),str(ORIG),str(SILENT)],
                cwd=ROOT,text=True,capture_output=True,timeout=35)
        self.assertEqual(run.returncode,0,run.stdout+"\n"+run.stderr)
        self.assertIn("STAGE59_SILENT_SCANNER_REAL_LUA_2_CONTROL_AND_FIX_PASS",run.stdout)

    def test_scanner_cache_source_remains_identical_and_no_clipboard_writer(self):
        original=ORIG.read_text(encoding="utf-8")
        silent=SILENT.read_text(encoding="utf-8")
        raw=original.encode()
        blob=hashlib.sha1(f"blob {len(raw)}\0".encode()+raw).hexdigest()
        self.assertEqual(blob,EXPECTED_ORIGINAL_GIT_BLOB)
        initial=original.split("local E=",1)[1].split(
            "-- One diagnostic output only",1)[0]
        initial=initial.replace('    probe={"new_part4/STAGE25_READONLY_DIAGNOSTIC.lua",\n'
          '        "cd8ed9ca5cdc73d98af93059df6b189dcd0a93bc"},\n',"")
        revised=silent.split("local E=",1)[1].split(
            "-- STAGE59-ONLY silent scanner fork",1)[0]
        self.assertEqual(initial,revised)
        for mutation in ("setclipboard(","toclipboard(","task.spawn(",
                         'fetchAndRun("probe")',"STAGE25_READONLY_DIAGNOSTIC.lua"):
            self.assertNotIn(mutation,silent)
        for safety in ("authorizesTrade=false","authorizesAccept=false",
                       "noOutgoing=true","noHopping=true","marketFresh=false"):
            self.assertIn(safety,silent)

if __name__=="__main__":
    unittest.main()
