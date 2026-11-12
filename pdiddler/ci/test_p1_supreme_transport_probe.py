"""Focused synthetic tests for P1 transport diagnostic; zero network calls."""
import unittest

from pdiddler.ci import p1_supreme_transport_probe as d


class FakeResponse:
    def __init__(self, status, *, headers=None, url=d.CANONICAL):
        self.status_code = status
        self.headers = headers or {}
        self.url = url
        self.closed = False

    @property
    def content(self):
        raise AssertionError("PROBE_MUST_NOT_READ_HTML_BODY")

    def iter_content(self, **_):
        raise AssertionError("PROBE_MUST_NOT_READ_HTML_BODY")

    def close(self):
        self.closed = True


class FakeSession:
    def __init__(self, response=None, error=None):
        self.response = response
        self.error = error
        self.calls = []

    def get(self, url, **kwargs):
        self.calls.append((url, kwargs))
        if self.error:
            raise self.error
        return self.response


class TransportDiagnosticTests(unittest.TestCase):
    def run_probe(self, status, **kwargs):
        r = FakeResponse(status, **kwargs)
        session = FakeSession(r)
        result = d.probe(session, clock=lambda: "2026-11-11T23:55:00Z")
        self.assertEqual(len(session.calls), 1)
        url, opts = session.calls[0]
        self.assertEqual(url, d.CANONICAL)
        self.assertEqual(opts["headers"], d.REQUEST_HEADERS)
        self.assertEqual(opts["timeout"], (8, 20))
        self.assertTrue(opts["verify"])
        self.assertTrue(opts["stream"])
        self.assertFalse(opts["allow_redirects"])
        self.assertTrue(r.closed)
        self.assertFalse(result["bodyRead"])
        self.assertEqual(result["storedResponseBytes"], 0)
        self.assertFalse(result["authenticatesExternalSource"])
        self.assertTrue(all(result[key] is False for key in d.DENIED))
        return result

    def test_http_403_provides_numeric_status_not_source_authority(self):
        res = self.run_probe(403, headers={"Server": "cloudflare", "Content-Type": "text/html", "cf-mitigated": "challenge"})
        self.assertEqual(res["httpStatus"], 403)
        self.assertEqual(res["reason"], "HTTP_ACCESS_RESTRICTED_403")
        self.assertEqual(res["serverClass"], "CLOUDFLARE")
        self.assertTrue(res["cloudflareChallengeHeader"])

    def test_http_200_does_not_admit_market_source(self):
        res = self.run_probe(200, headers={"Content-Type": "text/html"})
        self.assertEqual(res["reason"], "HTTP_200_HEADERS_ONLY_NOT_SOURCE_ADMISSION")

    def test_redirect_never_follows_or_leaks_location(self):
        res = self.run_probe(301, headers={"Location": "https://www.supremevalues.com/mm2/ancients?token=secret"})
        self.assertEqual(res["redirectLocationClass"], "WWW_HOST")
        self.assertNotIn("secret", str(res))
        self.assertEqual(res["reason"], "HTTP_REDIRECT_REVIEW_REQUIRED")

    def test_restricted_or_rate_limited(self):
        self.assertEqual(self.run_probe(429, headers={"Retry-After": "120"})["reason"], "HTTP_ACCESS_RESTRICTED_429")
        self.assertEqual(self.run_probe(503)["reason"], "HTTP_SERVER_ERROR")

    def test_transport_exception_sanitized(self):
        session = FakeSession(error=RuntimeError("secret authorization/cookie text"))
        res = d.probe(session)
        self.assertEqual(res["reason"], "TRANSPORT_EXCEPTION_SANITIZED")
        self.assertNotIn("secret", str(res))
        self.assertTrue(all(res[k] is False for k in d.DENIED))

    def test_cross_site_and_non_tls_redirect_labels(self):
        self.assertEqual(d._redirect_category("https://elsewhere.example/?key=x"), "OTHER_HOST")
        self.assertEqual(d._redirect_category("http://supremevalues.com/mm2/ancients"), "NON_HTTPS")
        self.assertEqual(d._redirect_category("/mm2/ancients"), "RELATIVE_NO_REDIRECT_FOLLOWED")


if __name__ == "__main__":
    unittest.main()
