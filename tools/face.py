"""The face under a fit: the selfie's skin-tone pixels (by the input's colour, in the upper middle of the frame),
the reference against the parametric fit's prediction, or against RetroSnap's render with `--render`, with the
overall medians. A viewer judges a picture by the face first, and whole-picture medians hide it.

    venv/bin/python -I tools/face.py <id> ref/pairs/<id>.json [--render]
"""
import sys, json, numpy as np
sys.path.insert(0, __file__.rsplit("/", 1)[0])
from colour import ColourStage, srgb_to_lab, delta_e2000
from PIL import Image
def load(p): return np.asarray(Image.open(p).convert("RGB")).astype(float)/255
def box(a, n=4):
    h, w = a.shape[0]//n, a.shape[1]//n
    return a[:h*n, :w*n].reshape(h, n, w, n, 3).mean(axis=(1,3))
cam, fit_path = sys.argv[1], sys.argv[2]; render = "--render" in sys.argv
p = ColourStage.from_json(json.load(open(fit_path)))
R = __file__.rsplit("/", 1)[0] + "/../ref/pairs"
import os
for pair in [cam, f"{cam}-1", f"{cam}-2"]:
    if not os.path.exists(f"{R}/{pair}-input.png"):
        continue
    inp, ref = load(f"{R}/{pair}-input.png"), load(f"{R}/{pair}-reference.png")
    h, w = ref.shape[:2]
    if render:
        out = load(f"{R}/{pair}-retrosnap.png")
    else:
        uv = np.stack([(np.arange(w)+0.5)[None,:].repeat(h,0)/w, (np.arange(h)+0.5)[:,None].repeat(w,1)/h], -1)
        out = ColourStage.apply(p, inp, uv)
    A, B, O = srgb_to_lab(box(inp)), srgb_to_lab(box(ref)), srgb_to_lab(box(out))
    m = int((0.06 if cam == "slide" else 0.02) * w) // 4
    de_all = np.median(delta_e2000(O[m:-m or None, m:-m or None], B[m:-m or None, m:-m or None]))
    if pair == cam:
        hh, ww = A.shape[:2]; yy, xx = np.mgrid[0:hh, 0:ww]
        skin = (A[...,0] > 40) & (A[...,0] < 80) & (A[...,1] > 6) & (A[...,1] < 26) & (A[...,2] > 10) & (A[...,2] < 36) & (np.hypot(A[...,1], A[...,2]) < 36) & (yy < 0.62*hh) & (xx > 0.3*ww) & (xx < 0.8*ww)
        d = (O - B)[skin]
        print(f"{cam:13s} {pair:13s} median dE {de_all:.2f} | face (n {skin.sum()}): Dazz L {B[...,0][skin].mean():.1f} a {B[...,1][skin].mean():+.1f} b {B[...,2][skin].mean():+.1f} | {'RetroSnap' if render else 'fit'} L {O[...,0][skin].mean():.1f} a {O[...,1][skin].mean():+.1f} b {O[...,2][skin].mean():+.1f} | diff dL {d[:,0].mean():+.1f} da {d[:,1].mean():+.1f} db {d[:,2].mean():+.1f} | face dE {np.median(delta_e2000(O[skin], B[skin])):.2f}")
    else:
        print(f"{cam:13s} {pair:13s} median dE {de_all:.2f}")
