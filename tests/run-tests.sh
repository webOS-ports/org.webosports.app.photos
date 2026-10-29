#!/bin/sh
# Run the app's QML tests on a development machine.
#
# Same idea as run-desktop.sh one level up: nothing here needs a device or the
# webOS system libraries. luneos-components ships QML mocks for its C++ plugins
# under test/imports, and mocks/ holds this app's own stand-ins: FakeBus for
# the bus (db8, com.palm.service.photos, the print and system services) and
# FakeEngine for the video engine.
#
#   tst_library  the logic in qml/js/Library.js
#   tst_store    PhotoStore against FakeBus
#   tst_ui       the whole app, once per screen in PROFILES - by default the
#                TouchPad, the mindphone and the Q25. Each state is also saved
#                as a screenshot in build/test-output/ui/<profile>-<state>.png.
#
# Each test file gets its own qmltestrunner, and tst_ui one per profile:
# SettingsStub reads its profile once, as it loads, and one process can only
# ever be one device. qmltestrunner refuses options it does not know, so the
# stub's --profile flag cannot be passed through; each profile runs instead
# against a copy of LunaNext.Common whose default profile is that screen.
# Settings go to a throwaway folder.
#
# Override COMPONENTS, QMLTESTRUNNER or PROFILES if your checkout, Qt or
# screens differ; further arguments go to every qmltestrunner, e.g.
#   PROFILES=q25 tests/run-tests.sh -functions
# TESTS names the files run once and UI_TESTS the ones run once per profile,
# so one of them can be run alone (CMakeLists.txt does that for CTest):
#   TESTS=tst_store.qml UI_TESTS= tests/run-tests.sh
#   TESTS= UI_TESTS=screens/tst_screens.qml PROFILES=tp tests/run-tests.sh
#
# A Qt 6 qmltestrunner is looked for before the one on PATH: on Debian and
# Ubuntu that one is often qtchooser's wrapper, which runs Qt 5's.
COMPONENTS=${COMPONENTS:-../../luneos-components}
PROFILES=${PROFILES:-tp mindphone q25}
TESTS=${TESTS-tst_library.qml tst_store.qml}
UI_TESTS=${UI_TESTS-tst_ui.qml}
if [ -z "${QMLTESTRUNNER:-}" ]; then
    for candidate in /usr/lib/qt6/bin/qmltestrunner \
            $(ls -d "$HOME"/Qt/6.*/gcc_64/bin/qmltestrunner 2>/dev/null | sort -V | tail -1) \
            "$(command -v qmltestrunner)"; do
        if [ -x "$candidate" ]; then
            QMLTESTRUNNER=$candidate
            break
        fi
    done
fi

cd "$(dirname "$0")" || exit 1

if [ ! -x "$QMLTESTRUNNER" ]; then
    echo "qmltestrunner not found; set QMLTESTRUNNER to your Qt's bin/qmltestrunner" >&2
    exit 1
fi
if [ ! -d "$COMPONENTS/test/imports" ]; then
    echo "luneos-components not found at $COMPONENTS; set COMPONENTS to your checkout" >&2
    exit 1
fi
COMPONENTS=$(cd "$COMPONENTS" && pwd)

CONF=$(mktemp -d)
trap 'rm -rf "$CONF"' EXIT
mkdir -p ../build/test-output/ui

run() {
    rm -rf "$CONF/config" "$CONF/cache"
    XDG_CONFIG_HOME=$CONF/config XDG_CACHE_HOME=$CONF/cache \
    QT_QPA_PLATFORM=${QT_QPA_PLATFORM:-offscreen} \
    QT_QUICK_CONTROLS_STYLE=QtQuick.Controls.LuneOS \
        "$QMLTESTRUNNER" \
        -import "$COMPONENTS/modules" \
        -import "$COMPONENTS/test/imports" "$@"
}

status=0
for t in $TESTS; do
    echo "--- $t"
    run -input "$t" "$@" || status=1
done
[ -n "$UI_TESTS" ] || exit $status
for profile in $PROFILES; do
    common=$CONF/profile-$profile/LunaNext/Common
    mkdir -p "$common"
    cp "$COMPONENTS"/test/imports/LunaNext/Common/* "$common/"
    sed -i "s/^var defaultProfile = .*/var defaultProfile = \"$profile\";/" "$common/SettingsStub.js"
    if ! grep -q "^var defaultProfile = \"$profile\";" "$common/SettingsStub.js"; then
        echo "could not select profile $profile in SettingsStub.js" >&2
        status=1
        continue
    fi
    for t in $UI_TESTS; do
        echo "--- $t ($profile)"
        run -import "$CONF/profile-$profile" -input "$t" "$@" || status=1
    done
done

exit $status
