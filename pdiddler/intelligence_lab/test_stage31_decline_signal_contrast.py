"""Stage31: false-attribution regressions for local vs partner closing MM2.

The baseline fields match the user's native Stage30 anonymized test.
Partner trial fixtures are SYNTHETIC and cannot establish native behavior.
"""
from copy import deepcopy
from dataclasses import fields, replace
import unittest

from stage31_decline_signal_contrast import (
    Contrast, InvalidEvidence, compare_local_and_partner,
)

CATALOG=[
    "AcceptRequest","AcceptTrade","CancelAccept","CancelRequest",
    "CompleteTrade","DeclineRequest","DeclineTrade","EndTrade",
    "GetRequest","OfferItem","RemoveOffer","RequestSent",
    "SetRequestsEnabled","StartTrade","UpdateOffers","UpdateTrade",
]

def baseline():
    return {
        "schema":"gingerscope-stage30-client-trade-signal-census-v1",
        "status":"CLOSED_WITH_CLIENT_SIGNAL_CENSUS",
        "closureStatus":"CLOSED_UNKNOWN",
        "observerClosureStatus":"closed_unknown",
        "probeStopReason":"CLOSE_AND_SIGNAL_GRACE_FINISHED",
        "catalogRemoteEvents":16,"catalogNames":list(CATALOG),
        "signalReceipts":1,"retainedReceipts":1,
        "postCloseSignalReceipts":0,"partnerDepartureObserved":False,
        "observedOurAccept":False,"observedTheirAccept":False,
        "serverAttestation":False,"serverCompletionProven":False,
        "mayRecordCompletedTrade":False,"mayReportProfit":False,
        "authorizesTrade":False,"authorizesAccept":False,
        "signals":[{"phase":"WHILE_OPEN","name":"DeclineTrade","elapsed":12.575}],
    }

class Stage31Tests(unittest.TestCase):
    def test_matching_decline_signal_in_both_traces_cannot_prove_actor(self):
        local=baseline()
        partner=baseline()
        partner["signals"][0]["elapsed"]=17.72
        r=compare_local_and_partner(local,partner)
        self.assertEqual(r.status,"SHARED_DECLINE_NAMED_RECEIPT_NO_ACTOR_PROOF")
        self.assertEqual(r.shared_client_signals,("DeclineTrade",))
        self.assertTrue(r.declared_actions_not_authenticated)
        self.assertFalse(r.initiator_proven)
        self.assertFalse(r.decline_proven)
        self.assertFalse(r.server_completion_proven)
        self.assertFalse(r.may_record_completed_trade)
        self.assertFalse(r.may_report_profit)
        self.assertFalse(r.authorizes_accept)

    def test_event_absent_in_partner_trace_does_not_prove_origin(self):
        local=baseline();partner=baseline()
        partner["signals"]=[];partner["retainedReceipts"]=0
        partner["signalReceipts"]=0
        r=compare_local_and_partner(local,partner)
        self.assertEqual(r.status,"INCONCLUSIVE_DIFFERENT_CLIENT_RECEIPTS")
        self.assertFalse(r.initiator_proven)
        self.assertFalse(r.decline_proven)

    def test_other_event_names_are_not_completed_trade(self):
        local=baseline();partner=baseline()
        partner["signals"][0]["name"]="CompleteTrade"
        r=compare_local_and_partner(local,partner)
        self.assertEqual(r.difference_partner_only,("CompleteTrade",))
        self.assertFalse(r.server_completion_proven)
        self.assertFalse(r.may_report_profit)

    def test_duplicated_receipts_do_not_add_credibility(self):
        partner=baseline()
        partner["signals"]=[
            {"name":"DeclineTrade","phase":"WHILE_OPEN","elapsed":10.5},
            {"name":"DeclineTrade","phase":"WHILE_OPEN","elapsed":10.7},
        ]
        partner["retainedReceipts"]=2;partner["signalReceipts"]=2
        r=compare_local_and_partner(baseline(),partner)
        self.assertEqual(r.shared_client_signals,("DeclineTrade",))

    def test_accepting_either_side_is_outside_requested_test(self):
        for key in ("observedOurAccept","observedTheirAccept"):
            altered=baseline();altered[key]=True
            with self.assertRaisesRegex(InvalidEvidence,"unsupported"):
                compare_local_and_partner(baseline(),altered)

    def test_wrong_schema_or_unclosed_window_rejected(self):
        for key,val in (
            ("schema","bogus"),("status","INCOMPLETE"),
            ("closureStatus","NOT_OBSERVED"),
            ("probeStopReason","WINDOW_TIMED_OUT"),
        ):
            changed=baseline();changed[key]=val
            with self.assertRaises(InvalidEvidence):
                compare_local_and_partner(changed,baseline())

    def test_never_assume_partner_left_or_server_completion(self):
        for key in ("partnerDepartureObserved","serverCompletionProven",
                    "mayRecordCompletedTrade","authorizesTrade"):
            changed=baseline();changed[key]=True
            with self.assertRaises(InvalidEvidence):
                compare_local_and_partner(baseline(),changed)

    def test_unsafe_or_duplicate_remote_catalog_fails(self):
        for bad in ("Other/1234","A space","name\nprivate"):
            changed=baseline()
            changed["catalogNames"][0]=bad
            with self.assertRaises(InvalidEvidence):
                compare_local_and_partner(baseline(),changed)
        changed=baseline();changed["catalogNames"][1]="AcceptRequest"
        with self.assertRaises(InvalidEvidence):
            compare_local_and_partner(baseline(),changed)

    def test_unknown_event_not_in_catalog_is_invalid(self):
        changed=baseline()
        changed["signals"][0]["name"]="OutsideTrade"
        with self.assertRaisesRegex(InvalidEvidence,"unbound"):
            compare_local_and_partner(baseline(),changed)

    def test_payload_or_identity_fields_in_event_rejected(self):
        changed=baseline()
        changed["signals"][0]["partnerId"]="SECRET"
        with self.assertRaisesRegex(InvalidEvidence,"unexpected-raw-payload"):
            compare_local_and_partner(baseline(),changed)

    def test_invalid_event_timestamp_rejected(self):
        for value in (-1,float("inf"),float("nan"),"11.2"):
            changed=baseline();changed["signals"][0]["elapsed"]=value
            with self.assertRaises(InvalidEvidence):
                compare_local_and_partner(baseline(),changed)

    def test_receipt_count_and_catalog_size_limits(self):
        changed=baseline();changed["signalReceipts"]=0
        with self.assertRaises(InvalidEvidence):
            compare_local_and_partner(baseline(),changed)
        changed=baseline();changed["catalogRemoteEvents"]=30
        with self.assertRaises(InvalidEvidence):
            compare_local_and_partner(baseline(),changed)

    def test_no_raw_account_job_or_session_output_fields(self):
        result=compare_local_and_partner(baseline(),baseline())
        names={f.name for f in fields(result)}
        for x in ("partnerId","jobId","accountId","session",
                  "localUserId","itemId","serverResult","profit"):
            self.assertNotIn(x,names)
        self.assertFalse(result.authorizes_accept)

    def test_inverting_trial_labels_changes_no_claim_to_authenticity(self):
        a=baseline()
        b=baseline()
        b["signals"][0]["name"]="EndTrade"
        left=compare_local_and_partner(a,b)
        right=compare_local_and_partner(b,a)
        self.assertEqual(left.status,right.status)
        self.assertFalse(left.initiator_proven)
        self.assertFalse(right.initiator_proven)
        self.assertEqual(left.difference_local_only,right.difference_partner_only)

if __name__=="__main__":
    unittest.main()
