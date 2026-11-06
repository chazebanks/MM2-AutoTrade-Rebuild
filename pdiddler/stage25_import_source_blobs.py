#!/usr/bin/env python3
"""Stage25: import immutable, browser-retrieved official Supreme HTML from Git
blobs into the existing refresh_supreme_snapshot.py --input-dir path.

The browser source receipt and observation time are supplied in a pinned,
reviewable manifest. Do not equate browser retrieval with a new market
publication or an authenticated Roblox trade. Never invent source dates.
"""
from __future__ import annotations

import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
from urllib.request import Request, urlopen

REPO = "chazebanks/MM2-AutoTrade-Rebuild"
PAGES = {"ancient": "ancients", "chroma": "chromas", "godly": "godlies"}


def moment(raw: str) -> datetime:
    t = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    if t.tzinfo is None or t.utcoffset() is None:
        raise ValueError("source timestamp missing timezone")
    return t.astimezone(timezone.utc)


def git_oid(raw: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()


def download_git_blob(sha: str) -> bytes:
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise ValueError("invalid source blob SHA")
    url = f"https://api.github.com/repos/{REPO}/git/blobs/{sha}"
    headers = {"Accept": "application/vnd.github+json",
               "X-GitHub-Api-Version": "2022-11-28",
               "User-Agent": "gingerscope-stage25-source-import/1.0"}
    token = os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = "Bearer " + token
    with urlopen(Request(url, headers=headers), timeout=25) as response:
        result = json.load(response)
    if result.get("sha") != sha or result.get("encoding") != "base64":
        raise ValueError("GitHub blob identity or transfer encoding mismatch")
    raw = base64.b64decode(result["content"].replace("\n", ""), validate=True)
    if git_oid(raw) != sha:
        raise ValueError("Git blob payload does not match verified object SHA")
    return raw


def import_sources(manifest: dict, output_dir: Path, *,
                   fetch=download_git_blob,
                   now: datetime | None = None) -> dict:
    if manifest.get("schema") != "gingerscope-supreme-browser-import-v1":
        raise ValueError("unknown source manifest schema")
    if set(manifest.get("sources", {})) != set(PAGES):
        raise ValueError("exact three source pages required")
    now = now or datetime.now(timezone.utc)
    if now.tzinfo is None:
        raise ValueError("current time must include timezone")
    results = {}
    pending = []
    for page, slug in PAGES.items():
        entry = manifest["sources"][page]
        if (entry.get("slug") != slug or
            entry.get("url") != f"https://supremevalues.com/mm2/{slug}" or
            entry.get("statusCode") != 200 or
            not re.fullmatch(r"[0-9a-f-]{36}", str(entry.get("scrapeId", "")))):
            raise ValueError(f"wrong source identity or browser status: {page}")
        sha = entry.get("blobSha")
        if not isinstance(sha, str) or not re.fullmatch(r"[0-9a-f]{40}", sha):
            raise ValueError(f"missing immutable source digest: {page}")
        observed = moment(entry["observedAt"])
        published = moment(entry["publishedAt"])
        if (published > observed or observed > now or
                (now - observed).total_seconds() >= 86400 or
                (now - published).total_seconds() >= 72 * 3600):
            raise ValueError(f"expired, reversed or future source observation: {page}")
        data = fetch(sha)
        if not isinstance(data, bytes) or len(data) > 5*1024*1024 or git_oid(data) != sha:
            raise ValueError(f"immutable source content mismatch: {page}")
        source = data.decode("utf-8")
        if f"MM2 {page.title()} Values" not in source:
            raise ValueError(f"category page title mismatch: {page}")
        stamps = set(re.findall(r'data-updated-iso="([^"]+)"', source))
        if len(stamps) != 1 or moment(next(iter(stamps))) != published:
            raise ValueError(f"original source publication differs from receipt: {page}")
        pending.append((slug, data, observed))
        results[page] = {
            "sourcePage": entry["url"],
            "publishedAt": entry["publishedAt"],
            "observedAt": entry["observedAt"],
            "gitBlob": sha,
            "sha256": hashlib.sha256(data).hexdigest(),
            "browserReceipt": entry["scrapeId"],
            "bytes": len(data),
        }
    # All pages must validate BEFORE writing any imported source.
    output_dir.mkdir(parents=True, exist_ok=True)
    for slug, data, observed in pending:
        target = output_dir / f"pdiddler-supreme-{slug}.html"
        target.write_bytes(data)
        nanoseconds = int(observed.timestamp() * 1_000_000_000)
        os.utime(target, ns=(nanoseconds, nanoseconds))
    return results


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--manifest", type=Path, required=True)
    p.add_argument("--output-dir", type=Path, required=True)
    args = p.parse_args()
    evidence = import_sources(json.loads(args.manifest.read_text()), args.output_dir)
    print(json.dumps({
        "result": "browser-retrieved-immutable-input-verified",
        "sourceType": "third-party-browser-capture-not-direct-site-fetch",
        "pages": evidence,
    }, indent=2))


if __name__ == "__main__":
    main()
