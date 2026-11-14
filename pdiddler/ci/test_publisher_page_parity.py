"""Offline synthetic tests for three-page publisher parity (no live auth)."""
import copy
from html import escape
import unittest
from unittest import mock
from pdiddler.system2 import publisher_page_parity as p

STAMP='Values Last Updated - November 13th, 2026 at 1:20 PM'

def row(cat,slug,value=30,demand=2,stability='Stable',low=None,high=None,name=None):
    return {'category':cat,'image':f'mm2{cat}/{slug}', 'name':name or slug,
            'decimalValue':value,'demand':demand,'stability':stability,
            'rangeLow':value if low is None else low,'rangeHigh':value if high is None else high}

def source(row):
    rng=(f'{row["rangeLow"]:,} - {row["rangeHigh"]:,}'
         if row['rangeLow']!=row['rangeHigh'] else '[N/A]')
    name=escape(row['name'],quote=True)
    return f'''<div class="itemcolumn" data-value="{row['decimalValue']}" data-demand="{row['demand']}" data-stability="{escape(row['stability'],quote=True)}">
        <div class="itemcell" id="{row['image'].split('/')[-1]}"><table><tr><td>
        <button data-name="{name}" data-image="{row['image']}"></button>
        <div class="itembody">Value - <b class="itemvalue">{row['decimalValue']:,}</b><br>
        Range - <b class="itemrange">{rng}</b><br>
        Stability - <b>{row['stability']}</b><br>Demand - <b>{row['demand']}</b></div>
        </td></tr></table></div></div>'''

def page(cat,rows,stamp=STAMP,extras=()):
    html=f'<html><head><title>Supreme</title></head><body><div>{stamp}</div><section class="grid">'+''.join(source(r) for r in [*rows,*extras])+'</section></body></html>'
    return {'url':p.CANONICAL[cat],'httpStatus':200,'html':html.encode()}

