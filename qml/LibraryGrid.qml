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
 * A library's albums as a grid (webOS's LibraryMode): all of them, or the
 * device's, or one account's; sub-albums are in their albums. Slideshow
 * plays every album with pictures, sub-albums too.
 */
Rectangle {
    id: page
    objectName: "libraryGrid"

    readonly property var store: appWindow.store
    // Those in no other album: a sub-album is in its album
    readonly property var albums: { store.revision; return appWindow.libraryTopAlbums(); }

    color: "#1a1a1a"

    Rectangle {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        height: appWindow.headerHeight
        color: "#2a2a2a"
        z: 2

        Image {
            id: sourceIcon
            anchors.left: parent.left
            anchors.leftMargin: Units.gu(2)
            anchors.verticalCenter: parent.verticalCenter
            width: Units.gu(3.5)
            height: width
            fillMode: Image.PreserveAspectFit
            sourceSize: Qt.size(Math.ceil(width), Math.ceil(height))
            source: appWindow.sourceIcon
        }
        Label {
            objectName: "libraryTitle"
            anchors.left: sourceIcon.right
            anchors.leftMargin: Units.gu(1.5)
            anchors.right: parent.right
            anchors.rightMargin: appWindow.compact ? toolbar.width : Units.gu(2)
            anchors.verticalCenter: parent.verticalCenter
            text: appWindow.sourceTitle
            color: "white"
            elide: Text.ElideRight
            font.pixelSize: FontUtils.sizeToPixels("large")
        }
    }

    GridView {
        id: grid
        objectName: "albumGrid"
        anchors.top: header.bottom
        anchors.bottom: appWindow.compact ? parent.bottom : toolbar.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Units.gu(1)
        clip: true
        model: page.albums
        readonly property real maxCell: height > 0 ? (height / 2 - Units.gu(5)) / 0.75 : width
        readonly property int columns: Math.max(2, Math.floor(width / Units.gu(19)),
                                                Math.ceil(width / Math.max(Units.gu(8), maxCell)))
        cellWidth: Math.floor(width / columns)
        cellHeight: cellWidth * 0.75 + Units.gu(5)
        boundsBehavior: Flickable.StopAtBounds

        delegate: AlbumCell {
            width: grid.cellWidth
            height: grid.cellHeight
            album: modelData
        }
    }

    Label {
        anchors.centerIn: grid
        width: grid.width - Units.gu(4)
        visible: page.albums.length === 0 && page.store.status === "ready"
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        color: "#9a9a9a"
        text: appWindow.source !== "all" && appWindow.source !== "local" ? "No albums in this account yet." : "No photos or videos yet."
    }

    // The bottom bar; on a short landscape window (appWindow.compact) its keys
    // sit at the right end of the header instead, and the page runs to the bottom.
    Rectangle {
        id: toolbar
        anchors.left: appWindow.compact ? undefined : parent.left
        anchors.right: parent.right
        anchors.top: appWindow.compact ? parent.top : undefined
        anchors.bottom: appWindow.compact ? undefined : parent.bottom
        width: librarySlideshow.width + Units.gu(2)
        height: appWindow.compact ? appWindow.headerHeight : Units.gu(7)
        color: appWindow.compact ? "transparent" : "#2a2a2a"
        z: 3

        IconButton {
            id: librarySlideshow
            objectName: "librarySlideshowButton"
            anchors.centerIn: parent
            image: "icn-playslideshow"
            onClicked: appWindow.startSlideshow(Library.slideshowAlbums(appWindow.libraryAlbums(), []))
        }
    }
}
