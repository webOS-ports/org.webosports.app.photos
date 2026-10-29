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

/*
 * LuneOS.Components' ConfirmDialog, asked with a title, the words, the
 * button and what it does: ask("Delete", "Are you sure...", "Delete", true,
 * function() {...}). A null action makes it a notice with one button.
 */
LC.ConfirmDialog {
    id: dialog

    property var _action: null
    readonly property bool isOpen: visible

    visible: false
    dialogHeight: Units.gu(22)
    dialogWidth: Math.min(Units.gu(34), parent ? parent.width - Units.gu(2) : Units.gu(34))

    function ask(newTitle, newMessage, accept, isDestructive, action) {
        title = newTitle;
        message = newMessage;
        acceptText = accept;
        rejectText = action ? "Cancel" : "";
        destructive = isDestructive && !!action;
        _action = action;
        open();
    }

    function cancel() {
        _action = null;
        close();
    }

    onAccepted: {
        var a = _action;
        _action = null;
        close();
        if (a)
            a();
    }
    onRejected: cancel()
}
