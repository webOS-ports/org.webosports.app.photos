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
import "js/Images.js" as Images

/*
 * A video in the full-screen view, played where it is (webOS's DbViewVideo):
 * its picture until it plays, then the video with a bar - play/pause, the
 * time played and left, a seek bar, and fit or fill - shown with the top
 * bar. Opened from the grid it starts by itself, where it was left last
 * (lastPlayTime, kept in its db8 entry). Swiped away, it stops and that
 * place is kept.
 */
Item {
    id: pane

    property var item: null
    property bool current: false
    property bool autoPlay: false
    property bool controlsShown: true
    property url engineSource
    readonly property var engine: engineLoader.item
    readonly property bool playing: engine !== null && engine.playing
    property bool fill: false
    signal tapped()
    signal lastPlayTime(real seconds)

    function play() {
        if (!engineLoader.active)
            engineLoader.active = true;
        else if (engine)
            engine.play();
    }

    function pause() {
        if (engine && engine.playing) {
            engine.pause();
            saveState();
        }
    }

    function saveState() {
        if (engine && engine.duration > 0)
            lastPlayTime(engine.ended ? 0 : engine.position / 1000);
    }

    onCurrentChanged: {
        if (current) {
            if (autoPlay)
                play();
        } else if (engineLoader.active) {
            saveState();
            engineLoader.active = false;
        }
    }
    Component.onCompleted: if (current && autoPlay) play()

    Thumbnail {
        anchors.fill: parent
        crop: false
        item: pane.item
        visible: !engineLoader.active
    }

    Loader {
        id: engineLoader
        objectName: "videoEngine"
        anchors.fill: parent
        active: false
        source: pane.engineSource
        onLoaded: {
            item.fill = Qt.binding(function() { return pane.fill; });
            item.source = Library.fileUrl(pane.item.path);
            var at = pane.item.lastPlayTime > 0 && !(pane.item.duration > 0 && pane.item.lastPlayTime >= pane.item.duration - 1)
                     ? pane.item.lastPlayTime * 1000 : 0;
            item.play();
            if (at > 0)
                item.seek(at);
        }
    }

    Connections {
        target: pane.engine
        function onEndedChanged() {
            if (pane.engine.ended)
                pane.lastPlayTime(0);
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: pane.tapped()
    }

    // The big play button over a video that is not playing.
    Image {
        objectName: "bigPlay"
        anchors.centerIn: parent
        width: Units.gu(8.8)
        height: width
        sourceSize: Qt.size(Math.ceil(width), Math.ceil(height))
        source: Images.url("playIcon", Units.gridUnit)
        visible: !pane.playing && (pane.engine === null || !pane.engine.errorText)
        opacity: 0.85
        MouseArea {
            anchors.fill: parent
            onClicked: pane.play()
        }
    }

    Label {
        objectName: "videoError"
        anchors.centerIn: parent
        width: parent.width - Units.gu(4)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        visible: pane.engine !== null && pane.engine.errorText !== ""
        text: pane.engine ? pane.engine.errorText : ""
        color: "white"
        font.pixelSize: FontUtils.sizeToPixels("large")
    }

    Rectangle {
        id: bar
        objectName: "videoBar"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Units.gu(8)
        color: "#c0000000"
        opacity: pane.controlsShown || !pane.playing ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        MouseArea { anchors.fill: parent }

        IconButton {
            id: playButton
            objectName: "playPauseButton"
            anchors.left: parent.left
            anchors.leftMargin: Units.gu(1)
            anchors.verticalCenter: parent.verticalCenter
            image: pane.playing ? "icn-pause" : "icn-play"
            onClicked: pane.playing ? pane.pause() : pane.play()
        }
        Label {
            id: played
            objectName: "timePlayed"
            anchors.left: playButton.right
            anchors.leftMargin: Units.gu(1)
            anchors.verticalCenter: parent.verticalCenter
            text: Library.formatDuration(pane.engine ? pane.engine.position / 1000 : 0)
            color: "white"
            font.pixelSize: FontUtils.sizeToPixels("small")
        }
        Slider {
            id: seekBar
            objectName: "seekBar"
            anchors.left: played.right
            anchors.right: left.left
            anchors.margins: Units.gu(1)
            anchors.verticalCenter: parent.verticalCenter
            from: 0
            to: pane.engine && pane.engine.duration > 0 ? pane.engine.duration : 1
            enabled: pane.engine !== null && pane.engine.seekable
            value: pressed ? value : (pane.engine ? pane.engine.position : 0)
            onMoved: if (pane.engine) pane.engine.seek(value)
        }
        Label {
            id: left
            objectName: "timeLeft"
            anchors.right: fitButton.left
            anchors.rightMargin: Units.gu(1)
            anchors.verticalCenter: parent.verticalCenter
            text: "-" + Library.formatDuration(pane.engine ? Math.max(0, pane.engine.duration - pane.engine.position) / 1000
                                                         : (pane.item ? pane.item.duration : 0))
            color: "white"
            font.pixelSize: FontUtils.sizeToPixels("small")
        }
        IconButton {
            id: fitButton
            objectName: "fitButton"
            anchors.right: parent.right
            anchors.rightMargin: Units.gu(1)
            anchors.verticalCenter: parent.verticalCenter
            image: pane.fill ? "icn-normalsize" : "icn-fillscreen"
            onClicked: pane.fill = !pane.fill
        }
    }
}
