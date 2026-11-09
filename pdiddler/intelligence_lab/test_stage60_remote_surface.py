"""Stage60: execute real read-only Lua surface census against fake MM2 nodes.

The fake game can lie; these tests establish only source safety, bounded
enumeration and no false authority. Native iPad behavior remains untested.
"""
from __future__ import annotations

import random
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
LUA=ROOT/"pdiddler/new_part4/STAGE60_READONLY_TRADE_REMOTE_SURFACE.lua"

HARNESS=r"""
local mode=arg[1] or "normal"
local source=arg[2]
local function entry(name,cls)
  return {Name=name,ClassName=cls}
end
local children={}
local defaults={"AcceptRequest","AcceptTrade","CancelAccept","CancelRequest",
 "CompleteTrade","DeclineRequest","DeclineTrade","EndTrade","GetRequest",
 "OfferItem","RemoveOffer","RequestSent","SetRequestsEnabled","StartTrade",
 "UpdateOffers","UpdateTrade"}
for _,name in ipairs(defaults) do
 children[#children+1]=entry(name,"RemoteEvent")
end
children[#children+1]=entry("SendRequest","RemoteFunction")
if mode=="function-candidate" then
 children[#children+1]=entry("GetTradeHistory","RemoteFunction")
elseif mode=="unsafe" then
 children[#children+1]=entry("private_UID=123;TOKEN","RemoteFunction")
elseif mode=="duplicate" then
 children[#children+1]=entry("SendRequest","RemoteFunction")
elseif mode=="many" then
 for i=1,64 do children[#children+1]=entry("Extra"..i,"RemoteEvent") end
elseif mode=="unknown-class" then
 children[#children+1]=entry("Mystery","Script")
elseif mode:find("^fuzz:") then
 local n=tonumber(mode:match("^fuzz:(%d+)$")) or 0
 for i=1,n%34 do
  local class=(i%3==0 and "RemoteFunction" or "RemoteEvent")
  children[#children+1]=entry("Probe_"..i,class)
 end
end
local folder={GetChildren=function()return children end}
local rs={FindFirstChild=function(_,name)
 if mode=="no-folder" then return nil end
 return name=="Trade" and folder or nil
end}
local http={JSONEncode=function(_,r)
 return "status="..tostring(r.status)
   ..";childCount="..tostring(r.childCount)
   ..";eventCount="..tostring(#r.eventNames)
   ..";functionNames="..table.concat(r.functionNames,",")
   ..";candidateEventNames="..table.concat(r.candidateEventNames,",")
   ..";candidateFunctionNames="..table.concat(r.candidateFunctionNames,",")
   ..";unsafeNames="..tostring(r.unsafeNames)
   ..";duplicateNames="..tostring(r.duplicateNames)
   ..";serverCompletionProven="..tostring(r.serverCompletionProven)
   ..";mayUseForStrategyLearning="..tostring(r.mayUseForStrategyLearning)
   ..";authorizesAccept="..tostring(r.authorizesAccept)
end}
game={PlaceId=mode=="wrong-place" and 1 or 142823291,
 GetService=function(_,name)
  if name=="ReplicatedStorage" then return rs end
  if name=="HttpService" then return http end
  return nil
 end}
local result=dofile(source)
assert(result.serverCompletionProven==false)
assert(result.serverTransactionIdAuthenticated==false)
assert(result.authorizesAccept==false)
assert(result.authorizesTrade==false)
assert(result.mayUseForStrategyLearning==false)
assert(result.mayRecordCompletedTrade==false)
assert(result.tradeOutcome=="UNKNOWN")
"""

class Stage60RemoteSurfaceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.exe=shutil.which("lua5.4") or shutil.which("lua")
        if not cls.exe:
            raise RuntimeError("Lua 5.4 required to execute real Stage60 launcher")
        cls.temp=tempfile.TemporaryDirectory(prefix="stage60_native_")
        cls.harness=Path(cls.temp.name)/"harness.lua"
        cls.harness.write_text(HARNESS,encoding="utf-8")

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def run_native(self,mode):
        p=subprocess.run([self.exe,str(self.harness),mode,str(LUA)],
                         capture_output=True,text=True,timeout=8)
        self.assertEqual(p.returncode,0,(mode,p.stdout,p.stderr))
        self.assertIn("[GINGERSCOPE STAGE60 REMOTE SURFACE]",p.stdout)
        self.assertIn("serverCompletionProven=false",p.stdout)
        self.assertIn("mayUseForStrategyLearning=false",p.stdout)
        return p.stdout

    def test_real_lua_compile_and_no_trade_mutators(self):
        parser=shutil.which("luac5.4") or shutil.which("luac")
        if parser:
            p=subprocess.run([parser,"-p",str(LUA)],capture_output=True,text=True)
            self.assertEqual(p.returncode,0,p.stderr)
        src=LUA.read_text(encoding="utf-8")
        for forbidden in (":FireServer(",":InvokeServer(",":FireClient(",
                          ":FireAllClients(","GetProfileData(", ".JobId",
                          "UserId","HttpGet(","Weapons.Owned"):
            self.assertNotIn(forbidden,src)
        self.assertIn("b.Activated:Connect(function()",src)
        self.assertNotIn("return finish(\"SUCCESS\")",src)

    def test_existing_sixteen_named_remotes_and_one_function(self):
        out=self.run_native("normal")
        self.assertIn("status=CLIENT_REMOTE_SURFACE_ENUMERATED_NO_CONTRACT",out)
        self.assertIn("childCount=17",out)
        self.assertIn("eventCount=16",out)
        self.assertIn("functionNames=SendRequest",out)
        self.assertIn("candidateEventNames=CompleteTrade,EndTrade",out)
        self.assertIn("candidateFunctionNames=;",out)

    def test_hypothetical_get_history_is_name_only(self):
        out=self.run_native("function-candidate")
        self.assertIn("GetTradeHistory,SendRequest",out)
        self.assertIn("candidateFunctionNames=GetTradeHistory;",out)
        self.assertIn("serverCompletionProven=false",out)

    def test_injection_and_ambiguous_names_fail_closed(self):
        out=self.run_native("unsafe")
        self.assertIn("status=UNSAFE_CHILD_NAMES_REJECTED",out)
        self.assertIn("unsafeNames=1",out)
        self.assertNotIn("private_UID",out)
        self.assertNotIn("TOKEN",out)
        out=self.run_native("duplicate")
        self.assertIn("status=AMBIGUOUS_DUPLICATE_REMOTE_NAMES",out)
        self.assertIn("duplicateNames=1",out)

    def test_missing_wrong_oversize_and_unknown_class(self):
        self.assertIn("status=TRADE_FOLDER_MISSING",self.run_native("no-folder"))
        self.assertIn("status=NOT_ORIGINAL_MM2",self.run_native("wrong-place"))
        self.assertIn("status=TOO_MANY_CHILDREN",self.run_native("many"))
        out=self.run_native("unknown-class")
        self.assertIn("status=CLIENT_REMOTE_SURFACE_ENUMERATED_NO_CONTRACT",out)
        self.assertIn("functionNames=SendRequest",out)

    def test_300_seeded_direct_child_shapes(self):
        rng=random.Random(60060)
        for i in range(300):
            n=rng.randrange(0,250)
            out=self.run_native("fuzz:"+str(n))
            self.assertIn("CLIENT_REMOTE_SURFACE_ENUMERATED_NO_CONTRACT",out,
                          (i,n))
            self.assertNotIn("serverCompletionProven=true",out)
            self.assertNotIn("authorizesAccept=true",out)

if __name__=="__main__":
    unittest.main()
