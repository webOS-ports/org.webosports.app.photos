/*
 * Copyright (C) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 3, as published
 * by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.LuneOS 2.0

import LunaNext.Common 0.1

import "components"
import "js/Library.js" as Library

/*
 * Preferences & Accounts: how much of the device the cloud photos take,
 * how much of it their whole pictures may, clearing them, and the way to
 * the accounts. What is shown is the photos service's getStorage.
 */
Rectangle {
    id: prefs
    objectName: "preferencesView"
    color: "#1c1c1c"
    visible: isOpen

    property bool isOpen: false
    property var info: null
    // While clearDownloads runs: it removes every opened album's photos, which takes a while
    property bool clearing: false
    readonly property var store: appWindow.store

    function open() {
        isOpen = true;
        refresh();
    }

    function close() {
        isOpen = false;
    }

    function refresh() {
        store.getStorage(function(r) { prefs.info = prefs._usable(r); });
    }

    // An answer that does not say what the page shows is taken as no answer
    function _usable(r) {
        return r && r.originals && r.kept ? r : null;
    }

    function chooseCap() {
        if (!info)
            return;
        var choices = (info.capChoices || []).map(function(b) {
            return { label: Library.formatBytes(b), key: b, checked: b === info.capBytes,
                     action: function() { store.setStorage(b, function(r) { if (prefs._usable(r)) prefs.info = r; }); } };
        });
        appWindow.sheet.show("Keep Downloaded Photos Up To", choices);
    }

    function askClear() {
        appWindow.confirm.ask({ title: "Clear Downloaded Photos",
                            message: "Albums you have opened go back to the cloud; albums kept on the device stay.",
                            acceptText: "Clear", destructive: true,
                            onAccepted: function() {
                                prefs.clearing = true;
                                store.clearDownloads(function(r) {
                                    prefs.clearing = false;
                                    if (prefs._usable(r))
                                        prefs.info = r;
                                });
                            } });
    }

    // Back closes it
    function handleBack() {
        if (!isOpen)
            return false;
        close();
        return true;
    }

    Rectangle {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        height: appWindow.headerHeight
        color: "#2a2a2a"

        IconButton {
            id: backButton
            objectName: "preferencesBackButton"
            anchors.left: parent.left
            anchors.leftMargin: Units.gu(0.5)
            anchors.verticalCenter: parent.verticalCenter
            image: "dark-back-arrow"
            iconSize: Units.gu(1.6)
            onClicked: prefs.close()
        }
        Label {
            anchors.left: backButton.right
            anchors.leftMargin: Units.gu(1.5)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Preferences & Accounts"
            color: "white"
            elide: Text.ElideRight
            font.pixelSize: FontUtils.sizeToPixels("large")
        }
    }

    Flickable {
        id: flick
        objectName: "preferencesFlick"
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentHeight: column.height + Units.gu(4)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            x: Units.gu(2)
            y: Units.gu(2)
            width: parent.width - Units.gu(4)
            spacing: Units.gu(1.5)

            Label {
                text: "DOWNLOADED PHOTOS"
                color: "#9a9a9a"
                font.pixelSize: FontUtils.sizeToPixels("small")
                font.bold: true
            }
            Label {
                objectName: "storageUnavailable"
                width: parent.width
                visible: prefs.info === null
                wrapMode: Text.WordWrap
                text: "How much space the cloud photos take cannot be read now."
                color: "#c0c0c0"
            }
            Repeater {
                model: prefs.info ? [
                    { name: "storagePictures", label: "Whole pictures",
                      value: Library.formatBytes(prefs.info.originals.bytes) + " of " + Library.formatBytes(prefs.info.capNowBytes) },
                    { name: "storageKept", label: "Albums kept on the device",
                      value: prefs.info.kept.albums > 0 ? prefs.info.kept.albums + (prefs.info.kept.albums === 1 ? " album, " : " albums, ") + Library.formatBytes(prefs.info.kept.bytes) : "None" },
                    { name: "storageOther", label: "Previews and thumbnails", value: Library.formatBytes(prefs.info.otherBytes) },
                    { name: "storageFree", label: "Free on the device", value: Library.formatBytes(prefs.info.freeBytes) }
                ] : []
                delegate: Item {
                    required property var modelData
                    width: column.width
                    height: Units.gu(4)
                    Label {
                        anchors.left: parent.left
                        anchors.right: value.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: "white"
                        elide: Text.ElideRight
                    }
                    Label {
                        id: value
                        objectName: modelData.name
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.value
                        color: "#c0c0c0"
                    }
                }
            }
            Button {
                objectName: "storageCapButton"
                width: parent.width
                visible: prefs.info !== null
                text: prefs.info ? "Keep up to " + Library.formatBytes(prefs.info.capBytes) : ""
                onClicked: prefs.chooseCap()
            }
            Label {
                width: parent.width
                visible: prefs.info !== null
                wrapMode: Text.WordWrap
                color: "#9a9a9a"
                font.pixelSize: FontUtils.sizeToPixels("small")
                text: prefs.info ? "Past that, or 5% of the free space, the pictures opened longest ago go back to the cloud. "
                                   + "Albums not opened for " + prefs.info.expireDays + " days go back too, and nothing is downloaded while less than "
                                   + Library.formatBytes(prefs.info.floorBytes) + " is free. Albums kept on the device stay." : ""
            }
            Button {
                objectName: "clearDownloadsButton"
                width: parent.width
                visible: prefs.info !== null
                text: prefs.clearing ? "Clearing..." : "Clear Downloaded Photos"
                enabled: !prefs.clearing
                LuneOSButton.mainColor: LuneOSButton.negativeColor
                onClicked: prefs.askClear()

                BusyIndicator {
                    objectName: "clearingBusy"
                    anchors.right: parent.right
                    anchors.rightMargin: Units.gu(1)
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height * 0.7
                    width: height
                    visible: prefs.clearing
                    running: visible
                }
            }

            Item { width: 1; height: Units.gu(1) }
            Label {
                text: "ACCOUNTS"
                color: "#9a9a9a"
                font.pixelSize: FontUtils.sizeToPixels("small")
                font.bold: true
            }
            Button {
                objectName: "accountsButton"
                width: parent.width
                text: "Accounts"
                onClicked: appWindow.launchApp("com.palm.app.accounts", {})
            }
        }
    }
}
