"""One table per camera for the refinement round, from the files the round wrote under `ref/pairs/refine/`: the
median on every picture before and after, the floor and whether the after is within 0.5 of it, the held-out
median of the leave-one-out, the face, the whites, the grain ratio, the clipping, then the camera's halation,
blur, prior, the residual's largest remaining structure and the banding. Markdown, for the plan and the owner.

    venv/bin/python -I tools/roundtable.py [<id> ...] [--before <before.json>] [--after <after.json>]

Missing files leave a dash, so it runs on a half-finished round too.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pairs import NAMES, pairs  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
REFINE = os.path.join(ROOT, "ref", "pairs", "refine")
ORDER = ["negative", "plastic35", "slide", "mediumFormat", "tlr", "film", "inst", "compactPro", "classicSLR", "instSquare"]


def read(name):
    path = os.path.join(REFINE, name)
    return open(path).read() if os.path.exists(path) else ""


def load_json(name):
    path = os.path.join(REFINE, name)
    return json.load(open(path)) if os.path.exists(path) else {}


def floors(text):
    out = {}
    for m in re.finditer(r"^(\S+)\s+\S+\s+([\d.]+)\s+([\d.]+)\s+([+-][\d.]+)", text, re.M):
        out[m.group(1)] = (float(m.group(2)), float(m.group(3)))
    return out


def held_out(cam):
    rounds = [n for n in os.listdir(REFINE) if re.fullmatch(rf"{cam}-loo(-p\d)?\.txt", n)] if os.path.isdir(REFINE) else []
    if os.path.exists(os.path.join(REFINE, f"{cam}-loo-pick.txt")):
        last = f"{cam}-loo-pick.txt"  # the run at the prior `pickprior.py` chose
    elif rounds:
        last = sorted(rounds)[-1]  # "-loo-p3" sorts after "-loo-p1"; "-loo.txt" alone is the only round
    else:
        return {}
    text = read(last)
    return {m.group(1): (float(m.group(2)), float(m.group(3))) for m in re.finditer(r"^\s+(\S+)\s+\S+\s+fitted\s+([\d.]+)\s+held-out\s+([\d.]+)", text, re.M)}


def whites(text):
    out = {}
    for m in re.finditer(r"^(\S+)\s+(\S+)\s+the (window|price card|wall)\s+\(n\s*(\d+)\):.*diff dL ([+-][\d.]+) da ([+-][\d.]+) db ([+-][\d.]+) \| dE ([\d.]+)", text, re.M):
        out[(m.group(2), m.group(3))] = (float(m.group(5)), float(m.group(6)), float(m.group(7)), float(m.group(8)), int(m.group(4)))
    return out


def grains(text):
    return {m.group(1): float(m.group(2)) for m in re.finditer(r"^(\S+): ([\d.]+)", text, re.M)}


def clipping(text):
    return {m.group(1): (m.group(2), m.group(3)) for m in re.finditer(r"^(\S+)\s+\S+\s+([\d.]+%)\s+([\d.]+%)", text, re.M)}


def banding(text):
    out = {}
    for m in re.finditer(r"^(\S+)\s+(column|row)\s+(\S+)\s+(\S+)\s+(\d+) px\s+(\d+) px", text, re.M):
        out.setdefault(m.group(1), []).append((m.group(2), m.group(3), m.group(4), int(m.group(5)), int(m.group(6))))
    return out


def residual(text, cam):
    m = re.search(rf"^{cam}: largest remaining structure over its pictures: (.*)$", text, re.M)
    return m.group(1) if m else "–"


def fmt(v, digits=1):
    return "–" if v is None else f"{v:.{digits}f}"


def main(argv):
    opts = {"--before": "before.json", "--after": "after.json"}
    cams = []
    i = 0
    while i < len(argv):
        if argv[i] in opts:
            opts[argv[i]] = argv[i + 1]; i += 2
        else:
            cams.append(argv[i]); i += 1
    cams = cams or ORDER
    before, after = load_json(opts["--before"]), load_json(opts["--after"])
    floor_b, floor_a = floors(read("floor-before.txt")), floors(read("floor-after.txt"))
    whites_a, grain_a = whites(read("whites-after.txt")), grains(read("grain-after.txt"))
    clip_a, band_a = clipping(read("exceed-clipping-after.txt")), banding(read("exceed-banding-after.txt"))
    residual_a = read("residual-after.txt")
    picture_of = {pair: d["picture"] for table in (before, after) for rows in table.values() for pair, d in rows.items()}
    for cam in cams:
        refine = load_json(f"{cam}-refine.json")
        loo = held_out(cam)
        print(f"\n#### {NAMES.get(cam, cam)} (`{cam}`)\n")
        print("| Picture | before | after | floor | within floor + 0.5 | held out (fit on the other six) | face dL da db (dE) | whites dL / dE | grain ratio | clipped ours / ref |")
        print("|---|---|---|---|---|---|---|---|---|---|")
        for pair in pairs(cam):
            b, a = before.get(cam, {}).get(pair), after.get(cam, {}).get(pair)
            if not b and not a:
                continue
            picture = (a or b).get("picture", "")
            med_b, med_a = (b or {}).get("retrosnap"), (a or {}).get("retrosnap")
            floor = floor_a.get(pair, floor_b.get(pair, (None, None)))[0]
            gate = "–" if floor is None or med_a is None else ("yes" if med_a <= floor + 0.5 else f"no (+{med_a - floor - 0.5:.1f})")
            ho = loo.get(pair)
            face = (a or {}).get("face")
            face_s = f"{face['dL']:+.1f} {face['da']:+.1f} {face['db']:+.1f} ({face['dE']:.1f})" if face else "–"
            w = next((whites_a[k] for k in whites_a if k[0] == pair), None)
            w_s = f"{w[0]:+.1f} / {w[3]:.1f}" if w else "–"
            clip = clip_a.get(pair)
            print(f"| {picture} | {fmt(med_b)} | {fmt(med_a)} | {fmt(floor)} | {gate} | {fmt(ho[1]) if ho else '–'} | {face_s} | {w_s} | "
                  f"{fmt(grain_a.get(pair), 2)} | {clip[0] + ' / ' + clip[1] if clip else '–'} |")
        if refine:
            t, r, a_, tint = refine["halation"]
            print(f"\nHalation (threshold, radius, amount, tint): {t}, {r} pt, {a_}, {tint}. Blur: {refine['blur']:.2f} pt. "
                  f"Table prior {refine['prior']:g}, smooth {refine['smooth']:g}, skin {refine['skin']:g}; held-out median gap {refine['loo_median_gap']:+.2f}.")
        print(f"Residual's largest remaining structure: {residual(residual_a, cam)}.")
        bands = [(p, line, ours, ref, run_o, run_r) for p, rows in band_a.items() if p.startswith(cam + "-") for line, ours, ref, run_o, run_r in rows]
        if bands:
            print("Banding (levels ours vs reference, longest run ours vs reference): " + "; ".join(
                f"{picture_of.get(p, p)} {line} {ours} vs {ref}, {ro} vs {rr} px" for p, line, ours, ref, ro, rr in bands) + ".")


if __name__ == "__main__":
    main(sys.argv[1:])
