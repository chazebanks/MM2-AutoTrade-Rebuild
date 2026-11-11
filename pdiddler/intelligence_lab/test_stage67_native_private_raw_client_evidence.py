"""Stage67: native-shaped Stage66 evidence + 1000 fail-closed mutation checks."""
from __future__ import annotations

import copy
import importlib.util
import json
import random
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "scripts/stage67_native_private_raw_client_evidence.py"
spec = importlib.util.spec_from_file_location("stage67", SRC)
assert spec and spec.loader
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

def native66():
    """Exact anonymous fields/values in the user-supplied Stage66 native report."""
    return {
        "eventSessionAssociationProven": False,
        "recordCount": 2,
        "coreTerminal": True,
        "readOnly": True,
        "serverTransactionIdAuthenticated": False,
        "status": "CLIENT_RAW_RECEIPT_EQUALS_OWN_GAIN_UNATTRIBUTED",
        "callbackRowFieldTypes": ["string", "number", "string"],
        "callbackRowShape": "TRIPLET_ELEMENT_TYPES_OBSERVED",
        "serverAttestation": False,
        "authorizesAccept": False,
        "authorizesTrade": False,
        "listenerDisconnected": True,
        "clientCompatibleFlagPattern": True,
        "schema": "gingerscope-stage66-one-window-client-accept-delta-v1",
        "causalTradeAttributionProven": False,
        "serverCompletionProven": False,
        "mayRecordCompletedTrade": False,
        "reason": "private-raw-key-string-equality-is-not-server-settlement-proof",
        "tradeOutcome": "UNKNOWN",
        "discardedReceipts": 0,
        "mayRecordRejectedTrade": False,
        "privateRawKeyEqualityObserved": True,
        "privateRawEqualityStatus": "PRIVATE_RAW_PRIMITIVE_EQUALITY_CLIENT_ONLY",
        "stablePartnerLabel": True,
        "samples": [
            {
                "secondArg": "NIL",
                "firstArg": "BOOLEAN_FALSE",
                "phase": "WITHIN_BOUND_GUI_CLIENT_ONLY",
                "elapsedSeconds": 12,
                "argCount": 1,
                "secondTableShape": "NOT_TABLE",
            },
            {
                "secondArg": "TABLE",
                "firstArg": "BOOLEAN_TRUE",
                "phase": "IMMEDIATE_GUI_CLOSE_CLIENT_ONLY",
                "elapsedSeconds": 14.2,
                "argCount": 2,
                "secondTableShape": "BOUNDED_SEQUENCE_1",
            },
        ],
        "ownReadbacks": {
            "rawWeaponInventoryChanged": True,
            "stopReason": "TWO_POST_CLOSE_READS_FINISHED",
            "beforeObserved": True,
            "partnerCacheAtBaseline": True,
            "gainedEligibleCopies": 1,
            "changedEligibleTypes": 1,
            "status": "ELIGIBLE_DELTA_WITHOUT_RESULT_NAMED_RECEIPT",
            "windowClosureObserved": True,
            "lostEligibleCopies": 0,
            "postReadbacksObserved": 2,
        },
        "ignoredUnboundReceipts": 0,
        "guiBound": True,
        "sameBoundWindowClientOnly": True,
        "exactCallbackWeaponKeyIdentityProven": False,
        "privateRawEqualityReason": "private-exact-string-equality-is-not-server-transaction-proof",
        "clientReciprocalTransferProven": False,
        "mayUseForStrategyLearning": False,
        "mayReportProfit": False,
        "exactWeaponIdentityConfirmed": False,
    }

def assert_no_authority(t, out):
    for field in (
        "recordDeduplicationPossible",
        "sourceRunNonceObserved",
        "distinctTradeObserved",
        "independentCounterpartyWitnessObserved",
        "operatorConfirmedThisRun",
        "serverAttestation",
        "serverCompletionProven",
        "serverTransactionIdAuthenticated",
        "eventSessionAssociationProven",
        "causalTradeAttributionProven",
        "exactWeaponIdentityConfirmed",
        "mayRecordCompletedTrade",
        "mayRecordRejectedTrade",
        "mayReportProfit",
        "mayUseForStrategyLearning",
        "authorizesAccept",
        "authorizesTrade",
        "discordMarketLearningEligible",
    ):
        t.assertIs(out[field], False, field)
    t.assertEqual(out["tradeOutcome"], "UNKNOWN")
    t.assertEqual(out["evidenceTier"],
                  "LOCAL_CLIENT_OBSERVATION_NOT_SETTLEMENT")


