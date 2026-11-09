"""Actual pure-Python Stage76 research guard tests, no Roblox execution."""
import copy
import importlib.util
import random
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / 'intelligence_lab' / 'stage76_first_party_slug_audit.py'
spec = importlib.util.spec_from_file_location('stage76', SCRIPT)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

def fixtures():
    client, market = [], []
    for raw, (name, kind, rarity, chroma, page, slug, market_name) in m.CASES.items():
        client.append({'rawKey': raw, 'ItemName': name, 'ItemType': kind,
                       'Rarity': rarity, 'Chroma': chroma})
        item = {'rawKey': raw, 'url': m._site_url(page, slug),
                'headline': f'MM2 {market_name} Value & More',
                'sourceName': market_name, 'pageCategory': page}
        if page == 'chromas':
            item['baseClass'] = rarity
        market.append(item)
    return client, market

class Stage76Tests(unittest.TestCase):
    def setUp(self):
        self.client, self.market = fixtures()

    def check_closed(self, report):
        self.assertFalse(report['authorizesTrade'])
        self.assertFalse(report['authorizesAccept'])
        self.assertFalse(report['mayUseForStrategyLearning'])
        self.assertFalse(report['mayReportProfit'])
        self.assertFalse(report['currentPricesVerified'])
        self.assertFalse(report['numericSupremeCheckerIdVerified'])
        self.assertFalse(report['authenticatedOwnedInventory'])

    def test_all_four_strict_public_contracts(self):
        r = m.audit(self.client, self.market)
        self.assertEqual(r['status'], 'PUBLIC_NAME_AND_SLUG_CORRESPONDENCE_ONLY')
        self.assertEqual(r['matched'], 4)
        self.assertEqual(r['websiteSlugDiffersFromGameRawKey'], 3)
        self.assertEqual(r['marketNameCaseDiffersFromClient'], 2)
        self.check_closed(r)

    def test_nonidentical_slug_namespaces(self):
        by_key = {p['rawKey']: p['url'] for p in self.market}
        self.assertIn('item=BA2', by_key['BattleAxe2'])
        self.assertIn('item=CEmberscythe', by_key['EmberscytheChroma'])
        self.assertNotIn('item=BattleAxe2', by_key['BattleAxe2'])

    def test_all_metadata_mutations_rejected(self):
        for row in range(4):
            for field, evil in [('ItemName','Other'), ('ItemType','Gun' if row != 0 else 'Knife'),
                                ('Rarity','Legendary'), ('Chroma',1), ('Chroma',None)]:
                cc=copy.deepcopy(self.client)
                cc[row][field]=evil
                out=m.audit(cc,self.market)
                self.assertEqual(out['status'],'INCONCLUSIVE', (row,field))
                self.check_closed(out)

    def test_all_page_identity_mutations_rejected(self):
        for row in range(4):
            for field, evil in [('url','https://evil.example/mm2/ancients?item=Gingerscope'),
                                ('url',self.market[row]['url']+'&item=dup'),
                                ('url',self.market[row]['url']+'#fragment'),
                                ('headline','MM2 Different Value & More'),
                                ('sourceName','Different'),
                                ('pageCategory','wrong')]:
                pp=copy.deepcopy(self.market)
                pp[row][field]=evil
                out=m.audit(self.client,pp)
                self.assertEqual(out['status'],'INCONCLUSIVE',(row,field))
                self.check_closed(out)

    def test_raw_key_duplicates_missing_and_unexpected(self):
        for group in ('client','market'):
            a,b=copy.deepcopy(self.client),copy.deepcopy(self.market)
            gg=a if group=='client' else b
            gg[1]['rawKey']=gg[0]['rawKey']
            self.assertEqual(m.audit(a,b)['status'],'INCONCLUSIVE')
            a,b=copy.deepcopy(self.client),copy.deepcopy(self.market)
            (a if group=='client' else b).pop()
            self.assertEqual(m.audit(a,b)['status'],'INCONCLUSIVE')

    def test_ancient_chroma_is_not_godly(self):
        pp=copy.deepcopy(self.market)
        pp[1]['baseClass']='Godly'
        self.assertEqual(m.audit(self.client,pp)['reason'],'CHROMA_BASE_CLASS_MISMATCH')
        self.assertEqual(m.audit(self.client,self.market)['matched'],4)

    def test_no_fuzzy_alias_or_extra_query(self):
        for evil in ('https://supremevalues.com/mm2/godlies?item=BattleAxe2',
                     'http://supremevalues.com/mm2/godlies?item=BA2',
                     'https://supremevalues.com/mm2/godlies?item=BA2%20',
                     'https://supremevalues.com/mm2/godlies?item=BA2&other=1',
                     'https://supremevalues.com.evil.example/mm2/godlies?item=BA2'):
            pp=copy.deepcopy(self.market)
            pp[3]['url']=evil
            self.assertEqual(m.audit(self.client,pp)['status'],'INCONCLUSIVE')

    def test_shuffle_order_irrelevant(self):
        rng=random.Random(76)
        for _ in range(100):
            aa,bb=copy.deepcopy(self.client),copy.deepcopy(self.market)
            rng.shuffle(aa);rng.shuffle(bb)
            self.assertEqual(m.audit(aa,bb)['matched'],4)

    def test_seeded_corruption_does_not_promote_evidence(self):
        rng=random.Random(7601)
        for i in range(400):
            aa,bb=copy.deepcopy(self.client),copy.deepcopy(self.market)
            idx=rng.randrange(4)
            if i%4==0:
                aa[idx]['Rarity']='Rare'
            elif i%4==1:
                bb[idx]['url']+='&fake='+str(i)
            elif i%4==2:
                bb[idx]['sourceName']='Not '+bb[idx]['sourceName']
            else:
                aa[idx]['Chroma'] = not aa[idx]['Chroma']
            rr=m.audit(aa,bb)
            self.assertEqual(rr['status'],'INCONCLUSIVE',i)
            self.check_closed(rr)

if __name__ == '__main__':
    unittest.main()
