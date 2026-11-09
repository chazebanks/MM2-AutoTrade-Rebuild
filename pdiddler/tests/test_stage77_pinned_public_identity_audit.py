"""Stage77 isolated source-bound regression; dedicated CI REQUIRES actual Git-blob fixtures."""
from __future__ import annotations

import importlib.util
import os
from pathlib import Path
import random
import unittest
from unittest.mock import patch

MODULE = Path(__file__).resolve().parents[1] / 'intelligence_lab' / 'stage77_pinned_public_identity_audit.py'
spec = importlib.util.spec_from_file_location('stage77', MODULE)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

def synthetic():
    # Complete 1,040-record Lua catalogue with four independently reviewed targets.
    rows = []
    for key, (_, _, name, kind, rarity, chroma, _) in m.TARGETS.items():
        rows.append((key, dict(ItemName=name, ItemType=kind, Rarity=rarity, Chroma=chroma)))
    for i in range(1036):
        rows.append((f'UnusedItem{i}', {'ItemName': f'Unused Item {i}',
                                        'ItemType': 'Knife', 'Rarity': 'Common', 'Chroma': False}))
    def val(v):
        if isinstance(v, bool):
            return str(v).lower()
        return '"' + v + '"'
    game = (''.join('  ["'+key+'"] = {\n'+''.join(f'    ["{name}"] = {val(value)},\n' for name,value in fields.items())+'  },\n' for key,fields in rows)).encode()
    html = {}
    for page,title in [('ancients','Ancient'),('godlies','Godly'),('chromas','Chroma')]:
        snippets=[]
        for key,(p,slug,name,kind,rarity,chroma,marketname) in m.TARGETS.items():
            if p != page:
                continue
            class_info = f'Class - <b>{rarity}</b><br>' if page == 'chromas' else ''
            snippets.append(f'<div class="itemcolumn"><div class="itemcell" id="{slug}">'
                f'<button data-name="{marketname}"></button>'
                f'<div class="itemhead"><a class="itemlink" href="https://supremevalues.com/mm2/{page}?item={slug}">{marketname}</a></div>'
                f'<div class="itembody">{class_info} Value - <b>12</b></div>'
                '</div></div>')
        html[page] = (f'<html><head><title>MM2 {title} Values - Supreme Values</title>'
             f'</head><body><div data-updated-iso="2026-11-06T10:56:07-05:00"></div>'
             + ''.join(snippets) + '</body></html>').encode()
    return game, html

