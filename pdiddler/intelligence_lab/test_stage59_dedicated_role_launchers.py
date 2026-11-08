"""Execute the TWO distinct immutable Stage59 launchers against a mocked Roblox runtime.

The main and alt launchers must each choose exactly the correct role without
purple role buttons or a second manual click; they reuse the SAME verified
read-only Stage59 shared observer and preserve its in-game instructions.
"""
from __future__ import annotations

import hashlib
import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/"pdiddler/new_part4"
SHARED=SRC/"STAGE59_GUIDED_DUAL_CLIENT_WITNESS.lua"
MAIN=SRC/"STAGE59_MAIN_RECEIVER.lua"
ALT=SRC/"STAGE59_ALT_SENDER.lua"
PIN="d21af6e479cc1c34ef0d2d4a6a5f5916b5c512a2"
BLOB="eed720db5e738e4a05cf9d43237036c78cd2d5a3"
S2="f74cb081590dfcdf100bd41f818e07d34856dff4"
EXISTING=ROOT/"pdiddler/intelligence_lab/test_stage59_guided_witness_wrapper.py"

def git_blob(source:str)->str:
    data=source.encode("utf-8")
    return hashlib.sha1(f"blob {len(data)}\0".encode()+data).hexdigest()

def driver()->str:
    spec=importlib.util.spec_from_file_location("stage59_existing_mock",EXISTING)
    assert spec and spec.loader
    obj=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    mock=obj.DRIVER.split("local passed=0",1)[0]
    markers=[
        ('local path=arg[1]', 'local path=arg[1]\nlocal shared=arg[2]'),
        ('   assert(url:find("'+S2+'",1,true),',
         '   if url:find("'+PIN+'",1,true) then\n'
         '    assert(url:find("STAGE59_GUIDED_DUAL_CLIENT_WITNESS.lua",1,true))\n'
         '    local file=assert(io.open(shared,"r"))\n'
         '    local content=file:read("*a")\n'
         '    file:close()\n'
         '    return content\n'
         '   end\n'
         '   assert(url:find("'+S2+'",1,true),'),
        ('assert(#remoteCalls==1,"one READ-ONLY source loader required")',
         'assert(#remoteCalls==2,"one immutable shared guide and one client-only observer needed")'),
        ('if opt.prior or opt.wrongGame or (opt.noGui and not opt.direct)\n'
         '    or (opt.guiBroken and not opt.direct) then',
         'if opt.prior or opt.wrongGame then'),
    ]
    for old,new in markers:
        assert mock.count(old)==1, f"cannot safely adapt mock marker: {old[:70]}"
        mock=mock.replace(old,new)
    mock+=r'''
local function exercise(path,shared,role,opts)
 local report,guide,created,remotes,clipboard=call(role,opts)
 assert(report and #remotes==2)
 assert(report:find('"operatorDeclaredRole":"'..role..'"',1,true),
  "wrong automatic role selected")
 local autoset=false
 local panel=false
 local title=false
 for _,line in ipairs(guide) do
  if line:find("ROLE AUTO-SELECTED: "..role,1,true) then autoset=true end
 end
 for _,node in ipairs(created) do
  if node.kind=="ScreenGui" and node.Name=="GINGERSCOPE_STAGE59_GUIDE" then
   panel=true
  end
  if node.kind=="TextLabel" and node.Active==true
   and node.Text:find("DRAG HERE",1,true) then title=true end
  assert(node.Name~="SENDER" and node.Name~="RECEIVER",
   "role buttons should NEVER appear for fixed-role entrypoints")
 end
 assert(autoset,"user must see selected role during execution")
 if not opts.noGui and not opts.guiBroken then
  assert(panel and title,"persistent draggable guide was not created")
 end
 assert(report:find('"tradeOutcome":"UNKNOWN"',1,true))
 assert(report:find('"serverCompletionProven":false',1,true))
 assert(report:find('"authorizesAccept":false',1,true))
 assert(report:find('"mayReportProfit":false',1,true))
end
local role=arg[3]
exercise(path,shared,role,{direct=false})
exercise(path,shared,role,{direct=false,noGui=true})
exercise(path,shared,role,{direct=false,guiBroken=true})
exercise(path,shared,role,{direct=false,clipboardMissing=true})
local report,guide=call(role,{direct=false,stage32TimedOut=true})
assert(report:find('"collectorStatus":"INCOMPLETE_STAGE32_NO_POST_CLOSE_EVIDENCE"',1,true))
assert(report:find('"postReadbacksObserved":0',1,true))
print("[STAGE59_TWO_ROLE_LAUNCHERS_TESTS_OK] "..role)
'''
    # In this mock, broken GUI/no-GUI cases still correctly launch the
    # unconditionally selected role, instead of awaiting manual role buttons.
    return mock

class Stage59DedicatedLauncherTests(unittest.TestCase):
    def test_role_fixed_and_pinned_from_unchanged_shared_code(self):
        shared=SHARED.read_text(encoding="utf-8")
        self.assertEqual(git_blob(shared),BLOB,
                         "pinned shared observer was changed silently")
        self.assertIn('if not fixedRole() then',shared)
        self.assertIn('say("ROLE AUTO-SELECTED: "..specifiedRole',shared)
        self.assertIn('frame.Position=UDim2.new(0,12,1,-200)',shared)
        for path,role in ((MAIN,"RECEIVER"),(ALT,"SENDER")):
            with self.subTest(path=path.name):
                src=path.read_text(encoding="utf-8")
                self.assertIn(f'local ROLE="{role}"',src)
                self.assertIn(PIN,src)
                self.assertIn('return fn(ROLE)',src)
                self.assertIn('STAGE59_GUIDED_DUAL_CLIENT_WITNESS.lua',src)
                self.assertIn('game.PlaceId~=142823291',src)
                for unsafe in (":FireServer(",":InvokeServer(",":PostAsync(",
                               "AcceptTrade:","OfferItem:","DeclineTrade:",
                               "TeleportToPlaceInstance(", "setclipboard("):
                    self.assertNotIn(unsafe,src)
        self.assertNotEqual(MAIN.read_bytes(),ALT.read_bytes())
        self.assertNotIn('local ROLE="SENDER"',MAIN.read_text())
        self.assertNotIn('local ROLE="RECEIVER"',ALT.read_text())

    @unittest.skipUnless(shutil.which("lua5.4"),"CI installs Lua5.4")
    def test_actual_separate_lua_launchers_and_real_shared_lua_guidance(self):
        with tempfile.TemporaryDirectory(prefix="stage59_two_launchers_") as td:
            mock=Path(td)/"driver.lua"
            mock.write_text(driver(),encoding="utf-8")
            for path,role in ((MAIN,"RECEIVER"),(ALT,"SENDER")):
                with self.subTest(role=role):
                    p=subprocess.run(
                        ["lua5.4",str(mock),str(path),str(SHARED),role],
                        cwd=ROOT,capture_output=True,text=True,timeout=50
                    )
                    self.assertEqual(p.returncode,0,p.stdout+"\n"+p.stderr)
                    self.assertIn(
                        f"[STAGE59_TWO_ROLE_LAUNCHERS_TESTS_OK] {role}",p.stdout
                    )

if __name__=="__main__":
    unittest.main()
