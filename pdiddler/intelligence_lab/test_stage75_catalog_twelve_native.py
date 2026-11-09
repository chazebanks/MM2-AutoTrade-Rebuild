"""Stage75: pinned Oct18 source vs bounded actual Lua5.4 mocked game metadata.

No real client, player inventory or network remotes. Public raw keys are
embedded in the research script but NOT emitted in its report.
"""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/"pdiddler/new_part4/STAGE75_READONLY_CATALOG_TWELVE.lua"
PUBLIC=Path(os.getenv("STAGE75_PINNED_PUBLIC", "/tmp/stage75_oct18_db.lua"))
PUBLIC_BLOB="2be54c3f5c6b715844728c01a65cc2f24a55c02d"
SRC_ENTRY=re.compile(r'(?m)^  \["([^"\n]+)"\]\s*=\s*\{\s*\n([\s\S]*?)^  \},?')
SRC_FIELD=re.compile(r'(?m)^    \["(ItemName|ItemType|Rarity|Chroma|ItemID|Year|Event)"\]\s*=\s*("[^"\n]*"|\d+|true|false)\s*,?\s*$')
TARGET_LINE=re.compile(r'^\s*\{"([^"]+)","([^"]+)","(Knife|Gun)","(Ancient|Godly)",(true|false),"(\d{4})","(\d+)"\},?\s*$')
MARK="[GINGERSCOPE STAGE75 CATALOGUE EQUALITY]"

def git_blob_bytes(raw:bytes)->str:
    return hashlib.sha1(b"blob "+str(len(raw)).encode()+b"\0"+raw).hexdigest()

def public_items(raw:bytes)->dict:
    text=raw.decode("utf-8")
    out={}
    for match in SRC_ENTRY.finditer(text):
        key=match.group(1)
        if key in out:
            raise ValueError("duplicate external source record")
        rec={}
        for fld in SRC_FIELD.finditer(match.group(2)):
            if fld.group(1) in rec:
                raise ValueError("duplicate external direct field")
            value=fld.group(2)
            rec[fld.group(1)]=(value[1:-1] if value.startswith('"') else
                value=="true" if value in ("true","false") else int(value))
        out[key]=rec
    if len(out)!=1040:
        raise ValueError("uncorroborated public source item count")
    return out

def embedded_target_rows(source:str):
    block=source.split("local TARGETS={",1)[1].split("\n}",1)[0]
    rows=[]
    for line in block.splitlines():
        if not line.strip():
            continue
        m=TARGET_LINE.fullmatch(line)
        if not m:
            raise ValueError("unexpected embedded target row "+line[:90])
        raw,name,typ,rarity,chroma,year,item_id=m.groups()
        rows.append((raw,name,typ,rarity,chroma=="true",year,int(item_id)))
    if len(rows)!=12 or len({r[0] for r in rows})!=12:
        raise ValueError("target census not bounded and unique")
    return rows

def lua_table(rows):
    def s(v):return json.dumps(v,ensure_ascii=True)
    lines=["return {"]
    for raw,name,typ,rarity,chroma,year,item_id in rows:
        lines.append(f'  [{s(raw)}]={{')
        for field,val in [
            ("ItemName",name),("ItemType",typ),("Rarity",rarity),
            ("Event","Halloween"),("Year",year),("ItemID",item_id),
            ("Chroma",chroma),
        ]:
            value=("true" if val is True else "false" if val is False else
                   s(val) if isinstance(val,str) else str(val))
            lines.append(f"    {field}={value},")
        lines.append("  },")
    lines.append("}")
    return "\n".join(lines)+"\n"

