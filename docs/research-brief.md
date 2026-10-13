# Research brief (context)

This is the brief the project owner wrote for the camera work, kept verbatim. It is **context, not a literal task list**: the goal it sets is what counts, and its definitions of "Match", "Exceed", the evidence grades and the method boundary are the project's definitions. The plan that turns it into work is `docs/camera-lineup.md`.

Two things it leaves open that the plan settles:

- The catalog in scope is Dazz Cam's lineup (`docs/app-camera-video-list/`, 28 photo and 10 video cameras). The other reference apps it names are for technique research only; nothing is built from their catalogs.
- "Better" means image quality and the "Exceed" list below. The app's UI and UX do not change in functionality: a new camera is an entry in the existing carousel.

---

ROLE
You are a senior imaging engineer (iOS camera pipelines, Metal/Core Image, film and color science)
doing evidence-based technical research. Every important claim needs a source or a stated method.
No generic explanations of vintage photography: concrete, implementable engineering detail only.

OBJECTIVE
Give an iOS team everything needed to build RetroSnap, a vintage-camera app whose cameras reproduce
the character of Dazz Cam's camera line-up as closely as can be measured and exceed its image
quality, using our own on-device implementation. Use third-party libraries only where they clearly
beat building in-house.

DEFINITIONS (use throughout)
- "Match" = measured perceptual parity with photos taken by the reference apps: tone curve, color
  rendering, grain, halation/bloom, vignette, chromatic aberration, lens distortion/softness, light
  leaks, frames, aspect ratio, date stamp. It does NOT mean copying their code, LUT/overlay/grain
  files, UI art, names or branding.
- "Exceed" = measurably better on: full-resolution output, viewfinder-to-export consistency,
  banding-free gradients, highlight roll-off, resolution-independent grain, metadata preservation,
  battery and thermal behavior.
- Propose pass/fail tolerances for both (e.g., median ΔE2000 on chart patches, grain amplitude vs
  luminance, vignette falloff in EV).

INPUTS I WILL SUPPLY (do not try to discover these; if something is missing, list it, continue with
public information, and mark the affected conclusions)
- The Dazz Cam camera list (names, categories, camera-picker screenshots) with app version and date.
- My own test photos from each reference app, shot with your protocol (Task 3), plus any film scans.

REFERENCE APPS (use these exact identities; look-alike apps with near-identical names exist)
- Dazz Cam: DAZZ PTE. LTD., App Store ID 1422471180. Primary target.
- NOMO CAM - Point and Shoot (formerly NOMO): Beijing Lingguang Zaixian Information Technology
  Limited, ID 1362548649.
- OldRoll - Vintage Film Camera: developer 梓杰 张, ID 1570093460.
- ProCCD - Digital Film Camera: ID 1616113199 (not CCD CamPro). Check whether it shares a studio or
  engine with OldRoll (its listing references OldRoll filters); treat as inference unless confirmed.
- FIMO - Analog Camera: Guangzhou Hongxiao Network Technology Co., Ltd., ID 1454219307
  (not FIMO 1903).
- Huji Cam: Manhole, Inc., ID 781383622. One disposable-camera look; analyze it as a single preset.
- Rarevision VHS: Rarevision LLC, ID 679454835. Video-only; use it solely for tape, temporal and
  date-stamp techniques.
Record app version and date for every observation; these apps update often.

SCOPE
- iOS only. Photo first; video is phase 2. Recommend a minimum iOS version and oldest supported
  iPhone with justification, and verify every API against current Apple documentation.
- Phase 1 = five hero cameras chosen from the Dazz line-up to cover distinct archetypes (e.g., 35mm
  color-negative compact, flash disposable/toy, early-2000s CCD compact, instant film with frame,
  slide/cross-process or B&W). The architecture must scale to Dazz's full catalog through
  data-driven presets, plus per-camera custom stages where needed (instant-film development
  animation, depth-based 3D, double exposure). State which cameras need bespoke code.

RULES
1. Evidence grades on every claim: A = documented or verifiable (docs, datasheet, paper, open-source
   code, store listing; link it); B = measured from app output (state method and data);
   C = inference (state the reasoning); D = unknown. Never present C or D as A or B. Never claim
   knowledge of proprietary code. Treat developer marketing ("what you see is what you get",
   "RAW, zero sharpening") as claims until measurements confirm them.
2. Method boundary. In scope: black-box analysis of photos I take with the apps. Out of scope:
   decompiling, extracting assets (LUTs, overlays, grain textures, fonts) or bypassing app
   protections. Dazz's terms prohibit copying parts of the app or its trademarks, extracting source
   code and making derivative versions. Use measurements as calibration targets for our own
   parametric models; do not recommend shipping LUTs or textures derived 1:1 from competitor
   output. Flag any step where measuring and copying blur, for legal review.
