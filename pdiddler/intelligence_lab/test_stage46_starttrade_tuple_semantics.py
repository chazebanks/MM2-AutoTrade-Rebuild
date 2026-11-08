"""Stage46: Python runs checked-in pure and whole-native Lua, not reimplementation.

Stage46 is one passive hypothesis about StartTrade(TABLEx1, STRINGx1).
Client-name/initial-trade-layout match never supplies a verified session ID.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[1]
P4 = ROOT / "new_part4"
CORE = P4 / "p4_stage46_starttrade_tuple_semantics.lua"
LAUNCHER = P4 / "STAGE46_READONLY_STARTTRADE_TUPLE_PROBE.lua"
PURE_TEST = P4 / "tests" / "test_stage46_starttrade_tuple_semantics.lua"
NATIVE_TEST = P4 / "tests" / "test_stage46_starttrade_tuple_native.lua"
RESEARCH = P4 / "STAGE46_STARTTRADE_TUPLE_RESEARCH.md"
AUTH = (
    "eventSessionAssociationProven", "causalAttributionProven",
    "serverAttestation", "serverCompletionProven",
    "hasAuthenticatedSessionIdentifier", "sessionIdProven",
    "ownerSideSlotBound", "rawItemIdConfirmed",
    "exactWeaponIdentityConfirmed", "rawKeyPresentConfirmed",
    "authorizesAccept", "authorizesTrade",
    "mayRecordCompletedTrade", "mayReportProfit",
)


class Stage46StartTradeTests(unittest.TestCase):
    def test_source_has_exact_pinned_read_only_loader_modules(self):
        source = LAUNCHER.read_text()
        self.assertIn('CORE_PIN="6118cd280991a257d6ad89b42c4e4aea61b33f4e"', source)
        self.assertIn('source(CORE_PIN,"p4_stage46_starttrade_tuple_semantics")', source)
        self.assertIn('source(BASE,"p4_native_observer")', source)
        self.assertIn('source(BASE,"p4_observer_contract")', source)
        self.assertIn('PDIDDLER_STAGE45_STARTTRADE_TYPES', source)
        self.assertIn('ONE_START_TRADE_TUPLE_CLASSIFIED_CLIENT_ONLY', source)
        self.assertIn('GUI_VISIBLE_AT_CALLBACK_CLIENT_ONLY', source)
        self.assertIn('EVENT_BEFORE_VISIBLE_GUI_CLIENT_ONLY', source)
        self.assertIn('CALLBACK_GUI_PARTNER_CHANGED', source)
        self.assertIn('CALLBACK_GUI_ROOT_CHANGED', source)
        self.assertIn('privatePack=nil', source)

    def test_no_mutating_outbound_trading_or_data_exfil(self):
        for source in (CORE.read_text(), LAUNCHER.read_text()):
            for forbidden in (
                ':FireServer(', ':InvokeServer(', ':FireClient(', ':FireAllClients(',
                'SendMouseButtonEvent(', 'PostAsync(', 'GetProfileData(',
                'TeleportToPlaceInstance(', 'queue_on_teleport(',
                'hookfunction(', 'getconnections(', 'getupvalue(',
                'Instance.new(', 'OfferItem:FireServer',
                'AcceptTrade:FireServer', 'DeclineTrade:FireServer',
            ):
                with self.subTest(forbidden=forbidden):
                    self.assertNotIn(forbidden, source)

    def test_pure_inspector_privacy_and_exactness(self):
        source = CORE.read_text()
        for marker in (
            'getmetatable(t)~=nil', 'rawget(args,"n")~=2',
            'stringClassification', 'AMBIGUOUS_BOTH_ACTORS',
            'OTHER_STRING_UNCLASSIFIED', 'ROOT_FIELDSET_MISMATCH',
            'ACTOR_PAIR_MISMATCH', 'EMPTY_TRADE_TABLE_CLIENT_LAYOUT_MATCH',
            'bothOffersEmpty', 'bothAcceptedFalse',
            'clientTupleHypothesisMatched',
        ):
            self.assertIn(marker, source)
        for forbidden in (
            'r.rawString=', 'r.rawPayload=', 'r.partnerName=',
            'r.localName=', 'r.sessionId=', 'tostring(second)',
            'tostring(first)', 'for k,v in pairs(first)',
            'for k,v in next,first',
        ):
            self.assertNotIn(forbidden, source)

    def test_all_authority_flags_are_immutably_false(self):
        core = CORE.read_text()
        native = LAUNCHER.read_text()
        for name in AUTH:
            self.assertIn(name + "=false", core)
            self.assertNotIn(name + "=true", core)
            self.assertIn('"' + name + '"', native)
        self.assertIn('r[flag]=false', native)
        self.assertIn('tradeOutcome="UNKNOWN"', core)

    def test_native_mock_covers_event_and_gui_failures(self):
        source = NATIVE_TEST.read_text()
        for label in (
            "native P2 trade table plus partner username matches client hypothesis",
            "local P1 also matches",
            "unmatched private string never leaked or called session ID",
            "wrong root classified but not matched",
            "foreign actor cannot match",
            "same-tick visible GUI still permits client tuple classification",
            "multiple visible GUI roots at callback is rejected",
            "visible-at-callback partner label drift is rejected",
            "pre-arm callback from queued/stale event fails",
            "synchronous callback inside listener attach tears down correctly",
            "listener disconnection failure reports incomplete",
        ):
            self.assertIn(label, source)

    def test_research_does_not_claim_unsupported_server_session(self):
        source = RESEARCH.read_text()
        self.assertIn("NO claims about MM2's private StartTrade protocol", source)
        self.assertIn("unverified public MM2 script", source)
        self.assertIn("never any authority flag", source)
        self.assertIn("not yet observed", source)

    @unittest.skipUnless(shutil.which("lua5.4"), "Lua5.4 in GitHub CI")
    def test_python_runs_actual_checked_in_pure_lua(self):
        p = subprocess.run(
            ["lua5.4", str(PURE_TEST), str(P4)],
            cwd=ROOT.parent, capture_output=True, text=True, timeout=15,
        )
        self.assertEqual(p.returncode, 0, p.stdout + "\n" + p.stderr)
        self.assertIn("Stage46 StartTrade tuple pure: 34 passed, 0 failed", p.stdout)

    @unittest.skipUnless(shutil.which("lua5.4"), "Lua5.4 in GitHub CI")
    def test_python_runs_entire_native_mock(self):
        p = subprocess.run(
            ["lua5.4", str(NATIVE_TEST), str(P4)],
            cwd=ROOT.parent, capture_output=True, text=True, timeout=25,
        )
        self.assertEqual(p.returncode, 0, p.stdout + "\n" + p.stderr)
        self.assertIn("Stage46 StartTrade whole launcher native: 45 passed, 0 failed", p.stdout)

    @unittest.skipUnless(shutil.which("lua5.4"), "Lua5.4 in GitHub CI")
    def test_python_compiles_native_without_execution(self):
        p = subprocess.run(
            ["lua5.4", "-e", "assert(loadfile('pdiddler/new_part4/STAGE46_READONLY_STARTTRADE_TUPLE_PROBE.lua'))"],
            cwd=ROOT.parent, capture_output=True, text=True, timeout=15,
        )
        self.assertEqual(p.returncode, 0, p.stdout + "\n" + p.stderr)

    @unittest.skipUnless(shutil.which("lua5.4"), "Lua5.4 in GitHub CI")
    def test_python_randomized_400_real_lua_payloads(self):
        script = textwrap.dedent(r'''
            local M=assert(loadfile(arg[1]))()
            local me={Name="DELTAPRIVATE",DisplayName="LocalAlias"}
            local them={Name="PARTNERPRIVATE",DisplayName="PartnerAlias"}
            local other={Name="OTHERPRIVATE"}
            local SECRET="SECRET_TOKEN_MUST_NOT_EXPORT"
            local authority={"eventSessionAssociationProven","causalAttributionProven",
              "serverAttestation","serverCompletionProven","hasAuthenticatedSessionIdentifier",
              "sessionIdProven","ownerSideSlotBound","rawItemIdConfirmed",
              "exactWeaponIdentityConfirmed","rawKeyPresentConfirmed",
              "authorizesTrade","authorizesAccept","mayRecordCompletedTrade","mayReportProfit"}
            local function safe(v,seen)
              local t=type(v)
              if t=="string" then
                for _,s in ipairs({me.Name,them.Name,other.Name,SECRET})do
                  assert(not v:find(s,1,true),"raw secret leaked")
                end
              elseif t=="table" then
                seen=seen or {};assert(not seen[v]);seen[v]=true
                for k,x in pairs(v)do safe(k,seen);safe(x,seen)end
                seen[v]=nil
              end
            end
            local function original(orientation,mode)
              local p1=orientation==1 and me or them
              local p2=orientation==1 and them or me
              local t={LastOffer=1760000000,Locked=false,
                Player1={Player=p1,Accepted=false,Offer={}},
                Player2={Player=p2,Accepted=false,Offer={}}}
              if mode==1 then t.LastOffer=math.huge
              elseif mode==2 then t.Player1.Player=other
              elseif mode==3 then t.Player1.Offer={{SECRET,1,"Weapons"}}
              elseif mode==4 then t.Player2.Accepted=true
              elseif mode==5 then t.Extra=SECRET
              elseif mode==6 then t.Player1.Extra=SECRET
              elseif mode==7 then
                setmetatable(t,{__index=function()error("unsafe getter")end})
              elseif mode==8 then t.Locked="bad"end
              return t
            end
            math.randomseed(461126)
            for i=1,400 do
              local mode=math.random(0,8)
              local stringKind=math.random(0,5)
              local text=({them.Name,them.DisplayName,me.Name,me.DisplayName,SECRET,""})[stringKind+1]
              local r=M.inspect(table.pack(original(math.random(1,2),mode),text),me,them)
              assert(r.readOnly and r.clientOnly and r.tradeOutcome=="UNKNOWN")
              for _,flag in ipairs(authority)do assert(r[flag]==false,flag)end
              assert(r.status=="CLIENT_TUPLE_CLASSIFIED_UNAUTHENTICATED")
              assert(r.argumentCount==2)
              assert(r.argumentTypes[1]=="TABLE" and r.argumentTypes[2]=="STRING")
              if r.clientTupleHypothesisMatched then
                assert(mode==0)
                assert(r.tableLayout=="EMPTY_TRADE_TABLE_CLIENT_LAYOUT_MATCH")
                assert(r.stringClassification=="PARTNER_USERNAME_EXACT"
                       or r.stringClassification=="PARTNER_DISPLAY_ONLY")
              end
              safe(r)
            end
            print("STAGE46_REAL_LUA_RANDOMIZED: 400 passed")
        ''')
        with tempfile.TemporaryDirectory(prefix="stage46_py_lua_") as tmp:
            test_path = Path(tmp) / "property.lua"
            test_path.write_text(script)
            p = subprocess.run(
                ["lua5.4", str(test_path), str(CORE)],
                cwd=ROOT.parent, capture_output=True, text=True, timeout=20,
            )
        self.assertEqual(p.returncode, 0, p.stdout + "\n" + p.stderr)
        self.assertIn("STAGE46_REAL_LUA_RANDOMIZED: 400 passed", p.stdout)


if __name__ == "__main__":
    unittest.main()
