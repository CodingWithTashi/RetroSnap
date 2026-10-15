"""How coloured the grain is and what the reference adds next to highlights, for RetroSnap's renders of the pairs
(after `ReferencePairTests`) against the references: the two layers whole-picture ΔE hides.

    venv/bin/python -I tools/glow_grain.py ref/pairs/<pair> [...]
"""
import sys, json, numpy as np
sys.path.insert(0, __file__.rsplit("/", 1)[0])
from colour import ColourStage, srgb_to_lab
from images import load_rgb as load
from PIL import Image
from scipy import ndimage
def hp(x, s=2.5): return x - ndimage.gaussian_filter(x, s)
for pair in sys.argv[1:]:
    cam = pair.split("/")[-1].split("-")[0]
    inp, ref, ours = load(f"{pair}-input.png"), load(f"{pair}-reference.png"), load(f"{pair}-retrosnap.png")
    if ref.shape[1] > 1400: inp, ref, ours = inp[::2, ::2], ref[::2, ::2], ours[::2, ::2]
    Li, Lr, Lo = srgb_to_lab(inp), srgb_to_lab(ref), srgb_to_lab(ours)
    n = 24; H, W = Li.shape[:2]; rows = []
    for y in range(n, H - 2*n, n):
        for x in range(n, W - 2*n, n):
            if hp(Li[y:y+n, x:x+n, 0]).std() < 1.5 and 35 < Lr[y:y+n, x:x+n, 0].mean() < 85:
                r = Lr[y:y+n, x:x+n]; o = Lo[y:y+n, x:x+n]
                rows.append((hp(r[...,0]).std(), np.hypot(hp(r[...,1]), hp(r[...,2])).mean(), hp(o[...,0]).std(), np.hypot(hp(o[...,1]), hp(o[...,2])).mean()))
    rows = np.array(rows)
    line = f"{pair.split('/')[-1]:15s} grain L-noise ref {np.median(rows[:,0]):.2f} ours {np.median(rows[:,2]):.2f} (x{np.median(rows[:,2])/np.median(rows[:,0]):.2f}) | chroma-noise ref {np.median(rows[:,1]):.2f} ours {np.median(rows[:,3]):.2f} (x{np.median(rows[:,3])/max(np.median(rows[:,1]),1e-6):.2f})"
    bright = Li[...,0] > 96
    if bright.sum() > 200:
        near = ndimage.binary_dilation(bright, iterations=12) & ~ndimage.binary_dilation(bright, iterations=2) & (Li[...,0] < 70)
        d = (Lr - Lo)[near]
        line += f" | next to highlights, reference minus RetroSnap: dL {d[:,0].mean():+.2f} da {d[:,1].mean():+.2f} db {d[:,2].mean():+.2f}"
    print(line)
