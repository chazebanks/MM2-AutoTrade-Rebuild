#!/usr/bin/env python3
"""Stage25: compare a source-checked Supreme candidate to the last checked map.

Read-only accounting. No re-pricing guesses, trading actions, or snapshot install.
The observation timestamp and the WEBSITE publication timestamp are distinct.
"""
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import argparse
import json
import math

KEYS = ("ancient", "chroma", "godly")
EXPECTED = {"ancient": 16, "chroma": 46, "godly": 128}


def utc_epoch(text: str) -> int:
    dt = datetime.fromisoformat(text.replace("Z", "+00:00"))
    if dt.tzinfo is None or dt.utcoffset() is None:
        raise ValueError("timezone required")
    return int(dt.timestamp())


def indexed(snap: dict, label: str) -> dict:
    if not isinstance(snap, dict) or snap.get("schemaVersion") != 1:
        raise ValueError(f"{label}: unexpected snapshot schema")
    coverage = snap.get("coverage")
    rows = snap.get("rows")
    if (not isinstance(rows, list) or len(rows) != 190 or
        not isinstance(coverage, dict) or
        any(coverage.get(k) != count for k, count in EXPECTED.items()) or
        coverage.get("total") != 190 or coverage.get("finite") != 189 or
        coverage.get("unpriced") != 1):
        raise ValueError(f"{label}: incomplete canonical coverage")
    research = snap.get("researchOnly") is True
    if research:
        if not (
            snap.get("authorizesTrade") is False and
            snap.get("authorizesAccept") is False and
            snap.get("autoDeploy") is False and
            snap.get("sourceRowsMatched") is True and
            snap.get("rawGameMappingsVerified") is False and
            snap.get("sourceAcquisition") == "EXTERNAL_SCRAPE_REVIEW_ONLY"
        ):
            raise ValueError(f"{label}: research candidate cannot promote trade or raw identity authority")
    elif snap.get("researchOnly") not in (None, False):
        raise ValueError(f"{label}: invalid research status")
    records = {}
    for r in rows:
        if not isinstance(r, dict):
            raise ValueError(f"{label}: malformed record")
        page, rid, name = r.get("page"), r.get("id"), r.get("name")
        if page not in KEYS or not isinstance(rid, str) or not rid.isascii() or not rid.isdigit():
            raise ValueError(f"{label}: noncanonical identity")
        if not isinstance(name, str) or not name.strip():
            raise ValueError(f"{label}: missing canonical source name")
        if research:
            if not (
                r.get("verified") is False and
                r.get("sourceRecordMatched") is True and
                r.get("rawGameMappingVerified") is False and
                r.get("priceForTradeVerified") is False
            ):
                raise ValueError(f"{label}: unverified raw game mapping was promoted")
        elif r.get("verified") is not True:
            raise ValueError(f"{label}: unverified identity")
        val, demand, stability = r.get("supremeValue"), r.get("demand"), r.get("stability")
        if val is not None and (type(val) not in (int, float) or not math.isfinite(val) or val <= 0):
            raise ValueError(f"{label}: invalid quote")
        if type(demand) is not int or not 0 <= demand <= 11:
            raise ValueError(f"{label}: invalid demand")
        if not isinstance(stability, str) or not stability.strip():
            raise ValueError(f"{label}: unknown stability")
        key = page, rid
        if key in records:
            raise ValueError(f"{label}: duplicate canonical item")
        records[key] = r
    if len(records) != 190:
        raise ValueError(f"{label}: duplicate source identities")
    return records


