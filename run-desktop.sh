#!/bin/sh
# Run the app on a development machine.
#
# The C++ plugins that need webOS system libraries (luna-service2 and friends)
# are not built here: luneos-components ships pure QML mocks for all of them
# under test/imports, and tests/mocks has this app's stand-in for the bus.
# tests/mainDesktop.qml starts the app with those and the test library from
# tests/data. Only LuneOS.Components and QtQuick.Controls.LuneOS have to be
# built.
#
# The screen is a device profile of luneos-components' Settings stub; the
# default is the TouchPad's:
#   ./run-desktop.sh --profile=q25
#   ./run-desktop.sh --profile=mindphone --ui-scale=1.25
#
# Use the qml runtime of the Qt luneos-components was built against (on
# Debian and Ubuntu: the qml-qt6 package); another Qt's cannot load its
# plugins. Settings are kept in build/desktop/, apart from your own. Override
# COMPONENTS or QMLBIN if your checkout or Qt lives elsewhere.
COMPONENTS=${COMPONENTS:-../luneos-components}
QMLBIN=${QMLBIN:-}
if [ -z "$QMLBIN" ]; then
    for candidate in /usr/lib/qt6/bin/qml \
            $(ls -d "$HOME"/Qt/6.*/gcc_64/bin/qml 2>/dev/null | sort -V | tail -1) \
            "$(command -v qml)"; do
        if [ -x "$candidate" ]; then
            QMLBIN=$candidate
            break
        fi
    done
fi

cd "$(dirname "$0")" || exit 1

if [ ! -x "$QMLBIN" ]; then
    echo "qml runtime not found; set QMLBIN to your Qt's bin/qml" >&2
    echo "(Debian/Ubuntu: the qml-qt6 package, the same Qt luneos-components was built with)" >&2
    exit 1
fi
if [ ! -d "$COMPONENTS/test/imports" ]; then
    echo "luneos-components not found at $COMPONENTS; set COMPONENTS to your checkout" >&2
    exit 1
fi

case " $* " in
    *" --profile"*) ;;
    *) set -- --profile=tp "$@" ;;
esac

mkdir -p build/desktop
XDG_CONFIG_HOME=$PWD/build/desktop/config XDG_CACHE_HOME=$PWD/build/desktop/cache \
QT_QUICK_CONTROLS_STYLE=QtQuick.Controls.LuneOS \
    "$QMLBIN" -I "$COMPONENTS/modules" -I "$COMPONENTS/test/imports" tests/mainDesktop.qml -- "$@"
