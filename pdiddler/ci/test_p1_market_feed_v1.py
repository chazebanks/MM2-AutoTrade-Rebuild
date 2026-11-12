"""Original MarketFeedV1 pure Python tests; NO HTTP, real prices or credentials."""
from __future__ import annotations

import copy
import math
import random
import unittest

from pdiddler.ci import p1_market_feed_v1 as market
from pdiddler.ci import p1_source_rights_gate as rights
from pdiddler.intelligence_lab import stage121_source_to_strategy_firewall as stage121

NOW = "2026-11-12T08:00:00Z"

def fixture(*, external=False):
    return {
        "schema": market.SCHEMA,
        "mode": "EXTERNAL_UNTRUSTED" if external else "SYNTHETIC_OFFLINE_ONLY",
        "httpStatus": 200,
        "provider": {
            "name": "TEST_PROVIDER",
            "declaredRights": "CC_BY_4_DECLARED",
            "upstreamProvenance": "INDEPENDENT_CLAIM",
            "timestampMeaning": "PUBLISHER_TIMESTAMP",
            "identityEvidence": "EXACT_GAME_RAW_KEY_CLAIM",
        },
        "snapshot": {
            "version": "TEST_REV2",
            "publishedAtUtc": "2026-11-12T02:00:00Z",
            "retrievedAtUtc": "2026-11-12T03:00:00Z",
            "expiresAtUtc": "2026-11-13T02:00:00Z",
            "units": "TEST_POINTS",
            "items": [
                {"providerKey": "TEST_P0", "gameRawKey": "TEST_RAW0",
                 "rarity": "Ancient", "variant": "Base", "year": 2023,
                 "value": 125, "publishedAtUtc": "2026-11-12T02:00:00Z"},
                {"providerKey": "TEST_P1", "gameRawKey": "TEST_RAW1",
                 "rarity": "Godly", "variant": "Chroma", "year": 2024,
                 "value": 250.0, "publishedAtUtc": "2026-11-12T02:00:00Z"},
            ],
        },
        "coverage": {"expectedGameRawKeys": ["TEST_RAW0", "TEST_RAW1"]},
        "previous": None,
    }

def judge(envelope, now=NOW):
    return market.validate_feed(envelope, observed_utc=now)

