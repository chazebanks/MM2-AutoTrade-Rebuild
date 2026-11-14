"""Offline mutation tests for immutable 189-row user-export adapter.

All fixture prices/identities synthetic: never commit operator price snapshot.
"""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
from unittest import TestCase, mock

from pdiddler.system2 import operator_capture_adapter as a


def fixture():
    registry = {}
    records = []
    for cat,count in a.EXPECTED_COUNTS.items():
        for n in range(count):
            key = f'test_{cat}_{n}'
            if cat=='godlies' and n==0:
                key='BattleAxe'
                name='Battleaxe'; expected='BattleAxe'
                slug='Battleaxe'
            elif cat=='godlies' and n==1:
                key='BattleAxe2'
                name='Battleaxe II'; expected='BattleAxe II'
                slug='BA2'
            else:
                name=('Chroma ' if cat=='chromas' else '')+f'Synthetic {cat} {n}'
                expected=name
                slug=f'Fixture_{cat}_{n}'
            image=f'mm2{cat}/{slug}'
            registry[(cat,image)]={
                'rawGameKeyCandidate':key,
                'expectedName':expected,
                'weaponTypeCandidate':'Gun' if n%2 else 'Knife',
                'rarityCandidate':'Ancient' if cat=='ancients' else 'Godly',
            }
            records.append({
                'category':cat,'image':image,'name':name,
                'valueDisplay':'*5' if (cat=='ancients' and n==0) else '5',
                'decimalValue':5,
                'previousDecimalValue':None if n==0 else 4,
                'rangeLow':4 if (cat=='ancients' and n==0) else 5,
                'rangeHigh':6 if (cat=='ancients' and n==0) else 5,
                'demand':1,'stability':'Stable',
                'observedAt':'2026-11-13T23:54:12.000Z',
            })
    data={
        'schema':a.EXPORT_SCHEMA,'captureScope':'OFFLINE_REVIEW_ONLY',
        'catalogCapturedAt':'2026-11-13T23:24:06.802Z',
        'firstValueCollectedAt':'2026-11-13T23:54:11.551Z',
        'exportedAt':'2026-11-14T00:28:09.127Z',
        'historicalCatalogFingerprint':a.CATALOG_FINGERPRINT,
        'expected':189,'actual':189,'publisherVersion':None,
        'source':a.SOURCE_TEXT,'records':records,
        'authorizesTrade':False,'authorizesOffer':False,
        'authorizesAccept':False,'serverCompletionProven':False,
    }
    return data,registry


def encode(data):
    return json.dumps(data,ensure_ascii=False,separators=(',',':')).encode('utf-8')


