"""Adversarial tests for actual two-sided incentive research, NOT an offer bot."""
from __future__ import annotations
from copy import deepcopy
from unittest.mock import patch
import unittest

from pdiddler.system2 import supreme_only_bilateral_partner_friction_shadow as lab

NOW=1794951710
def slot(key,quantity=1):
 return {"rawGameKey":key,"quantity":quantity}
def route(give,receive,preference="UNKNOWN",interest=None):
 return {"give":give,"receive":receive,
         "partnerPreferenceScenario":preference,"interestKey":interest}
def request():
 return {
  "kind":"SYNTHETIC_BILATERAL_RESEARCH_ONLY",
  "valueSource":"SUPREME_ONLY",
  "ownHypotheticalStock":{"FlowerwoodKnife":1,"Harvester":1,
                          "GreenLuger":1,"Logchopper":1,"Icebreaker":2,
                          "Emberbow":1,"Gingerscope":1},
  "partnerHypotheticalStock":{"Harvester":1,"FlowerwoodKnife":1,
                             "GreenLuger":1,"Logchopper":1,
                             "Icepiercer":1,"Gingerscope":1,
                             "Icebreaker":8,"Emberbow":1},
  "routes":[
   route([slot("FlowerwoodKnife")],[slot("Harvester")],
         "HYPOTHETICAL_VALUE_WATCHER"),
   route([slot("Logchopper")],[slot("GreenLuger")],
         "HYPOTHETICAL_DEMAND_SEEKER"),
  ]
 }

