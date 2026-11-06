"""Stage25 Python-first checks of Supreme source preflight and read-only Delta probe.

All trading permissions remain disabled. Live Supreme retrieval is performed
only by the separate GitHub Actions source preflight, not by these fixtures.
"""
from pathlib import Path
import importlib.util
import shutil
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[1]
SPEC=importlib.util.spec_from_file_location(
    "supreme_stage25",ROOT/"refresh_supreme_snapshot.py")
S=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(S)
LUA=ROOT/"new_part4"

def row(name,style=""):
    return (f'<div class="itemcolumn" {style} data-value="100" '
            f'data-demand="5" data-stability="Stable">'
            f'<button data-name="{name}"></button>'
            f'<div class="itemhead">{name}</div>'
            f'<div class="itembody">Value - <b>100</b><br>'
            f'Stability - <b class="itemstability">Stable</b><br>'
            f'Demand - <b>5</b></div></div>')

def page(body):
    return ('<div data-updated-iso="2026-11-04T12:27:12-05:00"></div>'+body)

class Stage25Tests(unittest.TestCase):
    def test_pet_rows_are_excluded_only_from_real_pets_section(self):
        source=page(row("Chroma Laser")+
                    '<section data-tier="pets">'+row("Chroma Fire Bat")+'</section>')
        records,_=S.parse_page(source,"chroma")
        self.assertEqual([r["name"] for r in records],["Chroma Laser"])

    def test_pet_name_outside_pet_tier_is_not_excluded(self):
        source=page(row("Chroma Fire Bat"))
        records,_=S.parse_page(source,"chroma")
        self.assertEqual([r["name"] for r in records],["Chroma Fire Bat"])

    def test_hidden_placeholder_is_never_a_market_item(self):
        source=page(row("Laser")+row("Black Luger",'style="display:none"'))
        records,_=S.parse_page(source,"godly")
        self.assertEqual([r["name"] for r in records],["Laser"])

    def test_new_hidden_weapon_requires_review(self):
        with self.assertRaisesRegex(ValueError,"unreviewed excluded"):
            S.parse_page(page(row("Secret Item",'style="display:none"')),"godly")

    def test_source_coverage_remains_190_authoritative_ids(self):
        self.assertEqual(S.EXPECTED,{"ancient":16,"chroma":46,"godly":128})
        self.assertEqual(len(S.KNOWN_NONWEAPON_PETS["chroma"]),7)
        self.assertEqual(S.KNOWN_HIDDEN_PLACEHOLDERS["godly"],
                         {"Batwing","Black Luger"})
        source=(ROOT/"snapshots"/"supreme_snapshot_2026_11_04.json")
        import json
        old=json.loads(source.read_text())
        self.assertEqual(len(old["rows"]),190)

    def test_expired_existing_snapshot_not_relabelled(self):
        import json
        old=json.loads((ROOT/"snapshots"/
                       "supreme_snapshot_2026_11_04.json").read_text())
        self.assertLessEqual(
            S.epoch(old["expiresAt"]),S.epoch("2026-11-06T00:00:00Z"))
        new=(LUA/"REPLACEMENT_INTEGRATION_PREVIEW.lua").read_text()
        self.assertIn("supreme_snapshot_2026_11_04.lua",new)
        self.assertIn("assert(I.profile.isFresh()",new)

    def test_probe_cannot_execute_or_expose_identity(self):
        src=(LUA/"STAGE25_READONLY_DIAGNOSTIC.lua").read_text()
        for forbidden in ("InvokeServer","FireServer","mouse1click",
                          "VirtualInputManager","webhookUrl","requestHop",
                          "queue_on_teleport"):
            self.assertNotIn(forbidden,src)
        self.assertIn("serverAttestation=false",src)
        self.assertIn("authorizesTrade=false",src)
        self.assertIn("authorizesAccept=false",src)
        self.assertIn('row.label="P"..i',src)

    @unittest.skipUnless(shutil.which("lua5.4"),"Lua 5.4 installed in CI")
    def test_actual_read_only_lua_diagnostic(self):
        result=subprocess.run(
            ["lua5.4",str(LUA/"tests"/"test_stage25_readonly_diagnostic.lua"),
             str(LUA)],cwd=str(ROOT.parent),capture_output=True,text=True,
             timeout=12,check=False)
        self.assertEqual(result.returncode,0,
                         result.stdout+"\n"+result.stderr)
        self.assertIn("Stage25 read-only scanner proof diagnostic tests",
                      result.stdout)

if __name__=="__main__":
    unittest.main()
