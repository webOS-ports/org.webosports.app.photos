#!/bin/bash
# Packs the app into an ipk and installs it through
# com.webos.appInstallService, as Preware does: opkg with its own root
# (/media/cryptofs/apps), so system packages are left alone, and the app's
# bus permissions come from requiredPermissions in appinfo.json. For
# development; a recipe does the real install.
#
#   tools/install.sh <adb serial>
#   tools/install.sh ssh:<host>[:<port>]     e.g. ssh:localhost:5522, a VM
#
# The app is QML only: the package is "Architecture: all" and the same on
# every device.
set -e
cd "$(dirname "$0")/.."
TARGET=${1:?usage: tools/install.sh <adb serial> | ssh:<host>[:<port>]}
BUILD=build

case $TARGET in
    ssh:*)
        HOSTPORT=${TARGET#ssh:}
        HOST=${HOSTPORT%%:*}
        PORT=22
        [ "$HOST" != "$HOSTPORT" ] && PORT=${HOSTPORT#*:}
        push() { scp -q -P "$PORT" "$1" "root@$HOST:$2"; }
        shell() { ssh -p "$PORT" "root@$HOST" "$1"; }
        ;;
    *)
        push() { adb -s "$TARGET" push "$1" "$2" >/dev/null; }
        shell() { adb -s "$TARGET" shell "$1"; }
        ;;
esac

ID=$(python3 -I -c 'import json; print(json.load(open("appinfo.json"))["id"])')
VERSION=$(python3 -I -c 'import json; print(json.load(open("appinfo.json"))["version"])')

WORK=$BUILD/ipk
rm -rf "$WORK"
APP=$WORK/data/usr/palm/applications/$ID
mkdir -p "$WORK/control" "$APP"
cp -r appinfo.json icon.png icon-256x256.png qml "$APP/"

cat > "$WORK/control/control" <<CONTROL
Package: $ID
Version: $VERSION
Section: misc
Priority: optional
Architecture: all
Installed-Size: $(du -sk "$WORK/data" | cut -f1)
Maintainer: Herman van Hazendonk <github.com@herrie.org>
Description: Photos & Videos
 Shows the pictures and videos on the device and in the cloud, by album,
 with slideshows and exhibition mode.
webOS-Package-Format-Version: 2
webOS-Packager-Version: x.y.x
CONTROL

echo "2.0" > "$WORK/debian-binary"
TAROPTS="--owner=0 --group=0 --numeric-owner --sort=name"
tar $TAROPTS -czf "$WORK/control.tar.gz" -C "$WORK/control" ./control
tar $TAROPTS -czf "$WORK/data.tar.gz" -C "$WORK/data" ./usr
IPK=${ID}_${VERSION}_all.ipk
rm -f "$BUILD/$IPK"
(cd "$WORK" && ar rc "../$IPK" debian-binary control.tar.gz data.tar.gz)

# The package goes to the device's /tmp, which opkg reads it from.
push "$BUILD/$IPK" /tmp/
# luna-send prints nothing on an adb pipe; results go through a file.
shell "luna-send -w 90000 -i luna://com.webos.appInstallService/install '{\"id\":\"$ID\",\"ipkUrl\":\"/tmp/$IPK\",\"subscribe\":true}' > /tmp/photos-inst.out 2>&1 & P=\$!; \
    for i in \$(seq 1 60); do sleep 1; grep -qE '\"installed\"|failed|errorCode' /tmp/photos-inst.out && break; done; kill \$P 2>/dev/null; \
    rm -f /tmp/$IPK; grep -oE '\"state\":\"installed\"|errorText\":\"[^\"]*\"' /tmp/photos-inst.out | tail -n 1"
