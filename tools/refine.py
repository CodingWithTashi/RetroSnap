"""The refit loop for one camera after `refit.py --pick` has put its joint parametric fit in place: the halation
from all its pairs with the recipe's blur (`halation.py --fine --wide`), the table on all pairs after that glow
and blur (`lut.py`, prior 0.3, smooth 2, skin 3), the blur through the new table (`softness.py`; the halation and
table are refitted once if it moved by more than 0.03 pt), then leave-one-out on the table (`loo.py`; the prior and
smoothing are doubled and the table refitted while the median held-out gap over the pairs is over 0.5), and finally the recipe
block (`recipe.py`) with the grain the renders measured.

    venv/bin/python -I tools/refine.py <id> [--prior 0.3] [--smooth 2] [--skin 3] [--grain size,amount,color] [--resume | --settle <prior> <smooth>]

Everything it ran is kept under `ref/pairs/refine/<id>-*.txt`; the table lands at `ref/pairs/<id>.cube` and
`<id>-lut.json` as `lut.py` writes them.
"""
import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pairs import pairs as pairs_of, recipe  # noqa: E402

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(TOOLS, "..")
R = os.path.join(ROOT, "ref", "pairs")
OUT = os.path.join(R, "refine")
ENV = os.environ | {"OPENBLAS_NUM_THREADS": "2", "OMP_NUM_THREADS": "2"}
HEX = {"0xFFFFFF": "white", "0xE0F0FF": "cool", "0xFF8A50": "warm"}


def run(name, args):
    done = subprocess.run([sys.executable, "-I"] + args, capture_output=True, text=True, cwd=ROOT, env=ENV)
    text = done.stdout + done.stderr
    open(os.path.join(OUT, name + ".txt"), "w").write(text)
    if done.returncode != 0:
        raise RuntimeError(f"{name} failed:\n{text[-2000:]}")
    return text


def fit_halation(cam, blur, tag):
    text = run(f"{cam}-halation{tag}", [os.path.join(TOOLS, "halation.py"), cam] + [os.path.join(R, p) for p in pairs_of(cam)]
               + ["--fit", os.path.join(R, cam + ".json"), "--fine", "--wide", "--blur", str(blur)])
    m = re.search(r"Halation\(threshold: ([\d.]+), radius: ([\d.]+), amount: ([\d.]+), tintHex: (0x[0-9A-F]+)\)", text)
    return (float(m.group(1)), float(m.group(2)), float(m.group(3)), HEX[m.group(4)])


def fit_table(cam, halation, blur, prior, smooth, skin, tag):
    t, r, a, tint = halation
    text = run(f"{cam}-lut{tag}", [os.path.join(TOOLS, "lut.py"), cam, R] + sum([["--pair", os.path.join(R, p)] for p in pairs_of(cam)], [])
               + ["--halation", f"{t},{r},{a},{tint}", "--blur", str(blur), "--prior", str(prior), "--smooth", str(smooth), "--skin", str(skin)])
    return {m.group(1): float(m.group(2)) for m in re.finditer(r"^\s+(\S+): table vs reference median ([\d.]+)", text, re.M)}


def fit_blur(cam, tag):
    text = run(f"{cam}-softness{tag}", [os.path.join(TOOLS, "softness.py"), cam] + [os.path.join(R, p) for p in pairs_of(cam)])
    m = re.search(r"blurRadius ([\d.]+) pt", text)
    return float(m.group(1)), text.strip().splitlines()[-1]


def leave_one_out(cam, prior, smooth, skin, tag):
    import shutil
    folder = os.path.join(R, "loo", cam + tag)
    shutil.rmtree(folder, ignore_errors=True)
    text = run(f"{cam}-loo{tag}", [os.path.join(TOOLS, "loo.py"), cam, "--prior", str(prior), "--smooth", str(smooth), "--skin", str(skin), "--out", folder, "--jobs", "2"])
    # Over-fitting is judged on the median gap over the pairs: a picture whose colours no other picture shows
    # (the market's saturated crates) is held out of a table that cannot know them, which is not over-fitting.
    gaps = [float(g) for g in re.findall(r"gap ([+-][\d.]+)", text)]
    import statistics
    return (statistics.median(gaps) if gaps else float("nan")), text


def resume(cam, look, prior, smooth, skin):
    """Rebuild the loop's state from the files a run left under `ref/pairs/refine/` (when the run died after its
    fits, as the ones of 14 October 2026 did at the recipe step): the halation, blur, prior, medians, gap and log."""
    def text(tag):
        return open(os.path.join(OUT, f"{cam}-{tag}.txt")).read()
    def halation_of(t):
        m = re.search(r"Halation\(threshold: ([\d.]+), radius: ([\d.]+), amount: ([\d.]+), tintHex: (0x[0-9A-F]+)\)", t)
        return (float(m.group(1)), float(m.group(2)), float(m.group(3)), HEX[m.group(4)])
    def medians_of(t):
        return {m.group(1): float(m.group(2)) for m in re.finditer(r"^\s+(\S+): table vs reference median ([\d.]+)", t, re.M)}
    def gap_of(t):
        import statistics
        gaps = [float(g) for g in re.findall(r"gap ([+-][\d.]+)", t)]
        return statistics.median(gaps) if gaps else float("nan")
    blur = look["blur"]
    log = []
    halation = halation_of(text("halation"))
    log.append(f"halation with blur {blur}: {halation}")
    medians = medians_of(text("lut"))
    log.append(f"table (prior {prior}, smooth {smooth}, skin {skin}): " + " ".join(f"{k} {v:.2f}" for k, v in medians.items()))
    soft = text("softness")
    new_blur = float(re.search(r"blurRadius ([\d.]+) pt", soft).group(1))
    log.append(f"blur through the new table: {new_blur:.2f} pt ({soft.strip().splitlines()[-1]})")
    if os.path.exists(os.path.join(OUT, f"{cam}-halation-2.txt")):
        blur = round(new_blur, 2)
        halation = halation_of(text("halation-2"))
        log.append(f"halation with blur {blur}: {halation}")
        medians = medians_of(text("lut-2"))
        log.append(f"table again: " + " ".join(f"{k} {v:.2f}" for k, v in medians.items()))
    gap = gap_of(text("loo"))
    log.append(f"leave-one-out median gap {gap:+.2f}")
    rounds = 0
    while os.path.exists(os.path.join(OUT, f"{cam}-loo-p{rounds + 1}.txt")):
        rounds += 1
        prior, smooth = prior * 2, smooth * 2
        medians = medians_of(text(f"lut-p{rounds}"))
        gap = gap_of(text(f"loo-p{rounds}"))
        log.append(f"over-fitted: prior {prior}, smooth {smooth}: table " + " ".join(f"{k} {v:.2f}" for k, v in medians.items()) + f"; held-out median gap {gap:+.2f}")
    return halation, blur, prior, smooth, medians, gap, log, text(f"loo-p{rounds}" if rounds else "loo")


