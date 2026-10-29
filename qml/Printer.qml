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

import LuneOS.Components 1.0 as LC

/*
 * Printing a picture: the printers luneos-print-adapter (which serves
 * webOS's com.palm.printmgr over CUPS) sees, one picked, and the file sent
 * as one job (jobs/allAtOnce). Without the service, it says so.
 */
QtObject {
    id: printer

    // function(uri, json, onReply, onError)
    property var call: null
    property var sheet: null
    readonly property bool isOpen: sheet !== null && sheet.visible
    signal message(string text)
    // The job sent (the tests read it).
    signal printed(var params)

    function close() {
        if (sheet)
            sheet.hide();
    }

    function printItem(item, actionSheet) {
        sheet = actionSheet;
        call("luna://com.palm.printmgr/printers/listActive", JSON.stringify({}), function(m) {
            var r = JSON.parse(m.payload);
            var list = r.returnValue ? (r.activePrinters || []) : [];
            if (list.length === 0) {
                printer.message("No printers found");
                return;
            }
            actionSheet.show("Print", list.map(function(p) {
                return { label: p.printerName || p.printerID, key: p.printerID,
                         action: function() { printer._send(item, p.printerID); } };
            }), item.path.substring(item.path.lastIndexOf("/") + 1));
        }, function() {
            printer.message("Printing is not available");
        });
    }

    function _send(item, printerId) {
        var params = { printerID: printerId, description: item.path.substring(item.path.lastIndexOf("/") + 1),
                       appName: "Photos", pathNames: [item.path], autoScale: true };
        printed(params);
        call("luna://com.palm.printmgr/jobs/allAtOnce", JSON.stringify(params), function(m) {
            var r = JSON.parse(m.payload);
            printer.message(r.returnValue ? "Sent to the printer" : "Could not print: " + (r.errorText || r.errorCode));
        }, function(error) {
            printer.message("Could not print: " + error);
        });
    }
}