def compare(before: dict, candidate: dict, *, now_epoch: int | None = None) -> dict:
    old = indexed(before, "previous")
    new = indexed(candidate, "candidate")
    if set(old) != set(new):
        raise ValueError("canonical item identities changed")
    for key in old:
        if old[key]["name"].casefold() != new[key]["name"].casefold():
            raise ValueError(f"canonical name changed: {key}")
    for stamp in ("observedAt", "publishedAt", "expiresAt"):
        utc_epoch(before[stamp])
        utc_epoch(candidate[stamp])
    observed = utc_epoch(candidate["observedAt"])
    published = utc_epoch(candidate["publishedAt"])
    expires = utc_epoch(candidate["expiresAt"])
    if (observed <= utc_epoch(before["observedAt"]) or
        published < utc_epoch(before["publishedAt"]) or
        published > observed or expires <= observed):
        raise ValueError("invalid or reversed publication/retrieval provenance")
    sources = candidate.get("sources")
    if not isinstance(sources, dict) or set(sources) != set(KEYS):
        raise ValueError("source provenance is incomplete")
    expected_expiry = []
    source_observations, source_publications = [], []
    for page, record in sources.items():
        if record.get("url") != "https://supremevalues.com/mm2/" + {"ancient": "ancients", "chroma": "chromas", "godly": "godlies"}[page]:
            raise ValueError("unexpected source URL")
        digest = record.get("sha256")
        if not isinstance(digest, str) or len(digest) != 64 or any(c not in "0123456789abcdef" for c in digest):
            raise ValueError("invalid source SHA256")
        o = utc_epoch(record["observedAt"])
        p = utc_epoch(record["publishedAt"])
        if p > o or o < observed:
            raise ValueError("source observations inconsistent with snapshot")
        source_observations.append(o)
        source_publications.append(p)
        expected_expiry.append(min(o + 86400, p + 72*3600))
    if observed != min(source_observations) or published != min(source_publications):
        raise ValueError("snapshot timestamp differs from oldest source observation/publication")
    if expires != min(expected_expiry):
        raise ValueError("candidate expiry is not tied to source observation and publication")
    if now_epoch is not None and not observed <= now_epoch < expires:
        raise ValueError("candidate is not current")

    changes = []
    for key in sorted(old):
        a, b = old[key], new[key]
        fields = ("supremeValue", "demand", "stability")
        if any(a[f] != b[f] for f in fields):
            changes.append({"page": key[0], "checkerId": key[1], "name": b["name"],
                "before": {f: a[f] for f in fields},
                "after": {f: b[f] for f in fields}})
    pub_changed = candidate["publishedAt"] != before["publishedAt"]
    return {
        "status": "REVIEW_ONLY_NO_TRADE_AUTHORITY",
        "previousVersion": before["version"],
        "candidateVersion": candidate["version"],
        "originalPublication": before["publishedAt"],
        "candidatePublication": candidate["publishedAt"],
        "publicationChanged": pub_changed,
        "publicationClassification": "NEW_SOURCE_PUBLICATION" if pub_changed else "SAME_PUBLICATION_NEW_RETRIEVAL",
        "candidateObservedAt": candidate["observedAt"],
        "candidateExpiresAt": candidate["expiresAt"],
        "canonicalCount": len(new),
        "changedItems": len(changes),
        "unchangedItems": len(new)-len(changes),
        "changed": changes,
        "sourceSHA256": {page: sources[page]["sha256"] for page in KEYS},
        "authorizesTrade": False,
        "authorizesAccept": False,
        "autoDeploy": False
    }


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--previous", type=Path, required=True)
    p.add_argument("--candidate", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args()
    old = json.loads(args.previous.read_text())
    candidate = json.loads(args.candidate.read_text())
    result = compare(old, candidate, now_epoch=int(datetime.now(timezone.utc).timestamp()))
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False)+"\n")
    print(json.dumps({k: result[k] for k in
        ("status", "publicationClassification", "canonicalCount",
         "changedItems", "unchangedItems", "candidateExpiresAt")}))
    for row in result["changed"][:25]:
        print("CHANGED", row["page"], row["checkerId"], row["name"],
              row["before"], "=>", row["after"])


if __name__ == "__main__":
    main()
