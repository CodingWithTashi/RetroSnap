# Camera lineup

The plan for growing RetroSnap from 5 cameras to the 38 in Dazz Cam's lineup, taken from the six screenshots in `docs/app-camera-video-list/` (the reference app's photo row and video row, captured 12 October 2026; app version not recorded). Read this before adding or changing a camera. The brief behind it is `docs/research-brief.md`.

## Goal

**Every camera's output matches the reference app's by measurement, and beats it in quality.** "Match" is the brief's definition: measured perceptual parity on tone curve, colour rendering, grain, halation, vignette, aberration, softness, light leaks, frames, aspect ratio and date stamp. "Beat" is its "Exceed" list: full-resolution output, viewfinder equals export, banding-free gradients, highlight roll-off, resolution-independent grain, metadata kept, battery and thermal behaviour.

Everything is ours: recipes, shaders, icons, frames, grain and leak textures. The names are the one exception: at the owner's direction (12 October 2026, D6) a camera is named in the app exactly as the reference app names it.

**The UI and UX do not change in functionality.** A new camera is an entry in the existing carousel, a `CameraStyle` case and a `CameraLook` recipe. Cameras that would need more than that are flagged under "Decisions".

## How to use this file

- Work goes in batches of five. Batch 1 is the five cameras with reference material in hand; after that, the five whose references arrive next, in the suggested order under "Batches".
- One batch at a time: add the five, build, run the tests, check each camera with `-rsScreen look -rsCamera <id>`, compare with the references, tick them off here.
- `id` is the `CameraStyle` raw value. It is written to disk (`library.json` and the user defaults), so once a camera has shipped its id never changes. Names, badges and summaries can change freely.
- A camera's name in the app is its Reference name, spelled exactly as in the tables (D6, decided by the owner on 12 October 2026). The "Name (proposal)" column is kept only as the fallback should the owner decide otherwise for a batch. The unit tests and UI tests assert on camera names, so a rename touches them.

## Ground rules

1. **Reference photos, not reference files.** A look is matched by comparing RetroSnap's output with the reference app's output for the same input. We measure and imitate the result; we never open the other app's binary or assets, and we never ship a LUT or texture lifted 1:1 from its output. Measurements are calibration targets for our own parametric model.
2. **Colour and tone are matched by measurement; textures are ours.** Grain, leaks, dust, frames and stamps are generated or drawn by us and are allowed to be better than the reference.
3. **A camera is a `CameraStyle` case plus a `CameraLook` recipe.** The pipeline grows new layers when a batch needs them ("Pipeline work"), but a camera never gets a view of its own.
4. **Capture modes are not looks.** D Half, D3D, Golf and Slide P need more than a recipe (two shots in one frame, a three-frame wiggle, a grid of frames, a projector playback). They are listed, but each needs a decision before its batch, because it changes what the shutter does.

## Reference material (`ref/`, gitignored except its README)

How the references are made: a stock iPhone Camera photo is **imported into the reference app**, each camera is applied to it, and the result screen is **screenshotted** (the reference app does not save without its paid tier). So:

| Folder | Contents |
|---|---|
| `ref/photo-input/` | The stock Camera photos that were imported. Today: `input.JPG`, 4032×3024, a selfie in a subway car (landscape); `input_1.JPG`, 4284×5712 upright, a dune landscape under a cloudy sky with a wooden post in front (added 12 October 2026 for the held-out check). |
| `ref/photo/<reference name>/` | For that camera: screenshots of the result screen with the input applied (the fitting pair), and sometimes the reference app's own sample picture for the camera (no input; texture reference by eye). Filenames are whatever the phone gave them; a later picture's result is `output_<n>.*`. One result is a saved export rather than a screenshot: CPM35's `output_1.jpg`, 2688×4033 with the input's EXIF, which is the better evidence for grain and softness (see "Re-verifying a shipped batch with a new picture"). |
| `ref/video/<reference name>/` | The same for video cameras, as clips when they exist. |

What a screenshot is good for: tone, colour, frames and layout, at screen resolution (the picture is about 900 px wide). What it is not good for: grain structure and fine texture, which need a saved export; until one exists, grain is authored from film references, not fitted. The result screenshots carry the reference app's banner and close button: crop to the picture before measuring. Whether the reference app's preview equals its export is unknown (no export available); treat preview measurements as the target and note the uncertainty.

The input is landscape. The reference app rendered it landscape inside each camera's own canvas (a 3:2 picture inside a horizontal film strip for 135 NE; a 3:2 picture inside a square cardboard mount for D Slide). RetroSnap's photos are portrait, so the frame layers must be designed for portrait and checked with a portrait input too.

