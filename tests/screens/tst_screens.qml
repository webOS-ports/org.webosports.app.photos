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
import QtTest

import LunaNext.Common 0.1

import "../mocks"
import "DemoFixtures.js" as Demo

/*
 * The README's screenshots: the app on the demo library of
 * tools/make-demo-library.sh, one screen after another, saved as
 * build/screenshots/<device>-<screen>.png. Not a test of the app (tst_ui is);
 * tools/screenshots-host.sh runs it once per device and makes the JPEGs in
 * docs/screenshots/ of them.
 */
TestCase {
    id: test
    name: "Screens"
    when: windowShown

    readonly property string root: path(Qt.resolvedUrl("../../build/demo"))
    readonly property string outDir: path(Qt.resolvedUrl("../../build/screenshots"))
    readonly property var devices: ({ tp: "touchpad", mindphone: "mindphone", q25: "q25" })
    readonly property string device: devices[Settings.profileName] || Settings.profileName
    property var app: null

    FakeBus {
        id: bus
    }

    function path(url) {
        return decodeURIComponent(url.toString().replace(/^file:\/\//, ""));
    }

    function shotOf(item, name) {
        var done = false;
        verify(item.grabToImage(function(result) {
            result.saveToFile(outDir + "/" + device + "-" + name + ".png");
            done = true;
        }), "grab " + name);
        tryVerify(function() { return done; }, 5000, "saved " + name);
    }

    function shot(name) {
        // Pictures load and the sheet slides on their own time
        wait(400);
        shotOf(app.contentItem, name);
    }

    function find(objectName) {
        function look(item) {
            if (!item)
                return null;
            if (item.objectName === objectName && item.visible !== false)
                return item;
            var kids = item.children || [];
            for (var i = 0; i < kids.length; i++) {
                var found = look(kids[i]);
                if (found)
                    return found;
            }
            if (item.contentItem && item.contentItem !== item)
                return look(item.contentItem);
            return null;
        }
        var it = look(app.contentItem);
        verify(it !== null, "found " + objectName);
        return it;
    }

    function tap(item) {
        if (item.parent)
            waitForItemPolished(item.parent);
        mouseClick(item);
        wait(20);
    }

    function init() {
        verify(Demo.albums().length > 0);
        var component = Qt.createComponent(Qt.resolvedUrl("../../qml/main.qml"));
        if (component.status === Component.Error)
            fail(component.errorString());
        app = component.createObject(null, {
            readDb: false,
            quitOnBack: false,
            engineSource: Qt.resolvedUrl("../mocks/FakeEngine.qml"),
            busCall: bus.call,
            busSubscribe: bus.subscribe
        });
        verify(app !== null, "main.qml made");
        app.prefs.slideshowInterval = 60000;
        app.prefs.exhibitionAlbums = [];
        app.prefs.exhibitionShuffle = false;
        Demo.ROOT = root;
        app.store.storageRoot = root + "/pictures";
        app.store.setEntries(Demo.albums(), Demo.images(), Demo.videos());
        app.requestActivate();
        wait(300);
    }

    function cleanup() {
        if (app) {
            app.destroy();
            app = null;
        }
        wait(50);
    }

    function test_library() {
        var list = find("albumList");
        tryVerify(function() { return list.count === 4; }, 2000, "four albums");
        shot("library");
        // Where the albums are below the libraries (the Q25), them too
        if (list.contentHeight > list.height + 1) {
            list.contentY = list.contentHeight - list.height;
            shot("albums");
        }
    }

    function test_album() {
        app.openAlbum("alb-nature");
        tryVerify(function() { return app.albumView.visible; });
        shot("album");
    }

    function test_select() {
        app.openAlbum("alb-nature");
        tap(find("selectButton"));
        var grid = find("itemGrid");
        mouseClick(grid.itemAtIndex(0));
        mouseClick(grid.itemAtIndex(2));
        tap(find("addToAlbumButton"));
        tryVerify(function() { return app.sheet.shown; });
        shot("add-to-album");
    }

    function test_picture() {
        app.openPicture("alb-nature", "img-n3", false);
        tryCompare(find("fullPicture"), "status", Image.Ready);
        shot("picture");
    }

    function test_slideshow() {
        app.openAlbum("alb-night");
        tap(find("albumSlideshowButton"));
        verify(app.slideshow.isOpen);
        wait(700);
        shot("slideshow");
    }

    function test_exhibition() {
        app.handleLaunch({ windowType: "dockModeWindow", dockMode: true });
        tryVerify(function() { return app.exhibition.item !== null; });
        var win = app.exhibition.item;
        waitForRendering(win.contentItem);
        wait(800);
        shotOf(win.contentItem, "exhibition");
    }
}
