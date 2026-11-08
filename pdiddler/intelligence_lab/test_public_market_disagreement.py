"""Date-scoped cross-source *public display* audit: NOT a live MM2 price feed.

No game/raw inventory identifiers. No trade or strategy learning authority.
All numeric differences are recomputed from two independent public page snapshots.
"""
from __future__ import annotations

import copy
import json
import random
import unittest
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
from urllib.parse import urlparse

FILE=Path(__file__).with_name("PUBLIC_MARKET_DISAGREEMENT_2026_11_08.json")
EXPECTED_NAMES={
    "Gingerscope", "Traveler's Axe", "Emberbow", "Emberscythe",
    "Harvester","Icepiercer","Batwing","Icewing",
    "Chroma Emberbow","Chroma Emberscythe",
}
FALSE_GATES={
    "exactRawWeaponIdAuthenticated", "sourceNamesMappedToGameKeys",
    "canPublishTradingPrices","liveReady","authorizesTrade","authorizesAccept",
    "mayRecordCompletedTrade","mayReportProfit","mayUseForStrategyLearning",
    "serverCompletionProven",
}
PERCENT_MIN=10

class SourceEvidenceError(ValueError):
    pass

def invalid(why):
    raise SourceEvidenceError(why)

def validate(data):
    if not isinstance(data,dict):
        invalid("not a JSON object")
    if data.get("schema")!="gingerscope-offline-public-market-disagreement-v1":
        invalid("schema unknown")
    if data.get("observedDateUtc")!="2026-11-08":
        invalid("date not independently reviewed")
    if data.get("status")!="RESEARCH_SOURCE_DISPLAY_ONLY_NOT_EXECUTABLE":
        invalid("source authority expanded")
    safety=data.get("safety")
    if not isinstance(safety,dict):
        invalid("safety missing")
    if safety.get("lookupOnly") is not True or safety.get("marketDisplayOnly") is not True:
        invalid("not review only")
    for field in FALSE_GATES:
        if safety.get(field) is not False:
            invalid("economic/trade authority set: "+field)
    if safety.get("tradeOutcome")!="UNKNOWN":
        invalid("trade outcome claimed")
    sources=data.get("sourceLabels")
    if not isinstance(sources,dict) or set(sources)!={"supreme","mm2values"}:
        invalid("must have both site families")
    supreme=sources["supreme"]
    mm2=sources["mm2values"]
    if supreme.get("publisherUpdatedLabel")!="November 6th, 2026 at 10:56 AM":
        invalid("wrong dated public publisher label")
    if supreme.get("publisherTimezoneKnown") is not False or mm2.get("publisherUpdatedAtUtc") is not None:
        invalid("unsupported official publisher clock")
    for family,site in ((supreme,"supremevalues.com"),(mm2,"mm2values.com")):
        for kind in ("ancient","chroma"):
            link=urlparse(family.get(kind,""))
            if link.scheme!="https" or link.hostname!=site:
                invalid("unexpected source domain")
    if data.get("comparisonPolicy")!={"percentDenominator":"MM2VALUES_LISTED_VALUE",
        "reviewOnAbsoluteDisagreementAtLeastPercent":PERCENT_MIN}:
        invalid("comparison policy not fixed")
    rows=data.get("records")
    if not isinstance(rows,list) or len(rows)!=10:
        invalid("not exactly ten reviewed display examples")
    names={x.get("displayName") for x in rows if isinstance(x,dict)}
    if names!=EXPECTED_NAMES or len({x["displayName"] for x in rows})!=10:
        invalid("missing/duplicate display item")
    count=0
    for row in rows:
        if set(row)!={
            "displayName","group","supremeListedValue","mm2valuesListedValue",
            "deltaSupremeMinusMM2Values","deltaPercentOfMM2Values",
            "supremeDemand","mm2valuesDemand","supremeStability",
            "mm2valuesStability","differingBy10PercentOrMore",
            "rawKeyCheckerIdentityAttested","tradeAuthority",
        }:
            invalid("unknown/unreviewed field")
        name=row["displayName"]
        expected_group="chroma-ancient" if name.startswith("Chroma ") else "ancient"
        if row.get("group")!=expected_group:
            invalid("chroma variant mixed with ordinary ancient")
        if row.get("rawKeyCheckerIdentityAttested") is not False or row.get("tradeAuthority") is not False:
            invalid("display alias promoted to game identity or trade authority")
        a=row.get("supremeListedValue")
        b=row.get("mm2valuesListedValue")
        if type(a) is not int or type(b) is not int or not 0<a<=1000000 or not 0<b<=1000000:
            invalid("missing or noninteger positive prices")
        if row.get("deltaSupremeMinusMM2Values")!=a-b:
            invalid("incorrect source delta")
        expected_pct=(Decimal(100)*(Decimal(a)-Decimal(b))/Decimal(b)).quantize(
            Decimal("0.01"),rounding=ROUND_HALF_UP)
        reported=row.get("deltaPercentOfMM2Values")
        if type(reported) not in (int,float) or Decimal(str(reported))!=expected_pct:
            invalid("incorrect source percentage")
        if row.get("differingBy10PercentOrMore") is not (abs(a-b)*10>=b):
            invalid("incorrect review threshold")
        if type(row.get("supremeDemand")) not in (int,float) or not 0<row["supremeDemand"]<=11:
            invalid("source demand missing")
        if type(row.get("mm2valuesDemand")) not in (int,float) or not 0<row["mm2valuesDemand"]<=11:
            invalid("MM2Values demand missing")
        if not all(isinstance(row.get(x),str) and row[x] for x in
                   ("supremeStability","mm2valuesStability")):
            invalid("stability missing")
        count += 1
    return count

class PublicMarketDisagreementTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data=json.loads(FILE.read_text())
    def clone(self):
        return copy.deepcopy(self.data)
    def rejects(self,data):
        with self.assertRaises((SourceEvidenceError,KeyError,TypeError,ValueError)):
            validate(data)
    def test_10_actual_reviewed_public_display_rows(self):
        self.assertEqual(validate(self.data),10)
        large=[x["displayName"] for x in self.data["records"]
            if x["differingBy10PercentOrMore"]]
        self.assertEqual(set(large),{"Emberbow","Emberscythe","Icewing","Chroma Emberscythe"})
        item={x["displayName"]:x for x in self.data["records"]}
        self.assertEqual(item["Gingerscope"]["supremeListedValue"],16000)
        self.assertEqual(item["Gingerscope"]["mm2valuesListedValue"],16000)
        self.assertEqual(item["Emberbow"]["deltaSupremeMinusMM2Values"],75)
        self.assertEqual(item["Chroma Emberscythe"]["deltaSupremeMinusMM2Values"],3500)
        self.assertEqual(item["Harvester"]["supremeDemand"],3)
    def test_named_attacks_quarantined(self):
        for edit in [
            lambda d:d["safety"].__setitem__("authorizesAccept",True),
            lambda d:d["safety"].__setitem__("mayReportProfit",True),
            lambda d:d["safety"].__setitem__("sourceNamesMappedToGameKeys",True),
            lambda d:d["sourceLabels"]["mm2values"].__setitem__("publisherUpdatedAtUtc","2026-11-08"),
            lambda d:d["sourceLabels"]["supreme"].__setitem__("publisherTimezoneKnown",True),
            lambda d:d["sourceLabels"]["supreme"].__setitem__("ancient","https://fake.example/ancients"),
            lambda d:d["records"][0].__setitem__("rawKeyCheckerIdentityAttested",True),
            lambda d:d["records"][0].__setitem__("tradeAuthority",True),
            lambda d:d["records"][0].__setitem__("deltaPercentOfMM2Values",999),
            lambda d:d["records"][0].__setitem__("deltaSupremeMinusMM2Values",999),
            lambda d:d["records"][0].__setitem__("mm2valuesListedValue",-4),
            lambda d:d["records"][0].__setitem__("differingBy10PercentOrMore",True),
            lambda d:d["records"][0].__setitem__("group","chroma-ancient"),
            lambda d:d["records"][0].__setitem__("rawKey","FAKE"),
            lambda d:d["records"].append(copy.deepcopy(d["records"][0])),
        ]:
            d=self.clone();edit(d);self.rejects(d)
    def test_400_deterministic_adversarial_changes(self):
        rng=random.Random(6039)
        for i in range(400):
            d=self.clone()
            row=d["records"][rng.randrange(10)]
            mode=i%8
            if mode==0:row["deltaSupremeMinusMM2Values"]+=1
            elif mode==1:row["supremeListedValue"]+=rng.randrange(1,150)
            elif mode==2:row["differingBy10PercentOrMore"]=not row["differingBy10PercentOrMore"]
            elif mode==3:row["tradeAuthority"]=True
            elif mode==4:row["group"]="vintage"
            elif mode==5:row["mm2valuesListedValue"]+=rng.randrange(1,150)
            elif mode==6:row["deltaPercentOfMM2Values"]=9999
            elif mode==7:d["safety"]["mayUseForStrategyLearning"]=True
            self.rejects(d)

if __name__=="__main__":
    unittest.main()