def main(argv):
    cam = argv[0]
    opts = {"--prior": "0.3", "--smooth": "2", "--skin": "3", "--grain": None}
    i = 1
    while i < len(argv):
        if argv[i] == "--resume":
            opts["--resume"] = True; i += 1; continue
        if argv[i] == "--settle":
            opts["--settle"] = (argv[i + 1], argv[i + 2]); i += 3; continue
        opts[argv[i]] = argv[i + 1]; i += 2
    os.makedirs(OUT, exist_ok=True)
    look = recipe(cam)
    prior, smooth, skin = float(opts["--prior"]), float(opts["--smooth"]), float(opts["--skin"])
    if opts.get("--resume"):
        halation, blur, prior, smooth, medians, gap, log, text = resume(cam, look, prior, smooth, skin)
        return finish(cam, opts, look, halation, blur, prior, smooth, skin, medians, gap, log, text)
    if opts.get("--settle"):
        # The table again at a prior and smoothness chosen from the leave-one-out runs (`pickprior.py`), with the
        # loop's halation and blur; the summary keeps the loop's log and adds this fit.
        summary = json.load(open(os.path.join(OUT, cam + "-refine.json")))
        halation, blur = tuple(summary["halation"]), summary["blur"]
        prior, smooth = float(opts["--settle"][0]), float(opts["--settle"][1])
        medians = fit_table(cam, halation, blur, prior, smooth, skin, "-pick")
        log = summary["log"] + [f"settled on prior {prior:g}, smooth {smooth:g} by the held-out medians (pickprior.py): table "
                                + " ".join(f"{k} {v:.2f}" for k, v in medians.items())]
        gap = summary.get("loo_median_gap", float("nan"))
        return finish(cam, opts, look, halation, blur, prior, smooth, skin, medians, gap, log, "")
    blur = look["blur"]
    log = []
    halation = fit_halation(cam, blur, "")
    log.append(f"halation with blur {blur}: {halation}")
    medians = fit_table(cam, halation, blur, prior, smooth, skin, "")
    log.append(f"table (prior {prior}, smooth {smooth}, skin {skin}): " + " ".join(f"{k} {v:.2f}" for k, v in medians.items()))
    new_blur, blur_line = fit_blur(cam, "")
    log.append(f"blur through the new table: {new_blur:.2f} pt ({blur_line})")
    if abs(new_blur - blur) > 0.03:
        blur = round(new_blur, 2)
        halation = fit_halation(cam, blur, "-2")
        log.append(f"halation with blur {blur}: {halation}")
        medians = fit_table(cam, halation, blur, prior, smooth, skin, "-2")
        log.append(f"table again: " + " ".join(f"{k} {v:.2f}" for k, v in medians.items()))
    gap, text = leave_one_out(cam, prior, smooth, skin, "")
    log.append(f"leave-one-out median gap {gap:+.2f}")
    rounds = 0
    while gap > 0.5 and rounds < 3:
        rounds += 1
        prior, smooth = prior * 2, smooth * 2
        medians = fit_table(cam, halation, blur, prior, smooth, skin, f"-p{rounds}")
        gap, text = leave_one_out(cam, prior, smooth, skin, f"-p{rounds}")
        log.append(f"over-fitted: prior {prior}, smooth {smooth}: table " + " ".join(f"{k} {v:.2f}" for k, v in medians.items()) + f"; held-out median gap {gap:+.2f}")
    finish(cam, opts, look, halation, blur, prior, smooth, skin, medians, gap, log, text)


def finish(cam, opts, look, halation, blur, prior, smooth, skin, medians, gap, log, text):
    t, r, a, tint = halation
    args = [os.path.join(TOOLS, "recipe.py"), cam, "--frame", "?", "--halation", f"{t},{r},{a},{tint}", "--blur", str(blur)]
    if opts["--grain"]:
        args += ["--grain", opts["--grain"]]
    elif look["grain"]:
        args += ["--grain", ",".join(str(v) for v in look["grain"])]
    block = run(f"{cam}-recipe", args)
    summary = {"camera": cam, "halation": halation, "blur": blur, "prior": prior, "smooth": smooth, "skin": skin, "table": medians, "loo_median_gap": gap, "log": log}
    json.dump(summary, open(os.path.join(OUT, cam + "-refine.json"), "w"), indent=1)
    print("\n".join(log))
    print(text)
    print(block)


if __name__ == "__main__":
    main(sys.argv[1:])
