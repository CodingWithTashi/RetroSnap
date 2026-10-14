# tools

The calibration scripts for matching a camera to its reference pair. `docs/camera-lineup.md`, "Measuring a pair", says when to run which; each script's docstring says how.

| Script | Does |
|---|---|
| `pairs.py` | The manifest of every reference pair: input picture, reference file, crop rectangle or print window, date-back mask, canvas region, the regions a viewer judges first, and `recipe(cam)`, which reads a camera's blur, halation and grain out of `CameraLook.swift`. Every other script takes its pairs from here. |
| `refpairs.py` | Cuts every crop the manifest lists (`crop`) and aligns each with its input through `fit.py`'s single form (`align`, several at once). |
| `refscan.py` | Scans a reference screenshot for where the picture and canvas are. |
| `refcrop.py` | Snaps a rough rectangle to the picture's edges and saves the crop with its colour profile; `--deskew` first turns a tilted canvas straight; `--exact` cuts the rectangle as given (a dark picture against black film has no edge to snap to). |
| `printscan.py` | Measures a print camera's export: the sheet, the print, its window, outline, shadow and paper colours, as fractions the app draws from; `--corners` saves the corners at 1:1. |
| `stamp.py` | Measures a date back on an export (or on RetroSnap's): where it sits, its glyphs, its ink under a screen blend, its glow; prints the `--mask` for `fit.py`. |
| `softness.py` | Fits a camera's `blurRadius` from its pairs: the Gaussian radius that makes the input, through the camera's colour, keep as much fine detail as the reference does. |
| `fit.py` | Converts the pictures to sRGB, aligns the crop with the input photo, writes the pair to `ref/pairs`, fits the colour stage (matrix, curves, per-hue terms) and vignette, writes the JSON and a report. With `--pair`, fits one colour stage over several pairs already aligned, each counting the same. |
| `sanity.py` | Runs a fit over a hue sweep and a grey ramp, to catch a fit that misbehaves on colours it never saw. |
| `transcribe.py` | Prints a fit as the Swift literal for `CameraLook.swift`. |
| `recipe.py` | Prints a camera's whole `CameraLook` block from its fit, table, halation, blur and grain, ready for `CameraLook.swift`. |
| `cube_fixture.py` | The fixtures' orange through a shipped table, as `ColorCubeTests` pins it. |
| `compare.py` | ΔE2000 of RetroSnap's render (from `ReferencePairTests`) against the reference and against the camera's fit (its table when it ships one, else the parametric fit, over the input after the recipe's halation and blur), for the first pair or any later one. |
| `grain.py` | The grain of a pair's reference and of RetroSnap's render: amplitude by luminance, their ratio at mid grey, texture size, and the detail each keeps where the input has some (softness). |
| `lut.py` | Fits a camera's colour as a 3D lookup table from all its pairs at once (one sparse least-squares solve), held toward the parametric fit where the pictures showed nothing and kept smooth, after the camera's halation and blur; writes the `.cube` the app ships. |
| `halation.py` | Fits a camera's halation from its pairs: the glow the reference spreads around highlights, found as the threshold, radius, amount and tint that best explain what the colour-only fit leaves next to bright pixels; `--blur` runs it with the camera's blur in the loop, `--wide` widens the fine grid to 16 pt. |
| `face.py` | The face (skin-tone pixels, on the pictures that have one) under a fit or RetroSnap's render against the reference: the region a viewer judges first, which whole-picture medians hide. |
| `whites.py` | The whites (the backlit window, the market's price card, the grey wall) under RetroSnap's render against the reference: the cast a viewer sees after the face. |
| `floor.py` | The per-pixel floor of a pair: how far the reference scatters around the mean colour it gives each input colour, which no colour-to-colour model can beat; RetroSnap's median beside it. |
| `grain_profile.py` | The reference's grain amplitude by luminance over the export pairs, scaled by its peak, against RetroSnap's: the shape `FilmGrain`'s luminance weight follows. |
| `refine.py` | One camera's refit loop after `refit.py --pick`: halation, table, blur, leave-one-out, recipe block. `--resume` rebuilds the summary from the files a run left (when it died after its fits); `--settle <prior> <smooth>` refits the table at a prior chosen by `pickprior.py` and rewrites the recipe. |
| `apply_recipes.py` | Puts the refitted recipes into `CameraLook.swift`, the tables into `Resources/Looks`, and re-pins the tests. |
| `residual.py` | What the colour leaves (reference minus RetroSnap, in CIELAB) by position, lightness and hue, and the largest remaining structure per camera: a spatial layer, a tone gap or a table gap. |
| `refit.py` | The joint parametric fit on every pair of a camera at `--reg 3` and at `--reg 8 --hue-reg 2`, with `sanity.py`'s swing, and the pick. |
| `loo.py` | Leave-one-out on the table: fitted on all pairs but one, measured on the one left out, for each pair; its "fitted" column is the table on disk. The held-out median is what an unseen picture gets. |
| `pickprior.py` | Picks each camera's table prior and smoothness from `loo.py` runs by the smallest mean held-out median (the lower prior on a tie): generalisation measured, not the gap between fitted and held-out, which shrinks just as well by fitting worse. |
| `report.py` | One table per camera from the renders: RetroSnap against the reference, the fit, parity, grain, detail, face and whites on every pair. |
| `roundtable.py` | One table per camera for the round from the files under `ref/pairs/refine/`: the median on every picture before and after, the floor and the gate, the held-out median, the face, the whites, the grain ratio, the clipping, then halation, blur, prior, the residual's largest structure and the banding. |
| `exceed.py` | The brief's "Exceed" list as numbers against the reference: clipping, banding, grain at 12 and 48 MP, metadata, viewfinder against export (with `ExceedTests`). |
| `glow_grain.py` | How coloured the grain is and what the reference adds next to highlights, for RetroSnap's renders against the references. |
| `frames.py` | RetroSnap's exports (`ReferenceExportTests`) beside the reference app's screens, canvas to canvas, and `--sheet` stacks them into one sheet; `--per-camera <dir>` writes one sheet per camera, short enough to read on a phone. |
| `seed_simulator.py` | Puts the reference inputs into the booted simulator's live library, so `-rsLive 1 -rsScreen result -rsPhoto selfie` shows the real pictures on the real screens. |
| `shoot.sh` | Every designed scenario screenshotted from the installed app, for before/after pixel diffs. |
| `device_probe.py` | A connected phone's look-screen screenshots (from `testLookScreensAreKeptAsScreenshotsForTheDeviceProbe`) against the simulator's: whether the phone draws what the simulator draws. |
| `verify.sh` | A batch's definition of done, start to finish, on the booted simulator. |
| `screen_vs_bake.py` | A Viewer screenshot against the export of the same photo (from `BakeVersusScreenTests`); `--points W H --safe-top T` for a phone's screen (an iPhone 15 is 393 852 59). |
| `colour.py` | Shared maths: sRGB/CIELAB, ΔE2000, and the colour stage exactly as `RetroLook.metal` evaluates it (matrix, curves, hue terms), with `ColourStage.from_json` for a fit's JSON. |

Python with numpy, Pillow and scipy: `python3 -m venv venv && venv/bin/pip install numpy pillow scipy` (the system `/usr/bin/python3` if Homebrew's cannot make a venv), then `venv/bin/python -I tools/<script>.py …` from the repository root. `ref/` is gitignored, so everything here works only on a machine that has the reference material. Everything is measured in sRGB: an iPhone's photos and screenshots are Display P3 and are converted on loading.
