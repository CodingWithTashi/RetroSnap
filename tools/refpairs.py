"""Cut and align the reference pairs `tools/pairs.py` lists: every reference file becomes a crop under
`ref/crops/<pair>.png` (a screenshot through `refcrop.py`, a print's window cut from its export, a bare 3:2 export
as it is), and `fit.py`'s single form aligns each crop with its input and writes the pair under `ref/pairs`.

    venv/bin/python -I tools/refpairs.py crop [<pair> ...]              # the crops (all pairs, or the named ones)
    venv/bin/python -I tools/refpairs.py align [<pair> ...] [--jobs 3] [--samples 30000] [--reg 3]

`align` skips a pair that already has its `-input.png`; `--force` redoes it. A pair's single-picture fit is only the
bound for that picture; the camera's recipe comes from the joint fit over all its pairs (`fit.py --pair`).
"""
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

from PIL import Image, ImageOps

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pairs import CAMERAS, PAIRS, ROOT, input_path, reference_path  # noqa: E402

TOOLS = os.path.dirname(os.path.abspath(__file__))
# One BLAS thread per fit: several fits at once, each spawning a thread per core, thrash the machine.
ENV = os.environ | {"OPENBLAS_NUM_THREADS": "1", "OMP_NUM_THREADS": "1", "MKL_NUM_THREADS": "1"}
PYTHON = sys.executable
CROPS = os.path.join(ROOT, "crops")
OUT = os.path.join(ROOT, "pairs")


def crop_path(pair):
    return os.path.join(CROPS, pair + ".png")


def crop(cam, suffix):
    ref = PAIRS[cam][suffix]
    pair = cam + suffix
    src = reference_path(cam, suffix)
    out = crop_path(pair)
    os.makedirs(CROPS, exist_ok=True)
    if ref["kind"] == "screenshot":
        left, top, right, bottom = ref["crop"]
        args = [PYTHON, "-I", os.path.join(TOOLS, "refcrop.py"), src, str(left), str(top), str(right), str(bottom), out]
        if ref.get("deskew"):
            args.append("--deskew")
        if ref.get("angle") is not None:
            args += ["--angle", str(ref["angle"])]
        if ref.get("exact"):
            args.append("--exact")
        print(subprocess.run(args, capture_output=True, text=True, check=True).stdout.strip())
    elif ref["kind"] == "print":
        image = ImageOps.exif_transpose(Image.open(src))
        icc = image.info.get("icc_profile")
        window = image.convert("RGB").crop(ref["window"])
        window.save(out, icc_profile=icc)
        print(f"{pair}: window {window.size[0]}x{window.size[1]} cut from {os.path.basename(src)}")
    else:
        # A bare export is its own crop: the file is used as it is (the mask keeps the date back out of the fit).
        print(f"{pair}: the export is the crop ({os.path.basename(src)})")
    return pair


def source_for(cam, suffix):
    """What `fit.py` takes as the reference crop: the crop file, or the export itself."""
    ref = PAIRS[cam][suffix]
    return reference_path(cam, suffix) if ref["kind"] == "export" else crop_path(cam + suffix)


def align(cam, suffix, samples, reg, force):
    pair = cam + suffix
    if not force and os.path.exists(os.path.join(OUT, pair + "-input.png")):
        return f"{pair}: already aligned"
    ref = PAIRS[cam][suffix]
    args = [PYTHON, "-I", os.path.join(TOOLS, "fit.py"), pair, input_path(suffix), source_for(cam, suffix), OUT,
            "--samples", str(samples), "--reg", str(reg)]
    if ref.get("mask"):
        args += ["--mask", ",".join(str(v) for v in ref["mask"])]
    if cam == "slide":
        args += ["--inset", "0.06"]
    done = subprocess.run(args, capture_output=True, text=True, env=ENV)
    log = os.path.join(OUT, pair + "-fit.log")
    open(log, "w").write(done.stdout + done.stderr)
    first = [line for line in done.stdout.splitlines() if line.startswith(pair + ":") or "fit vs reference" in line]
    return f"{pair}: " + ("; ".join(line.strip() for line in first) if done.returncode == 0 else f"FAILED (see {log})")


def main(argv):
    command = argv[0]
    opts = {"--jobs": "3", "--samples": "30000", "--reg": "3"}
    names, force = [], False
    i = 1
    while i < len(argv):
        if argv[i] in opts:
            opts[argv[i]] = argv[i + 1]; i += 2
        elif argv[i] == "--force":
            force = True; i += 1
        else:
            names.append(argv[i]); i += 1
    wanted = [(cam, suffix) for cam in CAMERAS for suffix in PAIRS[cam] if not names or cam + suffix in names]
    if command == "crop":
        for cam, suffix in wanted:
            crop(cam, suffix)
    elif command == "align":
        with ThreadPoolExecutor(int(opts["--jobs"])) as pool:
            for line in pool.map(lambda cs: align(*cs, int(opts["--samples"]), float(opts["--reg"]), force), wanted):
                print(line, flush=True)


if __name__ == "__main__":
    main(sys.argv[1:])
