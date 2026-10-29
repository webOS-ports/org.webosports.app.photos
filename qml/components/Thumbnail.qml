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
import LuneOS.Components 1.0 as LC

import "../js/Library.js" as Library
import "../js/Images.js" as Images

/*
 * A picture or video, small: the thumbnail the indexer or the photos
 * service made, or the file scaled down when the thumbnail is too small
 * for the cell; a video without one shows the video sign. A thumbnail that
 * does not load (its file gone) says broken(), and the grid asks the
 * service for new ones.
 */
LC.PlaceholderImage {
    id: thumb

    property var item: null

    crop: false
    placeholder: Images.url(item && item.mediaType === "video" ? "blank-video" : "empty-thumbnail", Units.gridUnit)
    source: Library.fileUrl(Library.thumbnailPath(item, Math.max(width, height)))
}
