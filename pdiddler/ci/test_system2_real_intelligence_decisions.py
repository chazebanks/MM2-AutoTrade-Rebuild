"""Independent behavioral oracles for five real System2 algorithmic capabilities.

All fixtures are deliberately synthetic. A PASS here is necessary but
insufficient for live-MM2 proof. Neither live trading nor API credentials.
"""
import copy
import unittest

from pdiddler.system2.system2_decision_acceptance_engine import (
    inventory_admission,bilateral_decision,growth_route_decision,
    adaptive_response,learning_decision,PROVENANCE_DENIAL,
)

AT="2026-11-14T15:00:00Z"
def quote(v,d=5,st="Stable",lo=None,hi=None,category="Godly"):
    return {"value":v,"low":v if lo is None else lo,
       "high":v if hi is None else hi,"demand":d,"stability":st,
       "category":category,"chroma":category.startswith("Chroma ")}
C={"schema":"SYNTHETIC_S2_EXACT_RAW_KEY_MARKET_FIXTURE",
   "publicationAt":"2026-11-14T14:00:00Z",
   "expiresAt":"2026-11-15T00:00:00Z",
   "quotes":{
     "Gingerscope":quote(16000,5,"Stable",category="Ancient"),
     "OwnA":quote(100,6),
     "OwnB":quote(30,5),
     "Cheap":quote(40,6),
     "Mid":quote(110,8),
     "Valuable":quote(150,5),
     "Good":quote(110,9),
     "Junk":quote(135,1,"Unsafe",lo=70,hi=165),
     "ChromaSample":quote(80,8,category="Chroma Godly"),
   }}
OWN={"OwnA":1,"OwnB":1}
def slot(k,q=1):return {"key":k,"copies":q}
def dec(give,rec):return {"give":give,"receive":rec}
def task(fn,**args):
    return fn(catalog=C,inventory=OWN,at=AT,**args)
def event(seq,kind,rev=0,session="session",partner="partner"):
    return {"session":session,"partner":partner,"seq":seq,
     "revision":rev,"kind":kind,"scope":"SYNTHETIC_EXACT_PARTNER"}
def dataset():
    rows=[]
    for i in range(12):
        holdout=i>=8
        label=i%2
        rows.append({"episode":str(i),"partner":f"partner{i}",
         "scope":"PUBLIC_NONALT","kind":
         "EXPLICIT_PARTNER_REQUEST_ACCEPTED" if label else "EXPLICIT_PARTNER_DECLINE",
         "attributed":True,"holdout":holdout,
         "prediction":0.9 if label else 0.1,
         "baseline":0.5})
    return rows

