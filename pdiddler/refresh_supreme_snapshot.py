#!/usr/bin/env python3
"""Build a dated, research-only Supreme snapshot using Python's standard library.

Direct source mode uses original page metadata and acquisition time:
  python3 pdiddler/refresh_supreme_snapshot.py --mapping old.json

RESEARCH-ONLY external import mode is necessary when GitHub runners get HTTP
403 from Supreme. Requires committed HTML, a strict Git-blob-pinned manifest
and source acquisition time; never substitutes Git checkout mtime:
  python3 pdiddler/refresh_supreme_snapshot.py --mapping old.json \
      --input-dir pdiddler/research_source_html/stage69_2026_11_09 \
      --source-manifest pdiddler/research_source_html/stage69_2026_11_09/source_manifest.json \
      --research-only

Both acquisition paths emit JSON with no trade, Accept or deployment authority.
"""
import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
from html.parser import HTMLParser
import json
import math
from pathlib import Path
import re
import time
from urllib.request import Request, urlopen

PAGES = {"ancient": "ancients", "chroma": "chromas", "godly": "godlies"}
EXPECTED = {"ancient": 16, "chroma": 46, "godly": 128}
STABILITIES = {"Stable", "Fluctuating", "Overpaid For", "Underpaid For", "Doing Well"}
# Source pages also carry non-weapon entries. Exclude them ONLY with matching
# structural evidence: Chroma tierpets, or explicitly hidden Godly test rows.
# Any new non-weapon/hidden row is a hard failure pending manual review.
KNOWN_NONWEAPON_PETS = {"chroma": {
    "Chroma Fire Bat", "Chroma Fire Bear", "Chroma Fire Bunny",
    "Chroma Fire Cat", "Chroma Fire Dog", "Chroma Fire Fox",
    "Chroma Fire Pig",
}}
KNOWN_HIDDEN_PLACEHOLDERS = {"godly": {"Batwing", "Black Luger"}}

VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr", "sep"}


def epoch(value):
    stamp = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if stamp.tzinfo is None:
        raise ValueError("timestamp requires explicit timezone")
    return int(stamp.timestamp())


