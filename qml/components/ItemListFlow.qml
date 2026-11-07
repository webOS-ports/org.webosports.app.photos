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
ListView {
    id: root

    property var items: []
    property bool selecting: false
    property var selection: Library.newSelection()
    signal tapped(var item, int index)
    signal thumbnailBroken()

    orientation: ListView.Vertical
    clip: true
    model: flowListModel
    boundsBehavior: Flickable.StopAtBounds

    spacing: 5

    readonly property real rowHeight: Units.gu(12)
    property ListModel flowListModel: ListModel {}

    onItemsChanged: fillPhotoList();
    onWidthChanged: fillPhotoList();

    function fillPhotoList() {
        // recompute the preferred scaling of each photo, line by line
        const maxWidth = root.width;
        const wantedHeight = root.rowHeight;
        var currentWidth=0;

        var lineContentArray = []
        flowListModel.clear();

        for(let currentPhoto of root.items) {
            // setup fallback height and width to a square of the line's height
            if (!currentPhoto.height) currentPhoto.height = wantedHeight;
            if (!currentPhoto.width) currentPhoto.width = wantedHeight;

            // compute this photo's scaling to fit the wanted height, and
            // use it to compute the photo's scaled width keeping aspect ratio
            const currentHeightScaling = wantedHeight / currentPhoto.height;
            const nextWidth = root.spacing + currentPhoto.width * currentHeightScaling;

            // if the photo overflows the listview's width, adjust the scaling and commit the line
            if( currentWidth+nextWidth > maxWidth ) {
                var widthScaling = maxWidth/currentWidth;

                // compute the final scaling for each photo
                for( let linePhoto of lineContentArray ) {
                    linePhoto.scaling=widthScaling * wantedHeight / linePhoto.photo.height;
                }

                // commit this line to the global model, and start a new one
                flowListModel.append({lineHeight: wantedHeight*widthScaling, lineContent: lineContentArray});
                lineContentArray = [];

                // reset counters
                currentWidth = 0;
            }

            lineContentArray.push({photo: currentPhoto, scaling: currentHeightScaling});
            currentWidth += nextWidth;
        }
        flowListModel.append({lineHeight: wantedHeight, lineContent: lineContentArray });
    }

    delegate: Row {
        id: listRow
        //property var lineModel: modelData.lineContent
        height: lineHeight
        spacing: root.spacing

        Repeater {
            model: lineContent
            delegate: ItemListFlowDelegate {
                id: cell
                objectName: "item-" + modelData._id

                property var modelData: photo

                height: modelData.height * scaling
                width: modelData.width * scaling

                picked: root.selecting && Library.isSelected(root.selection, modelData._id)
                gridSelecting: root.selecting

                onThumbnailBroken: root.thumbnailBroken()
                onTapped: (item, index) => root.tapped(item, index)
            }
        }
    }
}
