"""Hold RetroSnap's export of a reference input (`ref/pairs/export-<id>[-1].png`, from `ReferenceExportTests`)
against the reference app's screenshot, canvas to canvas: both scaled to the same width, side by side, for every
camera and picture. Writes <out>/<id>[-1].png; `--sheet <file.jpg>` also stacks them all into one sheet for the
owner. The screenshot's canvas region per pair is the table below: extend it when a camera is added.

    venv/bin/python -I tools/frames.py <outdir> [--sheet out.jpg]
"""
import sys, os
import numpy as np
from PIL import Image, ImageDraw
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ref")
out = sys.argv[1]; os.makedirs(out, exist_ok=True)
sheet = sys.argv[sys.argv.index("--sheet") + 1] if "--sheet" in sys.argv else None
rows = []
# The reference screenshot's canvas region (x0, y0, x1, y1) in the 1179x2556 screenshot, from the measurements.
refs = {
    "negative": ("135 NE/IMG_5894.PNG", (0, 769, 1179, 1787)),
    "negative-1": ("135 NE/output_1.jpeg", (0, 595, 1179, 1961)),
    "plastic35": ("CPM35/IMG_5895.PNG", (0, 851, 1179, 1636)),
    "plastic35-1": ("CPM35/output_1.jpg", None),
    "slide": ("D Slide/IMG_5890.PNG", (0, 560, 1179, 2016)),
    "slide-1": ("D Slide/output_1.jpeg", (0, 560, 1179, 2016)),
    "mediumFormat": ("S 67/IMG_5889.PNG", (0, 780, 1179, 1776)),
    "mediumFormat-1": ("S 67/output_1.jpeg", (0, 580, 1179, 1976)),
    "tlr": ("S Classic/IMG_5892.PNG", (0, 688, 1179, 1867)),
    "tlr-1": ("S Classic/output_1.jpeg", (0, 688, 1179, 1867)),
}
W = 700
LABELS = {"negative": "135 NE", "plastic35": "CPM35", "slide": "D Slide", "mediumFormat": "S 67", "tlr": "S Classic"}
for name, (path, box) in refs.items():
    ref = Image.open(f"{R}/photo/{path}").convert("RGB")
    if box: ref = ref.crop(box)
    ours = Image.open(f"{R}/pairs/export-{name}.png").convert("RGB")
    ref_s = ref.resize((W, round(ref.height * W / ref.width)), Image.LANCZOS)
    ours_s = ours.resize((W, round(ours.height * W / ours.width)), Image.LANCZOS)
    h = max(ref_s.height, ours_s.height)
    sheet = Image.new("RGB", (W * 2 + 30, h + 30), (90, 90, 90))
    sheet.paste(ref_s, (10, 20)); sheet.paste(ours_s, (W + 20, 20))
    ImageDraw.Draw(sheet).text((10, 4), f"{LABELS.get(name.split('-')[0], name)}: left the reference app's screen, right RetroSnap's export", fill=(235, 235, 235))
    sheet.save(f"{out}/{name}.png")
    rows.append((name, sheet))
    print(name, "reference canvas", ref.size, "ratio", round(ref.width / ref.height, 4), "| RetroSnap export", ours.size, "ratio", round(ours.width / ours.height, 4))

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