3. Prefer primary sources: Apple documentation and WWDC sessions, manufacturer datasheets
   (Kodak/Fujifilm characteristic curves, spectral dye density), peer-reviewed papers, standards
   (e.g., AV1 film-grain synthesis), GitHub repos (check license and maintenance), store listings,
   credible teardowns. Patents only where they are genuinely relevant prior art. Link directly to
   every source.

TASKS
1. Per-app catalog. For each app: every publicly documented camera/preset; the real camera or film
   stock it claims to emulate (grade the evidence; many are only "inspired by"); color, contrast,
   saturation, exposure behavior, highlight roll-off, shadows, grain, vignette, halation, chromatic
   aberration, lens distortion, light leaks, softness, date stamp, border, aspect ratio; what is
   automatic vs user-adjustable; special behaviors (film-development delay, negative saving, double
   exposure, color temperature/tint). Compare with real film/camera samples where licensed or
   public-domain references exist; otherwise specify what to shoot.
2. Implementation evidence. What can be established or reasonably inferred about capture APIs, GPU
   shaders vs Core Image, LUT size and interpolation, procedural vs texture grain, halation,
   aberration, light leaks, and how preview matches export. For each open question, give a
   black-box test that discriminates between hypotheses.
3. Measurement protocol (I will run it). Test scenes (ColorChecker, grayscale step wedge, smooth
   gradients, uniform gray card, point lights and high-contrast edges); repeated shots for grain
   fingerprinting (fixed texture vs procedural, tile period); different zoom, orientation and
   resolution; preview-vs-export comparison. Analysis: per-channel tone curves, 3x3 matrix plus
   saturation, ΔE2000, vignette radial profile, grain amplitude/PSD vs luminance, halation
   radius/tint, CA offset. Provide Python scripts if possible.
4. Hero-camera specification tables (5). Per camera: visual traits, evidence grade, processing-stage
   order, parameter ranges to calibrate (do not invent exact values), shader technique, LUT format,
   assets we must author ourselves, user-adjustable controls. Separate "verified" from "must be
   experimentally approximated".
5. Libraries and services. Compare maintained open-source and commercial options for LUT
   application, grain, halation/bloom, film-development simulation and GPU pipelines. Include at
   least: Core Image (CIColorCubeWithColorSpace, custom Metal kernels), Metal/MPS, MetalPetal,
   GPUImage3, film-emulation CLUT collections (check licenses), open-source film simulators and
   grain models (e.g., Filmulator; the Newson/Delon/Galerne stochastic grain model), and any
   commercial film-emulation SDK with a mobile license. Compare license, commercial-use terms,
   price, iOS support, performance, offline capability, output quality, maintenance. Verdict: what
   to adopt, what to build. Any cloud service must justify uploading users' photos.
6. RetroSnap architecture. Capture (AVCaptureSession/AVCapturePhotoOutput; RAW/ProRAW vs processed
   HEIF; neutralizing Apple tone mapping and sharpening; HDR gain maps; lens selection; depth for
   3D cameras); working color space (linear, wide-gamut, float16); ONE shared shader graph for
   viewfinder and export so preview = output, with tiled full-resolution export; 1D shaper + 3D LUT
   vs parametric; seeded, resolution-independent grain; overlays, frames, date stamp; HEIC/JPEG
   export that preserves EXIF; versioned preset schema (Codable/JSON). Performance: zero-copy
   camera-to-Metal (CVMetalTextureCache), preview at display resolution, dropping late frames,
   thermal-state adaptation, memory at 48 MP, battery. Compatibility across iPhone cameras and
   sensors: device test matrix and a per-device neutral baseline.
7. Competitive analysis. What makes each app visually distinctive; which effects are standard image
   processing vs need physical modeling or authored assets; recurring weaknesses in reviews and
   forums that RetroSnap can beat (e.g., overwritten metadata, unconvincing date stamps, resolution
   loss, preview not matching output); how to differentiate without copying assets or branding.
8. Calibration loop. Reference set, metrics, tolerances, golden images, regression tests in CI,
   side-by-side review tooling.

DELIVERABLES (in this order)
1. Executive summary (max 200 words) and a confidence table: verified / inferred / unknown.
2. Per-app findings with graded evidence and links.
3. Measurement protocol and analysis scripts.
4. Hero-camera specification tables.
5. Library comparison and recommendation.
6. Architecture (text diagram) with short Swift/Metal sketches of the shared pipeline, LUT, grain
   and halation stages.
7. Calibration plan with tolerances.
8. Prioritized roadmap with risks and effort, then a source list ranked by evidence quality and
   practical usefulness.
