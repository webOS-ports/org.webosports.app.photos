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

import "../js/Images.js" as Images

/*
 * The large spinner of webOS 3.0's Enyo (enyo.SpinnerLarge, Onyx's
 * spinner-large: 128px at the TouchPad's scale, one turn a second), for a
 * view whose content is on its way. Turned on the render thread, as
 * luneos-components' BusyIndicator is, so a busy page does not stop it.
 */
Image {
    id: spinner

    property bool running: true

    width: Units.gu(12.8)
    height: width
    source: Images.url("spinner-large", Units.gridUnit)
    sourceSize: Qt.size(width, height)
    smooth: true
    opacity: running ? 1 : 0
    visible: opacity > 0

    Behavior on opacity { OpacityAnimator { duration: 250 } }

    RotationAnimator on rotation {
        running: spinner.running && spinner.visible
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: 1000
    }
}
