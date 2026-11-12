"""Strict offline tests for provider API v2 read-only connector (no network)."""
from __future__ import annotations

import copy
import json
import os
from contextlib import redirect_stdout
from io import StringIO
import unittest
from unittest import mock

from pdiddler.ci import p1_rblxvalue_v2_private_adapter as api
from pdiddler.ci.p1_source_rights_gate import DENIED
from pdiddler.intelligence_lab.stage121_source_to_strategy_firewall import FALSE

FAKE_SECRET = "TEST_PRIVATE_KEY_NEVER_LEAK_THIS_EXAMPLE"

def encode(data):
    return json.dumps(data).encode("utf-8")

def meta():
    return {
        "last_updated": "2026-11-12 12:33:44",
        "update_interval_hours": 12,
        "totals": {"items": 1200, "sets": 100},
        "sources": ["mm2values", "supremevalues"],
        "last_run": {"run_time": "2026-11-12 12:35:00",
                     "items_updated": 630, "items_skipped": 300},
        "credit": "Data from rblxvalue.com",
    }

def page():
    return {
        "total": 2, "limit": 100, "offset": 0, "count": 2,
        "items": [
            {"id": 151, "slug": "test-ancient-1", "name": "TEST_ANCIENT",
             "category": "ancient", "value": 500, "value_source_a": 490,
             "value_source_b": 510, "demand": 5, "stability": "Stable",
             "type": "Gun", "last_updated": "2026-11-12 12:33:44"},
            {"id": 152, "slug": "test-chroma-2", "name": "TEST_CHROMA",
             "category": "chroma", "value": 40, "value_source_a": 42,
             "value_source_b": 38, "demand": 4, "stability": "Stable",
             "type": "Knife", "last_updated": "2026-11-12 12:33:44"},
        ],
        "credit": "Data from rblxvalue.com",
    }

