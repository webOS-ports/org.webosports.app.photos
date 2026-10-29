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
import "../js/Images.js" as Images

/*
 * An album's pictures and videos as a grid (webOS's AlbumGridView): a
 * video shows its name and length on a bar, and while selecting a picked
 * one is framed in blue and the others are dimmed.
 */
Flickable {
  id: grid

  clip: true
  boundsBehavior: Flickable.StopAtBounds

  property var items: []
  property bool selecting: false
  property var selection: Library.newSelection()
  signal tapped(var item, int index)
  signal thumbnailBroken()

  readonly property real rowHeight: Units.gu(16)

  Flow {

    anchors.fill: parent
    //readonly property int columns: Math.max(3, Math.floor(width / Units.gu(16)))
    //cellWidth: Math.floor(width / columns)
    //cellHeight: cellWidth

    Repeater {
      id: flowRepeater
      model: grid.items
      delegate: Item {
        id: cell
        objectName: "item-" + modelData._id
        width: cellThumbnail.width
        height: grid.rowHeight
        readonly property bool picked: grid.selecting && Library.isSelected(grid.selection, modelData._id)

        Thumbnail {
            id: cellThumbnail
            height: parent.height
            width: height*cellThumbnail.aspectRatio
            anchors.margins: 1
            // While selecting, what is not picked is dimmed, as webOS did
            opacity: grid.selecting && !cell.picked ? 0.4 : 1.0
            item: modelData
            onBroken: grid.thumbnailBroken()
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 1
            height: Units.gu(3)
            visible: modelData.mediaType === "video"
            opacity: grid.selecting && !cell.picked ? 0.4 : 1.0
            color: "#b0000000"
            Image {
                id: videoSign
                anchors.left: parent.left
                anchors.leftMargin: Units.gu(0.5)
                anchors.verticalCenter: parent.verticalCenter
                width: Units.gu(2.1)
                height: Units.gu(1.7)
                sourceSize: Qt.size(Math.ceil(width), Math.ceil(height))
                source: Images.url("icn-video-overlay", Units.gridUnit)
            }
            Label {
                anchors.left: videoSign.right
                anchors.leftMargin: Units.gu(0.5)
                anchors.right: length.left
                anchors.verticalCenter: parent.verticalCenter
                text: Library.basename(modelData.path)
                color: "white"
                elide: Text.ElideMiddle
                font.pixelSize: FontUtils.sizeToPixels("small")
            }
            Label {
                id: length
                anchors.right: parent.right
                anchors.rightMargin: Units.gu(0.5)
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.duration > 0 ? Library.formatDuration(modelData.duration) : ""
                color: "white"
                font.pixelSize: FontUtils.sizeToPixels("small")
            }
        }
        // A picked one in webOS's blue frame: multi-select-9tile, its
        // borders 15 px at grid unit 10. A BorderImage draws borders at the
        // PNG's own pixels, so the frame is laid out at the set's scale and
        // shrunk to this screen's.
        BorderImage {
            id: pickedFrame
            objectName: "pickedFrame"
            readonly property int set: Images.scale(Units.gridUnit)
            readonly property real shrink: Units.gridUnit / 10 / set
            width: parent.width / shrink
            height: parent.height / shrink
            visible: cell.picked
            source: Images.url("multi-select-9tile", Units.gridUnit)
            border { left: 15 * set; top: 15 * set; right: 15 * set; bottom: 15 * set }
            transform: Scale { xScale: pickedFrame.shrink; yScale: pickedFrame.shrink }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: grid.tapped(modelData, index)
        }
    }
    }
  }
}
