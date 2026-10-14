"""Choose each camera's table prior and smoothness from leave-one-out runs: the setting whose held-out medians
(the table fitted on the other pictures, measured on the one left out) have the smallest mean, and among
settings within 0.05 of that, the lowest prior (less regularisation never fits the seen pictures worse). The
held-out median is what a picture the camera has never seen will get, so it, not the gap between fitted and
held-out, is what generalisation means; the gap shrinks just as well by fitting worse.

    venv/bin/python -I tools/pickprior.py <dir with <id>-p<prior>-s<smooth>.txt from loo.py> [<id> ...]

Prints a table per camera (setting, mean held-out, worst held-out, per picture) and the pick.
"""
import os
import re
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pairs import NAMES  # noqa: E402


def main(argv):
    folder, cams = argv[0], argv[1:]
    runs = {}
    for name in sorted(os.listdir(folder)):
        m = re.fullmatch(r"(\w+)-p(\d+)-s(\d+)\.txt", name)
        if not m:
            continue
        cam = m.group(1)
        if cams and cam not in cams:
            continue
        text = open(os.path.join(folder, name)).read()
        head = re.search(r"\(prior ([\d.]+), smooth ([\d.]+)", text)
        rows = re.findall(r"^\s+(\S+)\s+\S+\s+fitted\s+([\d.]+)\s+held-out\s+([\d.]+)", text, re.M)
        if not head or not rows:
            continue
        fitted = [float(r[1]) for r in rows]
        held = [float(r[2]) for r in rows]
        runs.setdefault(cam, []).append((float(head.group(1)), float(head.group(2)), statistics.mean(fitted), statistics.mean(held), max(held), rows))
    picks = {}
    for cam, settings in runs.items():
        settings.sort()
        best = min(s[3] for s in settings)
        candidates = [s for s in settings if s[3] <= best + 0.05]
        pick = min(candidates, key=lambda s: (s[0], s[1]))
        picks[cam] = (pick[0], pick[1])
        print(f"\n{NAMES.get(cam, cam)} ({cam}): prior / smooth -> mean held-out, worst held-out")
        for prior, smooth, mf, mh, worst, rows in settings:
            mark = "  <- pick" if (prior, smooth) == picks[cam] else ""
            print(f"  {prior:>4g} / {smooth:<4g}  {mh:5.2f}  {worst:5.2f}   held-out per picture: " + " ".join(f"{float(r[2]):.2f}" for r in rows) + mark)
    print("\npicks: " + " ".join(f"{cam}={p}/{s:g}" for cam, (p, s) in picks.items()))


if __name__ == "__main__":
    main(sys.argv[1:])
