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
import "js/Images.js" as Images

/*
 * Libraries & Albums (webOS's LibraryNavigationPanel): the libraries - all
 * of them, the device, each cloud account with a spinner while it syncs -
 * then every album, and New Album at the bottom. On a narrow window it is
 * the first page.
 */
Rectangle {
    id: panel
    objectName: "libraryPanel"

    readonly property var store: appWindow.store
    readonly property var albums: { store.revision; return appWindow.wide ? store.lib.albums : appWindow.libraryAlbums(); }
    property bool librariesOpen: true

    color: "#262626"

    Rectangle {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        height: appWindow.headerHeight
        color: "#1d1d1d"
        z: 2

        Image {
            id: appIcon
            anchors.left: parent.left
            anchors.leftMargin: Units.gu(1.5)
            anchors.verticalCenter: parent.verticalCenter
            width: Units.gu(4)
            height: width
            sourceSize: Qt.size(width, height)
            source: Qt.resolvedUrl("../icon.png")
        }
        Label {
            anchors.left: appIcon.right
            anchors.leftMargin: Units.gu(1)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Libraries & Albums"
            color: "white"
            elide: Text.ElideRight
            font.pixelSize: FontUtils.sizeToPixels("large")
        }
    }

    Flickable {
        id: list
        objectName: "albumList"
        anchors.top: header.bottom
        anchors.bottom: toolbar.top
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        contentHeight: column.height
        boundsBehavior: Flickable.StopAtBounds
        readonly property int count: albumRows.count

        // Scrolls just far enough to show the given row whole.
        function ensureVisible(row) {
            var y = row.mapToItem(column, 0, 0).y;
            if (y < contentY)
                contentY = y;
            else if (y + row.height > contentY + height)
                contentY = Math.min(y + row.height - height, Math.max(0, contentHeight - height));
        }

        Column {
            id: column
            width: list.width

            LC.SectionDivider {
                text: "LIBRARIES"
                open: panel.librariesOpen
                onClicked: panel.librariesOpen = !panel.librariesOpen
            }
            Column {
                width: parent.width
                visible: panel.librariesOpen

                PanelRow {
                    objectName: "library-all"
                    title: "All Photos & Videos"
                    iconSource: Images.url("icn-all-photos", Units.gridUnit)
                    selected: appWindow.source === "all" && (appWindow.albumId === "" || !appWindow.wide)
                    onClicked: appWindow.showSource("all")
                }
                Repeater {
                    model: panel.store.libraries
                    PanelRow {
                        objectName: "library-" + modelData.accountId
                        title: modelData.title
                        iconSource: appWindow.libraryIcon(modelData)
                        busy: Library.isSyncing(modelData)
                        selected: appWindow.source === modelData.accountId && (appWindow.albumId === "" || !appWindow.wide)
                        onClicked: appWindow.showSource(modelData.accountId)
                    }
                }
            }
            LC.SectionDivider {
                text: appWindow.wide || appWindow.source === "all" ? "ALL ALBUMS" : appWindow.sourceTitle.toUpperCase()
            }
            Label {
                objectName: "panelStatus"
                width: parent.width
                padding: Units.gu(2)
                visible: panel.albums.length === 0
                wrapMode: Text.Wrap
                color: "#9a9a9a"
                font.pixelSize: FontUtils.sizeToPixels("small")
                text: panel.store.status === "loading" ? "Looking for photos and videos…"
                    : panel.store.status === "denied" ? "Photos & Videos was not allowed to see your pictures."
                    : panel.store.status === "error" ? panel.store.errorText
                    : "No albums"
            }
            Repeater {
                id: albumRows
                model: panel.albums
                PanelRow {
                    objectName: "album-" + modelData._id
                    title: modelData.title
                    subtitle: appWindow.wide ? "" : Library.countLabel(modelData)
                    coverItem: modelData.cover
                    badge: Library.isCloud(modelData) ? appWindow.libraryIcon({ accountId: modelData.accountId,
                                                                               templateId: modelData.type }) : ""
                    selected: appWindow.albumId === modelData._id
                    onClicked: appWindow.openAlbum(modelData._id)
                }
            }
        }
    }

    Rectangle {
        id: toolbar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Units.gu(7)
        color: "#1d1d1d"

        Button {
            objectName: "newAlbumButton"
            anchors.centerIn: parent
            text: "New Album"
            enabled: panel.store.serviceAvailable
            onClicked: appWindow.askNewAlbum([])
        }
        IconButton {
            objectName: "panelSlideshowButton"
            anchors.right: parent.right
            anchors.rightMargin: Units.gu(1)
            anchors.verticalCenter: parent.verticalCenter
            visible: !appWindow.wide
            image: "icn-playslideshow"
            onClicked: appWindow.startSlideshow(Library.slideshowAlbums(appWindow.libraryAlbums(), []))
        }
    }

    // A library or an album: an album shows its cover, or the generic album
    component PanelRow: LC.IconListRow {
        id: row
        property var coverItem: null
        iconSource: Images.url("icon_album_thumbnail_generic", Units.gridUnit)
        picture: coverItem !== null ? cover : null
        property Component cover: Component {
            Thumbnail { item: row.coverItem }
        }
    }
}
