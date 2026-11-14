"""Research-only publication/census invalidation tests — not MM2 native chat/client data."""
from __future__ import annotations
import copy
import unittest
from unittest import mock

from pdiddler.ci.test_market_research_reader import data
from pdiddler.ci.test_client_inventory_shadow import _env
from pdiddler.system2 import market_inventory_revision_gate as g


def pages(publisher="2026-11-13T18:20:00.000Z",
          fetched="2026-11-14T01:15:38.000Z"):
    return {"kind": g.OBSERVATION_KIND, "pages": [
        {"url":url, "publisherUpdatedAtUTC":publisher, "fetchedAtUTC":fetched}
        for url in g.CANONICAL
    ]}


def trade(offer_revision=7, job="TEST_JOB_20261114_001",
          lease="test-lease-0001", partner=12345,
          seen="2026-11-14T01:15:35.000Z", active=True):
    return {
        "kind":g.TRADE_KIND,"jobId":job,"tradeLeaseId":lease,
        "partnerUserId":partner,"offerRevision":offer_revision,
        "offerObservedAtUTC":seen,"tradeWindowOpen":active,
    }


class MarketInventoryRevisionTests(unittest.TestCase):
    def setUp(self):
        self.mapped=data()
        self.mapped["captureWindowUTC"]={"exportedAt":"2026-11-14T00:28:09.127Z"}
        self.own=_env(self.mapped, quantities={"Celestial":2},
                      extras={"CommonKnife":1})
        self.web=pages()
        self.binding=trade()
        self.now="2026-11-14T01:15:40.000Z"
        self.digest=g.canonical_record_hash(self.mapped["records"])
        self.original=b"TEST_ONLY_NOT_THE_OPERATOR_EXPORT"
        self.registry=b"TEST_ONLY_NOT_STAGE83"

    def observe(self):
        # The full inherited adapter tests independently verify real pinned
        # original export SHA and Stage83 Git blob, with hostile mutations.
        # These cases test ONLY transition behavior with an artificial source.
        with (mock.patch.object(g, "ingest", return_value=self.mapped) as read,
              mock.patch.object(g, "EXPECTED_ROWS_SHA256", self.digest)):
            result=g.observe(
                export_bytes=self.original, stage83_lua_bytes=self.registry,
                client_envelope=self.own, trade_binding=self.binding,
                publication_pages=self.web, evaluated_at_utc=self.now,
            )
            read.assert_called_once_with(self.original,self.registry)
        return result

    def compare(self, previous):
        with (mock.patch.object(g, "ingest",return_value=self.mapped),
              mock.patch.object(g,"EXPECTED_ROWS_SHA256",self.digest)):
            return g.compare(
                previous, export_bytes=self.original,
                stage83_lua_bytes=self.registry,
                client_envelope=self.own, trade_binding=self.binding,
                publication_pages=self.web, evaluated_at_utc=self.now,
            )

    def baseline(self):
        initial=self.observe()
        self.assertEqual(initial["status"],"RESEARCH_SNAPSHOT_ONLY",initial)
        self.assertFalse(initial["authorizesOffer"])
        self.assertFalse(initial["publisherEditionAuthenticated"])
        return initial

    def advance(self):
        self.now="2026-11-14T01:15:50.000Z"
        self.web=pages(fetched="2026-11-14T01:15:48.000Z")

    def blocked(self, msg):
        result=self.observe()
        self.assertEqual(result["status"],"BLOCKED",result)
        self.assertIn(msg,result["reason"])
        self.assertFalse(result["authorizesAccept"])
        self.assertFalse(result["marketSourceUsableForLiveOffer"])

    def invalidated(self, previous, msg):
        result=self.compare(previous)
        self.assertEqual(result["status"],"INVALIDATED",result)
        self.assertFalse(result["researchDecisionReusable"])
        self.assertIn(msg,result.get("reason","")+
                      "/"+repr(result.get("invalidationReasons",[])))
        self.assertFalse(result["authorizesTrade"])

    def test_initial_four_page_publication_census_snapshot(self):
        result=self.baseline()
        stamp=result["researchStamp"]
        self.assertEqual(stamp["publisherVisibleWatermarkUTC"],
                         "2026-11-13T18:20:00.000Z")
        self.assertEqual(stamp["marketExportSha256"],g.EXPORT_SHA256)
        self.assertEqual(stamp["mappedRowsSha256"],self.digest)
        self.assertNotIn("TEST_JOB_",repr(result))
        self.assertNotIn("12345",repr(result))
        self.assertFalse(result["liveSyncAuthenticated"])

    def test_same_full_census_and_same_offer_revision_is_research_only(self):
        first=self.baseline()
        self.advance()
        refreshed=self.compare(first)
        self.assertEqual(refreshed["status"],"UNCHANGED_RESEARCH_ONLY",refreshed)
        self.assertFalse(refreshed["researchDecisionReusable"])
        self.assertTrue(refreshed["researchDecisionReusableForSyntheticReplayOnly"])
        self.assertFalse(refreshed["mayUseForLiveStrategy"])

    def test_legacy_scanner_price_change_does_not_trigger_semantic_reset(self):
        first=self.baseline()
        self.advance()
        self.own["inventory"]["items"][0]["value"]=9_999_999
        self.own["inventory"]["total"]=99_000_000
        same=self.compare(first)
        self.assertEqual(same["status"],"UNCHANGED_RESEARCH_ONLY",same)

    def test_quantity_census_change_invalidates_even_within_sixty_seconds(self):
        first=self.baseline()
        self.advance()
        self.own["capturedAt"]="2026-11-14T01:15:44.000Z"
        self.binding["offerObservedAtUTC"]="2026-11-14T01:15:47.000Z"
        self.own["inventory"]["items"][0]["qty"]=3
        self.own["inventory"]["seen"]=["Celestialx3","CommonKnifex1"]
        self.own["inventory"]["fingerprint"]="Celestialx3|CommonKnifex1"
        self.own["inventory"]["rawOwned"]=4
        self.invalidated(first,"OWN_INVENTORY_CENSUS_CHANGED")

    def test_excluded_untargeted_inventory_changes_invalidate(self):
        first=self.baseline()
        self.advance()
        self.own["capturedAt"]="2026-11-14T01:15:44.000Z"
        self.binding["offerObservedAtUTC"]="2026-11-14T01:15:47.000Z"
        self.own["inventory"]["seen"]=["Celestialx2","CommonKnifex2"]
        self.own["inventory"]["fingerprint"]="Celestialx2|CommonKnifex2"
        self.own["inventory"]["rawOwned"]=4
        self.invalidated(first,"OWN_INVENTORY_CENSUS_CHANGED")

    def test_offer_revision_change_invalidates_without_inventory_change(self):
        first=self.baseline()
        self.advance()
        self.binding["offerRevision"]=8
        self.invalidated(first,"OFFER_REVISION_CHANGED")

    def test_server_change_invalidates(self):
        first=self.baseline()
        self.advance()
        self.own["jobId"]="TEST_JOB_20261114_002"
        self.binding["jobId"]="TEST_JOB_20261114_002"
        self.invalidated(first,"SERVER_PARTNER_OR_TRADE_LEASE_CHANGED")

    def test_partner_change_invalidates(self):
        first=self.baseline()
        self.advance()
        self.binding["partnerUserId"]=67890
        self.invalidated(first,"SERVER_PARTNER_OR_TRADE_LEASE_CHANGED")

    def test_trade_lease_change_invalidates(self):
        first=self.baseline()
        self.advance()
        self.binding["tradeLeaseId"]="test-lease-0002"
        self.invalidated(first,"SERVER_PARTNER_OR_TRADE_LEASE_CHANGED")

    def test_publisher_newer_than_source_export_invalidates_and_quarantines(self):
        first=self.baseline()
        self.advance()
        self.web=pages(
            publisher="2026-11-14T00:59:00.000Z",
            fetched="2026-11-14T01:15:48.000Z")
        self.invalidated(first,"NEWER_PUBLISHER_PUBLICATION_REQUIRES_NEW_RAW_ARCHIVE")

    def test_publisher_minor_change_within_old_capture_is_also_invalidation(self):
        first=self.baseline()
        self.advance()
        self.web=pages(
            publisher="2026-11-13T18:30:00.000Z",
            fetched="2026-11-14T01:15:48.000Z")
        self.invalidated(first,"PUBLISHER_OR_MARKET_SOURCE_CHANGED")

    def test_disagreeing_canonical_pages_quarantines(self):
        first=self.baseline()
        self.advance()
        self.web["pages"][2]["publisherUpdatedAtUTC"]="2026-11-13T18:25:00.000Z"
        self.invalidated(first,"PUBLISHER_PAGE_VERSION_DISAGREEMENT")

    def test_missing_canonical_category_blocks(self):
        self.web["pages"].pop()
        self.blocked("FOUR_CANONICAL_PUBLICATION_PAGES_REQUIRED")

    def test_same_canonical_page_twice_blocks(self):
        self.web["pages"][1]["url"]=g.CANONICAL[0]
        self.blocked("PAGE_URL_DUPLICATE_OR_UNEXPECTED")

    def test_unknown_page_url_blocks(self):
        self.web["pages"][1]["url"]="https://evil.example.net/mm2/godlies"
        self.blocked("PAGE_URL_DUPLICATE_OR_UNEXPECTED")

    def test_future_publisher_time_blocked(self):
        self.web=pages(publisher="2026-11-15T12:00:00.000Z")
        self.blocked("PAGE_FETCH_FUTURE_STALE_OR_PUBLISHER_FUTURE")

    def test_future_fetch_stamp_blocked(self):
        self.web=pages(fetched="2026-11-14T01:15:41.000Z")
        self.blocked("PAGE_FETCH_FUTURE_STALE_OR_PUBLISHER_FUTURE")

    def test_old_fetch_stamp_blocks(self):
        self.web=pages(fetched="2026-11-14T01:10:00.000Z")
        self.blocked("PAGE_FETCH_FUTURE_STALE_OR_PUBLISHER_FUTURE")

    def test_excessive_four_page_fetch_skew_blocks(self):
        self.web["pages"][0]["fetchedAtUTC"]="2026-11-14T01:13:58.000Z"
        self.blocked("CANONICAL_PAGE_FETCHES_NOT_COHERENT")

    def test_authorizing_source_payload_blocks_at_shadow_gate(self):
        self.mapped["authorizesTrade"]=True
        self.blocked("PINNED_COMPLETE_189_ROWS_MISMATCH") if False else None
        # Synthetic adapter bypass is used only to test post-loader source
        # contracts; its data fields are not allowed to waive authority.
        self.blocked("SCANNER_SHADOW_INVALID:SOURCE_AUTHORITY_CONTRACT_VIOLATION")

    def test_modified_row_price_blocks_even_with_same_declared_export_sha(self):
        for row in self.mapped["records"]:
            if row["rawGameKeyCandidate"]=="Gingerscope":
                row["decimalValue"]=999999
        self.blocked("PINNED_COMPLETE_189_ROWS_MISMATCH")

    def test_deleted_row_blocks_before_inventory_gate(self):
        self.mapped["records"].pop()
        self.blocked("MAPPED_189_RECORDS_REQUIRED")

    def test_old_client_inventory_blocks_even_with_valid_market(self):
        self.own["capturedAt"]="2026-11-14T01:10:00.000Z"
        self.blocked("SCANNER_SHADOW_INVALID:CLIENT_OBSERVATION_OUTSIDE_60S")

    def test_closed_trade_does_not_create_or_refresh(self):
        first=self.baseline()
        self.advance()
        self.binding["tradeWindowOpen"]=False
        self.invalidated(first,"TRADE_WINDOW_NOT_ACTIVE")

    def test_no_source_raw_bytes_rejected_before_synthetic_adapter(self):
        self.original="string not bytes"
        self.blocked("ORIGINAL_SOURCE_BYTES_REQUIRED")

    def test_publication_has_no_demand_or_market_price_authorization(self):
        r=self.baseline()
        for k,v in g.AUTHORITY_DENIED.items():
            self.assertEqual(r[k],v)
        self.assertFalse(r["publisherArchiveVerifiedForDecision"])
        self.assertFalse(r["currentGameInventoryProven"])

    def test_prior_token_with_forged_trade_permission_is_rejected(self):
        first=self.baseline()
        first["authorizesAccept"]=True
        self.advance()
        result=self.compare(first)
        self.assertEqual(result["status"],"BLOCKED",result)
        self.assertIn("PRIOR_RESEARCH_STAMP_UNTRUSTED",result["reason"])

    def test_prior_token_unknown_fields_rejected(self):
        first=self.baseline()
        first["researchStamp"]["newAdminFlag"]="trusted"
        self.advance()
        result=self.compare(first)
        self.assertEqual(result["status"],"BLOCKED")
        self.assertIn("PRIOR_RESEARCH_STAMP_SHAPE_INVALID",result["reason"])

    def test_source_older_than_research_max_age_requires_review(self):
        self.now="2026-11-15T01:15:40.000Z"
        self.web=pages(fetched="2026-11-15T01:15:38.000Z")
        self.blocked("SOURCE_EXPORT_RESEARCH_AGE_REQUIRES_REVIEW")

    def test_offer_binding_before_client_census_blocks(self):
        self.binding["offerObservedAtUTC"]="2026-11-14T01:15:20.000Z"
        self.blocked("TRADE_BINDING_STALE_OR_BEFORE_OWN_CENSUS")

    def test_false_trade_identity_field_blocks(self):
        self.binding["partnerUserId"]=True
        self.blocked("TRADE_BINDING_ID_OR_REVISION_INVALID")

    def test_duplicate_alias_of_snapshot_fields_is_rejected(self):
        first=self.baseline()
        self.advance()
        first["status"]="RESEARCH_OWNED_IN_MM2"
        result=self.compare(first)
        self.assertEqual(result["status"],"BLOCKED")

    def test_real_bad_export_bytes_do_not_pass_original_loader(self):
        # No mock: original SHA-pinned adapter rejects mutated/raw wrong input.
        result=g.observe(
            export_bytes=b"forged",stage83_lua_bytes=b"bad-registry",
            client_envelope=self.own,trade_binding=self.binding,
            publication_pages=self.web,evaluated_at_utc=self.now,
        )
        self.assertEqual(result["status"],"BLOCKED")
        self.assertIn("OPERATOR_EXPORT_SHA256_MISMATCH",result["reason"])

    def test_identical_repeated_observation_deterministic(self):
        first=self.observe()
        second=self.observe()
        self.assertEqual(first,second)
        self.assertFalse(first["mayUseForLiveStrategy"])


if __name__ == "__main__":
    unittest.main()
