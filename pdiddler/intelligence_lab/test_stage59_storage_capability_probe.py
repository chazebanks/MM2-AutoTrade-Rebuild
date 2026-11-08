"""Real Lua mocked Stage59 local-storage capability check without MM2 trade.

Simulates first-run readback and return after game rejoin on SAME device,
role-isolated files, API unavailable, write failure, and corrupted prior data.
"""
from pathlib import Path
import subprocess
import tempfile
import shutil
import unittest
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/"pdiddler/new_part4"
DRIVER=r'''
local main,alt,probePath=arg[1],arg[2],arg[3]
local file=assert(io.open(probePath,"r"));local probe=file:read("*a");file:close()
local originalPrint=print
local saved={}
local count=0
local function check(name,fn)
 local ok,err=pcall(fn)
 if not ok then error(name..": "..tostring(err)) end
end
local function run(path,role,mode)
 local lines,ui={},{}
 print=function(msg)lines[#lines+1]=tostring(msg)end
 getgenv=function()return {}end
 if mode=="NOFILE" then
  writefile=nil;readfile=nil
 elseif mode=="WRFAIL" then
  writefile=function()error("write disabled")end
  readfile=function(p)if saved[p] then return saved[p]end error("missing")end
 elseif mode=="RDFAIL" then
  writefile=function(p,t)saved[p]=t end
  readfile=function()error("read disabled")end
 else
  writefile=function(p,t)saved[p]=t end
  readfile=function(p)if saved[p] then return saved[p]end error("missing")end
 end
 local http={
  GenerateGUID=function()
   count=count+1
   return string.format("12345678-aaaa-4000-8000-%012x",count)
  end,
  JSONEncode=function(_,r)
   return string.format('{"role":"%s","status":"%s"}',r.role,r.storageStatus)
  end,
 }
 local pg={FindFirstChild=function()return nil end}
 local player={FindFirstChildOfClass=function(_,name)
  if name=="PlayerGui" then return pg end end}
 game={
  GetService=function(_,name)
   if name=="HttpService" then return http end
   if name=="Players" then return {LocalPlayer=player} end
  end,
  HttpGet=function(_,url)
   assert(url:find("STAGE59_LOCAL_STORAGE_CHECK.lua",1,true))
   return probe
  end,
 }
 local size=function(a,b)
  return {X={Offset=a},Y={Offset=b}}
 end
 UDim2={fromOffset=size,new=function()return {}end}
 Color3={fromRGB=function()return {}end}
 Enum={Font={GothamBold="gb",Gotham="g"},
  TextXAlignment={Left="L"},TextYAlignment={Top="T"}}
 Instance={new=function(kind)
  local obj={kind=kind}
  function obj:Destroy()self.Parent=nil end
  function obj:FindFirstChild()return nil end
  ui[#ui+1]=obj;return obj
 end}
 loadstring=load
 local ok,result=pcall(function()return assert(loadfile(path))()end)
 assert(ok,result)
 assert(type(result)=="table" and result.role==role)
 assert(result.readOnlyGame==true)
 assert(result.tradeOutcome=="UNKNOWN")
 assert(result.serverCompletionProven==false)
 assert(result.authorizesAccept==false)
 assert(result.mayReportProfit==false)
 assert(#lines==1 and lines[1]:find("[GINGERSCOPE STAGE59 STORAGE CHECK]",1,true)==1)
 local screenFound,labelFound=false,false
 for _,node in ipairs(ui) do
  if node.kind=="ScreenGui" and node.Name=="GINGERSCOPE_STAGE59_STORAGE_TEST" then screenFound=true end
  if node.kind=="TextLabel" and type(node.Text)=="string"
    and node.Text:find(role,1,true)==nil and node.Text:find("CURRENT ID",1,true) then
   labelFound=true end
 end
 assert(screenFound and labelFound,"role-specific live GUI must exist")
 return result
end
check("first MAIN write and exact-byte readback",function()
 local x=run(main,"MAIN")
 assert(x.storageStatus=="LOCAL_READBACK_OK" and x.previousNonce=="NONE")
 _G.mainNonce=x.currentNonce
end)
check("post-rejoin MAIN recalls exactly original marker",function()
 local x=run(main,"MAIN")
 assert(x.storageStatus=="LOCAL_READBACK_OK")
 assert(x.previousNonce==_G.mainNonce and x.currentNonce~=_G.mainNonce)
end)
check("first ALT has separate storage, independent from MAIN",function()
 local x=run(alt,"ALT")
 assert(x.storageStatus=="LOCAL_READBACK_OK" and x.previousNonce=="NONE")
 assert(saved["GINGERSCOPE_STAGE59_MAIN_STORAGE_CHECK.txt"]~=
   saved["GINGERSCOPE_STAGE59_ALT_STORAGE_CHECK.txt"])
 _G.altNonce=x.currentNonce
end)
check("post-rejoin ALT recalls its own earlier marker",function()
 local x=run(alt,"ALT")
 assert(x.previousNonce==_G.altNonce and x.currentNonce~=_G.altNonce)
end)
check("local writefile missing never masquerades as success",function()
 local x=run(alt,"ALT","NOFILE")
 assert(x.storageStatus=="NO_WRITEFILE")
end)
check("writefile failure always surfaced",function()
 local x=run(main,"MAIN","WRFAIL")
 assert(x.storageStatus=="WRITE_FAILED")
end)
check("readfile failure cannot prove local write",function()
 local x=run(alt,"ALT","RDFAIL")
 assert(x.storageStatus=="READBACK_FAILED")
end)
check("malformed previously saved file is explicitly rejected",function()
 saved["GINGERSCOPE_STAGE59_ALT_STORAGE_CHECK.txt"]="NOT A STAGE59 MARKER"
 local x=run(alt,"ALT")
 assert(x.previousNonce=="INVALID_PRIOR_FILE")
 assert(x.storageStatus=="LOCAL_READBACK_OK")
end)
check("other account marker in ALT file is rejected",function()
 saved["GINGERSCOPE_STAGE59_ALT_STORAGE_CHECK.txt"]=
   saved["GINGERSCOPE_STAGE59_MAIN_STORAGE_CHECK.txt"]
 local x=run(alt,"ALT")
 assert(x.previousNonce=="INVALID_PRIOR_FILE")
end)
originalPrint("STAGE59_STORAGE_NO_TRADE_REAL_LUA_9_CASES_PASS")
'''
class Stage59StorageSelfTest(unittest.TestCase):
    @unittest.skipUnless(shutil.which("lua5.4"),"CI installs Lua5.4")
    def test_two_separate_lua_storage_entrypoints_and_rejoin_cases(self):
        with tempfile.TemporaryDirectory(prefix="stage59_storage_") as td:
            drv=Path(td)/"driver.lua";drv.write_text(DRIVER)
            process=subprocess.run(["lua5.4",str(drv),
                str(SOURCE/"STAGE59_MAIN_STORAGE_CHECK.lua"),
                str(SOURCE/"STAGE59_ALT_STORAGE_CHECK.lua"),
                str(SOURCE/"STAGE59_LOCAL_STORAGE_CHECK.lua")],
                cwd=ROOT,capture_output=True,text=True,timeout=35)
        self.assertEqual(process.returncode,0,process.stdout+"\n"+process.stderr)
        self.assertIn("STAGE59_STORAGE_NO_TRADE_REAL_LUA_9_CASES_PASS",process.stdout)

    def test_no_trade_authority_and_role_pinning(self):
        source=(SOURCE/"STAGE59_LOCAL_STORAGE_CHECK.lua").read_text()
        self.assertIn('GINGERSCOPE_STAGE59_"..who.."_STORAGE_CHECK.txt"',source)
        self.assertIn('"LOCAL_READBACK_OK"',source)
        self.assertIn('"STAGE59-STORAGE-CHECK|"',source)
        self.assertIn('"UNKNOWN"',source)
        for name,role,device in [
            ("STAGE59_MAIN_STORAGE_CHECK.lua","RECEIVER","TABLET"),
            ("STAGE59_ALT_STORAGE_CHECK.lua","SENDER","PHONE")]:
            loader=(SOURCE/name).read_text()
            self.assertIn(f'entry("{role}","{device}")',loader)
            self.assertIn("STAGE59_LOCAL_STORAGE_CHECK.lua",loader)
        for name in ("STAGE59_MAIN_STORAGE_CHECK.lua",
                     "STAGE59_ALT_STORAGE_CHECK.lua"):
            loader=(SOURCE/name).read_text()
            self.assertNotIn(":FireServer(",loader)
            self.assertNotIn(":InvokeServer(",loader)
        for bad in (":FireServer(",":InvokeServer(",":PostAsync(",
                    "AcceptTrade:","OfferItem:","TeleportToPlaceInstance("):
            self.assertNotIn(bad,source)

if __name__=="__main__":
    unittest.main()