class BilateralIncentiveShadowTests(unittest.TestCase):
 def evaluate(self,req=None,epoch=NOW):
  return lab.evaluate(request() if req is None else req,now_epoch=epoch)
 def blocked(self,req,reason):
  result=self.evaluate(req)
  self.assertEqual(result["status"],"BLOCKED")
  self.assertIn(reason,result["reason"])
  self.assertIs(result["authorizesTrade"],False)
  self.assertIs(result["authorizesAccept"],False)
  self.assertIs(result["mayUseForStrategyLearning"],False)
  return result
 def test_our_paper_gain_is_exact_other_side_paper_loss(self):
  x=self.evaluate()
  self.assertEqual(x["status"],"BILATERAL_FRICTION_SHADOW_RESEARCH_ONLY")
  self.assertEqual(x["sourcePublisherEdition"],"2026-11-15T11:59:41-05:00")
  self.assertEqual(x["sourceCaptureUtc"],"2026-11-17T21:41:18Z")
  self.assertEqual([r["ourSupremeListedDelta"] for r in x["routes"]],[40,6])
  self.assertEqual([r["partnerSupremeListedDelta"] for r in x["routes"]],[-40,-6])
  for r in x["routes"]:
   self.assertEqual(r["ourSupremeListedDelta"],-r["partnerSupremeListedDelta"])
   self.assertIn("PARTNER_PAPER_LISTED_LOSS_NEEDS_OTHER_MOTIVE",r["warnings"])
   self.assertIn("PARTNER_WILLINGNESS_UNVERIFIED",r["warnings"])
   self.assertIsNone(r["actualPartnerWouldAccept"])
   self.assertFalse(r["tradeActionable"])
 def test_no_acceptance_probability_or_real_partner_classification(self):
  x=self.evaluate()
  self.assertIsNone(x["empiricalPartnerAcceptanceProbability"])
  self.assertEqual(x["empiricalRetradeLiquidity"],"UNKNOWN")
  self.assertFalse(x["actualPartnerIdentityProven"])
  self.assertFalse(x["actualCounterpartyOwnershipProven"])
  self.assertFalse(x["liveOfferRankingAuthorized"])
  self.assertFalse(x["authorizesOffer"])
  self.assertFalse(x["authorizesAccept"])
  self.assertFalse(x["maySendDiscordWebhook"])
  self.assertFalse(x["mayReportProfit"])
  self.assertFalse(x["calibratedToRealTrades"])
  self.assertFalse(x["isOfferRanking"])
 def test_equal_paper_trade_cannot_imply_acceptance(self):
  req=request()
  req["routes"]=[
   route([slot("Harvester")],[slot("Harvester")]),
   route([slot("GreenLuger")],[slot("GreenLuger")],
        "HYPOTHETICAL_VALUE_WATCHER")
  ]
  self.blocked(req,"SAME_RAW_KEY_BOTH_SIDES_AMBIGUOUS")
  # Different keys with equal publisher listing are allowed, but not accepted.
  rows=lab.catalog()
  matches={}
  for key,row in rows.items():
   matches.setdefault(row["supremeListed"],[]).append(key)
  pair=next((z for z in matches.values() if len(z)>1 and
             not any(k=="Gingerscope" for k in z)),None)
  self.assertIsNotNone(pair)
  a,b=pair[:2]
  req=request()
  req["ownHypotheticalStock"]={a:1}
  req["partnerHypotheticalStock"]={b:1}
  req["routes"]=[route([slot(a)],[slot(b)]),
                 route([slot(a)],[slot(b)],"HYPOTHETICAL_VALUE_WATCHER")]
  x=self.evaluate(req)
  self.assertEqual(x["status"],"BILATERAL_FRICTION_SHADOW_RESEARCH_ONLY")
  self.assertEqual(x["routes"][0]["ourSupremeListedDelta"],0)
  self.assertIn("LISTED_EVEN_DOES_NOT_IMPLY_ACCEPTANCE",x["routes"][0]["warnings"])
 def test_demand_ordinal_is_not_empirical_liquidity(self):
  req=request()
  req["routes"]=[
   route([slot("Emberbow")],[slot("Harvester")],
         "HYPOTHETICAL_DEMAND_SEEKER"),
   route([slot("FlowerwoodKnife")],[slot("Icepiercer")],
         "HYPOTHETICAL_DEMAND_SEEKER")]
  x=self.evaluate(req)
  self.assertEqual(x["status"],"BILATERAL_FRICTION_SHADOW_RESEARCH_ONLY")
  self.assertEqual(x["routes"][0]["status"],"BLOCKED_UNAPPROVED_OUR_LOSS")
  self.assertEqual(x["routes"][1]["status"],"BLOCKED_UNAPPROVED_OUR_LOSS")
  self.assertIsNone(x["empiricalPartnerAcceptanceProbability"])
 def test_our_negative_delta_is_never_authorized(self):
  req=request()
  req["routes"]=[
   route([slot("Harvester")],[slot("FlowerwoodKnife")]),
   route([slot("Emberbow")],[slot("GreenLuger")])]
  x=self.evaluate(req)
  self.assertEqual([r["status"] for r in x["routes"]],
                   ["BLOCKED_UNAPPROVED_OUR_LOSS"]*2)
  self.assertFalse(x["authorizesTrade"])
 def test_incoming_gingerscope_only_research_not_offer(self):
  req=request()
  req["routes"]=[
   route([slot("FlowerwoodKnife")],[slot("Gingerscope")]),
   route([slot("Logchopper")],[slot("Gingerscope")],
         "HYPOTHETICAL_COLLECTOR_INTEREST","Logchopper")]
  x=self.evaluate(req)
  self.assertEqual(x["status"],"BILATERAL_FRICTION_SHADOW_RESEARCH_ONLY")
  self.assertFalse(x["authorizesOffer"])
  self.assertTrue(all("PARTNER_PAPER_LISTED_LOSS_NEEDS_OTHER_MOTIVE" in r["warnings"]
                      for r in x["routes"]))
 def test_owned_gingerscope_never_outgoing(self):
  req=request()
  req["routes"][0]["give"]=[slot("Gingerscope")]
  self.blocked(req,"GINGERSCOPE_NEVER_OUTGOING")
 def test_unknown_item_id_no_label_guess(self):
  req=request()
  req["routes"][0]["receive"]=[slot("SomeUnknownChroma")]
  self.blocked(req,"PARTNER_OUTGOING_RAW_KEY_OR_QUANTITY_NOT_PROVEN")
 def test_unverified_partner_stock_not_trusted(self):
  req=request()
  req["routes"][0]["receive"]=[slot("Harvester",2)]
  self.blocked(req,"PARTNER_OUTGOING_RAW_KEY_OR_QUANTITY_NOT_PROVEN")
 def test_four_physical_slots_not_total_copies(self):
  req=request()
  req["ownHypotheticalStock"]={"Icebreaker":8,"Logchopper":1,
                                "Harvester":1,"FlowerwoodKnife":1,"GreenLuger":1}
  req["partnerHypotheticalStock"]={"GreenLuger":1,"Harvester":1}
  req["routes"][0]["give"]=[
   slot("Icebreaker",8),slot("Logchopper"),
   slot("Harvester"),slot("FlowerwoodKnife"),slot("GreenLuger")]
  self.blocked(req,"OUR_OUTGOING_PHYSICAL_SLOTS_INVALID")
  req["partnerHypotheticalStock"]["Gingerscope"]=1
  req["routes"][0]["give"]=[slot("Icebreaker",8)]
  req["routes"][0]["receive"]=[slot("Gingerscope")]
  x=self.evaluate(req)
  self.assertEqual(x["status"],"BILATERAL_FRICTION_SHADOW_RESEARCH_ONLY")
  self.assertEqual(x["routes"][0]["status"],"BLOCKED_STACK_PRICE_UNVERIFIED")
 def test_bad_duplicate_or_unexpected_fields(self):
  req=request()
  req["routes"][0]["give"].append(slot("FlowerwoodKnife"))
  self.blocked(req,"OUR_OUTGOING_RAW_KEY_OR_QUANTITY_NOT_PROVEN")
  req=request()
  req["routes"][0]["give"][0]["valueFromSecondSite"]=99999
  self.blocked(req,"OUR_OUTGOING_UNEXPECTED_ITEM_FIELD")
 def test_incompatible_publisher_and_live_request_forbidden(self):
  req=request();req["valueSource"]="MM2VALUES"
  self.blocked(req,"OTHER_PUBLISHER_OR_LIVE_REQUEST_FORBIDDEN")
  req=request();req["kind"]="REAL_PLAYER_ACCEPT_THIS_NOW"
  self.blocked(req,"OTHER_PUBLISHER_OR_LIVE_REQUEST_FORBIDDEN")
 def test_actual_partner_personas_not_proven(self):
  req=request()
  req["routes"][0]["partnerPreferenceScenario"]="GREEDY_PLAYER_CONFIRMED"
  self.blocked(req,"UNSUPPORTED_HYPOTHETICAL_PREFERENCE")
 def test_collector_interest_must_be_explicit_and_offered(self):
  req=request()
  req["routes"][0]["partnerPreferenceScenario"]="HYPOTHETICAL_COLLECTOR_INTEREST"
  req["routes"][0]["interestKey"]="Logchopper"
  x=self.evaluate(req)
  self.assertEqual(x["status"],"BILATERAL_FRICTION_SHADOW_RESEARCH_ONLY")
  self.assertIn("HYPOTHETICAL_COLLECTOR_INTEREST_NOT_OFFERED",
                x["routes"][0]["warnings"])
  req["routes"][0]["interestKey"]="FlowerwoodKnife"
  x=self.evaluate(req)
  self.assertIn("HYPOTHETICAL_COLLECTOR_INTEREST_INCLUDED",
                x["routes"][0]["warnings"])
 def test_duplicate_routes_are_not_double_counted(self):
  req=request()
  req["routes"][1]=deepcopy(req["routes"][0])
  self.blocked(req,"DUPLICATE_COUNTERPARTY_ROUTE")
 def test_expired_or_future_source_refuses_paper_research(self):
  for t in (1794951677,1794973279):
   x=self.evaluate(epoch=t)
   self.assertEqual(x["status"],"BLOCKED")
   self.assertIn("SUPREME_ONLY_RESEARCH_CAPTURE_STALE_OR_FUTURE",x["reason"])
 def test_tampered_digest_rejected(self):
  with patch.object(lab,"SOURCE_SHA256","0"*64):
   self.blocked(request(),"SOURCE_SHA256_UNVERIFIED")
 def test_value_only_is_not_approved_live_risk_budget(self):
  x=self.evaluate()
  self.assertTrue(all(r["empiricalPartnerFillEvidenceCount"]==0
                      for r in x["routes"]))
  self.assertTrue(all(not r["tradeActionable"] for r in x["routes"]))
  self.assertFalse(x["authorizesTrade"])
  self.assertFalse(x["authorizesAccept"])

