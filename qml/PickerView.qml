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
 * Add Photos, for an empty album: the library's pictures and videos,
 * newest first, picked and added (webOS opened its media file picker).
 */
Rectangle {
    id: picker

    signal picked(var ids)
    signal cancelled()

    readonly property var store: appWindow.store
    property var selection: Library.newSelection()
    readonly property var items: {
        store.revision;
        if (!visible)
            return [];
        var all = [];
        store.lib.albums.forEach(function(a) {
            if (!Library.isCloud(a))
                all = all.concat(store.itemsOf(a._id));
        });
        return all.sort(Library.compareItems);
    }

    color: "#1a1a1a"
    onVisibleChanged: selection = Library.newSelection()

    Rectangle {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        height: appWindow.headerHeight
        color: "#2a2a2a"

        Button {
            objectName: "pickerCancel"
            anchors.left: parent.left
            anchors.leftMargin: Units.gu(1)
            anchors.verticalCenter: parent.verticalCenter
            text: "Cancel"
            onClicked: picker.cancelled()
        }
        Label {
            anchors.centerIn: parent
            text: Library.selectedCount(picker.selection, picker.items.length) + " Selected"
            color: "white"
            font.pixelSize: FontUtils.sizeToPixels("medium")
        }
        Button {
            objectName: "pickerDone"
            anchors.right: parent.right
            anchors.rightMargin: Units.gu(1)
            anchors.verticalCenter: parent.verticalCenter
            text: "Add"
            enabled: Library.selectedCount(picker.selection, picker.items.length) > 0
            onClicked: picker.picked(Library.selectedItems(picker.selection, picker.items).map(function(i) { return i._id; }))
        }
    }

    ItemGrid {
        objectName: "pickerGrid"
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        items: picker.items
        selecting: true
        selection: picker.selection
        onTapped: function(item) { picker.selection = Library.toggle(picker.selection, item._id); }
    }
}
