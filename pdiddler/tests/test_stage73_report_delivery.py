"""Stage73 real Lua5.4 report path: one receipt, clipboard feedback, safe abort.

All values are synthetic. No Roblox client, Discord, trade, or real IDs.
"""
from __future__ import annotations
import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = ROOT / "pdiddler"
BOOT = BASE / "new_part4/STAGE73_SCANNER_HISTORY_ONLY_BOOT.lua"
PROBE = BASE / "new_part4/STAGE25_READONLY_DIAGNOSTIC.lua"
PROFILE = BASE / "snapshots/pdiddler_supreme_snapshot_2026_11_06.lua"
HISTORY = BASE / "intelligence_lab/stage72_historical_reference_preview.lua"
VIEW = BASE / "presentation/pdiddler3_scanner_view_stage73_history_v1.lua"
LUA = r'''
local mode = assert(arg[1])
local paths = {
  ["snapshots/pdiddler_supreme_snapshot_2026_11_06.lua"] = arg[3],
  ["intelligence_lab/stage72_historical_reference_preview.lua"] = arg[4],
  ["presentation/pdiddler3_scanner_view_stage73_history_v1.lua"] = arg[5],
  ["new_part4/STAGE25_READONLY_DIAGNOSTIC.lua"] = arg[6],
}
local logs, warnings, statuses, clipboardCalls, copyAttempts = {}, {}, {}, {}, 0
print = function(s) logs[#logs+1] = tostring(s) end
warn = function(s) warnings[#warnings+1] = tostring(s) end
local elapsed = 0
os.clock = function() return elapsed end
os.time = function() return 1794301000 end
local env = {}
getgenv = function() return env end
loadstring = load
local delayed
task = {
  spawn = function(cb) delayed = cb end,
  wait = function(seconds) elapsed = elapsed + seconds end
}
local localPlayer = {UserId=101}
local otherPlayer = {UserId=102}
local players = {LocalPlayer=localPlayer}
otherPlayer.Parent = players
function players:GetPlayers()
  if mode == "timeout" then return {localPlayer,otherPlayer} end
  return {localPlayer}
end
local http = {}
function http:JSONEncode(report)
  if mode == "encode_error" then error("synthetic encode failure") end
  assert(type(report)=="table" and report.schema=="gingerscope-stage25-scanner-evidence-v1")
  assert(report.authorizesTrade == false and report.authorizesAccept == false)
  assert(report.sourceFresh == false and report.serverAttestation == false)
  return "SYNTHETIC_ANON_REPORT"
end
game = {PlaceId=142823291, JobId="stage73-synthetic-job"}
function game:GetService(name)
  if name=="Players" then return players end
  if name=="HttpService" then return http end
  error("unexpected service "..name)
end
function game:HttpGet(url)
  local name = assert(url:match("/pdiddler/(.+)$"), "invalid source URL")
  if name == "presentation/pdiddler3_scanner_MODULE_v6_10_CURRENT_PRESENTATION.lua" then
    return [[local profile,policy,view=...
      assert(type(policy)=="table" and next(policy)==nil)
      return {
        getRecord=function() return nil end,
        getVerificationState=function() return {scanning=true} end,
        claimStatusOwner=function(owner)
          assert(owner=="STAGE73")
          return true
        end,
        setStatus=function(txt,owner)
          assert(owner=="STAGE73")
          _G.testStatus(txt)
          return true
        end,
        profile=profile,view=view
      }]]
  end
  local f=assert(io.open(assert(paths[name],"unexpected module: "..name),"rb"))
  local s=f:read("*a")
  f:close()
  return s
end
_G.testStatus = function(s) statuses[#statuses+1] = s end
if mode=="success" or mode=="timeout" or mode=="stale_session" then
  setclipboard=function(s)
    copyAttempts=copyAttempts+1
    clipboardCalls[#clipboardCalls+1]=s
  end
elseif mode=="throws" or mode=="fallback" then
  setclipboard=function()
    copyAttempts=copyAttempts+1
    error("synthetic copy API throws")
  end
elseif mode=="returns_false" then
  setclipboard=function()
    copyAttempts=copyAttempts+1
    return false
  end
else
  setclipboard=nil
end
if mode=="fallback" then
  toclipboard=function(s)
    copyAttempts=copyAttempts+1
    clipboardCalls[#clipboardCalls+1]=s
  end
else
  toclipboard=nil
end
local state = assert(dofile(arg[2]))
assert(type(delayed)=="function","report callback missing")
if mode=="stale_session" then env.PDIDDLER_PART4_SESSION=1 end
delayed()
local reportCount, oldStage25Reports = 0, 0
for _,s in ipairs(logs) do
  if s:find("[GINGERSCOPE STAGE73 READ-ONLY REPORT]",1,true) then
    reportCount=reportCount+1
    assert(s:find("SYNTHETIC_ANON_REPORT",1,true),"console receipt missing")
  end
  if s:find("[GINGERSCOPE STAGE25 READ-ONLY]",1,true) then
    oldStage25Reports=oldStage25Reports+1
  end
end
assert(oldStage25Reports==0,"duplicate implicit Stage25 report")
if mode=="encode_error" then
  assert(state.probeStatus=="REPORT_UNAVAILABLE")
  assert(state.reportStatus=="UNAVAILABLE")
  assert(state.clipboardStatus=="NOT_ATTEMPTED")
  assert(reportCount==0 and copyAttempts==0)
  assert(#warnings==1,"missing sanitized failure warning")
  assert(#statuses==1 and statuses[1]:find("REPORT UNAVAILABLE",1,true))
elseif mode=="stale_session" then
  assert(state.probeStatus=="ABORTED_SESSION_CHANGED")
  assert(reportCount==0 and #statuses==0 and copyAttempts==0)
else
  assert(state.probeStatus=="ONE_REPORT_CAPTURED")
  assert(state.reportStatus=="GENERATED_READ_ONLY")
  assert(reportCount==1,"expected exactly one console receipt")
  assert(#statuses==1,"in-game status was not presented")
  local gui=statuses[1]
  assert(gui:find("Total value UNVERIFIED",1,true)
     and gui:find("Outgoing paused",1,true),"safety state hidden")
  if mode=="success" or mode=="timeout" or mode=="fallback" then
    assert(state.clipboardStatus=="COPY_REQUEST_SUCCEEDED")
    assert(#clipboardCalls==1 and clipboardCalls[1]=="SYNTHETIC_ANON_REPORT")
    assert(gui:find("paste to confirm",1,true),"clipboard was overclaimed")
  else
    local stateExpected=mode=="unavailable" and "COPY_API_UNAVAILABLE"
       or "COPY_API_FAILED"
    assert(state.clipboardStatus==stateExpected,
      "unexpected clipboard status "..tostring(state.clipboardStatus))
    assert(#clipboardCalls==0)
    assert(gui:find("use Delta console",1,true),"fallback status hidden")
  end
  if mode=="timeout" then
    assert(state.scanWindowStatus=="TIMEOUT_POSSIBLY_INCOMPLETE")
    assert(elapsed>=45)
    assert(gui:find("some records may be unverified",1,true))
  else
    assert(state.scanWindowStatus=="CACHE_SETTLED")
  end
end
assert(state.authorizesAccept==false and state.authorizesTrade==false)
assert(state.marketFresh==false and state.noOutgoing==true and state.noHopping==true)
io.write("STAGE73_REPORT_TEST "..mode.." OK\n")
'''
class Stage73ReportDeliveryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lua=shutil.which("lua5.4")
        cls.luac=shutil.which("luac5.4")
        if not cls.lua or not cls.luac:
            raise RuntimeError("Actual Lua5.4 tools required")
        cls.tmp=tempfile.TemporaryDirectory(prefix="stage73_delivery_")
        cls.harness=pathlib.Path(cls.tmp.name)/"stage73_delivery.lua"
        cls.harness.write_text(LUA,encoding="utf-8")
    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()
    def run_mode(self,mode):
        result=subprocess.run(
            [self.lua,str(self.harness),mode,str(BOOT),str(PROFILE),
             str(HISTORY),str(VIEW),str(PROBE)],
            capture_output=True,text=True,timeout=8)
        self.assertEqual(result.returncode,0,
            (mode,result.stdout[-1500:],result.stderr[-1600:]))
        self.assertIn("STAGE73_REPORT_TEST "+mode+" OK",result.stdout)
    def test_source_syntax(self):
        for p in [BOOT,PROBE]:
            q=subprocess.run([self.luac,"-p",str(p)],capture_output=True,text=True)
            self.assertEqual(q.returncode,0,(str(p),q.stderr))
        src=BOOT.read_text()
        self.assertIn("0fdabefdd612afddc0e37f05896d5265d192daf2",src)
        self.assertIn('stage73CaptureOnly=true',src)
        self.assertNotIn('pcall(fetchAndRun,"probe")',src)
    def test_one_report_and_clipboard_request_success(self):
        self.run_mode("success")
    def test_clipboard_api_absent_console_fallback(self):
        self.run_mode("unavailable")
    def test_clipboard_api_throws_console_fallback(self):
        self.run_mode("throws")
    def test_clipboard_api_returns_false_console_fallback(self):
        self.run_mode("returns_false")
    def test_alternate_clipboard_api_fallback(self):
        self.run_mode("fallback")
    def test_encode_failure_fails_closed(self):
        self.run_mode("encode_error")
    def test_delayed_scan_timeout_is_distinguished_from_complete_scan(self):
        self.run_mode("timeout")
    def test_new_trade_session_aborts_old_result(self):
        self.run_mode("stale_session")

if __name__=="__main__":
    unittest.main()
