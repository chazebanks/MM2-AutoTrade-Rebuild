"""Stage70 actual-Lua fail-closed source-to-weapon checker-ID trust boundary.

No MM2 connection, copied player inventory, Discord, real pricing authorization,
or external network. The production reviewed raw-key roster is EMPTY; a positive
case requires test-local source-code modification, NOT client field injection.
"""
from __future__ import annotations

import random
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "pdiddler/intelligence_lab/stage70_raw_checker_proof_gate.lua"
APPROVED_FIXTURE = r''' ["RAW_TEST_GUN"]={
  rawKey="RAW_TEST_GUN",page="godly",checkerId="42",
  name="Sample Gun",type="Gun",
  reviewedEvidenceId="INDEPENDENT-REVIEW-1",
  provenanceVersion="synthetic-test-only"
 },'''

HARNESS = r'''
local source,mode=arg[1],arg[2]
local T=1794000000
local sourceEpoch=T
os.time=function()return sourceEpoch end
local M=assert(dofile(source))
local getCalls=0
local record={
 page="godly",id="42",name="Sample Gun",verified=true,
 supremeValue=125,demand=5,stability="Stable"
}
local function src(slug)
 return {
  url="https://supremevalues.com/mm2/"..slug,
  sha256=string.rep("a",64),
  publishedAt="2026-11-09T00:00:00Z",
  observedAt="2026-11-09T00:01:00Z"
 }
end
local profile={
 liveReady=true,observedAtEpoch=T-120,publishedAtEpoch=T-3600,
 expiresAtEpoch=T+1000,
 sources={ancient=src("ancients"),chroma=src("chromas"),
          godly=src("godlies")},
 isFresh=function(x)return x>=T-120 and x<T+1000 end,
 get=function(page,id)
  getCalls=getCalls+1
  if page=="godly" and id=="42" then return record end
 end
}
local item={
 id="RAW_TEST_GUN",cat="Weapons",name="Sample Gun",
 page="godly",checkerId="42",qty=2,type="Gun",
}
local inv={items={item},unmapped=0,unpriced=0,badQty=0}
if mode=="different-id" then item.checkerId="43"
elseif mode=="wrong-name" then item.name="Other Gun"
elseif mode=="wrong-page" then item.page="ancient"
elseif mode=="wrong-type" then item.type="Knife"
elseif mode=="client-flags" then
 item.verified=true;item.mappingVerified=true
 item.exactWeaponIdentityConfirmed=true
 item.source="verified-snapshot-2026-11-01"
 item.rawKeyIdentityProof="INDEPENDENT"
 item.marketVerified=true
elseif mode=="expired" then profile.expiresAtEpoch=T-1
elseif mode=="backdated-publisher" then
 profile.publishedAtEpoch=T-73*3600
 profile.expiresAtEpoch=T+1000
elseif mode=="bad-source-sha" then profile.sources.godly.sha256="abc"
elseif mode=="bad-source-url" then profile.sources.godly.url="https://example.com"
elseif mode=="bad-source-clock" then profile.observedAtEpoch=T+1
elseif mode=="profile-notfresh" then profile.isFresh=function()return false end
elseif mode=="missing-source" then profile.sources.chroma=nil
elseif mode=="fake-live-ready" then profile.liveReady=false
elseif mode=="zero-quantity" then item.qty=0
elseif mode=="negative-quantity" then item.qty=-1
elseif mode=="fraction-quantity" then item.qty=1.5
elseif mode=="duplicate-raw" then inv.items[2]={
 id="RAW_TEST_GUN",cat="Weapons",name="Sample Gun",
 page="godly",checkerId="42",qty=1,type="Gun"
}
elseif mode=="sparse" then inv.items={[1]=item,[3]=item}
elseif mode=="foreign-key" then inv.items.foreign=item
elseif mode=="category-mismatch" then item.cat="Pets"
elseif mode=="missing-raw" then item.id=nil
elseif mode=="profile-get-mismatch" then record.id="999"
elseif mode=="profile-name-mismatch" then record.name="Other gun"
elseif mode=="profile-demand-bad" then record.demand=999
elseif mode=="profile-price-bad" then record.supremeValue=0/0
elseif mode=="profile-verified-false" then record.verified=false
elseif mode=="backdated-now-argument" then
 profile.expiresAtEpoch=T-1
elseif mode=="unknown-raw" then item.id="RAW_UNKNOWN_GUN"
elseif mode=="no-inventory" then inv=nil
elseif mode=="unpriced-existing" then inv.unpriced=1
elseif mode=="wrong-stability" then record.stability=""
elseif mode=="fuzz" then
 local seed=tonumber(arg[3]) or 0
 local variant=seed%17
 if variant==0 then item.checkerId="999"
 elseif variant==1 then item.name="Malicious"
 elseif variant==2 then item.id="RAW_UNKNOWN_GUN"
 elseif variant==3 then item.marketVerified=true
 elseif variant==4 then profile.expiresAtEpoch=T-1
 elseif variant==5 then item.qty=0
 elseif variant==6 then profile.sources.ancient.sha256="!"
 elseif variant==7 then record.verified=false
 elseif variant==8 then record.supremeValue=-1
 elseif variant==9 then item.type="Pet"
 elseif variant==10 then inv.unpriced=2
 elseif variant==11 then profile.publishedAtEpoch=T-73*3600
 elseif variant==12 then profile.liveReady=false
 elseif variant==13 then inv.items[2]=item
 elseif variant==14 then inv.items[4]=item
 elseif variant==15 then record.name="Alternate"
 else profile.sources.godly.url="https://fake.invalid" end
end
-- Extra untrusted timestamp ignored even if an old caller sends one.
local out=M.evaluate(inv,profile,T-500000)
assert(type(out)=="table")
assert(out.readOnly==true)
assert(out.tradeOutcome=="UNKNOWN")
assert(out.rawCheckerCrosswalkProven==false)
assert(out.numericTradingAuthority==false)
assert(out.authorizesAccept==false)
assert(out.authorizesTrade==false)
assert(out.mayReportProfit==false)
assert(out.mayRecordCompletedTrade==false)
assert(out.mayRecordRejectedTrade==false)
assert(out.mayUseForStrategyLearning==false)
assert(out.maySendDiscordWebhook==false)
for _,r in ipairs(out.items) do
 assert(r.rawKey==nil and r.name==nil)
 assert(r.serverTransactionId==nil)
end

local approved=arg[4]=="approved"
local positive=approved and (mode=="valid" or mode=="client-flags")
local partial=approved and mode=="unpriced-existing"
if positive then
 assert(out.reviewedMappingCount==1)
 assert(out.priceRowsVerified==1)
 assert(out.completeValue==250)
 assert(out.verifiedSubtotal==250)
 assert(out.status=="SOURCE_CURRENT_AND_REVIEWED_CROSSWALK_ONLY")
 assert(getCalls==1)
elseif partial then
 assert(out.priceRowsVerified==1)
 assert(out.verifiedSubtotal==250)
 assert(out.completeValue==nil)
 assert(getCalls==1)
else
 assert(out.priceRowsVerified==0)
 assert(out.completeValue==nil)
 assert(out.verifiedSubtotal==nil)
 if not approved then
  assert(out.reviewedMappingCount==0)
  assert(getCalls==0) -- no fuzzy/name/alias-only source-quote lookup
 end
end
print("STAGE70_GATE mode="..mode.." priceRows="..out.priceRowsVerified..
 " reviewed="..out.reviewedMappingCount.." profileGetCalls="..getCalls..
 " sourceFresh="..tostring(out.sourceFresh)..
 " completeValue="..tostring(out.completeValue)..
 " status="..out.status)
'''

