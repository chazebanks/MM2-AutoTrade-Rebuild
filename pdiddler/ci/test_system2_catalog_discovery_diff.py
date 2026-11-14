"""Small synthetic input tests for catalog discovery-diff boundary."""
import unittest
from copy import deepcopy
from pdiddler.system2.catalog_discovery_diff import audit,load_historical_registry

REG=b'''["Scythe"] = {"Batwing", "Knife", "Ancient", false, "ancient", "Batwing"},
["EmberbowChroma"] = {"Emberbow", "Gun", "Ancient", true, "chroma", "CEmberbow"},
["BattleAxe"] = {"BattleAxe", "Knife", "Godly", false, "godly", "Battleaxe"},
'''
REGISTRY=load_historical_registry(REG,require_original_pin=False)
def row(cat,name,slug,origin='Known',klass=None):
    return dict(category=cat,name=name,image='mm2'+cat+'/'+slug,origin=origin,aliases=[],**{'class':klass})

def capture():
    rows=[row('ancients','Batwing','Batwing'),
          row('godlies','Battleaxe','Battleaxe'),
          row('chromas','Chroma Emberbow','CEmberbow',klass='Ancient')]
    return dict(schema='gingerscope-full-catalog-discovery-v1',
        status='DISCOVERY_COMPLETE',categories=dict(ancients=1,godlies=1,chromas=1),
        items=rows,errors=[],authorizesTrade=False)

class CatalogDiscoveryTests(unittest.TestCase):
    def test_pin(self):
        with self.assertRaisesRegex(ValueError,'BLOB_MISMATCH'):
            load_historical_registry(REG)
    def test_known_and_case_drift(self):
        r=audit(capture(),REGISTRY)
        self.assertEqual(r['status'],'HISTORICAL_SCOPE_RECONCILED')
        self.assertEqual(r['totals']['nameDrift'],1)
        self.assertTrue(r['nameDrift'][0]['caseOnly'])
        for flag in ('authorizesTrade','authorizesAccept','mayUseForStrategyLearning','currentPricesVerified'):
            self.assertIs(r[flag],False)
    def test_new_weapon_review(self):
        s=capture();s['items'].append(row('ancients','New Axe','New_Axe'));s['categories']['ancients']+=1
        r=audit(s,REGISTRY)
        self.assertEqual(r['status'],'REVIEW_REQUIRED')
        self.assertEqual(r['unreviewedExtra'][0]['image'],'mm2ancients/New_Axe')
    def test_secret_and_pet_extras_are_separate(self):
        s=capture();s['items'].append(row('godlies','Black Luger','Black_Luger','Secret MM2 Item'))
        s['items'].append(row('chromas','Chroma Fire Bat','CBat','Season 1 Pet Egg',klass='Godly'))
        s['categories']['godlies']+=1;s['categories']['chromas']+=1
        r=audit(s,REGISTRY)
        self.assertEqual(r['status'],'HISTORICAL_SCOPE_RECONCILED')
        self.assertEqual(r['totals']['secretLabeledExtra'],1)
        self.assertEqual(r['totals']['petExtra'],1)
    def test_fake_pet_is_not_ignored(self):
        s=capture();s['items'].append(row('chromas','Chroma Fire Dragon','CDragon','Season 1 Pet Egg',klass='Godly'))
        s['categories']['chromas']+=1
        self.assertEqual(audit(s,REGISTRY)['status'],'REVIEW_REQUIRED')
    def test_missing_item(self):
        s=capture();s['items'].pop();s['categories']['chromas']-=1
        self.assertEqual(audit(s,REGISTRY)['totals']['missing'],1)
    def test_duplicate_item(self):
        s=capture();s['items'].append(s['items'][0]);s['categories']['ancients']+=1
        self.assertEqual(audit(s,REGISTRY)['reason'],'DUPLICATE_WEBSITE_IDENTITY')
    def test_counts_forgery(self):
        s=capture();s['categories']['godlies']=2
        self.assertEqual(audit(s,REGISTRY)['reason'],'CATEGORY_COUNTS_DO_NOT_MATCH_ROWS')
    def test_partial_capture(self):
        s=capture();s['status']='INCOMPLETE'
        self.assertEqual(audit(s,REGISTRY)['status'],'BLOCKED')
    def test_unexpected_price_payload(self):
        s=capture();s['items'][0]['decimalValue']=9999
        self.assertEqual(audit(s,REGISTRY)['reason'],'UNEXPECTED_ROW_FIELDS')
    def test_variant_drift(self):
        s=capture();s['items'][2]['class']='Godly'
        r=audit(s,REGISTRY)
        self.assertEqual(r['status'],'REVIEW_REQUIRED')
        self.assertEqual(r['totals']['variantDrift'],1)
    def test_noncase_name_change(self):
        s=capture();s['items'][1]['name']='Totally Different'
        self.assertEqual(audit(s,REGISTRY)['status'],'REVIEW_REQUIRED')
    def test_wrong_image_prefix(self):
        s=capture();s['items'][0]['image']='mm2godlies/Batwing'
        self.assertEqual(audit(s,REGISTRY)['status'],'BLOCKED')
    def test_bool_counter(self):
        s=capture();s['categories']['ancients']=True
        self.assertEqual(audit(s,REGISTRY)['status'],'BLOCKED')
    def test_unhashable_category_is_blocked(self):
        s=capture();s['items'][0]['category']=['ancients']
        self.assertEqual(audit(s,REGISTRY)['status'],'BLOCKED')
    def test_alias_validation(self):
        s=capture();s['items'][0]['aliases']=[123]
        self.assertEqual(audit(s,REGISTRY)['status'],'BLOCKED')

if __name__=='__main__':unittest.main()