## Counts

| | Reference | Already in RetroSnap | New looks | Not a look |
|---|---|---|---|---|
| Photo cameras | 28 | 9 (`film` `disp` `inst` `digi`, and batch 1: `negative` `plastic35` `slide` `mediumFormat` `tlr`) | 17 | Original, Collage |
| Video cameras | 10 | 1 (`vhs`) | 8 | Original V |

RetroSnap records video as a mode of the camera screen (`CaptureMode`, `-rsVariant videoMode`), not as a property of a camera. The reference app's video row therefore maps to cameras whose looks are tuned for moving pictures; whether they also take stills, and whether photo cameras also record, is decision D4.

## Photo cameras (28)

Row order is the reference app's, reconstructed from screenshots IMG_5879 → 5880 → 5881 → 5882 → 5877 → 5878 (the row starts at Original). The exact order between screenshots is a best guess and does not matter. "R" and "β" are badges the reference app shows (recent, beta). ☐ becomes ☑ when the camera ships.

| # | Reference | Icon | What it is | id | Name (proposal) | Needs | Refs | Done |
|---|---|---|---|---|---|---|---|---|
| 1 | Original | Black iPhone back | The phone's own photo, no look | `plain` | Original | nothing (D5) | | ☐ |
| 2 | GRD R | Blue-grey compact, blue lens ring | Street-snap digital compact: high contrast, punchy, cool, strong vignette | `street` | Street Snap | lut, digital, vignette | | ☐ |
| 3 | KV80 R | Silver/black box camera "KV80", big lens | 1980s electronic still/video camera: low resolution, soft, colour bleed | `stillvideo` | Still Video | lut, digital, soft; verify in app | | ☐ |
| 4 | FXN R | Silver retro rangefinder, red ball on top | Modern digital rangefinder with film simulation: clean, muted | `rangefinder` | Rangefinder | lut, digital | | ☐ |
| 5 | FQS R | Green/black disposable | Fuji-style disposable: cooler greens, cyan shadows, hard flash, grain | `dispCool` | Disposable Cool | lut, grain, flash, leak | | ☐ |
| 6 | PAF R β | Black/orange folding instant | Folding instant: wide white frame, warm fade, soft, low contrast | `foldInstant` | Folding Instant | lut, frame:wide, fade | | ☐ |
| 7 | SRX R | Bright blue toy camera | Plastic toy camera: saturated, heavy vignette, soft corners, light leaks | `toy` | Toy Camera | lut, soft, vignette, leak | | ☐ |
| 8 | OFM R β | Black SLR "OFM" | 1970s manual SLR on colour negative: natural, fine grain, slight warmth | `slr` | Manual SLR | lut, halation, grain | | ☐ |
| 9 | IR | Pastel blue/red small compact | Unclear from the icon: infrared false colour, or a pastel toy digital | `ir` | Infrared | verify in app first | | ☐ |
| 10 | D Half | White/black half-frame | Half-frame 35mm: two vertical shots side by side in one frame | `half` | Half Frame | lut, grain, frame:half, **mode** (D3) | | ☐ |
| 11 | Classic U | Silver/black SLR, red button | Classic 35mm SLR on consumer colour film: warm, moderate grain | `classicSLR` | Classic SLR | lut, halation, grain | | ☐ |
| 12 | Inst SQC | Brown/white square instant | Square instant: square white frame, soft pastel | `instSquare` | Instant Square | lut, frame:square, ratio | | ☐ |
| 13 | CT2F | Beige 1990s premium compact | Premium point-and-shoot: high contrast, rich colour, fine grain, strong flash fall-off | `compactPro` | Premium Compact | lut, halation, grain, stamp:date | | ☐ |
| 14 | D Classic | Silver/black compact 35mm | Everyday 35mm point-and-shoot; the reference app's default | `film` (exists) | 35mm Film | re-tune | | ☐ |
| 15 | Inst C | White instant, red button | Mini instant print | `inst` (exists) | Instant | re-tune, frame:mini | | ☐ |
| 16 | CPM35 | Silver/grey plastic compact | Cheap 1990s plastic point-and-shoot: soft, low contrast, greenish, flash | `plastic35` | CPM35 | lut, soft, grain, flash | Fitted on both pictures together (`ref/pairs/plastic35`, `plastic35-1`; `--reg 3`): RetroSnap vs reference 2.4 on the selfie, 2.3 on the dunes (held out before the refit: 3.2). The dunes result is a saved export, 2688×4033, which keeps 0.92 of the input's fine detail in the middle and 0.90 at the corners, so batch 1's blur and soft corners are gone. Grain ratio 1.2 and 1.2. The reference crops to 3:2 and stamps a yellow Japanese-format date; the photo stays 3:4 (D2) and uses the existing orange date stamp until the stamp variants of batch 2. The flash fall-off is batch 2's `flash` layer. | ☑ |
| 17 | D Slide | Cardboard slide mount with a sunset | Slide/reversal film: high saturation, deep blacks, cool shadows, in a grey cardboard mount on a light background | `slide` | D Slide | lut, frame:slide, ratio | Fitted on both pictures together (`ref/pairs/slide`, `slide-1`, 634 and 435 px wide, the inner 6% masked for the mount's shadow; `--reg 3`): 2.9 on the selfie, 2.4 on the dunes (held out before: 3.8). Grain ratio 1.4 and 1.1. The second screenshot's mount is a different, striped card lying at 1.8°, deskewed before the crop: the reference app varies its mount. Mount, dimples and window shadow drawn by eye from the first screenshot. | ☑ |
| 18 | S Classic | Black twin-lens reflex | Medium-format TLR: square, creamy tones, very fine grain, possibly monochrome | `tlr` | S Classic | lut, ratio, bw? | Fitted on both pictures together (`ref/pairs/tlr`, `tlr-1`; `--reg 3`): 2.0 on the selfie, 2.9 on the dunes (held out before: 3.6). Grain ratio 1.1 and 1.1. It is colour, not monochrome. The black rebate with the edge print down the right side comes from the app's sample strip. | ☑ |
| 19 | 135 NE | 35mm film strip with a sky photo | 35mm colour negative shown as the scanned strip: sprocket holes above and below, orange edge print | `negative` | 135 NE | lut, grain, frame:strip | Fitted on both pictures together (`ref/pairs/negative`, `negative-1`; `--reg 1`, the dunes weighted 5×): 3.5 on the selfie, 3.6 on the dunes (held out before: 5.6; batch 1 measured 3.0 on the selfie alone). **Over the 3.0 line on both**: the reference turns the blue sky cyan-grey and the greens yellow, which the matrix and curves cannot express (the dunes alone fit no better than 3.45), so this is the fit with the smallest worse median, kept as "Measuring a pair" says, and the first case for the hue-dependent terms under "Pipeline work". Grain ratio 1.1 and 1.2; halation set by eye against the window light. Strip proportions from real 135 film, checked against the app's sample strip. | ☑ |
| 20 | S 67 | Black medium-format SLR "67" | 6×7 medium format: 4:5, shallow depth, ultra-fine grain, rich tones | `mediumFormat` | S 67 | lut, ratio, soft background? | Fitted on both pictures together (`ref/pairs/mediumFormat`, `mediumFormat-1`; `--reg 3`, the dunes weighted 2×): 2.8 on the selfie, 2.9 on the dunes (held out before: 4.5). Grain ratio 1.0 and 1.1. The reference is 5:4, so 4:5 upright. No background blur in the reference. Black rebate with frame numbers along the top and the film name along the bottom. | ☑ |
| 21 | D3D | Orange three-lens "3D" | Lenticular 3D wiggle: three frames across a sweep, played as an animation | `wiggle` | 3D Wiggle | **mode** (D3) | | ☐ |
| 22 | D FunS | Yellow/red disposable with flash | Warm disposable with on-camera flash | `disp` (exists) | Disposable | re-tune | | ☐ |
| 23 | DQS | Green/red/yellow disposable | Punchy, warm disposable with hard flash | `dispPunch` | Disposable Punch | lut, grain, flash, leak | | ☐ |
| 24 | Collage | Tile of three photos | A layout mode, not a look; RetroSnap already has Collage | — | — | skip | | — |
| 25 | CCD R | Silver/champagne digicam "6.0" | Early-2000s CCD compact | `digi` (exists) | Digicam | re-tune, digital | | ☐ |
| 26 | HOGA | Red/white toy camera "HOGA" | Plastic-lens medium format: heavy vignette, blurry corners, leaks, saturated | `plasticLens` | Plastic Lens | lut, soft, vignette, leak | | ☐ |
| 27 | Golf | Green/black body with a grid of small lenses | Multi-lens action sampler: 4 or 8 sequential frames in a grid | `multiLens` | Action Sampler | **mode** (D3) | | ☐ |
| 28 | GR F | Black compact | Film street compact: 28 mm, crisp, contrasty, neutral or monochrome | `streetFilm` | Street Film | lut, halation, grain, bw? | | ☐ |

## Video cameras (10)

Row order from the screenshots: IMG_5878 shows the start of the row, IMG_5877 the end.

| # | Reference | Icon | What it is | id | Name (proposal) | Needs | Refs | Done |
|---|---|---|---|---|---|---|---|---|
| 1 | Original V | Black iPhone back, red play badge | The phone's own video, no look | `plainVideo` | Original | nothing (D4, D5) | | ☐ |
| 2 | V FunS | Yellow/red disposable-style camcorder | Disposable-camera look on video: warm, flashy, grainy | `dispVideo` | Disposable Video | lut, grain, video:jitter | | ☐ |
| 3 | Kino | White box cine camera with a hand crank | 1920s silent cinema: monochrome, flicker, low frame rate, scratches, vignette | `kino` | Silent Film | bw, video:flicker, video:scratches, video:framerate | | ☐ |
| 4 | 16mm | Grey 16 mm film camera, red record dot | 16 mm colour film: gate weave, grain, halation, warm fade | `film16` | 16mm Film | lut, halation, grain, video:weave | | ☐ |
| 5 | Glow | Glossy purple/pink camcorder with sparkles | Dreamy soft bloom, pink/purple haze | `glow` | Glow | lut, bloom | | ☐ |
| 6 | VHS | Black/grey VHS camcorder | VHS tape | `vhs` (exists) | Camcorder | re-tune, video:tracking | | ☐ |
| 7 | 8mm | Black/yellow camera with an "8" badge | Super 8 home movies: heavy grain, warm, vignette, frame jitter, 4:3 | `super8` | Super 8 | lut, grain, video:jitter, ratio | | ☐ |
| 8 | V Classic | White/black camcorder with a stripe | 1990s analogue camcorder: softer than VHS, on-screen timestamp | `hi8` | Classic Camcorder | lut, soft, stamp:vhs variant | | ☐ |
| 9 | Slide P | White/black slide projector, orange dot, "D RA 150" | Slide-projector show: stills projected with flicker, dust, warm lamp, click transitions | `projector` | Slide Projector | **mode** (D3): probably plays photos, verify | | ☐ |
| 10 | DCR | Beige Handycam "DCR 20x" | Early-2000s MiniDV: interlace combing, cool cast, timestamp | `minidv` | MiniDV | lut, video:interlace, stamp:date variant | | ☐ |

## Pipeline work

New layers, and the batch that introduces each. A new layer is added in both renderers (`PhotoLookView` and `LookRenderer.render`, same order) and, if it needs a shader uniform, in all four of `RetroLook.metal`, `LookShaders`, `LookRenderer`, `LookUniforms`.

| Layer | Batch | What |
|---|---|---|
| lut | 1 ☑ | `ColorStage`: a 3×3 matrix with offsets, then a monotone cubic tone curve per channel through six fixed knots (`rsColor` / `rsColorKernel`), fitted from the reference pair by `tools/fit.py`. 30 numbers per camera, smooth by construction (no banding), and enough for a median ΔE2000 of 2–3 against the reference. The CSS `LookFilter` chain stays for the first five until they migrate in batches 2 and 6. Hue-dependent terms (per-hue saturation) are not in yet; add them when a fit needs them. 135 NE is the first that does: on the second picture its reference turns blue to cyan-grey and green to yellow, and the best the matrix and curves reach is 3.5 on both pictures. |
| halation | 1 ☑ | `Halation`: the highlights above a threshold, tinted, blurred by a radius in points and screened over the picture (`rsHalationGlow`, and `.blur` / `CIGaussianBlur` + screen in the two renderers). |
| grain | 1 ☑ | `FilmGrain`: gradient noise with a clump size in points, an amplitude at mid grey that falls to nothing in black and white, and a mono-to-colour mix, added to the picture; the Grain slider scales the amplitude. Authored by measurement of the screenshots' texture (`tools/grain.py`), not fitted. The CSS `grain` opacity stays for the first five. |
| frame:strip | 1 ☑ | `LookFrame.filmStrip` + `LookFrameView`: the film at real 135 proportions (24mm picture on 35mm film), perforations at the KS pitch, our own edge print and DX barcode. |
| frame:slide | 1 ☑ | `LookFrame.slideMount`: a textured card with pressed dimples, a rounded window with the film in its shadow, on a light table. |
| ratio | 1 ☑ | `LookFrame.window(in:)`: the picture at its ratio inside the photo's own box (D2); `LookFrame.mediumFormat` (4:5) and `.square` draw the black rebate with frame numbers and edge print. `BakeLayout(source:frame:)` keeps every pixel of the crop and grows the canvas around it; `PhotoExporter` rasterises `LookFrameView` with `ImageRenderer` (like the stamps) and lays it over the baked picture. |
| soft | 1 ☑ | `Softness`: a blurred copy shows through a radial mask from `inner` to `outer` of the half-diagonal (`rsSoftMask`, `.mask` / `CIBlendWithMask`). |
| frame:mini | 2 | The real mini-instant print ratio and border for `inst`, replacing the current white frame. |
| digital | 2 | CCD noise, sharpening halos, JPEG blockiness, reduced resolution. |
| stamp:date variants | 2 | Orange seven-segment date in different positions and fonts. |
| flash | 2 | On-camera flash fall-off, already partly there as `flash`. |
| leak | 3 | Light-leak overlays, randomised per shot. |
| ca, vignette | 4 | Chromatic aberration; lens vignette with a shape. |
| frame:square, frame:wide, frame:half | 4 | Square instant, folding instant and half-frame canvases (frame:half depends on D3). |
| video: interlace, tracking, timestamp variants; bloom | 6 | Tape-family layers. |
| video: jitter, weave, flicker, scratches, framerate; bw | 7 | Film-motion layers and monochrome. |

## Decisions

Each is needed before the batch named. Recommendations are defaults: a session may take them without asking unless the owner has said otherwise.

- **D1 (batch 1) The design HTML.** `CLAUDE.md` says looks are transcribed from the `LOOKS` table in `docs/retrosnap-mobile-app-design/project/Photo.dc.html`. Options: extend that table for every camera, or let the app lead from here and keep the HTML as the record of the first five. Recommendation: the app leads. **Taken in batch 1:** the app leads; the HTML is the record of the first five and is not extended.
- **D2 (batch 1) Picture ratio and canvas.** Cameras whose output is not the plain 3:4 photo (3:2 in a strip, 3:2 in a square mount, square, 4:5): draw the picture at its ratio inside RetroSnap's photo with the canvas around it, no viewfinder change. Recommendation: that. **Taken in batch 1:** the canvas is the photo's own box and follows the `framed` flag exactly like the Instant print: the gallery tile and the collage show the whole 3:4 photo, the Result, Viewer and Edit screens and the saved file show the canvas with the picture in its window. The viewfinder dims a band to hint at the ratio, as it already did for Instant. A camera with no canvas in the reference (CPM35 crops to 3:2 with nothing around it) keeps the whole 3:4 photo rather than gaining black bars.
- **D3 (batches 4, 5, 7) Capture modes.** D Half (two shots into one frame), D3D (three-frame wiggle played as an animation), Golf (a grid of sequential frames), Slide P (projector playback of photos). Each changes the shutter or the result screen, which is a functionality change. Options per camera: skip, ship as a look only (D Half with a half-frame canvas and one shot), or build the mode. Recommendation: look only, and revisit.
- **D4 (batch 6) Video cameras.** Give `CameraStyle` a family (photo or video) so the carousel shows the right ones in each `CaptureMode`, or let every camera do both. Recommendation: a family, matching the reference app's two rows, no new UI.
- **D5 Original / Original V.** A no-look camera is cheap (an empty recipe). Recommendation: add `plain`; decide `plainVideo` with D4.
- **D6 Names.** Confirm the names before each batch. **Taken in batch 1:** the owner wants the app to use the reference app's names, exactly: 135 NE, CPM35, D Slide, S 67, S Classic. From here the Reference column is the name and the proposal column is the fallback. Still open for batch 2: whether the four existing cameras it re-tunes (35mm Film, Disposable, Instant, Digicam) take the reference names (D Classic, D FunS, Inst C, CCD R) as well.

## Batches

Five per batch. Batch 1 is the five with references in hand; the rest is the suggested order and moves with whatever references arrive next.

| Batch | Cameras | Pipeline work | Decisions first |
|---|---|---|---|
| 1 ☑ | 135 NE `negative`, CPM35 `plastic35`, D Slide `slide`, S 67 `mediumFormat`, S Classic `tlr` | lut, halation, grain, frame:strip, frame:slide, ratio, soft | D1, D2, D6 (shipped 12 October 2026, named as in the reference app; re-verified on a second picture and refitted on both the same day; the export was checked against the screen on the simulator, not yet on a device) |
| 2 | D Classic → `film`, D FunS → `disp`, Inst C → `inst`, CCD R → `digi` (re-tuned), CT2F `compactPro` | frame:mini, digital, stamp:date variants, flash | D6 |
| 3 | GR F `streetFilm`, Classic U `classicSLR`, OFM R `slr`, DQS `dispPunch`, FQS R `dispCool` | leak | D6 |
| 4 | SRX R `toy`, HOGA `plasticLens`, Inst SQC `instSquare`, PAF R `foldInstant`, D Half `half` | ca, vignette, frame:square, frame:wide, frame:half | D3 (D Half), D6 |
| 5 | GRD R `street`, FXN R `rangefinder`, IR `ir`, KV80 R `stillvideo`, D3D `wiggle` | — | D3 (D3D), D6; verify IR and KV80 in the app |
| 6 | VHS → `vhs` (re-tuned), V Classic `hi8`, DCR `minidv`, V FunS `dispVideo`, Glow `glow` | video: interlace, tracking, timestamp variants; bloom | D4, D6 |
| 7 | 8mm `super8`, 16mm `film16`, Kino `kino`, Slide P `projector`, Golf `multiLens` | video: jitter, weave, flicker, scratches, framerate; bw | D3 (Slide P, Golf), D6 |

Not in a batch: Original (`plain`, D5), Original V (`plainVideo`, D4/D5), Collage (exists).

## Per-camera checklist

What one new camera touches. The carousel, `stepped(by:)`, `-rsCamera <id>` and `-rsScreen look -rsCamera <id>` all follow `CameraStyle.allCases` and need nothing.

1. `Retrosnap/Models/CameraStyle.swift`: the case (raw value = `id`; declaration order is carousel order), `name`, `badge`, `summary`, `accentHex`, `cardTintHex` (`color-mix(in oklab, accent 14%, #1B1916)`, precomputed), `sample`.
2. `Retrosnap/DesignSystem/Look/CameraLook.swift`: the recipe.
3. The card's sample picture: `sample` → `Assets.xcassets/Samples/photo-<n>` and `photo-<n>-thumb`. Reuse an existing pair or add one; a new pair also wants a `tile-<n>` if the picture appears in onboarding. Batch 1 moved five pairs over from the debug-only `MockSamples.xcassets` (1043, 42, 110, 1074, 1025), so a seed photo's picture can be a card's picture too; the four pairs left there (1011, 1016, 1080, 29) are the next to move.
4. A new stamp: `LookStamp` and `DesignSystem/Look/StampViews.swift`, then both renderers (`PhotoLookView`, `LookRenderer.render`). A new frame: a `LookFrame` case with its window in `LookFrame.swift` and its artwork in `LookFrameView.swift`; the renderers, `BakeLayout` and `PhotoExporter` take any frame from there. Artwork is drawn with `Canvas` and no shaders, because `ImageRenderer` rasterises it for the file.
5. A new uniform: `RetroLook.metal`, `LookShaders`, `LookRenderer`, `LookUniforms`.
6. Tests in `RetrosnapTests/DesignSystem/LookRenderModelTests.swift`: the `stampKindPerCamera` and `framedCamerasGetTheirFrame` arguments, and the recipe's numbers where they are pinned (`aFittedCameraDrawsItsColourStage`, `LookUniformsTests`, `LookRendererTests.aFittedCameraRunsItsColourStage`, whose expected pixels come from `tools/colour.py`). `ReferencePairTests` and `BakeVersusScreenTests` take the camera in their argument lists. `FormattingTests` and `CameraViewModelTests` pin the wrap-around of the carousel, so appending a camera changes them.
7. UI tests only when an existing camera's copy changes: `RetrosnapUITests` asserts "35mm Film" and "Instant".
8. Reference comparison: the pair in `ref/photo-input/` and `ref/photo/<reference name>/` when it exists (crop the screenshot to the picture, fit the colour stage from the pair, see "Measuring a pair"); otherwise the reference app's sample picture, by eye.
9. The carousel and the strip scroll the selected card into view, so no camera order is special; `-rsScreen result -rsCamera <id>` poses the first seed photo as taken with the camera, for the screenshots.

## Measuring a pair

The scripts live in `tools/` (Python; make a venv with `python3 -m venv venv && venv/bin/pip install numpy pillow scipy`, and run them with `venv/bin/python -I`). The loop for one camera:

1. `tools/refscan.py` and `tools/refcrop.py` find the picture inside the reference screenshot and save the crop (the result screen's banner, close button and the camera's own canvas are outside it).
2. `tools/fit.py <id> ref/photo-input/input.JPG <crop> ref/pairs` aligns the crop with the input (scale and offset, by the correlation of luminance gradients), writes the pair at the reference's resolution (`ref/pairs/<id>-input.png`, `<id>-reference.png`), fits the colour stage plus the look's vignette by least squares on CIELAB differences, and writes `<id>.json` (the numbers for `CameraLook`) and `<id>-report.png` (input | fit | reference, with the curves). `--mask` keeps a date stamp out of the fit, `--inset` the mount's shadow, `--reg` pulls the matrix toward identity.
3. `tools/sanity.py ref/pairs/<id>.json` runs the fit over a hue sweep and a grey ramp: a fit that swings a hue it never saw by tens of degrees wants more `--reg`.
4. Transcribe the JSON into the camera's `ColorStage` in `CameraLook.swift`.
5. `xcodebuild test … -only-testing:RetrosnapTests/ReferencePairTests` renders every pair through the real pipeline (`LookRenderer`, at the size the Viewer gives the picture) into `ref/pairs/<id>-retrosnap.png`. The test is skipped on a machine without `ref/`.
6. `tools/compare.py ref/pairs/<id>` prints the median and 95th percentile ΔE2000 of RetroSnap against the reference, of the fit against the reference, and of RetroSnap against the fit (pipeline parity). `tools/grain.py ref/pairs/<id>` measures the grain of the reference and of RetroSnap's render in the same flat blocks, and their ratio at mid grey: the reference's texture is what `FilmGrain` is tuned to. It also prints the detail each keeps where the input has some, in the middle and at the corners, which is what a camera's `blurRadius` and `Softness` are tuned to.

A camera with several pictures (`<id>`, `<id>-1`, `<id>-2`, … under "Re-verifying a shipped batch with a new picture"):

- Each new picture is cropped and aligned on its own with steps 1 and 2, under its pair name (`tools/fit.py <id>-<n> ref/photo-input/input_<n>.* <crop> ref/pairs …`). The single-picture fit this writes is only a bound: what the colour stage could reach on that picture alone. A canvas the reference app lays at an angle (the D Slide mount) is turned straight first with `tools/refcrop.py … --deskew`.
- The camera's fit is one colour stage over every pair at once: `tools/fit.py <id> <outdir> --pair ref/pairs/<id> --pair ref/pairs/<id>-1 --reg <r>`. Each pair counts the same whatever its size, so the recipe is as right on one picture as on the other; a pair's mask and inset come from its own JSON. When a camera cannot meet the tolerance on every picture, `--weight <pair>=w` leans the fit toward the picture that misses, and the fit kept is the one with the smallest worst median. The chosen fit's JSON and report are copied to `ref/pairs/<id>.json` and `<id>-report.png`, replacing the single-picture fit, so `tools/compare.py` measures parity against what is transcribed.
- `ReferencePairTests` renders every pair a camera has, and `tools/compare.py ref/pairs/<id> ref/pairs/<id>-1` and `tools/grain.py` measure each. Every pair must be within the tolerances.

Tolerances, set in batch 1 from what screenshots allow: **median ΔE2000 ≤ 3.0** for RetroSnap against the reference over the 4×4 box-filtered picture, **≤ 1.0** for RetroSnap against the Python fit (parity), and grain amplitude within a factor of 1.5 of the reference's high-pass standard deviation at mid grey. The grain left after the box filter is worth about 0.1 of the median on both sides of the comparison, so a camera at 3.0 ± 0.1 is at the line, not over it (batch 1 on its first picture: `negative` measured 3.02, the other four 1.8 to 2.7; after the second picture and the refit on both, four cameras measure 2.0 to 2.9 on both pictures and `negative` 3.5 and 3.6, kept as the fit with the smallest worse median). A camera with several pictures must meet them on every picture. Vignette fall-off is fitted as part of the colour stage (the look's radial gradient, with its amount as the free parameter). The screenshot is a preview at screen resolution; whether the reference app's export differs is unknown (D: no export available), so these numbers are against its preview.