class RblxV2PrivateAdapterTests(unittest.TestCase):
    def safe(self, result):
        self.assertNotIn(FAKE_SECRET, str(result))
        self.assertNotIn("TEST_ANCIENT", str(result))
        self.assertNotIn("test-ancient-1", str(result))
        self.assertNotIn("value", result)
        self.assertEqual(result["tradeOutcome"], "UNKNOWN")
        self.assertFalse(result["marketFeedReadyForProduction"])
        self.assertFalse(result["sourcePublishTimeAuthenticated"])
        self.assertFalse(result["upstreamRightsApproved"])
        self.assertFalse(result["gameRawKeyMappingProven"])
        for key, value in FALSE.items():
            self.assertEqual(result[key], value, key)
        for key, value in DENIED.items():
            self.assertEqual(result[key], value, key)
        return result

    def test_without_arm_transport_never_invoked(self):
        f = mock.Mock(side_effect=AssertionError("NETWORK MUST NOT RUN"))
        r = api.probe_private_meta(enabled=False, secret=FAKE_SECRET, transport=f)
        self.assertEqual(self.safe(r)["status"], "DISABLED")
        f.assert_not_called()

    def test_without_key_transport_never_invoked(self):
        f = mock.Mock(side_effect=AssertionError("NETWORK MUST NOT RUN"))
        for secret in (None, "short", "", 123):
            r = api.probe_private_meta(enabled=True, secret=secret, transport=f)
            self.assertEqual(self.safe(r)["status"], "KEY_REQUIRED")
        f.assert_not_called()

    def test_explicit_private_one_shot_meta_success_is_still_not_authority(self):
        calls = []
        def transport(path, key):
            calls.append((path, key))
            return 200, encode(meta())
        r = self.safe(api.probe_private_meta(enabled=True, secret=FAKE_SECRET,
                                              transport=transport))
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0], ("/meta", FAKE_SECRET))
        self.assertTrue(r["providerApiContacted"])
        self.assertEqual(r["status"], "RESEARCH_META_ONLY")
        self.assertEqual(r["datasetItemsReported"], 1200)
        self.assertEqual(r["aggregatorClockTimeZone"], "UNSPECIFIED")
        self.assertEqual(r["aggregatorLastUpdatedUnzoned"], "2026-11-12 12:33:44")
        self.assertEqual(r["aggregatorLastRunUnzoned"], "2026-11-12 12:35:00")
        self.assertTrue(r["knownSupremeDerivedData"])
        self.assertTrue(r["creditRequired"])

    def test_no_key_probe_returns_sanitized_statuses(self):
        for status, expected in (
            (401, "KEY_REQUIRED"), (403, "ACCESS_RESTRICTED"),
            (429, "RATE_LIMITED"), (500, "SOURCE_UNAVAILABLE"),
            (301, "SOURCE_UNAVAILABLE"), (413, "SOURCE_UNAVAILABLE"),
            (599, "SOURCE_UNAVAILABLE")):
            with self.subTest(status=status):
                r = self.safe(api.probe_private_meta(
                    enabled=True, secret=FAKE_SECRET,
                    transport=lambda _p, _k: (status, b"SECRET_NEVER_ECHO")))
                self.assertEqual(r["status"], expected)

    def test_meta_parser_source_and_timestamp_are_not_claimed_primary(self):
        r = self.safe(api.classify_meta(200, encode(meta())))
        self.assertEqual(r["reason"], "AGGREGATOR_CLOCK_WITHOUT_TZ_OR_UPSTREAM_PROOF")
        self.assertFalse(r["sourcePublishTimeAuthenticated"])

    def test_meta_timezone_ambiguity_blocks_false_clock_proof(self):
        for value in ("2026-11-12T12:33:44Z", "2026-11-12 12:33:44+02:00",
                      "2026-99-99 12:33:44", None, 123):
            x = meta()
            x["last_updated"] = value
            with self.subTest(value=value):
                r = self.safe(api.classify_meta(200, encode(x)))
                self.assertEqual(r["reason"], "META_CLOCK_NOT_VERIFIABLE")

    def test_meta_unexpected_upstream_set_denied(self):
        for sources in (["supremevalues"], ["mm2values", "private-original"],
                        [], ["mm2values", "supremevalues", "unknown-provider"]):
            x = meta()
            x["sources"] = sources
            with self.subTest(sources=sources):
                self.assertEqual(self.safe(api.classify_meta(200, encode(x)))["reason"],
                                 "UNEXPECTED_UPSTREAM_SOURCE_SET")

    def test_meta_malformed_count_interval_or_credit_denied(self):
        changes = [
            ("totals", {"items": -1}),
            ("update_interval_hours", "12"),
            ("update_interval_hours", 0),
            ("update_interval_hours", True),
            ("last_run", {}),
            ("credit", ["malicious"]),
        ]
        for field, value in changes:
            x = meta()
            x[field] = value
            with self.subTest(field=field, value=value):
                self.assertIn(self.safe(api.classify_meta(200, encode(x)))["status"],
                              ("BLOCKED",))

    def test_meta_non_json_or_empty_and_invalid_error_blocked(self):
        for body in (b"", b"{", b"[]", b"null", b"\xff",
                     encode({"error": True, "message": FAKE_SECRET})):
            self.assertEqual(self.safe(api.classify_meta(200, body))["status"],
                             "BLOCKED")

    def test_meta_rejects_body_beyond_bound_without_parsing(self):
        self.assertEqual(self.safe(api.classify_meta(200, b"A" * (api.MAX_BYTES+1)))["reason"],
                         "INVALID_API_PAYLOAD_SIZE")

    def test_offline_item_page_shape_recognized_but_never_exposes_prices(self):
        r = self.safe(api.classify_item_page(200, encode(page())))
        self.assertEqual(r["status"], "RESEARCH_ITEM_PAGE_ONLY")
        self.assertEqual(r["pageItems"], 2)
        self.assertEqual(r["totalProviderItems"], 2)
        self.assertEqual(r["naiveItemClocks"], 2)
        self.assertFalse(r["rawGameWeaponKeysPresent"])
        self.assertFalse(r["itemPricesReturned"])
        self.assertEqual(r["itemClockTimeZone"], "UNSPECIFIED")

    def test_item_page_error_statuses_same_boundary(self):
        for status in (401, 403, 429, 503):
            r = self.safe(api.classify_item_page(status, b"SECRET_NEVER_ECHO"))
            self.assertFalse(r["confirmedMarketQuote"])
            self.assertNotIn("SECRET", str(r))

    def test_item_page_requires_count_matching_rows(self):
        for field, value in (("total", 0), ("total", 1), ("offset", 1),
                             ("limit", 50), ("count", 1), ("count", "2")):
            x = page()
            x[field] = value
            with self.subTest(field=field):
                self.assertEqual(self.safe(api.classify_item_page(
                    200, encode(x)))["reason"], "INVALID_PAGE_COUNT_OR_OFFSET")

    def test_unexpected_empty_page_before_total_denied(self):
        x = page()
        x["items"] = []
        x["count"] = 0
        self.assertEqual(self.safe(api.classify_item_page(200, encode(x)))["reason"],
                         "MISSING_PAGE_ROWS")

    def test_duplicate_item_id_and_slug_blocked(self):
        for field in ("id", "slug"):
            x = page()
            x["items"][1][field] = x["items"][0][field]
            with self.subTest(field=field):
                self.assertEqual(self.safe(api.classify_item_page(
                    200, encode(x)))["reason"], "DUPLICATE_ITEM_OR_ALIAS_COLLISION")

    def test_item_invalid_value_types_demand_and_category_denied(self):
        changes = [
            ("value", True), ("value", None), ("value", -3),
            ("value_source_a", -1), ("value_source_b", "50"),
            ("demand", 100), ("demand", True), ("category", "invented"),
            ("id", False), ("slug", "http://secret"), ("slug", "../pwn"),
        ]
        for field, value in changes:
            x = page()
            x["items"][0][field] = value
            with self.subTest(field=field):
                r = self.safe(api.classify_item_page(200, encode(x)))
                self.assertEqual(r["status"], "BLOCKED")

    def test_item_ambiguous_time_zone_never_authenticates_a_price(self):
        x = page()
        x["items"][0]["last_updated"] = "2026-11-12T12:33:44Z"
        self.assertEqual(self.safe(api.classify_item_page(200, encode(x)))["reason"],
                         "ITEM_CLOCK_UNVERIFIED")

    def test_pagination_is_fixed_and_strict(self):
        x = page()
        x["total"] = 202
        self.assertTrue(self.safe(api.classify_item_page(
            200, encode(x)))["hasAnotherPage"])
        for bad_limit, bad_offset in ((101, 0), (0, 0), (100, -1),
                                      (True, 0), (100, "0")):
            r = self.safe(api.classify_item_page(200, encode(x),
                                               requested_limit=bad_limit,
                                               requested_offset=bad_offset))
            self.assertEqual(r["reason"], "REQUEST_PAGINATION_INVALID")

    def test_real_transport_only_fixed_same_host_paths(self):
        for path in ("/items/../../secret", "https://example.com/steal",
                     "/meta?api_key=TEST", "/history", "/items?limit=100"):
            with self.subTest(path=path):
                with self.assertRaisesRegex(ValueError, "ENDPOINT_NOT_ALLOWED"):
                    api._no_redirect_get(path, FAKE_SECRET)

    def test_transport_sends_header_and_never_puts_key_in_url(self):
        class Response:
            def getcode(self):
                return 200
            def read(self, n):
                return encode(meta())
            def __enter__(self):
                return self
            def __exit__(self, *_args):
                return False
        class Opener:
            def open(self, req, timeout):
                self_url = req.full_url
                self.assertEqual(self_url, api.BASE + "/meta")
                self.assertNotIn(FAKE_SECRET, self_url)
                self.assertEqual(req.get_header("X-api-key"), FAKE_SECRET)
                self.assertLessEqual(timeout, 8)
                return Response()
            def assertEqual(self, x, y):
                assert x == y
            def assertNotIn(self, a, b):
                assert a not in b
            def assertLessEqual(self, a, b):
                assert a <= b
        with mock.patch("urllib.request.build_opener", return_value=Opener()) as patched:
            code, body = api._no_redirect_get("/meta", FAKE_SECRET)
        self.assertEqual(code, 200)
        self.assertEqual(body, encode(meta()))
        self.assertEqual(patched.call_count, 1)
        self.assertTrue(any(isinstance(x, api._NoRedirect)
                            for x in patched.call_args.args))

    def test_transport_does_not_retry_on_http_error(self):
        import urllib.error
        def error(*_args, **_kwargs):
            raise urllib.error.HTTPError(api.BASE + "/meta", 429, "limit", {}, None)
        with mock.patch("urllib.request.build_opener") as build:
            build.return_value.open.side_effect = error
            code, body = api._no_redirect_get("/meta", FAKE_SECRET)
            self.assertEqual(build.return_value.open.call_count, 1)
        self.assertEqual((code, body), (429, b""))

    def test_unavailable_provider_status_is_now_diagnostic_and_sanitized(self):
        statuses = {
            400: "HTTP_STATUS_400",
            404: "HTTP_STATUS_404",
            500: "HTTP_STATUS_500",
            502: "HTTP_STATUS_502",
            503: "HTTP_STATUS_503",
            590: "NETWORK_DNS_FAILURE",
            591: "NETWORK_TLS_FAILURE",
            593: "NETWORK_TIMEOUT",
            599: "NETWORK_OR_PROXY_FAILURE",
            302: "HTTP_REDIRECT_NOT_FOLLOWED",
        }
        for status, reason in statuses.items():
            with self.subTest(status=status):
                result = self.safe(api.classify_meta(status, b"SECRET_NEVER_ECHO"))
                self.assertEqual(result["status"], "SOURCE_UNAVAILABLE")
                self.assertEqual(result["reason"], reason)

    def test_transport_dns_tls_and_timeout_errors_are_safe_error_categories(self):
        import socket
        import ssl
        import urllib.error
        examples = [
            (urllib.error.URLError(socket.gaierror("EXAMPLE_PRIVATE_SECRET")),
             590, "NETWORK_DNS_FAILURE"),
            (urllib.error.URLError(ssl.SSLCertVerificationError("PRIVATE_CERT_PATH")),
             591, "NETWORK_TLS_FAILURE"),
            (urllib.error.URLError(TimeoutError("PRIVATE_REQUEST_TARGET")),
             593, "NETWORK_TIMEOUT"),
            (urllib.error.URLError("PRIVATE_PROXY_PASSWORD"),
             599, "NETWORK_OR_PROXY_FAILURE"),
        ]
        for exception, code, reason in examples:
            with self.subTest(reason=reason):
                with mock.patch("urllib.request.build_opener") as build:
                    build.return_value.open.side_effect = exception
                    status, body = api._no_redirect_get("/meta", FAKE_SECRET)
                self.assertEqual((status, body), (code, b""))
                result = self.safe(api.classify_meta(status, body))
                self.assertEqual(result["reason"], reason)
                self.assertNotIn("PRIVATE_", str(result))

    def test_fake_transport_exception_sanitized_without_leaking_key(self):
        def err(_path, key):
            raise RuntimeError(key)
        r = self.safe(api.probe_private_meta(
            enabled=True, secret=FAKE_SECRET, transport=err))
        self.assertEqual(r["status"], "SOURCE_UNAVAILABLE")
        self.assertEqual(r["reason"], "TRANSPORT_EXCEPTION_UNCLASSIFIED")

    def test_unexpected_transport_failures_are_stage_specific_and_secret_free(self):
        for problem, expected in (
            (TypeError(FAKE_SECRET), "TRANSPORT_EXCEPTION_TYPEERROR"),
            (ValueError(FAKE_SECRET), "TRANSPORT_EXCEPTION_VALUEERROR"),
            (KeyError(FAKE_SECRET), "TRANSPORT_EXCEPTION_KEYERROR"),
            (AttributeError(FAKE_SECRET), "TRANSPORT_EXCEPTION_ATTRIBUTEERROR"),
        ):
            with self.subTest(error_type=type(problem).__name__):
                def throw(_path, _key):
                    raise problem
                result = self.safe(api.probe_private_meta(
                    enabled=True, secret=FAKE_SECRET, transport=throw))
                self.assertEqual(result["reason"], expected)

    def test_unexpected_meta_parser_exception_is_separately_diagnosed(self):
        with mock.patch.object(api, "classify_meta",
                               side_effect=TypeError(FAKE_SECRET)):
            result = self.safe(api.probe_private_meta(
                enabled=True, secret=FAKE_SECRET,
                transport=lambda _path, _key: (200, encode(meta()))))
        self.assertEqual(result["status"], "BLOCKED")
        self.assertEqual(result["reason"], "PARSER_EXCEPTION_TYPEERROR")

    def test_cli_defaults_to_off_and_ignores_env_key(self):
        with mock.patch.dict(os.environ, {"RBLXVALUE_API_KEY": FAKE_SECRET},
                             clear=True):
            with mock.patch.object(api, "_no_redirect_get",
                                   side_effect=AssertionError("network")):
                sio = StringIO()
                with redirect_stdout(sio):
                    self.assertEqual(api.main([]), 0)
                r = self.safe(json.loads(sio.getvalue()))
                self.assertEqual(r["status"], "DISABLED")

    def test_private_probe_enabled_but_key_missing_still_offline(self):
        with mock.patch.dict(os.environ, {"P1_PRIVATE_METADATA_PROBE": "YES"},
                             clear=True):
            with mock.patch.object(api, "_no_redirect_get",
                                   side_effect=AssertionError("network")):
                sio = StringIO()
                with redirect_stdout(sio):
                    self.assertEqual(api.main(["--probe-meta"]), 0)
                self.assertEqual(self.safe(json.loads(sio.getvalue()))["status"],
                                 "KEY_REQUIRED")

    def test_100_malformed_metadatas_never_return_market_authority(self):
        for i in range(100):
            x = meta()
            x["totals"]["items"] = i if i % 2 else str(i)
            x["last_updated"] = "2026-11-12 12:33:44" if i % 3 else "invalid"
            x["sources"] = ["mm2values", "supremevalues"] if i % 5 else ["unknown"]
            self.safe(api.classify_meta(200, encode(x)))

if __name__ == "__main__":
    unittest.main()