def iso(value):
    return datetime.fromtimestamp(value, timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


class Node:
    def __init__(self, tag="", attrs=()):
        self.tag, self.attrs, self.children = tag, dict(attrs), []

    def text(self):
        return " ".join(child.text() if isinstance(child, Node) else child for child in self.children).strip()

    def walk(self):
        yield self
        for child in self.children:
            if isinstance(child, Node):
                yield from child.walk()

    def has_class(self, name):
        return name in self.attrs.get("class", "").split()


class Document(HTMLParser):
    def __init__(self, text):
        super().__init__(convert_charrefs=True)
        self.root = Node()
        self.stack = [self.root]
        self.feed(text)
        self.close()

    def handle_starttag(self, tag, attrs):
        node = Node(tag, attrs)
        self.stack[-1].children.append(node)
        if tag not in VOID:
            self.stack.append(node)

    def handle_startendtag(self, tag, attrs):
        self.stack[-1].children.append(Node(tag, attrs))

    def handle_endtag(self, tag):
        for index in range(len(self.stack) - 1, 0, -1):
            if self.stack[index].tag == tag:
                del self.stack[index:]
                break

    def handle_data(self, data):
        self.stack[-1].children.append(data)


def one(nodes, description):
    if len(nodes) != 1:
        raise ValueError(f"ambiguous or missing {description}: {len(nodes)} matches")
    return nodes[0]


def number(value):
    if not re.fullmatch(r"(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?", value):
        raise ValueError(f"invalid numeric value {value!r}")
    parsed = float(value.replace(",", ""))
    if not math.isfinite(parsed) or parsed <= 0:
        raise ValueError(f"nonpositive/nonfinite value {value!r}")
    return int(parsed) if parsed.is_integer() else parsed


def parse_page(text, page):
    if page not in PAGES:
        raise ValueError(f"unknown category {page!r}")
    document = Document(text)
    nodes = list(document.root.walk())
    publications = {n.attrs["data-updated-iso"] for n in nodes if "data-updated-iso" in n.attrs}
    published = iso(epoch(one(list(publications), "publication timestamp")))
    titles = [n.text() for n in nodes if n.tag == "title"]
    if titles and (len(titles) != 1 or f"MM2 {page.title()} Values" not in titles[0]):
        raise ValueError(f"source category mismatch for {page}: {titles}")
    records, identities = [], set()
    pet_columns = {
        id(n)
        for section in nodes
        if section.tag == "section" and section.attrs.get("data-tier") == "pets"
        for n in section.walk()
        if n.has_class("itemcolumn")
    }
    for column in (n for n in nodes if n.has_class("itemcolumn")):
        descendants = list(column.walk())
        head = one([n for n in descendants if n.has_class("itemhead")], "item name").text()
        source_names = {n.attrs["data-name"].strip() for n in descendants if n.attrs.get("data-name")}
        name = one(list(source_names), "full source name") if source_names else head
        expanded_head = "Chroma " + head[3:] if page == "chroma" and head.startswith("C. ") else head
        if expanded_head.casefold() != name.casefold():
            raise ValueError(f"name/header disagreement: {head!r}, {name!r}")
        is_pet = id(column) in pet_columns
        is_hidden = bool(re.search(r"display\s*:\s*none", column.attrs.get("style", ""), re.I))
        if is_pet or is_hidden:
            if is_pet and not is_hidden and name in KNOWN_NONWEAPON_PETS.get(page, set()):
                continue
            if is_hidden and not is_pet and name in KNOWN_HIDDEN_PLACEHOLDERS.get(page, set()):
                continue
            raise ValueError(f"unreviewed excluded source row {page}:{name} pet={is_pet} hidden={is_hidden}")
        if name.casefold() in identities:
            raise ValueError(f"duplicate source identity {page}:{name}")
        identities.add(name.casefold())
        body = one([n for n in descendants if n.has_class("itembody")], "item body").text()
        value_match = re.search(r"\bValue\s*-\s*(\S+)", body)
        if not value_match:
            raise ValueError(f"missing value for {name}")
        label = value_match[1]
        value = None if label == "Priceless" else number(label)
        attribute_value = column.attrs.get("data-value")
        if attribute_value is not None and (value is None or number(attribute_value) != value):
            raise ValueError(f"value attribute/display disagreement for {name}")
        if value is not None and attribute_value is None:
            raise ValueError(f"missing numeric value metadata for {name}")
        stability = one([n for n in descendants if n.has_class("itemstability")], "stability").text()
        if stability not in STABILITIES or column.attrs.get("data-stability") != stability:
            raise ValueError(f"unknown or inconsistent stability for {name}: {stability!r}")
        demand_match = re.search(r"\bDemand\s*-\s*(\d+)\b", body)
        if not demand_match or column.attrs.get("data-demand") != demand_match[1]:
            raise ValueError(f"demand attribute/display disagreement for {name}")
        demand = int(demand_match[1])
        if not 0 <= demand <= 11:
            raise ValueError(f"demand outside verified scale for {name}: {demand}")
        records.append({"name": name, "supremeValue": value, "supremeLabel": label if value is None else None,
                        "demand": demand, "stability": stability})
    if not records:
        raise ValueError(f"no structured rows for {page}")
    return records, published


def load_mapping(path):
    text = Path(path).read_text()
    if Path(path).suffix == ".json":
        data = json.loads(text)
        rows = data["rows"] if isinstance(data, dict) else data
        return [{k: row[k] for k in ("page", "id", "name")} for row in rows]
    pattern = r'^add\("(ancient|chroma|godly)","(\d+)",[^,]+,("(?:[^"\\]|\\.)*")'
    rows = [{"page": p, "id": identity, "name": json.loads(name)} for p, identity, name in re.findall(pattern, text, re.M)]
    if not rows:
        raise ValueError("canonical mapping is empty or unsupported")
    return rows


def map_rows(mapping, pages):
    identities, names = set(), set()
    for row in mapping:
        key, named = (row["page"], row["id"]), (row["page"], row["name"].casefold())
        if key in identities or named in names:
            raise ValueError(f"duplicate canonical mapping {key}")
        identities.add(key)
        names.add(named)
    mapped = []
    for row in mapping:
        matches = [r for r in pages.get(row["page"], []) if r["name"].casefold() == row["name"].casefold()]
        if len(matches) != 1:
            raise ValueError(f"unmapped or ambiguous canonical item {row}: {len(matches)} source rows")
        source = matches[0]
        mapped.append({**source, **row, "sourceName": source["name"], "sourceRecordMatched": True})
    return mapped


def expiry(sources):
    return min(min(epoch(s["observedAt"]) + 24 * 3600, epoch(s["publishedAt"]) + 72 * 3600) for s in sources.values())


def quarantine_research_only(snapshot, *, source_acquisition="EXTERNAL_SCRAPE_REVIEW_ONLY"):
    """Keep verified source rows separate from UNVERIFIED game raw IDs.

    Canonical checker IDs in the old snapshot are NOT independent proof that
    a raw Sync.Weapons key maps to that exact item/variant. Never allow the
    old generic 'verified' field to be used as trade-price authority.
    """
    if not isinstance(snapshot, dict) or not isinstance(snapshot.get("rows"), list):
        raise ValueError("research candidate missing rows")
    for row in snapshot["rows"]:
        if row.get("sourceRecordMatched") is not True:
            raise ValueError("source row was not checked")
        row.update({
            "verified": False,
            "rawGameMappingVerified": False,
            "priceForTradeVerified": False,
        })
    snapshot.update({
        "researchOnly": True, "authorizesTrade": False,
        "authorizesAccept": False, "autoDeploy": False, "liveReady": False,
        "sourceAcquisition": source_acquisition,
        "sourceRowsMatched": True, "rawGameMappingsVerified": False,
    })
    return snapshot


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--mapping", type=Path, required=True, help="previous generated JSON or canonical old-profile Lua")
    parser.add_argument("--input-dir", type=Path, help="research-only imported HTML directory; requires pinned source manifest")
    parser.add_argument("--source-manifest", type=Path, help="strict external source receipt with exact Git blob and observedAt timestamps")
    parser.add_argument("--research-only", action="store_true", help="required for manifest imports; all output is research-only JSON")
    parser.add_argument("--date", default=datetime.now(timezone.utc).date().isoformat(), help="output date YYYY-MM-DD")
    parser.add_argument("--output-dir", type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    datetime.strptime(args.date, "%Y-%m-%d")
    if bool(args.input_dir) != bool(args.source_manifest):
        raise ValueError("input directory and source manifest must be supplied together")
    if args.input_dir and not args.research_only:
        raise ValueError("externally retrieved sources must stay research-only")
    imported = None
    if args.input_dir:
        from stage69_manifest_provenance import read_manifest
        imported = read_manifest(args.source_manifest, args.input_dir)
    mapping = load_mapping(args.mapping)
    if dict(Counter(row["page"] for row in mapping)) != EXPECTED:
        raise ValueError("canonical checker coverage must be exactly ancient=16/chroma=46/godly=128")
    pages, sources = {}, {}
    for page, slug in PAGES.items():
        url = f"https://supremevalues.com/mm2/{slug}"
        if imported is not None:
            content = imported[page]["content"]
            # Never substitute Git checkout mtime for the source acquisition time.
            observed = imported[page]["observedAtEpoch"]
        else:
            request = Request(url, headers={"User-Agent": "pdiddler-snapshot-refresh/1.0", "Cache-Control": "no-cache"})
            with urlopen(request, timeout=30) as response:
                content = response.read(5 * 1024 * 1024 + 1)
                if len(content) > 5 * 1024 * 1024:
                    raise ValueError("source exceeds bounded download size")
            observed = int(time.time())
        text = content.decode("utf-8")
        if f"MM2 {page.title()} Values" not in text:
            raise ValueError(f"missing verified category title in {url}")
        pages[page], published = parse_page(text, page)
        if imported is not None and epoch(published) != epoch(imported[page]["publisher"]):
            raise ValueError(f"external source publisher clock mismatch for {page}")
        if len(pages[page]) != EXPECTED[page]:
            raise ValueError(f"unexpected visible eligible source rows for {page}: {len(pages[page])} != {EXPECTED[page]}")
        if epoch(published) > observed or observed > int(time.time()):
            raise ValueError(f"source timestamp in the future: {url}")
        sources[page] = {"url": url, "observedAt": iso(observed), "publishedAt": published,
                         "sha256": hashlib.sha256(content).hexdigest()}
    rows = map_rows(mapping, pages)
    expires = expiry(sources)
    if int(time.time()) >= expires:
        raise ValueError("source retrieval exceeds 24h or publication exceeds 72h; obtain current sources")
    finite = [row for row in rows if row["supremeValue"] is not None]
    coverage = {**EXPECTED, "total": len(rows), "finite": len(finite), "unpriced": len(rows) - len(finite)}
    for page in PAGES:
        coverage[page + "Finite"] = sum(row["page"] == page for row in finite)
    version_hash = hashlib.sha256(json.dumps(sources, sort_keys=True).encode()).hexdigest()[:12]
    snapshot = {"schemaVersion": 1, "version": f"supreme-{args.date}-{version_hash}", "snapshotDate": args.date,
                "observedAt": min(s["observedAt"] for s in sources.values()),
                "publishedAt": min(s["publishedAt"] for s in sources.values()), "expiresAt": iso(expires),
                "coverage": coverage, "sources": sources, "rows": rows}
    args.output_dir.mkdir(parents=True, exist_ok=True)
    suffix = args.date.replace("-", "_")
    json_path = args.output_dir / f"supreme_snapshot_{suffix}.json"
    acquisition = ("EXTERNAL_SCRAPE_REVIEW_ONLY" if imported is not None
                   else "DIRECT_SUPREME_FETCH_REVIEW_ONLY")
    snapshot = quarantine_research_only(snapshot, source_acquisition=acquisition)
    json_path.write_text(json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"files": [str(json_path)], "coverage": coverage,
                      "researchOnly": True,
                      "observedAt": snapshot["observedAt"],
                      "publishedAt": snapshot["publishedAt"],
                      "expiresAt": snapshot["expiresAt"]}, indent=2))


if __name__ == "__main__":
    main()
