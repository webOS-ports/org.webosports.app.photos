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

import "../js/Library.js" as Library

/*
 * An album as a cell: a stack of prints with its cover, the account's
 * mark for a cloud album, its title and what is in it. The library's grid
 * shows these, and an album its sub-albums.
 */
ItemDelegate {
    id: cell

    property var album: null

    objectName: "albumCell-" + (album ? album._id : "")
    padding: Units.gu(0.8)
    background: Rectangle {
        radius: Units.gu(0.6)
        color: cell.pressed ? "#333333" : "transparent"
    }
    onClicked: if (album) appWindow.openAlbum(album._id)

    contentItem: Column {
        spacing: Units.gu(0.5)
        Item {
            width: parent.width
            height: width * 0.75
            // A stack of prints, as webOS drew an album; more so with albums in it.
            Rectangle {
                anchors.fill: parent
                anchors.margins: Units.gu(0.4)
                rotation: 4
                color: "#bdbdbd"
                antialiasing: true
                visible: !!cell.album && cell.album.subAlbums > 0
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: Units.gu(0.4)
                rotation: -4
                color: "#d8d8d8"
                antialiasing: true
                visible: !!cell.album && (cell.album.images + cell.album.videos > 1 || cell.album.subAlbums > 0)
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: Units.gu(0.4)
                color: "#f2f2f2"
                antialiasing: true
                Thumbnail {
                    anchors.fill: parent
                    anchors.margins: Units.gu(0.4)
                    item: cell.album ? cell.album.cover : null
                }
            }
            Image {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: Units.gu(2.6)
                height: width
                visible: Library.isCloud(cell.album)
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(Math.ceil(width), Math.ceil(height))
                source: visible ? appWindow.libraryIcon({ accountId: cell.album.accountId, templateId: cell.album.type }) : ""
            }
        }
        Label {
            width: parent.width
            text: cell.album ? cell.album.title : ""
            color: "white"
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.pixelSize: FontUtils.sizeToPixels("medium")
        }
        Label {
            width: parent.width
            text: Library.countLabel(cell.album)
            color: "#9a9a9a"
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.pixelSize: FontUtils.sizeToPixels("small")
        }
    }
}