class RenewedBilateralSourceTests(unittest.TestCase):
 def setUp(self):
  from pathlib import Path
  from datetime import datetime
  self.raw=(Path(__file__).resolve().parents[1]/
    "system2/supreme_only_189_research_catalog_2026_11_25_publication_nov23.json").read_bytes()
  self.capture=int(datetime.fromisoformat("2026-11-25T06:09:59+00:00").timestamp())

 def test_shared_source_reprices_hypothetical_partner_incentive(self):
  r=lab.evaluate(request(),now_epoch=self.capture,source_bytes=self.raw)
  self.assertEqual(r["status"],"BILATERAL_FRICTION_SHADOW_RESEARCH_ONLY")
  self.assertEqual(r["sourcePublisherEdition"],"2026-11-23T19:13:44-05:00")
  self.assertEqual(r["sourceCaptureUtc"],"2026-11-25T06:09:59Z")
  self.assertEqual(r["routes"][0]["ourSupremeListedDelta"],75)
  self.assertEqual(r["routes"][0]["partnerSupremeListedDelta"],-75)
  self.assertIn("HYPOTHETICAL_VALUE_WATCHER_HAS_PAPER_DISINCENTIVE",r["routes"][0]["warnings"])
  self.assertIsNone(r["empiricalPartnerAcceptanceProbability"])
  self.assertFalse(r["authorizesOffer"])

 def test_expired_or_tampered_explicit_source_cannot_fall_back(self):
  for clock,raw,reason in (
     (self.capture+21601,self.raw,"SOURCE_EXPIRED_NO_OTHER_LIST_FALLBACK"),
     (self.capture-1,self.raw,"CAPTURE_FROM_FUTURE"),
     (self.capture,self.raw+b" ","CATALOG_GIT_BLOB_MISMATCH"),
     (NOW,b"{}","CATALOG_GIT_BLOB_MISMATCH")):
   with self.subTest(clock=clock,reason=reason):
    r=lab.evaluate(request(),now_epoch=clock,source_bytes=raw)
    self.assertEqual(r["status"],"BLOCKED")
    self.assertIn(reason,r["reason"])
    self.assertFalse(r["authorizesAccept"])
  self.assertEqual(lab.evaluate(request(),now_epoch=self.capture)["status"],"BLOCKED")

 def test_old_historical_default_stays_reproducible(self):
  r=lab.evaluate(request(),now_epoch=NOW)
  self.assertEqual(r["routes"][0]["ourSupremeListedDelta"],40)
  self.assertEqual(r["sourcePublisherEdition"],"2026-11-15T11:59:41-05:00")

if __name__=="__main__":
 unittest.main()
