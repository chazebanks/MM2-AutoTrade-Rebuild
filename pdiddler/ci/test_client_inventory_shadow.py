"""Hostile offline tests: original scanner getOwnInventory -> System2 pricing shadow.

Never touches player inventory, Roblox remotes, offers, Accept or webhooks.
"""
import copy
from datetime import datetime, timedelta, timezone
import unittest

from pdiddler.system2 import client_inventory_shadow as b
from pdiddler.ci.test_market_research_reader import data


def _row(key, qty, mapped):
    ref=next(x for x in mapped["records"] if x["rawGameKeyCandidate"]==key)
    page={"ancients":"ancient","godlies":"godly","chromas":"chroma"}[ref["category"]]
    kind=ref["gameItemTypeCandidate"]
    return {
        "id":key,"cat":"Weapons","name":ref["name"],
        "qty":qty,"type":kind,"page":page,
        "value":7_777_777,  # stale embedded October 31 checker MUST be ignored
        "checkerId":"UNPRICED","valueSource":"OLD_2026_10_31",
        "year":"","event":"",
        "identity":"|".join([key,page,kind.lower(),
                             "chroma" if page=="chroma" else "normal",
                             "","","",""]),
    }


def _env(mapped, quantities=None, extras=None):
    quantities=quantities or {"Celestial":2,"EmberbowChroma":6,"Gingerscope":1}
    extras=extras or {"CommonKnife":1}
    rows=[_row(key,qty,mapped) for key,qty in quantities.items()]
    seen=[f"{key}x{qty}" for key,qty in {**quantities,**extras}.items()]
    seen.sort()
    return {
        "schema":b.INPUT_SCHEMA,
        "source":b.SOURCE,
        "capturedAt":"2026-11-14T01:15:30.000Z",
        "jobId":"TEST_JOB_20261114_001",
        "readOnly":True,
        "inventory":{
            "items":rows,"rawOwned":sum(quantities.values())+sum(extras.values()),
            "unmapped":0,"badQty":0,"unpriced":5,
            "total":123456789,"seen":seen,"fingerprint":"|".join(seen),
        }
    }


