"""Stage69: exact frozen baseline comparisons; no trading-profile publication."""
from __future__ import annotations

import copy
import importlib.util
import random
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/"scripts/stage69_supreme_source_audit.py"
spec=importlib.util.spec_from_file_location("stage69_audit",SOURCE)
assert spec and spec.loader
A=importlib.util.module_from_spec(spec)
spec.loader.exec_module(A)

PUBLISH="2026-11-06T10:56:07-05:00"
PUBLISH_UTC=A.P.epoch(PUBLISH)
OBSERVE=A.P.epoch("2026-11-08T02:00:00Z")
NOW=A.P.epoch("2026-11-08T12:00:00Z")

def one_row(name, value=3, demand=5, stability="Stable"):
    value_str="Priceless" if value is None else str(value)
    attr="" if value is None else f' data-value="{value_str}"'
    return (
        f'<div class="itemcolumn"{attr} data-demand="{demand}"'
        f' data-stability="{stability}">'
        f'<button data-name="{name}"></button>'
        f'<div class="itemhead">{name}</div>'
        f'<div class="itembody">'
        f'Value - <b class="itemvalue">{value_str}</b><br>'
        f'Stability - <b class="itemstability">{stability}</b><br>'
        f'Demand - <b>{demand}</b><sep/>Rarity - <b>3</b>'
        f'</div></div>'
    )

def fixture():
    pages={}
    original=[]
    for kind in A.PAGE_ORDER:
        body=[]
        for i in range(A.EXPECTED[kind]):
            item_name=(f"{kind.title()} {i:03d}")
            if kind=="ancient" and i==2:
                item_name="Emberbow"
            if kind=="ancient" and i==0:
                item_name="Nik's Scythe"
            val=None if item_name=="Nik's Scythe" else (
                400 if item_name=="Emberbow" else i+3
            )
            demand=11 if val is None else 5
            stability="Overpaid For" if val is None else "Stable"
            body.append(one_row(item_name,val,demand,stability))
            original.append({
                "page":kind,"id":str(i+1), "name":item_name,
                "supremeValue":val, "demand":demand, "stability":stability,
            })
        html=(f'<html><head><title>MM2 {kind.title()} Values</title></head>'
              f'<body><div data-updated-iso="{PUBLISH}"></div>'
              f'{"".join(body)}</body></html>')
        pages[kind]=(html.encode("utf-8"),OBSERVE)
    return pages, {"rows":original}

def assert_no_authority(t, result):
    for k in ("researchOnly","outgoingPaused"):
        t.assertIs(result[k],True,k)
    for k in ("fullCatalogueCompletenessVerified",
              "rawWeaponToSupremeCheckerIdAuthenticated",
              "exactVariantIdentityAuthenticated",
              "publisherDateIndependentlyAuthenticated",
              "liveReady","authorizesTrading","authorizesAccept",
              "mayReportProfit","mayUseForStrategyLearning",
              "mayPublishLiveSnapshot"):
        t.assertIs(result[k],False,k)

