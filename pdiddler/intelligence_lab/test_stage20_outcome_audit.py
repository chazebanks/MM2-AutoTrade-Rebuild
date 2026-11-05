"""All Stage 20 tests use synthetic values; no genuine MM2 transfers."""
from __future__ import annotations
from dataclasses import replace
from datetime import datetime, timezone, timedelta
import unittest
from stage20_outcome_audit import (OfferObservation, ClosureObservation,
    InventoryReadback, review_outcome, EvidenceError)

T=datetime(2026,11,5,15,tzinfo=timezone.utc)
A,B,C=('godly:11:checker-id','chroma:12:checker-id','godly:13:checker-id')

def make():
    offer=OfferObservation('main','job-anon','s1','other-anon',T,
                           {A:2},{B:1},True,True,True,True)
    close=ClosureObservation('main','job-anon','s1','other-anon',
                             T+timedelta(seconds=1),'success_ui_claimed')
    def read(sec,seq,items):
        return InventoryReadback('main','job-anon',T+timedelta(seconds=sec),
                                 seq,items,True,'native_claimed')
    pre=read(-1,1,{A:3,C:1})
    post=read(2,2,{A:1,B:1,C:1})
    post2=read(2.5,3,{A:1,B:1,C:1})
    return offer,close,pre,post,post2

class AuditTests(unittest.TestCase):
    def test_consistent_client_report_never_claims_real_trade(self):
        r=review_outcome(*make())
        self.assertEqual(r.status,'CLIENT_CORROBORATED')
        self.assertEqual(dict(r.expected_delta),{A:-2,B:1})
        self.assertEqual(dict(r.observed_delta),{A:-2,B:1})
        self.assertTrue(r.client_evidence_consistent)
        self.assertFalse(r.server_completion_proven)
        self.assertFalse(r.may_record_completed_trade)
        self.assertFalse(r.may_report_profit)
        self.assertFalse(r.authorizes_trade)
        self.assertFalse(r.authorizes_accept)

    def test_closed_window_is_not_proof(self):
        o,c,*s=make()
        self.assertEqual(review_outcome(o,replace(c,status='closed_unknown'),*s).status,'INCOMPLETE')

    def test_decline_is_not_proof(self):
        o,c,*s=make()
        self.assertEqual(review_outcome(o,replace(c,status='declined'),*s).status,'INCOMPLETE')

    def test_only_one_accept_is_not_proof(self):
        o,c,*s=make()
        self.assertEqual(review_outcome(replace(o,their_accepted=False),c,*s).reason,
                         'both-accepted-not-observed')

    def test_unknown_accept_is_not_false_or_true(self):
        o,c,*s=make()
        self.assertEqual(review_outcome(replace(o,our_accepted=None),c,*s).status,'INCOMPLETE')

    def test_wrong_session_is_inconsistent(self):
        o,c,*s=make()
        self.assertEqual(review_outcome(o,replace(c,session='s2'),*s).reason,'session-or-account-mismatch')

    def test_wrong_partner_is_inconsistent(self):
        o,c,*s=make()
        self.assertEqual(review_outcome(o,replace(c,partner='other'),*s).status,'INCONSISTENT')

    def test_alt_inventory_read_cannot_prove_main_trade(self):
        o,c,pre,post,p2=make()
        self.assertEqual(review_outcome(o,c,replace(pre,account='alt'),post,p2).status,'INCONSISTENT')

    def test_wrong_job_after_hop_is_inconsistent(self):
        o,c,pre,post,p2=make()
        self.assertEqual(review_outcome(o,c,pre,replace(post,job='new-job'),p2).status,'INCONSISTENT')

    def test_changed_offer_not_matching_inventory_is_rejected(self):
        o,c,*s=make()
        self.assertEqual(review_outcome(replace(o,our_offer={A:1}),c,*s).reason,
                         'offer-does-not-match-inventory-delta')

    def test_post_scans_must_match(self):
        o,c,pre,post,p2=make()
        self.assertEqual(review_outcome(o,c,pre,replace(post,items={A:2,B:1,C:1}),p2).reason,
                         'two-post-readbacks-disagree')

    def test_stale_before_read_is_not_accepted(self):
        o,c,pre,post,p2=make()
        self.assertEqual(review_outcome(o,c,replace(pre,captured_at=T-timedelta(seconds=31)),
                          post,p2).status,'INCOMPLETE')

    def test_too_close_same_read_is_not_independent(self):
        o,c,pre,post,p2=make()
        self.assertEqual(review_outcome(o,c,pre,post,replace(p2,captured_at=
                          post.captured_at+timedelta(milliseconds=100))).status,'INCOMPLETE')

    def test_repeated_sequence_is_not_distinct_scan(self):
        o,c,pre,post,p2=make()
        self.assertEqual(review_outcome(o,c,pre,post,replace(p2,read_sequence=2)).reason,
                         'distinct-scan-sequences-unverified')

    def test_provisional_screenshots_cannot_replace_native_reads(self):
        o,c,pre,post,p2=make()
        self.assertEqual(review_outcome(o,c,pre,replace(post,source='provisional'),p2).status,'INCOMPLETE')

    def test_missing_inventory_coverage_not_silent_proof(self):
        o,c,pre,post,p2=make()
        self.assertEqual(review_outcome(o,c,pre,post,replace(p2,complete_eligible=False)).status,'INCOMPLETE')

    def test_name_only_laser_identity_rejected(self):
        o,c,*s=make()
        with self.assertRaisesRegex(EvidenceError,'outcome-identity-malformed'):
            review_outcome(replace(o,our_offer={'Laser':1}),c,*s)

    def test_ambiguous_vintage_laser_identity_rejected(self):
        o,c,*s=make()
        with self.assertRaisesRegex(EvidenceError,'outcome-identity-malformed'):
            review_outcome(replace(o,our_offer={'vintage:8:checker-id':1}),c,*s)

    def test_bool_quantity_rejected(self):
        o,c,*s=make()
        with self.assertRaisesRegex(EvidenceError,'outcome-quantity-malformed'):
            review_outcome(replace(o,our_offer={A:True}),c,*s)

    def test_zero_qty_rejected(self):
        o,c,*s=make()
        with self.assertRaisesRegex(EvidenceError,'outcome-quantity-malformed'):
            review_outcome(replace(o,our_offer={A:0}),c,*s)

    def test_timestamps_must_be_zoned(self):
        o,c,*s=make()
        with self.assertRaisesRegex(EvidenceError,'outcome-timestamp-invalid'):
            review_outcome(replace(o,captured_at=T.replace(tzinfo=None)),c,*s)

    def test_missing_offer_fails(self):
        o,c,*s=make()
        self.assertEqual(review_outcome(replace(o,our_offer={}),c,*s).status,'INCOMPLETE')

    def test_same_asset_on_both_sides_fails(self):
        o,c,*s=make()
        self.assertEqual(review_outcome(replace(o,their_offer={A:1}),c,*s).status,'INCOMPLETE')

    def test_fake_client_success_cannot_mint_completion(self):
        o,c,*s=make()
        result=review_outcome(o,c,*s)
        self.assertFalse(result.may_record_completed_trade)
        self.assertFalse(result.server_completion_proven)

if __name__=='__main__':
    unittest.main()