## Definition of done for a batch

- The Debug simulator build and the Release device build (`generic/platform=iOS`, `CODE_SIGNING_ALLOWED=NO`) both compile.
- `RetrosnapTests` is green (`-only-testing:RetrosnapTests`).
- Every new camera is screenshotted at `-rsScreen look`, `-rsScreen camera` and `-rsScreen result` with `-rsCamera <id>`, and looked at next to its reference.
- The cameras the batch did not touch are diffed against before-screenshots of the same scenarios: `compare -metric AE before.png after.png null:` prints 0.
- One export per new camera is checked on a device: the Core Image bake matches the screen. Until a device is at hand, `BakeVersusScreenTests` plus `tools/screen_vs_bake.py` do it on the simulator (batch 1: median ΔE2000 ≤ 0.2 for all five).
- The tables in this file are ticked, and the `Refs` column says what each camera was fitted from.

## Starting a session

Open a new conversation in the repo and paste:

> Read `docs/camera-lineup.md` and `docs/research-brief.md`. Start batch 2 (D Classic, D FunS, Inst C, CCD R, CT2F). Take the recommended answers for the open decisions. Reference material is under `ref/`.

### Re-verifying a shipped batch with a new picture

A batch is fitted on one pair, so its real accuracy is only known on a picture the fit never saw. To check one, import a second picture into the reference app, apply each camera, screenshot the result screen as before, and save the files as `ref/photo-input/input_<n>.*` and `ref/photo/<reference name>/output_<n>.*` (the phone's own extension). Pairs made from them are `ref/pairs/<id>-<n>-…`, and after a refit the camera's fit at `ref/pairs/<id>.json` is the one over every picture (the single-picture fits of batch 1 are kept under `ref/pairs/batch1/`). Then paste:

> Read `docs/camera-lineup.md` and `docs/research-brief.md`. Batch 1 (135 NE `negative`, CPM35 `plastic35`, D Slide `slide`, S 67 `mediumFormat`, S Classic `tlr`) is built; the names in the app are the reference app's exact names and the ids never change. I have added a second reference pair: the new input picture is `ref/photo-input/input_1.*`, and the reference app's result for it is `ref/photo/<reference name>/output_1.*` in each of the five folders. Verify the five cameras against it, then refine.
>
> 1. Held-out check first, with the recipes as they are. Crop each `output_1` (`tools/refscan.py`, `tools/refcrop.py`), align it with `input_1` through `tools/fit.py` using `<id>-1` as the pair name (so the pair lands at `ref/pairs/<id>-1-input.png` and `<id>-1-reference.png`), extend `ReferencePairTests` to render every pair a camera has, and measure with `tools/compare.py ref/pairs/<id>-1` and `tools/grain.py`. Report, per camera, the median ΔE2000 of RetroSnap against the new reference and the grain ratio before touching any recipe. The first pair is what the recipes were fitted on, so this number is the real accuracy.
> 2. For any camera outside the tolerances (median ΔE2000 ≤ 3.0, grain within 1.5×), refit the colour stage on both pairs together: extend `tools/fit.py` to take several pairs and minimise over their union, keep batch 1's `--reg` unless `tools/sanity.py` says otherwise, transcribe, and re-measure both pairs. Both must be within tolerance with parity ≤ 1.0; if a camera cannot meet 3.0 on both, take the fit that minimises the worse of the two medians and say so. Re-check grain, halation and softness against the new reference by the same loop. Leave a camera alone if it is within tolerance on both pairs.
> 3. Definition of done as in the plan: unit tests, UI tests, the Release device build, the baseline scenarios pixel-identical, and `BakeVersusScreenTests` plus `tools/screen_vs_bake.py` for every camera whose recipe changed.
> 4. Update the plan: the Refs column with both pairs' numbers, "Measuring a pair" for a camera with several pairs, and the decision log if a tolerance changes. Copy the chosen fit JSON and reports into `ref/pairs/`.
>
> Don't commit. Finish with a table per camera: the held-out median ΔE2000 before any change, and after a refit the median on both pairs, the parity and the grain ratio.

What the first re-verification taught (12 October 2026, `input_1`): a camera fitted on one picture missed the tolerance on the next one by 0.4 to 2.6 ΔE, and refitting on both brought four of the five back under 3.0 on both pictures; the fifth, 135 NE, is limited by a hue-dependent shift (blue sky to cyan-grey, greens to yellow) that the matrix and curves cannot express, and is the first case for the hue-dependent terms listed under "Pipeline work". A saved export (CPM35's `output_1.jpg`) measured sharper than the same camera's screenshot: the screenshot keeps 0.81 of the input's fine detail, the export 0.92, with the same grain amplitude, so a screenshot's softness is the screen's, not the look's, and `blurRadius` and `Softness` are tuned to an export when there is one. The D Slide mount in the second screenshot lay at 1.8°, which `tools/refcrop.py --deskew` takes out before the crop.

What the owner still has to supply, when available: the reference app's version and the date of the screenshots; references for the next five cameras (import the same `input.JPG`, apply the camera, screenshot the result into `ref/photo/<reference name>/`); saved exports if the paid tier is ever available, which would make grain fittable rather than measured from screenshots. Batch 1 left one thing for the owner: the device check of an export.
