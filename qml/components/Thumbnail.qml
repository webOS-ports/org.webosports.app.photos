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

import LunaNext.Common 0.1

import "../js/Library.js" as Library
import "../js/Images.js" as Images

/*
 * A picture or video, small: the thumbnail the indexer or the photos
 * service made, or the file scaled down when the thumbnail is too small
 * for the cell; a video without one shows the video sign. A thumbnail that
 * does not load (its file gone) asks the service for new ones.
 */
Item {
    id: thumb

    property var item: null
    property bool crop: true
    signal broken()

    Rectangle {
        anchors.fill: parent
        color: "#2b2b2b"
    }
    Image {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.4
        height: width
        sourceSize: Qt.size(Math.ceil(width), Math.ceil(height))
        source: Images.url(thumb.item && thumb.item.mediaType === "video" ? "blank-video" : "empty-thumbnail", Units.gridUnit)
        opacity: 0.35
        visible: picture.status !== Image.Ready
    }
    Image {
        id: picture
        objectName: "picture"
        anchors.fill: parent
        asynchronous: true
        autoTransform: true
        cache: true
        fillMode: thumb.crop ? Image.PreserveAspectCrop : Image.PreserveAspectFit
        clip: true
        sourceSize: Qt.size(Math.ceil(width), Math.ceil(height))
        source: Library.fileUrl(Library.thumbnailPath(thumb.item, Math.max(width, height)))
        onStatusChanged: if (status === Image.Error) thumb.broken()
    }
}
