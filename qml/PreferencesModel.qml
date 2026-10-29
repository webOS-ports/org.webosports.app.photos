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
import QtCore as Core
import LuneOS.Components 1.0

/*
 * What the app remembers: the slideshow's time per picture and the albums
 * exhibition plays (webOS kept those in db8's isSlideshowSelected, on the
 * indexer's albums, which this app does not write).
 */
Core.Settings {
    id: prefs

    // In the app's own file, as every QML app has (LuneOS.Components' AppFiles).
    location: AppFiles.preferencesFile("org.webosports.app.photos")
    category: "photos"

    property int slideshowInterval: 10000
    property var exhibitionAlbums: []
    property bool exhibitionShuffle: false
}
