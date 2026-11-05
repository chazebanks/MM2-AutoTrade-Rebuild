"""Stage 6 synthetic contract tests. These do NOT prove real scan recency."""
from __future__ import annotations
from datetime import datetime, timezone, timedelta
from pathlib import Path
from decimal import Decimal
import copy, json, unittest

from evaluator import AssessmentError
from market_bridge import load_market
from opponent_observation import parse_opponent_cache, compare_observed_opponent

HERE=Path(__file__).parent
NOW=datetime(2026,11,5,13,53,10,tzinfo=timezone.utc)

def mkmarket():
    return load_market(json.loads((HERE/'market_excerpt_fixture.json').read_text()),NOW)

def scenario(market):
    return {
        'format':'pdiddler-opponent-cache-v1','source':'scanner-record-cache',
        'marketVersion':market.source_version,'marketFresh':True,
        'snapshotAtEpoch':int((NOW-timedelta(seconds=15)).timestamp()),
        'cacheFreshnessProven':False,'totalTargets':1,
        'targets':[{
            'label':'P1','state':'whitelist','present':True,'scanning':False,'retryScheduled':False,
            'fingerprint':'synthetic-raw-fingerprint','rawOwned':4,
            'unmapped':0,'unpriced':0,'badQty':0,
            'items':[{'id':'example-immortal','checkerId':'1032','page':'godly','name':'Immortal',
                      'type':'Gun','cat':'Weapons','qty':1,'value':140}]
        }]
    }

class OpponentCacheTests(unittest.TestCase):
    def setUp(self):
        self.market=mkmarket()
        self.example=scenario(self.market)
    def get(self,blob=None,now=NOW):
        return parse_opponent_cache(blob if blob is not None else self.example,self.market,now)
    def test_cached_whitelist_identity_and_raw_price_drift(self):
        got=self.get();self.assertEqual(len(got.opponents),1)
        x=got.opponents[0]
        self.assertTrue(x.suitable_for_offline_review)
        self.assertEqual(x.observed_holdings,{'godly:1032:checker-id':1})
        self.assertEqual(x.raw_price_drift,(('godly:1032:checker-id','140','135'),))
        self.assertFalse(x.authorizes_live_trade)
        self.assertFalse(got.authorizes_live_trade)
        self.assertFalse(got.scan_age_known)
    def test_replay_offline_growth_with_observed_target(self):
        own={'godly:481:checker-id':3,'godly:448:checker-id':1}
        x=self.get().opponents[0]
        result=compare_observed_opponent(own,x,self.market,NOW)
        self.assertTrue(result.wealth_candidates)
        self.assertEqual(result.policy,'offline-human-review-only')
    def test_any_coverage_or_scan_uncertainty_holds_target(self):
        for field,value in [('state','unknown'),('present',False),('scanning',True),
                            ('retryScheduled',True),('fingerprint',''),('unmapped',1),
                            ('unpriced',1),('badQty',1),('rawOwned',None)]:
            with self.subTest(field=field):
                b=copy.deepcopy(self.example);b['targets'][0][field]=value
                x=self.get(b).opponents[0]
                self.assertFalse(x.suitable_for_offline_review)
                with self.assertRaisesRegex(AssessmentError,'not-usable'):
                    compare_observed_opponent({'godly:27:checker-id':1},x,self.market,NOW)
    def test_empty_and_no_record_not_viewable(self):
        b=copy.deepcopy(self.example);b['targets'][0].update(state='missing',rawOwned=None,items=[])
        x=self.get(b).opponents[0]
        self.assertFalse(x.suitable_for_offline_review)
        self.assertIn('no-verified-priced-items',x.issues)
    def test_bad_checker_or_name_never_falls_back_to_name_only(self):
        for field,value in [('checkerId','Immortal'),('page','chroma'),('name','Mortal'),
                            ('type','Pet'),('cat','Pets')]:
            with self.subTest(field=field):
                b=copy.deepcopy(self.example);b['targets'][0]['items'][0][field]=value
                x=self.get(b).opponents[0];self.assertFalse(x.suitable_for_offline_review)
                self.assertEqual(x.observed_holdings,{})
    def test_numeric_price_drift_not_identity_failure(self):
        b=copy.deepcopy(self.example);b['targets'][0]['items'][0]['value']=130
        x=self.get(b).opponents[0]
        self.assertTrue(x.suitable_for_offline_review)
        self.assertEqual(x.raw_price_drift[0][2],'135')
    def test_bad_scanner_price_blocks_review(self):
        b=copy.deepcopy(self.example);b['targets'][0]['items'][0]['value']='inf'
        self.assertFalse(self.get(b).opponents[0].suitable_for_offline_review)
    def test_missing_and_duplicate_identity_rejected(self):
        b=copy.deepcopy(self.example);b['targets'][0]['items'].append(copy.deepcopy(b['targets'][0]['items'][0]))
        with self.assertRaisesRegex(AssessmentError,'duplicate-or-missing'):
            self.get(b)
        b=copy.deepcopy(self.example);b['targets'].append(copy.deepcopy(b['targets'][0]));b['totalTargets']=2
        with self.assertRaisesRegex(AssessmentError,'duplicate-opponent-label'):
            self.get(b)
    def test_quantity_invariants_and_upper_bound(self):
        for bad in (0,-1,True,1.1,'2'):
            with self.subTest(bad=bad):
                b=copy.deepcopy(self.example);b['targets'][0]['items'][0]['qty']=bad
                with self.assertRaisesRegex(AssessmentError,'invalid-opponent-quantity'):
                    self.get(b)
        b=copy.deepcopy(self.example);b['targets'][0]['rawOwned']=0
        self.assertIn('priced-copies-exceed-raw-owned-count',self.get(b).opponents[0].issues)
    def test_age_and_price_freshness_gated(self):
        b=copy.deepcopy(self.example);b['snapshotAtEpoch']=int((NOW-timedelta(minutes=3)).timestamp())
        with self.assertRaisesRegex(AssessmentError,'too-old'):
            self.get(b)
        b=copy.deepcopy(self.example);b['marketFresh']=False
        with self.assertRaisesRegex(AssessmentError,'market-not-verified'):
            self.get(b)
        with self.assertRaisesRegex(AssessmentError,'price-snapshot-not-valid'):
            self.get(now=NOW+timedelta(days=2))
    def test_unknown_or_lying_source_fails_closed(self):
        for field,value in [('source','remote-actual'),('format','v2'),('cacheFreshnessProven',True),
                            ('marketVersion','supreme-fake')]:
            with self.subTest(field=field):
                b=copy.deepcopy(self.example);b[field]=value
                with self.assertRaises(AssessmentError):self.get(b)
    def test_multi_target_isolation_and_no_user_identity(self):
        b=copy.deepcopy(self.example)
        other=copy.deepcopy(b['targets'][0]);other['label']='P2';other['state']='unknown'
        b['targets'].append(other);b['totalTargets']=2
        r=self.get(b)
        self.assertTrue(r.opponents[0].suitable_for_offline_review)
        self.assertFalse(r.opponents[1].suitable_for_offline_review)
        self.assertNotIn('UserId',repr(r))
    def test_lua_exporter_never_exercises_trade_remote_or_claims_scan_age(self):
        code=(HERE/'EXPORT_OPPONENT_CACHE_READONLY.lua').read_text()
        for forbidden in ('InvokeServer(', 'FireServer(', 'queue_on_teleport', 'SendMouseButtonEvent'):
            self.assertNotIn(forbidden,code)
        self.assertIn('cacheFreshnessProven=false',code)
        self.assertIn('getVerificationState',code)

if __name__=='__main__':unittest.main()