class Stage77(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.game,cls.web = synthetic()

    def strict(self,r):
        for key in ('authenticatedOwnedInventory','serverAttestation',
                    'numericSupremeCheckerIdVerified','sourcePublisherFresh','currentPricesVerified',
                    'authorizesTrade','authorizesAccept','mayReportProfit','maySendDiscordWebhook',
                    'mayUseForStrategyLearning','mayRecordCompletedTrade'):
            self.assertIs(r[key], False, key)

    def synthetic_result(self, g=None, w=None):
        g = g if g is not None else self.game
        w = w if w is not None else self.web
        with patch.object(m,'GAME_BLOB',m.git_blob_sha(g)),patch.object(m,'SITE_BLOBS',{p:m.git_blob_sha(x) for p,x in w.items()}):
            return m.run(g,w)

    def test_synthetic_four_match_and_no_trade(self):
        out=self.synthetic_result()
        self.assertEqual(out['status'],'PINNED_PUBLIC_SOURCES_CORRESPOND_ONLY',out)
        self.assertEqual(out['corroboratedPublicKeyNames'],4)
        self.assertEqual(out['distinctWebsiteSlugs'],3)
        self.assertEqual(out['gamePublicRows'],1040)
        self.strict(out)

    def test_detect_unmodified_game_blob_required(self):
        g=bytearray(self.game);g[30]^=1
        r=m.run(bytes(g),self.web)
        self.assertEqual(r['reason'],'PINNED_GAME_PUBLIC_BLOB_MISMATCH')
        self.strict(r)

    def test_detect_unmodified_website_blobs_required(self):
        for p in m.SITE_BLOBS:
            modified=dict(self.web)
            modified[p]+=b'\n'
            with patch.object(m,'GAME_BLOB',m.git_blob_sha(self.game)),patch.object(m,'SITE_BLOBS',{s:m.git_blob_sha(t) for s,t in self.web.items()}):
                res=m.run(self.game,modified)
            self.assertEqual(res['reason'],'PINNED_FIRST_PARTY_HTML_BLOB_MISMATCH')
            self.strict(res)

    def test_game_parser_duplicate_and_wrong_row_count(self):
        self.assertEqual(len(m.game_rows(self.game)),1040)
        with self.assertRaises(ValueError):m.game_rows(self.game+b'  ["Gingerscope"] = {\n  },\n')
        with self.assertRaises(ValueError):m.game_rows(b'not a catalogue')

    def test_first_party_source_parses_exact_links(self):
        out=m.website_records(self.web['godlies'],'godlies')
        self.assertEqual(out['BA2'],('Battleaxe II','Godly'))
        self.assertEqual(out['Battleaxe'],('Battleaxe','Godly'))
        self.assertEqual(m.website_records(self.web['chromas'],'chromas')['CEmberscythe'],('Chroma Emberscythe','Ancient'))

    def test_reject_unreviewed_site_change_even_if_rehashed(self):
        w=dict(self.web)
        w['godlies']=w['godlies'].replace(b'item=BA2',b'item=BattleAxe2')
        r=self.synthetic_result(w=w)
        self.assertEqual(r['status'],'INCONCLUSIVE',r)
        self.strict(r)

    def test_reject_wrong_chroma_base_class_even_if_rehashed(self):
        w=dict(self.web)
        w['chromas']=w['chromas'].replace(b'Class - <b>Ancient</b>',b'Class - <b>Godly</b>')
        r=self.synthetic_result(w=w)
        self.assertEqual(r['status'],'INCONCLUSIVE',r)
        self.strict(r)

    def test_reject_public_game_variant_change_even_if_rehashed(self):
        g=self.game.replace(b'["EmberscytheChroma"] = {\n    ["ItemName"] = "Emberscythe",',
                            b'["EmberscytheChroma"] = {\n    ["ItemName"] = "OtherName",')
        self.assertNotEqual(g,self.game)
        r=self.synthetic_result(g=g)
        self.assertEqual(r['status'],'INCONCLUSIVE',r)
        self.strict(r)

    def test_reject_duplicate_slug_inside_html(self):
        w=dict(self.web)
        old=b'<div class="itemcolumn"><div class="itemcell" id="BA2">'
        w['godlies']=w['godlies'].replace(old,old+b'<div class="itemcell" id="BA2"></div>')
        r=self.synthetic_result(w=w)
        self.assertEqual(r['status'],'INCONCLUSIVE',r)

    def test_400_mutated_archive_inputs_never_authorize(self):
        rng=random.Random(77)
        for i in range(400):
            g=self.game;w=dict(self.web)
            p=rng.choice(list(w))
            if i%3==0:
                g+=b'garbage'
            elif i%3==1:
                w[p]+=b'garbage'
            else:
                w[p]=b'<html>wrong document</html>'
            r=m.run(g,w)
            self.assertEqual(r['status'],'INCONCLUSIVE',i)
            self.strict(r)

    def test_real_immutable_public_snapshots(self):
        env = {k:os.environ.get(k) for k in ('STAGE77_PINNED_GAME','STAGE77_PINNED_ANCIENTS','STAGE77_PINNED_GODLIES','STAGE77_PINNED_CHROMAS')}
        if not all(env.values()):
            if os.environ.get('STAGE77_REQUIRE_PINNED') == '1':
                self.fail('DEDICATED CI REQUIRES ALL FOUR ACTUAL HASH-PINNED SOURCES')
            self.skipTest('focused pinned public archives supplied only to dedicated CI')
        g=Path(env['STAGE77_PINNED_GAME']).read_bytes()
        w={k:Path(env[f'STAGE77_PINNED_{k.upper()}']).read_bytes() for k in ('ancients','godlies','chromas')}
        result=m.run(g,w)
        self.assertEqual(result['status'],'PINNED_PUBLIC_SOURCES_CORRESPOND_ONLY',result)
        self.assertEqual(result['independentlyPinnedSourceCount'],4)
        self.assertEqual(result['corroboratedPublicKeyNames'],4)
        self.strict(result)

if __name__=='__main__':
    unittest.main()