class MarketFeedV1Tests(unittest.TestCase):
    def safe(self, result):
        for k in rights.DENIED:
            self.assertIs(result[k], False, k)
        for k, value in stage121.FALSE.items():
            self.assertEqual(result[k], value, k)
        self.assertFalse(result["sourceRightsAuthenticated"])
        self.assertFalse(result["gameRawItemIdentityAuthenticated"])
        self.assertFalse(result["confirmedMarketQuote"])
        self.assertFalse(result["readyForLivePlanner"])
        self.assertFalse(result["mayAdvanceP2"])
        self.assertEqual(result["tradeOutcome"], "UNKNOWN")
        self.assertNotIn("items", result)
        self.assertNotIn("values", result)
        return result

    def test_synthetic_candidate_shadow_only(self):
        p = judge(fixture())
        self.assertEqual(p["status"], "SYNTHETIC_READY_FOR_SHADOW")
        self.assertEqual(p["observedItemCount"], 2)
        self.assertEqual(p["mode"], "SYNTHETIC_OFFLINE_ONLY")
        self.assertEqual(len(p["computedPayloadSha256NotAuthentication"]), 64)
        self.safe(p)

    def test_same_synthetic_snapshot_same_digest(self):
        first = judge(fixture())
        second = judge(copy.deepcopy(fixture()))
        self.assertEqual(first["computedPayloadSha256NotAuthentication"],
                         second["computedPayloadSha256NotAuthentication"])
        self.safe(first)

    def test_hypothetically_valid_external_never_authenticates_itself(self):
        p = judge(fixture(external=True))
        self.assertEqual(p["status"], "LIVE_CANDIDATE_UNVERIFIED")
        self.assertEqual(p["reason"],
                         "EXTERNAL_SOURCE_NOT_AUTHENTICATED_BY_CALLER_METADATA")
        self.safe(p)

    def test_401_no_fallback_to_valid_cached_snapshot(self):
        x = fixture()
        x["httpStatus"] = 401
        p = judge(x)
        self.assertEqual(p["status"], "KEY_REQUIRED")
        self.assertEqual(p["reason"], "HTTP_401_API_KEY_REQUIRED")
        self.assertEqual(p["observedItemCount"], 0)
        self.safe(p)

    def test_403_denies_access(self):
        x = fixture()
        x["httpStatus"] = 403
        self.assertEqual(self.safe(judge(x))["reason"], "HTTP_403_ACCESS_RESTRICTED")

    def test_429_never_falls_back_to_old_cache(self):
        x = fixture()
        x["httpStatus"] = 429
        self.assertEqual(self.safe(judge(x))["status"], "RATE_LIMITED")

    def test_500_never_falls_back(self):
        x = fixture()
        x["httpStatus"] = 500
        self.assertEqual(self.safe(judge(x))["status"], "SOURCE_UNAVAILABLE")

    def test_none_bool_or_string_http_code_denied(self):
        for status in (True, False, None, "200", 200.0, 99, 600):
            x = fixture()
            x["httpStatus"] = status
            with self.subTest(status=status):
                self.assertEqual(self.safe(judge(x))["reason"], "INVALID_HTTP_STATUS")

    def test_upstream_supreme_and_mixed_derived_cannot_launder_rights(self):
        for origin in ("SUPREME_DERIVED", "MIXED_DERIVED", "UNKNOWN"):
            x = fixture(external=True)
            x["provider"]["upstreamProvenance"] = origin
            with self.subTest(origin=origin):
                self.assertEqual(self.safe(judge(x))["status"], "LICENSE_BLOCKED")

    def test_api_access_is_not_licensed_data(self):
        x = fixture(external=True)
        x["provider"]["declaredRights"] = "API_ACCESS_ONLY"
        self.assertEqual(self.safe(judge(x))["status"], "LICENSE_BLOCKED")

    def test_restricted_unknown_rights_block(self):
        for permission in ("UNKNOWN", "RESTRICTED"):
            x = fixture()
            x["provider"]["declaredRights"] = permission
            with self.subTest(permission=permission):
                self.assertEqual(self.safe(judge(x))["status"], "LICENSE_BLOCKED")

    def test_oct12_publisher_with_fresh_retrieval_still_stale(self):
        x = fixture()
        x["snapshot"]["publishedAtUtc"] = "2026-10-12T00:42:14Z"
        for item in x["snapshot"]["items"]:
            item["publishedAtUtc"] = "2026-10-12T00:42:14Z"
        x["snapshot"]["retrievedAtUtc"] = "2026-11-12T07:50:00Z"
        self.assertEqual(self.safe(judge(x))["status"], "STALE")

    def test_aggregator_clock_is_not_publisher_clock(self):
        x = fixture(external=True)
        x["provider"]["timestampMeaning"] = "AGGREGATOR_REFRESH"
        self.assertEqual(self.safe(judge(x))["status"], "STALE")

    def test_display_date_is_not_publisher_timestamp(self):
        x = fixture()
        x["provider"]["timestampMeaning"] = "DISPLAY_DATE_ONLY"
        self.assertEqual(self.safe(judge(x))["status"], "STALE")

    def test_expired_payload_is_stale_even_when_published_recently(self):
        x = fixture()
        x["snapshot"]["expiresAtUtc"] = "2026-11-12T07:59:59Z"
        self.assertEqual(self.safe(judge(x))["status"], "STALE")

    def test_future_or_out_of_order_retrieval_denied(self):
        for field, value in (
            ("retrievedAtUtc", "2026-11-13T00:00:00Z"),
            ("publishedAtUtc", "2026-11-12T05:00:00Z"),
            ("expiresAtUtc", "2026-11-12T00:00:00Z"),
        ):
            x = fixture()
            x["snapshot"][field] = value
            self.assertEqual(self.safe(judge(x))["status"], "BLOCKED")

    def test_missing_timezone_or_fake_date_denied(self):
        for stamp in ("2026-11-12", "2026-11-12T08:00:00",
                      "2026-11-12T08:00:00+00:00", "2099-17-50T08:00:00Z"):
            self.assertEqual(self.safe(judge(fixture(), stamp))["status"], "BLOCKED")

    def test_unverified_game_mapping_cannot_reach_shadow_qualified(self):
        x = fixture(external=True)
        x["provider"]["identityEvidence"] = "UNKNOWN"
        self.assertEqual(self.safe(judge(x))["status"], "MAPPING_UNVERIFIED")

    def test_chroma_collision_with_reused_raw_key(self):
        x = fixture()
        x["snapshot"]["items"][1]["gameRawKey"] = "TEST_RAW0"
        self.assertEqual(self.safe(judge(x))["reason"],
                         "DUPLICATE_OR_VARIANT_MAPPING_COLLISION")

    def test_provider_id_collision(self):
        x = fixture()
        x["snapshot"]["items"][1]["providerKey"] = "TEST_P0"
        self.assertEqual(self.safe(judge(x))["reason"],
                         "DUPLICATE_OR_VARIANT_MAPPING_COLLISION")

    def test_wrong_chroma_variant_and_categories_denied(self):
        for field, value in (("variant", "CHROMA??"), ("rarity", "Unique"),
                             ("year", True), ("year", 1999)):
            x = fixture()
            x["snapshot"]["items"][1][field] = value
            with self.subTest(field=field,value=value):
                self.assertEqual(self.safe(judge(x))["status"], "BLOCKED")

    def test_invalid_values_and_nonfinite_all_denied(self):
        for value in (-3, 0, float("nan"), float("inf"), float("-inf"),
                      "100", True, None):
            x = fixture()
            x["snapshot"]["items"][0]["value"] = value
            with self.subTest(value=str(value)):
                self.assertEqual(self.safe(judge(x))["reason"], "ITEM_VALUE_INVALID")

    def test_stale_individual_row_denied_even_new_snapshot(self):
        x = fixture()
        x["snapshot"]["items"][0]["publishedAtUtc"] = "2026-10-01T00:00:00Z"
        self.assertEqual(self.safe(judge(x))["reason"],
                         "ITEM_INDEPENDENT_UPDATE_STALE")

    def test_future_item_time_denied(self):
        x = fixture()
        x["snapshot"]["items"][0]["publishedAtUtc"] = "2026-11-12T04:00:00Z"
        self.assertEqual(self.safe(judge(x))["reason"],
                         "ITEM_NEWER_THAN_PUBLISHER_SNAPSHOT")

    def test_partial_coverage_denied(self):
        x = fixture()
        x["coverage"]["expectedGameRawKeys"].append("TEST_RAW_MISSING")
        self.assertEqual(self.safe(judge(x))["status"], "INCOMPLETE")

    def test_duplicate_expected_key_denied(self):
        x = fixture()
        x["coverage"]["expectedGameRawKeys"].append("TEST_RAW0")
        self.assertEqual(self.safe(judge(x))["reason"], "DUPLICATE_EXPECTED_RAW_KEY")

    def test_empty_and_unbounded_item_lists_denied(self):
        x = fixture()
        x["snapshot"]["items"] = []
        self.assertEqual(self.safe(judge(x))["reason"], "ITEM_COUNT_INVALID")
        x = fixture()
        x["snapshot"]["items"] = [x["snapshot"]["items"][0]] * (market.MAX_ITEMS + 1)
        self.assertEqual(self.safe(judge(x))["reason"], "ITEM_COUNT_INVALID")

    def test_previous_snapshot_unchanged_small_change_allowed_in_research(self):
        x = fixture()
        x["previous"] = {
            "provider": "TEST_PROVIDER", "units": "TEST_POINTS",
            "version": "TEST_REV1",
            "publishedAtUtc": "2026-11-11T00:00:00Z",
            "items": [{"gameRawKey": "TEST_RAW0", "value": 110}],
        }
        self.assertEqual(self.safe(judge(x))["status"], "SYNTHETIC_READY_FOR_SHADOW")

    def test_large_value_shift_requires_review(self):
        x = fixture()
        x["previous"] = {
            "provider": "TEST_PROVIDER", "units": "TEST_POINTS",
            "version": "TEST_REV1",
            "publishedAtUtc": "2026-11-11T00:00:00Z",
            "items": [{"gameRawKey": "TEST_RAW0", "value": 70}],
        }
        self.assertEqual(self.safe(judge(x))["status"], "REVIEW_REQUIRED")

    def test_rollback_and_duplicate_previous_keys_rejected(self):
        x = fixture()
        x["previous"] = {
            "provider": "TEST_PROVIDER", "units": "TEST_POINTS",
            "version": "TEST_REV2", "publishedAtUtc": "2026-11-12T02:00:00Z",
            "items": [],
        }
        self.assertEqual(self.safe(judge(x))["reason"], "PUBLISHER_ROLLBACK_OR_REPLAY")
        x["previous"]["publishedAtUtc"] = "2026-11-11T00:00:00Z"
        x["previous"]["version"] = "TEST_REV1"
        x["previous"]["items"] = [{"gameRawKey": "TEST_RAW0", "value": 110}] * 2
        self.assertEqual(self.safe(judge(x))["reason"], "PREVIOUS_DUPLICATE_RAW_KEY")

    def test_previous_provider_and_currency_are_exactly_bound(self):
        x = fixture()
        x["previous"] = {
            "provider": "TEST_PROVIDER", "units": "TEST_POINTS",
            "version": "TEST_REV1",
            "publishedAtUtc": "2026-11-11T00:00:00Z",
            "items": [{"gameRawKey": "TEST_RAW0", "value": 110}],
        }
        self.assertEqual(self.safe(judge(x))["status"], "SYNTHETIC_READY_FOR_SHADOW")
        x["previous"]["provider"] = "TEST_OTHER_PROVIDER"
        self.assertEqual(self.safe(judge(x))["reason"], "CROSS_PROVIDER_PRICE_COMPARISON")
        x["previous"]["provider"] = "TEST_PROVIDER"
        x["previous"]["units"] = "TEST_DIFFERENT_POINTS"
        self.assertEqual(self.safe(judge(x))["reason"], "CROSS_UNIT_PRICE_COMPARISON")

    def test_synthetic_mode_never_accepts_real_weapon_labels(self):
        x = fixture()
        x["snapshot"]["items"][0]["gameRawKey"] = "Gingerscope"
        self.assertEqual(self.safe(judge(x))["reason"],
                         "SYNTHETIC_IDENTITIES_MUST_BE_TEST_ONLY")

    def test_strict_schema_rejects_injected_authority_and_secrets(self):
        for injection in (
            {"apiKey": "DO_NOT_SEND"},
            {"maySendDiscordWebhook": True},
            {"authorizesTrade": True},
        ):
            x = fixture(external=True)
            x.update(injection)
            p = self.safe(judge(x))
            self.assertEqual(p["reason"], "INVALID_ENVELOPE_FIELDS")
            self.assertNotIn("DO_NOT_SEND", str(p))

    def test_provider_metadata_self_asserted_permission_not_allowed(self):
        x = fixture(external=True)
        x["provider"]["permissionEvidenceVerified"] = True
        self.assertEqual(self.safe(judge(x))["reason"], "INVALID_PROVIDER_FIELDS")

    def test_item_metadata_self_asserted_raw_key_authority_not_allowed(self):
        x = fixture(external=True)
        x["snapshot"]["items"][0]["verified"] = True
        self.assertEqual(self.safe(judge(x))["reason"], "INVALID_ITEM_FIELDS")

    def test_non_object_or_pathological_input_never_throws(self):
        for x in (None, "", [], {"mode": "EXTERNAL_UNTRUSTED"},
                  {"schema": market.SCHEMA}):
            with self.subTest(x=str(x)):
                self.assertEqual(self.safe(judge(x))["status"], "BLOCKED")

    def test_property_mutation_500_corrupt_samples_no_false_live_authority(self):
        randomizer = random.Random(40112)
        for i in range(500):
            x = fixture(external=i % 2 == 0)
            mod = randomizer.randrange(13)
            if mod == 0:
                x["httpStatus"] = randomizer.choice([401, 403, 429, 502])
            elif mod == 1:
                x["provider"]["declaredRights"] = "API_ACCESS_ONLY"
            elif mod == 2:
                x["provider"]["upstreamProvenance"] = "MIXED_DERIVED"
            elif mod == 3:
                x["provider"]["identityEvidence"] = "UNKNOWN"
            elif mod == 4:
                x["provider"]["timestampMeaning"] = "AGGREGATOR_REFRESH"
            elif mod == 5:
                x["snapshot"]["items"][0]["value"] = randomizer.choice(
                    [None, -1, 0, math.inf, math.nan])
            elif mod == 6:
                x["snapshot"]["items"][0]["gameRawKey"] = "INJECTED"
            elif mod == 7:
                x["snapshot"]["items"][1]["providerKey"] = "TEST_P0"
            elif mod == 8:
                x["snapshot"]["publishedAtUtc"] = "2026-10-12T00:42:14Z"
            elif mod == 9:
                x["snapshot"]["retrievedAtUtc"] = "2026-11-13T00:00:00Z"
            elif mod == 10:
                x["snapshot"]["items"][0]["publishedAtUtc"] = "2026-10-01T00:00:00Z"
            elif mod == 11:
                x["coverage"]["expectedGameRawKeys"].append("TEST_MISSING")
            else:
                x["provider"]["name"] = "TEST_INVALID SLASH/KEY"
            result = self.safe(judge(x))
            self.assertNotEqual(result["status"], "READY_TO_TRADE")
            self.assertFalse(result["currentTradeValueAuthorized"])

if __name__ == "__main__":
    unittest.main()
