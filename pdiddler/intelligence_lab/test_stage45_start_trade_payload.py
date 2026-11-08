"""Stage45: Python executes the real Lua StartTrade argument inspector.

Threat model: the StartTrade payload is untrusted. Type-only evidence is NOT a
server session identifier; no code here grants trade/Accept/settlement authority.
GitHub CI installs lua5.4. Local environments without Lua run static gates and
clearly report dynamic tests SKIPPED, never PASSED.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[1]
P4 = ROOT / "new_part4"
MODULE = P4 / "p4_stage45_start_trade_payload.lua"
FIXTURE = P4 / "tests" / "test_stage45_start_trade_payload.lua"
NATIVE = P4 / "STAGE45_READONLY_STARTTRADE_TYPES_PROBE.lua"
NATIVE_FIXTURE = P4 / "tests" / "test_stage45_start_trade_native.lua"
RESEARCH = P4 / "STAGE45_STARTTRADE_ARGUMENT_RESEARCH.md"


class Stage45PythonIntegration(unittest.TestCase):
    def test_exact_module_never_exports_scalar_payloads(self):
        code = MODULE.read_text()
        self.assertIn('r.argumentTypes[i]=typ', code)
        self.assertIn('r.directPrimitiveCandidateCount=', code)
        self.assertIn('typ="LOCAL_PLAYER_REF"', code)
        self.assertIn('typ="PARTNER_PLAYER_REF"', code)
        self.assertIn('typ="OPAQUE"', code)
        self.assertIn('typ="TABLE"', code)
        self.assertIn('getmetatable(args)~=nil', code)
        self.assertIn('local n=rawget(args,"n")', code)
        self.assertIn('if me==nil or partner==nil or rawequal(me,partner)', code)
        for forbidden in (
            ':FireServer(', ':InvokeServer(', ':FireClient(', ':FireAllClients(',
            'SendMouseButtonEvent(', 'PostAsync(', 'HttpGet(', 'GetProfileData(',
            'hookfunction(', 'getconnections(', 'getupvalue(', 'setclipboard(',
            'getgenv(', 'queue_on_teleport(', 'TeleportToPlaceInstance(',
            'r.argumentValues=', 'r.rawPayload=', 'r.rawArgs=', 'r.sessionId=',
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, code)

    def test_all_session_and_trade_authorities_remain_false(self):
        code = MODULE.read_text()
        for field in (
            'hasAuthenticatedSessionIdentifier', 'sessionIdProven',
            'eventSessionAssociationProven', 'causalAttributionProven',
            'serverAttestation', 'serverCompletionProven', 'ownerSideSlotBound',
            'rawItemIdConfirmed', 'authorizesTrade', 'authorizesAccept',
            'mayRecordCompletedTrade', 'mayReportProfit',
        ):
            with self.subTest(field=field):
                self.assertIn(field + '=false', code)
                self.assertNotIn(field + '=true', code)
        self.assertIn('tradeOutcome="UNKNOWN"', code)
        self.assertIn('readOnly=true', code)

    def test_census_bounded_and_no_nesting(self):
        code = MODULE.read_text()
        self.assertIn('n>6', code)
        self.assertIn('for i=1,n do', code)
        self.assertNotIn('for k,v in pairs(a)', code)
        self.assertNotIn('for k,v in next,a', code)
        self.assertNotIn('tostring(a)', code)
        self.assertNotIn('string.format', code)
        self.assertIn('r.reason="NONFINITE_NUMBER"', code)

    def test_research_rejects_session_id_and_lastoffer_guess(self):
        note = RESEARCH.read_text()
        self.assertIn('not a session identifier', note.lower())
        self.assertIn('LastOffer', note)
        self.assertIn('before either account opens any trade', note)
        self.assertIn('NO real Stage45 result yet', note)

    def test_native_probe_has_exact_one_remote_and_no_outbound_actions(self):
        code = NATIVE.read_text()
        for marker in (
            'CORE_PIN="3635e6322cdcccc3d5bc9c1ea8a74bcf00a4333c"',
            'source(CORE_PIN,"p4_stage45_start_trade_payload")',
            'source(BASE,"p4_native_observer")',
            'node.Name=="StartTrade" and node:IsA("RemoteEvent")',
            'knownRemote.OnClientEvent', 'table.pack(...)',
            'privatePack=nil', 'seen>1',
            'ARGUMENT_LIMIT_EXCEEDED', 'GUI_VISIBLE_BUT_PARTNER_UNBOUND_AT_START',
            'UNARMED_START_TRADE_RECEIPT', 'TRADE_GUI_NOT_STABLE_AFTER_START',
            'LISTENER_CLEANUP_INCOMPLETE', 'WINDOW_CONTEXT_CHANGED',
            'START_TRADE_REMOTE_CHANGED', 'ACCEPT_INDICATOR_OBSERVED',
            'ONE_START_TRADE_TYPE_CENSUS_MATCHED',
            'r[flag]=false', 'r.tradeOutcome="UNKNOWN"',
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, code)
        for forbidden in (
            ':FireServer(', ':InvokeServer(', ':FireClient(', ':FireAllClients(',
            'SendMouseButtonEvent(', 'PostAsync(', 'GetProfileData(',
            'OfferItem:FireServer', 'AcceptTrade:FireServer',
            'TeleportToPlaceInstance(', 'queue_on_teleport(',
            'hookfunction(', 'getconnections(', 'getupvalue(', 'Instance.new(',
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, code)

    @unittest.skipUnless(shutil.which("lua5.4"), "Lua5.4 required for actual Lua execution")
    def test_native_lua_launcher_parses_but_does_not_execute(self):
        p = subprocess.run(
            ["lua5.4", "-e", "assert(loadfile('pdiddler/new_part4/STAGE45_READONLY_STARTTRADE_TYPES_PROBE.lua'))"],
            cwd=ROOT.parent, text=True, capture_output=True, timeout=15,
        )
        self.assertEqual(p.returncode, 0, p.stdout + "\\n" + p.stderr)

    @unittest.skipUnless(shutil.which("lua5.4"), "Lua5.4 required for actual Lua execution")
    def test_python_executes_whole_native_launcher_mock(self):
        source = NATIVE_FIXTURE.read_text()
        for name in (
            "second callback is ambiguous",
            "no StartTrade receipt times out",
            "pre-arm callback from queued/stale event fails",
            "event more than six arguments rejects",
            "observed acceptance fails closed",
            "session job change fails closed",
            "listener disconnection failure reports incomplete",
            "unknown scalar types do not leak or prove session ID",
            "same-tick visible GUI still permits TYPE-ONLY census",
            "synchronous callback inside listener attach tears down correctly",
            "offer mutation during observation grace rejects",
            "GUI visible at callback with wrong partner cannot inspect payload",
            "multiple visible GUI roots at callback is rejected",
            "visible-at-callback root lost before stable frame is rejected",
            "visible-at-callback partner label drift is rejected",
            "older Stage38 owner blocks launch before listeners are attached",
        ):
            self.assertIn(name, source)
        p = subprocess.run(
            ["lua5.4", str(NATIVE_FIXTURE), str(P4)],
            cwd=ROOT.parent, text=True, capture_output=True, timeout=20,
        )
        self.assertEqual(p.returncode, 0, p.stdout + "\\n" + p.stderr)
        self.assertIn("Stage45 StartTrade whole launcher native: 37 passed, 0 failed", p.stdout)

    @unittest.skipUnless(shutil.which("lua5.4"), "Lua5.4 required for actual Lua execution")
    def test_python_executes_checked_in_lua_fixture(self):
        process = subprocess.run(
            ["lua5.4", str(FIXTURE), str(P4)],
            cwd=ROOT.parent, text=True, capture_output=True, timeout=15,
            check=False,
        )
        self.assertEqual(process.returncode, 0, process.stdout + "\n" + process.stderr)
        self.assertIn("Stage45 StartTrade client argument types pure: 17 passed, 0 failed", process.stdout)

    @unittest.skipUnless(shutil.which("lua5.4"), "Lua5.4 required for actual Lua execution")
    def test_python_drives_320_real_lua_payload_property_cases(self):
        # Deliberately run 320 combinations of untrusted values through the
        # checked-in Lua module, NOT a Python reimplementation of its algorithm.
        script = textwrap.dedent(r'''
            local M=assert(loadfile(arg[1]))()
            local me,partner,other={},{},{}
            local SECRET="SESSION_SECRET_SENTINEL"
            local authority={"sessionIdProven","hasAuthenticatedSessionIdentifier",
              "eventSessionAssociationProven","causalAttributionProven","serverAttestation",
              "serverCompletionProven","ownerSideSlotBound","rawItemIdConfirmed",
              "authorizesTrade","authorizesAccept","mayRecordCompletedTrade","mayReportProfit"}
            local function clean(r)
              assert(r.readOnly==true and r.tradeOutcome=="UNKNOWN")
              for _,name in ipairs(authority) do assert(r[name]==false,name) end
              local function walk(t)
                for k,v in pairs(t) do
                  assert(k~=SECRET and v~=SECRET,"secret disclosed")
                  if type(v)=="table" then walk(v) end
                end
              end
              walk(r)
            end
            local function value(id)
              if id==0 then return nil end
              if id==1 then return SECRET end
              if id==2 then return 1000000000000 end
              if id==3 then return false end
              if id==4 then return true end
              if id==5 then return me end
              if id==6 then return partner end
              if id==7 then return other end
              if id==8 then
                return setmetatable({[SECRET]=SECRET},{
                  __index=function() error("metatable leaked") end})
              end
              return function() return SECRET end
            end
            math.randomseed(452026)
            for case=1,320 do
              local n=math.random(0,6)
              local a={n=n}
              local localRef,partnerRef=0,0
              for i=1,n do
                a[i]=value(math.random(0,9))
                if rawequal(a[i],me) then localRef=localRef+1 end
                if rawequal(a[i],partner) then partnerRef=partnerRef+1 end
              end
              local r=M.inspect(a,me,partner)
              clean(r)
              assert(r.status=="ANONYMIZED_CLIENT_ARGUMENT_TYPES_ONLY")
              assert(r.reason=="NONE")
              assert(r.argumentCount==n)
              assert(#r.argumentTypes==n)
              assert(r.localPlayerReferenceCount==localRef)
              assert(r.partnerPlayerReferenceCount==partnerRef)
              assert(r.playerPairReferencesObserved==
                (localRef==1 and partnerRef==1))
              assert(r.directPrimitiveCandidateCount==
                r.unclassifiedNumberCount+r.unclassifiedStringCount)
              local totals=r.localPlayerReferenceCount+r.partnerPlayerReferenceCount+
                r.unclassifiedStringCount+r.unclassifiedNumberCount+r.booleanCount+
                r.tableCount+r.opaqueCount+r.nilCount
              assert(totals==n,"classification not exhaustive")
            end
            print("STAGE45_REAL_LUA_PROPERTY_CASES: 320 passed")
        ''')
        with tempfile.TemporaryDirectory(prefix="stage45_py_lua_") as folder:
            path = Path(folder) / "test.lua"
            path.write_text(script)
            process = subprocess.run(
                ["lua5.4", str(path), str(MODULE)],
                cwd=ROOT.parent, text=True, capture_output=True, timeout=15,
                check=False,
            )
        self.assertEqual(process.returncode, 0, process.stdout + "\n" + process.stderr)
        self.assertIn("STAGE45_REAL_LUA_PROPERTY_CASES: 320 passed", process.stdout)


if __name__ == "__main__":
    unittest.main()
