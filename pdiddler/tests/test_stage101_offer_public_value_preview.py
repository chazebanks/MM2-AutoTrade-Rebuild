"""Stage101: real original Stage82/84/94 public-source-to-GUI research preview.

The 15 originals are SHA-pinned and rebuilt by the existing Stage94 test
fixtures in the dedicated workflow. All displayed prices remain public
research estimates, NEVER independent game raw-key identity/trade quotes.
"""
from __future__ import annotations
import copy
from datetime import datetime,timezone
import hashlib
import json
import os
import random
import unittest

from pdiddler.intelligence_lab.stage101_offer_public_value_preview import (
    preview_public_reference, PUBLISHED, EXPIRES,
)
T_PRE=int(datetime(2026,11,10,10,0,0,tzinfo=timezone.utc).timestamp())
T_EXP=int(datetime(2026,11,10,22,26,48,tzinfo=timezone.utc).timestamp())
FALSE_FLAGS=(
    "currentGameItemIdentityAuthenticated","numericSupremeCheckerIdVerified",
    "rawOfferKeyBoundToPhysicalSlot","uniqueWeaponInstanceProven",
    "currentPricesVerified","priceForTradeVerified",
    "sourcePublisherFreshForTrade","authenticatedOwnedInventory",
    "serverTradeRevisionProven","serverAttestation","serverCompletionProven",
    "eventSessionAssociationProven","callbackCausalityProven",
    "authorizesTrade","authorizesAccept","mayRecordCompletedTrade",
    "mayReportProfit","maySendDiscordWebhook","mayUseForStrategyLearning",
)
def offer(ours=None,theirs=None,**fields):
    o={
      "ours":ours if ours is not None else [{"slot":1,"label":"Emberbow","chroma":False,"quantity":1}],
      "theirs":theirs if theirs is not None else [{"slot":1,"label":"Gingerscope","chroma":False,"quantity":1}],
      "exactPartnerClientBound":True,
      "stage9ObserverBound":True,
      "acceptedIndicatorsFalse":True,
      "pendingOfferMutation":False,
      "localOfferEpoch":4,
      "stableGuiReads":3,
      "clientOnly":True,
      "serverTradeRevisionProven":False,
      "rawItemIdConfirmed":False,
    }
    o.update(fields)
    return o