class Stage67StrictNativeClientAudit(unittest.TestCase):
    def test_real_user_stage66_report_accepts_only_client_raw_equality(self):
        out = mod.evaluate(native66())
        self.assertEqual(out["status"],
                         "CLIENT_PRIVATE_RAW_KEY_EQUALITY_UNATTRIBUTED")
        self.assertTrue(out["clientRawPrimitiveEqualityPatternObserved"])
        self.assertNotIn("samples", out)
        self.assertNotIn("ownReadbacks", out)
        assert_no_authority(self, out)

    def test_report_has_no_unique_nonce_and_repeated_copy_is_not_second_trade(self):
        original = native66()
        self.assertNotIn("nonce", original)
        self.assertNotIn("transactionId", original)
        self.assertNotIn("localRunId", original)
        first = mod.evaluate(original)
        second = mod.evaluate(copy.deepcopy(original))
        self.assertEqual(first, second)
        self.assertFalse(first["recordDeduplicationPossible"])
        self.assertFalse(second["distinctTradeObserved"])
        # Combining two same-shaped reports, or a previous test, is not input.
        self.assertEqual(mod.evaluate([original, original])["status"],
                         "INCONCLUSIVE")
        self.assertEqual(mod.evaluate({"stage66": original, "stage63": {}})["status"],
                         "INCONCLUSIVE")
        assert_no_authority(self, first)

    def test_every_self_attested_authority_flag_rejected(self):
        valid = native66()
        for field in mod.FALSE_FLAGS:
            with self.subTest(field=field):
                x = copy.deepcopy(valid)
                x[field] = True
                out = mod.evaluate(x)
                self.assertEqual(out["status"], "INCONCLUSIVE")
                self.assertFalse(out["clientRawPrimitiveEqualityPatternObserved"])
                assert_no_authority(self, out)
        for field in mod.TRUE_FLAGS:
            with self.subTest(field=field):
                x = copy.deepcopy(valid)
                x[field] = False
                out = mod.evaluate(x)
                self.assertEqual(out["status"], "INCONCLUSIVE")
                assert_no_authority(self, out)

    def test_schema_and_private_data_must_not_be_imported(self):
        for kind in ("report", "sample", "readback"):
            x = native66()
            if kind == "report":
                x["userId"] = "SECRET_USER_123"
            elif kind == "sample":
                x["samples"][1]["receivedItem"] = "SECRET_KEY"
            else:
                x["ownReadbacks"]["rawWeaponId"] = "SECRET_RAW"
            out = mod.evaluate(x)
            self.assertEqual(out["status"], "INCONCLUSIVE")
            self.assertNotIn("SECRET_", json.dumps(out))
            assert_no_authority(self, out)
        for bad in (None, "string", 0, {}, [], [native66()], True):
            self.assertEqual(mod.evaluate(bad)["status"], "INCONCLUSIVE")

    def test_native_callback_timeline_and_own_snapshot_failure(self):
        edits = [
            lambda x: x["samples"].reverse(),
            lambda x: x["samples"][0].__setitem__("firstArg", "BOOLEAN_TRUE"),
            lambda x: x["samples"][1].__setitem__("secondArg", "NIL"),
            lambda x: x["samples"][1].__setitem__("secondTableShape", "BOUNDED_SEQUENCE_0"),
            lambda x: x["samples"][1].__setitem__("argCount", True),
            lambda x: x["samples"][1].__setitem__("phase", "OUT_OF_WINDOW"),
            lambda x: x["samples"][0].__setitem__("phase", "AFTER_CLOSE_UNATTRIBUTED"),
            lambda x: x["samples"][0].__setitem__("elapsedSeconds", 16),
            lambda x: x["samples"][1].__setitem__("elapsedSeconds", 25),
            lambda x: x["samples"][1].__setitem__("elapsedSeconds", float("nan")),
            lambda x: x["samples"][0].__setitem__("elapsedSeconds", float("inf")),
            lambda x: x["samples"].append(copy.deepcopy(x["samples"][1])),
            lambda x: x["ownReadbacks"].__setitem__("gainedEligibleCopies", 2),
            lambda x: x["ownReadbacks"].__setitem__("lostEligibleCopies", 1),
            lambda x: x["ownReadbacks"].__setitem__("changedEligibleTypes", 0),
            lambda x: x["ownReadbacks"].__setitem__("partnerCacheAtBaseline", False),
            lambda x: x["ownReadbacks"].__setitem__("postReadbacksObserved", 1),
            lambda x: x["ownReadbacks"].__setitem__("stopReason", "TIMEOUT"),
            lambda x: x["ownReadbacks"].__setitem__("rawWeaponInventoryChanged", False),
            lambda x: x.__setitem__("callbackRowFieldTypes", ["number", "number", "string"]),
            lambda x: x.__setitem__("privateRawEqualityStatus", "UNVERIFIED"),
            lambda x: x.__setitem__("ignoredUnboundReceipts", 1),
            lambda x: x.__setitem__("recordCount", 3),
            lambda x: x.__setitem__("discardedReceipts", 1),
            lambda x: x.__setitem__("schema", "gingerscope-stage59-two-client-aggregate-witness-v1"),
            lambda x: x.__setitem__("tradeOutcome", "COMPLETED"),
        ]
        for i, change in enumerate(edits):
            with self.subTest(i=i):
                x = native66()
                change(x)
                out = mod.evaluate(x)
                self.assertEqual(out["status"], "INCONCLUSIVE", (i, out))
                assert_no_authority(self, out)

    def test_1200_seeded_corruptions_fail_closed(self):
        rng = random.Random(67067)
        for i in range(1200):
            x = native66()
            selected = rng.randrange(18)
            if selected == 0: x["recordCount"] = rng.randint(3, 100)
            elif selected == 1: x["discardedReceipts"] = rng.randint(1, 100)
            elif selected == 2: x["ignoredUnboundReceipts"] = rng.randint(1, 100)
            elif selected == 3: x["samples"][1]["elapsedSeconds"] = rng.randint(20, 150)
            elif selected == 4: x["samples"][0]["elapsedSeconds"] = rng.randint(17, 100)
            elif selected == 5: x["samples"][1]["argCount"] = rng.randint(3, 16)
            elif selected == 6: x["samples"][0]["firstArg"] = "BOOLEAN_TRUE"
            elif selected == 7: x["samples"][1]["secondTableShape"] = "BOUNDED_SEQUENCE_2"
            elif selected == 8: x["samples"][0]["phase"] = "PRE_BOUND_UNATTRIBUTED"
            elif selected == 9: x["samples"][1]["phase"] = "OUT_OF_WINDOW"
            elif selected == 10: x["ownReadbacks"]["gainedEligibleCopies"] = rng.randint(2, 100)
            elif selected == 11: x["ownReadbacks"]["lostEligibleCopies"] = rng.randint(1, 100)
            elif selected == 12: x["ownReadbacks"]["postReadbacksObserved"] = rng.randint(3, 100)
            elif selected == 13: x["ownReadbacks"]["status"] = "UNKNOWN"
            elif selected == 14: x["serverCompletionProven"] = True
            elif selected == 15: x["mayUseForStrategyLearning"] = True
            elif selected == 16: x["samples"][1]["rawItemKey"] = str(rng.getrandbits(64))
            elif selected == 17: x["privateRawEqualityReason"] = "server-complete"
            result = mod.evaluate(x)
            self.assertEqual(result["status"], "INCONCLUSIVE", (i, selected))
            assert_no_authority(self, result)

    def test_pure_offline_source_never_calls_network_or_trade_apis(self):
        code = SRC.read_text(encoding="utf-8")
        for forbidden in ("requests.", "httpx", "urllib.request", "subprocess",
                          "FireServer", "InvokeServer", "getgenv", "DiscordWebhook",
                          "setclipboard", "http://", "https://", "API_KEY"):
            self.assertNotIn(forbidden, code)


if __name__ == "__main__":
    unittest.main()
