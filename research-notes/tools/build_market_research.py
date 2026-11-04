"""Offline research transformation; never imported by the Delta trader.

Use previously retrieved HTML in --input-dir. Does not crawl, refresh, or grant
permission to reuse a publisher's feed. See the report's access/rights limits.
"""
import argparse
import csv
from datetime import datetime, timedelta
import hashlib
import importlib.util
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("snapshot_parser", ROOT / "pdiddler/refresh_supreme_snapshot.py")
R = importlib.util.module_from_spec(spec)
spec.loader.exec_module(R)


def popup(text):
    result = {}
    for match in re.finditer(r"_svPopup\s*=\s*", text):
        try:
            obj, _ = json.JSONDecoder().raw_decode(text[match.end():])
        except ValueError:
            continue
        result.update(obj)
    return result


def history_summary(series, days):
    # Source timestamps lack explicit offsets. Calendar-relative publisher series,
    # not exact UTC execution times, and never a series of settled trade prices.
    end = datetime(2026, 11, 3)
    start = end - timedelta(days=days)
    ordered = sorted((datetime.fromisoformat(p["t"]), p["v"]) for p in series)
    before = [(t, v) for t, v in ordered if t <= start]
    within = [(t, v) for t, v in ordered if start < t <= end]
    last = [(t, v) for t, v in ordered if t <= end]
    base = before[-1][1] if before else None
    vals = ([base] if base is not None else []) + [v for _, v in within]
    return {"days": days, "cutoff": start.isoformat(), "end": end.isoformat(),
            "start_value": base, "end_value": last[-1][1] if last else None,
            "change_pct": (last[-1][1] / base - 1) * 100 if base and last else None,
            "min_value": min(vals) if vals else None, "max_value": max(vals) if vals else None,
            "change_records": len(within), "full_window_available": bool(before),
            "method": "publisher-event-series; last observation carried forward; timezone unspecified"}


