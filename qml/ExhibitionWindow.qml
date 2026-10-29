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

import Eos.Window 0.1
import LunaNext.Common 0.1

/*
 * The window exhibition mode shows: the shell launches the app with
 * { windowType: "dockModeWindow", dockMode: true } and takes in a window of
 * the dock type, full screen; it closes that window again on undocking,
 * which hides it here (main.qml then lets it go). It plays the slideshow,
 * as webOS's Photos did on the Touchstone.
 */
WebOSWindow {
    id: window

    property alias store: slideshow.store
    property alias prefs: slideshow.prefs
    property alias slideshow: slideshow

    windowType: "_WEBOS_WINDOW_TYPE_DOCK"
    width: Settings.displayWidth
    height: Settings.displayHeight
    color: "black"
    visible: true
    title: "Photos"

    SlideshowView {
        id: slideshow
        anchors.fill: parent
        exhibition: true
    }

    // A slideshow is paused while the window is not shown.
    onActiveChanged: active ? slideshow.resume() : slideshow.pause()
}
