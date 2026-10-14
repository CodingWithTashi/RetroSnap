"""Hold RetroSnap's export of a reference input (`ref/pairs/export-<id>[-1].png`, from `ReferenceExportTests`)
against the reference app's screenshot, canvas to canvas: both scaled to the same width, side by side, for every
camera and picture in `tools/pairs.py`. Writes <out>/<pair>.png; `--sheet <file.jpg>` also stacks them all into one
sheet for the owner.

    venv/bin/python -I tools/frames.py <outdir> [--sheet out.jpg] [--per-camera <dir>]
"""
import os
import sys, os
import numpy as np
from PIL import Image, ImageDraw
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ref")
out = sys.argv[1]; os.makedirs(out, exist_ok=True)
sheet = sys.argv[sys.argv.index("--sheet") + 1] if "--sheet" in sys.argv else None
# `--per-camera <dir>` also writes one sheet per camera (<dir>/<id>-<name>.jpg), each short enough to read on a phone.
per_camera = sys.argv[sys.argv.index("--per-camera") + 1] if "--per-camera" in sys.argv else None
rows = []
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pairs import CAMERAS, NAMES, PAIRS  # noqa: E402
# Per pair: the reference app's file and, for a screenshot, its canvas region (x0, y0, x1, y1); an export is whole.
refs = {cam + suffix: (ref["file"], ref.get("canvas")) for cam in CAMERAS for suffix, ref in PAIRS[cam].items()}
W = 700
LABELS = NAMES
from PIL import ImageOps
for name, (path, box) in refs.items():
    if not os.path.exists(f"{R}/pairs/export-{name}.png"):
        continue
    ref = ImageOps.exif_transpose(Image.open(f"{R}/photo/{path}")).convert("RGB")
    if box: ref = ref.crop(box)
    ours = Image.open(f"{R}/pairs/export-{name}.png").convert("RGB")
    ref_s = ref.resize((W, round(ref.height * W / ref.width)), Image.LANCZOS)
    ours_s = ours.resize((W, round(ours.height * W / ours.width)), Image.LANCZOS)
    h = max(ref_s.height, ours_s.height)
    row = Image.new("RGB", (W * 2 + 30, h + 30), (90, 90, 90))
    row.paste(ref_s, (10, 20)); row.paste(ours_s, (W + 20, 20))
    ImageDraw.Draw(row).text((10, 4), f"{LABELS.get(name.split('-')[0], name)}: left the reference app's, right RetroSnap's export", fill=(235, 235, 235))
    row.save(f"{out}/{name}.png")
    rows.append((name, row))
    print(name, "reference canvas", ref.size, "ratio", round(ref.width / ref.height, 4), "| RetroSnap export", ours.size, "ratio", round(ours.width / ours.height, 4))

if per_camera:
    os.makedirs(per_camera, exist_ok=True)
    for cam in dict.fromkeys(name.split("-")[0] for name, _ in rows):
        own = [im for name, im in rows if name.split("-")[0] == cam]
        total, width = sum(im.height for im in own), max(im.width for im in own)
        stack = Image.new("RGB", (width, total), (42, 42, 42))
        y = 0
        for im in own:
            stack.paste(im, (0, y)); y += im.height
        stack = stack.resize((1000, round(total * 1000 / width)), Image.LANCZOS)
        stack.save(os.path.join(per_camera, f"{cam}-{LABELS.get(cam, cam).replace(' ', '')}.jpg"), quality=88)
    print("per-camera sheets in", per_camera)

if sheet:
    total = sum(r[1].height for r in rows)
    width = max(r[1].width for r in rows)
    stack = Image.new("RGB", (width, total), (42, 42, 42))
    y = 0
    for _, im in rows:
        stack.paste(im, (0, y)); y += im.height
    stack = stack.resize((1000, round(stack.height * 1000 / stack.width)), Image.LANCZOS)
    stack.save(sheet, quality=88)
    print("sheet", sheet)
