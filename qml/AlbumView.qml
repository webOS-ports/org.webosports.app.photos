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
 * An album (webOS's AlbumMode): its pictures and videos, newest first. The
 * title, tapped, renames it (not the camera's, not a cloud album). Empty,
 * it offers Add Photos and Delete Album. The select button picks pictures
 * to add to another album or delete; Select All picks all but those then
 * tapped, which the photos service is told as such ("exclude").
 */
Rectangle {
    id: view
    objectName: "albumView"

    property var album: null
    readonly property var store: appWindow.store
    readonly property var items: { store.revision; return album ? store.itemsOf(album._id) : []; }
    readonly property bool empty: album !== null && items.length === 0

    property bool selecting: false
    property var selection: Library.newSelection()
    readonly property int selectedCount: Library.selectedCount(selection, items.length)
    property bool picking: false

    color: "#1a1a1a"

    function cancelSelection() {
        selecting = false;
        picking = false;
        selection = Library.newSelection();
    }

    function handleBack() {
        if (picking) {
            picking = false;
            return true;
        }
        if (selecting) {
            cancelSelection();
            return true;
        }
        return false;
    }

    onAlbumChanged: if (!album) cancelSelection()

    // A thumbnail that did not load, at most every two seconds.
    Timer {
        id: regenerate
        interval: 2000
        onTriggered: view.store.regenerateThumbnails()
    }

    Rectangle {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        height: appWindow.headerHeight
        color: "#2a2a2a"
        z: 2

        // Album mode's top bar.
        Item {
            anchors.fill: parent
            visible: !view.selecting

            IconButton {
                id: backButton
                objectName: "albumBackButton"
                anchors.left: parent.left
                anchors.leftMargin: Units.gu(0.5)
                anchors.verticalCenter: parent.verticalCenter
                visible: !appWindow.wide
                image: "dark-back-arrow"
                // the legacy back arrow is 16 px
                iconSize: Units.gu(1.6)
                onClicked: appWindow.albumId = ""
            }
            Image {
                id: badge
                anchors.left: backButton.visible ? backButton.right : parent.left
                anchors.leftMargin: Units.gu(1.5)
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? Units.gu(3) : 0
                height: Units.gu(3)
                visible: Library.isCloud(view.album)
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(Units.gu(6), Units.gu(6))
                source: visible ? appWindow.libraryIcon({ accountId: view.album.accountId, templateId: view.album.type }) : ""
            }
            Label {
                id: titleLabel
                objectName: "albumTitle"
                anchors.left: badge.right
                anchors.leftMargin: Units.gu(1)
                anchors.right: parent.right
                anchors.rightMargin: Units.gu(2)
                anchors.verticalCenter: parent.verticalCenter
                text: view.album ? view.album.title : "Album"
                color: "white"
                elide: Text.ElideRight
                font.pixelSize: FontUtils.sizeToPixels("large")
                MouseArea {
                    objectName: "renameArea"
                    anchors.fill: parent
                    enabled: Library.canRename(view.album) && view.store.serviceAvailable
                    onClicked: appWindow.askRename(view.album)
                }
            }
        }

        // Multi-select's: Cancel, how many, Select All / None.
        Item {
            anchors.fill: parent
            visible: view.selecting

            Button {
                objectName: "cancelSelectButton"
                anchors.left: parent.left
                anchors.leftMargin: Units.gu(1)
                anchors.verticalCenter: parent.verticalCenter
                text: "Cancel"
                onClicked: view.cancelSelection()
            }
            Label {
                objectName: "selectedLabel"
                anchors.centerIn: parent
                text: view.selectedCount + " Selected"
                color: "white"
                font.pixelSize: FontUtils.sizeToPixels("medium")
            }
            Button {
                objectName: "selectAllButton"
                anchors.right: parent.right
                anchors.rightMargin: Units.gu(1)
                anchors.verticalCenter: parent.verticalCenter
                readonly property bool all: view.selectedCount === view.items.length && view.items.length > 0
                text: all ? "Select None" : "Select All"
                onClicked: view.selection = Library.selectAll(!all)
            }
        }
    }

    ItemGrid {
        id: grid
        objectName: "itemGrid"
        anchors.top: header.bottom
        anchors.bottom: toolbar.top
        anchors.left: parent.left
        anchors.right: parent.right
        items: view.items
        selecting: view.selecting
        selection: view.selection
        visible: !view.empty
        onTapped: function(item, index) {
            if (view.selecting)
                view.selection = Library.toggle(view.selection, item._id);
            else
                appWindow.openPicture(view.album._id, item._id, true);
        }
        onThumbnailBroken: if (!regenerate.running) regenerate.start()
    }

    // An empty album.
    Column {
        objectName: "emptyAlbum"
        anchors.centerIn: grid
        width: Math.min(parent.width - Units.gu(4), Units.gu(40))
        spacing: Units.gu(2)
        visible: view.empty

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Units.gu(12.8)
            height: width
            sourceSize: Qt.size(Math.ceil(width), Math.ceil(height))
            source: Images.url("empty-photo-library", Units.gridUnit)
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Your album is empty."
            color: "#c0c0c0"
            font.pixelSize: FontUtils.sizeToPixels("large")
        }
        Button {
            objectName: "addPhotosButton"
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.8
            text: "Add Photos"
            visible: Library.canAddTo(view.album)
            enabled: view.store.serviceAvailable
            onClicked: view.picking = true
        }
        Button {
            objectName: "deleteAlbumButton"
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.8
            text: "Delete Album"
            LuneOSButton.mainColor: LuneOSButton.negativeColor
            visible: !!view.album && !view.album.virtual && view.store.can(view.album, "deleteAlbum")
            onClicked: appWindow.askDeleteAlbum(view.album)
        }
    }

    Rectangle {
        id: toolbar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Units.gu(7)
        color: "#2a2a2a"

        // Album mode: the select button, the date and counts, Slideshow.
        Item {
            anchors.fill: parent
            visible: !view.selecting

            IconButton {
                id: selectButton
                objectName: "selectButton"
                anchors.left: parent.left
                anchors.leftMargin: Units.gu(1)
                anchors.verticalCenter: parent.verticalCenter
                image: "icn-edit"
                visible: !view.empty
                onClicked: {
                    view.selection = Library.newSelection();
                    view.selecting = true;
                }
            }
            Column {
                anchors.centerIn: parent
                width: parent.width - Units.gu(16)
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: text !== ""
                    text: view.album ? Library.formatDate(view.album.modifiedTime) : ""
                    color: "#c0c0c0"
                    elide: Text.ElideRight
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }
                Label {
                    objectName: "albumCounts"
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Library.countLabel(view.album)
                    color: "#c0c0c0"
                    elide: Text.ElideRight
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }
            }
            IconButton {
                objectName: "albumSlideshowButton"
                anchors.right: parent.right
                anchors.rightMargin: Units.gu(1)
                anchors.verticalCenter: parent.verticalCenter
                image: "icn-playslideshow"
                visible: !!view.album && view.album.images > 0
                onClicked: appWindow.startSlideshow([view.album._id])
            }
        }

        // Multi-select: Add to Album, Delete.
        Row {
            anchors.centerIn: parent
            spacing: Units.gu(4)
            visible: view.selecting

            IconButton {
                objectName: "addToAlbumButton"
                image: "icn-add-album"
                enabled: view.store.serviceAvailable
                onClicked: appWindow.chooseAlbum(Library.selectedItems(view.selection, view.items),
                                                 view.album._id)
            }
            IconButton {
                objectName: "deleteSelectedButton"
                image: "icn-delete"
                visible: view.store.can(view.album, "deletePhoto")
                onClicked: appWindow.askDelete(Library.selectedItems(view.selection, view.items), view.album,
                                               view.selection, function() { view.cancelSelection(); })
            }
        }
    }

    // Add Photos: every picture and video of the library, picked.
    PickerView {
        id: picker
        objectName: "picker"
        anchors.fill: parent
        visible: view.picking
        z: 5
        onCancelled: view.picking = false
        onPicked: function(ids) {
            view.picking = false;
            if (ids.length > 0)
                view.store.addPhotos(view.album._id, [Library.specForIds(ids, "", view.album._id)]);
        }
    }
}
