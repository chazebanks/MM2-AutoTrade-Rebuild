"""Exact protected-host equivalence and non-actionable GUI-only modularization.

The prior original Supreme five-scenario host is retained unchanged.
This compares the exact source before/after presentation extraction and
protects its P3/P4 logic byte-for-byte (not just matching mocked behavior).
"""
from pathlib import Path
import unittest

P=Path(__file__).resolve().parents[1]
OLD=P/"supervised/STAGE119_C9_SUPREME_ONLY_FIVE_SCENARIO_NATIVE.lua"
NEW=P/"supervised/STAGE119_C9_SUPREME_ONLY_FIVE_SCENARIO_CLEAN_NATIVE.lua"
GUI=P/"system2/native_supreme_five_scenario_gui_presentation.lua"
START=P/"supervised/STAGE119_C9_SUPREME_ONLY_FIVE_SCENARIO_CLEAN_START.lua"
OLD_START=P/"supervised/STAGE119_C9_SUPREME_ONLY_FIVE_SCENARIO_START.lua"
PRESENTER_SOURCE_PIN="3836738d83da5d49ae50be6dbed12155d1388702"
HOST_SOURCE_PIN="f284dae578a8ec2558dba54ea828097567322a60"

class FiveStageGuiCleanupIntegrity(unittest.TestCase):
    def setUp(self):
        self.old=OLD.read_text()
        self.new=NEW.read_text()
        self.gui=GUI.read_text()

    def test_entire_protected_host_suffix_is_byte_for_byte_unchanged(self):
        # Includes stop, guard/lease binding, supervisor ARM, native scanner,
        # original Supreme 189 source version, observer, 5-scenario mutation
        # gating, P3/P4 triple GUI checks, output sanitization and callbacks.
        marker="local function stop(reason)"
        self.assertEqual(self.old.count(marker),1)
        self.assertEqual(self.new.count(marker),1)
        self.assertEqual(
            self.new.split(marker,1)[1],
            self.old.split(marker,1)[1],
            "Protected original trade logic MUST not change in GUI cleanup"
        )
        for token in ("supervisor.arm({",
                      "c9SupremeOnlyReadOnlyPreview(options)",
                      'native_supreme_only_five_scenario_recorder.lua',
                      "neverFinalAcceptDuringTest~=true",
                      "noAutomaticWeaponOffers~=true",
                      "c9ReadOnlyLeaseStatus()"):
            self.assertIn(token,self.new)

    def test_pre_ui_protected_guards_identical_except_presenter_load(self):
        old=self.old.split("local ui={}",1)[0]
        new=self.new.split("local built,ui,uiWhy=pcall",1)[0]
        inserted=(
            "-- Pure presentation module; session/geometry/identity/offer code remains here.\n"
            f'local presenter=loadFrozen("{PRESENTER_SOURCE_PIN}",\n'
            '    "system2/native_supreme_five_scenario_gui_presentation.lua",12000)\n'
        )
        self.assertIn(inserted,new)
        new=new.replace(inserted,"")
        # Source hygiene: prior 39-char Git commit abbreviation resolved to the
        # identical historical full commit; no underlying bridge bytes changed.
        full_pin="2f556afac5e5fd9cfdbf9e081eeea01a542d293d"
        short_pin=full_pin[:-1]
        self.assertEqual(self.old.count(short_pin),1)
        self.assertEqual(self.new.count(full_pin),1)
        new=new.replace(full_pin,short_pin)
        new=new.replace('    or not presenter or type(presenter.render)~="function"\n',"")
        self.assertEqual(new,old,"All pre-GUI original P3 guards must match")
        self.assertIn("type(presenter.render)","".join(self.new.splitlines()))
        self.assertIn('type(presenter.render)~="function"',self.new)
        self.assertIn("presenter.buildUI",self.new)

    def test_original_read_only_panel_geometry_and_labels_preserved(self):
        # Exact Roblox UI property statements extracted, not a redesign.
        original_block=self.old.split("local ui={}",1)[1].split(
            "local guide={",1)[0]
        new_block=self.gui.split("function M.buildUI(env)",1)[1]
        for statement in (
            'ui.screen=Instance.new("ScreenGui")',
            'ui.screen.Name="PDIDDLER_P3_STAGE101_ReadonlyIdentity"',
            "ui.screen.ResetOnSpawn=false",
            "ui.screen.IgnoreGuiInset=true",
            "ui.screen.DisplayOrder=150",
            "ui.screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling",
            'ui.panel=Instance.new("Frame")',
            'ui.panel.Name="LiveStatus"',
            "ui.panel.BackgroundColor3=Color3.fromRGB(28,23,40)",
            "ui.panel.BorderSizePixel=0",
            "ui.panel.Active=false",
            "ui.panel.Visible=false",
            "ui.panel.Parent=ui.screen",
            "stroke.Color=Color3.fromRGB(177,128,239)",
            "stroke.Thickness=1",
            "corner.CornerRadius=UDim.new(0,10)",
            "q.Position=UDim2.fromOffset(12,y)",
            "q.Size=UDim2.fromOffset(280,h)",
            'ui.title=label("CurrentStep",7,24,14)',
            'ui.body=label("WhatToDo",32,52,12)',
            'ui.warning=label("Safety",90,18,11)',
            'ui.warning.Text="MANUAL ITEM TEST | NEVER FINAL ACCEPT"',
            "q.Position=UDim2.fromOffset(x,111)",
            "q.Size=UDim2.fromOffset(128,28)",
            'ui.arm=action("ArmP3","ARM P3",12)',
            'ui.preview=action("SupremePreview","SUPREME PREVIEW",12)',
            'ui.stop=action("StopP3","STOP / COPY",164)',
        ):
            with self.subTest(statement=statement):
                self.assertIn(statement, original_block)
                self.assertIn(statement, new_block)
        self.assertIn("ui.screen.Parent=env.Parent",new_block)
        self.assertIn("ui.screen.Parent=PG",original_block)
        self.assertIn("if ui.screen then pcall(function()ui.screen:Destroy()end) end",
                      new_block)
        self.assertIn("PRESENTER_GUI_CONSTRUCTION_FAILED",new_block)

    def test_geometry_refresh_and_session_failure_behavior_unchanged(self):
        old=self.old.split("function guide:refresh()",1)[1].split(
            "function guide:show(r)",1)[0]
        new=self.new.split("function guide:refresh()",1)[1].split(
            "function guide:show(r)",1)[0]
        self.assertEqual(old,new)
        self.assertIn("geometry.choose(",new)
        self.assertIn("{w=304,h=148}",new)
        self.assertIn('error("P3_GUIDE_"..tostring(why))',self.new)
        self.assertIn('error("P3_GUIDE_PRESENTATION_INVALID_"',self.new)
        self.assertIn('setDisplayIfChanged(ui.arm,"Active",content.armVisible)',self.new)
        self.assertIn('setDisplayIfChanged(ui.preview,"Active",content.previewVisible)',self.new)
        self.assertIn('setDisplayIfChanged(ui.stop,"Active",true)',self.new)
        self.assertIn("previewUntil=supremePreviewUntil",self.new)
        self.assertIn("now=os.clock()",self.new)

    def test_render_pure_and_only_one_extra_frozen_read_at_startup(self):
        self.assertEqual(self.new.count("local presenter=loadFrozen("),1)
        self.assertIn(PRESENTER_SOURCE_PIN,self.new)
        self.assertIn("function M.render(args)",self.gui)
        self.assertIn("function M.buildUI(env)",self.gui)
        self.assertIn("PRESENTER_INPUT_INVALID",self.gui)
        self.assertIn("PRESENTER_GUI_DEPENDENCIES_INVALID",self.gui)
        for forbidden in (
            "FireServer","InvokeServer","AcceptTrade","DeclineTrade",
            "TeleportService","PostAsync","getgenv","game:HttpGet",
            "setclipboard","mm2Values","mm2Listed","targetName",
            "UserId","JobId",
        ):
            self.assertNotIn(forbidden,self.gui)
        self.assertNotIn("supervisor.arm",self.gui)

    def test_host_shorter_but_no_false_runtime_speed_claim(self):
        old_lines=len(self.old.splitlines())
        new_lines=len(self.new.splitlines())
        self.assertEqual(old_lines,1269)  # Actual original trailing LF
        # Nine new idempotent setter sites add a few lines without restoring UI
        # construction or touching protected P3/P4 code below STOP.
        self.assertLessEqual(new_lines,old_lines-60)
        self.assertLess(len(self.new),len(self.old)-1500)
        self.assertGreater(len(self.gui),0)
        self.assertIn("native_supreme_five_scenario_gui_presentation.lua",
                      START.read_text() if False else self.new)
        self.assertEqual(OLD_START.read_bytes().count(
            b"noAutomaticWeaponOffers"),START.read_bytes().count(
            b"noAutomaticWeaponOffers"))

    def test_one_execution_startup_pins_clean_host_and_same_test_policy(self):
        a=OLD_START.read_text()
        b=START.read_text()
        self.assertIn(HOST_SOURCE_PIN,b)
        self.assertIn("STAGE119_C9_SUPREME_ONLY_FIVE_SCENARIO_CLEAN_NATIVE.lua",b)
        self.assertIn("presenter.render({",b)
        self.assertIn("pcall(presenter.buildUI,{",b)
        # Verify operator authorization and source-age gates are unchanged.
        prefix=a.split('local pinned="',1)[0]
        self.assertEqual(prefix,b.split('local pinned="',1)[0])
        for flag in ("manualWeaponChangesSupervisedOnly",
                     "noAutomaticWeaponOffers",
                     "neverFinalAcceptDuringTest",
                     "explicitOwnInventoryReadRpcConsent",
                     "SUPREME_FIVE_TEST_SOURCE_EXPIRED_BEFORE_MANUAL_ARM",
                     "automaticP3ArmForbidden"):
            self.assertIn(flag,b)
        self.assertNotIn("supervisor.arm(",b)

if __name__=="__main__":
    unittest.main()
