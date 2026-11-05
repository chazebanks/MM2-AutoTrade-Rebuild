"""Synthetic contract tests; never claim that test fixtures prove live MM2 identity."""
import copy
import json
import unittest
from pathlib import Path
from datetime import datetime,timezone
from raw_inventory_intake import RawInventoryError,parse_raw_export,reconcile_scanner_output
from market_bridge import load_market

HERE=Path(__file__).parent
FIXTURE={"format":"pdiddler-raw-inventory-v1","source":"GetProfileData","items":[
    {"id":"WatergunChroma","qty":1},{"id":"BaubleKnife","qty":1},
    {"id":"Immortal","qty":2},{"id":"Brew_K_2026","qty":18}]}
NOW=datetime(2026,11,5,13,53,10,tzinfo=timezone.utc)

class IntakeTests(unittest.TestCase):
    def setUp(self):
        self.raw=parse_raw_export(FIXTURE)
        self.market=load_market(json.loads((HERE/'market_excerpt_fixture.json').read_text()),NOW)
    def test_counts_and_preserves_internal_ids(self):
        self.assertEqual((self.raw.distinct_count,self.raw.total_copies),(4,22))
        self.assertEqual(self.raw.owned['BaubleKnife'],1)
        self.assertFalse(self.raw.checker_ids_verified)
    def test_rejects_duplicates(self):
        r=copy.deepcopy(FIXTURE);r['items'].append(dict(r['items'][0]))
        with self.assertRaisesRegex(RawInventoryError,'duplicate-internal-id'):parse_raw_export(r)
    def test_rejects_bad_quantity(self):
        for bad in (0,-1,1.5,True,"3"):
            r=copy.deepcopy(FIXTURE);r['items'][0]['qty']=bad
            with self.assertRaisesRegex(RawInventoryError,'invalid-quantity'):parse_raw_export(r)
    def test_rejects_unknown_format_and_source(self):
        for fld,val in (("format","v99"),("source","screenshot")):
            r=copy.deepcopy(FIXTURE);r[fld]=val
            with self.assertRaisesRegex(RawInventoryError,'unknown-export'):parse_raw_export(r)
    def test_rejects_empty_and_bad_ids(self):
        r=copy.deepcopy(FIXTURE);r['items']=[]
        with self.assertRaisesRegex(RawInventoryError,'empty'):parse_raw_export(r)
        r=copy.deepcopy(FIXTURE);r['items'][0]['id']=' '
        with self.assertRaisesRegex(RawInventoryError,'invalid-internal-id'):parse_raw_export(r)
    def test_scanner_reconciliation_makes_exact_match(self):
        r={'format':'pdiddler-scanner-observation-v1','items':[dict(id='WatergunChroma',qty=1,checkerId='810',page='chroma',name='Chroma Watergun',type='Gun',cat='Weapons')]}
        got=reconcile_scanner_output(self.raw,r,self.market)
        self.assertEqual(got[0].checker_key,'chroma:810:checker-id')
        self.assertEqual(got[0].reason,'consistent-scanner-catalogue-match')
    def test_scanner_requires_real_checker_id(self):
        r={'format':'pdiddler-scanner-observation-v1','items':[dict(id='WatergunChroma',qty=1,checkerId='WatergunChroma',page='chroma',name='Chroma Watergun',type='Gun',cat='Weapons')]}
        got=reconcile_scanner_output(self.raw,r,self.market)
        self.assertIsNone(got[0].checker_key)
        self.assertEqual(got[0].reason,'unknown-checker-identity')
    def test_ambiguous_baubleknife_does_not_automatically_map(self):
        r={'format':'pdiddler-scanner-observation-v1','items':[dict(id='BaubleKnife',qty=1,checkerId='unknown',page='godly',name='Ornament',type='Knife',cat='Weapons')]}
        got=reconcile_scanner_output(self.raw,r,self.market)
        self.assertIsNone(got[0].checker_key)
    def test_scanner_must_match_native_owned_quantities(self):
        r={'format':'pdiddler-scanner-observation-v1','items':[dict(id='Immortal',qty=1,checkerId='1032',page='godly',name='Immortal',type='Gun',cat='Weapons')]}
        got=reconcile_scanner_output(self.raw,r,self.market)
        self.assertEqual(got[0].reason,'scanner-raw-quantity-mismatch')
    def test_scanner_rejects_fake_contract_and_duplicates(self):
        r={'format':'loose-guess','items':[]}
        with self.assertRaisesRegex(RawInventoryError,'contract-unverified'):reconcile_scanner_output(self.raw,r,self.market)
        r={'format':'pdiddler-scanner-observation-v1','items':[{'id':'X','qty':1}]*2}
        with self.assertRaisesRegex(RawInventoryError,'duplicate'):reconcile_scanner_output(self.raw,r,self.market)
    def test_scanner_rejects_duplicate_checker_identity(self):
        r={'format':'pdiddler-scanner-observation-v1','items':[
            dict(id='WatergunChroma',qty=1,checkerId='810',page='chroma',name='Chroma Watergun',type='Gun',cat='Weapons'),
            dict(id='BaubleKnife',qty=1,checkerId='810',page='chroma',name='Chroma Watergun',type='Knife',cat='Weapons'),
        ]}
        with self.assertRaisesRegex(RawInventoryError,'duplicate-mapped-checker-identity'):
            reconcile_scanner_output(self.raw,r,self.market)
    def test_scanner_price_mismatch_not_used(self):
        r={'format':'pdiddler-scanner-observation-v1','items':[
            dict(id='WatergunChroma',qty=1,checkerId='810',page='chroma',name='Chroma Watergun',value=1800,type='Gun',cat='Weapons')]}
        got=reconcile_scanner_output(self.raw,r,self.market)
        self.assertEqual(got[0].reason,'scanner-price-disagrees-with-catalogue')
    def test_scanner_rejects_display_name_collision(self):
        r={'format':'pdiddler-scanner-observation-v1','items':[dict(id='WatergunChroma',qty=1,checkerId='810',page='chroma',name='Watergun',type='Gun',cat='Weapons')]}
        got=reconcile_scanner_output(self.raw,r,self.market)
        self.assertEqual(got[0].reason,'checker-name-mismatch')
if __name__=='__main__':unittest.main()