def value_after(text, label):
    m = re.search(r"\b" + label + r"\s*[-:]\s*([\d,.]+)", text)
    return float(m[1].replace(",", "")) if m else None


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--input-dir", type=Path, required=True)
    ap.add_argument("--output-dir", type=Path, default=ROOT / "research-notes")
    args = ap.parse_args()
    inputs, output = args.input_dir, args.output_dir
    mapping = json.loads((ROOT / "pdiddler/supreme_snapshot_2026_11_03_ISSUE4.json").read_text())["rows"]
    metadata = {r["key"]: r for r in json.loads((inputs / "metadata.json").read_text())}
    pages = {"ancient": "supreme-ancients-all.raw.html", "godly": "supreme-godlies.html", "chroma": "supreme-chromas.html"}
    current, published, details = {}, {}, {}
    publication_basis = {}
    for page, filename in pages.items():
        html = (inputs / filename).read_text()
        parse_html = html
        publication_basis[page] = "new raw category capture"
        if "data-updated-iso=" not in html:
            earlier = (inputs / ("reused-supreme-" + {"godly":"godlies", "chroma":"chromas"}[page] + ".raw.html")).read_text()
            stamp = re.search(r'data-updated-iso=["\']([^"\']+)', earlier)[1]
            parse_html += '<meta data-updated-iso="' + stamp + '">'
            publication_basis[page] = "reused same-day raw category timestamp; fresh processed rows omit stamp"
        rows, published[page] = R.parse_page(parse_html, page)
        current[page] = rows
        for column in (n for n in R.Document(html).root.walk() if n.has_class("itemcolumn")):
            all_nodes = list(column.walk())
            names = {n.attrs["data-name"] for n in all_nodes if n.attrs.get("data-name")}
            if not names:
                names = {n.text() for n in all_nodes if n.has_class("itemhead")}
            if len(names) != 1:
                continue
            text = column.text()
            def field(cls):
                return next((n.text() for n in all_nodes if n.has_class(cls)), "")
            details[(page, next(iter(names)).casefold())] = {
                "rarity": column.attrs.get("data-rarity", ""), "range_text": field("itemrange"),
                "origin": field("itemorigin"), "event": column.attrs.get("data-event", ""),
                "year": column.attrs.get("data-year", ""), "last_change_pct": column.attrs.get("data-changepct", ""),
                "last_change_value": field("sv-diff-pos") or field("sv-diff-neg"),
                "class": re.search(r"Class\s*-\s*(Ancient|Godly)", text)[1] if re.search(r"Class\s*-\s*(Ancient|Godly)", text) else page.title() if page != "chroma" else "",
                "source_hidden": "display:none" in column.attrs.get("style", "").replace(" ", ""),
                "source_image_key": next((n.attrs.get("data-image", "") for n in all_nodes if n.attrs.get("data-image")), ""),
            }
    mapped = R.map_rows([{k: r[k] for k in ("page", "id", "name")} for r in mapping], current)
    assert len(mapped) == 190 and len({(r["page"], r["id"]) for r in mapped}) == 190
    mm2, types = {}, {}
    for page in pages:
        html = (inputs / f"mm2-{page}.html").read_text()
        for card in (n for n in R.Document(html).root.walk() if n.has_class("stackable")):
            ids = {re.fullmatch(r"i(\d+)", n.attrs.get("id", ""))[1]
                   for n in card.walk() if re.fullmatch(r"i(\d+)", n.attrs.get("id", ""))}
            if len(ids) != 1:
                continue
            identity = next(iter(ids)); txt = card.text()
            mm2[page, identity] = {"value": value_after(txt, "Value"), "demand": value_after(txt, "Demand"),
                "name": next((n.text() for n in card.walk() if n.tag == "b"), ""),
                "stability": re.search(r"Stability:\s*(.*?)\s*(?:SV|Wiki|$)", txt)[1] if re.search(r"Stability:\s*(.*?)\s*(?:SV|Wiki|$)", txt) else ""}
        for typ in ("gun", "knife"):
            text = (inputs / f"mm2-{page}-{typ}.html").read_text()
            for identity in re.findall(r'id=["\']i(\d+)["\']', text):
                types.setdefault((page, identity), set()).add(typ)
    extras, histories = {}, {}
    for key in ("supreme-ginger-raw", "supreme-harvester-raw", "supreme-embersickle-raw", "supreme-watergun-raw", "supreme-evergun-raw"):
        for name, data in popup((inputs / (key + ".raw.html")).read_text()).items():
            extras[name.casefold()] = data
            series = data.get("history", [])
            histories[name] = {"source_url": metadata[key]["url"], "observed_date": "2026-11-03", "series": series,
                "windows": [history_summary(series, n) for n in (30, 60, 90)]}
    matrix = []
    for row in mapped:
        page, identity, name = row["page"], row["id"], row["name"]
        detail = details[page, row["sourceName"].casefold()]
        cross = mm2.get((page, identity), {})
        extra = extras.get(name.casefold(), {})
        sv, mv = row["supremeValue"], cross.get("value")
        typ = types.get((page, identity), set())
        missing = []
        if len(typ) != 1: missing.append("weapon_type_unverified")
        if not extra.get("flippability"): missing.append("flippability_not_retrieved_permission_limit")
        if name not in histories: missing.append("history_not_retrieved")
        if sv is None: missing.append("priceless_not_numeric")
        if mv is None: missing.append("mm2_value_missing")
        missing += ["raw_executor_id_live_only", "realized_liquidity_unknown", "mm2_publication_time_unavailable"]
        bounds = re.findall(r"[\d,]+(?:\.\d+)?", detail["range_text"])
        range_low, range_high = ([float(x.replace(",", "")) for x in bounds] if len(bounds) == 2 else (None, None))
        source_key = {"ancient": "supreme-ancients-all", "godly": "supreme-godlies", "chroma": "supreme-chromas"}[page]
        result = {"canonical_page": page, "checker_id": identity, "canonical_name": name,
            "source_name": row["sourceName"], "weapon_type": next(iter(typ)).title() if len(typ) == 1 else "",
            "raw_executor_id": "", "live_tradability": "UNVERIFIED; canonical coverage is not native eligibility proof",
            "class": detail["class"], "supreme_value": sv, "supreme_label": row["supremeLabel"] or "",
            "demand": row["demand"], "rarity": detail["rarity"], "stability": row["stability"],
            "range_text": detail["range_text"], "range_low": range_low, "range_high": range_high,
            "flippability": extra.get("flippability", ""), "aliases": extra.get("aliases", ""),
            "publisher_rise_chance_text": extra.get("riseChance", ""),
            "origin": detail["origin"], "event": detail["event"], "event_year": detail["year"],
            "circulating_supply": "UNVERIFIED", "last_change_value": detail["last_change_value"],
            "last_change_pct": detail["last_change_pct"], "supreme_publication_utc": published[page],
            "publication_basis": publication_basis[page],
            "observed_date_utc": "2026-11-03", "supreme_url": metadata[source_key]["url"],
            "supreme_source_sha256": hashlib.sha256((inputs / pages[page]).read_bytes()).hexdigest(),
            "mm2_value": mv, "mm2_demand": cross.get("demand"), "mm2_source_name": cross.get("name", ""),
            "mm2_url": metadata["mm2-"+page]["url"], "mm2_minus_supreme": mv-sv if mv is not None and sv else None,
            "cross_list_disagreement_pct": (mv/sv-1)*100 if mv is not None and sv else None,
            "realized_liquidity": "UNVERIFIED", "confidence": "primary_publication_snapshot; not trade proof",
            "missing_data_flags": ";".join(missing)}
        matrix.append(result)
    assert sum(r["supreme_value"] is not None for r in matrix) == 189
    summary = {"canonical_rows": len(matrix), "finite_prices": 189,
        "mm2_matches": sum(r["mm2_value"] is not None for r in matrix),
        "weapon_type_known": sum(bool(r["weapon_type"]) for r in matrix),
        "cross_list_nonzero_discrepancies": sum(bool(r["mm2_minus_supreme"]) for r in matrix),
        "flippability_observed": sum(bool(r["flippability"]) for r in matrix),
        "range_observed": sum(r["range_low"] is not None for r in matrix),
        "histories": len(histories), "history_records": sum(len(x["series"]) for x in histories.values()),
        "publication_times": published}
    unmapped = []
    known = {(r["page"],r["name"].casefold()) for r in mapped}
    for page, rows in current.items():
        for row in rows:
            if (page,row["name"].casefold()) not in known:
                unmapped.append({"page":page,"source_name":row["name"],"supreme_value":row["supremeValue"],
                    "class":details[page,row["name"].casefold()]["class"],
                    "source_hidden":details[page,row["name"].casefold()]["source_hidden"],
                    "source_image_key":details[page,row["name"].casefold()]["source_image_key"],
                    "status":"UNMAPPED; inspect class/native tradability; do not invent checker/raw ID"})
    summary["extra_source_rows_outside_mapping"] = len(unmapped)
    output.mkdir(parents=True, exist_ok=True)
    with (output / "ELIGIBLE_ITEM_MARKET_MATRIX_2026-11-03.csv").open("w", newline="") as file:
        w = csv.DictWriter(file, fieldnames=list(matrix[0]), lineterminator="\n"); w.writeheader(); w.writerows(matrix)
    (output / "MARKET_DATA_2026-11-03.json").write_text(json.dumps({"summary": summary, "rows": matrix}, indent=2)+"\n")
    (output / "PUBLISHER_HISTORY_2026-11-03.json").write_text(json.dumps(histories, indent=2)+"\n")
    (output / "UNMAPPED_SOURCE_ROWS_2026-11-03.json").write_text(json.dumps(unmapped, indent=2)+"\n")
    print(json.dumps(summary, indent=2))
    for name, history in histories.items(): print(name, history["windows"])


if __name__ == "__main__":
    main()
