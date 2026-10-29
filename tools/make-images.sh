#!/bin/sh
# Draws the app's pictures, qml/images/<scale>x/<name>.png, from the SVGs in
# artwork/ at their own size (or the one artwork/sizes gives) with Qt's own
# SVG renderer, which draws their filters too. The app shows the PNGs
# (qml/js/Images.js picks the scale); the SVGs are kept here to change and
# draw again. Run through qmltestrunner, as tools/make-icon.sh is.
#
#   tools/make-images.sh
set -e
cd "$(dirname "$0")/.."
ROOT=$(pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Each SVG's size: its line in sizes, else its own width and height
LIST=$(grep -v '^#' artwork/sizes | grep -v '^ *$' || true)
for n in $(echo "$LIST" | cut -d' ' -f1); do
    [ -f "artwork/$n.svg" ] || { echo "artwork/sizes: no artwork/$n.svg" >&2; exit 1; }
done
ENTRIES=$(for f in artwork/*.svg; do
    n=$(basename "$f" .svg)
    s=$(echo "$LIST" | grep "^$n " | cut -d' ' -f2)
    if [ -n "$s" ]; then
        w=${s%x*}; h=${s#*x}
    else
        tag=$(tr '\n' ' ' < "$f" | grep -o '<svg[^>]*>')
        w=$(echo "$tag" | grep -o ' width="[0-9]*"' | grep -o '[0-9]*')
        h=$(echo "$tag" | grep -o ' height="[0-9]*"' | grep -o '[0-9]*')
        [ -n "$w" ] && [ -n "$h" ] || { echo "$f: no whole-pixel width and height, and not in artwork/sizes" >&2; exit 1; }
    fi
    echo "[\"$n\", $w, $h],"
done)

rm -rf qml/images/1x qml/images/2x qml/images/3x
mkdir -p qml/images/1x qml/images/2x qml/images/3x
cat > "$WORK/tst_images.qml" <<QMLEOF
import QtQuick
import QtTest
TestCase {
    name: "Images"
    when: windowShown
    property var entries: [ $ENTRIES ]
    Image {
        id: picture
        width: sourceSize.width
        height: sourceSize.height
        smooth: false
    }
    function test_draw() {
        for (var i = 0; i < entries.length; ++i) {
            for (var scale = 1; scale <= 3; ++scale) {
                var e = entries[i];
                picture.source = "";
                picture.sourceSize = Qt.size(e[1] * scale, e[2] * scale);
                picture.source = "file://$ROOT/artwork/" + e[0] + ".svg";
                tryCompare(picture, "status", Image.Ready);
                var done = false;
                var out = "$ROOT/qml/images/" + scale + "x/" + e[0] + ".png";
                picture.grabToImage(function(r) {
                    verify(r.saveToFile(out), out);
                    done = true;
                });
                tryVerify(function() { return done; });
            }
        }
    }
}
QMLEOF
QT_QPA_PLATFORM=offscreen ${QMLTESTRUNNER:-/usr/lib/qt6/bin/qmltestrunner} -input "$WORK/tst_images.qml" > "$WORK/log" 2>&1 \
    || { cat "$WORK/log"; exit 1; }
echo "$(ls qml/images/1x | wc -l) pictures, at 1x, 2x and 3x, in qml/images/"
