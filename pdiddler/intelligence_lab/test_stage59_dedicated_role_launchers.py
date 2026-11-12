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
PIN="c9c9fe64bce6563f8580321f7a58073ed27ef0b7"
BLOB="882fe34c3a694a4beb50e0e763defd86f3797b02"
S2="54b97f65290ce038910436e27600be6a2c4a005e"
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
    # Phone-specific viewport mock: landscape iPhone on ALT, iPad on MAIN.
    old_view="workspace={CurrentCamera={ViewportSize={X=1024,Y=768}}}"
    new_view='workspace={CurrentCamera={ViewportSize=role=="SENDER" and {X=844,Y=390} or {X=1024,Y=768}}}'
    assert mock.count(old_view)==1
    mock=mock.replace(old_view,
        'workspace={CurrentCamera={ViewportSize=opt.phoneViewport or (role=="SENDER" and {X=844,Y=390} or {X=1024,Y=768})}}')
    mock=mock.replace('o.AbsolutePosition={X=12,Y=586}',
        'o.AbsolutePosition={X=12,Y=role=="SENDER" and 89 or 586}')
    mock=mock.replace('o.AbsoluteSize={X=320,Y=182}',
        'o.AbsoluteSize={X=role=="SENDER" and 270 or 320,Y=role=="SENDER" and 146 or 182}')
    mock=mock.replace('return s,guide,created,remoteCalls,clip',
        'return s,guide,created,remoteCalls,clip,userInput')
    mock+=r'''
local function exercise(path,shared,role,opts)
 local report,guide,created,remotes,clipboard,userInput=call(role,opts)
 assert(report and #remotes==2)
 assert(report:find('"operatorDeclaredRole":"'..role..'"',1,true),
  "wrong automatic role selected")
 local autoset=false
 local panel=false
 local title=nil
 local frame=nil
 local notice=nil
 local fold=nil
 for _,line in ipairs(guide) do
  if line:find("ROLE AUTO-SELECTED: "..role,1,true) then autoset=true end
 end
 for _,node in ipairs(created) do
  if node.kind=="Frame" then frame=node end
  if node.kind=="TextLabel" and node.Active~=true then notice=node end
  if node.kind=="TextButton" and node.Name=="MINIMISE_PHONE_GUIDE" then fold=node end
  if node.kind=="ScreenGui" and node.Name=="GINGERSCOPE_STAGE59_GUIDE" then
   panel=true
  end
  if node.kind=="TextLabel" and node.Active==true
   and node.Text:find("DRAG HERE",1,true) then title=node end
  assert(node.Name~="SENDER" and node.Name~="RECEIVER",
   "role buttons should NEVER appear for fixed-role entrypoints")
 end
 assert(autoset,"user must see selected role during execution")
 if not opts.noGui and not opts.guiBroken then
  assert(panel and title and frame and notice,"persistent guide missing")
  if role=="SENDER" then
   local v=workspace.CurrentCamera.ViewportSize
   local expectedWidth=math.max(180,math.min(270,v.X-24))
   local expectedY=math.min(math.max(52,math.floor(v.Y*0.23)),
       math.max(0,v.Y-146))
   assert(frame.Size.X.Offset==expectedWidth and frame.Size.Y.Offset==146,
     "ALT iPhone guide must fit viewport")
   assert(frame.Position.X.Offset==12 and frame.Position.Y.Offset==expectedY,
     "ALT phone guide starts left/above joystick and outside leaderboard")
   assert(frame.Position.X.Offset+frame.Size.X.Offset<=v.X,
     "phone GUI leaked past right edge")
   assert(frame.Position.Y.Offset+frame.Size.Y.Offset<=v.Y,
     "phone GUI leaked past bottom edge")
   assert(title.Text:find("ALT SENDER",1,true),
     "ALT role must be visible in phone header")
   assert(title.TextSize==12 and notice.TextSize==12,
     "phone text not responsive")
   assert(notice.Text:find("FINISHED",1,true),
     "phone still needs visible completed instructions")
   assert(fold and fold.onActivate,"iPhone minimize control must be interactive")
   fold.onActivate()
   assert(frame.Size.X.Offset==expectedWidth and frame.Size.Y.Offset==36 and notice.Visible==false,
     "phone must minimise without falling off screen")
   fold.onActivate()
   assert(frame.Size.X.Offset==expectedWidth and frame.Size.Y.Offset==146 and notice.Visible==true,
     "phone must restore its visible live instructions")
   if opts.phoneTouchDrag then
    local press={UserInputType="Touch",Position={X=30,Y=expectedY+15}}
    title.InputBegan:Fire(press)
    press.Position={X=155,Y=expectedY+28}
    userInput.InputChanged:Fire(press)
    assert(frame.Position.X.Offset==137 and frame.Position.Y.Offset==expectedY+13,
      "phone iPhone touch must move title-dragged guide")
    userInput.InputEnded:Fire(press)
    local oldX=frame.Position.X.Offset
    press.Position={X=260,Y=expectedY+70}
    userInput.InputChanged:Fire(press)
    assert(frame.Position.X.Offset==oldX,
      "ALT iPhone drag must release when finger lifts")
   end
  else
   assert(frame.Size.X.Offset==320 and frame.Size.Y.Offset==182,
    "MAIN iPad layout changed unexpectedly")
   assert(frame.Position.Y.Scale==1 and frame.Position.Y.Offset==-200,
    "MAIN bottom-left position must be preserved")
   assert(fold==nil,"iPad should not gain phone-only minimise button")
  end
 end
 assert(report:find('"tradeOutcome":"UNKNOWN"',1,true))
 assert(report:find('"serverCompletionProven":false',1,true))
 assert(report:find('"authorizesAccept":false',1,true))
 assert(report:find('"mayReportProfit":false',1,true))
end
local role=arg[3]
exercise(path,shared,role,{direct=false,phoneTouchDrag=role=="SENDER"})
if role=="SENDER" then
 exercise(path,shared,role,{direct=false,phoneViewport={X=568,Y=320}})
 exercise(path,shared,role,{direct=false,phoneViewport={X=390,Y=844}})
end
exercise(path,shared,role,{direct=false,noGui=true})
exercise(path,shared,role,{direct=false,guiBroken=true})
exercise(path,shared,role,{direct=false,clipboardMissing=true})
local report,guide=call(role,{direct=false,stage32TimedOut=true})
assert(report:find('"collectorStatus":"INCOMPLETE_STAGE32_NO_POST_CLOSE_EVIDENCE"',1,true))
assert(report:find('"postReadbacksObserved":0',1,true))
oldPrint("[STAGE59_TWO_ROLE_LAUNCHERS_TESTS_OK] "..role)
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
        self.assertIn('local phoneMode=(specifiedRole=="SENDER" and (deviceProfile=="PHONE" or deviceProfile=="PHONE_RECOVER"))',shared)
        self.assertIn('local recoveryOnly=(deviceProfile=="PHONE_RECOVER" or deviceProfile=="TABLET_RECOVER")',shared)
        self.assertIn('local width,height=270,146',shared)
        self.assertIn('local minimise=Instance.new("TextButton")',shared)
        self.assertIn('return "BASELINE BOUND. Wait for MAIN too.',shared)
        self.assertIn('frame.Size=UDim2.fromOffset(frame.Size.X.Offset,folded and 36 or 146)',shared)
        for path,role in ((MAIN,"RECEIVER"),(ALT,"SENDER")):
            with self.subTest(path=path.name):
                src=path.read_text(encoding="utf-8")
                self.assertIn(f'local ROLE="{role}"',src)
                self.assertIn(PIN,src)
                self.assertIn(
                    f'return fn(ROLE,"{"PHONE" if role=="SENDER" else "TABLET"}")',
                    src
                )
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
