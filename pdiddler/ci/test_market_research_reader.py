"""System2 research-only lookup/portfolio tests, no executor or live account."""
import copy
import json
from pathlib import Path
import unittest
from pdiddler.system2 import market_research_reader as m


def data():
    vals=[('Gingerscope','ancients','Gingerscope',16000,5,'Stable',16000,16000),
          ('Celestial','ancients','Celestial',1950,5,'Stable',1950,1950),
          ('Emberbow','ancients','Emberbow',650,5,'Fluctuating',625,675),
          ('TheSeer','godlies','Seer',3,1,'Stable',3,3),
          ('EmberbowChroma','chromas','CEmberbow',6000,6,'Fluctuating',5750,6250)]
    rows=[]
    for key,cat,slug,value,dem,stab,lo,hi in vals:
        rows.append({'rawGameKeyCandidate':key,'gameItemTypeCandidate':'Gun',
          'gameRarityCandidate':'Ancient' if cat=='ancients' else 'Godly',
          'chromaCandidate':cat=='chromas','category':cat,'image':'mm2'+cat+'/'+slug,
          'name':'Chroma Emberbow' if key=='EmberbowChroma' else ('Seer' if key=='TheSeer' else key),
          'decimalValue':value,'valueDisplay':str(value),'rangeLow':lo,'rangeHigh':hi,
          'previousDecimalValue':None,'demand':dem,'stability':stab,
          'observedAt':'2026-11-13T23:54:11.648Z'})
    for n in range(184):
        cat='godlies'
        rows.append({'rawGameKeyCandidate':f'test_key_{n}',
          'gameItemTypeCandidate':'Knife','gameRarityCandidate':'Godly',
          'chromaCandidate':False,'category':cat,'image':f'mm2godlies/Test_{n}',
          'name':f'Test {n}','decimalValue':n+1,'valueDisplay':str(n+1),
          'rangeLow':n+1,'rangeHigh':n+1,'previousDecimalValue':None,
          'demand':1,'stability':'Stable','observedAt':'2026-11-13T23:54:11.648Z'})
    return {'schema':m.INPUT_SCHEMA,'status':'OFFLINE_CROSSWALK_READY',
      'records':rows,'publisherVersion':None,'sourceExportSha256':m.EXPORT_SHA256,
      **m.AUTHORITY_DENIED}

class ReaderTests(unittest.TestCase):
    def setUp(self):self.d=data()
    def test_exact_lookup(self):
        r=m.lookup_mapped(self.d,'Gingerscope')
        self.assertEqual(r['status'],'RESEARCH_LOOKUP_READY')
        self.assertEqual(r['item']['listedValue'],16000)
        self.assertTrue(r['item']['outgoingProtected'])
        self.assertFalse(r['authorizesOffer'])
    def test_unknown_key(self):
        self.assertEqual(m.lookup_mapped(self.d,'GingerScope')['status'],'BLOCKED')
    def test_nonstring_key(self):
        self.assertEqual(m.lookup_mapped(self.d,1)['status'],'BLOCKED')
    def test_chroma_distinct_key(self):
        r=m.lookup_mapped(self.d,'EmberbowChroma')
        self.assertEqual(r['item']['listedValue'],6000)
        self.assertTrue(r['item']['chromaCandidate'])
    def test_snapshot_is_not_live(self):
        r=m.lookup_mapped(self.d,'Celestial')
        for k,v in m.AUTHORITY_DENIED.items():self.assertEqual(r[k],v)
        self.assertFalse(r['sourceEditionAuthenticated'])
    def test_portfolio_exact_total_and_range(self):
        rows=[{'rawGameKey':'Celestial','quantity':2},{'rawGameKey':'Emberbow','quantity':3}]
        r=m.portfolio_mapped(self.d,rows)
        self.assertEqual(r['totalListedValue'],5850)
        self.assertEqual(r['totalRangeLow'],5775)
        self.assertEqual(r['totalRangeHigh'],5925)
        self.assertEqual(r['listedValueGap'],10150)
        self.assertEqual(r['fourSlotTradeFeasibility'],'UNPROVEN')
        self.assertEqual(r['actualRetradeLiquidity'],'UNKNOWN')
    def test_total_above_target_does_not_authorize_trade(self):
        r=m.portfolio_mapped(self.d,[{'rawGameKey':'Celestial','quantity':9}])
        self.assertTrue(r['listedValueSufficient'])
        self.assertEqual(r['listedValueGap'],0)
        self.assertFalse(r['authorizesTrade'])
    def test_gscope_in_portfolio_stays_protected(self):
        r=m.portfolio_mapped(self.d,[{'rawGameKey':'Gingerscope','quantity':1}])
        self.assertTrue(r['rows'][0]['outgoingProtected'])
        self.assertTrue(r['targetOutgoingProtected'])
    def test_stacked_inventory_not_4_slot_offer(self):
        r=m.portfolio_mapped(self.d,[{'rawGameKey':'TheSeer','quantity':100}])
        self.assertEqual(r['itemCounts']['godlies'],100)
        self.assertEqual(r['fourSlotTradeFeasibility'],'UNPROVEN')
    def test_bad_inventory_shape(self):
        self.assertEqual(m.portfolio_mapped(self.d,[{'rawGameKey':'Celestial'}])['status'],'BLOCKED')
    def test_bool_qty(self):
        self.assertEqual(m.portfolio_mapped(self.d,[{'rawGameKey':'Celestial','quantity':True}])['status'],'BLOCKED')
    def test_zero_quantity(self):
        self.assertEqual(m.portfolio_mapped(self.d,[{'rawGameKey':'Celestial','quantity':0}])['status'],'BLOCKED')
    def test_unknown_portfolio_item(self):
        self.assertEqual(m.portfolio_mapped(self.d,[{'rawGameKey':'Unknown','quantity':1}])['status'],'BLOCKED')
    def test_duplicate_key(self):
        rows=[{'rawGameKey':'Celestial','quantity':1}]*2
        self.assertEqual(m.portfolio_mapped(self.d,rows)['status'],'BLOCKED')
    def test_forged_source_verification(self):
        self.d['verifiedMarketQuote']=True
        self.assertEqual(m.lookup_mapped(self.d,'Celestial')['status'],'BLOCKED')
    def test_unknown_publisher_version(self):
        self.d['publisherVersion']='Fake version'
        self.assertEqual(m.lookup_mapped(self.d,'Celestial')['status'],'BLOCKED')
    def test_modified_record_count(self):
        self.d['records'].pop()
        self.assertEqual(m.lookup_mapped(self.d,'Celestial')['status'],'BLOCKED')
    def test_duplicate_mapped_raw_key(self):
        self.d['records'][5]['rawGameKeyCandidate']='Celestial'
        self.assertEqual(m.lookup_mapped(self.d,'Celestial')['status'],'BLOCKED')
    def test_wrong_target(self):
        self.d['records'][0]['image']='mm2godlies/Gingerscope'
        self.assertEqual(m.lookup_mapped(self.d,'Celestial')['status'],'BLOCKED')
    def test_empty_inventory(self):
        self.assertEqual(m.portfolio_mapped(self.d,[])['status'],'BLOCKED')

if __name__=='__main__':unittest.main()
