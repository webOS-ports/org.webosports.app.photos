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

    spacing: Units.gu(0.2)

    readonly property real rowHeight: Units.gu(12)
    property ListModel flowListModel: ListModel {}

    onItemsChanged: fillPhotoList();
    onWidthChanged: fillPhotoList();

    function _setOrInsertPhotoRow(idxCurrentRow, lineContentArray, lineHeight) {
        // Compare this line to the previous existing line, if any
        if (flowListModel.count > idxCurrentRow) {
            let previousRowModel = flowListModel.get(idxCurrentRow);
            if (lineContentArray.length !== previousRowModel.lineContent.count ||
                lineContentArray.some((linePhoto, index) => {
                      let previousLinePhoto = previousRowModel.lineContent.get(index);
                      return previousLinePhoto.photo._id !== linePhoto.photo._id;
                }))
            {
                // row has changed: set new value
                flowListModel.set(idxCurrentRow, {lineHeight: lineHeight, lineContent: lineContentArray});
            }
            else {
                // even if the row contains the same photos, update the photos scaling and line height:
                // the scaling depends on the whole line, so every photo gets its new one
                lineContentArray.forEach((linePhoto, index) => {
                    let previousLinePhoto = previousRowModel.lineContent.get(index);
                    previousLinePhoto.scaling = linePhoto.scaling;
                    // The model also keeps a copy of each photo: one whose thumbnail,
                    // path or size changed since is given to its cell again.
                    if (!Library.sameEntry(previousLinePhoto.photo, linePhoto.photo))
                        previousLinePhoto.photo = linePhoto.photo;
                });
                previousRowModel.lineHeight = lineHeight;
            }
        }
        else {
            flowListModel.append({lineHeight: lineHeight, lineContent: lineContentArray});
        }
    }

    function fillPhotoList() {
        // recompute the preferred scaling of each photo, line by line
        const maxWidth = root.width;
        const wantedHeight = root.rowHeight;
        var currentWidth=0;

        var idxCurrentRow = 0;
        var lineContentArray = []

        for(let currentPhoto of root.items) {
            // setup fallback height and width to a square of the line's height
            const currentPhotoHeight = currentPhoto.height || wantedHeight;
            const currentPhotoWidth  = currentPhoto.width  || wantedHeight;

            // compute this photo's scaling to fit the wanted height, and
            // use it to compute the photo's scaled width keeping aspect ratio
            const currentHeightScaling = wantedHeight / currentPhotoHeight;
            const nextWidth = currentPhotoWidth * currentHeightScaling;

            if (currentWidth>0) currentWidth += root.spacing;
            currentWidth += nextWidth;

            lineContentArray.push({photo: currentPhoto, scaling: currentHeightScaling});

            // if the last photo overflows the listview's width, adjust the scaling and commit the line
            if( currentWidth > maxWidth ) {
                // n photos have n-1 gaps between them, which are not scaled
                const cumulatedSpacing = root.spacing * (lineContentArray.length - 1);
                const widthScaling = (maxWidth-cumulatedSpacing)/(currentWidth-cumulatedSpacing);

                // compute the final scaling for each photo
                for( let linePhoto of lineContentArray ) {
                    linePhoto.scaling=widthScaling * wantedHeight / (linePhoto.photo.height || wantedHeight);
                }

                // commit this line to the global model, and start a new one
                _setOrInsertPhotoRow(idxCurrentRow, lineContentArray, wantedHeight*widthScaling)
                lineContentArray = [];

                // reset counters
                currentWidth = 0;
                idxCurrentRow++;
            }
        }
        // commit last incomplete row: it does not fill the width, so its photos
        // keep the wanted height they were given above
        if (lineContentArray.length>0) {
            _setOrInsertPhotoRow(idxCurrentRow++, lineContentArray, wantedHeight)
        }

        // Remove lines that aren't there anymore
        if (flowListModel.count>idxCurrentRow) {
            flowListModel.remove(idxCurrentRow, flowListModel.count-idxCurrentRow);
        }
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

                height: (modelData.height || root.rowHeight) * scaling
                width: (modelData.width || root.rowHeight) * scaling

                picked: root.selecting && Library.isSelected(root.selection, modelData._id)
                gridSelecting: root.selecting

                onThumbnailBroken: root.thumbnailBroken()
                onTapped: (item, index) => root.tapped(item, index)
            }
        }
    }
}
