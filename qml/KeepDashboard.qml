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

import Eos.Window 0.1
import LunaNext.Common 0.1

/*
 * The dashboard while albums come down to be kept on the device, as webOS's
 * sync dashboard (enyo syncui) is up while an account syncs: the account's
 * icon, its name and "Syncing account...", the sync glyph in the row of
 * icons. Here the album's account icon, its title and "Downloading
 * album...". Laid out as systemui's dashboards (stylesheets/dashboard.css,
 * the USB one among them): a 50px row, the 48px icon in a 54px container on
 * the left, a bold 16px title over 14px text; the shell gives a dashboard
 * that 50px as 5.6 grid units, so the CSS pixels are scaled by height / 50.
 * A tap opens the album; swiped away, it stays away for this download.
 */
WebOSWindow {
    id: dashboard

    // The album shown, and how many are coming down
    property string title: ""
    property url icon
    property int count: 1
    // The glyph in the notification area's row of icons
    property string smallIcon: ""

    signal tapped()
    signal dismissed()

    property bool _shown: false

    windowType: "_WEBOS_WINDOW_TYPE_FLOATING"
    width: Settings.displayWidth
    height: Units.gu(5.6)
    color: "transparent"
    visible: false

    Component.onCompleted: {
        setWindowProperty("LuneOS_window", "dashboard");
        setWindowProperty("LuneOS_icon", smallIcon);
        visible = true;
        _shown = true;
    }

    // Swiped away, the shell closes the window
    onWindowCloseRequested: _dismiss()
    onVisibleChanged: if (!visible) _dismiss()

    function _dismiss() {
        if (!_shown)
            return;
        _shown = false;
        dashboard.dismissed();
    }

    // One CSS pixel of the dashboard CSS
    readonly property real _px: height / 50
    // The USB dashboard's background on sargo, measured: one box, square corners
    readonly property color _bg: "#1d1d1d"

    Rectangle {
        anchors.fill: parent
        color: dashboard._bg
    }

    MouseArea {
        anchors.fill: parent
        onClicked: dashboard.tapped()
    }

    Item {
        id: iconBox
        objectName: "keepDashboardIcon"
        width: 54 * dashboard._px
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        Image {
            anchors.centerIn: parent
            width: 44 * dashboard._px
            height: width
            source: dashboard.icon
            sourceSize.width: width
            sourceSize.height: height
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
        // More than one: how many, over the icon's corner, as webOS's dashboard-newitem badge
        Rectangle {
            objectName: "keepDashboardCount"
            visible: dashboard.count > 1
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 1 * dashboard._px
            height: 22 * dashboard._px
            width: Math.max(height, countLabel.implicitWidth + 10 * dashboard._px)
            radius: height / 2
            color: "#2a6dd8"
            Text {
                id: countLabel
                anchors.centerIn: parent
                text: dashboard.count
                color: "white"
                font.family: "Prelude"
                font.weight: Font.Bold
                font.pixelSize: 14 * dashboard._px
            }
        }
    }

    Column {
        anchors.left: iconBox.right
        anchors.leftMargin: 4 * dashboard._px
        anchors.right: parent.right
        anchors.rightMargin: 12 * dashboard._px
        anchors.verticalCenter: parent.verticalCenter

        Text {
            objectName: "keepDashboardTitle"
            width: parent.width
            text: dashboard.title
            color: "white"
            font.family: "Prelude"
            font.weight: Font.Bold
            font.pixelSize: 16 * dashboard._px
            textFormat: Text.PlainText
            elide: Text.ElideRight
        }
        Text {
            objectName: "keepDashboardText"
            width: parent.width
            text: "Downloading album..."
            color: "white"
            font.family: "Prelude"
            font.pixelSize: 14 * dashboard._px
            textFormat: Text.PlainText
            elide: Text.ElideRight
        }
    }
}
