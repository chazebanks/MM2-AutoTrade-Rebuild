"""Plot published list estimates; no external requests or trader imports."""
from datetime import datetime
import json
import os
from pathlib import Path
import tempfile

os.environ.setdefault("MPLCONFIGDIR", str(Path(tempfile.gettempdir()) / "mm2-research-mpl"))
os.environ.setdefault("XDG_CACHE_HOME", str(Path(tempfile.gettempdir()) / "mm2-research-cache"))

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.dates as dates

root = Path(__file__).resolve().parents[1]
data = json.loads((root / "PUBLISHER_HISTORY_2026-11-03.json").read_text())
start, end = datetime(2026, 8, 5), datetime(2026, 11, 3)
fig, axes = plt.subplots(2, 1, figsize=(10, 7), layout="constrained")
for name in ("Gingerscope", "Watergun", "Harvester", "Evergun"):
    points = sorted((datetime.fromisoformat(p["t"]), p["v"]) for p in data[name]["series"])
    base = [v for t, v in points if t <= start][-1]
    sample = [(start, base)] + [(t,v) for t,v in points if start < t <= end]
    sample += [(end, sample[-1][1])]
    axes[0].step([p[0] for p in sample], [100*p[1]/base for p in sample], where="post", label=name)
axes[0].set_title("Publisher list estimates: August 5 = 100")
axes[0].set_ylabel("List-price index")
axes[0].legend(ncol=2)
pts = [(datetime.fromisoformat(p["t"]), p["v"]) for p in data["Embersickle"]["series"]]
axes[1].step([p[0] for p in pts], [p[1] for p in pts], where="post", color="#a13f29")
axes[1].set_title("New-item series: Embersickle (no complete 30-day window)")
axes[1].set_ylabel("Supreme list units")
for ax in axes:
    ax.grid(alpha=.2)
    ax.xaxis.set_major_formatter(dates.DateFormatter("%b %d"))
fig.suptitle("MM2 published-price histories — not realized trade prices", fontsize=14)
fig.supxlabel("Publisher calendar timestamps; timezone unspecified. Cutoff: November 3, 2026.")
fig.savefig(root / "PUBLISHER_HISTORY_90D.svg", metadata={"Date": None})

path = root / "PUBLISHER_HISTORY_90D.svg"
path.write_text("\n".join(line.rstrip() for line in path.read_text().splitlines()) + "\n")
