"""Measure a reproducible paper-search workload in a fresh Linux process."""
import argparse
import json
import os
from pathlib import Path
import platform
import resource
from time import perf_counter, process_time

from pdiddler.system2.manual_portfolio_review import DEFAULT_CATALOG, analyze
from pdiddler.system2.portfolio_planner import MAX_PAIRS, plan
from pdiddler.system2.supreme_market_editions import load_edition


CLOCK = "2026-11-25T07:52:05Z"


def _shortlist(catalog, legacy):
    main = dict.fromkeys(("godly:Fang", "godly:Chill", "godly:Clockwork", "godly:Heat"), 4)
    partner = dict.fromkeys(("godly:Gemstone", "godly:Plasmabeam", "godly:Slasher", "godly:Green_Luger"), 4)
    if legacy:
        return analyze(catalog, {"accounts": {"main": main, "alt": {}}, "comparison": {
            "mainItemTypes": list(main), "counterpartyStock": partner,
        }}, evaluated_at_utc=CLOCK)["comparison"]
    return plan(catalog, main, [partner], evaluated_at_utc=CLOCK, copies_per_slot=4,
                max_steps=1, max_bundles_per_side=624)["search"]


def _large(catalog, worst_case):
    edition = load_edition(catalog, evaluated_at_utc=CLOCK)
    items = sorted(f"{row['category']}:{row['officialItemId']}" for row in edition.rows.values())
    main = dict.fromkeys(items[:90], 4)
    partners = [dict.fromkeys(items[90 + offset:165 + offset], 4) for offset in range(12)]
    return plan(catalog, main, partners, evaluated_at_utc=CLOCK, edition=edition,
                max_pairs=MAX_PAIRS if worst_case else 20_000,
                max_bundles_per_side=1_024 if worst_case else 256,
                copies_per_slot=4 if worst_case else 1)["search"]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("workload", choices=("legacy", "bounded", "large", "maximum"))
    args = parser.parse_args(argv)
    catalog = DEFAULT_CATALOG.read_bytes()
    wall, cpu = perf_counter(), process_time()
    counts = (_shortlist(catalog, args.workload == "legacy") if args.workload in {"legacy", "bounded"}
              else _large(catalog, args.workload == "maximum"))
    cpu, wall = process_time() - cpu, perf_counter() - wall
    model = next((line.split(":", 1)[1].strip() for line in Path("/proc/cpuinfo").read_text().splitlines()
                  if line.startswith("model name")), platform.machine())
    print(json.dumps({
        "workload": args.workload, "catalog_evaluated_at": CLOCK, "cpu_model": model,
        "allowed_logical_cpus": len(os.sched_getaffinity(0)), "python": platform.python_version(),
        "wall_seconds": round(wall, 6), "cpu_seconds": round(cpu, 6),
        "process_peak_rss_kib": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        "counts": {key: value for key, value in counts.items() if key != "alternatives"},
    }, sort_keys=True))


if __name__ == "__main__":
    main()