HARNESS=r'''
local mode,script,publicFixture=arg[1],arg[2],arg[3]
local records,prints,clips={}, {}, {}
local weaponSet=assert(dofile(publicFixture))
local original={Emberbow=true,Emberscythe=true,Mortal=true,Immortal=true,
  Embersickle=true,EmberbowChroma=true,EmberscytheChroma=true,
  MortalChroma=true,ImmortalChroma=true,EmbersickleChroma=true,
  BattleAxe=true,BattleAxe2=true}
if mode=="missing" then weaponSet["MortalChroma"]=nil end
if mode=="wrong-variant" then weaponSet["EmberbowChroma"].Chroma=false end
if mode=="wrong-rarity" then weaponSet["EmberscytheChroma"].Rarity="Godly" end
if mode=="wrong-name" then weaponSet["BattleAxe"].ItemName="Battleaxe" end
if mode=="asset-change" then weaponSet["EmberscytheChroma"].ItemID=222222 end
if mode=="bad-art" then weaponSet["Emberbow"].ItemID=-2 end
local panelStatus=nil
local pg={}
function pg:FindFirstChild() return nil end
if mode~="no-ui" then
 Instance={new=function(class)
   local n={ClassName=class}
   function n:Destroy() self.Parent=nil end
   if class=="TextLabel" then panelStatus=n end
   return n
 end}
 UDim2={fromOffset=function()return {}end,new=function()return {}end}
 Vector2={new=function()return {}end}
 Color3={fromRGB=function()return {}end}
 UDim={new=function()return {}end}
 Enum={Font={GothamBold={},Gotham={}},
       TextXAlignment={Left={}},TextYAlignment={Top={}}}
end
local pl={LocalPlayer={}}
function pl.LocalPlayer:FindFirstChildOfClass()return pg end
local syncObj={}
local db={}
function db:FindFirstChild(n)
 if n=="Sync" and mode~="no-sync" then return syncObj end
end
local rs={}
function rs:FindFirstChild(n)if n=="Database" then return db end end
local http={}
function http:JSONEncode(r)
 if mode=="bad-encode" then error("synthetic encoding unavailable") end
 assert(type(r)=="table" and r.schema=="gingerscope-stage75-client-catalogue-twelve-v1")
 assert(r.authorizesTrade==false and r.authorizesAccept==false)
 assert(r.sourceFresh==false and r.serverAttestation==false)
 assert(r.rawGameToSupremeCheckerApproved==false)
 assert(r.clipboardPasteVerified==false)
 assert(r.tradeOutcome=="UNKNOWN")
 assert(type(r.targetChecks)=="table" and #r.targetChecks<=12)
 for _,a in ipairs(r.targetChecks) do
   assert(type(a.case)=="string" and a.case:match("^T%d%d$"))
   assert(not a.rawKey and not a.ItemID and not a.userId)
 end
 return "SANITIZED_SYNTHETIC_JSON"
end
game={PlaceId=142823291,JobId="stage75_fake_job"}
function game:GetService(name)
 if name=="Players" then return pl end
 if name=="ReplicatedStorage" then
   if mode=="no-rs" then error("fake ReplicatedStorage unavailable") end
   return rs
 end
 if name=="HttpService" then return http end
 error("unexpected service requested: "..tostring(name))
end
if mode=="wrong-game" then game.PlaceId=123 end
require=function(module)
 assert(module==syncObj)
 if mode=="server-change" then game.JobId="another_server" end
 return {Weapons=weaponSet}
end
print=function(a)prints[#prints+1]=tostring(a)end
warn=function(a)prints[#prints+1]=tostring(a)end
setclipboard=function(s)
 if mode=="copy-fails" then error("copy failure") end
 clips[#clips+1]=s
 return true
end
if mode=="no-clipboard" then setclipboard=nil end
toclipboard=nil
local result=assert(dofile(script))
assert(result.readOnly==true and result.authorizesTrade==false
 and result.authorizesAccept==false and result.maySendDiscordWebhook==false
 and result.mayUseForStrategyLearning==false)
local reports=0
for _,line in ipairs(prints)do
 if line:find("[GINGERSCOPE STAGE75 CATALOGUE EQUALITY]",1,true)
    and line:find("SANITIZED_SYNTHETIC_JSON",1,true) then reports=reports+1 end
end
if mode=="bad-encode" then
 assert(reports==0 and #clips==0)
else
 assert(reports==1,"expected exactly one console report, not duplicate export")
 if mode=="copy-fails" or mode=="no-clipboard" then
   assert(#clips==0)
 else
   assert(#clips==1,"exactly one clipboard request expected")
   assert(clips[1]:find("SANITIZED_SYNTHETIC_JSON",1,true))
 end
end
if mode=="wrong-game" then
 assert(result.status=="WRONG_GAME")
elseif mode=="no-rs" then
 assert(result.status=="REPLICATED_STORAGE_UNAVAILABLE")
elseif mode=="no-sync" then
 assert(result.status=="SYNC_MODULE_MISSING")
elseif mode=="server-change" then
 assert(result.status=="SERVER_CHANGED" and #result.targetChecks==0)
elseif mode=="missing" then
 assert(result.status=="CLIENT_CATALOGUE_DIFFERENCE_OBSERVED"
  and result.targetMissing==1 and result.targetMatches==11)
elseif mode=="wrong-variant" or mode=="wrong-rarity" or mode=="wrong-name"
   or mode=="asset-change" or mode=="bad-art" then
 assert(result.status=="CLIENT_CATALOGUE_DIFFERENCE_OBSERVED"
  and result.targetMismatched==1 and result.targetMatches==11)
elseif mode=="bad-encode" then
 assert(result.status=="CLIENT_PUBLIC_METADATA_EQUALITY_OBSERVED_UNVERIFIED")
elseif mode=="success" or mode=="copy-fails" or mode=="no-clipboard"
   or mode=="no-ui" then
 assert(result.status=="CLIENT_PUBLIC_METADATA_EQUALITY_OBSERVED_UNVERIFIED")
 assert(result.catalogueRowsObserved==12 and result.targetMatches==12)
 assert(result.targetMissing==0 and result.targetMismatched==0)
 assert(result.artIdReusedVariantPairs==5)
end
if mode=="success" or mode=="copy-fails" then
 assert(panelStatus and panelStatus.Text and panelStatus.Text:find("DONE",1,true),
  "in-game status did not update")
end
io.write("STAGE75_TEST "..mode.." PASSED\n")
'''

