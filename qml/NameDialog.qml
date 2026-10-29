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

import "js/Library.js" as Library

/*
 * An album's name, asked: "New Album" (Create Album) or "Rename Album".
 * An empty name is not taken; the field flashes red, as webOS's did.
 */
LC.Dialog {
    id: dialog

    property string acceptText: "OK"
    property var _done: null
    readonly property bool isOpen: visible
    property alias text: input.text

    visible: false
    dialogHeight: Units.gu(20)
    dialogWidth: Math.min(Units.gu(34), parent ? parent.width - Units.gu(2) : Units.gu(34))
    keepClearOfKeyboard: true

    function ask(newTitle, value, accept, done) {
        title = newTitle;
        message = "";
        input.text = value || "";
        acceptText = accept;
        _done = done;
        open();
        input.textInput.forceActiveFocus();
        input.textInput.selectAll();
    }

    function cancel() {
        _done = null;
        close();
    }

    function accept() {
        if (!Library.validAlbumName(input.text)) {
            flash.restart();
            return;
        }
        var d = _done;
        var name = input.text.trim();
        _done = null;
        close();
        if (d)
            d(name);
    }

    Row {
        LC.DialogLineInput {
            id: input
            objectName: "albumNameField"
            onAccepted: dialog.accept()
            Rectangle {
                id: warn
                anchors.fill: parent
                color: "#be0003"
                opacity: 0
                radius: Units.gu(0.5)
                SequentialAnimation on opacity {
                    id: flash
                    running: false
                    NumberAnimation { to: 0.35; duration: 120 }
                    NumberAnimation { to: 0; duration: 400 }
                }
            }
        }
    }
    Row {
        LC.DialogButton {
            objectName: "nameAcceptButton"
            text: dialog.acceptText
            color: "#171717"
            fontcolor: "white"
            buttonWidth: Units.gu(26.0)
            onClicked: dialog.accept()
        }
    }
    Row {
        LC.DialogButton {
            text: "Cancel"
            color: "transparent"
            fontcolor: "#444444"
            buttonWidth: Units.gu(26.0)
            onClicked: dialog.cancel()
        }
    }
}
