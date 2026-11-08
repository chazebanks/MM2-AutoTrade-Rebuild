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

    def test_one_sided_receiver_gain_matches_complete_client_readbacks(self):
        # Mirrors the operator's confirmed Iceblaster gift STRUCTURE, with
        # synthetic checker IDs and a synthetic full two-Accept UI record.
        o,c,pre,post,p2=make()
        o=replace(o,our_offer={},their_offer={B:1})
        pre=replace(pre,items={A:3,C:1})
        post=replace(post,items={A:3,B:1,C:1})
        p2=replace(p2,items=post.items)
        r=review_outcome(o,c,pre,post,p2)
        self.assertEqual(r.status,'CLIENT_CORROBORATED')
        self.assertEqual(dict(r.expected_delta),{B:1})
        self.assertEqual(dict(r.observed_delta),{B:1})
        self.assertFalse(r.server_completion_proven)
        self.assertFalse(r.may_record_completed_trade)
        self.assertFalse(r.may_report_profit)
        self.assertFalse(r.authorizes_accept)

    def test_one_sided_sender_loss_matches_client_readbacks(self):
        o,c,pre,post,p2=make()
        o=replace(o,our_offer={A:2},their_offer={})
        post=replace(post,items={A:1,C:1})
        p2=replace(p2,items=post.items)
        r=review_outcome(o,c,pre,post,p2)
        self.assertEqual(r.status,'CLIENT_CORROBORATED')
        self.assertEqual(dict(r.expected_delta),{A:-2})
        self.assertEqual(dict(r.observed_delta),{A:-2})
        self.assertFalse(r.server_completion_proven)

    def test_shared_type_both_sides_net_negative_one_is_reconcilable(self):
        o,c,pre,post,p2=make()
        o=replace(o,our_offer={A:2},their_offer={A:1})
        post=replace(post,items={A:2,C:1})
        p2=replace(p2,items=post.items)
        r=review_outcome(o,c,pre,post,p2)
        self.assertEqual(r.status,'CLIENT_CORROBORATED')
        self.assertEqual(dict(r.expected_delta),{A:-1})
        self.assertEqual(dict(r.observed_delta),{A:-1})
        self.assertFalse(r.may_record_completed_trade)

    def test_shared_type_both_sides_net_positive_one_is_reconcilable(self):
        o,c,pre,post,p2=make()
        o=replace(o,our_offer={A:1},their_offer={A:2})
        post=replace(post,items={A:4,C:1})
        p2=replace(p2,items=post.items)
        r=review_outcome(o,c,pre,post,p2)
        self.assertEqual(r.status,'CLIENT_CORROBORATED')
        self.assertEqual(dict(r.expected_delta),{A:1})
        self.assertEqual(dict(r.observed_delta),{A:1})

    def test_zero_net_shared_type_is_not_inventory_verifiable(self):
        o,c,pre,post,p2=make()
        o=replace(o,our_offer={A:1},their_offer={A:1})
        post=replace(post,items=pre.items)
        p2=replace(p2,items=post.items)
        r=review_outcome(o,c,pre,post,p2)
        self.assertEqual(r.status,'INCOMPLETE')
        self.assertEqual(r.reason,'zero-net-offer-not-inventory-verifiable')
        self.assertFalse(r.client_evidence_consistent)
        self.assertFalse(r.server_completion_proven)

    def test_both_empty_is_not_a_trade(self):
        o,c,pre,post,p2=make()
        o=replace(o,our_offer={},their_offer={})
        post=replace(post,items=pre.items)
        p2=replace(p2,items=post.items)
        r=review_outcome(o,c,pre,post,p2)
        self.assertEqual(r.status,'INCOMPLETE')
        self.assertEqual(r.reason,'offer-unresolved-or-empty')

    def test_one_sided_gain_wrong_inventory_delta_is_rejected(self):
        o,c,pre,post,p2=make()
        o=replace(o,our_offer={},their_offer={B:1})
        post=replace(post,items={A:3,C:1})
        p2=replace(p2,items=post.items)
        r=review_outcome(o,c,pre,post,p2)
        self.assertEqual(r.status,'INCONSISTENT')
        self.assertEqual(r.reason,'offer-does-not-match-inventory-delta')

    def test_one_sided_unrelated_inventory_change_is_rejected(self):
        o,c,pre,post,p2=make()
        o=replace(o,our_offer={},their_offer={B:1})
        post=replace(post,items={A:2,B:1,C:1})
        p2=replace(p2,items=post.items)
        r=review_outcome(o,c,pre,post,p2)
        self.assertEqual(r.status,'INCONSISTENT')
        self.assertEqual(r.reason,'offer-does-not-match-inventory-delta')

    def test_one_sided_unknown_partner_accept_remains_incomplete(self):
        o,c,pre,post,p2=make()
        o=replace(o,our_offer={},their_offer={B:1},their_accepted=None)
        post=replace(post,items={A:3,B:1,C:1})
        p2=replace(p2,items=post.items)
        r=review_outcome(o,c,pre,post,p2)
        self.assertEqual(r.status,'INCOMPLETE')
        self.assertEqual(r.reason,'both-accepted-not-observed')

    def test_one_sided_closed_unknown_remains_incomplete(self):
        o,c,pre,post,p2=make()
        o=replace(o,our_offer={},their_offer={B:1})
        c=replace(c,status='closed_unknown')
        post=replace(post,items={A:3,B:1,C:1})
        p2=replace(p2,items=post.items)
        r=review_outcome(o,c,pre,post,p2)
        self.assertEqual(r.status,'INCOMPLETE')
        self.assertEqual(r.reason,'closure-not-proof-of-completion')

    def test_one_sided_nonindependent_post_scans_rejected(self):
        o,c,pre,post,p2=make()
        o=replace(o,our_offer={},their_offer={B:1})
        post=replace(post,items={A:3,B:1,C:1})
        p2=replace(p2,items=post.items,read_sequence=post.read_sequence)
        r=review_outcome(o,c,pre,post,p2)
        self.assertEqual(r.status,'INCOMPLETE')
        self.assertEqual(r.reason,'distinct-scan-sequences-unverified')

    def test_one_sided_native_incomplete_coverage_rejected(self):
        o,c,pre,post,p2=make()
        o=replace(o,our_offer={},their_offer={B:1})
        post=replace(post,items={A:3,B:1,C:1})
        p2=replace(p2,items=post.items,complete_eligible=False)
        r=review_outcome(o,c,pre,post,p2)
        self.assertEqual(r.status,'INCOMPLETE')
        self.assertEqual(r.reason,'complete-native-readback-unverified')

    def test_500_seeded_one_type_net_delta_scenarios(self):
        import random
        rng=random.Random(471107)
        for n in range(500):
            ours=rng.randint(0,4)
            theirs=rng.randint(0,4)
            o,c,pre,post,p2=make()
            o=replace(o,our_offer={A:ours} if ours else {},
                      their_offer={A:theirs} if theirs else {})
            pre=replace(pre,items={A:8,C:1})
            post_count=8+theirs-ours
            post_items={A:post_count,C:1}
            post=replace(post,items=post_items)
            p2=replace(p2,items=post_items)
            with self.subTest(case=n,ours=ours,theirs=theirs):
                r=review_outcome(o,c,pre,post,p2)
                if ours==0 and theirs==0:
                    self.assertEqual(r.status,'INCOMPLETE')
                elif ours==theirs:
                    self.assertEqual(r.status,'INCOMPLETE')
                    self.assertEqual(r.reason,'zero-net-offer-not-inventory-verifiable')
                else:
                    self.assertEqual(r.status,'CLIENT_CORROBORATED')
                    self.assertEqual(dict(r.expected_delta),{A:theirs-ours})
                    self.assertEqual(dict(r.observed_delta),{A:theirs-ours})
                self.assertFalse(r.server_completion_proven)
                self.assertFalse(r.may_record_completed_trade)
                self.assertFalse(r.may_report_profit)
                self.assertFalse(r.authorizes_trade)
                self.assertFalse(r.authorizes_accept)

    def test_overlap_impossible_outgoing_masked_by_net_gain_is_rejected(self):
        o,c,pre,post,p2=make()
        # Previously CLIENT_CORROBORATED: owns A x1, offers A x3,
        # receives A x4, so the net counts still look like +1.
        o=replace(o,our_offer={A:3},their_offer={A:4})
        pre=replace(pre,items={A:1,C:1})
        post=replace(post,items={A:2,C:1})
        p2=replace(p2,items=post.items)
        r=review_outcome(o,c,pre,post,p2)
        self.assertEqual(r.status,'INCONSISTENT')
        self.assertEqual(r.reason,'outgoing-copies-exceed-pretrade-ownership')
        self.assertEqual(dict(r.expected_delta),{A:1})
        self.assertEqual(dict(r.observed_delta),{A:1})
        self.assertFalse(r.client_evidence_consistent)
        self.assertFalse(r.server_completion_proven)
        self.assertFalse(r.authorizes_accept)

    def test_offer_of_unowned_type_with_matching_net_delta_is_rejected(self):
        o,c,pre,post,p2=make()
        o=replace(o,our_offer={A:1},their_offer={A:2})
        pre=replace(pre,items={C:1})
        post=replace(post,items={A:1,C:1})
        p2=replace(p2,items=post.items)
        r=review_outcome(o,c,pre,post,p2)
        self.assertEqual(r.status,'INCONSISTENT')
        self.assertEqual(r.reason,'outgoing-copies-exceed-pretrade-ownership')

    def test_one_sided_sender_cannot_offer_more_copies_than_owned(self):
        o,c,pre,post,p2=make()
        o=replace(o,our_offer={A:2},their_offer={})
        pre=replace(pre,items={A:1,C:1})
        # The expected A -2 cannot be represented by a valid nonnegative
        # post-inventory readback. Should still fail closed.
        post=replace(post,items={C:1})
        p2=replace(p2,items=post.items)
        r=review_outcome(o,c,pre,post,p2)
        self.assertEqual(r.reason,'outgoing-copies-exceed-pretrade-ownership')
        self.assertFalse(r.may_record_completed_trade)

    def test_exact_outgoing_copy_count_matches_before_stock(self):
        o,c,pre,post,p2=make()
        o=replace(o,our_offer={A:3},their_offer={B:1})
        pre=replace(pre,items={A:3,C:1})
        post=replace(post,items={B:1,C:1})
        p2=replace(p2,items=post.items)
        r=review_outcome(o,c,pre,post,p2)
        self.assertEqual(r.status,'CLIENT_CORROBORATED')
        self.assertFalse(r.server_completion_proven)
        self.assertFalse(r.may_report_profit)

    def test_legitimate_one_sided_receiver_never_requires_owned_incoming(self):
        o,c,pre,post,p2=make()
        o=replace(o,our_offer={},their_offer={B:1})
        pre=replace(pre,items={A:3,C:1})
        post=replace(post,items={A:3,B:1,C:1})
        p2=replace(p2,items=post.items)
        r=review_outcome(o,c,pre,post,p2)
        self.assertEqual(r.status,'CLIENT_CORROBORATED')
        self.assertFalse(r.authorizes_trade)

    def test_impossible_outgoing_and_changed_partner_still_fail_scope_first(self):
        o,c,pre,post,p2=make()
        o=replace(o,our_offer={A:3},their_offer={A:4})
        pre=replace(pre,items={A:1,C:1})
        post=replace(post,items={A:2,C:1})
        p2=replace(p2,items=post.items)
        c=replace(c,partner='unrelated')
        r=review_outcome(o,c,pre,post,p2)
        self.assertEqual(r.reason,'session-or-account-mismatch')

    def test_impossible_outgoing_with_untrusted_inventory_cannot_correlate(self):
        o,c,pre,post,p2=make()
        o=replace(o,our_offer={A:3},their_offer={A:4})
        pre=replace(pre,items={A:1,C:1},complete_eligible=False)
        post=replace(post,items={A:2,C:1})
        p2=replace(p2,items=post.items)
        r=review_outcome(o,c,pre,post,p2)
        self.assertEqual(r.reason,'complete-native-readback-unverified')

    def test_impossible_outgoing_with_conflicting_post_scans_stays_inconsistent(self):
        o,c,pre,post,p2=make()
        o=replace(o,our_offer={A:3},their_offer={A:4})
        pre=replace(pre,items={A:1,C:1})
        post=replace(post,items={A:3,C:1})
        p2=replace(p2,items={A:2,C:1})
        r=review_outcome(o,c,pre,post,p2)
        self.assertEqual(r.reason,'two-post-readbacks-disagree')

    def test_two_outgoing_types_only_one_missing_stock_rejects(self):
        o,c,pre,post,p2=make()
        o=replace(o,our_offer={A:1,B:3},their_offer={B:4})
        pre=replace(pre,items={A:1,B:1,C:1})
        post=replace(post,items={B:2,C:1})
        p2=replace(p2,items=post.items)
        r=review_outcome(o,c,pre,post,p2)
        self.assertEqual(r.reason,'outgoing-copies-exceed-pretrade-ownership')
        self.assertEqual(dict(r.expected_delta),{A:-1,B:1})
        self.assertEqual(dict(r.observed_delta),{A:-1,B:1})

    def test_net_zero_remains_incomplete_regardless_of_impossible_stock(self):
        o,c,pre,post,p2=make()
        o=replace(o,our_offer={A:5},their_offer={A:5})
        pre=replace(pre,items={A:1,C:1})
        post=replace(post,items=pre.items)
        p2=replace(p2,items=post.items)
        r=review_outcome(o,c,pre,post,p2)
        self.assertEqual(r.reason,'zero-net-offer-not-inventory-verifiable')
        self.assertEqual(r.status,'INCOMPLETE')
        self.assertFalse(r.server_completion_proven)

    def test_750_seeded_outgoing_stock_feasibility_cases(self):
        import random
        rng=random.Random(481107)
        counts={'corroborated':0,'impossible':0,'incomplete':0}
        for n in range(750):
            pre_count=rng.randint(1,10)
            ours=rng.randint(0,10)
            # Keep post-count representable without hiding over-offer cases:
            # a partner's incoming copies can mask insufficient PRE holdings.
            theirs=rng.randint(max(0, ours-pre_count),10)
            post_count=pre_count+theirs-ours
            self.assertGreaterEqual(post_count,0)
            o,c,pre,post,p2=make()
            o=replace(o,our_offer={A:ours} if ours else {},
                      their_offer={A:theirs} if theirs else {})
            pre=replace(pre,items={A:pre_count,C:1})
            after={C:1}
            if post_count: after[A]=post_count
            post=replace(post,items=after)
            p2=replace(p2,items=after)
            with self.subTest(seed_case=n,pre=pre_count,ours=ours,theirs=theirs):
                r=review_outcome(o,c,pre,post,p2)
                if ours==theirs:
                    counts['incomplete']+=1
                    self.assertEqual(r.status,'INCOMPLETE')
                elif ours>pre_count:
                    counts['impossible']+=1
                    self.assertEqual(r.status,'INCONSISTENT')
                    self.assertEqual(r.reason,'outgoing-copies-exceed-pretrade-ownership')
                else:
                    counts['corroborated']+=1
                    self.assertEqual(r.status,'CLIENT_CORROBORATED')
                    self.assertEqual(dict(r.expected_delta),{A:theirs-ours})
                    self.assertEqual(dict(r.observed_delta),{A:theirs-ours})
                self.assertFalse(r.server_completion_proven)
                self.assertFalse(r.authorizes_trade)
                self.assertFalse(r.authorizes_accept)
                self.assertFalse(r.may_record_completed_trade)
                self.assertFalse(r.may_report_profit)
        self.assertEqual(sum(counts.values()),750)
        self.assertGreater(counts['impossible'],200)
        self.assertGreater(counts['corroborated'],250)
        self.assertGreater(counts['incomplete'],10)

    def test_fake_client_success_cannot_mint_completion(self):
        o,c,*s=make()
        result=review_outcome(o,c,*s)
        self.assertFalse(result.may_record_completed_trade)
        self.assertFalse(result.server_completion_proven)

if __name__=='__main__':
    unittest.main()
