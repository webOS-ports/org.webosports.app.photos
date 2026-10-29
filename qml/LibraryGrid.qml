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
 * device's, or one account's. Slideshow plays every album with pictures.
 */
Rectangle {
    id: page
    objectName: "libraryGrid"

    readonly property var store: appWindow.store
    readonly property var albums: { store.revision; return appWindow.libraryAlbums(); }

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
            anchors.rightMargin: Units.gu(2)
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
        anchors.bottom: toolbar.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Units.gu(1)
        clip: true
        model: page.albums
        readonly property int columns: Math.max(2, Math.floor(width / Units.gu(19)))
        cellWidth: Math.floor(width / columns)
        cellHeight: cellWidth * 0.75 + Units.gu(5)
        boundsBehavior: Flickable.StopAtBounds

        delegate: ItemDelegate {
            objectName: "albumCell-" + modelData._id
            width: grid.cellWidth
            height: grid.cellHeight
            padding: Units.gu(0.8)
            background: Rectangle {
                radius: Units.gu(0.6)
                color: parent.pressed ? "#333333" : "transparent"
            }
            onClicked: appWindow.openAlbum(modelData._id)
            contentItem: Column {
                spacing: Units.gu(0.5)
                Item {
                    width: parent.width
                    height: (grid.cellWidth - Units.gu(1.6)) * 0.75
                    // A stack of prints, as webOS drew an album.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Units.gu(0.4)
                        rotation: -4
                        color: "#d8d8d8"
                        antialiasing: true
                        visible: modelData.images + modelData.videos > 1
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Units.gu(0.4)
                        color: "#f2f2f2"
                        antialiasing: true
                        Thumbnail {
                            anchors.fill: parent
                            anchors.margins: Units.gu(0.4)
                            item: modelData.cover
                        }
                    }
                    Image {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        width: Units.gu(2.6)
                        height: width
                        visible: Library.isCloud(modelData)
                        fillMode: Image.PreserveAspectFit
                        sourceSize: Qt.size(Math.ceil(width), Math.ceil(height))
                        source: visible ? appWindow.libraryIcon({ accountId: modelData.accountId, templateId: modelData.type }) : ""
                    }
                }
                Label {
                    width: parent.width
                    text: modelData.title
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }
                Label {
                    width: parent.width
                    text: Library.countLabel(modelData)
                    color: "#9a9a9a"
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }
            }
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

    Rectangle {
        id: toolbar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Units.gu(7)
        color: "#2a2a2a"

        IconButton {
            objectName: "librarySlideshowButton"
            anchors.centerIn: parent
            image: "icn-playslideshow"
            onClicked: appWindow.startSlideshow(Library.slideshowAlbums(appWindow.libraryAlbums(), []))
        }
    }
}
