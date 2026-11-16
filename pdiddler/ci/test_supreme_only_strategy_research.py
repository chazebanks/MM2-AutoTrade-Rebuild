"""Supreme-only source/strategy regression: no blended, alternate or fallback values."""
from __future__ import annotations

from copy import deepcopy
from datetime import datetime,timedelta,timezone
import json
from pathlib import Path
import unittest

from pdiddler.system2.supreme_only_strategy_research import (
    SCHEMA,SOURCE,CATALOG_BLOB_SHA, SOURCE_CAPTURE,
    SupremeOnlyBlocked, source_rows, review, blob_sha, parse_slots,
)

ROOT = Path(__file__).resolve().parents[2]/"pdiddler/system2"
CATALOG = (ROOT/"supreme_only_189_research_catalog.json").read_bytes()
DATA = json.loads(CATALOG)
AT = "2026-11-16T04:37:05Z"


def option(give,receive,**overrides):
    v={"kind":"HYPOTHETICAL_RESEARCH_ONLY",
       "valuationSource":"SUPREME_ONLY",
       "give":[{"rawGameKeyCandidate":k,"quantity":q} for k,q in give.items()],
       "receive":[{"rawGameKeyCandidate":k,"quantity":q} for k,q in receive.items()]}
    v.update(overrides)
    return v


OWN={"Harvester":1,"FlowerwoodKnife":2,"EmberscytheChroma":1,"TravelerAxe":1,"Gingerscope":1}


def task(alt=None,owned=None,clock=AT,src=CATALOG):
    return review(src,owned=OWN if owned is None else owned,
                  alternatives=[option({"Harvester":1},{"FlowerwoodKnife":2})]
                  if alt is None else alt,
                  evaluated_at_utc=clock)


def plus(source,secs):
    x=datetime.fromisoformat(source.replace("Z","+00:00"))
    return (x+timedelta(seconds=secs)).astimezone(timezone.utc).isoformat().replace("+00:00","Z")


