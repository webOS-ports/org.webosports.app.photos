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

.pragma library

/*
 * The app's pictures: PNGs drawn from artwork/ by tools/make-images.sh at
 * one, two and three times their size at grid unit 10. The set is the
 * smallest that is not smaller than the screen needs, so a picture is only
 * ever made smaller (sourceSize does that once, smoothly), never blown up;
 * at grid unit 10 it is the drawn pixels themselves.
 *
 *     Image { source: Images.url("check", Units.gridUnit); sourceSize: ... }
 */

function scale(gridUnit) {
    // Five percent over a set is still that set: not worth twice the pixels
    return Math.max(1, Math.min(3, Math.ceil(gridUnit / 10 - 0.05)));
}

// The pictures drawn with a "-pressed" state too (artwork/<name>-pressed.svg)
var pressedNames = ["icn-add-album", "icn-comments", "icn-delete", "icn-edit", "icn-fillscreen",
                    "icn-normalsize", "icn-pause", "icn-play", "icn-playslideshow", "icn-print",
                    "icn-share-contact", "icn-shuffle", "icn-time"];

function hasPressed(name) {
    return pressedNames.indexOf(name) >= 0;
}

function url(name, gridUnit) {
    return Qt.resolvedUrl("../images/" + scale(gridUnit) + "x/" + name + ".png");
}
