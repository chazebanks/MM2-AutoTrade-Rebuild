"""Stage36 bounded full-catalog icon-reference collision census.
Real Lua tests plus static compile/safety audit of one native read-only probe.
"""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[2]
P4=ROOT/"pdiddler"/"new_part4"
CORE=P4/"p4_stage36_icon_catalog_audit.lua"
NATIVE=P4/"STAGE36_READONLY_ICON_CATALOG_DELTA_PROBE.lua"
TEST=P4/"tests"/"test_stage36_icon_catalog_audit.lua"

class Stage36IconCatalogTests(unittest.TestCase):
    def test_pure_module_strictly_comparable_reference_formats_no_authority(self):
        src=CORE.read_text()
        for phrase in (
            "matchingCatalogueEntries=0",
            'catalogEntriesWithoutComparableArt=0',
            'status="INCOMPLETE"',
            'MULTIPLE_CATALOGUE_ENTRIES_SHARE_ICON',
            'ONE_ICON_REFERENCE_MATCH_CLIENT_ONLY',
            'SINGLE_ICON_MATCH_WITH_COVERAGE_GAPS',
            'SPRITESHEET_REFERENCE_NOT_IDENTITY',
            'NO_MATCH_IN_READABLE_CATALOGUE',
            'ROBLOX_THUMB_ASSET',
            'ROBLOX_GAMEASSET',
            'ROBLOX_THUMB_UNSUPPORTED_VARIANT',
            'catalogEntriesFormatInspected=0',
            'catalogueReferenceFormatCounts=formatCounts()',
            'recordFormat(r.catalogueReferenceFormatCounts,ckFormat)',
            'catalogue-entry-invalid-or-duplicate',
            'rawItemIdConfirmed=false,exactWeaponIdentityConfirmed=false',
            'causalAttributionProven=false,authorizesTrade=false',
            'mayRecordCompletedTrade=false',
            'mayReportProfit=false',
            'readOnly=true,tradeOutcome="UNKNOWN"',
        ):
            self.assertIn(phrase,src)
        for forbidden in (':FireServer(', ':InvokeServer(', 'HttpGet(',
                          'SendMouseButtonEvent(', 'setclipboard(', 'require('):
            self.assertNotIn(forbidden,src)

    def test_native_only_reads_slot_icon_and_full_native_sync_without_payload_export(self):
        src=NATIVE.read_text()
        for phrase in (
            'PDIDDLER_STAGE36_ICON_CATALOG_AUDIT',
            'PDIDDLER_STAGE35_SLOT_METADATA_CENSUS',
            'p4_stage36_icon_catalog_audit.lua',
            'local PIN36="30eb8498f82fd6a79f2f0fbbfc282e59b97c7bdd"',
            'db:FindFirstChild("Sync")',
            'pcall(require,syncModule)',
            'gather(sync.Weapons)',
            'gather(sync.Item)',
            'for _,field in ipairs({"Image","Icon","Texture"})',
            'iconContainer:FindFirstChild("Icon")',
            'not visible(icon,root)',
            'icon.Image~=reference',
            'local slot,side,index,icon',
            'if root then slot,side,index,icon=filledSlot(root) end',
            'usesSpriteSheet=rect.X~=0 or rect.Y~=0',
            'finish("SYNC_READ_EXCEPTION")',
            'finish("ICON_REFERENCE_CATALOGUE_AUDIT_FINISHED"',
            '[GINGERSCOPE STAGE36 ANONYMIZED]',
            'r.serverCompletionProven=false',
            'r.exactWeaponIdentityConfirmed=false',
            'r.authorizesAccept=false',
        ):
            self.assertIn(phrase,src)
        self.assertNotIn("root and filledSlot(root)",src)
        for forbidden in (
            ':FireServer(', ':InvokeServer(', 'SendMouseButtonEvent(',
            'TeleportToPlaceInstance(', 'queue_on_teleport(',
            'getOwnInventory(', 'GetFullInventory(', 'GetProfileData(',
            'HttpService:PostAsync(', 'hookfunction(', 'getconnections(',
            'getupvalue(', 'SetCore(',
            'print(reference)', 'print(icon.Image)',
            'r.icon=reference', 'r.image=reference',
        ):
            self.assertNotIn(forbidden,src)

    def test_actual_native_unsupported_format_regression_in_lua(self):
        tests=TEST.read_text()
        for named in (
            "actual Stage36 native unreadable URI case is incomplete",
            "official rbxthumb Asset URI now comparable",
            "thumbnail Asset ID shared with excluded tier",
            "unknown scheme is labeled only by safe family",
            "undocumented numeric-only icon is not guessed",
            "Roblox game-local asset path",
        ):
            self.assertIn(named,tests)
        src=CORE.read_text()
        self.assertLess(src.index('recordFormat(r.catalogueReferenceFormatCounts,ckFormat)'),
                        src.index('if not raw then\\n  r.reason="slot-icon-reference-not-comparable"'))
        self.assertIn('catalogEntriesAudited=0',src)
        self.assertIn('r.catalogEntriesFormatInspected=#input.entries',src)

    @unittest.skipUnless(shutil.which("lua5.4"),"Lua5.4 required")
    def test_python_executes_actual_pure_stage36_lua(self):
        run=subprocess.run(
            ["lua5.4",str(TEST),"pdiddler/new_part4"],cwd=str(ROOT),
            capture_output=True,text=True,timeout=14)
        self.assertEqual(run.returncode,0,run.stdout+"\n"+run.stderr)
        self.assertIn("Stage36 client icon vs all-tier Sync catalogue collision audit",
                      run.stdout)

    @unittest.skipUnless(shutil.which("lua5.4"),"Lua5.4 required")
    def test_pure_and_native_compile(self):
        for file in (CORE,NATIVE):
            run=subprocess.run(["lua5.4","-e",
                 "assert(loadfile("+repr(str(file))+"))"],
                 cwd=str(ROOT),capture_output=True,text=True,timeout=12)
            self.assertEqual(run.returncode,0,run.stdout+"\n"+run.stderr)

    @unittest.skipUnless(shutil.which("lua5.4"),"Lua5.4 required")
    def test_native_multi_return_slot_bind_executed_real_lua(self):
        code=NATIVE.read_text()
        statement=("  local slot,side,index,icon\n"
                   "  if root then slot,side,index,icon=filledSlot(root) end")
        self.assertIn(statement,code)
        snippet=(
            'local root={}\n'
            'local function filledSlot(r) '
            'assert(r==root);return {}, "TheirOffer", 1, {} end\n'
            +statement+'\n'
            'assert(slot and side=="TheirOffer" and index==1 and icon)\n'
            'root=nil\n'
            +statement+'\n'
            'assert(slot==nil and side==nil and index==nil and icon==nil)\n'
            'print("STAGE36_MULTIRETURN_SAFE")'
        )
        run=subprocess.run(["lua5.4","-e",snippet],
            cwd=str(ROOT),capture_output=True,text=True,timeout=12)
        self.assertEqual(run.returncode,0,run.stdout+"\n"+run.stderr)
        self.assertIn("STAGE36_MULTIRETURN_SAFE",run.stdout)

if __name__=="__main__":
    unittest.main()
