import copy
import subprocess
import unittest

try:
    from pdiddler.continuity.recovery_gate import gate, unique_fields
except ModuleNotFoundError:
    from recovery_gate import gate, unique_fields


GOOD = {
    "taskId": "GS-RECOVERY-20261114",
    "baseHead": "44268df1e3080b49aa9e586851867fd602a3ce1f",
    "sourceHead": "5925c6a4cb4b7eb7491d6bd00592039e1c83154b",
    "sourcePullRequest": 289,
    "recoveredEntrypoint": "00 - GINGERSCOPE RECOVERY ENTRYPOINT - READ FIRST",
    "missionRead": True,
    "matrixRead": True,
    "historyCoverage": "PARTIAL_NOT_ALL_STAGES_AUDITED",
    "relatedFailures": ["F13 stale history index"],
    "priorEvidence": [{
        "url": "https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/289",
        "head": "5925c6a4cb4b7eb7491d6bd00592039e1c83154b",
    }],
    "falsificationTests": ["Missing evidence must block"],
    "scope": "TEST_ONLY",
    "authorization": "NO_LIVE_GAME_ACTIONS",
    "risk": "NO_GAME_ACTIONS_NO_PRIVATE_DATA",
    "newFindings": ["Original history remains partial"],
}
REFS = {
    "refs/heads/main": "44268df1e3080b49aa9e586851867fd602a3ce1f",
    "refs/pull/289/head": "5925c6a4cb4b7eb7491d6bd00592039e1c83154b",
}


def evaluate(receipt, refs=REFS):
    return gate(receipt, resolve_refs=lambda names: {name: refs[name] for name in names if name in refs})


class GateTests(unittest.TestCase):
    def test_live_refs_match_receipt_and_reading_stays_self_attested(self):
        result = evaluate(GOOD)
        self.assertEqual(result["status"], "RESEARCH_RECEIPT_VALID")
        self.assertEqual(result["verifiedRefs"], REFS)
        self.assertIn("Self-attested reading", result["note"])

    def test_missing_each_required(self):
        for field in GOOD:
            with self.subTest(field=field):
                receipt = copy.deepcopy(GOOD)
                del receipt[field]
                self.assertEqual(evaluate(receipt)["reasons"], [f"MISSING_{field}"])

    def test_invalid_values(self):
        cases = [
            ("taskId", "x"), ("sourceHead", "0" * 39),
            ("recoveredEntrypoint", "wrong"), ("missionRead", False), ("matrixRead", False),
            ("historyCoverage", "COMPLETE"), ("scope", "LIVE_TRADE"),
            ("authorization", "AUTHORIZED"), ("risk", "PRIVATE_DATA"),
            ("relatedFailures", []), ("priorEvidence", ["https://example.org/pr/289"]),
            ("falsificationTests", ["short"]), ("newFindings", []),
            ("sourcePullRequest", True), ("sourcePullRequest", 288),
        ]
        for field, value in cases:
            with self.subTest(field=field, value=value):
                self.assertEqual(evaluate({**GOOD, field: value})["status"], "BLOCKED")

    def test_false_trade_authority(self):
        for field in ("serverSettlementProven", "authorizesFinalAccept"):
            for value in (True, "true", None):
                with self.subTest(field=field, value=value):
                    self.assertEqual(evaluate({**GOOD, field: value})["reasons"],
                                     ["UNSUPPORTED_LIVE_AUTHORITY"])

    def test_wrong_field_types_produce_structured_block(self):
        for field, value in (("scope", []), ("priorEvidence", [17]), ("priorEvidence", {})):
            with self.subTest(field=field, value=value):
                self.assertEqual(evaluate({**GOOD, field: value})["status"], "BLOCKED")
        for payload in ([], True, "receipt", None):
            with self.subTest(payload=payload):
                self.assertEqual(evaluate(payload)["reasons"], ["INVALID_RECEIPT"])

    def test_zero_commit_is_rejected(self):
        self.assertIn("HEAD_INVALID", evaluate({**GOOD, "sourceHead": "0" * 40})["reasons"])

    def test_github_head_mismatch_blocks_even_if_commit_is_well_formed(self):
        advanced = {**REFS, "refs/pull/289/head": "f" * 40}
        self.assertEqual(evaluate(GOOD, advanced)["reasons"], ["SOURCE_HEAD_STALE"])

    def test_source_pr_head_must_match_its_pin_in_the_receipt(self):
        self.assertEqual(evaluate({**GOOD, "sourceHead": "f" * 40})["reasons"],
                         ["CONFLICTING_SOURCE_HEAD"])

    def test_main_advances_after_recovery(self):
        newer_refs = {**REFS, "refs/heads/main": "f" * 40}
        self.assertEqual(evaluate(GOOD, newer_refs)["reasons"], ["BASE_HEAD_STALE"])

    def test_receipt_must_match_the_trusted_validator_checkout(self):
        result = gate(GOOD, resolve_refs=lambda _names: REFS, expected_base="f" * 40)
        self.assertEqual(result["reasons"], ["TRUSTED_BASE_MISMATCH"])

    def test_missing_primary_pr_blocks(self):
        self.assertEqual(evaluate(GOOD, {"refs/heads/main": GOOD["baseHead"]})["reasons"],
                         ["PR_EVIDENCE_UNRESOLVED_289"])

    def test_missing_secondary_pr_blocks_even_if_primary_exists(self):
        receipt = {
            **GOOD,
            "priorEvidence": [
                *GOOD["priorEvidence"],
                {"url": "https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/987654321", "head": "f" * 40},
            ],
        }
        self.assertEqual(evaluate(receipt)["reasons"], ["PR_EVIDENCE_UNRESOLVED_987654321"])

    def test_secondary_pr_head_must_match_its_pin(self):
        receipt = {**GOOD, "priorEvidence": [
            *GOOD["priorEvidence"],
            {"url": "https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/288", "head": "f" * 40},
        ]}
        refs = {**REFS, "refs/pull/288/head": "a" * 40}
        self.assertEqual(evaluate(receipt, refs)["reasons"], ["PR_EVIDENCE_STALE_288"])

    def test_missing_base_ref_blocks(self):
        self.assertEqual(evaluate(GOOD, {"refs/pull/289/head": GOOD["sourceHead"]})["reasons"],
                         ["GITHUB_BASE_REF_UNAVAILABLE"])

    def test_unavailable_github_blocks(self):
        def timeout(_names):
            raise subprocess.TimeoutExpired("git ls-remote", 25)

        self.assertEqual(gate(GOOD, resolve_refs=timeout)["reasons"], ["GITHUB_REFS_UNAVAILABLE"])

    def test_duplicate_json_keys_are_rejected(self):
        with self.assertRaises(ValueError):
            unique_fields([("scope", "TEST_ONLY"), ("scope", "LIVE_TRADE")])


if __name__ == "__main__":
    unittest.main()