class ActualOriginalStage101Preview(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if os.getenv("STAGE101_REQUIRE_PINNED")!="1":
            raise unittest.SkipTest("Stage101 needs original 15-source pinned public research CI")
        from pdiddler.tests.test_stage94_public_source_join import ActualOriginalPublicSourceJoin
        from pdiddler.intelligence_lab.stage94_public_source_join import join_public_sources
        ActualOriginalPublicSourceJoin.setUpClass()
        cls.original=ActualOriginalPublicSourceJoin
        cls.source=join_public_sources(cls.original.old,cls.original.new,
                                      cls.original.newSiteSlugs,at_epoch=T_PRE)
        assert cls.source["status"]=="PUBLIC_RESEARCH_JOIN_READY"
        assert len(cls.source["rows"])==189
        d=hashlib.sha256(json.dumps(cls.source["rows"],sort_keys=True,
            separators=(",",":"),ensure_ascii=True).encode()).hexdigest()
        print("STAGE101_SOURCE_189_ROW_SHA256="+d)
    def check_denied(self,r):
        self.assertIs(r["readOnly"],True)
        self.assertIs(r["researchOnly"],True)
        self.assertIs(r["nameOnlyUnbound"],True)
        for k in FALSE_FLAGS:
            self.assertIs(r[k],False,k)
        self.assertEqual(r["tradeOutcome"],"UNKNOWN")
        self.assertNotIn("checkerId",json.dumps(r))
        self.assertNotIn("serverTransactionId",json.dumps(r))
    def test_real_189_rows_produce_two_sided_PUBLIC_RESEARCH_candidate_only(self):
        r=preview_public_reference(self.source,offer(),now_epoch=T_PRE)
        self.assertEqual(r["status"],"HISTORICAL_PUBLIC_CANDIDATES_RESEARCH_ONLY",r)
        self.assertEqual(r["matchedCandidateSlots"],2)
        self.assertEqual(r["offerReferenceCompleteness"],"BOTH_SIDES_PUBLIC_NAME_CANDIDATES")
        self.assertEqual(r["sourcePriceState"],"HISTORICAL_RESEARCH_WITHIN_CAPTURE_WINDOW")
        self.assertEqual(r["ourReferenceTotal"],650)
        self.assertEqual(r["theirReferenceTotal"],16000)
        self.assertEqual(r["illustrativeReferenceDifference"],15350)
        self.assertEqual(r["rows"][0]["identityEvidence"],"NAME_ONLY_NOT_RAW_KEY_BOUND")
        self.assertIsNone(r["rows"][0]["historicalPublicRawKey"])
        self.assertEqual(r["rows"][1]["publicReferenceName"],"Gingerscope")
        self.assertEqual(r["rows"][1]["publicDemandResearch"],5)
        self.assertEqual(r["rows"][1]["liquidity"],"UNVERIFIED")
        self.check_denied(r)
    def test_real_chroma_and_stack_quantities_never_convert_to_raw_key_proof(self):
        s=[{"slot":2,"label":"Chroma Fang","chroma":True,"quantity":2}]
        r=preview_public_reference(self.source,offer(ours=s),now_epoch=T_PRE)
        self.assertEqual(r["status"],"HISTORICAL_PUBLIC_CANDIDATES_RESEARCH_ONLY")
        self.assertEqual(r["matchedCandidateSlots"],2)
        self.assertEqual(r["rows"][0]["quantity"],2)
        self.assertIn(r["rows"][0]["publicReferencePage"],("chroma",))
        self.assertEqual(r["rows"][0]["publicValueSubtotalResearch"],
                         2*r["rows"][0]["publicValuePerCopyResearch"])
        self.check_denied(r)
    def test_unmatched_alias_stops_two_sided_value_or_spread(self):
        r=preview_public_reference(self.source,offer(theirs=[
          {"slot":1,"label":"Ginger Scope","chroma":False,"quantity":1}]),now_epoch=T_PRE)
        self.assertEqual(r["status"],"PUBLIC_NAME_MATCH_INCOMPLETE_RESEARCH_ONLY")
        self.assertEqual(r["unmatchedSlots"],1)
        self.assertIsNone(r["illustrativeReferenceDifference"])
        self.assertIsNone(r["theirReferenceTotal"])
        self.check_denied(r)
    def test_chroma_variant_and_nonchroma_fang_never_cross(self):
        r=preview_public_reference(self.source,offer(ours=[
          {"slot":1,"label":"Chroma Fang","chroma":False,"quantity":1}]),now_epoch=T_PRE)
        self.assertEqual(r["unmatchedSlots"],1)
        self.check_denied(r)
        r=preview_public_reference(self.source,offer(ours=[
          {"slot":1,"label":"Fang","chroma":True,"quantity":1}]),now_epoch=T_PRE)
        self.assertEqual(r["unmatchedSlots"],1)
        self.check_denied(r)
    def test_expiry_switches_to_archived_without_double_valuing_old_quotes(self):
        for when in (T_EXP,T_EXP+1,T_EXP+3600*24):
            r=preview_public_reference(self.source,offer(),now_epoch=when)
            self.assertEqual(r["sourcePriceState"],"ARCHIVED_RESEARCH_CAPTURE_EXPIRED")
            self.assertIsNone(r["ourReferenceTotal"])
            self.assertIsNone(r["theirReferenceTotal"])
            self.assertIsNone(r["illustrativeReferenceDifference"])
            self.assertEqual(r["matchedCandidateSlots"],2)
            self.assertEqual(r["rows"][1]["publicValuePerCopyResearch"],16000)
            self.check_denied(r)
        r=preview_public_reference(self.source,offer(),now_epoch=T_EXP-1)
        self.assertEqual(r["sourcePriceState"],"HISTORICAL_RESEARCH_WITHIN_CAPTURE_WINDOW")
        self.check_denied(r)
    def test_stale_readiness_flags_do_not_overrule_clock(self):
        s=copy.deepcopy(self.source)
        s["sourceResearchFreshAtEvaluation"]=True
        s["status"]="PUBLIC_RESEARCH_JOIN_READY"
        r=preview_public_reference(s,offer(),now_epoch=T_EXP+1)
        self.assertEqual(r["sourcePriceState"],"ARCHIVED_RESEARCH_CAPTURE_EXPIRED")
        self.check_denied(r)
    def test_wrong_publisher_expiry_or_forged_authorities_fail_closed(self):
        for name,bad in (("publisher","2026-11-10T18:58:33Z"),
                        ("sourceExpiry","2026-11-25T18:58:33Z"),
                        ("currentPricesVerified",True),
                        ("authorizesAccept",True),
                        ("rawGameToMarketIdentityAuthenticated",True),
                        ("publicCandidates",190)):
            s=copy.deepcopy(self.source);s[name]=bad
            r=preview_public_reference(s,offer(),now_epoch=T_PRE)
            self.assertEqual(r["status"],"INCONCLUSIVE",name)
            self.check_denied(r)
    def test_duplicate_or_modified_public_row_rejected(self):
        for change in ("duplicate_raw","duplicate_same_category",
                       "wrong_chroma","missing","price_string","negative",
                       "false_verified"):
            s=copy.deepcopy(self.source)
            a,b=s["rows"][0],s["rows"][1]
            if change=="duplicate_raw": b["historicalPublicRawKey"]=a["historicalPublicRawKey"]
            if change=="duplicate_same_category":
                b["page"]=a["page"];b["publicItemName"]=a["publicItemName"]
            if change=="wrong_chroma": a["page"]="chroma"
            if change=="missing": s["rows"].pop()
            if change=="price_string": a["researchSourceValue"]="650"
            if change=="negative": a["researchSourceValue"]=-1
            if change=="false_verified": a["priceForTradeVerified"]=True
            r=preview_public_reference(s,offer(),now_epoch=T_PRE)
            self.assertEqual(r["status"],"INCONCLUSIVE",change)
            self.check_denied(r)
    def test_forged_but_plausible_189_row_prices_and_demand_are_rejected(self):
        for change in ("value_plus_five","demand_plus_one","row_reorder",
                       "historical_raw_key_substitution","stable_to_volatile"):
            x=copy.deepcopy(self.source)
            row=x["rows"][0]
            if change=="value_plus_five":
                row["researchSourceValue"]+=5
            elif change=="demand_plus_one":
                row["researchDemand"]=(row["researchDemand"]+1)%12
            elif change=="row_reorder":
                x["rows"][0],x["rows"][1]=x["rows"][1],x["rows"][0]
            elif change=="historical_raw_key_substitution":
                row["historicalPublicRawKey"]="different_plausible_archive_key"
            elif change=="stable_to_volatile":
                row["researchStability"]="Changing"
            r=preview_public_reference(x,offer(),now_epoch=T_PRE)
            self.assertEqual(r["status"],"INCONCLUSIVE",change)
            self.assertEqual(r["rows"],[])
            self.check_denied(r)
    def test_missing_offer_identity_or_accept_flags_never_approved(self):
        for field,bad in (("exactPartnerClientBound",False),
                          ("stage9ObserverBound",False),
                          ("acceptedIndicatorsFalse",False),
                          ("pendingOfferMutation",True),
                          ("serverTradeRevisionProven",True),
                          ("rawItemIdConfirmed",True),
                          ("stableGuiReads",1),
                          ("localOfferEpoch",0)):
            r=preview_public_reference(self.source,offer(**{field:bad}),now_epoch=T_PRE)
            self.assertEqual(r["status"],"INCONCLUSIVE",field)
            self.check_denied(r)
    def test_missing_offer_and_stack_corruptions_fail_closed(self):
        invalid=[
          {"slot":1,"label":"Gingerscope","chroma":False,"quantity":0},
          {"slot":1,"label":"Gingerscope","chroma":False,"quantity":5},
          {"slot":1,"label":"Gingerscope","chroma":"False","quantity":1},
          {"slot":1,"label":"Gingerscope","chroma":False,"quantity":True},
          {"slot":1,"label":"Gingerscope","chroma":False,"quantity":1,"rawId":"Scythe"},
          {"slot":5,"label":"Gingerscope","chroma":False,"quantity":1},
          {"slot":1,"label":"\x00Gingerscope","chroma":False,"quantity":1},
        ]
        for slot in invalid:
            r=preview_public_reference(self.source,offer(theirs=[slot]),now_epoch=T_PRE)
            self.assertEqual(r["status"],"INCONCLUSIVE",slot)
            self.check_denied(r)
        two=[{"slot":1,"label":"Emberbow","chroma":False,"quantity":1}]*2
        r=preview_public_reference(self.source,offer(ours=two),now_epoch=T_PRE)
        self.assertEqual(r["status"],"INCONCLUSIVE")
        self.check_denied(r)
    def test_empty_side_never_emits_spread(self):
        r=preview_public_reference(self.source,offer(ours=[]),now_epoch=T_PRE)
        self.assertEqual(r["matchedCandidateSlots"],1)
        self.assertIsNone(r["illustrativeReferenceDifference"])
        self.check_denied(r)
    def test_500_seeded_name_and_variant_mutations_never_escalate_trade_authority(self):
        rnd=random.Random(101)
        for i in range(500):
            v=offer()
            n=rnd.choice(("fang","Chroma Fang","Gingerscope","gInGeRsCoPe",
                          "Ginger scope","Fang","Batwing","Nik's Scythe",
                          " Chroma Fang ","Chroma Fang\x00","Chroma Harvester"))
            v["ours"][0]["label"]=n
            v["ours"][0]["chroma"]=rnd.choice((True,False))
            if i%19==0: v["ours"][0]["quantity"]=2
            if i%27==0: v["ours"][0]["slot"]=2
            r=preview_public_reference(self.source,v,now_epoch=T_EXP+(i%2))
            self.check_denied(r)
            self.assertIsNone(r["illustrativeReferenceDifference"])
    def test_public_archive_never_authenticates_actual_inventory_or_supreme_checker_id(self):
        for when in (T_PRE,T_EXP+1):
            r=preview_public_reference(self.source,offer(),now_epoch=when)
            self.assertFalse(r["currentGameItemIdentityAuthenticated"])
            self.assertFalse(r["numericSupremeCheckerIdVerified"])
            self.assertFalse(r["authenticatedOwnedInventory"])
            self.assertFalse(r["authorizesTrade"])
            self.assertFalse(r["authorizesAccept"])
            self.assertFalse(r["mayReportProfit"])
            self.check_denied(r)

if __name__=="__main__":
    unittest.main()
