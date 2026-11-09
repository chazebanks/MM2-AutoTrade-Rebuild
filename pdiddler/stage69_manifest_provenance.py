"""Strict, RESEARCH-ONLY import provenance for independently retrieved Supreme HTML.

The CI runner gets HTTP 403 from Supreme. A connector may acquire HTML,
preserving the acquisition-start time and the actual publisher timestamp.
Git checkout time is *never* a retrieval timestamp. Manifest + exact Git
blob bind the committed bytes; neither authenticates the site's server nor
grants item identity or trade authority.
"""
from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re

SLUGS = {"ancient": "ancients", "chroma": "chromas", "godly": "godlies"}
SCHEMA = "gingerscope-stage69-external-source-evidence-v1"
ACQUISITION = "Firecrawl rawHtml maxAge=0, not guaranteed byte-identical to origin HTTP"

def _epoch(text: object) -> int:
    if not isinstance(text, str) or not text:
        raise ValueError("manifest timestamp missing or invalid")
    try:
        parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ValueError("manifest timestamp invalid") from exc
    if parsed.utcoffset() is None:
        raise ValueError("manifest timestamp must include timezone")
    return int(parsed.timestamp())

def git_blob_sha1(content: bytes) -> str:
    header = ("blob " + str(len(content))).encode("ascii") + b"\0"
    return hashlib.sha1(header + content).hexdigest()

def read_manifest(path: Path, source_dir: Path, *, now_epoch: int | None = None) -> dict:
    """Return verified import rows by page (no data copying or live access)."""
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError("source manifest missing/malformed") from exc

    if (not isinstance(value, dict) or
        set(value) != {"schema", "purpose", "acquisition", "items"} or
        value["schema"] != SCHEMA or
        value["purpose"] != "RESEARCH_ONLY_NO_TRADE_AUTHORITY" or
        value["acquisition"] != ACQUISITION):
        raise ValueError("source manifest trust policy unexpected")
    rows = value["items"]
    if not isinstance(rows, list) or len(rows) != 3:
        raise ValueError("manifest must list exactly three category pages")
    now = int(datetime.now(timezone.utc).timestamp()) if now_epoch is None else now_epoch
    if type(now) is not int:
        raise ValueError("now_epoch must be an integer")
    result = {}
    for row in rows:
        if not isinstance(row, dict) or set(row) != {
            "page", "url", "path", "observedAt", "sourcePublisherIso",
            "sourceGitBlobSha", "scrapeId", "bytesUtf8"
        }:
            raise ValueError("manifest item has missing or extra fields")
        page = row["page"]
        if not isinstance(page, str) or page not in SLUGS or page in result:
            raise ValueError("manifest duplicate/unknown category")
        slug = SLUGS[page]
        if row["url"] != f"https://supremevalues.com/mm2/{slug}":
            raise ValueError("manifest source URL mismatch")
        exact_file = (Path(source_dir) / f"{slug}.html").resolve()
        if row["path"] != str(Path(source_dir) / f"{slug}.html"):
            raise ValueError("manifest path unexpectedly changed")
        if not exact_file.is_file():
            raise ValueError("missing committed source page")
        # Disallow symlink/outside-workspace paths, even if they happen to exist.
        if (Path(source_dir) / f"{slug}.html").is_symlink():
            raise ValueError("source page must be a regular tracked file")
        data = exact_file.read_bytes()
        if (type(row["bytesUtf8"]) is not int or
            not 25000 <= row["bytesUtf8"] <= 5 * 1024 * 1024 or
            len(data) != row["bytesUtf8"]):
            raise ValueError("source bytes inconsistent with manifest")
        sha = row["sourceGitBlobSha"]
        if not isinstance(sha, str) or not re.fullmatch("[0-9a-f]{40}", sha):
            raise ValueError("source Git blob SHA missing or invalid")
        if git_blob_sha1(data) != sha:
            raise ValueError("source Git blob mismatch")
        observed = _epoch(row["observedAt"])
        publisher = _epoch(row["sourcePublisherIso"])
        if publisher > observed or observed > now:
            raise ValueError("source publication/observation time reversed or future")
        if observed < now - 86400:
            raise ValueError("external retrieval older than 24 hours; re-fetch sources")
        if not isinstance(row["scrapeId"], str) or not row["scrapeId"]:
            raise ValueError("missing independent acquisition receipt")
        result[page] = {
            "url": row["url"],
            "content": data,
            "observedAtEpoch": observed,
            "publisher": row["sourcePublisherIso"],
            "acquisition": ACQUISITION,
        }
    if set(result) != set(SLUGS):
        raise ValueError("incomplete source category coverage")
    return result