class S2AcceptanceOracles(unittest.TestCase):
    def assertSafety(self,v):
        for k,value in PROVENANCE_DENIAL.items():
            self.assertEqual(v[k],value,(k,v))
        self.assertIs(v["fixtureOnly"],True)
        self.assertIs(v["originalMM2LivePass"],False)

    def test_one_exact_market_census_and_stack_quantity(self):
        r=task(inventory_admission,offer=[slot("OwnA")])
        self.assertEqual(r["status"],"RESEARCH_DECISION_PASS")
        self.assertEqual(r["visiblePhysicalOfferSlots"],1)
        self.assertEqual(r["portfolio"]["total"],130)
        self.assertSafety(r)

    def test_one_stale_future_and_nonexistent_source_date_block(self):
        for publication,expiry in [
          ("2026-11-13T00:00:00Z","2026-11-14T14:00:00Z"),
          ("2026-11-15T00:00:00Z","2026-11-15T12:00:00Z"),
          ("2026-02-30T00:00:00Z","2026-11-15T00:00:00Z")]:
            with self.subTest(publication=publication):
                z=copy.deepcopy(C);z["publicationAt"]=publication;z["expiresAt"]=expiry
                r=inventory_admission(catalog=z,inventory=OWN,at=AT)
                self.assertEqual(r["status"],"BLOCKED")
                self.assertSafety(r)

    def test_one_protected_outbound_and_unknown_identity_block(self):
        r=inventory_admission(catalog=C,inventory={"Gingerscope":1},at=AT,
                              offer=[slot("Gingerscope")])
        self.assertEqual(r["reason"],"PROTECTED_GINGERSCOPE_NEVER_OUTBOUND")
        bad=task(inventory_admission,offer=[slot("maybe-ChromaSample")])
        self.assertEqual(bad["status"],"BLOCKED")
        self.assertSafety(bad)

    def test_one_four_physical_slots_not_four_copies(self):
        inventory={"OwnA":7}
        r=inventory_admission(catalog=C,inventory=inventory,at=AT,
                               offer=[slot("OwnA",5)])
        self.assertEqual(r["status"],"RESEARCH_DECISION_PASS")
        self.assertEqual(r["visiblePhysicalOfferSlots"],1)
        self.assertEqual(r["outgoingCopies"],5)
        five=[slot(k) for k in ("OwnA","OwnB","Cheap","Good","Mid")]
        blocked=inventory_admission(catalog=C,inventory={
           k:1 for k in ("OwnA","OwnB","Cheap","Good","Mid")},
           at=AT,offer=five)
        self.assertEqual(blocked["status"],"BLOCKED")

    def test_two_nominally_greater_but_risky_junk_loses_to_robust_good(self):
        opts=[dec([slot("OwnA")],[slot("Junk")]),
              dec([slot("OwnA")],[slot("Good")])]
        r=task(bilateral_decision,alternatives=opts)
        self.assertEqual(r["status"],"RESEARCH_DECISION_PASS")
        self.assertEqual(r["selectedIndex"],1)
        self.assertEqual(r["considered"][0]["nominalGain"],35)
        self.assertEqual(r["considered"][0]["rangeWorstCaseGain"],-30)
        self.assertEqual(r["considered"][1]["rangeWorstCaseGain"],10)
        self.assertFalse(r["opponentIncentiveKnown"])
        self.assertSafety(r)

    def test_two_five_demand_or_low_demand_not_probabilities(self):
        opts=[dec([slot("OwnA")],[slot("Good")]),
              dec([slot("OwnA")],[slot("Mid")])]
        r=task(bilateral_decision,alternatives=opts)
        self.assertEqual(r["status"],"RESEARCH_DECISION_PASS")
        self.assertIsNone(r["considered"][0]["empiricalFillRate"])
        self.assertIsNone(r["considered"][1]["empiricalFillRate"])
        self.assertTrue(r["deploymentWouldRequireMeasuredPartnerPreference"])
        self.assertSafety(r)

    def test_two_no_conservative_option_abstains_instead_of_fabrication(self):
        opts=[dec([slot("OwnA")],[slot("OwnB")]),
              dec([slot("OwnA")],[slot("Cheap")])]
        r=task(bilateral_decision,alternatives=opts)
        self.assertEqual(r["status"],"ABSTAIN")
        self.assertIsNone(r["selectedIndex"])
        self.assertSafety(r)

    def test_two_duplicate_hypothesis_rejected(self):
        a=dec([slot("OwnA")],[slot("Good")])
        r=task(bilateral_decision,alternatives=[a,copy.deepcopy(a)])
        self.assertEqual(r["status"],"BLOCKED")
        self.assertEqual(r["reason"],"DUPLICATE_COUNTERFACTUAL")

    def test_three_compounding_quality_beats_concentrated_route_on_equal_gain(self):
        routes=[
          [dec([slot("OwnB")],[slot("Cheap")]),
           dec([slot("OwnA")],[slot("Mid")])],
          [dec([slot("OwnB")],[slot("Cheap")]),
           dec([slot("OwnA"),slot("Cheap")],[slot("Valuable")])],
        ]
        r=task(growth_route_decision,routes=routes)
        self.assertEqual(r["status"],"RESEARCH_DECISION_PASS")
        self.assertEqual(r["selectedRouteIndex"],0)
        self.assertEqual(r["auditedRoutes"][0]["endingListedValue"],150)
        self.assertEqual(r["auditedRoutes"][1]["endingListedValue"],150)
        self.assertLess(
          r["auditedRoutes"][0]["quality"]["concentrationBasisPoints"],
          r["auditedRoutes"][1]["quality"]["concentrationBasisPoints"])
        self.assertFalse(r["futureSellersInvented"])
        self.assertSafety(r)

    def test_three_no_unapproved_value_loss_even_if_great_demand(self):
        routes=[
          [dec([slot("OwnA")],[slot("Cheap")]),
           dec([slot("Cheap")],[slot("Good")])],
          [dec([slot("OwnB")],[slot("Cheap")]),
           dec([slot("OwnA")],[slot("Mid")])]
        ]
        r=task(growth_route_decision,routes=routes)
        self.assertEqual(r["status"],"BLOCKED")
        self.assertEqual(r["reason"],"LOSS_BUDGET_NULL_NEVER_APPROVED")
        self.assertSafety(r)

    def test_three_never_offer_target_outbound(self):
        routes=[
          [dec([slot("Gingerscope")],[slot("Valuable")]),
           dec([slot("OwnB")],[slot("Cheap")])],
          [dec([slot("OwnB")],[slot("Cheap")]),
           dec([slot("OwnA")],[slot("Mid")])]]
        r=growth_route_decision(catalog=C,
               inventory={"Gingerscope":1,"OwnA":1,"OwnB":1},
               at=AT,routes=routes)
        self.assertEqual(r["status"],"BLOCKED")
        self.assertEqual(r["reason"],"PROTECTED_GINGERSCOPE_NEVER_OUTBOUND")

    def test_three_circular_repackaging_no_false_growth(self):
        routes=[
          [dec([slot("OwnB")],[slot("Cheap")]),
           dec([slot("Cheap")],[slot("OwnB")])],
          [dec([slot("OwnB")],[slot("Cheap")]),
           dec([slot("OwnA")],[slot("Mid")])]
        ]
        r=task(growth_route_decision,routes=routes)
        self.assertEqual(r["status"],"BLOCKED")
        self.assertEqual(r["reason"],"LOSS_BUDGET_NULL_NEVER_APPROVED")

    def test_four_offer_revision_invalidates_plan_without_persona_label(self):
        r=adaptive_response(events=[
             event(1,"PARTNER_OFFER_STABLE"),
             event(2,"PARTNER_OFFER_REVISED",1),
             event(3,"CHAT_OTHER_CONVERSATION",1)],
             expected_session="session",expected_partner="partner")
        self.assertEqual(r["status"],"RESEARCH_DECISION_PASS")
        self.assertFalse(r["previousCandidateReusable"])
        self.assertEqual(r["nextResearchAction"],"REPRICE_AND_RECONSIDER_BEFORE_ANY_ACTION")
        self.assertFalse(r["learnedGreedyPersonality"])
        self.assertSafety(r)

    def test_four_separate_decline_timeout_and_cancel(self):
        for kind,want in [("PARTNER_DECLINED","STOP_AND_ROTATE_FUTURE_PARTNER"),
                          ("PARTNER_NO_RESPONSE_TIMEOUT","MARK_CENSORED_AND_ROTATE"),
                          ("PARTNER_CANCELLED","CANCELLED_NO_PERSONALITY_LABEL"),
                          ("CLIENT_WINDOW_CLOSED_UNKNOWN","ABSTAIN_UNVERIFIED_OUTCOME")]:
            with self.subTest(kind=kind):
                r=adaptive_response(events=[event(1,kind)],
                 expected_session="session",expected_partner="partner")
                self.assertEqual(r["nextResearchAction"],want)
                self.assertSafety(r)

    def test_four_wrong_partner_replay_future_revisions_block(self):
        cases=[
          [event(1,"PARTNER_OFFER_STABLE",partner="outsider")],
          [event(2,"PARTNER_OFFER_STABLE")],
          [event(1,"PARTNER_OFFER_STABLE"),event(2,"PARTNER_OFFER_REVISED",2)],
          [event(1,"PARTNER_DECLINED"),event(2,"PARTNER_OFFER_STABLE")],
        ]
        for sequence in cases:
            with self.subTest(events=sequence):
                r=adaptive_response(events=sequence,
                  expected_session="session",expected_partner="partner")
                self.assertEqual(r["status"],"BLOCKED")
                self.assertSafety(r)

    def test_five_holdout_beats_baseline_without_production_learning(self):
        r=learning_decision(episodes=dataset())
        self.assertEqual(r["status"],"RESEARCH_DECISION_PASS")
        self.assertTrue(r["researchModelSelected"])
        self.assertLess(r["brierScore"],r["baselineBrierScore"])
        self.assertFalse(r["productionLearningAuthorized"])
        self.assertEqual(r["verifiedTradesForProfit"],0)
        self.assertSafety(r)

    def test_five_alt_and_unknown_excluded_no_fictitious_training(self):
        data=dataset()
        data[0]["scope"]="MAIN_ALT_TEST"
        data[1]["kind"]="UNKNOWN"
        data[2]["kind"]="NO_RESPONSE_TIMEOUT"
        r=learning_decision(episodes=data)
        self.assertEqual(r["status"],"ABSTAIN")
        self.assertEqual(r["quarantined"]["ALT_OR_UNATTRIBUTED"],1)
        self.assertEqual(r["quarantined"]["CENSORED_OR_UNKNOWN"],2)
        self.assertFalse(r["researchModelSelected"])
        self.assertSafety(r)

    def test_five_seen_partner_in_holdout_rejected(self):
        d=dataset()
        d[8]["partner"]=d[0]["partner"]
        r=learning_decision(episodes=d)
        self.assertEqual(r["status"],"ABSTAIN")
        self.assertEqual(r["reason"],"INSUFFICIENT_INDEPENDENT_PARTNER_HOLDOUT")
        self.assertSafety(r)

    def test_five_new_model_worse_than_baseline_must_not_update(self):
        d=dataset()
        for row in d:row["prediction"]=1-row["prediction"]
        r=learning_decision(episodes=d)
        self.assertEqual(r["status"],"ABSTAIN")
        self.assertFalse(r["researchModelSelected"])
        self.assertSafety(r)

    def test_five_duplicate_episode_fails_closed(self):
        d=dataset(); d[1]["episode"]=d[0]["episode"]
        r=learning_decision(episodes=d)
        self.assertEqual(r["status"],"BLOCKED")
        self.assertEqual(r["reason"],"LEARNING_REPLAYED_EPISODE")
        self.assertSafety(r)

    def test_full_five_capability_chain_with_distinct_expected_results(self):
        result=[
          task(inventory_admission,offer=[slot("OwnA")]),
          task(bilateral_decision,alternatives=[
            dec([slot("OwnA")],[slot("Junk")]),
            dec([slot("OwnA")],[slot("Good")])]),
          task(growth_route_decision,routes=[
            [dec([slot("OwnB")],[slot("Cheap")]),
             dec([slot("OwnA")],[slot("Mid")])],
            [dec([slot("OwnB")],[slot("Cheap")]),
             dec([slot("OwnA"),slot("Cheap")],[slot("Valuable")])]
          ]),
          adaptive_response(events=[
             event(1,"PARTNER_OFFER_STABLE"),
             event(2,"PARTNER_OFFER_REVISED",1)],
             expected_session="session",expected_partner="partner"),
          learning_decision(episodes=dataset()),
        ]
        self.assertEqual(len({v["capability"] for v in result}),5)
        self.assertTrue(all(v["status"]=="RESEARCH_DECISION_PASS" for v in result))
        self.assertEqual(result[1]["selectedIndex"],1)
        self.assertEqual(result[2]["selectedRouteIndex"],0)
        self.assertFalse(result[3]["previousCandidateReusable"])
        self.assertTrue(result[4]["researchModelSelected"])
        self.assertTrue(all(v["originalMM2LivePass"] is False for v in result))
        self.assertTrue(all(v["mayUseForLiveOffer"] is False for v in result))
        self.assertTrue(all(v["serverSettlementProven"] is False for v in result))
if __name__=="__main__":
    unittest.main()
