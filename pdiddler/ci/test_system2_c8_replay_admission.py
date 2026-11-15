"""C8 adversarial read-only replay contract tests. All receipts synthetic."""
import copy
import unittest
from pdiddler.system2.c8_replay_admission import review, REQUIRED

CONTEXT = dict(sourceSha256="a"*64, jobId="fake-job-123",
               leaseId="fake-lease-123", partnerUserId=12345,
               offerRevision=3, inventoryCensusSha256="b"*64)

def sample():
    items = {}
    for name in REQUIRED:
        items[name] = dict(context=copy.deepcopy(CONTEXT), status="RESEARCH_ONLY",
            readOnly=True, authorizesTrade=False, authorizesOffer=False,
            authorizesAccept=False, authorizesChat=False,
            mayUseForStrategyLearning=False, mayReportProfit=False,
            maySendDiscordWebhook=False, serverCompletionProven=False)
    items["feedback"].update(realResponseRewardLabelsForModel=0,
        offerBundleFeaturesAvailableInV2=False, knownTradeSettlements=0)
    items["chat"]["personalReplyProven"] = False
    return items

class C8ReplayAdmission(unittest.TestCase):
    def test_aligned_is_never_authority(self):
        x=review(sample(), expected_context=CONTEXT)
        self.assertEqual(x["status"], "OFFLINE_C8_COMPONENT_CONTEXTS_ALIGNED")
        for flag in ("authorizesTrade","authorizesOffer","authorizesAccept",
                     "authorizesChat","mayUseForStrategyLearning",
                     "maySendDiscordWebhook","mayReportProfit",
                     "serverCompletionProven"):
            self.assertIs(x[flag],False)
    def test_missing_component(self):
        x=sample(); del x["market"]
        self.assertEqual(review(x,expected_context=CONTEXT)["status"],"BLOCKED")
    def test_extra_component(self):
        x=sample(); x["unreviewed"]={}
        self.assertEqual(review(x,expected_context=CONTEXT)["status"],"BLOCKED")
    def test_source_revision_and_session_drift(self):
        for key,value in (("sourceSha256","c"*64),("jobId","other"),
                          ("leaseId","other"),("partnerUserId",444),
                          ("offerRevision",4),("inventoryCensusSha256","c"*64)):
            with self.subTest(key=key):
                x=sample();x["bilateral"]["context"][key]=value
                self.assertEqual(review(x,expected_context=CONTEXT)["status"],"BLOCKED")
    def test_authority_leaks_every_component(self):
        for name in REQUIRED:
            for flag in ("authorizesTrade","authorizesOffer","authorizesAccept",
                         "authorizesChat","mayUseForStrategyLearning",
                         "mayReportProfit","maySendDiscordWebhook"):
                with self.subTest(name=name,flag=flag):
                    x=sample();x[name][flag]=True
                    self.assertEqual(review(x,expected_context=CONTEXT)["status"],"BLOCKED")
    def test_client_settlement_forgery(self):
        for name in REQUIRED:
            with self.subTest(name=name):
                x=sample();x[name]["serverCompletionProven"]=True
                self.assertEqual(review(x,expected_context=CONTEXT)["status"],"BLOCKED")
    def test_feedback_labels_are_not_learning(self):
        for field,value in (("realResponseRewardLabelsForModel",1),
                            ("offerBundleFeaturesAvailableInV2",True),
                            ("knownTradeSettlements",1)):
            with self.subTest(field=field):
                x=sample();x["feedback"][field]=value
                self.assertEqual(review(x,expected_context=CONTEXT)["status"],"BLOCKED")
    def test_unproven_public_chat_not_direct(self):
        x=sample();x["chat"]["personalReplyProven"]=True
        self.assertEqual(review(x,expected_context=CONTEXT)["status"],"BLOCKED")
    def test_upstream_blocked(self):
        x=sample();x["inventory"]["status"]="BLOCKED"
        self.assertEqual(review(x,expected_context=CONTEXT)["status"],"BLOCKED")
    def test_malformed_types(self):
        for bad in (None,[],{},{"market":None}):
            self.assertEqual(review(bad,expected_context=CONTEXT)["status"],"BLOCKED")
        for key,bad in (("offerRevision",True),("partnerUserId",True),
                        ("sourceSha256",None)):
            x=copy.deepcopy(CONTEXT);x[key]=bad
            self.assertEqual(review(sample(),expected_context=x)["status"],"BLOCKED")
    def test_hypothetical_gingerscope_not_completed(self):
        x=sample();x["growth"]["goalTargetHypotheticallyReceived"]=True
        result=review(x,expected_context=CONTEXT)
        self.assertFalse(result["serverCompletionProven"])
        self.assertFalse(result["authorizesAccept"])

if __name__=="__main__":
    unittest.main()
