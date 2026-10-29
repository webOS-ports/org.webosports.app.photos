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

import "mocks"
import "Fixtures.js" as Fixtures

/*
 * The app on a development machine, which run-desktop.sh one level up starts.
 * main.qml is made the way tst_ui makes it: db8 is not read, the library is
 * the one in Fixtures.js over the pictures in data/, and FakeBus answers for
 * com.palm.service.photos (a Dropbox account included), the accounts,
 * system and print services. Videos play with Qt's own engine.
 *
 * Every bus call and app launch is printed, so what a button would do on a
 * device can be read off the console.
 */
Item {
    id: desktop

    readonly property string root: decodeURIComponent(Qt.resolvedUrl("data").toString().replace(/^file:\/\//, ""))
    property var app: null

    FakeBus {
        id: bus
    }

    function call(uri, json, onReply, onError) {
        console.log("bus call " + uri + " " + json);
        return bus.call(uri, json, onReply, onError);
    }

    function subscribe(uri, json, onReply, onError) {
        console.log("bus subscribe " + uri + " " + json);
        return bus.subscribe(uri, json, onReply, onError);
    }

    Component.onCompleted: {
        var component = Qt.createComponent(Qt.resolvedUrl("../qml/main.qml"));
        if (component.status === Component.Error) {
            console.error(component.errorString());
            Qt.exit(1);
            return;
        }
        app = component.createObject(null, {
            readDb: false,
            quitOnBack: true,
            busCall: desktop.call,
            busSubscribe: desktop.subscribe
        });
        app.quitRequested.connect(Qt.quit);
        app.launched.connect(function(id, params) {
            console.log("launch " + id + " " + JSON.stringify(params));
        });
        app.closing.connect(Qt.quit);
        Fixtures.ROOT = root;
        app.store.storageRoot = root + "/pictures";
        app.store.setEntries(Fixtures.albums(), Fixtures.images(), Fixtures.videos());
        console.log("profile " + Settings.profileName + ", " + Settings.displayWidth + "x" + Settings.displayHeight
                    + ", grid unit " + Units.gu(1));
        app.visible = true;
        app.requestActivate();
    }
}
