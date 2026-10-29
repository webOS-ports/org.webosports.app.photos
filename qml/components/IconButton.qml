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
import LuneOS.Forms 1.0 as Forms

import "../js/Images.js" as Images

/*
 * LuneOS.Forms' toolbar key with a picture from qml/images ("<image>", a
 * PNG of tools/make-images.sh), or a short text (the speed), on the
 * player's dark bars: while held or checked it shows the picture's
 * "-pressed" state, the legacy glow, where it has one. Forms draws its
 * picture from an SVG; the app's are PNGs, so the key's inside is its own.
 */
Forms.IconToolButton {
    id: key

    appearance: "overlay"
    implicitHeight: Math.max(Units.gu(5.5), 54)
    // The legacy toolbar pictures are 32 px
    iconSize: Units.gu(3.2)

    contentItem: Item {
        Image {
            objectName: "iconButtonImage"
            anchors.centerIn: parent
            width: key.iconSize
            height: key.iconSize
            visible: key.image !== ""
            source: key.image === "" ? ""
                    : Images.url((key.pressed || key.checked) && Images.hasPressed(key.image)
                                 ? key.image + "-pressed" : key.image, Units.gridUnit)
            sourceSize: Qt.size(Math.ceil(width), Math.ceil(height))
            opacity: key.enabled ? 1.0 : 0.35
        }
        Text {
            anchors.centerIn: parent
            visible: key.image === ""
            text: key.label
            color: key.labelColor
            opacity: key.enabled ? 1.0 : 0.35
            font.pixelSize: FontUtils.sizeToPixels("medium")
            font.bold: true
        }
    }
}
