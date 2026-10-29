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

/*
 * The video engine's interface (qml/VideoEngine.qml) without Qt Multimedia:
 * plays by counting time, 95 s long, and fails for a file named
 * "broken". The tests drive it with advance() and finish().
 */
Rectangle {
    id: engine

    property url source
    property bool fill: false
    property bool playing: false
    property bool ended: false
    property int position: 0
    property int duration: String(source).indexOf("broken") >= 0 ? 0 : 95000
    readonly property bool seekable: duration > 0
    property string errorText: String(source).indexOf("broken") >= 0 ? "Video is corrupted" : ""
    property var seeks: []

    color: "#203040"

    function play() {
        if (errorText !== "")
            return;
        ended = false;
        playing = true;
    }
    function pause() { playing = false; }
    function stop() { playing = false; position = 0; }
    function seek(ms) {
        position = ms;
        var s = seeks.slice();
        s.push(ms);
        seeks = s;
    }
    function advance(ms) { position = Math.min(duration, position + ms); }
    function finish() {
        position = duration;
        playing = false;
        ended = true;
    }
}