class ShadowTests(unittest.TestCase):
    def setUp(self):
        self.mapped=data()
        self.envelope=_env(self.mapped)
        self.now="2026-11-14T01:15:40.000Z"

    def run_bridge(self):
        return b.evaluate(self.mapped,self.envelope,evaluated_at_utc=self.now)

    def blocked(self,why):
        r=self.run_bridge()
        self.assertEqual(r["status"],"BLOCKED",r)
        self.assertIn(why,r["reason"],r)
        self.assertFalse(r["authorizesTrade"])
        self.assertFalse(r["authorizesAccept"])
        self.assertTrue(r["targetOutgoingProtected"])

    def test_valid_stacked_full_shadow(self):
        r=self.run_bridge()
        self.assertEqual(r["status"],"RESEARCH_CLIENT_INVENTORY_SHADOW_READY")
        self.assertEqual(r["eligibleDistinctKeys"],3)
        self.assertEqual(r["eligibleCopies"],9)
        self.assertEqual(r["scannerRawOwnedCopies"],10)
        self.assertEqual(r["excludedOrUnclassifiedCopies"],1)
        self.assertEqual(r["listedEligibleTotal"],55900)
        self.assertEqual(r["listedEligibleRangeLow"],54400)
        self.assertEqual(r["listedEligibleRangeHigh"],57400)
        self.assertEqual(r["listedGapToGingerscope"],0)
        self.assertFalse(r["legacyScannerPricingUsed"])
        self.assertTrue(r["listedSumDoesNotProveFourSlotOffer"])
        self.assertFalse(r["portfolioCompletenessProven"])
        self.assertFalse(r["currentGameItemInstanceProven"])
        self.assertFalse(r["actualTradeSessionProven"])
        self.assertNotIn("TEST_JOB_20261114_001",repr(r))
        for k,v in b.AUTHORITY_DENIED.items():self.assertEqual(r[k],v,k)
        target=[x for x in r["records"] if x["rawGameKeyCandidate"]=="Gingerscope"][0]
        self.assertTrue(target["outgoingProtected"])
        self.assertEqual(target["listedSubtotal"],16000)

    def test_ancient_name_collision_is_blocked(self):
        self.envelope["inventory"]["items"][0]["name"]="Chroma Celestial"
        self.blocked("CURRENT_GAME_LABEL_NOT_HISTORICAL_CANDIDATE")

    def test_unknown_item(self):
        self.envelope["inventory"]["items"][0]["id"]="UnknownGodly"
        self.blocked("UNKNOWN_OR_DUPLICATE_RAW_GAME_KEY")

    def test_chroma_swapped_page(self):
        self.envelope["inventory"]["items"][1]["page"]="godly"
        self.blocked("CATEGORY_OR_CHROMA_MISMATCH")

    def test_chroma_identity_flag(self):
        rec=self.envelope["inventory"]["items"][1]
        rec["identity"]=rec["identity"].replace("|chroma|","|normal|")
        self.blocked("SCANNER_META_IDENTITY_CONFLICT")

    def test_wrong_game_type(self):
        self.envelope["inventory"]["items"][0]["type"]="Knife"
        self.blocked("GAME_WEAPON_TYPE_MISMATCH")

    def test_raw_in_meta_differs(self):
        self.envelope["inventory"]["items"][0]["identity"] = \
            self.envelope["inventory"]["items"][0]["identity"].replace("Celestial|","Emberbow|")
        self.blocked("SCANNER_META_IDENTITY_CONFLICT")

    def test_bad_qty_zero(self):
        self.envelope["inventory"]["items"][0]["qty"]=0
        self.blocked("SCANNER_OWNED_QUANTITY_INCONSISTENT")

    def test_bad_qty_string(self):
        self.envelope["inventory"]["items"][0]["qty"]="2"
        self.blocked("SCANNER_OWNED_QUANTITY_INCONSISTENT")

    def test_bad_qty_boolean(self):
        self.envelope["inventory"]["items"][0]["qty"]=True
        self.blocked("SCANNER_OWNED_QUANTITY_INCONSISTENT")

    def test_eligible_count_differs_from_census(self):
        self.envelope["inventory"]["items"][0]["qty"]=3
        self.blocked("SCANNER_OWNED_QUANTITY_INCONSISTENT")

    def test_raw_owned_count_conflict(self):
        self.envelope["inventory"]["rawOwned"]+=1
        self.blocked("SCANNER_CENSUS_TOTAL_CONFLICT")

    def test_fingerprint_conflict(self):
        self.envelope["inventory"]["fingerprint"]="bad"
        self.blocked("OWNED_FINGERPRINT_CONFLICT")

    def test_census_duplicated(self):
        s=self.envelope["inventory"]["seen"]
        s.append(s[0]);s.sort()
        self.envelope["inventory"]["fingerprint"]="|".join(s)
        self.blocked("OWNED_CENSUS_ENTRY_INVALID")

    def test_census_invalid_negative(self):
        self.envelope["inventory"]["seen"][0]="Celestialx-2"
        self.envelope["inventory"]["fingerprint"]="|".join(sorted(self.envelope["inventory"]["seen"]))
        self.blocked("OWNED_CENSUS_ENTRY_INVALID")

    def test_scanner_unmapped(self):
        self.envelope["inventory"]["unmapped"]=1
        self.blocked("SCANNER_CENSUS_INCOMPLETE")

    def test_scanner_invalid_qty(self):
        self.envelope["inventory"]["badQty"]=1
        self.blocked("SCANNER_CENSUS_INCOMPLETE")

    def test_legacy_unpriced_is_ignored(self):
        self.envelope["inventory"]["unpriced"]=999
        self.assertEqual(self.run_bridge()["status"],"RESEARCH_CLIENT_INVENTORY_SHADOW_READY")

    def test_legacy_price_mutation_has_no_effect(self):
        rec=self.envelope["inventory"]["items"][0]
        rec["value"]=None
        actual=self.run_bridge()
        self.assertEqual(actual["listedEligibleTotal"],55900)
        self.assertFalse(actual["legacyScannerPricingUsed"])

    def test_empty_eligible_inventory_is_zero_value_only(self):
        self.envelope=_env(self.mapped,quantities={"Celestial":1})
        self.envelope["inventory"]["items"]=[]
        out=self.run_bridge()
        self.assertEqual(out["status"],"RESEARCH_CLIENT_INVENTORY_SHADOW_READY")
        self.assertEqual(out["listedEligibleTotal"],0)
        self.assertEqual(out["excludedOrUnclassifiedCopies"],2)
        self.assertFalse(out["portfolioCompletenessProven"])

    def test_duplicate_raw_items(self):
        self.envelope["inventory"]["items"].append(
            copy.deepcopy(self.envelope["inventory"]["items"][0]))
        self.blocked("UNKNOWN_OR_DUPLICATE_RAW_GAME_KEY")

    def test_timestamp_older_than_60s(self):
        self.now="2026-11-14T01:16:31.000Z"
        self.blocked("CLIENT_OBSERVATION_OUTSIDE_60S_RESEARCH_WINDOW")

    def test_snapshot_from_future(self):
        self.now="2026-11-14T01:15:29.000Z"
        self.blocked("CLIENT_OBSERVATION_OUTSIDE_60S_RESEARCH_WINDOW")

    def test_snapshot_pre_market_export(self):
        self.envelope["capturedAt"]="2026-11-13T23:54:00.000Z"
        self.now="2026-11-13T23:54:10.000Z"
        self.blocked("CLIENT_OBSERVATION_PRECEDES_MARKET_EXPORT")

    def test_invalid_job(self):
        self.envelope["jobId"]="bad|job"
        self.blocked("CLIENT_JOB_REFERENCE_INVALID")

    def test_forged_authorize_field(self):
        self.envelope["authorizesAccept"]=True
        self.blocked("INVALID_UNTRUSTED_ENVELOPE")

    def test_readonly_not_true(self):
        self.envelope["readOnly"]=False
        self.blocked("INVALID_UNTRUSTED_ENVELOPE")

    def test_changed_source_label(self):
        self.envelope["source"]="CURRENT_GAME_PROVEN"
        self.blocked("INVALID_UNTRUSTED_ENVELOPE")

    def test_wrong_source_sha(self):
        self.mapped["sourceExportSha256"]="0"*64
        self.blocked("UNEXPECTED_MAPPED_SOURCE_VERSION")

    def test_forged_market_authority(self):
        self.mapped["verifiedMarketQuote"]=True
        self.blocked("SOURCE_AUTHORITY_CONTRACT_VIOLATION")

    def test_bad_slot_does_not_misstate_partner_interest(self):
        self.assertFalse(self.run_bridge()["sellerAppealVerified"])
        self.assertFalse(self.run_bridge()["fourPhysicalSlotTradeFeasible"])

    def test_scanner_old_invalid_price(self):
        self.envelope["inventory"]["items"][0]["value"]=float("nan")
        self.blocked("LEGACY_VALUE_SHAPE_INVALID")

    def test_missing_item_field(self):
        del self.envelope["inventory"]["items"][0]["checkerId"]
        self.blocked("SCANNER_ITEM_FIELDS_INVALID")

    def test_special_batwing_raw_scythe(self):
        # Historical raw key Scythe belongs to published Batwing; never use
        # the label as raw ID. This synthetic mapped key is deliberate.
        test=self.mapped["records"][-1]
        test.update({"rawGameKeyCandidate":"Scythe","image":"mm2ancients/Batwing",
                     "name":"Batwing","category":"ancients",
                     "gameItemTypeCandidate":"Knife","gameRarityCandidate":"Ancient",
                     "chromaCandidate":False,"decimalValue":40,"rangeLow":40,"rangeHigh":40})
        self.envelope=_env(self.mapped,quantities={"Scythe":2},extras={})
        self.assertEqual(self.run_bridge()["listedEligibleTotal"],80)

if __name__ == "__main__":
    unittest.main()