class Stage70LuaPolicyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lua=shutil.which("lua5.4")
        cls.luac=shutil.which("luac5.4")
        if not cls.lua or not cls.luac:
            raise RuntimeError("Stage70 actual Lua5.4 runtime/compiler required")
        cls.temp=tempfile.TemporaryDirectory(prefix="stage70_")
        t=Path(cls.temp.name)
        cls.harness=t/"harness.lua"
        cls.harness.write_text(HARNESS,encoding="utf-8")
        cls.pinned=t/"approved-fixture-only.lua"
        source=SOURCE.read_text(encoding="utf-8")
        anchor="local REVIEWED_RAW_TO_CHECKER={\n"
        assert source.count(anchor)==1
        cls.pinned.write_text(source.replace(anchor,anchor+APPROVED_FIXTURE+"\n"),
                              encoding="utf-8")
    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def run_lua(self,mode,approved=False,seed=None):
        src=self.pinned if approved else SOURCE
        cmd=[self.lua,str(self.harness),str(src),mode]
        if seed is not None:
            cmd.append(str(seed))
        elif mode=="fuzz":
            cmd.append("0")
        if approved:
            if seed is None and mode!="fuzz":
                cmd.append("0")
            cmd.append("approved")
        p=subprocess.run(cmd,capture_output=True,text=True,timeout=6)
        self.assertEqual(p.returncode,0,(mode,approved,p.stdout,p.stderr))
        self.assertIn("STAGE70_GATE mode=",p.stdout)
        self.assertNotIn("RAW_TEST_GUN",p.stdout)
        self.assertNotIn("RAW_UNKNOWN_GUN",p.stdout)
        return p.stdout

    def test_exact_actual_lua_syntax_and_static_empty_trust_root(self):
        for src in (SOURCE,self.pinned):
            p=subprocess.run([self.luac,"-p",str(src)],capture_output=True,text=True)
            self.assertEqual(p.returncode,0,p.stderr)
        source=SOURCE.read_text(encoding="utf-8")
        self.assertIn("local REVIEWED_RAW_TO_CHECKER={\n -- EMPTY",source)
        self.assertIn("local at=os.time()",source)
        self.assertNotIn("now or os.time()",source)
        for forbidden in (":FireServer(",":InvokeServer(",":HttpGet(",
                          "setclipboard(", "DiscordWebhook(", ":PostAsync(", "request("):
            self.assertNotIn(forbidden,source)

    def test_current_source_with_fuzzy_alias_or_injected_proof_stays_unverified(self):
        for mode in ("valid","client-flags","different-id","wrong-name",
                     "wrong-page","wrong-type","unknown-raw"):
            with self.subTest(mode=mode):
                out=self.run_lua(mode)
                self.assertIn("priceRows=0 reviewed=0 profileGetCalls=0",out)
                self.assertIn("completeValue=nil",out)

    def test_stale_or_forged_clock_and_source_cannot_reprice(self):
        for mode in ("expired","backdated-publisher","bad-source-sha",
                     "bad-source-url","bad-source-clock","profile-notfresh",
                     "missing-source","fake-live-ready","backdated-now-argument"):
            with self.subTest(mode=mode):
                out=self.run_lua(mode,approved=True)
                self.assertIn("priceRows=0",out)
                self.assertIn("completeValue=nil",out)

    def test_invalid_owned_rows_and_untrusted_market_records_quarantine(self):
        for mode in ("zero-quantity","negative-quantity","fraction-quantity",
                     "duplicate-raw","sparse","foreign-key","category-mismatch",
                     "missing-raw","profile-get-mismatch","profile-name-mismatch",
                     "profile-demand-bad","profile-price-bad",
                     "profile-verified-false","unpriced-existing",
                     "wrong-stability"):
            with self.subTest(mode=mode):
                out=self.run_lua(mode,approved=True)
                if mode=="unpriced-existing":
                    self.assertIn("priceRows=1",out)
                    self.assertIn("completeValue=nil",out)
                else:
                    self.assertIn("priceRows=0",out)
                    self.assertIn("completeValue=nil",out)

    def test_test_only_static_source_change_allows_readonly_quote_without_trade(self):
        self.assertIn("priceRows=1 reviewed=1",self.run_lua("valid",approved=True))
        self.assertIn("priceRows=1 reviewed=1",self.run_lua("client-flags",approved=True))
        # Client name, raw key, tier or checker mutation cannot self-approve.
        for mode in ("different-id","wrong-name","wrong-page","wrong-type",
                     "unknown-raw"):
            out=self.run_lua(mode,approved=True)
            self.assertIn("priceRows=0",out)

    def test_static_reviewed_checker_target_collision_fails_closed(self):
        source=SOURCE.read_text(encoding="utf-8")
        anchor="local REVIEWED_RAW_TO_CHECKER={\n"
        second=r''' ["RAW_DIFFERENT"]={
          rawKey="RAW_DIFFERENT",page="godly",checkerId="42",
          name="Different Gun",type="Gun",
          reviewedEvidenceId="INDEPENDENT-REVIEW-2",
          provenanceVersion="synthetic-test-only"
        },'''
        candidate=Path(self.temp.name)/"duplicate-reviewed.lua"
        candidate.write_text(source.replace(
            anchor,anchor+APPROVED_FIXTURE+"\n"+second+"\n"
        ),encoding="utf-8")
        probe=Path(self.temp.name)/"duplicate-probe.lua"
        probe.write_text(
            'local M=dofile(arg[1])\n'
            'local o=M.evaluate({items={}},nil)\n'
            'assert(o.reason=="DUPLICATE_REVIEWED_CHECKER_TARGET")\n'
            'assert(o.priceRowsVerified==0 and o.completeValue==nil)\n'
            'assert(o.authorizesTrade==false)\n'
            'print("DUPLICATE_TARGET_REJECTED")\n',
            encoding="utf-8")
        p=subprocess.run([self.lua,str(probe),str(candidate)],
                         capture_output=True,text=True,timeout=5)
        self.assertEqual(p.returncode,0,p.stderr)
        self.assertIn("DUPLICATE_TARGET_REJECTED",p.stdout)

    def test_multiple_finite_quotes_cannot_overflow_aggregate(self):
        source=SOURCE.read_text(encoding="utf-8")
        anchor="local REVIEWED_RAW_TO_CHECKER={\n"
        both=r''' ["RAW_HUGE_A"]={
          rawKey="RAW_HUGE_A",page="godly",checkerId="42",
          name="One Gun",type="Gun",
          reviewedEvidenceId="INDEPENDENT-REVIEW-1",
          provenanceVersion="synthetic-test-only"
        },
        ["RAW_HUGE_B"]={
          rawKey="RAW_HUGE_B",page="godly",checkerId="43",
          name="Two Gun",type="Gun",
          reviewedEvidenceId="INDEPENDENT-REVIEW-2",
          provenanceVersion="synthetic-test-only"
        },'''
        candidate=Path(self.temp.name)/"overflow-reviewed.lua"
        candidate.write_text(source.replace(anchor,anchor+both+"\n"),
                             encoding="utf-8")
        probe=Path(self.temp.name)/"overflow-probe.lua"
        probe.write_text(r'''
local M=dofile(arg[1])
local t=1794000000
os.time=function()return t end
local function src(slug)
 return {url="https://supremevalues.com/mm2/"..slug,
 sha256=string.rep("a",64),publishedAt="2026-11-09T00:00:00Z",
 observedAt="2026-11-09T00:01:00Z"}
end
local p={
 liveReady=true,observedAtEpoch=t-120,publishedAtEpoch=t-3600,
 expiresAtEpoch=t+1000,
 sources={ancient=src("ancients"),chroma=src("chromas"),godly=src("godlies")},
 isFresh=function()return true end,
 get=function(page,id)
  return {page=page,id=id,
    name=id=="42" and "One Gun" or "Two Gun",
    supremeValue=1e308,demand=5,stability="Stable",verified=true}
 end
}
local inv={unmapped=0,unpriced=0,badQty=0,items={
 {id="RAW_HUGE_A",checkerId="42",page="godly",type="Gun",
  cat="Weapons",qty=1,name="One Gun"},
 {id="RAW_HUGE_B",checkerId="43",page="godly",type="Gun",
  cat="Weapons",qty=1,name="Two Gun"}
}}
local out=M.evaluate(inv,p)
assert(out.reason=="AGGREGATE_VALUE_OVERFLOW")
assert(out.priceRowsVerified==0)
assert(out.completeValue==nil and out.verifiedSubtotal==nil)
assert(#out.items==0)
assert(out.authorizesTrade==false)
print("AGGREGATE_OVERFLOW_REJECTED")
''',encoding="utf-8")
        p=subprocess.run([self.lua,str(probe),str(candidate)],
                         capture_output=True,text=True,timeout=5)
        self.assertEqual(p.returncode,0,p.stderr)
        self.assertIn("AGGREGATE_OVERFLOW_REJECTED",p.stdout)

    def test_400_seeded_changes_never_promote_unreviewed_client_rows(self):
        rng=random.Random(707070)
        for i in range(400):
            seed=rng.randrange(1,1_000_000)
            with self.subTest(i=i,seed=seed):
                out=self.run_lua("fuzz",seed=seed)
                self.assertIn("priceRows=0 reviewed=0 profileGetCalls=0",out)

if __name__=="__main__":
    unittest.main()
