#!/bin/zsh
# Screenshots of every designed scenario from the app installed on the booted simulator, for before/after diffs
# (`compare -metric AE before.png after.png null:`). usage: tools/shoot.sh <outdir>
out=$1; mkdir -p "$out"
xcrun simctl status_bar booted override --time 9:41
shoot() { # name, args...
  local name=$1; shift
  xcrun simctl launch --terminate-running-process booted com.retrosnap.vintagecamera "$@" >/dev/null 2>&1
  sleep 4.5
  xcrun simctl io booted screenshot "$out/$name.png" >/dev/null 2>&1
}
shoot welcome -rsScreen welcome
shoot how -rsScreen how
shoot camera -rsScreen camera
shoot carousel -rsScreen carousel
shoot gallery -rsScreen gallery
shoot gallery-empty -rsScreen gallery -rsVariant empty
shoot result-film -rsScreen result -rsCamera film
shoot viewer-disp -rsScreen viewer -rsCamera disp
shoot edit-inst -rsScreen edit -rsCamera inst
shoot print-digi -rsScreen print -rsCamera digi
shoot collage -rsScreen collage
shoot settings -rsScreen settings
shoot catalog -rsScreen catalog
for c in film disp inst digi vhs; do shoot look-$c -rsScreen look -rsCamera $c; done
for c in negative plastic35 slide mediumFormat tlr; do
  shoot look-$c -rsScreen look -rsCamera $c
  shoot result-$c -rsScreen result -rsCamera $c
  shoot viewer-$c -rsScreen viewer -rsCamera $c
done
ls "$out" | wc -l
