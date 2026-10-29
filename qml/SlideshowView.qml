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

import LuneOS.Components 1.0 as LC
import "components"
import "js/Library.js" as Library

/*
 * A slideshow (webOS's SlideshowMode): the pictures one after the other,
 * full screen, each sliding in from the right over the last as it fades,
 * going round at the end; swiped to the next or previous by hand.
 *
 * In the app a tap ends it, on the picture showing. In exhibition (the
 * dock) a tap shows the bars for five seconds instead: Select Album (the
 * albums it plays, remembered), Shuffle, Play/Pause and how long each
 * picture stays.
 */
Rectangle {
    id: show
    objectName: "slideshowView"

    property var store: appWindow.store
    property var prefs: appWindow.prefs
    property bool exhibition: false
    property bool isOpen: exhibition
    property var playlist: []
    property int index: 0
    property bool paused: false
    property bool shuffle: false
    readonly property bool running: isOpen && !paused && playlist.length > 1
    readonly property var currentItem: playlist.length > 0 ? playlist[Library.wrap(index, playlist.length)] : null
    property bool controlsShown: false
    // The random source for shuffling (the tests give their own).
    property var random: Math.random

    signal closed(string lastItemId)

    color: "black"
    visible: isOpen

    function start(list, startId, inExhibition) {
        playlist = list;
        index = 0;
        for (var i = 0; i < list.length; i++)
            if (list[i]._id === startId)
                index = i;
        paused = false;
        controlsShown = false;
        isOpen = true;
        front.source = _url(currentItem);
        back.source = "";
        timer.restart();
    }

    function stop() {
        if (!isOpen || exhibition)
            return;
        var last = currentItem ? currentItem._id : "";
        isOpen = false;
        timer.stop();
        playlist = [];
        closed(last);
    }

    function pause() {
        paused = true;
        timer.stop();
    }

    function resume() {
        if (!isOpen)
            return;
        paused = false;
        timer.restart();
    }

    function _url(item) {
        return item ? Library.fileUrl(Library.viewPath(item)) : "";
    }

    // To the next (1) or previous (-1) picture, sliding in from that side.
    function go(step) {
        if (playlist.length === 0)
            return;
        index = Library.wrap(index + step, playlist.length);
        back.source = front.source;
        back.opacity = 1;
        back.x = 0;
        front.source = _url(currentItem);
        front.x = step > 0 ? show.width : -show.width;
        slide.restart();
        if (running)
            timer.restart();
    }

    function setShuffle(on) {
        shuffle = on;
        if (exhibition && prefs)
            prefs.exhibitionShuffle = on;
        var current = currentItem;
        playlist = on ? Library.shuffled(playlist, random) : _ordered();
        index = 0;
        for (var i = 0; i < playlist.length; i++)
            if (current && playlist[i]._id === current._id)
                index = i;
    }

    // Exhibition's playlist, from the albums chosen (all with pictures if none).
    function _ordered() {
        if (!exhibition)
            return playlist.slice().sort(Library.compareItems).reverse();
        return Library.slideshowPlaylist(store.lib, Library.slideshowAlbums(store.lib.albums, prefs.exhibitionAlbums));
    }

    function reloadExhibition() {
        var list = _ordered();
        if (shuffle)
            list = Library.shuffled(list, random);
        var keep = currentItem ? currentItem._id : "";
        start(list, keep, true);
    }

    Connections {
        target: show.exhibition ? show.store : null
        function onRevisionChanged() {
            if (show.playlist.length === 0)
                show.reloadExhibition();
        }
    }

    Component.onCompleted: {
        if (exhibition) {
            shuffle = prefs.exhibitionShuffle;
            reloadExhibition();
        }
    }

    Timer {
        id: timer
        interval: show.prefs ? show.prefs.slideshowInterval : 10000
        repeat: true
        running: false
        onTriggered: show.go(1)
    }

    Image {
        id: back
        objectName: "slideBack"
        width: show.width
        height: show.height
        asynchronous: true
        autoTransform: true
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(show.width, show.height)
    }
    Image {
        id: front
        objectName: "slideFront"
        width: show.width
        height: show.height
        asynchronous: true
        autoTransform: true
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(show.width, show.height)
    }
    ParallelAnimation {
        id: slide
        NumberAnimation { target: front; property: "x"; to: 0; duration: 600; easing.type: Easing.OutCubic }
        NumberAnimation { target: back; property: "opacity"; to: 0; duration: 600 }
    }

    Label {
        objectName: "slideshowEmpty"
        anchors.centerIn: parent
        width: parent.width - Units.gu(4)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        visible: show.isOpen && show.playlist.length === 0
        text: "Please download more photos to play slideshow."
        color: "white"
        font.pixelSize: FontUtils.sizeToPixels("large")
    }

    // A swipe goes back or on; a tap ends it (in the app) or shows the bars.
    MouseArea {
        anchors.fill: parent
        property real startX: 0
        onPressed: function(mouse) { startX = mouse.x; }
        onReleased: function(mouse) {
            var dx = mouse.x - startX;
            if (Math.abs(dx) > show.width * 0.12) {
                show.go(dx < 0 ? 1 : -1);
            } else if (show.exhibition) {
                show.controlsShown = !show.controlsShown;
                if (show.controlsShown)
                    barsTimer.restart();
            } else {
                show.stop();
            }
        }
    }

    Timer {
        id: barsTimer
        interval: 5000
        onTriggered: show.controlsShown = false
    }

    // Exhibition's bars.
    Rectangle {
        objectName: "slideshowTopBar"
        anchors.left: parent.left
        anchors.right: parent.right
        height: Units.gu(7)
        color: "#c0000000"
        visible: show.exhibition && show.controlsShown

        Label {
            anchors.left: parent.left
            anchors.leftMargin: Units.gu(2)
            anchors.verticalCenter: parent.verticalCenter
            text: "Slideshow"
            color: "white"
            font.pixelSize: FontUtils.sizeToPixels("large")
        }
        Button {
            objectName: "selectAlbumButton"
            anchors.right: parent.right
            anchors.rightMargin: Units.gu(1)
            anchors.verticalCenter: parent.verticalCenter
            text: "Select Album"
            visible: show.store.lib.albums.filter(function(a) { return a.images > 0; }).length > 1
            onClicked: { barsTimer.restart(); show.chooseAlbums(); }
        }
    }
    Rectangle {
        objectName: "slideshowCommandBar"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Units.gu(8)
        color: "#c0000000"
        visible: show.exhibition && show.controlsShown

        Row {
            anchors.centerIn: parent
            spacing: Units.gu(5)
            IconButton {
                objectName: "shuffleButton"
                image: "icn-shuffle"
                checked: show.shuffle
                onClicked: { barsTimer.restart(); show.setShuffle(!show.shuffle); }
            }
            IconButton {
                objectName: "slideshowPlayButton"
                image: show.paused ? "icn-play" : "icn-pause"
                onClicked: { barsTimer.restart(); show.paused ? show.resume() : show.pause(); }
            }
            IconButton {
                objectName: "timerButton"
                image: "icn-time"
                onClicked: {
                    barsTimer.restart();
                    sheet.show("Show Each Photo For", Library.slideshowIntervals.map(function(c) {
                        return { label: c.label, key: c.ms, checked: c.ms === show.prefs.slideshowInterval,
                                 action: function() { show.prefs.slideshowInterval = c.ms; if (show.running) timer.restart(); } };
                    }));
                }
            }
        }
    }

    // The albums exhibition plays, ticked one at a time; none is all.
    function chooseAlbums() {
        var chosen = (prefs.exhibitionAlbums || []).slice();
        var albums = store.lib.albums.filter(function(a) { return a.images > 0; });
        var choices = albums.map(function(a) {
            return { label: a.title, key: a._id, checked: chosen.indexOf(a._id) >= 0,
                     action: function() {
                         var at = chosen.indexOf(a._id);
                         if (at >= 0)
                             chosen.splice(at, 1);
                         else
                             chosen.push(a._id);
                         show.prefs.exhibitionAlbums = chosen;
                         show.chooseAlbums();
                     } };
        });
        choices.push({ label: "Done", action: function() { show.reloadExhibition(); } });
        sheet.show("Select Album", choices);
    }

    LC.ActionSheet {
        id: sheet
        objectName: "slideshowSheet"
        anchors.fill: parent
    }
}
