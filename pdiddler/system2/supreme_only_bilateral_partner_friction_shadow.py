"""System2 opponent-appeal research, explicitly SYNTHETIC and Supreme-only.

Separates the other player's paper listed-value incentive and publisher-demand
tradeoff from our compounding objective. Never infers an acceptance probability,
labels an actual opponent as greedy, ranks live offers, or learns from outcomes.
An equal-value trade is NOT evidence either side wants it.
"""
from __future__ import annotations
import hashlib,json
from pathlib import Path

SOURCE=Path(__file__).resolve().parent/"supreme_only_189_research_catalog_2026_11_17_214118z_refresh.json"
SOURCE_SHA256="fd657db48c00c996705093dadc384c1a0ddd4630398826108b5585ca76c2eca4"
SOURCE_BLOB="958038a6b22c43e8d0359cb15e6704bc84253430"
CAPTURE_EPOCH=1794951678
MAX_AGE=21600
SCHEMA="gingerscope-system2-supreme-only-opponent-friction-shadow-v1"
SCENARIOS=frozenset({
 "UNKNOWN","HYPOTHETICAL_VALUE_WATCHER","HYPOTHETICAL_DEMAND_SEEKER",
 "HYPOTHETICAL_COLLECTOR_INTEREST","HYPOTHETICAL_BUNDLE_PREFERENCE"
})
RESEARCH_ONLY={
 "valueSource":"SUPREME_ONLY","researchOnly":True,
 "simulationOnly":True,"clientOnly":False,
 "actualPartnerIdentityProven":False,
 "actualCounterpartyOwnershipProven":False,
 "empiricalPartnerAcceptanceProbability":None,
 "empiricalRetradeLiquidity":"UNKNOWN","calibratedToRealTrades":False,
 "serverTradeSettlementProven":False,"mayUseForStrategyLearning":False,
 "maySendDiscordWebhook":False,"mayReportProfit":False,
 "authorizesTrade":False,"authorizesOffer":False,
 "authorizesAccept":False,"liveOfferRankingAuthorized":False,
}
def deny(reason):
 return {"schema":SCHEMA,"status":"BLOCKED","reason":str(reason)[:160],**RESEARCH_ONLY}

class Invalid(ValueError): pass
def check(ok,msg):
 if not ok: raise Invalid(msg)
def catalog():
 raw=SOURCE.read_bytes()
 check(hashlib.sha256(raw).hexdigest()==SOURCE_SHA256,
       "SOURCE_SHA256_UNVERIFIED")
 d=json.loads(raw)
 check(d.get("valueSource")=="SUPREME_ONLY" and
       d.get("publisherUpdatedAt")=="2026-11-15T11:59:41-05:00" and
       d.get("sourceCapturedUtc")=="2026-11-17T21:41:18Z" and
       d.get("publisherSigned") is False and
       d.get("sourceResearchOnly") is True and
       d.get("liveTradePricingAuthorized") is False and
       d.get("authorizesTrade") is False and
       d.get("authorizesAccept") is False and
       d.get("mayUseForStrategyLearning") is False and
       d.get("categories")=={"ancient":15,"godly":128,"chroma":46} and
       isinstance(d.get("rows"),list) and len(d["rows"])==189,
       "SUPREME_ONLY_CATALOG_CONTRACT_INVALID")
 lookup={}
 for row in d["rows"]:
  k=row.get("rawGameKeyCandidate")
  check(type(k) is str and k not in lookup and
        row.get("category") in ("ancient","godly","chroma") and
        type(row.get("supremeListed")) is int and row["supremeListed"]>0 and
        type(row.get("supremeDemand")) is str and
        row["supremeDemand"].isdigit() and
        0<=int(row["supremeDemand"])<=11 and
        type(row.get("supremeStability")) is str,
        "SUPREME_ROW_UNVERIFIED")
  lookup[k]=row
 check(len(lookup)==189 and lookup["Gingerscope"]["supremeListed"]==16000,
       "TARGET_OR_ROW_SET_INVALID")
 return lookup

