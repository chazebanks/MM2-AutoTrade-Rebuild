"""Offline research consistency checks. No performance backtest is claimed."""
import csv
import hashlib
import itertools
import json
import math
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[2]
notes = root / "research-notes"
data = json.loads((notes / "MARKET_DATA_2026-11-03.json").read_text())
with (notes / "ELIGIBLE_ITEM_MARKET_MATRIX_2026-11-03.csv").open() as file:
    csv_rows = list(csv.DictReader(file))
rows = data["rows"]
assert len(csv_rows) == len(rows) == 190
assert len({(r["canonical_page"],r["checker_id"]) for r in rows}) == 190
assert sum(r["supreme_value"] is not None for r in rows) == 189
assert sum(bool(r["mm2_minus_supreme"]) for r in rows) == 118
assert all(r["raw_executor_id"] == "" and r["realized_liquidity"] == "UNVERIFIED" for r in rows)
assert sum(bool(r["flippability"]) for r in rows) == 5
assert sum(bool(r["weapon_type"]) for r in rows) == 166
for row in rows:
    if row["supreme_value"] is not None:
        assert math.isfinite(row["supreme_value"]) and row["supreme_value"] > 0
        assert abs(row["mm2_minus_supreme"]-(row["mm2_value"]-row["supreme_value"])) < 1e-8
    else:
        assert row["supreme_label"] == "Priceless" and row["cross_list_disagreement_pct"] is None
histories = json.loads((notes / "PUBLISHER_HISTORY_2026-11-03.json").read_text())
assert len(histories) == 5 and sum(len(v["series"]) for v in histories.values()) == 801
assert all(not w["full_window_available"] and w["change_pct"] is None for w in histories["Embersickle"]["windows"])
assert abs(histories["Watergun"]["windows"][2]["change_pct"]+42)<1e-8
assert abs(histories["Gingerscope"]["windows"][2]["change_pct"]+11.2676056338)<1e-8
for n in (15,50,100):
    assert math.ceil(10750/n) == {15:717,50:215,100:108}[n]
fixture = json.loads((notes / "STRATEGY_COMPARISON_FIXTURES.json").read_text())
values = {r["id"]:r["value"] for r in fixture["inventory"]}
expected = {tuple(p["give"]) for p in fixture["all_safe_plans"]}
actual = {p for n in range(1,5) for p in itertools.combinations(values,n) if 100-sum(values[k] for k in p)>=15}
assert expected == actual
for name, picks in fixture["defined_policy_examples"].items():
    assert tuple(picks) in actual and len(picks)<=4
assert fixture["acceptance_probabilities"] is None and fixture["observed_completions"] is None
extras = json.loads((notes / "UNMAPPED_SOURCE_ROWS_2026-11-03.json").read_text())
assert len(extras)==9 and sum(x["source_hidden"] for x in extras)==2
# Protected checkpoint covers every prior blob, not only the files read in research.
for line in subprocess.check_output(["git","ls-tree","-r","4b5c6d9095d21643349cee32d43719e515e294d1"],cwd=root).decode().splitlines():
    meta,path=line.split("\t"); sha=meta.split()[2]; raw=(root/path).read_bytes()
    assert hashlib.sha1(b"blob "+str(len(raw)).encode()+b"\0"+raw).hexdigest()==sha,path
changes = subprocess.check_output(["git","diff","--name-only","4b5c6d9095d21643349cee32d43719e515e294d1"],cwd=root).decode().splitlines()
assert all(path.startswith("research-notes/") for path in changes)
spec = (notes / "PDIDDLER_TRADING_STRATEGY_SPEC.md").read_text().lower()
assert "gingerscope" not in spec
print("PASS 190-row/189-price consistency; exact identity joins; missing-data flags; 801 publisher records")
print("PASS reproducible window arithmetic, synthetic feasible plans and hypothetical roadmap arithmetic")
print("PASS all protected engineering blobs unchanged; documentation-only paths; no personal target in strategy spec")