class Stage75NativeMetadataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lua=shutil.which("lua5.4")
        cls.luac=shutil.which("luac5.4")
        if not cls.lua or not cls.luac:
            raise unittest.SkipTest("Actual Lua5.4 required; dedicated CI installs it")
        if not PUBLIC.is_file():
            if os.getenv("STAGE75_REQUIRE_PINNED_FIXTURE")=="1":
                raise RuntimeError("Pinned Stage75 original public-source bytes missing")
            raise unittest.SkipTest("Dedicated Stage75 external pinned fixture unavailable in generic offline suite")
        cls.public=PUBLIC.read_bytes()
        if git_blob_bytes(cls.public)!=PUBLIC_BLOB:
            raise RuntimeError("Unreviewed third-party source blob")
        cls.expected=embedded_target_rows(SOURCE.read_text())
        cls.catalog=public_items(cls.public)
        cls.temp=tempfile.TemporaryDirectory(prefix="gingerscope_stage75_")
        cls.base=Path(cls.temp.name)
        cls.fixture=cls.base/"source_fixture.lua"
        cls.fixture.write_text(lua_table(cls.expected),encoding="utf-8")
        cls.runner=cls.base/"runner.lua"
        cls.runner.write_text(HARNESS,encoding="utf-8")

    @classmethod
    def tearDownClass(cls):
        if hasattr(cls,"temp"): cls.temp.cleanup()

    def test_source_pinned_metadata_matches_all_twelve_public_rows(self):
        for raw,name,typ,rarity,chroma,year,item_id in self.expected:
            with self.subTest(raw=raw):
                row=self.catalog[raw]
                self.assertEqual(row["ItemName"],name)
                self.assertEqual(row["ItemType"],typ)
                self.assertEqual(row["Rarity"],rarity)
                self.assertEqual(row.get("Chroma",False),chroma)
                self.assertEqual(str(row["Year"]),year)
                self.assertEqual(row["Event"],"Halloween")
                self.assertEqual(row["ItemID"],item_id)
        self.assertEqual(len(self.catalog),1040)
        self.assertEqual(len(self.expected),12)
        self.assertEqual([r[0] for r in self.expected][-2:],
                         ["BattleAxe","BattleAxe2"])

    def test_source_preserves_ancient_chromas_and_nonunique_item_ids(self):
        m={r[0]:r for r in self.expected}
        self.assertEqual(m["EmberbowChroma"][3],"Ancient")
        self.assertTrue(m["EmberbowChroma"][4])
        self.assertEqual(m["EmberscytheChroma"][3],"Ancient")
        self.assertEqual(m["EmberbowChroma"][6],m["Emberbow"][6])
        self.assertEqual(m["EmberscytheChroma"][6],m["Emberscythe"][6])
        self.assertNotIn("Supreme checker",SOURCE.read_text().split("TARGETS=",1)[-1])

    def test_actual_lua54_source_syntax(self):
        p=subprocess.run([self.luac,"-p",str(SOURCE)],capture_output=True,text=True)
        self.assertEqual(p.returncode,0,p.stderr)
        raw=SOURCE.read_text()
        for forbidden in ("FireServer(", "InvokeServer(", "GetPlayers(", "OwnInventory",
                          "GetInventory(", "TradeGUI", "RemoteEvent:Fire",
                          "SyncedTrade", "Purchase("):
            self.assertNotIn(forbidden,raw)

    def run_mode(self,mode):
        p=subprocess.run(
            [self.lua,str(self.runner),mode,str(SOURCE),str(self.fixture)],
            capture_output=True,text=True,timeout=8
        )
        self.assertEqual(p.returncode,0,(mode,p.stdout[-1000:],p.stderr[-1200:]))
        self.assertIn("STAGE75_TEST "+mode+" PASSED",p.stdout)

    def test_success_real_lua_and_in_game_guide(self):
        self.run_mode("success")

    def test_ancient_chroma_variant_is_not_silently_ignored(self):
        self.run_mode("wrong-variant")
        self.run_mode("wrong-rarity")

    def test_source_name_and_asset_mismatch_fail_without_trade(self):
        for m in ("wrong-name","asset-change","bad-art"):self.run_mode(m)

    def test_missing_weapon_is_detected(self):
        self.run_mode("missing")

    def test_session_and_wrong_place_fail_closed(self):
        for m in ("server-change","wrong-game","no-rs","no-sync"):
            self.run_mode(m)

    def test_clipboard_failure_has_one_console_report(self):
        for m in ("copy-fails","no-clipboard"):
            self.run_mode(m)

    def test_gui_absence_has_console_fallback(self):
        self.run_mode("no-ui")

    def test_json_encoding_failure_no_copy_or_false_success(self):
        self.run_mode("bad-encode")

if __name__=="__main__":
    unittest.main()
