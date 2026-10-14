"""One table per camera of what the calibration loop measured on every pair: RetroSnap against the reference
(median ΔE2000, `compare.py`), the fit's own median, parity, the grain ratio (`grain.py`), the face where the
picture has one (`face.py`) and the whites where the picture has them (`whites.py`), from the renders
`ReferencePairTests` wrote.

    venv/bin/python -I tools/report.py [<id> ...] [--json <file>]

`--json` also writes the numbers, so a before and an after can be laid side by side.
"""
import contextlib
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compare  # noqa: E402
import face  # noqa: E402
import grain  # noqa: E402
import whites  # noqa: E402
from pairs import CAMERAS, INPUTS, pairs as pairs_of, suffix_of  # noqa: E402

R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ref", "pairs")


def captured(fn, *args):
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        fn(*args)
    return buffer.getvalue()


def main(argv):
    json_path = argv[argv.index("--json") + 1] if "--json" in argv else None
    cams = [a for a in argv if not a.startswith("--") and (argv.index(a) == 0 or argv[argv.index(a) - 1] != "--json")] or CAMERAS
    everything = {}
    for cam in cams:
        rows = {}
        for pair in pairs_of(cam):
            if not os.path.exists(os.path.join(R, pair + "-retrosnap.png")):
                continue
            text = captured(compare.main, os.path.join(R, pair))
            numbers = {m.group(1).strip(): float(m.group(2)) for m in re.finditer(r"^\s+(.+?)\s+median\s+([\d.]+)", text, re.M)}
            g = captured(grain.main, os.path.join(R, pair))
            ratio = re.search(r"grain ratio RetroSnap/reference at mid grey: ([\d.]+)", g)
            detail = re.search(r"detail kept middle \(r < 0.5\)\s*: reference ([\d.]+) of the input's \| RetroSnap ([\d.]+)", g)
            rows[pair] = {"picture": INPUTS[suffix_of(pair)][0], "retrosnap": numbers.get("RetroSnap vs reference"),
                          "fit": numbers.get("fit vs reference"), "parity": numbers.get("RetroSnap vs fit (parity)"),
                          "grain_ratio": float(ratio.group(1)) if ratio else None,
                          "detail_ref": float(detail.group(1)) if detail else None, "detail_ours": float(detail.group(2)) if detail else None}
        f = captured(face.main, [cam, "--render"])
        for m in re.finditer(r"^(\S+)\s+(\S+)\s+\S+\s+median dE [\d.]+ \| face \(n (\d+)\): reference L ([\d.]+) a ([+-][\d.]+) b ([+-][\d.]+) \| RetroSnap L ([\d.]+) a ([+-][\d.]+) b ([+-][\d.]+) \| diff dL ([+-][\d.]+) da ([+-][\d.]+) db ([+-][\d.]+) \| face dE ([\d.]+)", f, re.M):
            pair = m.group(2)
            if pair in rows:
                rows[pair]["face"] = {"n": int(m.group(3)), "dL": float(m.group(10)), "da": float(m.group(11)), "db": float(m.group(12)), "dE": float(m.group(13))}
        wtext = captured(whites.main, [cam])
        for m in re.finditer(r"^(\S+)\s+(\S+)\s+(.+?)\s+\(n\s+(\d+)\): reference L\s+([\d.]+) a ([+-][\d.]+) b ([+-][\d.]+) \| RetroSnap L\s+([\d.]+) a ([+-][\d.]+) b ([+-][\d.]+) \| diff dL ([+-][\d.]+) da ([+-][\d.]+) db ([+-][\d.]+) \| dE ([\d.]+)", wtext, re.M):
            pair = m.group(2)
            if pair in rows:
                rows[pair]["whites"] = {"what": m.group(3).strip(), "dL": float(m.group(11)), "da": float(m.group(12)), "db": float(m.group(13)), "dE": float(m.group(14))}
        everything[cam] = rows
        print(f"{cam}")
        print(f"   {'pair':15s} {'picture':9s} {'ours':>5s} {'fit':>5s} {'parity':>6s} {'grain':>5s} {'detail ref/ours':>15s}  face (dL da db, dE)          whites (dL da db, dE)")
        for pair, r in rows.items():
            fc = r.get("face"); wh = r.get("whites")
            face_s = f"{fc['dL']:+.1f} {fc['da']:+.1f} {fc['db']:+.1f}, {fc['dE']:.1f}" if fc else ""
            white_s = f"{wh['what']}: {wh['dL']:+.1f} {wh['da']:+.1f} {wh['db']:+.1f}, {wh['dE']:.1f}" if wh else ""
            detail_s = f"{r['detail_ref']:.2f}/{r['detail_ours']:.2f}" if r["detail_ref"] is not None else ""
            print(f"   {pair:15s} {r['picture']:9s} {r['retrosnap']:5.2f} {r['fit']:5.2f} {r['parity']:6.2f} {r['grain_ratio'] if r['grain_ratio'] is not None else float('nan'):5.2f} {detail_s:>15s}  {face_s:28s} {white_s}")
        print()
    if json_path:
        json.dump(everything, open(json_path, "w"), indent=1)


if __name__ == "__main__":
    main(sys.argv[1:])
