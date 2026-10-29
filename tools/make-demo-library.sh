#!/bin/sh
# Makes the demo library the README's screenshots are taken of, in
# build/demo/pictures/: the LuneOS default wallpapers (real photographs; the
# luneos-default-wallpapers recipe in meta-luneos has them as Apache-2.0),
# made smaller, in four albums. tests/screens/DemoFixtures.js describes them
# to the app the way the media indexer would.
#
#   tools/make-demo-library.sh [folder with the wallpapers]
#
# With no folder they are cloned from GitHub at the revision the recipe
# builds. Needs ImageMagick. The pictures are not kept in the repository:
# only the screenshots are.
set -e
cd "$(dirname "$0")/.."
SRCREV=c063f57b20a2cfc11ad0e097547610f9bcf242fc
DEMO=build/demo
SRC=${1:-}

if [ -z "$SRC" ]; then
    SRC=$DEMO/wallpapers
    if [ "$(git -C "$SRC" rev-parse HEAD 2>/dev/null)" != "$SRCREV" ]; then
        rm -rf "$SRC"
        git clone -q https://github.com/webOS-ports/luneos-default-wallpapers "$SRC"
        git -C "$SRC" -c advice.detachedHead=false checkout -q "$SRCREV"
    fi
fi
MAGICK=$(command -v magick || command -v convert || true)
if [ -z "$MAGICK" ]; then
    echo "ImageMagick (magick or convert) is needed" >&2
    exit 1
fi

rm -rf "$DEMO/pictures" "$DEMO/thumbs"
mkdir -p "$DEMO/thumbs"

# The wallpapers are square, for a screen that turns; photographs are not.
# Each is cut to a camera's 3:2, landscape (name) or portrait (name:tall).
LANDSCAPE=1280x853
PORTRAIT=853x1280

# album folder, then its pictures
put() {
    dir=$DEMO/pictures/$1
    shift
    mkdir -p "$dir"
    for spec in "$@"; do
        name=${spec%%:*}
        size=$LANDSCAPE
        [ "$spec" = "$name:tall" ] && size=$PORTRAIT
        if [ ! -f "$SRC/$name.jpg" ]; then
            echo "$SRC/$name.jpg is missing" >&2
            exit 1
        fi
        "$MAGICK" "$SRC/$name.jpg" -auto-orient -resize '1280x1280^' -gravity center -crop "$size+0+0" +repage \
            -strip -quality 85 "$dir/$name.jpg"
    done
}

put DCIM moonrise orangesunset
put Nature plant:tall iceplant butterfly bubbles
put "Night Sky" milkyway iceveins:tall
put cloud wyoming snowtracks
# The camera's video, by its picture (the file itself is never played)
"$MAGICK" "$SRC/LuneOS.jpg" -resize '960x960^' -gravity center -crop 960x540+0+0 +repage -strip -quality 85 \
    "$DEMO/thumbs/video-poster.jpg"

echo "demo library in $DEMO/pictures"
