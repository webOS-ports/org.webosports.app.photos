#!/bin/sh
# The README's screenshots, on the build host: the demo library of
# make-demo-library.sh, the app on each device's screen through
# tests/screens/tst_screens.qml, into docs/screenshots/<device>-<screen>.jpg.
# They are mostly photographs, which as PNGs would be several times larger.
#
#   tools/screenshots-host.sh [folder with the wallpapers]
#
# The devices are those of PROFILES (default: the TouchPad, the mindphone and
# the Q25); COMPONENTS and QMLTESTRUNNER as for tests/run-tests.sh.
set -e
cd "$(dirname "$0")/.."
tools/make-demo-library.sh "$@"
rm -rf build/screenshots
mkdir -p build/screenshots docs/screenshots
TESTS= UI_TESTS=screens/tst_screens.qml tests/run-tests.sh
MAGICK=$(command -v magick || command -v convert)
for png in build/screenshots/*.png; do
    "$MAGICK" "$png" -strip -quality 88 -sampling-factor 4:4:4 "docs/screenshots/$(basename "$png" .png).jpg"
done
ls docs/screenshots