class ParityTests(unittest.TestCase):
    def setUp(self):
        self.items=[row('ancients','Gingerscope',16000,5),
                    row('ancients','Batwing',40,1),
                    row('godlies','Battleaxe',12,1,name='Battleaxe'),
                    row('godlies','Candy',85,2),
                    row('chromas','CEmberscythe',13000,6,'Fluctuating',12000,14000,'Chroma Emberscythe'),
                    row('chromas','CBB',22,1,name='Chroma Boneblade')]
        self.mapped={'sourceExportSha256':'a'*64,'records':self.items,
            'captureWindowUTC':{'firstObservedAt':'2026-11-13T23:54:11.648Z'}}
        self.pages={c:page(c,[x for x in self.items if x['category']==c]) for c in p.CATS}
    def check(self):
        with mock.patch.object(p,'ingest',return_value=self.mapped):
            return p.attest(b'export',b'registry',self.pages)
    def test_full_positive(self):
        r=self.check()
        self.assertEqual(r['status'],'RESEARCH_PARITY_CORROBORATED')
        self.assertEqual(r['websiteMatchedRows'],6)
        self.assertEqual(r['confirmedPublisherUtc'],'2026-11-13T18:20:00Z')
        self.assertTrue(r['sourcePageParity'])
        self.assertIs(r['publishedCurrentPriceAuthenticated'],False)
        self.assertIs(r['mayFeedStage120AsVerifiedMarket'],False)
    def test_large_189_synthetic(self):
        self.items=[row(cat,'Fixture_'+str(i),30+i) for cat,qty in [('ancients',15),('godlies',128),('chromas',46)] for i in range(qty)]
        self.mapped['records']=self.items
        self.pages={c:page(c,[x for x in self.items if x['category']==c]) for c in p.CATS}
        r=self.check()
        self.assertEqual(r['websiteMatchedRows'],189)
        self.assertEqual([x['publishedItemMatches'] for x in r['pages']],[15,128,46])
    def test_allowed_known_secrets_pets(self):
        self.pages['godlies']=page('godlies',[x for x in self.items if x['category']=='godlies'],extras=[row('godlies','Black_Luger',10)])
        self.pages['chromas']=page('chromas',[x for x in self.items if x['category']=='chromas'],extras=[row('chromas','CBat',10)])
        r=self.check();self.assertEqual(r['status'],'RESEARCH_PARITY_CORROBORATED')
        self.assertEqual(len(r['pages'][1]['excludedKnownItems']),1)
        self.assertEqual(len(r['pages'][2]['excludedKnownItems']),1)
    def test_missing_canonical_category(self):
        del self.pages['godlies'];self.assertEqual(self.check()['reason'],'THREE_CANONICAL_PAGES_REQUIRED')
    def test_category_source_url_poison(self):
        self.pages['godlies']['url']='https://example.com/godlies'
        self.assertIn('INVALID_CANONICAL_PAGE_RECEIPT',self.check()['reason'])
    def test_http_status_poison(self):
        self.pages['godlies']['httpStatus']=429
        self.assertIn('INVALID_CANONICAL_PAGE_RECEIPT',self.check()['reason'])
    def test_timestamp_missing(self):
        self.pages['godlies']=page('godlies',[x for x in self.items if x['category']=='godlies'],stamp='No timestamp')
        self.assertEqual(self.check()['reason'],'PUBLISHER_TIMESTAMP_NOT_UNIQUE')
    def test_timestamp_disagreement(self):
        self.pages['godlies']=page('godlies',[x for x in self.items if x['category']=='godlies'],stamp='Values Last Updated - November 12th, 2026 at 1:20 PM')
        self.assertEqual(self.check()['reason'],'PUBLISHER_TIMESTAMPS_DISAGREE')
    def test_publisher_postdates_capture(self):
        self.pages={c:page(c,[x for x in self.items if x['category']==c],stamp='Values Last Updated - November 14th, 2026 at 1:20 PM') for c in p.CATS}
        self.assertEqual(self.check()['reason'],'PUBLISHER_VERSION_POSTDATES_OPERATOR_CAPTURE')
    def test_value_mismatch(self):
        self.items[0]['decimalValue']+=1
        self.assertIn('PUBLISHED_ITEM_MISMATCH',self.check()['reason'])
    def test_demand_mismatch(self):
        self.items[0]['demand']+=1
        self.assertIn('PUBLISHED_ITEM_MISMATCH',self.check()['reason'])
    def test_stability_mismatch(self):
        self.items[0]['stability']='Fluctuating'
        self.assertIn('PUBLISHED_ITEM_MISMATCH',self.check()['reason'])
    def test_range_mismatch(self):
        self.items[4]['rangeHigh']=14500
        self.assertIn('PUBLISHED_ITEM_MISMATCH',self.check()['reason'])
    def test_extra_unknown_weapon(self):
        self.pages['godlies']=page('godlies',[x for x in self.items if x['category']=='godlies'],extras=[row('godlies','New_Weapon',30)])
        self.assertIn('UNKNOWN_PUBLISHED_WEAPON',self.check()['reason'])
    def test_missing_weapon(self):
        self.pages['godlies']=page('godlies',[x for x in self.items if x['category']=='godlies'][:1])
        self.assertEqual(self.check()['reason'],'PUBLISHED_COVERAGE_INCOMPLETE')
    def test_duplicate_weapon(self):
        self.pages['godlies']=page('godlies',[x for x in self.items if x['category']=='godlies']*2)
        self.assertIn('DUPLICATE_PUBLISHED_IMAGE',self.check()['reason'])
    def test_wrong_name(self):
        self.items[0]['name']='Alien Gun'
        self.assertIn('PUBLISHED_NAME_DRIFT',self.check()['reason'])
    def test_nonnumeric_value(self):
        b=self.pages['ancients']['html'];self.pages['ancients']['html']=b.replace(b'data-value="16000"',b'data-value="INVALID"')
        self.assertIn('MISSING_PUBLISHED_METRICS',self.check()['reason'])
    def test_wrong_category_image(self):
        b=self.pages['ancients']['html'];self.pages['ancients']['html']=b.replace(b'mm2ancients/Gingerscope',b'mm2godlies/Gingerscope')
        self.assertIn('CATEGORY_IMAGE_CONFLICT',self.check()['reason'])
    def test_duplicate_timestamp(self):
        b=self.pages['ancients']['html'];self.pages['ancients']['html']=b.replace(b'</body>',STAMP.encode()+b'</body>')
        self.assertEqual(self.check()['reason'],'PUBLISHER_TIMESTAMP_NOT_UNIQUE')
    def test_invalid_page_bytes(self):
        self.pages['godlies']['html']='notbytes'
        self.assertIn('INVALID_CANONICAL_PAGE_RECEIPT',self.check()['reason'])

if __name__=='__main__':unittest.main()
