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
 * A picture or video full screen (webOS's PictureMode): swiped to the next
 * and previous of its album (newest first, no going round), a picture
 * pinched or double-tapped to zoom, a video played here with its own bar.
 * A tap shows or hides the top bar, which goes by itself after six
 * seconds: back to the album, Slideshow from here, Share (email),
 * Comments where the account has them, Print, Delete, and More - Add to
 * Album and Set As Wallpaper. A video has no Slideshow, Comments, Print or
 * wallpaper.
 */
Rectangle {
    id: view
    objectName: "pictureView"

    readonly property var store: appWindow.store
    property bool isOpen: false
    property string albumId: ""
    property string currentId: ""
    property bool autoPlay: false
    property var items: []
    readonly property var current: list.currentIndex >= 0 && list.currentIndex < items.length ? items[list.currentIndex] : null
    readonly property bool isVideo: current !== null && current.mediaType === "video"
    property bool controlsShown: true
    property bool commentsOpen: false
    // The video pane of the current item, when it is one.
    property var video: null
    readonly property bool playing: isOpen && video !== null && video.playing
    // What the tests replace: the video engine.
    property url engineSource: Qt.resolvedUrl("VideoEngine.qml")

    signal closed()

    color: "black"
    visible: isOpen

    function open(album, itemId, play) {
        albumId = album;
        items = store.itemsOf(album);
        currentId = itemId;
        autoPlay = play;
        commentsOpen = false;
        isOpen = true;
        _position();
        showControls();
        root.forceActiveFocus();
    }

    function close() {
        pause();
        if (video)
            video.saveState();
        isOpen = false;
        commentsOpen = false;
        items = [];
        closed();
    }

    function show(itemId) {
        currentId = itemId;
        _position();
    }

    function pause() {
        if (video)
            video.pause();
    }

    function handleBack() {
        if (!isOpen)
            return false;
        if (commentsOpen) {
            commentsOpen = false;
            return true;
        }
        close();
        return true;
    }

    // The album changed: the current one stays, or the next takes the place
    // of one deleted; nothing left closes the view.
    function libraryChanged() {
        if (!isOpen)
            return;
        var old = list.currentIndex;
        var fresh = store.itemsOf(albumId);
        var at = Library.indexAfterRemoval(fresh, currentId, old);
        if (at < 0) {
            close();
            return;
        }
        autoPlay = false;
        items = fresh;
        currentId = fresh[at]._id;
        _position();
    }

    function _position() {
        for (var i = 0; i < items.length; i++) {
            if (items[i]._id === currentId) {
                list.currentIndex = i;
                list.positionViewAtIndex(i, ListView.Beginning);
                return;
            }
        }
    }

    function showControls() {
        controlsShown = true;
        hideTimer.restart();
    }

    function toggleControls() {
        if (controlsShown) {
            controlsShown = false;
            hideTimer.stop();
        } else {
            showControls();
        }
    }

    // A short word over the picture ("Wallpaper set").
    function flash(text) {
        toast.show(text);
    }

    Timer {
        id: hideTimer
        interval: 6000
        onTriggered: if (!view.commentsOpen && !(view.isVideo && view.video && !view.video.playing)) view.controlsShown = false
    }

    ListView {
        id: list
        objectName: "pictureList"
        anchors.fill: parent
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: 0
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: width
        model: view.items
        interactive: !(currentItem && currentItem.zoomed)
        onCurrentIndexChanged: {
            if (currentIndex >= 0 && currentIndex < view.items.length && view.items[currentIndex]._id !== view.currentId) {
                view.currentId = view.items[currentIndex]._id;
                view.autoPlay = false;
            }
        }

        delegate: Item {
            id: page
            width: list.width
            height: list.height
            readonly property bool isCurrent: ListView.isCurrentItem
            readonly property bool zoomed: zoom.item ? zoom.item.zoomed === true : false

            Loader {
                id: zoom
                anchors.fill: parent
                active: modelData.mediaType !== "video"
                sourceComponent: LC.ZoomableImage {
                    source: Library.fileUrl(Library.viewPath(modelData))
                    onTapped: view.toggleControls()
                }
            }
            Loader {
                anchors.fill: parent
                active: modelData.mediaType === "video"
                sourceComponent: VideoPane {
                    id: pane
                    item: modelData
                    current: page.isCurrent && view.isOpen
                    autoPlay: view.autoPlay
                    controlsShown: view.controlsShown
                    engineSource: view.engineSource
                    onTapped: view.toggleControls()
                    onCurrentChanged: if (current) view.video = pane; else if (view.video === pane) view.video = null
                    Component.onCompleted: if (current) view.video = pane
                    Component.onDestruction: if (view.video === pane) view.video = null
                    onLastPlayTime: function(seconds) { view.store.setLastPlayTime(modelData._id, seconds); }
                }
            }
            // Zoomed in, a picture that is swiped away comes back fitted.
            onIsCurrentChanged: if (!isCurrent && zoom.item) zoom.item.reset()
        }
    }

    // The top bar.
    Rectangle {
        id: topBar
        objectName: "pictureControls"
        anchors.left: parent.left
        anchors.right: parent.right
        height: appWindow.headerHeight
        color: "#c0000000"
        opacity: view.controlsShown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        MouseArea {
            anchors.fill: parent
            onClicked: view.showControls()
        }
        IconButton {
            id: backButton
            objectName: "pictureBackButton"
            anchors.left: parent.left
            anchors.leftMargin: Units.gu(0.5)
            anchors.verticalCenter: parent.verticalCenter
            image: "dark-back-arrow"
            // the legacy back arrow is 16 px
            iconSize: Units.gu(1.6)
            onClicked: view.close()
        }
        Label {
            anchors.left: backButton.right
            anchors.right: buttons.left
            anchors.margins: Units.gu(0.5)
            anchors.verticalCenter: parent.verticalCenter
            text: {
                view.store.revision;
                var a = view.store.album(view.albumId);
                return a ? a.title : appWindow.sourceTitle;
            }
            color: "white"
            elide: Text.ElideRight
            font.pixelSize: FontUtils.sizeToPixels("medium")
        }
        Row {
            id: buttons
            anchors.right: parent.right
            anchors.rightMargin: Units.gu(0.5)
            anchors.verticalCenter: parent.verticalCenter
            readonly property real buttonWidth: Math.min(Units.gu(6), (view.width - Units.gu(14)) / 6)

            IconButton {
                objectName: "pictureSlideshowButton"
                width: buttons.buttonWidth
                image: "icn-playslideshow"
                visible: !view.isVideo
                onClicked: {
                    var list = Library.slideshowPlaylist(view.store.lib, [view.albumId]);
                    appWindow.slideshow.start(list, view.currentId, false);
                }
            }
            IconButton {
                objectName: "shareButton"
                width: buttons.buttonWidth
                image: "icn-share-contact"
                visible: view.current !== null && !!view.current.path
                onClicked: appWindow.share(view.current)
            }
            IconButton {
                objectName: "commentsButton"
                width: buttons.buttonWidth
                image: "icn-comments"
                visible: !view.isVideo && view.store.can(view.current, "getComments")
                onClicked: view.commentsOpen = !view.commentsOpen
            }
            IconButton {
                objectName: "printButton"
                width: buttons.buttonWidth
                image: "icn-print"
                visible: !view.isVideo && view.current !== null && !!view.current.path
                onClicked: appWindow.printer.printItem(view.current, appWindow.sheet)
            }
            IconButton {
                objectName: "deleteButton"
                width: buttons.buttonWidth
                image: "icn-delete"
                visible: view.store.can(view.current, "deletePhoto")
                onClicked: appWindow.askDelete([view.current], view.store.album(view.albumId), null, null)
            }
            IconButton {
                objectName: "moreButton"
                width: buttons.buttonWidth
                image: "icn-more"
                onClicked: {
                    var item = view.current;
                    var choices = [{ label: "Add to Album", enabled: view.store.serviceAvailable,
                                     action: function() { appWindow.chooseAlbum([item], view.albumId); } }];
                    if (!view.isVideo)
                        choices.push({ label: "Set As Wallpaper", action: function() { appWindow.setWallpaper(item); } });
                    appWindow.sheet.show(Library.basename(item.path), choices);
                }
            }
        }
    }

    // Comments, where the account has them (webOS's PictureComments).
    Rectangle {
        id: comments
        objectName: "commentsPanel"
        anchors.right: parent.right
        anchors.top: topBar.bottom
        anchors.margins: Units.gu(1)
        width: Math.min(parent.width - Units.gu(2), Units.gu(40))
        height: Math.min(parent.height * 0.6, Units.gu(50))
        radius: Units.gu(1)
        color: "#e8222222"
        visible: view.commentsOpen
        property var entries: []

        onVisibleChanged: if (visible) load()
        function load() {
            entries = [];
            var item = view.current;
            view.store.getComments(item, function(list) { comments.entries = list || []; });
        }

        ListView {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: commentField.top
            anchors.margins: Units.gu(1)
            clip: true
            model: comments.entries
            delegate: Column {
                width: ListView.view.width
                bottomPadding: Units.gu(1)
                Label {
                    width: parent.width
                    text: (modelData.user || "") + " · " + Library.relativeTime(modelData.time, Date.now() / 1000)
                    color: "#9a9a9a"
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }
                Label {
                    width: parent.width
                    text: modelData.text || ""
                    color: "white"
                    wrapMode: Text.Wrap
                }
            }
        }
        TextField {
            id: commentField
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Units.gu(1)
            placeholderText: "Tap here to add comment"
            onAccepted: {
                var t = text.trim();
                if (t === "")
                    return;
                text = "";
                view.store.addComment(view.current, t, function() { comments.load(); });
            }
        }
    }

    LC.Toast {
        id: toast
    }
}
