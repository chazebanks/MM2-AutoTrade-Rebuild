# Stage69: research-only copy of prior Stage26 Supreme structured parser.
# Original commit a2a2e601be864f970da0a69c436ab3b12efd8112.
# This library has NO publisher, source fetcher, or live profile formatter.
#!/usr/bin/env python3
"""Build a dated Supreme-only snapshot using Python's standard library.

Refresh from public sources, keeping canonical checker IDs from an existing snapshot:
  python3 pdiddler/refresh_supreme_snapshot.py --mapping pdiddler/supreme_snapshot_2026_11_03.json

Import previously downloaded pages without resetting their retrieval timestamps:
  python3 pdiddler/refresh_supreme_snapshot.py --mapping old.lua --input-dir /tmp

Local files must be pdiddler-supreme-{ancients,chromas,godlies}.html. Their preserved
mtime is the observation time. Only structured rows and provenance are written;
the downloaded HTML is never included in the generated artifacts.
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
        mapped.append({**source, **row, "sourceName": source["name"], "verified": True})
    return mapped


def expiry(sources):
    return min(min(epoch(s["observedAt"]) + 24 * 3600, epoch(s["publishedAt"]) + 72 * 3600) for s in sources.values())


