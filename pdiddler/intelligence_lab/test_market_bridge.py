"""Stage 2 contract tests: pure importer and strict scanner evidence guard."""
import copy
import json
from pathlib import Path
import unittest
from datetime import datetime, timezone, timedelta
from decimal import Decimal
from evaluator import AssessmentError
from market_bridge import load_market, load_market_file, audit_inventory, analyze_observed_pair, market_snapshot_summary

ROOT=Path(__file__).parent
NOW=datetime(2026,11,5,13,53,10,tzinfo=timezone.utc)


def fixture():
    return json.loads((ROOT/"market_excerpt_fixture.json").read_text())


def inventory():
    return json.loads((ROOT/"screenshot_inventory_provisional.json").read_text())


def scanner_from_subset(rows, *, user=123, job="job-test"):
    return {"source":"native_scanner","captured_at":"2026-11-05T13:53:00Z",
            "jobId":job,"playerUserId":user,"placeId":142823291,
            "fingerprint":f"synthetic-snapshot-{user}",
            "unmapped":0,"unpriced":0,"badQty":0,
            "items":rows}


class Stage2MarketBridge(unittest.TestCase):
    def setUp(self):
        self.market=load_market(fixture(),NOW)
        self.raw=inventory()

    def test_real_source_excerpt_loads_exact_identities(self):
        self.assertEqual(len(self.market.catalog.items),16)
        water=self.market.catalog.items["chroma:810:checker-id"]
        self.assertEqual(water.value,Decimal("2300"))
        self.assertEqual(self.market.catalog.items["chroma:1033:checker-id"].stability,"doing_well")
        self.assertEqual(self.market.catalog.items["ancient:771:checker-id"].value,Decimal("16000"))

    def test_screenshot_can_value_but_cannot_authorize_trade(self):
        a=audit_inventory(self.raw,self.market,NOW)
        self.assertFalse(a.native_authoritative)
        self.assertEqual(a.exact_id_verified,14)
        self.assertEqual(a.unresolved_units,0)
        result=market_snapshot_summary(self.market,a)
        self.assertEqual(result["known_listed_value_lower_bound"],"4548")
        self.assertIn("screenshot-cannot-prove-native-checker-ids", result["issues"])
        with self.assertRaisesRegex(AssessmentError,"trade-evidence-not-native-authoritative"):
            analyze_observed_pair(a,a,{"godly:27:checker-id":1},{"godly:481:checker-id":1},self.market,NOW)

    def test_native_exact_ids_allow_offline_evaluation(self):
        give=self.raw["items"][13]  # boneblade
        recv=self.raw["items"][4]  # iceblaster
        ours=audit_inventory(scanner_from_subset([give],user=123),self.market,NOW)
        theirs=audit_inventory(scanner_from_subset([recv],user=456),self.market,NOW)
        self.assertTrue(ours.native_authoritative)
        x=analyze_observed_pair(ours,theirs,{"godly:27:checker-id":1},{"godly:481:checker-id":1},self.market,NOW)
        self.assertEqual(x.net_listed_value,Decimal("26"))
        self.assertEqual(x.decision,"human-review-only")
        self.assertEqual(x.goal_value,Decimal("16000"))

    def test_screenshot_no_inferred_value_for_missing_item(self):
        r=copy.deepcopy(self.raw)
        r["items"].append(dict(page="legendary",id="X",checkerId="X",name="Emberknife",type="Knife",cat="Weapons",qty=1))
        a=audit_inventory(r,self.market,NOW)
        self.assertEqual(a.unresolved_units,1)
        self.assertEqual(market_snapshot_summary(self.market,a)["known_listed_value_lower_bound"],"4548")

    def test_market_dated_expiry_fails_closed(self):
        with self.assertRaisesRegex(AssessmentError,"price-snapshot-not-valid"):
            load_market(fixture(),datetime(2026,11,5,22,0,tzinfo=timezone.utc))

    def test_market_source_cannot_be_silently_renamed(self):
        row=fixture()
        row["original_commit"]="latest"
        with self.assertRaisesRegex(AssessmentError,"unexpected-source-commit"):
            load_market(row,NOW)
        row=fixture()
        row["sources"]["godly"]["sha256"]="000"
        with self.assertRaisesRegex(AssessmentError,"market-source-provenance-invalid"):
            load_market(row,NOW)

    def test_unknown_market_status_rejected(self):
        row=fixture()
        row["items"][1]["stability"]="Very Desirable"
        with self.assertRaisesRegex(AssessmentError,"unknown-market-status"):
            load_market(row,NOW)

    def test_name_id_collision_is_not_name_only_mapping(self):
        r=copy.deepcopy(self.raw)
        r["items"][0]["checkerId"]="811"  # normal Watergun ID
        a=audit_inventory(r,self.market,NOW)
        self.assertGreater(a.unresolved_units,0)
        self.assertIn("row-unknown-or-unpriced",a.issues)  # normal Watergun absent from the excerpt

    def test_market_cannot_use_duplicate_ids(self):
        row=fixture()
        row["items"].append(copy.deepcopy(row["items"][0]))
        row["profile_count"]+=1
        with self.assertRaisesRegex(AssessmentError,"duplicate-market-identity"):
            load_market(row,NOW)

    def test_duplicate_inventory_rows_blocked(self):
        r=copy.deepcopy(self.raw)
        r["items"].append(copy.deepcopy(r["items"][0]))
        with self.assertRaisesRegex(AssessmentError,"duplicate-inventory-identity"):
            audit_inventory(r,self.market,NOW)

    def test_native_bad_coverage_cannot_be_authoritative(self):
        r=scanner_from_subset([self.raw["items"][0]])
        r["unpriced"]=1
        a=audit_inventory(r,self.market,NOW)
        self.assertFalse(a.native_authoritative)
        self.assertIn("scanner-unpriced-nonzero",a.issues)

    def test_native_cross_job_block(self):
        a=audit_inventory(scanner_from_subset([self.raw["items"][13]],user=3,job="server-A"),self.market,NOW)
        b=audit_inventory(scanner_from_subset([self.raw["items"][4]],user=4,job="server-B"),self.market,NOW)
        with self.assertRaisesRegex(AssessmentError,"scanner-reads-from-different-jobs"):
            analyze_observed_pair(a,b,{"godly:27:checker-id":1},{"godly:481:checker-id":1},self.market,NOW)

    def test_stale_inventory_capture_block(self):
        r=copy.deepcopy(self.raw)
        r["captured_at"]="2026-11-05T13:50:00Z"
        with self.assertRaisesRegex(AssessmentError,"inventory-capture-stale"):
            audit_inventory(r,self.market,NOW)

    def test_native_wrong_place_block(self):
        r=scanner_from_subset([self.raw["items"][0]])
        r["placeId"]=999
        self.assertFalse(audit_inventory(r,self.market,NOW).native_authoritative)

    def test_invalid_quantity_and_type_block(self):
        r=copy.deepcopy(self.raw)
        r["items"][0]["qty"]=True
        with self.assertRaisesRegex(AssessmentError,"raw-inventory-quantity-invalid"):
            audit_inventory(r,self.market,NOW)
        r=copy.deepcopy(self.raw)
        r["items"][0]["type"]="Pet"
        a=audit_inventory(r,self.market,NOW)
        self.assertEqual(a.unresolved_units,1)

    def test_source_rows_are_not_mutated(self):
        original=copy.deepcopy(self.raw)
        audit_inventory(self.raw,self.market,NOW)
        self.assertEqual(self.raw,original)

if __name__=="__main__": unittest.main()
