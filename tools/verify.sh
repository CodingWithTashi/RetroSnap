#!/bin/zsh
# A batch's definition of done, serial on the booted simulator (`Retrosnap 16e`): the app built and installed, the
# reference inputs (the seven pictures of `tools/pairs.py`) shown on the live Result and Viewer screens for every
# fitted camera, every designed scenario screenshotted and diffed against the committed tree's screenshots (built in
# a worktree), the calibration tests (pairs, exports, bake versus screen), compare/grain/glow/face/whites/residual/
# screen_vs_bake/frames, the unit tests, the UI tests and the Release device build.
# usage: tools/verify.sh <outdir> [camera ids...]
set -u
OUT=${1:?outdir}; shift
CAMERAS=${@:-"negative plastic35 slide mediumFormat tlr film inst compactPro classicSLR instSquare"}
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"; mkdir -p "$OUT"
DEST='platform=iOS Simulator,name=Retrosnap 16e'
step() { echo; echo "=== $1 ($(date +%H:%M:%S))"; }
step "before: the committed tree"
rm -rf "$OUT/head-tree"; git worktree prune
git worktree add --detach "$OUT/head-tree" HEAD >/dev/null 2>&1 && {
  xcodebuild build -project "$OUT/head-tree/Retrosnap.xcodeproj" -scheme Retrosnap -destination "$DEST" -derivedDataPath "$OUT/dd-head" -quiet 2>&1 | grep -E "error|BUILD" | head -3
  xcrun simctl terminate booted com.retrosnap.vintagecamera 2>/dev/null
  xcrun simctl install booted "$OUT/dd-head/Build/Products/Debug-iphonesimulator/Retrosnap.app"
  zsh tools/shoot.sh "$OUT/before"
  git worktree remove --force "$OUT/head-tree"; git worktree prune
}
step "build"
xcodebuild build -project Retrosnap.xcodeproj -scheme Retrosnap -destination "$DEST" -quiet 2>&1 | grep -E "error|BUILD" | head -3
APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/Retrosnap-*/Build/Products/Debug-iphonesimulator/Retrosnap.app | head -1)
xcrun simctl terminate booted com.retrosnap.vintagecamera 2>/dev/null
xcrun simctl install booted "$APP"
xcrun simctl privacy booted grant photos com.retrosnap.vintagecamera 2>/dev/null
xcrun simctl status_bar booted override --time 9:41
CONTAINER=$(xcrun simctl get_app_container booted com.retrosnap.vintagecamera data)
step "live shots of the reference inputs"
mkdir -p "$OUT/live"
shoot() { local name=$1; shift; xcrun simctl launch --terminate-running-process booted com.retrosnap.vintagecamera "$@" >/dev/null 2>&1; sleep 4.5; xcrun simctl io booted screenshot "$OUT/live/$name.png" >/dev/null 2>&1; }
for cam in ${=CAMERAS}; do
  xcrun simctl terminate booted com.retrosnap.vintagecamera 2>/dev/null
  venv/bin/python -I tools/seed_simulator.py $cam "$CONTAINER" >/dev/null
  for pic in selfie dunes sign tungsten backlit market wall; do shoot result-$cam-$pic -rsLive 1 -rsScreen result -rsPhoto $pic; shoot viewer-$cam-$pic -rsLive 1 -rsScreen viewer -rsPhoto $pic; done
done
xcrun simctl terminate booted com.retrosnap.vintagecamera 2>/dev/null
xcrun simctl privacy booted reset photos com.retrosnap.vintagecamera 2>/dev/null
step "scenario shots and diffs (0 = untouched)"
zsh tools/shoot.sh "$OUT/after"
for f in "$OUT"/before/*.png; do n=$(basename $f); echo "$n: $(compare -metric AE $f "$OUT/after/$n" null: 2>&1)"; done
step "calibration tests"
xcodebuild test -project Retrosnap.xcodeproj -scheme Retrosnap -destination "$DEST" -only-testing:RetrosnapTests/ReferencePairTests -only-testing:RetrosnapTests/ReferenceExportTests -only-testing:RetrosnapTests/BakeVersusScreenTests -parallel-testing-enabled NO 2>&1 | grep -E "Test run|✘" | tail -4
step "compare, grain, glow, face, whites, residual"
pairs_of() { venv/bin/python -I -c "import sys; sys.path.insert(0, 'tools'); import pairs; print(' '.join(pairs.pairs('$1')))"; }
for cam in ${=CAMERAS}; do for p in $(pairs_of $cam); do [ -f ref/pairs/$p-input.png ] && venv/bin/python -I tools/compare.py ref/pairs/$p | grep -E "^[a-zA-Z]|RetroSnap vs"; done; done
for cam in ${=CAMERAS}; do for p in $(pairs_of $cam); do [ -f ref/pairs/$p-input.png ] && echo "$p: $(venv/bin/python -I tools/grain.py ref/pairs/$p 2>&1 | grep 'grain ratio' | sed 's/.*grey: //')"; done; done
venv/bin/python -I tools/glow_grain.py $(for cam in ${=CAMERAS}; do for p in $(pairs_of $cam); do [ -f ref/pairs/$p-input.png ] && echo ref/pairs/$p; done; done)
for cam in ${=CAMERAS}; do venv/bin/python -I tools/face.py $cam --render | grep face; done
venv/bin/python -I tools/whites.py ${=CAMERAS}
venv/bin/python -I tools/residual.py ${=CAMERAS} | grep -E "largest remaining"
step "screen vs bake"
for cam in ${=CAMERAS}; do venv/bin/python -I tools/screen_vs_bake.py $cam "$OUT/after/viewer-$cam.png"; done
step "frames"
venv/bin/python -I tools/frames.py "$OUT/frames" --sheet "$OUT/reference-vs-retrosnap.jpg"
step "unit tests"
xcodebuild test -project Retrosnap.xcodeproj -scheme Retrosnap -destination "$DEST" -only-testing:RetrosnapTests -parallel-testing-enabled NO > "$OUT/unit-tests.txt" 2>&1
grep -E "Test run with|✘" "$OUT/unit-tests.txt" | tail -6
step "ui tests"
xcodebuild test -project Retrosnap.xcodeproj -scheme Retrosnap -destination "$DEST" -only-testing:RetrosnapUITests -parallel-testing-enabled NO > "$OUT/ui-tests.txt" 2>&1
grep -E "Executed|passed|failed" "$OUT/ui-tests.txt" | tail -2
step "release device build"
xcodebuild build -project Retrosnap.xcodeproj -scheme Retrosnap -destination 'generic/platform=iOS' -configuration Release CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | head -3
echo; echo "VERIFY DONE ($(date +%H:%M:%S))"
