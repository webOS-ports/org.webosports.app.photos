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
 * The bus as the app sees it (main.qml's busCall and busSubscribe), with
 * com.palm.service.photos, the accounts service, systemservice, the print
 * manager and the application manager answered here. Every call is kept
 * in "calls" ({uri, params}); "replies" overrides an answer by URI
 * (an object, or a function of the parameters; null: no answer at all).
 */
QtObject {
    id: bus

    property var calls: []
    // The subscriptions cancelled, by uri
    property var cancelled: []
    property var replies: ({})
    property var accounts: ({
        "local": { accountId: "local", syncStatus: "idle", isEnabled: true },
        "acc-dropbox": { accountId: "acc-dropbox", syncStatus: "idle", isEnabled: true,
                         username: "me@example.com", templateId: "com.palm.dropbox" }
    })
    property var subscribers: []

    readonly property var defaults: ({
        "luna://com.palm.service.photos/getAccountsCapability": { returnValue: true, AccountsCapability: {
            local: { createAlbum: true, deleteAlbum: true, deletePhoto: true, getComments: false },
            "com.palm.dropbox": { createAlbum: false, deleteAlbum: false, deletePhoto: true, getComments: true,
                                  serviceName: "com.palm.service.dropbox" } } },
        "luna://com.palm.service.accounts/listAccountTemplates": { returnValue: true, results: [
            { templateId: "com.palm.dropbox", icon: { loc_48x48: "" } }] },
        "luna://com.palm.service.photos/getPhotoComments": { returnValue: true, comments: [
            { cid: "1", user: "Ann", text: "Nice one", time: 1791400100 }] },
        "luna://com.webos.service.systemservice/wallpaper/importWallpaper": { returnValue: true,
            wallpaper: { wallpaperName: "beach.jpg", wallpaperFile: "/w/beach.jpg" } },
        "luna://com.palm.printmgr/printers/listActive": { returnValue: true, activePrinters: [
            { printerID: "p1", printerName: "Office Printer" }] },
        "luna://com.palm.printmgr/jobs/allAtOnce": { returnValue: true, jobID: 7 }
    })

    function callsTo(uri) {
        return calls.filter(function(c) { return c.uri === uri; });
    }

    function _answer(uri, params) {
        var r = replies.hasOwnProperty(uri) ? replies[uri] : (defaults.hasOwnProperty(uri) ? defaults[uri] : { returnValue: true });
        if (typeof r === "function")
            r = r(params);
        return r;
    }

    function call(uri, json, onReply, onError) {
        var params = JSON.parse(json);
        var c = calls.slice();
        c.push({ uri: uri, params: params });
        calls = c;
        var r = _answer(uri, params);
        if (r === null)
            return null;
        if (r.busError) {
            if (onError)
                onError(r.busError);
            return null;
        }
        if (onReply)
            onReply({ payload: JSON.stringify(r) });
        return { cancel: function() {} };
    }

    function subscribe(uri, json, onReply, onError) {
        var params = JSON.parse(json);
        var c = calls.slice();
        c.push({ uri: uri, params: params });
        calls = c;
        if (uri === "luna://com.palm.service.photos/subscribeToAccountsInfo") {
            var s = subscribers.slice();
            s.push(onReply);
            subscribers = s;
            onReply({ payload: JSON.stringify({ returnValue: true, accounts: accounts }) });
        }
        return { cancel: function() { bus.cancelled = bus.cancelled.concat([uri]); } };
    }

    // A later answer of subscribeToAccountsInfo: one account's status.
    function push(update) {
        update.returnValue = true;
        subscribers.forEach(function(f) { f({ payload: JSON.stringify(update) }); });
    }
}