class OperatorAdapterTests(TestCase):
    def setUp(self):
        self.obj,self.registry=fixture()

    def run_adapter(self, data=None, raw=None, expected_hash=None):
        raw=encode(self.obj if data is None else data) if raw is None else raw
        sha=hashlib.sha256(raw).hexdigest() if expected_hash is None else expected_hash
        with mock.patch.object(a,'load_historical_registry',return_value=self.registry) as loader:
            result=a.ingest(raw,b'test-fixture',expected_export_sha256=sha)
            loader.assert_called_once_with(b'test-fixture')
            return result

    def reject(self, why, data=None, raw=None, expected_hash=None):
        with self.assertRaisesRegex(ValueError,why):
            self.run_adapter(data=data,raw=raw,expected_hash=expected_hash)

    def test_actual_immutable_stage83_git_source_integration(self):
        """CI loads the ORIGINAL Stage83 Git blob, not reconstructed mappings."""
        path=os.environ.get('GINGERSCOPE_PINNED_STAGE83')
        if not path:
            self.skipTest('set GINGERSCOPE_PINNED_STAGE83 in source-archive CI')
        original=Path(path).read_bytes()
        original_registry=a.load_historical_registry(original)
        self.assertEqual(len(original_registry),189)
        rows=[]
        for (cat,image),item in sorted(original_registry.items()):
            name=item['expectedName']
            if item['rawGameKeyCandidate'] in ('BattleAxe','BattleAxe2'):
                name=name.replace('Axe','axe')
            rows.append({'category':cat,'image':image,'name':name,
                         'valueDisplay':'5','decimalValue':5,
                         'previousDecimalValue':None,'rangeLow':5,
                         'rangeHigh':5,'demand':1,'stability':'Stable',
                         'observedAt':'2026-11-13T23:54:12.000Z'})
        export=fixture()[0]
        export['records']=rows
        raw=encode(export)
        output=a.ingest(raw,original,expected_export_sha256=hashlib.sha256(raw).hexdigest())
        self.assertEqual(output['statistics']['total'],189)
        self.assertEqual(len(output['statistics']['approvedCaseOnlyLabelDrift']),2)
        self.assertEqual(next(x for x in output['records']
                              if x['rawGameKeyCandidate']=='Gingerscope')['image'],
                         'mm2ancients/Gingerscope')
        self.assertFalse(output['authorizesTrade'])

    def test_full_synthetic_mapping_complete_and_offline(self):
        res=self.run_adapter()
        self.assertEqual(res['status'],'OFFLINE_CROSSWALK_READY')
        self.assertEqual(len(res['records']),189)
        self.assertEqual(res['statistics']['byCategory'],a.EXPECTED_COUNTS)
        self.assertEqual(len(res['statistics']['approvedCaseOnlyLabelDrift']),2)
        self.assertEqual(res['publisherVersion'],None)
        self.assertEqual(res['records'][0]['rawGameKeyCandidate'],'BattleAxe')
        self.assertEqual(res['records'][0]['name'],'Battleaxe')
        for k,v in a.AUTHORITY_DENIED.items():
            self.assertEqual(res[k],v,k)

    def test_sha_pin_blocks_change_even_if_self_consistent(self):
        self.reject('OPERATOR_EXPORT_SHA256_MISMATCH',expected_hash='0'*64)

    def test_bad_hash_format(self):
        self.reject('OPERATOR_EXPORT_SHA256_MISMATCH',expected_hash='not-a-sha')

    def test_bad_bytes(self):
        with self.assertRaisesRegex(ValueError,'INVALID_EXPORT_BYTES'):
            a.ingest('not-bytes',b'registry')

    def test_json_duplicate_keys(self):
        raw=encode(self.obj).replace(b'"actual":189',b'"actual":189,"actual":189',1)
        self.reject('JSON_DUPLICATE_KEY',raw=raw)

    def test_nan(self):
        raw=encode(self.obj).replace(b'"demand":1',b'"demand":NaN',1)
        self.reject('NONFINITE_JSON_NUMBER',raw=raw)

    def test_bad_json(self):
        self.reject('INVALID_EXPORT_JSON',raw=b'{')

    def test_export_cannot_claim_trade(self):
        self.obj['authorizesTrade']=True
        self.reject('EXPORT_CONTRACT_REJECTED')

    def test_export_cannot_claim_settlement(self):
        self.obj['serverCompletionProven']=True
        self.reject('EXPORT_CONTRACT_REJECTED')

    def test_unverified_publisher_cannot_be_self_approved(self):
        self.obj['publisherVersion']='2026-11-13'
        self.reject('EXPORT_CONTRACT_REJECTED')

    def test_wrong_fingerprint(self):
        self.obj['historicalCatalogFingerprint']='12341234'
        self.reject('EXPORT_CONTRACT_REJECTED')

    def test_extra_field(self):
        self.obj['records'][0]['fakeLiquidity']=10
        self.reject('INVALID_RECORD_FIELDS')

    def test_duplicate_identity(self):
        self.obj['records'][5]=self.obj['records'][4].copy()
        self.reject('UNKNOWN_OR_DUPLICATE_WEAPON_IDENTITY')

    def test_unknown_website_identity(self):
        self.obj['records'][0]['image']='mm2ancients/UNKNOWN'
        self.reject('UNKNOWN_OR_DUPLICATE_WEAPON_IDENTITY')

    def test_noncase_renamed_label(self):
        self.obj['records'][3]['name']='Changed identity'
        self.reject('UNAUTHORIZED_WEAPON_LABEL_DRIFT')

    def test_case_drift_on_unapproved_weapon(self):
        self.obj['records'][3]['name']=self.obj['records'][3]['name'].lower()
        self.reject('UNAUTHORIZED_WEAPON_LABEL_DRIFT')

    def test_null_previous_is_legitimate(self):
        self.obj['records'][5]['previousDecimalValue']=None
        r=self.run_adapter()
        self.assertEqual(r['statistics']['nullPreviousValue'],4)

    def test_fake_zero_previous_is_not_null(self):
        self.obj['records'][0]['previousDecimalValue']=0
        r=self.run_adapter()
        self.assertEqual(r['statistics']['nullPreviousValue'],2)

    def test_starred_display_preserved(self):
        r=self.run_adapter()
        self.assertEqual(r['statistics']['starredDisplay'],1)
        self.assertEqual([x for x in r['records'] if x['valueDisplay'].startswith('*')][0]['valueDisplay'],'*5')

    def test_display_mismatch(self):
        self.obj['records'][0]['valueDisplay']='*6'
        self.reject('INVALID_SOURCE_VALUE_FIELDS')

    def test_demand_boolean_is_rejected(self):
        self.obj['records'][0]['demand']=True
        self.reject('INVALID_SOURCE_VALUE_FIELDS')

    def test_price_boolean_is_rejected(self):
        self.obj['records'][0]['decimalValue']=True
        self.reject('INVALID_SOURCE_VALUE_FIELDS')

    def test_range_excludes_listed(self):
        self.obj['records'][0]['rangeLow']=6
        self.reject('INVALID_SOURCE_VALUE_FIELDS')

    def test_invalid_date(self):
        self.obj['records'][0]['observedAt']='November 13'
        self.reject('INVALID_UTC_TIMESTAMP')

    def test_observation_after_export(self):
        self.obj['records'][0]['observedAt']='2026-11-14T00:30:00.000Z'
        self.reject('OBSERVATION_OUTSIDE_CAPTURE_WINDOW')

    def test_export_before_capture(self):
        self.obj['exportedAt']='2026-11-13T22:00:00.000Z'
        self.reject('CAPTURE_WINDOW_INVALID')

    def test_bool_expected_count(self):
        self.obj['expected']=True
        self.reject('EXPORT_CONTRACT_REJECTED')

    def test_truncated_records(self):
        self.obj['records'].pop()
        self.obj['actual']=188
        self.reject('EXPORT_CONTRACT_REJECTED')

    def test_unauthorized_label_drift_set(self):
        # Fixed exactly two historical name drifts: no silent shrink of the known discrepancy list.
        for r in self.obj['records']:
            if r['image']=='mm2godlies/Battleaxe':r['name']='BattleAxe'
        self.reject('UNEXPECTED_LABEL_DRIFT_SET')

    def test_output_does_not_fabricate_liquidity_or_profit(self):
        res=self.run_adapter()
        self.assertNotIn('successRate',res)
        self.assertNotIn('profit',res)
        self.assertNotIn('liquidity',res['records'][0])
        self.assertFalse(res['mayFeedStage120AsVerifiedMarket'])

if __name__=='__main__':
    import unittest
    unittest.main()