class Stage69SupremeAuditTests(unittest.TestCase):
    def test_complete_unchanged_source_never_enables_quote(self):
        pages,base=fixture()
        result=A.audit(pages,base,now=NOW)
        self.assertEqual(result["status"],"MATCHES_OLD_SNAPSHOT_RESEARCH_ONLY",result)
        self.assertEqual(result["reason"],"SOURCE_CLAIMS_MATCH_BUT_ITEM_ID_AND_TRADE_AUTHORITY_NOT_PROVEN")
        self.assertEqual(result["comparedCanonicalEntries"],190)
        self.assertEqual(result["sourceCounts"],A.EXPECTED)
        self.assertEqual(len(result["sourceChecks"]),3)
        self.assertEqual(len({x["rawSha256"] for x in result["sourceChecks"]}),3)
        self.assertEqual(result["claimedSitePublisherTimestampUtc"],"2026-11-06T15:56:07Z")
        assert_no_authority(self,result)

    def test_emberbow_400_to_525_is_an_explicit_review_change(self):
        pages,base=fixture()
        raw,when=pages["ancient"]
        pages["ancient"]=(raw.replace(b'data-value="400"',b'data-value="525"')
                         .replace(b'Value - <b class="itemvalue">400</b>',
                                  b'Value - <b class="itemvalue">525</b>'),when)
        result=A.audit(pages,base,now=NOW)
        self.assertEqual(result["status"],"REVIEW_REQUIRED")
        self.assertEqual(result["reason"],"SOURCE_VALUES_OR_MARKET_METADATA_CHANGED")
        match=[x for x in result["changes"] if x["canonicalName"]=="Emberbow"]
        self.assertEqual(len(match),1)
        self.assertEqual((match[0]["before"],match[0]["observed"]),(400,525))
        assert_no_authority(self,result)

    def test_new_weapon_never_inherits_fuzzy_canonical_id(self):
        pages,base=fixture()
        raw,when=pages["chroma"]
        pages["chroma"]=(raw.replace(b"</body></html>",one_row("Chroma NEW HALLOWEEN").encode()+b"</body></html>"),when)
        result=A.audit(pages,base,now=NOW)
        self.assertEqual(result["status"],"REVIEW_REQUIRED")
        self.assertEqual(result["reason"],"SOURCE_INVENTORY_OR_MAPPING_DRIFT")
        self.assertEqual(result["unmappedSourceNames"],[
            {"category":"chroma","name":"Chroma NEW HALLOWEEN"}])
        self.assertEqual(result["sourceCounts"]["chroma"],47)
        assert_no_authority(self,result)

    def test_missing_or_renamed_canonical_weapon_blocks(self):
        pages,base=fixture()
        raw,when=pages["ancient"]
        raw=raw.replace(b'Emberbow',b'Fake New Name')
        pages["ancient"]=(raw,when)
        result=A.audit(pages,base,now=NOW)
        self.assertEqual(result["status"],"REVIEW_REQUIRED")
        self.assertEqual(len(result["missingCanonicalNames"]),1)
        self.assertEqual(len(result["unmappedSourceNames"]),1)
        assert_no_authority(self,result)

    def test_differing_site_claimed_publication_times_block(self):
        pages,base=fixture()
        raw,when=pages["godly"]
        pages["godly"]=(raw.replace(PUBLISH.encode(),b"2026-11-06T10:56:08-05:00"),when)
        result=A.audit(pages,base,now=NOW)
        self.assertEqual(result["status"],"SOURCE_INVALID")
        self.assertEqual(result["reason"],"CONFLICTING_PUBLISHER_TIMESTAMPS")
        assert_no_authority(self,result)

    def test_price_metadata_disagreement_is_not_a_live_quote(self):
        pages,base=fixture()
        raw,when=pages["ancient"]
        pages["ancient"]=(raw.replace(b'data-value="400"',b'data-value="525"'),when)
        result=A.audit(pages,base,now=NOW)
        self.assertEqual(result["status"],"SOURCE_INVALID")
        self.assertEqual(result["reason"],"STRUCTURED_SOURCE_PARSER_REJECTED")
        self.assertEqual(result["failedCategory"],"ancient")
        assert_no_authority(self,result)

    def test_publisher_age_policy_exact_boundary(self):
        pages,base=fixture()
        before=A.audit(pages,base,now=PUBLISH_UTC+72*3600)
        self.assertIn(before["status"],("MATCHES_OLD_SNAPSHOT_RESEARCH_ONLY","SOURCE_INVALID"))
        after=A.audit(pages,base,now=PUBLISH_UTC+72*3600+1)
        self.assertEqual(after["status"],"SOURCE_INVALID")
        self.assertEqual(after["reason"],"SITE_PUBLICATION_OLDER_THAN_EXISTING_72H_POLICY")
        assert_no_authority(self,after)

    def test_fake_refresh_from_future_and_invalid_source_rejected(self):
        pages,base=fixture()
        negatives=[
          ({**pages,"pet":(b"stuff",OBSERVE)},base,NOW),
          ({"ancient":pages["ancient"]},base,NOW),
          ({**pages,"godly":(pages["godly"][0],NOW+60)},base,NOW),
          ({**pages,"godly":(b"",OBSERVE)},base,NOW),
          (pages,{"rows":[]},NOW),
          (pages,{"rows":base["rows"]+[base["rows"][-1]]},NOW),
          (pages,{},NOW),
        ]
        for i,(p,b,n) in enumerate(negatives):
            with self.subTest(i=i):
                result=A.audit(p,b,now=n)
                self.assertEqual(result["status"],"SOURCE_INVALID")
                assert_no_authority(self,result)

    def test_400_seeded_corruptions_never_grant_trade_permissions(self):
        rng=random.Random(6969)
        for i in range(400):
            pages,base=fixture()
            kind=rng.choice(A.PAGE_ORDER)
            raw,when=pages[kind]
            n=rng.randrange(8)
            if n==0:
                raw=raw.replace(b'data-demand="5"',b'data-demand="11"',1)
            elif n==1:
                raw=raw.replace(b'data-stability="Stable"',b'data-stability="Mystery"',1)
            elif n==2:
                raw=raw.replace(PUBLISH.encode(),b"2030-11-06T10:56:07-05:00")
            elif n==3:
                raw=raw.replace(b'data-name=',b'data-missing-name=',1)
            elif n==4:
                raw=raw.replace(b'class="itemcolumn"',b'class="hiddencolumn"',1)
            elif n==5:
                raw=raw.replace(b'<title>',b'<title>Completely Different ',1)
            elif n==6:
                raw=raw.replace(b"</body></html>",one_row("UNKNOWN COPY").encode()+b"</body></html>")
            else:
                raw=raw.replace(b'data-value="',b'data-value="NaN',1)
            pages[kind]=(raw,when)
            out=A.audit(pages,base,now=NOW)
            self.assertNotEqual(out["status"],"MATCHES_OLD_SNAPSHOT_RESEARCH_ONLY",
                                (i,n,kind,out["reason"]))
            assert_no_authority(self,out)

    def test_actual_code_has_no_auto_trade_or_snapshot_write(self):
        source=SOURCE.read_text()
        for forbidden in ("FireServer","InvokeServer","setclipboard",
                          "send_webhook","authorizesTrading = True",
                          "mayPublishLiveSnapshot = True","os.replace(",
                          "subprocess","create_file("):
            self.assertNotIn(forbidden,source)
        self.assertIn("cache",source.lower())  # Cache-Control/no-cache header
        self.assertIn("SOURCE_VALUES_OR_MARKET_METADATA_CHANGED",source)

if __name__=="__main__":
    unittest.main()
