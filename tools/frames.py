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
    # Batch 2: the reference app's exports, which are the whole canvas.
    "film": ("D Classic/dclassic 2026-10-13 12584393BDF746956D.jpg", None),
    "film-1": ("D Classic/dclassic 2026-10-13 12585463779A200758.jpg", None),
    "film-2": ("D Classic/dclassic 2026-10-13 1258482BD4FDFDE524.jpg", None),
    "inst": ("Inst C/instc 2026-10-13 125627B1E07A644D71.jpg", None),
    "inst-1": ("Inst C/instc 2026-10-13 125707D6631BF33833.jpg", None),
    "inst-2": ("Inst C/instc 2026-10-13 125741FA539412BD42.jpg", None),
    "compactPro": ("CT2F/ct2f 2026-10-13 1259524B9DC3638601.jpg", None),
    "compactPro-1": ("CT2F/ct2f 2026-10-13 125952BCC6D6D1B4D1.jpg", None),
    "compactPro-2": ("CT2F/ct2f 2026-10-13 125953969342376801.jpg", None),
    "classicSLR": ("Classic U/classicu 2026-10-13 1302126C86A06C18E2.jpg", None),
    "classicSLR-1": ("Classic U/classicu 2026-10-13 130212B1F2575D660F.jpg", None),
    "classicSLR-2": ("Classic U/classicu 2026-10-13 130213FED571A8FE1A.jpg", None),
    "instSquare": ("Inst SQC/instsqc 2026-10-13 130051466BF8D1713F.jpg", None),
    "instSquare-1": ("Inst SQC/instsqc 2026-10-13 130050F5A56D6C147E.jpg", None),
    "instSquare-2": ("Inst SQC/instsqc 2026-10-13 130051DE2A0C351A86.jpg", None),
}
W = 700
LABELS = {"negative": "135 NE", "plastic35": "CPM35", "slide": "D Slide", "mediumFormat": "S 67", "tlr": "S Classic",
          "film": "D Classic", "inst": "Inst C", "compactPro": "CT2F", "classicSLR": "Classic U", "instSquare": "Inst SQC"}
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
