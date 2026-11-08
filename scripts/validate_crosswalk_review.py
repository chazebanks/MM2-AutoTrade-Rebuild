"""Validate a REVIEW-ONLY MM2 weapon-name crosswalk evidence ledger.

This does not fetch prices, execute Roblox code, verify server item instances,
authorize trades, or attest to a Supreme numeric checker ID. Fail closed.
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
LEDGER = ROOT / "pdiddler/intelligence_lab/STAGE58_CROSSWALK_REVIEW_ONLY_LEDGER.json"

EXPECTED = {
    "Bloom": ("Bloom", "Knife", "Godly", "godly", "890", 2025),
    "Blossom_G": ("Blossom", "Gun", "Godly", "godly", "696", 2023),
    "Flora": ("Flora", "Gun", "Godly", "godly", "891", 2025),
    "Gingermint_K": ("Cookiecane", "Knife", "Godly", "godly", "660", 2022),
    "Icecream": ("Icecream", "Knife", "Godly", "godly", "1005", 2026),
    "Icewing": ("Icewing", "Knife", "Ancient", "ancient", "4", 2018),
    "ImmortalChroma": ("Chroma Immortal", "Gun", "Godly", "chroma", "1034", 2026),
    "MortalChroma": ("Chroma Mortal", "Knife", "Godly", "chroma", "1033", 2026),
    "Ocean_G": ("Ocean", "Gun", "Godly", "godly", "728", 2023),
    "Waves_K": ("Waves", "Knife", "Godly", "godly", "727", 2023),
}

FORBIDDEN_FIELD_NAMES = {
    "value", "values", "displayed_price", "marketvalue", "price",
    "tradevalue", "profit", "tradeprofit", "accepted", "settled",
    "webhooktoken", "userid", "username", "jobid", "inventory",
}
ALLOWED_SOURCE_HOSTS = {"mm2wiki.org", "supremevalues.com"}

class EvidenceError(ValueError):
    pass

def fail(message: str) -> None:
    raise EvidenceError(message)

def _assert_no_forbidden_keys(node: object, path: str = "ledger") -> None:
    if isinstance(node, dict):
        for key, value in node.items():
            if key.lower().replace("_", "") in FORBIDDEN_FIELD_NAMES:
                fail(f"not allowed in public display metadata: {path}.{key}")
            _assert_no_forbidden_keys(value, f"{path}.{key}")
    elif isinstance(node, list):
        for i, value in enumerate(node):
            _assert_no_forbidden_keys(value, f"{path}[{i}]")

def validate(data: dict) -> int:
    if not isinstance(data, dict):
        fail("ledger must be a JSON object")
    if data.get("schema") != "gingerscope-stage58-review-only-crosswalk-ledger-v1":
        fail("unexpected schema")
    if data.get("reviewAsOfUtc") != "2026-11-08":
        fail("unreviewed ledger date")
    safety = data.get("safety")
    if not isinstance(safety, dict):
        fail("safety metadata missing")
    required_false = (
        "usesLivePrices", "marketValueFieldsIncluded",
        "externalCheckerIdAuthenticated", "rawKeyAuthenticatedByExternalSource",
        "sourceItemIdInstanceAuthenticated", "serverCompletionProven",
        "mayRecordCompletedTrade", "mayReportProfit",
        "authorizesTrade", "authorizesAccept",
    )
    for name in required_false:
        if safety.get(name) is not False:
            fail(f"unsafe authority promotion or missing false: {name}")
    if safety.get("readOnly") is not True or safety.get("lookupOnly") is not True:
        fail("not explicitly read-only")
    if safety.get("tradeOutcome") != "UNKNOWN":
        fail("trade outcome unverified")
    source = data.get("source")
    if not isinstance(source, dict):
        fail("missing source receipt")
    if source.get("nativeProbe") != "gingerscope-stage57-crosswalk-candidates-v1":
        fail("wrong native evidence")
    if source.get("catalogueCandidateCount") != 10:
        fail("unexpected native receipt count")
    if source.get("gameMetadataAuthority") != "CLIENT_REPLICATED_UNATTESTED":
        fail("source authentication overstated")
    policy = data.get("reviewPolicy", {})
    if policy.get("allItemsReleaseState") != (
        "REVIEW_ONLY; never used as trader's live price or offer authority"
    ):
        fail("release gate missing")
    if policy.get("checkerId") != (
        "Provisional ID from the old frozen checker reference, NOT independently attested by MM2 or Supreme API."
    ):
        fail("checker-ID nonattestation not explicit")

    records = data.get("candidates")
    if not isinstance(records, list) or len(records) != 10:
        fail("expected exactly 10 candidate records")
    keys = [r.get("rawKey") for r in records if isinstance(r, dict)]
    if len(keys) != 10 or keys != sorted(EXPECTED):
        fail("candidate keys missing, duplicate or reordered")
    if len(set(keys)) != 10:
        fail("duplicate raw keys")

    checker_targets = set()
    missing_years, second_levels, placeholders, near_runner = 0, 0, 0, 0
    for record in records:
        raw = record["rawKey"]
        display, typ, rarity, tier, numeric_id, expected_year = EXPECTED[raw]
        client = record.get("client", {})
        checker = record.get("provisionalChecker", {})
        public = record.get("publicDisplay", {})
        review = record.get("review", {})
        if not all(isinstance(x, dict) for x in (client, checker, public, review)):
            fail(f"{raw}: record sections malformed")
        if (client.get("displayName"), client.get("weaponType"),
            client.get("rarity"), checker.get("tier"), checker.get("id"),
            public.get("originYear")) != (
            display, typ, rarity, tier, numeric_id, expected_year
        ):
            fail(f"{raw}: mismatch against Stage57/native + external display baseline")
        for key, expected in (("name",display),("type",typ),("rarity",rarity)):
            if public.get(key) != expected:
                fail(f"{raw}: contradicts client identity: {key}")
        cy = client.get("sourceYear")
        if cy is None:
            missing_years += 1
            if client.get("sourceEventRaw") != "1":
                fail(f"{raw}: unknown year misrepresented")
            if review.get("clientYearAgreement") != "NOT_COMPARABLE_GAME_YEAR_MISSING":
                fail(f"{raw}: independent source year promoted to client")
            required_flags = {"GAME_YEAR_MISSING", "SOURCE_EVENT_GENERIC_MARKER"}
            if not required_flags.issubset(set(review.get("flags", []))):
                fail(f"{raw}: missing generic event/year review flags")
        elif (
            not isinstance(cy,str) or
            not re.fullmatch(r"20[0-9]{2}",cy) or
            int(cy) != expected_year or
            review.get("clientYearAgreement") != "MATCH"
        ):
            fail(f"{raw}: client/public year contradiction")
        if not isinstance(client.get("itemIdHint"), str) or not (
            client["itemIdHint"].isdigit()
        ):
            fail(f"{raw}: untrusted game item ID hint invalid")
        if checker.get("mappingMethod") not in (
            "match:355", "match:405", "alias"
        ):
            fail(f"{raw}: unknown mapping method")
        target = (checker["tier"],checker["id"])
        if target in checker_targets:
            fail(f"{raw}: checker collision")
        checker_targets.add(target)
        image = checker.get("image")
        if not isinstance(image,str) or not image.endswith(".png"):
            fail(f"{raw}: missing checker image filename")
        flags = set(review.get("flags",[]))
        if checker.get("selectionReason") == "LEVEL2_NORMALIZATION":
            second_levels += 1
            if "LEVEL2_NORMALIZATION" not in flags:
                fail(f"{raw}: level2 proof flag missing")
        elif checker.get("selectionReason") == "PLACEHOLDER_ARTWORK":
            placeholders += 1
            if image != "coming.png" or "PLACEHOLDER_ARTWORK" not in flags:
                fail(f"{raw}: placeholder evidence inadequately quarantined")
        elif checker.get("selectionReason") == "NEAR_RUNNER":
            near_runner += 1
            if "NEAR_RUNNER_SCORE" not in flags:
                fail(f"{raw}: closer runner-up unflagged")
        else:
            fail(f"{raw}: unrecognized selection reason")
        if raw == "Gingermint_K":
            if not {"LEGACY_INTERNAL_KEY_NAME_DISAGREES_WITH_DISPLAY",
                    "DIFFERENT_ITEM_GINGERMINT_IS_GUN"}.issubset(flags):
                fail("Cookiecane/Gingermint distinct-item quarantine missing")
            if display != "Cookiecane" or typ != "Knife":
                fail("mistakenly used Gingermint gun as Cookiecane knife")

        urls = public.get("sources")
        if not isinstance(urls,list) or len(urls) < 2:
            fail(f"{raw}: fewer than two displayed external sources")
        hosts = set()
        for source_ref in urls:
            if not isinstance(source_ref,dict):
                fail(f"{raw}: malformed source")
            u = urlparse(source_ref.get("url",""))
            host = (u.hostname or "").removeprefix("www.")
            if u.scheme != "https" or host not in ALLOWED_SOURCE_HOSTS:
                fail(f"{raw}: untrusted or malformed source domain")
            hosts.add(host)
        if hosts != ALLOWED_SOURCE_HOSTS:
            fail(f"{raw}: not independently corroborated in two source families")

        if review.get("status") != (
            "DISPLAY_METADATA_CORROBORATED_RAW_TO_CHECKER_ID_UNATTESTED"
        ):
            fail(f"{raw}: source review authority promoted")
        for flag in (
            "sourceItemIdIndependentlyAttested",
            "rawKeyToPublicNameIndependentlyAttested",
            "checkerNumericIdIndependentlyAttested",
            "uniqueItemInstanceProven", "mayAutoTrade",
            "mayFinalizeAccept", "mayReportProfit"
        ):
            if review.get(flag) is not False:
                fail(f"{raw}: unauthorized field {flag}")
        for flag in (
            "displayNameCorroborated", "rarityAndTypeCorroborated",
            "publicOriginYearCorroborated"
        ):
            if review.get(flag) is not True:
                fail(f"{raw}: public display metadata not corroborated")

    if (second_levels, placeholders, near_runner, missing_years) != (7,2,1,5):
        fail("candidate source-review pattern deviated from native Stage57")
    _assert_no_forbidden_keys(data)
    return len(records)

def main() -> None:
    data = json.loads(LEDGER.read_text(encoding="utf-8"))
    n = validate(data)
    print(f"STAGE58_REVIEW_ONLY_LEDGER_VALIDATED={n}")
    print("MARKET_PRICE_AND_TRADE_AUTHORITY=FALSE")

if __name__ == "__main__":
    main()
