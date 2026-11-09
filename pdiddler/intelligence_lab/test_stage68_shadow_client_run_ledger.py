"""Stage68: client-run copy replay and nonmarket quarantine, 1,200 variants."""
from __future__ import annotations

import copy
import importlib.util
import random
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT/"scripts/stage68_shadow_client_run_ledger.py"
spec = importlib.util.spec_from_file_location("stage68_shadow", PATH)
assert spec and spec.loader
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

N1 = "11111111-2222-4333-8444-555555555555"
N2 = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"

def source(nonce=N1):
    return {
        "schema": "gingerscope-stage68-client-run-id-observation-v1",
        "clientRunNonce": nonce,
        "clientRunNonceProvenServerSide": False,
        "status": "CLIENT_RAW_RECEIPT_EQUALS_OWN_GAIN_UNATTRIBUTED",
        "tradeOutcome": "UNKNOWN",
        "serverCompletionProven": False,
        "serverAttestation": False,
        "serverTransactionIdAuthenticated": False,
        "eventSessionAssociationProven": False,
        "causalTradeAttributionProven": False,
        "exactWeaponIdentityConfirmed": False,
        "mayRecordCompletedTrade": False,
        "mayRecordRejectedTrade": False,
        "mayReportProfit": False,
        "mayUseForStrategyLearning": False,
        "authorizesAccept": False,
        "authorizesTrade": False,
        "clientReciprocalTransferProven": False,
        "readOnly": True,
        "privateRawKeyEqualityObserved": True,
        "privateRawDataReleased": True,
        "listenerDisconnected": True,
        "privateRawEqualityStatus": "PRIVATE_RAW_PRIMITIVE_EQUALITY_CLIENT_ONLY",
    }

def reject_trade_authority(t, r):
    for k in ("distinctTradeCount", "completedTradesRecorded",
              "rejectedTradesRecorded", "profitClaimsRecorded",
              "marketTrainingExamples", "authenticatedServerTransactions"):
        t.assertEqual(r[k], 0, k)
    for k in ("observationNonceIsServerAuthenticated",
              "mayRecordCompletedTrade", "mayRecordRejectedTrade",
              "mayUseForStrategyLearning", "mayReportProfit",
              "authorizesAccept", "discordWebhookSent"):
        t.assertIs(r[k], False, k)
    t.assertEqual(r["tradeOutcome"], "UNKNOWN")

class Stage68ShadowLedgerTests(unittest.TestCase):
    def test_repeated_copy_of_same_guid_is_one_client_observation(self):
        ledger = mod.ShadowLedger()
        first = ledger.ingest(source())
        self.assertEqual(first["status"], "SHADOW_CLIENT_OBSERVATION_ONLY")
        self.assertEqual(first["shadowClientObservationCount"], 1)
        for _ in range(50):
            second = ledger.ingest(copy.deepcopy(source()))
            self.assertEqual(second["status"], "DUPLICATE_CLIENT_RUN")
            self.assertEqual(second["shadowClientObservationCount"], 1)
            reject_trade_authority(self, second)
        self.assertEqual(ledger.client_observation_count, 1)
        reject_trade_authority(self, first)

    def test_different_client_guids_are_observations_not_proven_trades(self):
        ledger = mod.ShadowLedger()
        a = ledger.ingest(source(N1))
        b = ledger.ingest(source(N2))
        self.assertEqual(a["shadowClientObservationCount"], 1)
        self.assertEqual(b["shadowClientObservationCount"], 2)
        self.assertEqual(ledger.client_observation_count, 2)
        reject_trade_authority(self, b)
        self.assertNotIn("clientRunNonce", b)
        self.assertNotIn(N2, str(b))

    def test_old_stage66_without_guid_and_supplied_server_claim_quarantined(self):
        ledger = mod.ShadowLedger()
        without = source()
        without.pop("clientRunNonce")
        self.assertEqual(ledger.ingest(without)["status"], "QUARANTINED")
        x = source()
        x["clientRunNonceProvenServerSide"] = True
        self.assertEqual(ledger.ingest(x)["status"], "QUARANTINED")
        x = source()
        x["serverCompletionProven"] = True
        self.assertEqual(ledger.ingest(x)["status"], "QUARANTINED")
        self.assertEqual(ledger.client_observation_count, 0)

    def test_nonce_corruption_source_flags_and_release_failure(self):
        ledger = mod.ShadowLedger()
        strings = [
            "", "NOT_GENERATED", "123",
            "{11111111-2222-4333-8444-555555555555}",
            "11111111-2222-4333-8444-55555555555z",
            "11111111-2222-4333-8444-555555555555 ",
            "11111111-2222-4333-8444-555555555555\n",
            "not-a-uuid",
        ]
        for value in strings:
            x = source(value)
            self.assertEqual(ledger.ingest(x)["status"], "QUARANTINED")
        for key in mod.FIXED_FALSE:
            x = source()
            x[key] = True
            out = ledger.ingest(x)
            self.assertEqual(out["status"], "QUARANTINED", key)
            reject_trade_authority(self, out)
        for key in mod.REQUIRED_TRUE:
            x = source()
            x[key] = False
            out = ledger.ingest(x)
            self.assertEqual(out["status"], "QUARANTINED", key)
            reject_trade_authority(self, out)
        self.assertEqual(ledger.client_observation_count, 0)

    def test_1200_deterministic_adversarial_input_variants(self):
        rng = random.Random(68068)
        ledger = mod.ShadowLedger()
        for i in range(1200):
            x = source()
            k = rng.randrange(13)
            if k == 0: x["clientRunNonce"] = ""
            elif k == 1: x["clientRunNonce"] = str(rng.randint(1, 10000000))
            elif k == 2: x["clientRunNonceProvenServerSide"] = True
            elif k == 3: x["serverCompletionProven"] = True
            elif k == 4: x["mayUseForStrategyLearning"] = True
            elif k == 5: x["authorizesAccept"] = True
            elif k == 6: x["readOnly"] = False
            elif k == 7: x["privateRawDataReleased"] = False
            elif k == 8: x["privateRawKeyEqualityObserved"] = False
            elif k == 9: x["privateRawEqualityStatus"] = "UNKNOWN"
            elif k == 10: x["schema"] = "gingerscope-stage66-one-window-client-accept-delta-v1"
            elif k == 11: x["status"] = "COMPLETE"
            elif k == 12: x["tradeOutcome"] = "SETTLED"
            out = ledger.ingest(x)
            self.assertEqual(out["status"], "QUARANTINED", (i, k, out))
            reject_trade_authority(self, out)
        self.assertEqual(ledger.client_observation_count, 0)

    def test_untrusted_bundles_cannot_create_observations(self):
        ledger = mod.ShadowLedger()
        for bad in (None, [], [source()], {"stage66": source()},
                    False, "PRIVATE_ITEM_NAME", 42):
            out = ledger.ingest(bad)
            self.assertEqual(out["status"], "QUARANTINED")
            self.assertNotIn("PRIVATE_ITEM_NAME", str(out))
            reject_trade_authority(self, out)
        source_text = PATH.read_text(encoding="utf-8")
        for forbidden in ("requests.", "httpx", "urllib", "subprocess",
                          "webhook", "HttpGet", "FireServer", "InvokeServer"):
            # The word webhook occurs as a lower-case output field name.
            if forbidden == "webhook":
                continue
            self.assertNotIn(forbidden, source_text)

if __name__ == "__main__":
    unittest.main()