class SupremeOnlyStrategy(unittest.TestCase):
    def test_archived_supreme_json_is_pinned_exact_and_has_189(self):
        self.assertEqual(blob_sha(CATALOG),CATALOG_BLOB_SHA)
        x,prov=source_rows(CATALOG,evaluated_at_utc=AT)
        self.assertEqual(len(x),189)
        self.assertEqual(DATA["categories"],{"ancient":15,"godly":128,"chroma":46})
        self.assertEqual(prov["sourceSignatureVerified"],False)
        self.assertEqual(DATA["sourceOrigin"],"https://supremevalues.com/")

    def test_catalog_itself_contains_only_supreme_fields(self):
        raw=CATALOG.decode("utf-8").lower()
        for prohibited in ("mm2values","mm2listed","mm2value",
                           "crosslist","hybrid","secondaryvalue","averaged",
                           "fallbacksource","max(mm2","min(mm2"):
            with self.subTest(field=prohibited):
                self.assertNotIn(prohibited,raw)
        for row in DATA["rows"]:
            self.assertEqual(set(row),{
                "rawGameKeyCandidate","category","officialName","officialItemId",
                "supremeListed","supremeDemand","supremeStability",
                "outgoingGingerscopeProtected"})

    def test_true_supreme_prices_not_earlier_alternate_values(self):
        x,_=source_rows(CATALOG,evaluated_at_utc=AT)
        self.assertEqual(x["Gingerscope"]["supremeListed"],16000)
        self.assertEqual(x["Harvester"]["supremeListed"],275)
        self.assertEqual(x["FlowerwoodKnife"]["supremeListed"],235)
        self.assertEqual(x["EmberscytheChroma"]["supremeListed"],12000)
        self.assertEqual(x["TravelerAxe"]["supremeListed"],6700)

    def test_profit_computed_supreme_only_for_both_sides(self):
        output=task()
        self.assertEqual(output["status"],
                         "SUPREME_ONLY_HYPOTHETICAL_STRATEGY_RESEARCH_NOT_EXECUTABLE")
        r=output["hypotheticalAlternatives"][0]
        self.assertEqual(r["outgoingSupremeListedValue"],275)
        self.assertEqual(r["incomingSupremeListedValue"],470)
        self.assertEqual(r["supremeListedValueGain"],195)
        self.assertEqual(r["opponentSupremeListedValueGain"],-195)
        self.assertEqual(r["incomingSupremeDemandOrdinal"],3)
        self.assertEqual(r["beforeSupremePortfolioValue"]+195,
                         r["hypotheticalAfterSupremePortfolioValue"])
        self.assertTrue(r["targetNeverOutgoing"])

    def test_chroma_upgrade_uses_only_supreme_not_cross_list(self):
        x=task(alt=[option({"EmberscytheChroma":1},{"Gingerscope":1})])
        self.assertEqual(x["hypotheticalAlternatives"][0]["supremeListedValueGain"],4000)
        self.assertTrue(x["hypotheticalAlternatives"][0]
                        ["receivedGingerscopeHypothetically"])
        self.assertEqual(x["valueSource"],SOURCE)

    def test_target_never_sent_out_even_if_we_own_it(self):
        x=task(alt=[option({"Gingerscope":1},{"Harvester":1})])
        self.assertEqual(x["status"],"BLOCKED")
        self.assertEqual(x["reason"],"SUPREME_ONLY_GINGERSCOPE_NEVER_OUTGOING")

    def test_stale_supreme_refuses_without_any_fallback(self):
        x=task(clock=plus(SOURCE_CAPTURE,21601))
        self.assertEqual(x["status"],"BLOCKED")
        self.assertEqual(x["reason"],"SUPREME_ONLY_SOURCE_EXPIRED_NO_OTHER_LIST_FALLBACK")
        self.assertEqual(x["valueSource"],SOURCE)
        self.assertIs(x["authorizesTrade"],False)

    def test_exact_6_hour_boundary_and_future_clock_fail_stop(self):
        self.assertEqual(task(clock=plus(SOURCE_CAPTURE,21600))
                         ["status"],"SUPREME_ONLY_HYPOTHETICAL_STRATEGY_RESEARCH_NOT_EXECUTABLE")
        self.assertEqual(task(clock=plus(SOURCE_CAPTURE,-1))
                         ["reason"],"SUPREME_ONLY_CAPTURE_FROM_FUTURE")

    def test_source_price_mutation_rejected_even_when_more_profitable(self):
        s=deepcopy(DATA)
        next(x for x in s["rows"] if x["rawGameKeyCandidate"]=="Harvester")["supremeListed"]=1
        invalid=(json.dumps(s)).encode()
        self.assertEqual(task(src=invalid)["reason"],
                         "SUPREME_ONLY_CATALOG_GIT_BLOB_MISMATCH")

    def test_source_forged_retrieval_time_rejected(self):
        s=deepcopy(DATA);s["sourceCapturedUtc"]="2026-11-16T18:00:00Z"
        self.assertEqual(task(src=json.dumps(s).encode())["status"],"BLOCKED")

    def test_source_missing_supreme_price_cannot_fallback(self):
        s=deepcopy(DATA)
        row=next(x for x in s["rows"] if x["rawGameKeyCandidate"]=="Harvester")
        row.pop("supremeListed")
        self.assertEqual(task(src=json.dumps(s).encode())["reason"],
                         "SUPREME_ONLY_CATALOG_GIT_BLOB_MISMATCH")

    def test_wrong_value_publisher_not_permitted_anywhere_in_option(self):
        for wrong in ("MM2VALUES","AUTO","HYBRID","SUPREME_PLUS_BACKUP",None):
            with self.subTest(value=wrong):
                x=task(alt=[option({"Harvester":1},{"FlowerwoodKnife":1},
                                     valuationSource=wrong)])
                self.assertEqual(x["status"],"BLOCKED")
                self.assertEqual(x["reason"],"SUPREME_ONLY_NO_HYBRID_OR_UNKNOWN_PRICING_INPUT")

    def test_injection_of_alternate_value_not_accepted(self):
        o=option({"Harvester":1},{"FlowerwoodKnife":1},secondaryValue=999999)
        x=task(alt=[o])
        self.assertEqual(x["reason"],"SUPREME_ONLY_NO_HYBRID_OR_UNKNOWN_PRICING_INPUT")
        o=option({"Harvester":1},{"FlowerwoodKnife":1})
        o["receive"][0]["alternateListed"]=999999
        x=task(alt=[o])
        self.assertEqual(x["reason"],"SUPREME_ONLY_RECEIVE_SLOT_SHAPE_OR_PRICE_SOURCE_INVALID")

    def test_four_physical_slots_capped_and_stacked_quantities_supported_as_research(self):
        o=option({"Harvester":1},{"FlowerwoodKnife":2})
        self.assertEqual(task(alt=[o])["hypotheticalAlternatives"][0]["giveSlots"]
                         if "giveSlots" in task(alt=[o])["hypotheticalAlternatives"][0]
                         else len(o["give"]),1)
        five=option({"Harvester":1},{
            "FlowerwoodKnife":1,"Gingerscope":1,"TravelerAxe":1,
            "EmberscytheChroma":1,"Harvester":1,
        })
        x=task(alt=[five])
        self.assertEqual(x["status"],"BLOCKED")
        self.assertIn("ONE_TO_FOUR_PHYSICAL_SLOTS_REQUIRED",x["reason"])

    def test_stacked_five_copy_price_uncertainty_not_executable(self):
        x=task(owned={"Harvester":5},alt=[
            option({"Harvester":5},{"Gingerscope":1})])
        r=x["hypotheticalAlternatives"][0]
        self.assertEqual(r["status"],"BLOCKED_NONLINEAR_STACK_PRICE")
        self.assertIn("STACKED_COPY_PRICE_NONLINEAR_UNVERIFIED",r["warnings"])
        self.assertEqual(r["outgoingSupremeListedValue"],1375)
        self.assertFalse(r["tradeActionable"])

    def test_negative_supreme_loss_never_authorized(self):
        x=task(alt=[option({"FlowerwoodKnife":1},{"Harvester":1}),
                    option({"Harvester":1},{"FlowerwoodKnife":1})])
        second=x["hypotheticalAlternatives"][1]
        self.assertEqual(second["supremeListedValueGain"],-40)
        self.assertEqual(second["status"],"BLOCKED_UNAPPROVED_SUPREME_LOSS")
        self.assertIn("UNAPPROVED_SUPREME_LISTED_VALUE_LOSS",second["warnings"])
        self.assertFalse(second["tradeActionable"])

    def test_duplicate_route_is_rejected(self):
        a=option({"Harvester":1},{"FlowerwoodKnife":1})
        x=task(alt=[a,deepcopy(a)])
        self.assertEqual(x["reason"],"SUPREME_ONLY_DUPLICATE_HYPOTHETICAL_TRADE")

    def test_unlisted_weapon_or_wrong_chroma_variant_never_guessed(self):
        for key in ("Emberscythechroma","UnknownItem","HarvesterChroma"):
            with self.subTest(key=key):
                x=task(alt=[option({"Harvester":1},{key:1})])
                self.assertEqual(x["status"],"BLOCKED")
                self.assertIn("RAW_KEY_OR_STACK_AMBIGUOUS",x["reason"])

    def test_hypothetical_inventory_is_never_authenticated(self):
        x=task()
        for k in ("portfolioOwnershipAuthenticated","actualRobloxItemIdentityVerified",
                  "liveMarketAuthorized","authorizesTrade","authorizesOffer",
                  "authorizesAccept","mayReportProfit","mayUseForStrategyLearning"):
            self.assertIs(x[k],False)
        self.assertIsNone(x["empiricalAcceptanceProbability"])
        self.assertEqual(x["empiricalLiquidity"],"UNKNOWN")

    def test_concentration_and_demand_use_same_supreme_denominator(self):
        x=task(alt=[option({"Harvester":1},{"FlowerwoodKnife":2})])
        row=x["hypotheticalAlternatives"][0]
        self.assertTrue(0<=row["beforeSupremeConcentrationBasisPoints"]<=10000)
        self.assertTrue(0<=row["afterSupremeConcentrationBasisPoints"]<=10000)
        self.assertTrue(0<=row["outgoingSupremeDemandOrdinal"]<=11)
        self.assertTrue(0<=row["incomingSupremeDemandOrdinal"]<=11)

    def test_no_private_user_identifiers_or_webhook_in_report(self):
        raw=json.dumps(task(),sort_keys=True)
        for term in ("username","userId","jobId","leaseId",
                     "webhookUrl","privateInventory","sessionToken"):
            self.assertNotIn(term,raw)

    def test_source_identity_must_be_exactly_one_protected_gingerscope(self):
        x,_=source_rows(CATALOG,evaluated_at_utc=AT)
        self.assertEqual(sum(r["outgoingGingerscopeProtected"] for r in x.values()),1)
        self.assertTrue(x["Gingerscope"]["outgoingGingerscopeProtected"])

    def test_empty_trade_and_unapproved_source_schema_block(self):
        x=task(alt=[])
        self.assertEqual(x["status"],"BLOCKED")
        x=task(alt=[option({},{"Harvester":1})])
        self.assertEqual(x["status"],"BLOCKED")
        self.assertIn("ONE_TO_FOUR_PHYSICAL_SLOTS_REQUIRED",x["reason"])


    def test_exact_supreme_weapon_buckets_exclude_special_hidden_and_pets(self):
        """Independent Nov16 Supreme-site census: 15 ordinary Ancient +
        128 visible ordinary Godly + 46 Chroma KNIVES/GUNS. These are
        weapon buckets, not all visible/hidden website HTML cards.
        """
        expected = {"ancient": 15, "godly": 128, "chroma": 46}
        groups = {category: [r for r in DATA["rows"] if r["category"] == category]
                  for category in expected}
        self.assertEqual({category: len(rows) for category,rows in groups.items()},
                         expected)
        self.assertEqual(len(DATA["rows"]), 189)
        keys = [r["rawGameKeyCandidate"] for r in DATA["rows"]]
        self.assertEqual(len(set(keys)), 189)
        ids = [(r["category"], r["officialItemId"]) for r in DATA["rows"]]
        self.assertEqual(len(set(ids)), 189)

        # Supreme Ancients HTML has 16 columns; the 16th is Nik's
        # Scythe special-tier "Priceless" without a numeric ordinary quote.
        self.assertNotIn("Nik's Scythe", [r["officialName"] for r in DATA["rows"]])
        self.assertNotIn("Niks_Scythe", keys)
        # Godlies HTML has 130 itemcolumns, but the extra two are marked
        # style=display:none and Origin='Secret MM2 Item'. One reuses
        # the ordinary Ancient Batwing name / item id. Never import either
        # as a canonical Godly without new reviewed game-side identity proof.
        self.assertNotIn("Black Luger",
                         [r["officialName"] for r in groups["godly"]])
        self.assertNotIn("Batwing",
                         [r["officialName"] for r in groups["godly"]])
        ancient_batwing=[r for r in groups["ancient"] if r["officialName"]=="Batwing"]
        self.assertEqual(len(ancient_batwing),1)
        self.assertEqual(ancient_batwing[0]["supremeListed"],40)

        # Chroma HTML has 53 itemcolumns, but last seven are pets.
        chroma_names={r["officialName"] for r in groups["chroma"]}
        self.assertTrue(all(name.startswith("Chroma ") for name in chroma_names))
        self.assertTrue({"Chroma Emberbow","Chroma Emberscythe"} <= chroma_names)
        for pet in ("Bat","Bear","Bunny","Cat","Dog","Fox","Pig"):
            self.assertNotIn("Chroma Fire "+pet, chroma_names)

    def test_ordinary_supreme_weapon_census_does_not_assume_website_complete(self):
        """A 189-row snapshot is exact for Nov15 publisher edition, not
        a guarantee that every future release, secret item, or pet is covered.
        """
        self.assertEqual(DATA["sourceCapturedUtc"], "2026-11-16T04:36:35.765Z")
        self.assertEqual(DATA["publisherUpdatedAt"],
                         "2026-11-15T11:59:41-05:00")
        self.assertIs(DATA["liveTradePricingAuthorized"],False)
        self.assertIs(DATA["exactRobloxItemInstanceVerified"],False)



if __name__=="__main__":
    unittest.main()
