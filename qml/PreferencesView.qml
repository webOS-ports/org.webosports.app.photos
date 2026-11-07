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
import QtQuick.Layouts
import QtQuick.Controls.LuneOS 2.0

import LunaNext.Common 0.1
import LuneOS.Forms 1.0

import "js/Library.js" as Library

/*
 * Preferences & Accounts: how much of the device the cloud photos take,
 * how much of it their whole pictures may, clearing them, and the way to
 * the accounts. What is shown is the photos service's getStorage.
 *
 * A light page, as the preferences of Music, Sound Recorder, Phone and the
 * Settings app are: LuneOS.Forms' header, groups of rows and the list
 * selector for a choice, over the settings pages' grey gradient.
 */
Item {
    id: prefs
    objectName: "preferencesView"
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

    function setCap(bytes) {
        store.setStorage(bytes, function(r) { if (prefs._usable(r)) prefs.info = r; });
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

    // Swallows the taps meant for what is under it
    MouseArea {
        anchors.fill: parent
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Colors.pageGradientTop }
            GradientStop { position: 1.0; color: Colors.pageGradientBottom }
        }
    }

    AppHeader {
        id: header
        objectName: "preferencesHeader"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: appWindow.headerHeight
        title: "Preferences & Accounts"
        icon: Qt.resolvedUrl("../icon.png")
        compact: width < Units.gu(50)
    }

    Flickable {
        id: flick
        objectName: "preferencesFlick"
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentHeight: content.implicitHeight + Units.gu(2)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: content

            // Capped and centred, as SettingsPageContent's column: a line length on a tablet
            width: Math.min(flick.width - Units.gu(2), Units.gu(56))
            x: (flick.width - width) / 2
            y: Units.gu(1)
            spacing: Units.gu(1)

            ServiceUnavailableNotice {
                objectName: "storageUnavailable"
                Layout.fillWidth: true
                visible: prefs.info === null
                serviceName: "com.palm.service.photos"
                description: "How much space the cloud photos take cannot be read now."
                onRetry: prefs.refresh()
            }

            FormGroup {
                Layout.fillWidth: true
                visible: prefs.info !== null
                title: "Downloaded Photos"

                LabelAndSelector {
                    objectName: "storageCapSelector"
                    label: "Keep up to"
                    model: prefs.info ? (prefs.info.capChoices || []).map(function(b) { return Library.formatBytes(b); }) : []
                    values: prefs.info ? (prefs.info.capChoices || []) : []
                    value: prefs.info ? prefs.info.capBytes : 0
                    onChosen: (v) => prefs.setCap(v)
                }
            }

            ExplanationText {
                Layout.fillWidth: true
                visible: prefs.info !== null
                text: prefs.info ? "Past that, or 5% of the free space, the pictures opened longest ago go back to the cloud. "
                                   + "Albums not opened for " + prefs.info.expireDays + " days go back too, and nothing is downloaded while less than "
                                   + Library.formatBytes(prefs.info.floorBytes) + " is free. Albums kept on the device stay." : ""
            }

            FormGroup {
                Layout.fillWidth: true
                visible: prefs.info !== null
                title: "On This Device"

                LabelAndValue {
                    objectName: "storagePictures"
                    label: "Whole pictures"
                    value: prefs.info ? Library.formatBytes(prefs.info.originals.bytes) + " of " + Library.formatBytes(prefs.info.capNowBytes) : ""
                }
                LabelAndValue {
                    objectName: "storageKept"
                    label: "Albums kept"
                    value: !prefs.info ? ""
                         : prefs.info.kept.albums > 0 ? prefs.info.kept.albums + (prefs.info.kept.albums === 1 ? " album, " : " albums, ") + Library.formatBytes(prefs.info.kept.bytes)
                         : "None"
                }
                LabelAndValue {
                    objectName: "storageOther"
                    label: "Previews and thumbnails"
                    value: prefs.info ? Library.formatBytes(prefs.info.otherBytes) : ""
                }
                LabelAndValue {
                    objectName: "storageFree"
                    label: "Free"
                    value: prefs.info ? Library.formatBytes(prefs.info.freeBytes) : ""
                }
            }

            Button {
                objectName: "clearDownloadsButton"
                Layout.fillWidth: true
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

            Item { Layout.preferredHeight: Units.gu(1) }

            Button {
                objectName: "accountsButton"
                Layout.fillWidth: true
                text: "Accounts"
                onClicked: appWindow.launchApp("com.palm.app.accounts", {})
            }

            ExplanationText {
                Layout.fillWidth: true
                text: "The online accounts whose photos are shown here, and adding one, are in the Accounts app."
            }
        }
    }
}
