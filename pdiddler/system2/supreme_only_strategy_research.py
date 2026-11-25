"""Canonical System 2 SUPREME-ONLY strategy research engine.

Economic input: exactly one immutable Supreme Values catalog. No secondary
price list, averaging, dual-source max/min, historical scanner price fallback,
or unverified inferred acceptance rate. Roblox item identity, completed
settlement and real liquidity are NOT established by the public catalog.

Research only: never authorize trade, offer, Accept, chat, teleport, Discord
profit reporting, or live loss execution. Historical fixtures can be tested at
their authentic capture clock but never promoted to live source authority.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
import hashlib
import json
from pathlib import Path
import re

SCHEMA = "gingerscope-system2-supreme-only-strategy-research-v1"
CATALOG_SCHEMA = "gingerscope-system2-supreme-only-189-publisher-catalog-v1"
CATALOG_BLOB_SHA = "0fefb1d82d6841a787974478447f5d9e1db922e7"
ORIGINAL_SUPREME_BLOB_SHA = "b5afb393fc6646e02e19af899b8f066dd2df5708"
SOURCE_CAPTURE = "2026-11-16T04:36:35.765Z"
SOURCE_PUBLICATION = "2026-11-15T11:59:41-05:00"
MAX_CAPTURE_AGE_SECONDS = 6 * 3600
MAX_PUBLICATION_AT_CAPTURE_SECONDS = 4 * 86400
CENSUS = {"ancient": 15, "godly": 128, "chroma": 46}
ROW_KEYS = {
    "rawGameKeyCandidate", "category", "officialName", "officialItemId",
    "supremeListed", "supremeDemand", "supremeStability",
    "outgoingGingerscopeProtected",
}
DOC_KEYS = {
    "schema", "status", "valueSource", "sourceOrigin", "sourceTransport",
    "publisherUpdatedAt", "sourceCapturedUtc",
    "immutableOriginalSupremeReceiptGitBlob",
    "reviewedHistoricalRawGameKeyCandidates", "categories",
    "exactRobloxItemInstanceVerified", "publisherSigned",
    "currentInventoryVerified", "sourceResearchOnly",
    "liveTradePricingAuthorized", "authorizesTrade", "authorizesOffer",
    "authorizesAccept", "mayUseForStrategyLearning", "mayReportProfit",
    "rows",
}
INPUT_OPTION_KEYS = {"kind", "give", "receive", "valuationSource"}
SLOT_KEYS = {"rawGameKeyCandidate", "quantity"}
RAW_KEY = re.compile(r"^[A-Za-z0-9_]{1,90}$")
SOURCE = "SUPREME_ONLY"
TARGET = "Gingerscope"


class SupremeOnlyBlocked(ValueError):
    pass


def deny(reason):
    raise SupremeOnlyBlocked(reason)


def utc(value, *, captured=False):
    if type(value) is not str:
        deny("SUPREME_ONLY_CLOCK_TYPE_INVALID")
    if captured and not value.endswith("Z"):
        deny("SUPREME_ONLY_CAPTURE_CLOCK_FORMAT_INVALID")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (ValueError, OverflowError):
        deny("SUPREME_ONLY_CLOCK_INVALID")
    if parsed.tzinfo is None:
        deny("SUPREME_ONLY_CLOCK_MUST_BE_OFFSET_AWARE")
    return parsed.astimezone(timezone.utc)


def blob_sha(raw):
    if type(raw) is not bytes:
        deny("SUPREME_ONLY_SOURCE_BYTES_REQUIRED")
    return hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\x00" + raw).hexdigest()


def demand(v):
    if type(v) is not str or not re.fullmatch(r"\d+(?:\.\d+)?", v):
        deny("SUPREME_ONLY_PUBLISHER_DEMAND_INVALID")
    try:
        n = Decimal(v)
    except InvalidOperation:
        deny("SUPREME_ONLY_PUBLISHER_DEMAND_INVALID")
    if not n.is_finite() or n < 0 or n > 11:
        deny("SUPREME_ONLY_PUBLISHER_DEMAND_OUT_OF_RANGE")
    return float(n)


NOV25_CATALOG_BLOB_SHA = "b6f5c1eec48d59b422f53baa4d83a54ce6837b72"
NOV25_SOURCE_CAPTURE = "2026-11-25T06:09:59Z"
NOV25_SOURCE_PUBLICATION = "2026-11-23T19:13:44-05:00"


def _validate_rows(rows):
    if type(rows) is not list or len(rows) != 189:
        deny("SUPREME_ONLY_SOURCE_CENSUS_NOT_189")
    by_key, by_id, counts = {}, set(), {k: 0 for k in CENSUS}
    for row in rows:
        if type(row) is not dict or set(row) != ROW_KEYS:
            deny("SUPREME_ONLY_ROW_SHAPE_CHANGED")
        key, cat = row["rawGameKeyCandidate"], row["category"]
        if (type(key) is not str or not RAW_KEY.fullmatch(key) or
            key in by_key or cat not in counts):
            deny("SUPREME_ONLY_RAW_GAME_KEY_OR_CATEGORY_AMBIGUOUS")
        if (type(row["officialName"]) is not str or
            not 1 <= len(row["officialName"]) <= 110 or
            type(row["officialItemId"]) is not str or
            not 1 <= len(row["officialItemId"]) <= 120 or
            (cat, row["officialItemId"]) in by_id):
            deny("SUPREME_ONLY_OFFICIAL_NAME_OR_ID_AMBIGUOUS")
        value = row["supremeListed"]
        if type(value) is not int or not 0 < value < 10**10:
            deny("SUPREME_ONLY_PRICE_MISSING_OR_INVALID_NO_FALLBACK")
        demand(row["supremeDemand"])
        if (type(row["supremeStability"]) is not str or
            not 1 <= len(row["supremeStability"]) <= 80):
            deny("SUPREME_ONLY_STABILITY_MISSING")
        if row["outgoingGingerscopeProtected"] is not (key == TARGET):
            deny("SUPREME_ONLY_GINGERSCOPE_NEVER_OUTGOING")
        by_key[key] = row
        by_id.add((cat, row["officialItemId"]))
        counts[cat] += 1
    if counts != CENSUS or TARGET not in by_key:
        deny("SUPREME_ONLY_CATEGORY_OR_GINGERSCOPE_CENSUS_MISMATCH")
    return by_key


def _nov25_source_rows(raw, *, evaluated_at_utc):
    """Exact independently reviewed archive; no live authority or fallback."""
    if blob_sha(raw) != NOV25_CATALOG_BLOB_SHA:
        deny("SUPREME_ONLY_CATALOG_GIT_BLOB_MISMATCH")
    document = json.loads(raw)
    expected = {
        "schema": "gingerscope-system2-supreme-only-189-publisher-catalog-v4-research",
        "status": "SUPREME_ONLY_MEDIATED_PUBLIC_RESEARCH_NOT_LIVE",
        "valueSource": SOURCE,
        "sourceOrigin": "https://supremevalues.com/",
        "sourceTransport": "FIRECRAWL_MEDIATED_HTTPS_RESEARCH",
        "publisherUpdatedAt": NOV25_SOURCE_PUBLICATION,
        "sourceCapturedUtc": NOV25_SOURCE_CAPTURE,
        "sourceExpiresUtc": "2026-11-25T12:09:59Z",
        "sourceMaxAgeSeconds": MAX_CAPTURE_AGE_SECONDS,
        "priorResearchCatalogGitBlob": "958038a6b22c43e8d0359cb15e6704bc84253430",
        "reviewedHistoricalRawGameKeyCandidates": 189,
        "categories": CENSUS,
        "sourceResearchOnly": True,
        "publisherSigned": False,
        "rawHtmlArchived": False,
        "exactRobloxItemInstanceVerified": False,
        "currentInventoryVerified": False,
        "liveTradePricingAuthorized": False,
        "authorizesTrade": False,
        "authorizesOffer": False,
        "authorizesAccept": False,
        "mayUseForStrategyLearning": False,
        "mayReportProfit": False,
    }
    for field, value in expected.items():
        actual = document.get(field)
        if type(actual) is not type(value) or actual != value:
            deny("SUPREME_ONLY_NOV25_SOURCE_CONTRACT_INVALID_" + field)
    now, capture, published = (utc(evaluated_at_utc),
                               utc(NOV25_SOURCE_CAPTURE, captured=True),
                               utc(NOV25_SOURCE_PUBLICATION))
    capture_age = (now - capture).total_seconds()
    edition_age = (capture - published).total_seconds()
    if capture_age < 0:
        deny("SUPREME_ONLY_CAPTURE_FROM_FUTURE")
    if capture_age > MAX_CAPTURE_AGE_SECONDS:
        deny("SUPREME_ONLY_SOURCE_EXPIRED_NO_OTHER_LIST_FALLBACK")
    if edition_age < 0 or edition_age > MAX_PUBLICATION_AT_CAPTURE_SECONDS:
        deny("SUPREME_ONLY_PUBLISHER_EDITION_EXPIRED")
    return _validate_rows(document["rows"]), {
        "publisherUpdatedAt": NOV25_SOURCE_PUBLICATION,
        "capturedUtc": NOV25_SOURCE_CAPTURE,
        "captureAgeSeconds": int(capture_age),
        "catalogGitBlob": NOV25_CATALOG_BLOB_SHA,
        "sourceSignatureVerified": False,
    }


def source_rows(raw, *, evaluated_at_utc):
    """Reject any tamper, stale capture, missing Supreme quote or extra catalog key."""
    if blob_sha(raw) == NOV25_CATALOG_BLOB_SHA:
        return _nov25_source_rows(raw, evaluated_at_utc=evaluated_at_utc)
    if blob_sha(raw) != CATALOG_BLOB_SHA:
        deny("SUPREME_ONLY_CATALOG_GIT_BLOB_MISMATCH")
    try:
        document = json.loads(raw)
    except (ValueError, UnicodeError):
        deny("SUPREME_ONLY_CATALOG_JSON_MALFORMED")
    if type(document) is not dict or set(document) != DOC_KEYS:
        deny("SUPREME_ONLY_CATALOG_SCHEMA_OR_KEYS_CHANGED")
    for key, expected in {
        "schema": CATALOG_SCHEMA,
        "status": "SUPREME_ONLY_RESEARCH_SOURCE_NOT_LIVE",
        "valueSource": SOURCE,
        "sourceOrigin": "https://supremevalues.com/",
        "sourceTransport": "FIRECRAWL_MEDIATED_HTTPS_RESEARCH",
        "publisherUpdatedAt": SOURCE_PUBLICATION,
        "sourceCapturedUtc": SOURCE_CAPTURE,
        "immutableOriginalSupremeReceiptGitBlob": ORIGINAL_SUPREME_BLOB_SHA,
        "reviewedHistoricalRawGameKeyCandidates": 189,
        "categories": CENSUS,
        "exactRobloxItemInstanceVerified": False,
        "publisherSigned": False,
        "currentInventoryVerified": False,
        "sourceResearchOnly": True,
        "liveTradePricingAuthorized": False,
        "authorizesTrade": False,
        "authorizesOffer": False,
        "authorizesAccept": False,
        "mayUseForStrategyLearning": False,
        "mayReportProfit": False,
    }.items():
        if type(expected) is bool:
            if document.get(key) is not expected: deny("SUPREME_ONLY_UNSAFE_SOURCE_FLAG_"+key)
        elif type(expected) is int:
            if type(document.get(key)) is not int or document[key] != expected:
                deny("SUPREME_ONLY_SOURCE_COUNT_CHANGED_"+key)
        elif document.get(key) != expected:
            deny("SUPREME_ONLY_SOURCE_PROVENANCE_CHANGED_"+key)
    now, capture, published = utc(evaluated_at_utc), utc(SOURCE_CAPTURE, captured=True), utc(SOURCE_PUBLICATION)
    capture_age = (now - capture).total_seconds()
    edition_age = (capture - published).total_seconds()
    if capture_age < 0:
        deny("SUPREME_ONLY_CAPTURE_FROM_FUTURE")
    if capture_age > MAX_CAPTURE_AGE_SECONDS:
        deny("SUPREME_ONLY_SOURCE_EXPIRED_NO_OTHER_LIST_FALLBACK")
    if edition_age < 0 or edition_age > MAX_PUBLICATION_AT_CAPTURE_SECONDS:
        deny("SUPREME_ONLY_PUBLISHER_EDITION_EXPIRED")
    by_key = _validate_rows(document["rows"])
    return by_key, {"publisherUpdatedAt": SOURCE_PUBLICATION,
                    "capturedUtc": SOURCE_CAPTURE,
                    "captureAgeSeconds": int(capture_age),
                    "catalogGitBlob": CATALOG_BLOB_SHA,
                    "sourceSignatureVerified": False}


def quantities(value, market):
    if type(value) is not dict or not 0 < len(value) <= 189:
        deny("SUPREME_ONLY_HYPOTHETICAL_OWNERSHIP_REQUIRED")
    for key, qty in value.items():
        if key not in market or type(qty) is not int or not 0 < qty <= 100000:
            deny("SUPREME_ONLY_UNKNOWN_OR_INVALID_OWNED_STACK")
    return Counter(value)


def parse_slots(slots, market, *, side):
    if type(slots) is not list or not 1 <= len(slots) <= 4:
        deny("SUPREME_ONLY_" + side + "_ONE_TO_FOUR_PHYSICAL_SLOTS_REQUIRED")
    result = {}
    for item in slots:
        if type(item) is not dict or set(item) != SLOT_KEYS:
            deny("SUPREME_ONLY_" + side + "_SLOT_SHAPE_OR_PRICE_SOURCE_INVALID")
        key, qty = item["rawGameKeyCandidate"], item["quantity"]
        if key not in market or key in result or type(qty) is not int or (
            not 0 < qty <= 100000
        ):
            deny("SUPREME_ONLY_" + side + "_RAW_KEY_OR_STACK_AMBIGUOUS")
        result[key] = qty
    return result


def total(items, market):
    return sum(market[k]["supremeListed"] * q for k,q in items.items())


def mean_demand(items, market):
    value = total(items, market)
    return sum(market[k]["supremeListed"]*q*demand(market[k]["supremeDemand"])
               for k,q in items.items())/value if value else 0.0


def concentration(items, market):
    if not items:
        return 0
    worth = [q * market[k]["supremeListed"] for k,q in items.items()]
    return int(10000 * max(worth) / sum(worth))


def risky_stability(items, market):
    warnings = []
    for k in items:
        label = re.sub("[^a-z]", "", market[k]["supremeStability"].lower())
        if label in ("unsafe", "underpaidfor", "decreasing", "fluctuating"):
            warnings.append(k)
    return sorted(warnings)


def blocked(reason):
    return {
        "schema": SCHEMA, "status": "BLOCKED",
        "reason": reason, "valueSource": SOURCE,
        "researchOnly": True, "sourceFreshnessProven": False,
        "liveMarketAuthorized": False, "realInventoryVerified": False,
        "actualRobloxItemIdentityVerified": False,
        "empiricalAcceptanceProbability": None,
        "empiricalLiquidity": "UNKNOWN",
        "authorizesTrade": False, "authorizesOffer": False,
        "authorizesAccept": False, "mayReportProfit": False,
        "mayUseForStrategyLearning": False,
    }


def review(catalog_bytes, *, owned, alternatives, evaluated_at_utc):
    """C3/C4/C9 strategy replacement: only Supreme numerical economics.

    Never consumes any other price, market source, secondary demand, or
    purported player preference. Input ownership is a fixture, not an actual
    C3 client inventory attestation. No native game action is created.
    """
    try:
        market, provenance = source_rows(catalog_bytes,evaluated_at_utc=evaluated_at_utc)
        initial = quantities(owned,market)
        before_value = total(initial, market)
        if type(alternatives) is not list or not 1 <= len(alternatives) <= 12:
            deny("SUPREME_ONLY_ONE_TO_TWELVE_HYPOTHETICAL_ROUTES_REQUIRED")
        outcomes = []
        seen = set()
        for i, option in enumerate(alternatives,1):
            if type(option) is not dict or set(option) != INPUT_OPTION_KEYS or (
                option.get("kind") != "HYPOTHETICAL_RESEARCH_ONLY" or
                option.get("valuationSource") != SOURCE
            ):
                deny("SUPREME_ONLY_NO_HYBRID_OR_UNKNOWN_PRICING_INPUT")
            outgoing = parse_slots(option["give"],market,side="GIVE")
            incoming = parse_slots(option["receive"],market,side="RECEIVE")
            if TARGET in outgoing:
                deny("SUPREME_ONLY_GINGERSCOPE_NEVER_OUTGOING")
            signature = (tuple(sorted(outgoing.items())),tuple(sorted(incoming.items())))
            if signature in seen:
                deny("SUPREME_ONLY_DUPLICATE_HYPOTHETICAL_TRADE")
            seen.add(signature)
            if any(initial.get(k,0)<q for k,q in outgoing.items()):
                deny("SUPREME_ONLY_GIVE_EXCEEDS_HYPOTHETICAL_OWNERSHIP")
            after = Counter(initial)
            after.subtract(outgoing)
            if any(q<0 for q in after.values()):
                deny("SUPREME_ONLY_NEGATIVE_POST_TRADE_STACK")
            after.update(incoming)
            after = +after
            if any(q>100000 for q in after.values()):
                deny("SUPREME_ONLY_POST_TRADE_COPY_OVERFLOW")
            give_value,receive_value=total(outgoing,market),total(incoming,market)
            net=receive_value-give_value
            if before_value+net != total(after,market):
                deny("SUPREME_ONLY_VALUE_CONSERVATION_FAILED")
            five_plus=any(q>=5 and market[k]["supremeListed"]>1
                          for bundle in (outgoing,incoming)
                          for k,q in bundle.items())
            risky_incoming=risky_stability(incoming,market)
            warnings = ["PUBLISHED_DEMAND_NOT_MEASURED_RETRADE_LIQUIDITY",
                        "OTHER_PLAYER_ACCEPTANCE_NOT_PROVEN"]
            if net<0: warnings.append("UNAPPROVED_SUPREME_LISTED_VALUE_LOSS")
            if five_plus: warnings.append("STACKED_COPY_PRICE_NONLINEAR_UNVERIFIED")
            if risky_incoming: warnings.append("INCOMING_PUBLISHER_STABILITY_RISK")
            if TARGET in incoming: warnings.append("TARGET_ACQUISITION_HYPOTHETICAL_ONLY")
            attention_status=(
                "BLOCKED_UNAPPROVED_SUPREME_LOSS" if net<0 else
                "BLOCKED_NONLINEAR_STACK_PRICE" if five_plus else
                "SUPREME_PAPER_GAIN_RESEARCH_NOT_ACTIONABLE"
            )
            outcomes.append({
                "index":i, "status":attention_status,
                "source":SOURCE,
                "outgoingSupremeListedValue":give_value,
                "incomingSupremeListedValue":receive_value,
                "supremeListedValueGain":net,
                "opponentSupremeListedValueGain":-net,
                "beforeSupremePortfolioValue":before_value,
                "hypotheticalAfterSupremePortfolioValue":total(after,market),
                "beforeSupremeConcentrationBasisPoints":concentration(initial,market),
                "afterSupremeConcentrationBasisPoints":concentration(after,market),
                "outgoingSupremeDemandOrdinal":mean_demand(outgoing,market),
                "incomingSupremeDemandOrdinal":mean_demand(incoming,market),
                "incomingPublishedRiskLabelsForKeys":risky_incoming,
                "receivedGingerscopeHypothetically":TARGET in incoming,
                "targetNeverOutgoing":True,
                "warnings":warnings,
                "measuredAcceptanceProbability":None,
                "realRetradeLiquidity":"UNKNOWN",
                "tradeActionable":False,
                "mayUseForLiveOffer":False,
            })
        return {
            "schema":SCHEMA,
            "status":"SUPREME_ONLY_HYPOTHETICAL_STRATEGY_RESEARCH_NOT_EXECUTABLE",
            "valueSource":SOURCE,
            "source":provenance,
            "historicalCatalogRawKeys":189,
            "baselineSupremePortfolioValue":before_value,
            "gingerscopeSupremeTargetValue":market[TARGET]["supremeListed"],
            "hypotheticalAlternatives":outcomes,
            "portfolioOwnershipAuthenticated":False,
            "actualRobloxItemIdentityVerified":False,
            "empiricalAcceptanceProbability":None,
            "empiricalLiquidity":"UNKNOWN",
            "researchOnly":True,
            "liveMarketAuthorized":False,
            "authorizesTrade":False,"authorizesOffer":False,"authorizesAccept":False,
            "mayReportProfit":False,"mayUseForStrategyLearning":False,
        }
    except (SupremeOnlyBlocked,KeyError,TypeError,OverflowError,ZeroDivisionError) as e:
        return blocked(str(e))



def review_paths(catalog_bytes, *, owned, paths, evaluated_at_utc):
    """Compare distinct explicitly hypothetical multi-step growth alternatives.

    Reuses the existing single-step evaluator and exact Supreme source admission.
    Every partner stock is a separate synthetic fixture, never a game observation.
    A paper portfolio gap is not proof a target trade is feasible. No live ranking,
    executable offers, accepted trade, real inventory, or training is asserted.
    """
    schema = "gingerscope-system2-supreme-only-multistep-research-v1"
    def result_blocked(reason):
        return {**blocked(reason), "schema": schema, "simulationOnly": True}
    try:
        market, provenance = source_rows(catalog_bytes, evaluated_at_utc=evaluated_at_utc)
        initial = quantities(owned, market)
        if type(paths) is not list or not 2 <= len(paths) <= 12:
            deny("SUPREME_ONLY_TWO_TO_TWELVE_DISTINCT_PATHS_REQUIRED")
        start_value = total(initial, market)
        target = market[TARGET]["supremeListed"]
        routes, signatures = [], set()
        for index, path in enumerate(paths, 1):
            holdings = initial.copy()
            seen = {tuple(sorted(holdings.items()))}
            signature, transitions = [], []
            target_received = False
            step_number = 0
            try:
                if type(path) is not list or not 2 <= len(path) <= 8:
                    deny("SUPREME_ONLY_TWO_TO_EIGHT_STEPS_REQUIRED")
                for step_number, step in enumerate(path, 1):
                    if type(step) is not dict or set(step) != (
                            INPUT_OPTION_KEYS | {"partnerHypotheticalStock"}):
                        deny("SUPREME_ONLY_EXPLICIT_SYNTHETIC_PARTNER_STOCK_REQUIRED")
                    option = {k:step[k] for k in INPUT_OPTION_KEYS}
                    give = parse_slots(option["give"], market, side="GIVE")
                    receive = parse_slots(option["receive"], market, side="RECEIVE")
                    if set(give) & set(receive):
                        deny("SUPREME_ONLY_SAME_KEY_BOTH_SIDES_AMBIGUOUS")
                    partner = quantities(step["partnerHypotheticalStock"], market)
                    if any(partner.get(k, 0) < q for k,q in receive.items()):
                        deny("SUPREME_ONLY_HYPOTHETICAL_PARTNER_STOCK_SHORTFALL")
                    signature.append((tuple(sorted(give.items())), tuple(sorted(receive.items()))))
                    report = review(catalog_bytes, owned=dict(holdings),
                                    alternatives=[option], evaluated_at_utc=evaluated_at_utc)
                    if report["status"] == "BLOCKED":
                        deny(report["reason"])
                    row = report["hypotheticalAlternatives"][0]
                    if row["status"] != "SUPREME_PAPER_GAIN_RESEARCH_NOT_ACTIONABLE":
                        deny(row["status"])
                    next_holdings = holdings.copy()
                    next_holdings.subtract(give)
                    next_holdings.update(receive)
                    next_holdings = +next_holdings
                    if total(next_holdings, market) != row["hypotheticalAfterSupremePortfolioValue"]:
                        deny("SUPREME_ONLY_MULTISTEP_LEDGER_MISMATCH")
                    stamp = tuple(sorted(next_holdings.items()))
                    if stamp in seen:
                        deny("SUPREME_ONLY_HYPOTHETICAL_PORTFOLIO_CYCLE")
                    seen.add(stamp)
                    holdings = next_holdings
                    target_received = target_received or TARGET in receive
                    transitions.append({
                        "step": step_number,
                        "physicalShape": "UPGRADE" if len(receive)<len(give) else (
                            "DOWNGRADE" if len(receive)>len(give) else "SIDEGRADE"),
                        "outgoingPhysicalSlots": len(give),
                        "incomingPhysicalSlots": len(receive),
                        "outgoingCopies": sum(give.values()),
                        "incomingCopies": sum(receive.values()),
                        "ourListedDelta": row["supremeListedValueGain"],
                        "partnerListedDelta": row["opponentSupremeListedValueGain"],
                        "ourListedPortfolioAfter": total(holdings, market),
                        "partnerReceivesPublishedDemand": row["outgoingSupremeDemandOrdinal"],
                        "partnerGivesPublishedDemand": row["incomingSupremeDemandOrdinal"],
                        "partnerPaperLossNeedsOtherMotive": row["opponentSupremeListedValueGain"]<0,
                        "incomingPublisherRiskKeys": row["incomingPublishedRiskLabelsForKeys"],
                        "warnings": row["warnings"],
                        "actualPartnerWouldAccept": None,
                        "actionAuthorized": False,
                    })
                key = tuple(signature)
                if key in signatures:
                    deny("SUPREME_ONLY_DUPLICATE_HYPOTHETICAL_PATH")
                signatures.add(key)
                final_value = total(holdings, market)
                routes.append({
                    "index": index, "status": "PAPER_PATH_COMPARED_NOT_EXECUTABLE",
                    "completedHypotheticalSteps": len(transitions), "steps": transitions,
                    "endingHypotheticalListedValue": final_value,
                    "hypotheticalListedGrowth": final_value-start_value,
                    "endingPaperTargetGap": max(0,target-final_value),
                    "hypotheticalTargetReceived": target_received,
                    "endingHypotheticalTargetCopies": holdings.get(TARGET,0),
                    "endingPublishedDemandMean": mean_demand(holdings,market),
                    "endingConcentrationBasisPoints": concentration(holdings,market),
                    "targetSufficiencyDoesNotProveFeasibleFourSlotTrade": True,
                    "tradeActionable": False,
                })
            except (SupremeOnlyBlocked, KeyError, TypeError, OverflowError, ZeroDivisionError) as exc:
                routes.append({"index": index, "status": "BLOCKED_PATH", "reason": str(exc),
                               "blockedAtStep": step_number,
                               "completedHypotheticalSteps": len(transitions),
                               "tradeActionable": False})
        return {
            "schema": schema, "status": "SUPREME_ONLY_MULTI_PATH_RESEARCH_NOT_EXECUTABLE",
            "source": provenance, "valueSource": SOURCE, "researchOnly": True,
            "simulationOnly": True, "startingHypotheticalListedValue": start_value,
            "startingPublishedDemandMean": mean_demand(initial,market),
            "startingConcentrationBasisPoints": concentration(initial,market),
            "startingPaperTargetGap": max(0,target-start_value),
            "gingerscopeListedTarget": target, "hypotheticalRoutes": routes,
            "isOfferRanking": False, "realInventoryVerified": False,
            "actualPartnerOwnershipVerified": False, "empiricalAcceptanceProbability": None,
            "empiricalLiquidity": "UNKNOWN", "serverTradeSettlementProven": False,
            "authorizesTrade": False, "authorizesOffer": False, "authorizesAccept": False,
            "mayReportProfit": False, "maySendDiscordWebhook": False,
            "mayUseForStrategyLearning": False, "liveMarketAuthorized": False,
        }
    except (SupremeOnlyBlocked, KeyError, TypeError, OverflowError, ZeroDivisionError) as exc:
        return result_blocked(str(exc))


def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--catalog",type=Path,required=True)
    p.add_argument("--input",type=Path,required=True,help="Synthetic-only JSON owned/alternatives")
    p.add_argument("--evaluated-utc",required=True)
    p.add_argument("--output",type=Path,required=True)
    args=p.parse_args(argv)
    data=json.loads(args.input.read_text())
    report=review(args.catalog.read_bytes(),owned=data.get("owned"),
                  alternatives=data.get("alternatives"),
                  evaluated_at_utc=args.evaluated_utc)
    args.output.write_text(json.dumps(report,sort_keys=True,indent=2)+"\n")
    print(report["status"])
    print("VALUE_SOURCE=SUPREME_ONLY")
    print("LIVE_TRADE_AUTHORIZED=FALSE")
    return 0 if report["status"].startswith("SUPREME_ONLY_HYPOTHETICAL") else 2


if __name__=="__main__":
    raise SystemExit(main())
