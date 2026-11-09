"""Stage65: real Lua5.4 offline exact-string equality and privacy firewall.

Mocks are hypothetical contract inputs, NOT real observed AcceptTrade item rows.
"""
from __future__ import annotations

import random
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
LUA=ROOT/"pdiddler/intelligence_lab/p4_stage65_private_raw_receipt_equality.lua"
MOCK=r"""
local mode=arg[1] or "exact"
local path=arg[2]
local m=dofile(path)
local secret="PRIVATE_RAW_WEAPON_KEY_UNIQUE_001"
local before={
 [secret]=1,
 OtherRawKnife=3,
 AnotherGun=8
}
local post={
 [secret]=2,
 OtherRawKnife=3,
 AnotherGun=8
}
local post2={
 [secret]=2,
 OtherRawKnife=3,
 AnotherGun=8
}
local row={secret,1,"Weapons"}
local input={
 beforeOwned=before,
 post1Owned=post,
 post2Owned=post2,
 receivedItems={row},
 callbackFirstArg=true,
 scopedInOneGui=true
}
if mode=="different-key" then
 row[1]="PRIVATE_DIFFERENT_RAW_KEY"
elseif mode=="alias" then
 row[1]=string.lower(secret)
elseif mode=="space" then
 row[1]=" "..secret
elseif mode=="two-gain" then
 post.AnotherGun=9;post2.AnotherGun=9
elseif mode=="loss-and-gain" then
 post.OtherRawKnife=2;post2.OtherRawKnife=2
elseif mode=="no-gain" then
 post[secret]=1;post2[secret]=1
elseif mode=="two-post-disagree" then
 post2[secret]=3
elseif mode=="post-zero" then
 post2[secret]=0
elseif mode=="missing-before" then
 input.beforeOwned=nil
elseif mode=="missing-callback" then
 input.receivedItems={}
elseif mode=="multi-callback" then
 input.receivedItems={row,{secret,1,"Weapons"}}
elseif mode=="callback-map" then
 input.receivedItems={example=row}
elseif mode=="callback-extra" then
 row[4]="hidden"
elseif mode=="row-negative" then
 row[2]=-1
elseif mode=="row-two" then
 row[2]=2
elseif mode=="row-string-qty" then
 row[2]="1"
elseif mode=="row-fraction" then
 row[2]=1.5
elseif mode=="row-nan" then
 row[2]=0/0
elseif mode=="row-category" then
 row[3]="Pets"
elseif mode=="row-name" then
 row[3]="Godly"
elseif mode=="row-unicode" then
 row[1]="☠☠☠"
elseif mode=="row-control" then
 row[1]="\nINJECTED_SECRET\n"
elseif mode=="extra-top" then
 input.verified=true
elseif mode=="fake-verified" then
 input.serverCompletionProven=true
elseif mode=="not-true" then
 input.callbackFirstArg=false
elseif mode=="not-scoped" then
 input.scopedInOneGui=false
elseif mode=="raw-number-key" then
 before[7]=2;post[7]=2;post2[7]=2
elseif mode=="raw-nan-count" then
 post[secret]=0/0
elseif mode=="raw-string-count" then
 post[secret]="2"
elseif mode=="raw-negative-count" then
 post[secret]=-2
elseif mode=="raw-extra-long" then
 row[1]=string.rep("A",200)
elseif mode=="raw-empty" then
 row[1]=""
elseif mode=="empty-snapshot" then
 input.beforeOwned={}
elseif mode=="zero-qty-key" then
 before.Extra=0;post.Extra=0;post2.Extra=0
elseif mode=="shuffled-map" then
 input.beforeOwned={AnotherGun=8,OtherRawKnife=3,[secret]=1}
 input.post1Owned={AnotherGun=8,OtherRawKnife=3,[secret]=2}
 input.post2Owned={AnotherGun=8,OtherRawKnife=3,[secret]=2}
elseif mode=="fuzz" then
 -- The requested index is provided as a third arg to this fake Lua process.
 local seed=tonumber(arg[3]) or 0
 local index=seed%19
 if index==0 then row[1]="no-match"
 elseif index==1 then post2.OtherRawKnife=4
 elseif index==2 then post.OtherRawKnife=4
 elseif index==3 then row[2]=0
 elseif index==4 then input.callbackFirstArg=false
 elseif index==5 then row[3]="Pets"
 elseif index==6 then input.receivedItems={}
 elseif index==7 then row[4]="secret"
 elseif index==8 then input.extra="not-trusted"
 elseif index==9 then before[secret]=2
 elseif index==10 then post[secret]=3
 elseif index==11 then post2[secret]=4
 elseif index==12 then input.scopedInOneGui=false
 elseif index==13 then before["PRIVATE_EXTRA_WEAPON"]=1
 elseif index==14 then row[2]="1"
 elseif index==15 then post.OtherRawKnife=1
 elseif index==16 then post2.OtherRawKnife=1
 elseif index==17 then row[1]=""
 else row[1]="\1" end
end

local result=m.evaluate(input)
assert(type(result)=="table")
assert(result.schema=="gingerscope-stage65-private-raw-key-equality-v1")
assert(result.readOnly==true)
assert(result.tradeOutcome=="UNKNOWN")
for _,flag in ipairs({
 "sameAuthenticatedTransaction","serverAttestation","serverCompletionProven",
 "serverTransactionIdAuthenticated","causalTradeAttributionProven",
 "callbackKeySemanticIdentityProven","exactWeaponIdentityConfirmed",
 "exactWeaponInstanceIdentityProven","weaponCategoryProven",
 "syncedCatalogIdentityProven","marketCheckerIdentityProven",
 "serverOwnedInventorySourceAuthenticated","offerRevisionAuthenticated",
 "partnerIdentityAuthenticated","mayRecordCompletedTrade",
 "mayRecordRejectedTrade","mayReportProfit","mayUseForStrategyLearning",
 "authorizesTrade","authorizesAccept","itemNameOrKeyExported"
}) do
 assert(result[flag]==false,"authority escalation:"..flag)
end
local csv={}
for k,v in pairs(result) do
 csv[#csv+1]=tostring(k).."="..tostring(v)
 -- The safe status enum intentionally says PRIVATE_RAW_PRIMITIVE_EQUALITY,
 -- so reject source IDs themselves, not the descriptive status prefix.
 for _,private in ipairs({secret,"PRIVATE_DIFFERENT_RAW_KEY",
     "PRIVATE_EXTRA_WEAPON","INJECTED_SECRET"}) do
  assert(not tostring(k):find(private,1,true))
  assert(not tostring(v):find(private,1,true))
 end
end
if mode=="exact" or mode=="shuffled-map" or mode=="zero-qty-key" then
 assert(result.status=="PRIVATE_RAW_PRIMITIVE_EQUALITY_CLIENT_ONLY",
        "expected raw-equal client-only")
else
 assert(result.status=="INCONCLUSIVE","unsafe case promoted "..mode)
end
print("STAGE65_TEST mode="..mode
 .." status="..result.status
 .." identity="..tostring(result.exactWeaponIdentityConfirmed)
 .." learning="..tostring(result.mayUseForStrategyLearning)
 .." rawKeyExported="..tostring(result.itemNameOrKeyExported))
"""
class Stage65PrivateEqualityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lua=shutil.which("lua5.4")
        if not cls.lua:
            raise RuntimeError("Install native Lua 5.4 for Stage65 real-module tests")
        cls.dir=tempfile.TemporaryDirectory(prefix="stage65_equality_")
        cls.fixture=Path(cls.dir.name)/"harness.lua"
        cls.fixture.write_text(MOCK,encoding="utf-8")
    @classmethod
    def tearDownClass(cls):
        cls.dir.cleanup()
    def run_native(self,mode,index=None):
        command=[self.lua,str(self.fixture),mode,str(LUA)]
        if index is not None:
            command.append(str(index))
        r=subprocess.run(command,capture_output=True,text=True,timeout=5)
        self.assertEqual(r.returncode,0,(mode,index,r.stdout,r.stderr))
        self.assertIn("identity=false learning=false rawKeyExported=false",r.stdout)
        self.assertNotIn("PRIVATE_RAW_WEAPON_KEY_UNIQUE_001",r.stdout)
        self.assertNotIn("INJECTED_SECRET",r.stdout)
        return r.stdout

    def test_pure_lua_syntax_and_no_io_trade_side_effects(self):
        luac=shutil.which("luac5.4")
        self.assertIsNotNone(luac)
        p=subprocess.run([luac,"-p",str(LUA)],capture_output=True,text=True)
        self.assertEqual(p.returncode,0,p.stderr)
        s=LUA.read_text(encoding="utf-8")
        for bad in ("InvokeServer","FireServer","HttpGet","getgenv",
                    "setclipboard","toclipboard","io.open","os.execute",
                    "DiscordWebhook","UserId","JobId","game:GetService"):
            self.assertNotIn(bad,s)
        self.assertIn("callbackKey~=gained",s)
        self.assertIn("return result(",s)

    def test_only_exact_raw_key_and_one_copied_weapon_pass_client_equality(self):
        for mode in ("exact","shuffled-map","zero-qty-key"):
            with self.subTest(mode=mode):
                out=self.run_native(mode)
                self.assertIn("PRIVATE_RAW_PRIMITIVE_EQUALITY_CLIENT_ONLY",out)

    def test_raw_alias_and_case_mismatch_never_count_as_equality(self):
        for mode in ("different-key","alias","space","row-unicode","row-control"):
            with self.subTest(mode=mode):
                self.assertIn("INCONCLUSIVE",self.run_native(mode))

    def test_wrong_quantity_ambiguous_inventory_and_stale_readbacks(self):
        for mode in ("two-gain","loss-and-gain","no-gain",
                     "two-post-disagree","post-zero","missing-before",
                     "raw-number-key","raw-nan-count","raw-string-count",
                     "raw-negative-count","empty-snapshot"):
            with self.subTest(mode=mode):
                self.assertIn("INCONCLUSIVE",self.run_native(mode))

    def test_unverified_modern_callback_schema_and_self_attestation(self):
        for mode in ("missing-callback","multi-callback","callback-map",
                     "callback-extra","row-negative","row-two",
                     "row-string-qty","row-fraction","row-nan",
                     "row-category","row-name","extra-top","fake-verified",
                     "not-true","not-scoped","raw-extra-long","raw-empty"):
            with self.subTest(mode=mode):
                self.assertIn("INCONCLUSIVE",self.run_native(mode))

    def test_400_seeded_mutations_cannot_promote(self):
        rng=random.Random(6565)
        for i in range(400):
            ix=rng.randrange(1,10000000)
            self.assertIn("INCONCLUSIVE",self.run_native("fuzz",ix))

if __name__=="__main__":
    unittest.main()
