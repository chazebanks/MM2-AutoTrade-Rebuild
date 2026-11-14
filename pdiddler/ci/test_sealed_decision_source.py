"""Sealed private source to research decision entry-point adversarial tests.

Synthetic positive tests explicitly patch only the immutable adapter result and
expected SHA for an artificial 189 row fixture; the original upstream 31 tests
separately prove the real byte-level SHA and pinned Stage83 source contract.
"""
import copy
import unittest
from unittest import mock

from pdiddler.ci.test_market_research_reader import data
from pdiddler.ci.test_client_inventory_shadow import _env
from pdiddler.system2 import sealed_decision_source as gate
from pdiddler.system2.trade_scenario_lab import SIMULATION_KIND


def scenario(out, inc):
    return {
        "kind":SIMULATION_KIND,
        "outgoingSlots":[{"rawGameKey":k,"quantity":q} for k,q in out],
        "incomingSlots":[{"rawGameKey":k,"quantity":q} for k,q in inc],
    }


class SealedSourceDecisionTests(unittest.TestCase):
    def setUp(self):
        self.market=data()
        self.market["captureWindowUTC"]={"exportedAt":"2026-11-14T00:28:09.127Z"}
        self._original_hash=gate.canonical_record_hash(self.market["records"])
        self.client=_env(self.market,quantities={"Celestial":2},extras={"CommonKnife":1})
        self.clock="2026-11-14T01:15:40.000Z"

    def runmode(self, mode="SCENARIO", payload=None, source=None, digest=None,
                source_bytes=b"SYNTHETIC_FIXTURE_NOT_REAL_OPERATOR_EXPORT"):
        result_payload=(payload if payload is not None else
            scenario([("Celestial",1)],[("Gingerscope",1)]))
        with (mock.patch.object(gate,"ingest",return_value=source if source is not None else self.market) as loader,
              mock.patch.object(gate,"EXPECTED_ROWS_SHA256",
                                digest if digest is not None else self._original_hash)):
            out=gate.inspect_sealed(
                export_bytes=source_bytes,
                stage83_lua_bytes=b"SYNTHETIC_FIXTURE_NOT_REAL_STAGE83",
                client_envelope=self.client,
                evaluated_at_utc=self.clock,
                mode=mode,payload=result_payload)
            if type(source_bytes) is bytes and mode in gate.MODES:
                loader.assert_called_once_with(source_bytes,
                                                b"SYNTHETIC_FIXTURE_NOT_REAL_STAGE83")
            return out

    def test_integrity_seal_189_rows_hypothetical_scenario(self):
        output=self.runmode()
        self.assertEqual(output["status"],"SEALED_SOURCE_RESEARCH_ONLY",output)
        self.assertTrue(output["sourceRowsPinnedToOriginalOperatorExport"])
        self.assertEqual(output["mappedRowsSha256"],self._original_hash)
        self.assertEqual(output["researchResult"]["status"],"OFFLINE_SCENARIO_REVIEWED")
        self.assertFalse(output["safeForUnattendedTrading"])
        self.assertFalse(output["authorizesAccept"])
        self.assertFalse(output["clientSessionAuthenticated"])

    def test_private_snapshot_bytes_are_revalidated_each_call(self):
        self.runmode()
        self.runmode()
        # runmode independently asserts adapter was called once EACH call.

    def test_independent_mapped_seal_detects_modified_unowned_target_value(self):
        poisoned=copy.deepcopy(self.market)
        for row in poisoned["records"]:
            if row["rawGameKeyCandidate"]=="Gingerscope":
                row["decimalValue"]=500000
                row["rangeLow"]=500000
                row["rangeHigh"]=500000
        r=self.runmode(source=poisoned)
        self.assertEqual(r["status"],"BLOCKED")
        self.assertEqual(r["reason"],"SEALED_189_RECORD_CONTENT_MISMATCH")
        self.assertFalse(r["authorizesTrade"])

    def test_even_small_unowned_value_change_blocks(self):
        changed=copy.deepcopy(self.market)
        for row in changed["records"]:
            if row["rawGameKeyCandidate"]=="test_key_175":
                row["demand"]=7
        r=self.runmode(source=changed)
        self.assertEqual(r["reason"],"SEALED_189_RECORD_CONTENT_MISMATCH")

    def test_source_extra_item_rejected(self):
        changed=copy.deepcopy(self.market)
        changed["records"].append(copy.deepcopy(changed["records"][0]))
        r=self.runmode(source=changed)
        self.assertEqual(r["reason"],"MAPPED_189_RECORDS_REQUIRED")

    def test_wrong_immutable_mapped_seal_is_not_allowed(self):
        r=self.runmode(digest="0"*64)
        self.assertEqual(r["reason"],"SEALED_189_RECORD_CONTENT_MISMATCH")

    def test_modified_real_source_bytes_fail_original_adapter(self):
        r=gate.inspect_sealed(export_bytes=b"tampered",stage83_lua_bytes=b"not original",
                              client_envelope=self.client,evaluated_at_utc=self.clock,
                              mode="SCENARIO",payload=scenario([("Celestial",1)],[("Gingerscope",1)]))
        self.assertEqual(r["status"],"BLOCKED")
        self.assertEqual(r["reason"],"OPERATOR_EXPORT_SHA256_MISMATCH")

    def test_client_forged_permission_not_approved(self):
        self.client["authorizesTrade"]=True
        r=self.runmode()
        self.assertEqual(r["status"],"BLOCKED")
        self.assertIn("CLIENT_INVENTORY_UNVERIFIED",r["reason"])

    def test_expired_client_fails_even_with_sealed_price(self):
        self.clock="2026-11-14T01:16:31.000Z"
        r=self.runmode()
        self.assertEqual(r["status"],"BLOCKED")
        self.assertIn("CLIENT_OBSERVATION_OUTSIDE_60S",r["reason"])

    def test_invalid_job_id_not_hidden_by_source_seal(self):
        self.client["jobId"]="wrong|job"
        r=self.runmode()
        self.assertEqual(r["status"],"BLOCKED")
        self.assertIn("CLIENT_JOB_REFERENCE_INVALID",r["reason"])

    def test_attractiveness_mode_remains_unverified_research(self):
        a=[
            scenario([("Celestial",1)],[("Gingerscope",1)]),
            scenario([("Celestial",1)],[("EmberbowChroma",1)]),
        ]
        r=self.runmode(mode="ATTRACTIVENESS",payload=a)
        self.assertEqual(r["status"],"SEALED_SOURCE_RESEARCH_ONLY",r)
        self.assertEqual(r["researchResult"]["alternativesReviewed"],2)
        self.assertFalse(r["researchResult"]["authorizesTrade"])
        self.assertFalse(r["authorizesAccept"])

    def test_growth_mode_does_not_fake_settlement(self):
        route=[
            scenario([("Celestial",1)],[("EmberbowChroma",1)]),
            scenario([("EmberbowChroma",1)],[("Gingerscope",1)]),
        ]
        r=self.runmode(mode="MULTITRADE_GROWTH",payload=route)
        self.assertEqual(r["status"],"SEALED_SOURCE_RESEARCH_ONLY",r)
        self.assertTrue(r["researchResult"]["goalTargetHypotheticallyReceived"])
        self.assertFalse(r["researchResult"]["serverCompletionProven"])

    def test_unapproved_loss_rejected_by_individual_mode(self):
        a=scenario([("Celestial",1)],[("test_key_0",1)])
        r=self.runmode(payload=a)
        self.assertEqual(r["status"],"BLOCKED",r)
        self.assertIn("NO_APPROVED_LOSS_BUDGET",r["reason"])
        self.assertFalse(r["authorizesTrade"])

    def test_unapproved_loss_in_growth_route_is_not_published_as_success(self):
        route=[
            scenario([("Celestial",1)],[("EmberbowChroma",1)]),
            scenario([("EmberbowChroma",1)],[("test_key_100",1)]),
        ]
        r=self.runmode(mode="MULTITRADE_GROWTH",payload=route)
        self.assertEqual(r["status"],"BLOCKED")
        self.assertIn("UNAPPROVED_LISTED_LOSS",r["reason"])

    def test_explicit_counterparty_inventory_sealed_mode_only(self):
        candidate_request={
            "kind":"SYNTHETIC_OFFLINE_COUNTERPARTY_ENUMERATION",
            "ownShortlist":["Celestial"],
            "counterparty":{
                "kind":"SYNTHETIC_UNVERIFIED_COUNTERPARTY",
                "items":[{"rawGameKey":"Gingerscope","quantity":1}],
                "ownershipProof":"UNKNOWN",
            },
            "maxDisplay":5,
        }
        result=self.runmode(mode="COUNTERPARTY_OPTIONS",payload=candidate_request)
        self.assertEqual(result["status"],"SEALED_SOURCE_RESEARCH_ONLY",result)
        research=result["researchResult"]
        self.assertEqual(research["status"],"OFFLINE_COUNTERPARTY_OPTIONS_ENUMERATED")
        self.assertTrue(research["previews"][0]["incomingGingerscopeHypothesis"])
        self.assertFalse(research["counterpartyOwnsAnyItemProven"])
        self.assertFalse(result["authorizesOffer"])

    def test_no_fabricated_counterparty_census_in_sealed_mode(self):
        bogus={
            "kind":"SYNTHETIC_OFFLINE_COUNTERPARTY_ENUMERATION",
            "ownShortlist":["Celestial"],
            "counterparty":{
                "kind":"SYNTHETIC_UNVERIFIED_COUNTERPARTY",
                "items":[],
                "ownershipProof":"UNKNOWN",
            },
            "maxDisplay":3,
        }
        result=self.runmode(mode="COUNTERPARTY_OPTIONS",payload=bogus)
        self.assertEqual(result["status"],"BLOCKED")
        self.assertIn("COUNTERPARTY_EXPLICIT_SHORTLIST_INVALID",result["reason"])

    def test_bad_research_mode(self):
        r=self.runmode(mode="LIVE_TRADE")
        self.assertEqual(r["status"],"BLOCKED")
        self.assertEqual(r["reason"],"UNKNOWN_RESEARCH_DECISION_MODE")

    def test_modified_source_format_blocked_before_adapter(self):
        r=gate.inspect_sealed(export_bytes="not bytes",stage83_lua_bytes=b"x",
                              client_envelope=self.client,evaluated_at_utc=self.clock,
                              mode="SCENARIO",payload={})
        self.assertEqual(r["reason"],"ORIGINAL_SOURCE_BYTES_REQUIRED")

    def test_missing_clock_fails_before_a_hypothetical_plan(self):
        self.clock=None
        r=self.runmode()
        self.assertEqual(r["status"],"BLOCKED")
        self.assertIn("INVALID_UTC",r["reason"])

    def test_fake_source_authority_flag_blocks(self):
        x=copy.deepcopy(self.market)
        x["authorizesOffer"]=True
        r=self.runmode(source=x)
        self.assertEqual(r["status"],"BLOCKED")
        self.assertIn("SOURCE_AUTHORITY_CONTRACT_VIOLATION",r["reason"])

    def test_none_records_rejected(self):
        with self.assertRaisesRegex(ValueError,"MAPPED_189_RECORDS_REQUIRED"):
            gate.canonical_record_hash(None)

    def test_boolean_qty_in_client_cannot_be_cured_by_source_hash(self):
        self.client["inventory"]["items"][0]["qty"]=True
        r=self.runmode()
        self.assertEqual(r["status"],"BLOCKED")
        self.assertIn("SCANNER_OWNED_QUANTITY_INCONSISTENT",r["reason"])


if __name__=="__main__":
    unittest.main()
