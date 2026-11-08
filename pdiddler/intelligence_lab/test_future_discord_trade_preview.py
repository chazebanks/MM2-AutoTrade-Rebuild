"""Pure hypothetical Discord preview tests; no webhook, no usernames, no trades."""
import copy
import importlib.util
import random
import unittest
from pathlib import Path
ROOT=Path(__file__).parent
SPEC=importlib.util.spec_from_file_location("future_discord_preview",
                                           ROOT/"future_discord_trade_preview.py")
M=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)
def fixture():
    return {"gave":[{"name":"Iceblaster","quantity":2,"listedValue":35,
                     "demand":5,"liquidity":5,"stability":"Stable"}],
            "received":[{"name":"Vampire's Edge","quantity":1,"listedValue":75,
                         "demand":6,"liquidity":6,"stability":"Stable"}],
            "startingInventoryListedValue":550,
            "catalogVersion":"SYNTHETIC-2026-11-08"}
def safe(r):
    assert r["embedPreview"] is None or r["status"]=="PREVIEW_ONLY"
    assert r["tradeOutcome"]=="UNKNOWN"
    for flag in ("maySendWebhook","authorizesTrade","authorizesAccept",
                 "mayReportProfit","mayRecordCompletedTrade",
                 "mayUseForStrategyLearning","serverCompletionProven"):
        assert r[flag] is False,(flag,r)
class FutureDiscordTradePreviewTests(unittest.TestCase):
    def test_user_requested_all_fields_are_in_preview_not_completion(self):
        p=fixture()
        r=M.build_preview(p)
        self.assertEqual(r["status"],"PREVIEW_ONLY")
        safe(r)
        embed=r["embedPreview"]
        self.assertIn("NOT VERIFIED",embed["title"])
        alltext="\n".join(x["value"] for x in embed["fields"])
        self.assertIn("Iceblaster",alltext)
        self.assertIn("Vampire's Edge",alltext)
        self.assertIn("Demand 5/10",alltext)
        self.assertIn("Liquidity 6/10",alltext)
        self.assertIn("Projected listed difference: +5 pts",alltext)
        self.assertIn("After if recorded: 555 pts",alltext)
        self.assertIn("NOT realized profit",alltext)
        self.assertNotIn("Trade Completed",embed["title"])
        self.assertEqual(len(embed["fields"]),4)
        self.assertEqual(p["startingInventoryListedValue"],550)

    def test_zeros_one_sided_gift_are_hypothetical_only(self):
        p=fixture();p["gave"]=[]
        r=M.build_preview(p)
        self.assertEqual(r["status"],"PREVIEW_ONLY")
        self.assertIn("None (hypothetical gift)",r["embedPreview"]["fields"][0]["value"])
        safe(r)

    def test_sensitive_or_execution_fields_are_refused(self):
        for key in ("username","userId","trader","webhook","webhookUrl",
                    "webhookToken","discordToken","authToken","serverTransactionId"):
            p=fixture();p[key]="SHOULD_NOT_BE_RECORDED"
            x=M.build_preview(p)
            self.assertEqual(x["reason"],"ACTION_OR_ACCOUNT_FIELDS_FORBIDDEN")
            safe(x)

    def test_no_mentions_or_markup_injection(self):
        for bad in ("@everyone","<@1234567>","Item\nLine","**Spoof**",
                    "Trophy_\u2713","A"*71):
            p=fixture();p["gave"][0]["name"]=bad
            x=M.build_preview(p)
            self.assertEqual(x["status"],"BLOCKED",(bad,x))
            safe(x)

    def test_stack_math_and_negative_inventory_protection(self):
        p=fixture();p["gave"][0]["quantity"]=20
        x=M.build_preview(p)
        self.assertEqual(x["status"],"BLOCKED")
        self.assertEqual(x["reason"],"PROJECTED_INVENTORY_TOTAL_OUT_OF_BOUNDS")
        p["startingInventoryListedValue"]=2000
        x=M.build_preview(p)
        self.assertEqual(x["status"],"PREVIEW_ONLY")
        self.assertIn("Given: 700 pts",x["embedPreview"]["fields"][2]["value"])

    def test_fields_are_discord_size_compliant(self):
        p=fixture()
        p["gave"]=copy.deepcopy(p["gave"])*4
        p["received"]=copy.deepcopy(p["received"])*4
        x=M.build_preview(p)
        self.assertEqual(x["status"],"PREVIEW_ONLY")
        for field in x["embedPreview"]["fields"]:
            self.assertLessEqual(len(field["name"]),256)
            self.assertLessEqual(len(field["value"]),1024)

    def test_1000_seeded_adversarial_cases_block(self):
        rng=random.Random(6088)
        for i in range(1000):
            p=fixture()
            mod=i%12
            if mod==0:p["gave"][0]["quantity"]=True
            elif mod==1:p["received"][0]["listedValue"]=rng.choice([-5,0,10**30])
            elif mod==2:p["gave"][0]["demand"]=11
            elif mod==3:p["received"][0]["liquidity"]=False
            elif mod==4:p["received"][0]["stability"]="UNKNOWN"
            elif mod==5:p["gave"][0]["name"]="<script>"
            elif mod==6:p["catalogVersion"]="bad value with spaces"
            elif mod==7:p["gave"].append({"name":"A","quantity":1})
            elif mod==8:p["received"]=p["received"]*5
            elif mod==9:p["startingInventoryListedValue"]=-1
            elif mod==10:p["webhookToken"]="DO_NOT_TOUCH"
            elif mod==11:p["received"]=None
            x=M.build_preview(p)
            self.assertEqual(x["status"],"BLOCKED",(i,x))
            safe(x)

    def test_no_transport_or_secret_access(self):
        s=(ROOT/"future_discord_trade_preview.py").read_text()
        for text in ("requests.get(","requests.post(","httpx.","urllib.request",
                     "DiscordWebhook","FireServer(",":HttpGet(","PostAsync(",
                     "setclipboard(","os.environ", "webhook_url"):
            self.assertNotIn(text,s)
        self.assertIn('"maySendWebhook":False',s)
if __name__=="__main__":
    unittest.main()
