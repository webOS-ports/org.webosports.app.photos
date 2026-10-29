#!/bin/sh
# Draws the app icon from icon.svg with Qt's own SVG renderer (the one the
# device uses): icon.png and icon-256x256.png, both 256x256 as the other
# LuneOS apps' are. Run through qmltestrunner, which every Qt with QML
# testing has.
#
#   tools/make-icon.sh
set -e
cd "$(dirname "$0")/.."
OUT=$(pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cat > "$WORK/tst_icon.qml" <<QMLEOF
import QtQuick
import QtTest
TestCase {
    name: "Icon"
    when: windowShown
    Image {
        id: icon
        source: "file://$OUT/icon.svg"
        sourceSize: Qt.size(256, 256)
    }
    function test_draw() {
        tryCompare(icon, "status", Image.Ready);
        var done = false;
        icon.grabToImage(function(r) {
            verify(r.saveToFile("$OUT/icon.png"));
            verify(r.saveToFile("$OUT/icon-256x256.png"));
            done = true;
        });
        tryVerify(function() { return done; });
    }
}
QMLEOF
QT_QPA_PLATFORM=offscreen ${QMLTESTRUNNER:-/usr/lib/qt6/bin/qmltestrunner} -input "$WORK/tst_icon.qml" > "$WORK/log" 2>&1 \
    || { cat "$WORK/log"; exit 1; }