def stock(d,rows,label):
 check(type(d) is dict and 1<=len(d)<=189,label+"_STOCK_REQUIRED")
 for k,q in d.items():
  check(type(k) is str and k in rows and
        type(q) is int and 1<=q<=100000,label+"_STOCK_KEY_OR_QTY_INVALID")
 return d

def offer(items,stocked,rows,side):
 check(type(items) is list and 1<=len(items)<=4,
       side+"_PHYSICAL_SLOTS_INVALID")
 quantities={}
 for item in items:
  check(type(item) is dict and set(item)=={"rawGameKey","quantity"},
        side+"_UNEXPECTED_ITEM_FIELD")
  key,q=item["rawGameKey"],item["quantity"]
  check(type(key) is str and key in rows and key not in quantities and
        type(q) is int and q>0 and q<=100000 and
        q<=stocked.get(key,0),side+"_RAW_KEY_OR_QUANTITY_NOT_PROVEN")
  quantities[key]=q
 return quantities

def total(group,rows):
 return sum(rows[k]["supremeListed"]*q for k,q in group.items())
def demand(group,rows):
 t=total(group,rows)
 return sum(rows[k]["supremeListed"]*q*int(rows[k]["supremeDemand"])
            for k,q in group.items())/t

def evaluate(request,*,now_epoch):
 """2-12 competing synthetic routes; outputs warning matrix, NOT offer rank."""
 try:
  check(type(now_epoch) is int and
        CAPTURE_EPOCH<=now_epoch<=CAPTURE_EPOCH+MAX_AGE,
        "SUPREME_ONLY_RESEARCH_CAPTURE_STALE_OR_FUTURE")
  rows=catalog()
  check(type(request) is dict and set(request)=={
        "kind","valueSource","ownHypotheticalStock",
        "partnerHypotheticalStock","routes"},
        "EXPLICIT_SYNTHETIC_BILATERAL_REQUEST_REQUIRED")
  check(request["kind"]=="SYNTHETIC_BILATERAL_RESEARCH_ONLY" and
        request["valueSource"]=="SUPREME_ONLY",
        "OTHER_PUBLISHER_OR_LIVE_REQUEST_FORBIDDEN")
  own=stock(request["ownHypotheticalStock"],rows,"OWN")
  their=stock(request["partnerHypotheticalStock"],rows,"PARTNER_SYNTHETIC")
  routes=request["routes"]
  check(type(routes) is list and 2<=len(routes)<=12,
        "TWO_TO_TWELVE_DISTINCT_ALTERNATIVES_REQUIRED")
  checked=[];signatures=set()
  for index,option in enumerate(routes):
   check(type(option) is dict and set(option)=={
        "give","receive","partnerPreferenceScenario","interestKey"},
        "SYNTHETIC_ROUTE_FIELDS_INVALID")
   pref=option["partnerPreferenceScenario"]
   check(pref in SCENARIOS,"UNSUPPORTED_HYPOTHETICAL_PREFERENCE")
   if pref=="HYPOTHETICAL_COLLECTOR_INTEREST":
    check(type(option["interestKey"]) is str and
          option["interestKey"] in rows,
          "COLLECTOR_INTEREST_KEY_UNVERIFIED")
   else:check(option["interestKey"] is None,"UNREQUESTED_INTEREST_KEY")
   give=offer(option["give"],own,rows,"OUR_OUTGOING")
   receive=offer(option["receive"],their,rows,"PARTNER_OUTGOING")
   check("Gingerscope" not in give,"GINGERSCOPE_NEVER_OUTGOING")
   check(not (set(give)&set(receive)),"SAME_RAW_KEY_BOTH_SIDES_AMBIGUOUS")
   key=(tuple(sorted(give.items())),tuple(sorted(receive.items())),pref,
        option["interestKey"])
   check(key not in signatures,"DUPLICATE_COUNTERPARTY_ROUTE")
   signatures.add(key)
   out_value,in_value=total(give,rows),total(receive,rows)
   our_delta=in_value-out_value
   partner_delta=-our_delta
   partner_receives_demand=demand(give,rows)
   partner_gives_demand=demand(receive,rows)
   warnings=["PARTNER_WILLINGNESS_UNVERIFIED"]
   if partner_delta<0:
    warnings.append("PARTNER_PAPER_LISTED_LOSS_NEEDS_OTHER_MOTIVE")
   elif partner_delta==0:
    warnings.append("LISTED_EVEN_DOES_NOT_IMPLY_ACCEPTANCE")
   if partner_receives_demand<partner_gives_demand:
    warnings.append("PARTNER_RECEIVES_LOWER_PUBLISHED_DEMAND")
   if any(rows[k]["supremeStability"] in
          ("Fluctuating","Underpaid For","Decreasing","Unsafe","Receding")
          for k in give):
    warnings.append("PARTNER_RECEIVES_PUBLISHER_STABILITY_CAUTION")
   if any(q>=5 for grp in (give,receive) for q in grp.values()):
    warnings.append("STACK_VALUE_LINEAR_ASSUMPTION_NOT_VERIFIED")
   if pref=="HYPOTHETICAL_VALUE_WATCHER" and partner_delta<0:
    warnings.append("HYPOTHETICAL_VALUE_WATCHER_HAS_PAPER_DISINCENTIVE")
   if (pref=="HYPOTHETICAL_DEMAND_SEEKER" and
       partner_receives_demand<partner_gives_demand):
    warnings.append("HYPOTHETICAL_DEMAND_SEEKER_HAS_DEMAND_DISINCENTIVE")
   if pref=="HYPOTHETICAL_COLLECTOR_INTEREST":
    warnings.append(
      "HYPOTHETICAL_COLLECTOR_INTEREST_INCLUDED" if
      option["interestKey"] in give else
      "HYPOTHETICAL_COLLECTOR_INTEREST_NOT_OFFERED")
   if pref=="HYPOTHETICAL_BUNDLE_PREFERENCE":
    warnings.append("HYPOTHETICAL_BUNDLE_SHAPE_ONLY_NOT_VERIFIED")
   if our_delta<0:
    status="BLOCKED_UNAPPROVED_OUR_LOSS"
   elif "STACK_VALUE_LINEAR_ASSUMPTION_NOT_VERIFIED" in warnings:
    status="BLOCKED_STACK_PRICE_UNVERIFIED"
   else:
    status="PAPER_BILATERAL_INCENTIVE_AUDITED"
   checked.append({
     "index":index,"status":status,
     "ourSupremeListedDelta":our_delta,
     "partnerSupremeListedDelta":partner_delta,
     "outgoingListed":out_value,"incomingListed":in_value,
     "partnerReceivesPublishedDemandMean":round(partner_receives_demand,5),
     "partnerGivesPublishedDemandMean":round(partner_gives_demand,5),
     "partnerPreferenceScenarioIsHypothetical":True,
     "partnerPreferenceScenario":pref,
     "warnings":warnings,
     "actualPartnerWouldAccept":None,"empiricalPartnerFillEvidenceCount":0,
     "tradeActionable":False,
   })
  return {"schema":SCHEMA,"status":"BILATERAL_FRICTION_SHADOW_RESEARCH_ONLY",
          "sourcePublisherEdition":"2026-11-15T11:59:41-05:00",
          "sourceCaptureUtc":"2026-11-17T21:41:18Z",
          "routes":checked,"isOfferRanking":False,**RESEARCH_ONLY}
 except (Invalid,ValueError,TypeError,KeyError,OverflowError) as e:
  return deny(str(e))
