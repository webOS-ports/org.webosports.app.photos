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

import "mocks"
import "Fixtures.js" as Fixtures
import "../qml/js/Library.js" as Library

/*
 * The app as a whole - qml/main.qml - with a stand-in bus
 * (mocks/FakeBus.qml: the photos service, accounts, systemservice, the
 * print manager) and video engine (mocks/FakeEngine.qml), over the library
 * of Fixtures.js, on one screen per run (see tools/run-tests.sh). Each
 * state is also saved as a picture in build/test-output/ui/ to look at.
 */
TestCase {
    id: test
    name: "Ui"
    when: windowShown

    readonly property string root: decodeURIComponent(Qt.resolvedUrl("data").toString().replace(/^file:\/\//, ""))
    readonly property string shotDir: decodeURIComponent(Qt.resolvedUrl("../build/test-output/ui").toString()
                                                         .replace(/^file:\/\//, ""))
    property var app: null
    property string profile: Settings.profileName
    property int quits: 0
    property var launches: []

    FakeBus {
        id: bus
    }

    function init_data() {
        return [{ tag: Settings.profileName + " " + Settings.displayWidth + "x" + Settings.displayHeight }];
    }

    function shot(name) {
        var done = false;
        var ok = app.contentItem.grabToImage(function(result) {
            result.saveToFile(shotDir + "/" + profile + "-" + name + ".png");
            done = true;
        });
        verify(ok, "grab " + name);
        tryVerify(function() { return done; }, 5000, "saved " + name);
    }

    // An open sheet slides in: wait until it has stopped, then check that it
    // ends inside the window and that its last choice can be reached. A shot
    // taken as soon as it is shown catches it half way, with its rows still
    // below the window.
    function verifySheetSettled(sheet) {
        var panel = findChild(sheet, "sheetPanel");
        var list = findChild(sheet, "sheetList");
        verify(panel !== null && list !== null, "the sheet's panel and list");
        tryVerify(function() {
            var bottom = panel.mapToItem(app.contentItem, 0, panel.height).y;
            return sheet.centered ? bottom < app.height : Math.abs(bottom - app.height) < 1;
        }, 2000, "the sheet slid into place");
        list.positionViewAtEnd();
        var last = findChild(list, "choice_" + (sheet.choices.length - 1));
        verify(last !== null, "the last choice is made");
        var top = last.mapToItem(app.contentItem, 0, 0).y;
        verify(top >= 0 && top + last.height <= app.height + 1,
               "the last choice is inside the window: " + top + " + " + last.height + " in " + app.height);
        list.positionViewAtBeginning();
    }

    function startApp(withService) {
        bus.calls = [];
        bus.cancelled = [];
        bus.subscribers = [];
        bus.replies = withService === false ? {
            "luna://com.palm.service.photos/getAccountsCapability": { busError: "no service" } } : {};
        var component = Qt.createComponent(Qt.resolvedUrl("../qml/main.qml"));
        if (component.status === Component.Error)
            fail(component.errorString());
        app = component.createObject(null, {
            readDb: false,
            quitOnBack: false,
            engineSource: Qt.resolvedUrl("mocks/FakeEngine.qml"),
            busCall: bus.call,
            busSubscribe: function(uri, json, r, e) { return withService === false && uri.indexOf("service.photos") >= 0
                                                      ? null : bus.subscribe(uri, json, r, e); }
        });
        verify(app !== null, "main.qml made");
        quits = 0;
        launches = [];
        app.quitRequested.connect(function() { test.quits++; });
        app.launched.connect(function(id, params) { test.launches = test.launches.concat([{ id: id, params: params }]); });
        app.prefs.slideshowInterval = 10000;
        app.prefs.exhibitionAlbums = [];
        app.prefs.exhibitionShuffle = false;
        Fixtures.ROOT = root;
        app.store.storageRoot = root + "/pictures";
        app.store.setEntries(Fixtures.albums(), Fixtures.images(), Fixtures.videos());
        app.requestActivate();
        // The action sheet's slide when the window takes its size.
        wait(300);
        return app;
    }

    function cleanup() {
        if (app) {
            app.destroy();
            app = null;
        }
        wait(50);
    }

    function findChild(item, objectName) {
        if (!item)
            return null;
        if (item.objectName === objectName && item.visible !== false)
            return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) {
            var found = findChild(kids[i], objectName);
            if (found)
                return found;
        }
        if (item.contentItem && item.contentItem !== item)
            return findChild(item.contentItem, objectName);
        return null;
    }

    function find(objectName) {
        var it = findChild(app.contentItem, objectName);
        verify(it !== null, "found " + objectName);
        return it;
    }

    function tap(item) {
        verify(item.visible, "visible: " + item.objectName);
        // A row below the fold of the panel is scrolled to first, as a
        // user would (the Q25's libraries fill its screen).
        for (var p = item.parent; p; p = p.parent)
            if (p.objectName === "albumList") {
                var before = p.contentY;
                p.ensureVisible(item);
                if (p.contentY !== before)
                    waitForRendering(p);
                break;
            }
        // A Row lays its buttons out again on the next polish.
        if (item.parent)
            waitForItemPolished(item.parent);
        mouseClick(item);
        wait(20);
    }

    function back() {
        keyClick(Qt.Key_Escape);
        wait(20);
    }

    // The album's cell or row, wherever it shows (the panel on a phone, the
    // grid on a tablet), scrolled to.
    function openAlbum(id) {
        app.openAlbum(id);
        tryVerify(function() { return app.albumView.visible && app.albumView.items.length >= 0; });
        wait(50);
    }

    function test_00_library() {
        startApp();
        verify(app.store.serviceAvailable);
        compare(app.store.libraries.length, 2);
        var list = find("albumList");
        // Five albums and a folder of videos; the hidden one not.
        tryVerify(function() { return list.count === 6; }, 2000, "six albums shown");
        if (app.wide) {
            var grid = find("albumGrid");
            compare(grid.count, 6);
            compare(find("libraryTitle").text, "All Photos & Videos");
        }
        shot("library");
    }

    function lastCall(uri) {
        var c = bus.callsTo(uri);
        verify(c.length > 0, uri + " called");
        return c[c.length - 1].params;
    }

    function photos(method) {
        return lastCall("luna://com.palm.service.photos/" + method);
    }

    // A choice of the action sheet, by its label.
    function choose(label) {
        tryVerify(function() { return app.sheet.shown; }, 2000, "the sheet is open for " + label);
        for (var i = 0; i < app.sheet.choices.length; i++) {
            if (app.sheet.choices[i].label === label) {
                app.sheet.choose(i);
                wait(250);
                return;
            }
        }
        fail("no choice " + label + " in " + JSON.stringify(app.sheet.choices.map(function(c) { return c.label; })));
    }

    // The dialog's button, tapped
    function accept(dialog) {
        verify(dialog.opened, "dialog open");
        tap(findChild(dialog, dialog === app.nameDialog ? "promptAcceptButton" : "confirmAcceptButton"));
    }
    function cancel(dialog) {
        verify(dialog.opened, "dialog open");
        tap(findChild(dialog, dialog === app.nameDialog ? "promptRejectButton" : "confirmRejectButton"));
        verify(!dialog.opened);
    }

    function test_01_sources() {
        startApp();
        tap(find("library-acc-dropbox"));
        compare(app.source, "acc-dropbox");
        compare(app.sourceTitle, "me@example.com");
        compare(photos("syncSingleAccount").accountId, "acc-dropbox", "picking an account syncs it");
        if (app.wide) {
            compare(find("albumGrid").count, 1);
            compare(find("libraryTitle").text, "me@example.com");
        } else {
            compare(find("albumList").count, 1, "a phone's panel lists the account's albums");
        }
        shot("source-dropbox");
        tap(find("library-local"));
        compare(app.libraryAlbums().length, 5, "the device's: all but the cloud album");
        tap(find("library-all"));
        compare(app.libraryAlbums().length, 6);
        // A sync shows a spinner on its library.
        bus.push({ accountId: "acc-dropbox", syncStatus: "syncing" });
        tryVerify(function() { return findChild(find("library-acc-dropbox"), "rowBusy") !== null; });
        bus.push({ accountId: "acc-dropbox", syncStatus: "idle", error: "Network down" });
        tryCompare(app, "notice", "Network down");
        compare(app.noticeTitle, "Syncing failed");
        compare(findChild(find("notice"), "noticeTitle").text, "Syncing failed", "shown in bold above");
        shot("sync-failed");
        tap(find("noticeCloseButton"));
        compare(app.notice, "");
    }

    function test_02_album() {
        startApp();
        tap(find("album-alb-holiday"));
        compare(app.albumId, "alb-holiday");
        verify(app.albumView.visible);
        compare(find("albumTitle").text, "Holiday");
        compare(find("albumCounts").text, "4 images, 1 video");
        var grid = find("itemGrid");
        compare(grid.count, 5);
        verify(find("albumSlideshowButton").visible);
        wait(200);
        shot("album");
        // The back gesture goes back to the library.
        back();
        compare(app.albumId, "");
        compare(quits, 0);
        back();
        compare(quits, 1, "then the app ends");
    }

    function test_03_rename() {
        startApp();
        openAlbum("alb-holiday");
        tap(find("renameArea"));
        verify(app.nameDialog.opened);
        compare(app.nameDialog.text, "Holiday");
        app.nameDialog.text = "   ";
        accept(app.nameDialog);
        verify(app.nameDialog.opened, "an empty name is not taken");
        app.nameDialog.text = "Summer 2026";
        shot("rename");
        accept(app.nameDialog);
        verify(!app.nameDialog.opened);
        compare(photos("renameAlbum"), { albumId: "alb-holiday", newName: "Summer 2026" });
        // Not the camera's album, not a cloud one.
        openAlbum("alb-camera");
        compare(find("albumTitle").text, "Photo roll");
        verify(!findChild(app.albumView, "renameArea").enabled);
        openAlbum("alb-dropbox");
        verify(!findChild(app.albumView, "renameArea").enabled);
    }

    function test_04_newAlbum() {
        startApp();
        tap(find("newAlbumButton"));
        verify(app.nameDialog.opened);
        compare(app.nameDialog.title, "New Album");
        // With the on-screen keyboard over the lower 45% of the window, the
        // field and both buttons stay above it.
        var root = app.contentItem;
        var kb = Math.round(root.height * 0.45);
        app.nameDialog.keyboardHeightForTest = kb;
        wait(20);
        ["promptField", "promptAcceptButton", "promptRejectButton"].forEach(function(name) {
            var it = findChild(app.nameDialog, name);
            var bottom = it.mapToItem(root, 0, it.height).y;
            verify(bottom <= root.height - kb, name + " ends at " + bottom + ", the keyboard starts at " + (root.height - kb));
        });
        shot("new-album-keyboard");
        app.nameDialog.keyboardHeightForTest = -1;
        app.nameDialog.text = "Trip";
        accept(app.nameDialog);
        compare(photos("createAlbum"), { name: "Trip", accountId: "local" });
        // From the app menu too.
        app.openAppMenu();
        verify(app.appMenu.opened);
        app.appMenu.close();
        // Without the photos service there is nothing to make it with.
        cleanup();
        startApp(false);
        verify(!app.store.serviceAvailable);
        verify(!find("newAlbumButton").enabled);
    }

    function test_05_emptyAlbum() {
        startApp();
        openAlbum("alb-empty");
        verify(find("emptyAlbum").visible);
        verify(find("deleteAlbumButton").visible);
        shot("empty-album");
        tap(find("deleteAlbumButton"));
        compare(app.confirm.title, "Delete Album");
        compare(app.confirm.message, "Are you sure you want to delete this album?");
        compare(app.confirm.acceptText, "Delete Album");
        accept(app.confirm);
        compare(photos("deleteAlbum"), ["alb-empty"]);
        // Add Photos: the library to pick from.
        tap(find("addPhotosButton"));
        var picker = find("pickerGrid");
        tryVerify(function() { return picker.count === 9; }, 2000, "the device's nine pictures and videos");
        mouseClick(picker.itemAtIndex(0));
        mouseClick(picker.itemAtIndex(2));
        shot("add-photos");
        tap(find("pickerDone"));
        var p = photos("addPhotos");
        compare(p.targetAlbum, "alb-empty");
        compare(p.specs[0].photos.length, 2);
        compare(p.specs[0].exclude, false);
        verify(!app.albumView.picking);
        // The camera's album has no Add Photos, a made-up one no Delete Album.
        app.store.setEntries(Fixtures.albums(), [], []);
        openAlbum("alb-camera");
        verify(findChild(app.albumView, "addPhotosButton") === null);
        app.store.setEntries([], [], [{ _id: "v", path: "/media/internal/Movies/a.mp4" }]);
    }

    function test_06_select() {
        startApp();
        openAlbum("alb-holiday");
        tap(find("selectButton"));
        verify(app.albumView.selecting);
        compare(find("selectedLabel").text, "0 Selected");
        var grid = find("itemGrid");
        mouseClick(grid.itemAtIndex(0));
        mouseClick(grid.itemAtIndex(1));
        compare(find("selectedLabel").text, "2 Selected");
        mouseClick(grid.itemAtIndex(1));
        compare(find("selectedLabel").text, "1 Selected");
        // The picked one framed in webOS's blue, the others dimmed
        var frame = findChild(grid.itemAtIndex(0), "pickedFrame");
        verify(frame !== null, "picked frame");
        tryCompare(frame, "status", Image.Ready);
        compare(findChild(grid.itemAtIndex(1), "pickedFrame"), null);
        shot("select");
        tap(find("selectAllButton"));
        compare(find("selectedLabel").text, "5 Selected");
        compare(find("selectAllButton").text, "Select None");
        mouseClick(grid.itemAtIndex(4));
        compare(find("selectedLabel").text, "4 Selected");
        // Delete what is picked: all but one, which the service is told so.
        tap(find("deleteSelectedButton"));
        compare(app.confirm.message, "Are you sure you want to delete these 4 items?");
        accept(app.confirm);
        compare(photos("deletePhotos").specs, [{ sourceAlbum: "alb-holiday", photos: ["img-h4"], exclude: true }]);
        verify(!app.albumView.selecting, "done selecting");
        // Nothing picked.
        tap(find("selectButton"));
        tap(find("deleteSelectedButton"));
        compare(app.confirm.title, "No items selected");
        compare(app.confirm.message, "No items selected for deletion.");
        compare(findChild(app.confirm, "confirmRejectButton"), null, "a notice, with one button");
        accept(app.confirm);
        tap(find("addToAlbumButton"));
        compare(app.confirm.message, "No items selected for adding to album.");
        accept(app.confirm);
        back();
        verify(!app.albumView.selecting, "the back gesture ends selecting");
        compare(app.albumId, "alb-holiday");
    }

    function test_07_addToAlbum() {
        startApp();
        openAlbum("alb-holiday");
        tap(find("selectButton"));
        var grid = find("itemGrid");
        mouseClick(grid.itemAtIndex(0));
        tap(find("addToAlbumButton"));
        tryVerify(function() { return app.sheet.shown; });
        var labels = app.sheet.choices.map(function(c) { return c.label; });
        compare(labels[0], "Create New Album");
        verify(labels.indexOf("Camera Uploads") >= 0, "a cloud album takes pictures");
        verify(labels.indexOf("Photo roll") < 0, "not the camera's");
        verify(labels.indexOf("Holiday") < 0, "not this one");
        verify(labels.indexOf("Movies") < 0, "not a folder of videos");
        verifySheetSettled(app.sheet);
        shot("add-to-album");
        choose("Camera Uploads");
        var p = photos("addPhotos");
        compare(p.targetAlbum, "alb-dropbox");
        compare(p.specs, [{ sourceAlbum: "alb-holiday", photos: ["img-h1"], exclude: false, targetAlbum: "alb-dropbox" }]);
        // A video goes to the device's albums only; a new album takes it too.
        mouseClick(grid.itemAtIndex(0));
        mouseClick(grid.itemAtIndex(1));
        tap(find("addToAlbumButton"));
        tryVerify(function() { return app.sheet.shown; });
        labels = app.sheet.choices.map(function(c) { return c.label; });
        verify(labels.indexOf("Camera Uploads") < 0);
        choose("Create New Album");
        verify(app.nameDialog.opened);
        app.nameDialog.text = "Best";
        accept(app.nameDialog);
        var c = photos("createAlbum");
        compare(c.name, "Best");
        compare(c.specs[0].photos.sort(), ["vid-h"]);
    }

    function test_08_cloudDelete() {
        startApp();
        openAlbum("alb-dropbox");
        tap(find("selectButton"));
        verify(find("deleteSelectedButton").visible, "the account can delete pictures");
        mouseClick(find("itemGrid").itemAtIndex(0));
        tap(find("deleteSelectedButton"));
        compare(app.confirm.message, "This permanently deletes the photo from your cloud account. It can't be undone.");
        shot("cloud-delete");
        cancel(app.confirm);
        verify(!app.confirm.opened);
        // A device album never says so.
        openAlbum("alb-camera");
        tap(find("selectButton"));
        mouseClick(find("itemGrid").itemAtIndex(1));
        tap(find("deleteSelectedButton"));
        compare(app.confirm.message, "Are you sure you want to delete this image?");
        cancel(app.confirm);
    }

    function test_09_picture() {
        startApp();
        openAlbum("alb-holiday");
        mouseClick(find("itemGrid").itemAtIndex(0));
        verify(app.picture.isOpen);
        compare(app.picture.current._id, "img-h1");
        verify(app.fullScreen);
        compare(app.windowProperties["LuneOS_fullscreen"], "true", "the card full screen");
        var controls = find("pictureControls");
        verify(controls.visible);
        verify(find("printButton").visible);
        verify(find("pictureSlideshowButton").visible);
        verify(!findChild(app.picture, "commentsButton"), "no comments on the device");
        tryCompare(find("fullPicture"), "status", Image.Ready);
        wait(100);
        shot("picture");
        // Swiped on: the next, newest first.
        var list = find("pictureList");
        list.currentIndex = 1;
        compare(app.picture.current._id, "vid-h");
        verify(app.picture.isVideo);
        compare(findChild(app.picture, "pictureSlideshowButton"), null, "no slideshow from a video");
        compare(findChild(app.picture, "printButton"), null);
        list.currentIndex = 2;
        // A tap hides the bar after a moment (not a double tap).
        var pic = findChild(list.currentItem, "fullPicture");
        mouseClick(pic);
        tryVerify(function() { return !app.picture.controlsShown; }, 1000);
        wait(500);
        mouseClick(pic);
        tryVerify(function() { return app.picture.controlsShown; }, 1000);
        wait(500);
        // A double tap zooms in, and the list stops swiping until it is out.
        mouseDoubleClickSequence(pic);
        tryVerify(function() { return list.currentItem.zoomed; }, 1000);
        verify(!list.interactive);
        mouseDoubleClickSequence(findChild(list.currentItem, "fullPicture"));
        tryVerify(function() { return !list.currentItem.zoomed; }, 1000);
        verify(app.picture.controlsShown, "a double tap does not toggle the bar");
        // The bar goes by itself.
        app.picture.showControls();
        tryVerify(function() { return !app.picture.controlsShown; }, 8000);
        back();
        verify(!app.picture.isOpen);
        verify(!app.fullScreen);
        compare(app.albumId, "alb-holiday");
    }

    function test_10_pictureActions() {
        startApp();
        app.openPicture("alb-holiday", "img-h1", false);
        // Share: Email, with the file.
        tap(find("shareButton"));
        compare(launches[0].id, "com.palm.app.email");
        compare(launches[0].params.attachments[0].path, root + "/pictures/Holiday/beach.jpg");
        compare(launches[0].params.attachments[0].name, "beach.jpg");
        // More: Set As Wallpaper.
        tap(find("moreButton"));
        tryVerify(function() { return app.sheet.shown; });
        compare(app.sheet.choices.map(function(c) { return c.label; }), ["Add to Album", "Set As Wallpaper"]);
        verifySheetSettled(app.sheet);
        shot("picture-more");
        choose("Set As Wallpaper");
        compare(lastCall("luna://com.webos.service.systemservice/wallpaper/importWallpaper").target,
                root + "/pictures/Holiday/beach.jpg");
        compare(lastCall("luna://com.webos.service.systemservice/setPreferences").wallpaper.wallpaperName, "beach.jpg");
        compare(find("toast").text, "Wallpaper set");
        // Print: the printers, then the job.
        tap(find("printButton"));
        tryVerify(function() { return app.sheet.shown; });
        compare(app.sheet.title, "Print");
        choose("Office Printer");
        var job = lastCall("luna://com.palm.printmgr/jobs/allAtOnce");
        compare(job.printerID, "p1");
        compare(job.pathNames, [root + "/pictures/Holiday/beach.jpg"]);
        compare(job.appName, "Photos");
        compare(find("toast").text, "Sent to the printer");
        bus.replies = { "luna://com.palm.printmgr/printers/listActive": { busError: "no service" } };
        tap(find("printButton"));
        compare(find("toast").text, "Printing is not available");
        bus.replies = {};
        // Add to Album from here.
        tap(find("moreButton"));
        choose("Add to Album");
        choose("Empty");
        compare(photos("addPhotos").specs, [{ sourceAlbum: "alb-holiday", photos: ["img-h1"], exclude: false, targetAlbum: "alb-empty" }]);
        // Delete: asked, then the next one shows when it goes.
        tap(find("deleteButton"));
        compare(app.confirm.message, "Are you sure you want to delete this image?");
        accept(app.confirm);
        compare(photos("deletePhotos").specs, [{ sourceAlbum: "alb-holiday", photos: ["img-h1"], exclude: false }]);
        var imgs = Fixtures.images().filter(function(i) { return i._id !== "img-h1"; });
        app.store.setEntries(Fixtures.albums(), imgs, Fixtures.videos());
        verify(app.picture.isOpen);
        compare(app.picture.current._id, "vid-h", "the next takes its place");
        // The whole album gone: back to the library.
        app.store.setEntries(Fixtures.albums().filter(function(a) { return a._id !== "alb-holiday"; }), imgs, []);
        verify(!app.picture.isOpen);
        compare(app.albumId, "");
    }

    function test_11_comments() {
        startApp();
        app.openPicture("alb-dropbox", "img-d1", false);
        verify(find("commentsButton").visible, "the account has comments");
        tap(find("commentsButton"));
        verify(find("commentsPanel").visible);
        compare(photos("getPhotoComments")._id, "img-d1");
        shot("comments");
        back();
        verify(!app.picture.commentsOpen, "back closes the comments first");
        verify(app.picture.isOpen);
        tap(find("deleteButton"));
        compare(app.confirm.message, "This permanently deletes the photo from your cloud account. It can't be undone.");
        cancel(app.confirm);
    }

    function test_12_video() {
        startApp();
        openAlbum("alb-holiday");
        // Opened from the grid, a video starts, where it was left (30 s).
        mouseClick(find("itemGrid").itemAtIndex(1));
        tryVerify(function() { return app.picture.playing; }, 2000);
        var engine = app.picture.video.engine;
        compare(engine.seeks, [30000]);
        verify(app.keepScreenOn);
        compare(lastCall("luna://com.palm.display/control/setProperty"),
                { requestBlock: true, client: "org.webosports.app.photos" }, "the display held on");
        compare(String(engine.source), Library.fileUrl(root + "/pictures/Holiday/clip.mp4"));
        engine.advance(5000);
        compare(find("timePlayed").text, "0:35");
        compare(find("timeLeft").text, "-1:00");
        shot("video");
        tap(find("fitButton"));
        verify(engine.fill);
        tap(find("playPauseButton"));
        verify(!app.picture.playing);
        verify(!app.keepScreenOn);
        compare(bus.cancelled, ["luna://com.palm.display/control/setProperty"], "and let go");
        compare(app.store.item("vid-h").lastPlayTime, 35, "the place is kept on pause");
        tap(find("playPauseButton"));
        verify(app.picture.playing);
        // The card going to the background pauses it.
        app.picture.pause();
        verify(!app.picture.playing);
        // Swiped away: stopped and its engine let go.
        tap(find("playPauseButton"));
        find("pictureList").currentIndex = 0;
        tryVerify(function() { return app.picture.video === null; });
        verify(!app.keepScreenOn);
        // Swiped to, it waits for its play button.
        find("pictureList").currentIndex = 1;
        tryVerify(function() { return app.picture.video !== null; });
        verify(!app.picture.playing);
        // The pictures are PNGs drawn by tools/make-images.sh, and there
        var big = find("bigPlay");
        tryCompare(big, "status", Image.Ready);
        verify(/\/qml\/images\/[123]x\/playIcon\.png$/.test(String(big.source)), String(big.source));
        var key = find("playPauseButton");
        var keyImage = findChild(key, "iconButtonImage");
        tryCompare(keyImage, "status", Image.Ready);
        var drawn = key.image;
        verify(String(keyImage.source).endsWith("/" + drawn + ".png"), String(keyImage.source));
        // Held, a key shows its pressed state, the legacy glow
        mousePress(key);
        verify(String(keyImage.source).endsWith("/" + drawn + "-pressed.png"), String(keyImage.source));
        tryCompare(keyImage, "status", Image.Ready);
        // Let go, it plays, and the key shows pause, not held
        mouseRelease(key);
        tryVerify(function() { return app.picture.playing; });
        verify(String(keyImage.source).endsWith("/icn-pause.png"), String(keyImage.source));
        app.picture.pause();
        verify(!app.picture.playing);
        tap(find("bigPlay"));
        tryVerify(function() { return app.picture.playing; });
        // At the end, it starts from the beginning next time.
        app.picture.video.engine.finish();
        compare(app.store.item("vid-h").lastPlayTime, 0);
    }

    function test_13_slideshow() {
        startApp();
        openAlbum("alb-holiday");
        tap(find("albumSlideshowButton"));
        var show = app.slideshow;
        verify(show.isOpen);
        compare(show.playlist.map(function(i) { return i._id; }), ["img-h4", "img-h3", "img-h2", "img-h1"],
                "the pictures only, oldest first");
        verify(show.running);
        verify(app.keepScreenOn);
        show.go(1);
        compare(show.currentItem._id, "img-h3");
        show.go(-1);
        show.go(-1);
        compare(show.currentItem._id, "img-h1", "round at the ends");
        // A photo whose file changes under the slideshow (its whole picture came down, or
        // went back to the cloud): shown from where it is now
        var moved = Fixtures.images().map(function(i) { if (i._id === "img-h1") i.path = i.path.replace("Holiday/", "Holiday/whole-"); return i; });
        app.store.setEntries(Fixtures.albums(), moved, Fixtures.videos());
        verify(find("slideFront").source.toString().indexOf("Holiday/whole-") > 0, find("slideFront").source);
        show.go(1);
        show.go(-1);
        verify(find("slideFront").source.toString().indexOf("Holiday/whole-") > 0, "and when it comes round again");
        app.store.setEntries(Fixtures.albums(), Fixtures.images(), Fixtures.videos());
        verify(find("slideFront").source.toString().indexOf("Holiday/whole-") < 0);
        wait(700);
        shot("slideshow");
        // A swipe goes on, a tap ends it.
        var area = show;
        mouseDrag(area, area.width * 0.7, area.height / 2, -area.width * 0.4, 0);
        compare(show.currentItem._id, "img-h4");
        mouseClick(area);
        verify(!show.isOpen);
        // Timed: on by itself.
        app.prefs.slideshowInterval = 300;
        tap(find("albumSlideshowButton"));
        tryVerify(function() { return show.index === 1; }, 2000);
        back();
        verify(!show.isOpen);
        // From a picture, it starts there, and ends on the one showing.
        app.openPicture("alb-holiday", "img-h2", false);
        app.prefs.slideshowInterval = 10000;
        tap(find("pictureSlideshowButton"));
        compare(show.currentItem._id, "img-h2");
        show.go(1);
        mouseClick(show);
        verify(app.picture.isOpen);
        compare(app.picture.current._id, "img-h1");
        // An album without pictures has nothing to show.
        app.picture.close();
        app.startSlideshow(["video:" + root + "/Movies"]);
        verify(!show.isOpen);
        compare(app.notice, "Please download more photos to play slideshow.");
        // The library's: every album with pictures.
        app.notice = "";
        app.startSlideshow(Library.slideshowAlbums(app.libraryAlbums(), []));
        compare(show.playlist.length, 7);
        show.stop();
    }

    function test_14_exhibition() {
        startApp();
        app.handleLaunch({ windowType: "dockModeWindow", dockMode: true });
        tryVerify(function() { return app.exhibition.item !== null; });
        var win = app.exhibition.item;
        var show = win.slideshow;
        waitForRendering(win.contentItem);
        // The new window's sheet slides out of the way first (see startApp).
        wait(400);
        verify(show.isOpen);
        compare(show.playlist.length, 7);
        mouseClick(show);
        verify(show.isOpen, "a tap does not end it");
        verify(show.controlsShown);
        wait(100);
        var grab = false;
        win.contentItem.grabToImage(function(r) { r.saveToFile(shotDir + "/" + profile + "-exhibition.png"); grab = true; });
        tryVerify(function() { return grab; });
        // Pause and play.
        mouseClick(findChild(win.contentItem, "slideshowPlayButton"));
        verify(show.paused);
        mouseClick(findChild(win.contentItem, "slideshowPlayButton"));
        verify(!show.paused);
        // How long each picture stays.
        mouseClick(findChild(win.contentItem, "timerButton"));
        var sheet = findChild(win.contentItem, "slideshowSheet");
        tryVerify(function() { return sheet.shown; });
        compare(sheet.choices.length, 7);
        sheet.choose(0);
        compare(app.prefs.slideshowInterval, 5000);
        wait(400);
        // Shuffled, with the given random source.
        show.random = function() { return 0; };
        mouseClick(findChild(win.contentItem, "shuffleButton"));
        verify(show.shuffle);
        verify(app.prefs.exhibitionShuffle);
        compare(show.playlist.length, 7);
        // One album only.
        show.chooseAlbums();
        tryVerify(function() { return sheet.shown; });
        var at = -1;
        for (var i = 0; i < sheet.choices.length; i++)
            if (sheet.choices[i].key === "alb-camera")
                at = i;
        sheet.choose(at);
        compare(app.prefs.exhibitionAlbums, ["alb-camera"]);
        tryVerify(function() { return sheet.shown; });
        sheet.choose(sheet.choices.length - 1);
        compare(show.playlist.length, 2);
        win.visible = false;
        tryVerify(function() { return !app.exhibitionWanted; });
    }

    function test_15_launch() {
        startApp();
        app.handleLaunch({ albumID: "alb-holiday" });
        compare(app.albumId, "alb-holiday");
        verify(!app.picture.isOpen);
        app.handleLaunch({ albumID: "alb-holiday", pictureID: "img-h2" });
        verify(app.picture.isOpen);
        compare(app.picture.current._id, "img-h2");
        back();
        compare(app.albumId, "alb-holiday", "back goes to its album");
        // By file, as Files opens a picture.
        app.handleLaunch({ target: "file://" + root + "/pictures/DCIM/2026-10-08-05-37-19.jpg" });
        verify(app.picture.isOpen);
        compare(app.picture.current._id, "img-c2");
        compare(app.albumId, "alb-camera");
        app.picture.close();
        // Not known yet: opened once the library has it.
        app.store.setEntries([], [], []);
        app.handleLaunch({ albumID: "alb-holiday", pictureID: "img-h3" });
        verify(!app.picture.isOpen);
        app.store.setEntries(Fixtures.albums(), Fixtures.images(), Fixtures.videos());
        verify(app.picture.isOpen);
        compare(app.picture.current._id, "img-h3");
    }

    function test_16_appMenu() {
        startApp();
        app.openAppMenu();
        verify(app.appMenu.opened);
        var labels = [];
        for (var i = 0; i < app.appMenu.count; i++)
            labels.push(app.appMenu.itemAt(i).text);
        compare(labels, ["New Album", "Sync Now", "Keep on Device", "Preferences & Accounts"]);
        verify(app.appMenu.itemAt(2).visible && !app.appMenu.itemAt(2).enabled, "Keep on Device: shown, greyed out with no cloud album open");
        // At the window's top left, over the app, as the shell's app menu
        compare(app.appMenu.parent, app.contentItem);
        var at = app.appMenu.contentItem.mapToItem(app.contentItem, 0, 0);
        verify(at.x < Units.gu(4) && at.y < Units.gu(4), "at the top left: " + at.x + "," + at.y);
        shot("app-menu");
        app.appMenu.itemAt(3).triggered();
        verify(app.preferencesView.isOpen, "Preferences & Accounts: the app's own page");
        compare(app.preferencesView.info, null, "an answer without the numbers: taken as none");
        app.preferencesView.close();
        app.appMenu.itemAt(1).triggered();
        verify(bus.callsTo("luna://com.palm.service.photos/remoteSyncAlbums").length > 0);
        app.appMenu.close();
        // Not over a picture.
        app.openPicture("alb-holiday", "img-h1", false);
        app.openAppMenu();
        verify(!app.appMenu.opened);
    }

    function test_17_states() {
        startApp();
        app.store.setEntries([], [], []);
        tryCompare(find("panelStatus"), "text", "No albums");
        shot("no-albums");
        app.store.status = "denied";
        compare(find("panelStatus").text, "Photos & Videos was not allowed to see your pictures.");
    }

    function test_18_brokenThumbnail() {
        startApp();
        openAlbum("alb-holiday");
        // broken.jpg does not load: new thumbnails are asked for, once.
        tryVerify(function() { return bus.callsTo("luna://com.palm.service.photos/generateThumbnails").length >= 2; }, 4000);
    }

    // A PiGallery2 account's folders: the library shows the top one, an
    // album its sub-albums (the whole page, or a row above its pictures),
    // and back goes up one album at a time.
    function test_20_cloudPreviews() {
        startApp();
        // The Dropbox photo with only its preview here
        var images = Fixtures.images().map(function(i) {
            if (i._id === "img-d1")
                i.original = "remote";
            return i;
        });
        app.store.setEntries(Fixtures.albums(), images, Fixtures.videos());
        var fetched = root + "/pictures/Holiday/forest.png";
        bus.replies = { "luna://com.palm.service.photos/fetchOriginal": { returnValue: true, path: fetched } };

        // A cloud album not opened yet: its count from the service, a spinner while it lists
        var albums = Fixtures.albums().concat([{ _id: "alb-unopened", path: "/media/internal/.photosApp/com.palm.dropbox/me/Trips",
            name: "Trips", accountId: "acc-dropbox", type: "com.palm.dropbox", aid: "/Trips", showAlbum: true, listed: false,
            modifiedTime: 1791400001, total: { images: 12 } }]);
        app.store.setEntries(albums, images, Fixtures.videos());
        app.openAlbum("alb-unopened");
        compare(lastCall("luna://com.palm.service.photos/syncAlbum"), { albumId: "alb-unopened" });
        compare(find("albumCounts").text, "12 images");
        verify(find("albumAwaiting").running);
        compare(findChild(app.albumView, "emptyAlbum"), null, "not shown as empty");
        // While it is being listed: a cell for each picture it has, filled as they come
        app.closeAlbum();
        albums[albums.length - 1].coverPath = root + "/pictures/Holiday/forest.png";
        app.store.setEntries(albums, images, Fixtures.videos());
        bus.replies = { "luna://com.palm.service.photos/fetchOriginal": { returnValue: true, path: fetched },
                        "luna://com.palm.service.photos/syncAlbum": null };
        app.openAlbum("alb-unopened");
        tryCompare(find("itemGrid"), "count", 12);
        verify(find("item-pending:alb-unopened:0"));
        compare(findChild(app.albumView, "albumAwaiting"), null, "cells, not the spinner");
        bus.calls = [];
        tap(find("item-pending:alb-unopened:0"));
        verify(!app.picture.isOpen, "a cell with no picture yet opens nothing");
        var arrived = [{ _id: "img-u1", albumId: "alb-unopened", path: root + "/pictures/Holiday/beach.jpg", mediaType: "image",
                         type: "com.palm.dropbox", accountId: "acc-dropbox", createdTime: 1791400002 }];
        app.store.setEntries(albums, images.concat(arrived), Fixtures.videos());
        tryCompare(find("itemGrid"), "count", 12);
        verify(find("item-img-u1"));
        compare(find("albumCounts").text, "1 image");
        app.store._setLoading("alb-unopened", false);
        tryCompare(find("itemGrid"), "count", 1, 1000, "listed: only what came");
        app.closeAlbum();
        bus.replies = { "luna://com.palm.service.photos/fetchOriginal": { returnValue: true, path: fetched } };
        app.store.setEntries(albums, images, Fixtures.videos());
        // One that cannot be listed: the user is told
        bus.replies["luna://com.palm.service.photos/syncAlbum"] = { returnValue: false, errorText: "offline" };
        app.openAlbum("alb-dropbox");
        compare(app.noticeTitle, "Could not load the album");
        // An older service, which has no syncAlbum, has every photo here already: no failure
        app.noticeTitle = "";
        app.closeAlbum();
        bus.replies["luna://com.palm.service.photos/syncAlbum"] = { returnValue: false, errorCode: -1,
                                                                   errorText: "Unknown method syncAlbum" };
        app.openAlbum("alb-dropbox");
        compare(app.noticeTitle, "");
        app.closeAlbum();
        delete bus.replies["luna://com.palm.service.photos/syncAlbum"];
        bus.calls = [];

        // Opening a cloud album asks for its photos, once
        app.closeAlbum();
        app.openAlbum("alb-dropbox");
        compare(lastCall("luna://com.palm.service.photos/syncAlbum"), { albumId: "alb-dropbox" });
        app.store.setEntries(Fixtures.albums(), images, Fixtures.videos());
        compare(bus.callsTo("luna://com.palm.service.photos/syncAlbum").length, 1, "not again as the library changes");
        app.openAlbum("alb-holiday");
        compare(bus.callsTo("luna://com.palm.service.photos/syncAlbum").length, 1, "a device album: none");

        app.openPicture("alb-dropbox", "img-d1", false);
        compare(bus.callsTo("luna://com.palm.service.photos/generateImgForBigView").length, 0, "not at once");
        tryVerify(function() { return bus.callsTo("luna://com.palm.service.photos/generateImgForBigView").length === 1; }, 2000);
        compare(lastCall("luna://com.palm.service.photos/generateImgForBigView"), { _id: "img-d1" });
        verify(find("originalBusy").running, "the whole picture is on its way");
        // Share, print and the wallpaper: the whole picture, fetched first
        tap(find("shareButton"));
        compare(lastCall("luna://com.palm.service.photos/fetchOriginal"), { _id: "img-d1" });
        compare(launches[0].params.attachments[0].path, fetched);
        tap(find("printButton"));
        choose("Office Printer");
        compare(lastCall("luna://com.palm.printmgr/jobs/allAtOnce").pathNames, [fetched]);
        tap(find("moreButton"));
        choose("Set As Wallpaper");
        compare(lastCall("luna://com.webos.service.systemservice/wallpaper/importWallpaper").target, fetched);
        compare(bus.callsTo("luna://com.palm.service.photos/fetchOriginal").length, 3);

        // It cannot be fetched: nothing is sent, and the user is told
        bus.replies = { "luna://com.palm.service.photos/fetchOriginal": { returnValue: false, errorText: "offline" } };
        var sent = launches.length;
        tap(find("shareButton"));
        compare(launches.length, sent);
        compare(app.noticeTitle, "Could not download the picture");
    }

    function test_19_subAlbums() {
        startApp();
        app.store.setEntries(Fixtures.albums().concat(Fixtures.treeAlbums()),
                             Fixtures.images().concat(Fixtures.treeImages()), Fixtures.videos());
        var list = find("albumList");
        tryVerify(function() { return list.count === 7; }, 2000, "the six, and Holidays without its sub-albums");
        verify(findChild(app.contentItem, "album-alb-pg-holidays") !== null);
        compare(findChild(app.contentItem, "album-alb-pg-italy"), null);
        if (app.wide) {
            var grid = find("albumGrid");
            compare(grid.count, 7);
        }

        // The panel lays its rows out again first
        waitForItemPolished(find("album-alb-pg-holidays").parent);
        tap(find("album-alb-pg-holidays"));
        compare(app.albumId, "alb-pg-holidays");
        compare(find("albumCounts").text, "2 albums");
        var subs = find("subAlbumGrid");
        compare(subs.count, 2);
        compare(findChild(app.albumView, "itemGrid"), null, "no pictures of its own");
        compare(findChild(app.albumView, "emptyAlbum"), null, "and not empty");
        compare(findChild(app.albumView, "selectButton"), null, "nothing to select");
        verify(find("albumSlideshowButton").visible, "its sub-albums' pictures play");
        wait(200);
        shot("subalbums");

        tap(find("albumCell-alb-pg-italy"));
        compare(app.albumId, "alb-pg-italy");
        compare(find("albumTitle").text, "2025 Italy");
        compare(find("albumCounts").text, "1 image, 1 album");
        var row = find("subAlbumRow");
        compare(row.count, 1);
        compare(find("itemGrid").count, 1);
        verify(find("albumBackButton").visible, "a way back to Holidays, on a tablet too");
        if (app.wide)
            verify(find("album-alb-pg-holidays").selected, "the panel shows where it is");
        wait(200);
        shot("subalbum-row");

        // Selecting hides the row: only the pictures are picked
        tap(find("selectButton"));
        compare(findChild(app.albumView, "subAlbumRow"), null);
        tap(find("cancelSelectButton"));
        verify(find("subAlbumRow").visible);

        tap(find("albumCell-alb-pg-rome"));
        compare(app.albumId, "alb-pg-rome");
        compare(findChild(app.albumView, "subAlbumRow"), null);
        back();
        compare(app.albumId, "alb-pg-italy");
        tap(find("albumBackButton"));
        compare(app.albumId, "alb-pg-holidays");

        tap(find("albumSlideshowButton"));
        tryVerify(function() { return app.slideshow.isOpen; });
        compare(app.slideshow.playlist.map(function(i) { return i._id; }), ["img-pg-italy", "img-pg-rome", "img-pg-alps"]);
        back();
        tryVerify(function() { return !app.slideshow.isOpen; });

        back();
        compare(app.albumId, "", "out of the top album: the library");
        compare(quits, 0);

        // A sub-album that goes (its folder deleted on the server) while open: back to the library
        app.openAlbum("alb-pg-rome");
        app.store.setEntries(Fixtures.albums().concat(Fixtures.treeAlbums().slice(0, 2)),
                             Fixtures.images().concat(Fixtures.treeImages()), Fixtures.videos());
        tryCompare(app, "albumId", "");

        // A sub-album in the row with pictures and albums of its own: each on its line, and
        // the row tall enough for both (one line was cut off: "5 images, 1 albu...")
        var trastevere = { _id: "alb-pg-trastevere", path: "/media/internal/.photosApp/com.palm.pigallery2/jane@gallery/Trastevere",
                           name: "Trastevere", accountId: "acc-pg2", type: "com.palm.pigallery2", aid: "Trastevere",
                           parentId: "alb-pg-rome", showAlbum: true, modifiedTime: 1791600004, total: { images: 1 } };
        var tImage = { _id: "img-pg-trastevere", albumId: "alb-pg-trastevere", path: Fixtures.treeImages()[0].path,
                       mediaType: "image", type: "com.palm.pigallery2", accountId: "acc-pg2", createdTime: 1791600040,
                       appCacheComplete: true, "com.palm.pigallery2": { pid: "img-pg-trastevere" } };
        app.store.setEntries(Fixtures.albums().concat(Fixtures.treeAlbums(), [trastevere]),
                             Fixtures.images().concat(Fixtures.treeImages(), [tImage]), Fixtures.videos());
        app.openAlbum("alb-pg-italy");
        var cellRow = find("subAlbumRow");
        var romeCell = find("albumCell-alb-pg-rome");
        var count = findChild(romeCell, "albumCellCount");
        compare(count.text, "1 image\n1 album");
        compare(count.lineCount, 2);
        verify(!count.truncated, "nothing cut off");
        verify(count.mapToItem(cellRow, 0, count.height).y <= cellRow.height + 0.5, "inside the row");
        wait(200);
        shot("subalbum-row-two-lines");
    }

    // The bottom edge of an item, in the window
    function bottomOf(item) {
        return item.mapToItem(app.contentItem, 0, item.height).y;
    }

    // Two rows of albums and of pictures on every screen: a phone on its side
    // showed one and a bit, the cells sized by the width alone. There the
    // bottom bars go, their keys in the header instead, and the title stays whole.
    function test_20_rows() {
        startApp();
        var panel = find("libraryPanel");
        var list = find("albumList");
        tryVerify(function() { return list.count === 6; }, 2000, "six albums shown");
        verify(!find("panelTitle").truncated, "the panel's title is not cut off: " + find("panelTitle").width);
        if (app.compact) {
            fuzzyCompare(bottomOf(list), bottomOf(panel), 1, "no bar below the panel's list");
            // New Album on the ALL ALBUMS heading, out of the panel's header
            verify(find("newAlbumButton").mapToItem(panel, 0, 0).y >= app.headerHeight, "New Album below the header");
        }
        if (app.wide) {
            var albums = find("albumGrid");
            verify(albums.height >= 2 * albums.cellHeight,
                   "two rows of albums: " + albums.height + " for cells of " + albums.cellHeight);
            if (app.compact)
                fuzzyCompare(bottomOf(albums), bottomOf(albums.parent), 1, "no bar below the albums");
        }

        openAlbum("alb-holiday");
        var grid = find("itemGrid");
        verify(grid.height >= 2 * grid.cellHeight,
               "two rows of pictures: " + grid.height + " for cells of " + grid.cellHeight);
        if (!app.compact)
            return;
        fuzzyCompare(bottomOf(grid), bottomOf(app.albumView), 1, "no bar below the pictures");
        var slideshow = find("albumSlideshowButton");
        verify(slideshow.mapToItem(app.albumView, 0, 0).y < app.headerHeight, "Slideshow in the header");
        // The album's title and, picking, the count stop short of the keys
        var title = find("albumTitle");
        var keysLeft = find("selectButton").mapToItem(app.contentItem, 0, 0).x;
        verify(title.mapToItem(app.contentItem, title.width, 0).x <= keysLeft, "the title ends before the keys");
        tap(find("selectButton"));
        var picked = find("selectedLabel");
        keysLeft = find("addToAlbumButton").mapToItem(app.contentItem, 0, 0).x;
        verify(picked.mapToItem(app.contentItem, picked.contentWidth, 0).x <= keysLeft,
               "\"0 Selected\" ends before Add to Album");
    }

    function test_21_storage() {
        startApp();
        var MB = 1024 * 1024;
        var info = { returnValue: true, capBytes: 200 * MB, capChoices: [100 * MB, 200 * MB, 500 * MB, 1024 * MB, 2048 * MB],
                     capNowBytes: 200 * MB, floorBytes: 1024 * MB, freeBytes: 12.5 * 1024 * MB, expireDays: 30,
                     originals: { count: 12, bytes: 41.3 * MB }, kept: { albums: 1, count: 13, bytes: 45.6 * MB }, otherBytes: 3 * MB };
        bus.replies = { "luna://com.palm.service.photos/getStorage": info,
                        "luna://com.palm.service.photos/setStorage": function(p) {
                            var r = JSON.parse(JSON.stringify(info)); r.capBytes = p.capBytes; r.capNowBytes = p.capBytes; return r; },
                        "luna://com.palm.service.photos/clearDownloads": function() {
                            var r = JSON.parse(JSON.stringify(info)); r.originals = { count: 0, bytes: 0 };
                            r.cleared = { albums: 3, photos: 39 }; return r; } };
        app.openAppMenu();
        app.appMenu.itemAt(3).triggered();
        app.appMenu.close();
        verify(app.preferencesView.isOpen);
        compare(lastCall("luna://com.palm.service.photos/getStorage"), {});
        compare(find("storagePictures").text, "41 MB of 200 MB");
        compare(find("storageKept").text, "1 album, 46 MB");
        compare(find("storageOther").text, "3 MB");
        compare(find("storageFree").text, "13 GB");
        compare(find("storageCapButton").text, "Keep up to 200 MB");
        shot("preferences");
        // The size: one of those offered
        tap(find("storageCapButton"));
        tryVerify(function() { return app.sheet.shown; }, 2000);
        compare(app.sheet.choices.map(function(c) { return c.label; }), ["100 MB", "200 MB", "500 MB", "1 GB", "2 GB"]);
        verify(app.sheet.choices[1].checked);
        choose("500 MB");
        compare(lastCall("luna://com.palm.service.photos/setStorage"), { capBytes: 500 * MB });
        compare(find("storageCapButton").text, "Keep up to 500 MB");
        compare(find("storagePictures").text, "41 MB of 500 MB");
        // Clearing: asked first (scrolled to, on a small screen)
        var flick = find("preferencesFlick");
        flick.contentY = Math.max(0, flick.contentHeight - flick.height);
        wait(50);
        tap(find("clearDownloadsButton"));
        cancel(app.confirm);
        compare(bus.callsTo("luna://com.palm.service.photos/clearDownloads").length, 0);
        var clearReply = bus.replies["luna://com.palm.service.photos/clearDownloads"];
        bus.replies["luna://com.palm.service.photos/clearDownloads"] = null;     // still running
        tap(find("clearDownloadsButton"));
        accept(app.confirm);
        compare(bus.callsTo("luna://com.palm.service.photos/clearDownloads").length, 1);
        verify(app.preferencesView.clearing);
        verify(find("clearingBusy").running);
        verify(!find("clearDownloadsButton").enabled, "not twice at once");
        app.preferencesView.clearing = false;
        bus.replies["luna://com.palm.service.photos/clearDownloads"] = clearReply;
        tap(find("clearDownloadsButton"));
        accept(app.confirm);
        verify(!app.preferencesView.clearing, "answered: done");
        compare(find("storagePictures").text, "0 MB of 200 MB");
        // The accounts, from here
        tap(find("accountsButton"));
        compare(launches[launches.length - 1].id, "com.palm.app.accounts");
        // Back closes it; a service that cannot say: told so
        keyClick(Qt.Key_Escape);
        verify(!app.preferencesView.isOpen);
        bus.replies["luna://com.palm.service.photos/getStorage"] = { returnValue: false, errorText: "Unknown method getStorage" };
        app.preferencesView.open();
        verify(find("storageUnavailable"));
        compare(findChild(app.preferencesView, "clearDownloadsButton"), null);
        app.preferencesView.close();

        // Keep on Device: a cloud album open
        app.openAlbum("alb-holiday");
        app.openAppMenu();
        verify(app.appMenu.itemAt(2).visible, "the menu is static");
        verify(!app.appMenu.itemAt(2).enabled, "a device album: greyed out");
        app.appMenu.close();
        bus.replies["luna://com.palm.service.photos/keepAlbum"] = null;
        app.openAlbum("alb-dropbox");
        app.openAppMenu();
        verify(app.appMenu.itemAt(2).enabled);
        verify(!app.appMenu.itemAt(2).checked);
        app.appMenu.itemAt(2).triggered();
        app.appMenu.close();
        compare(lastCall("luna://com.palm.service.photos/keepAlbum"), { albumId: "alb-dropbox", keep: true });
        // As webOS's sync: a banner when it starts...
        var toast = lastCall("luna://com.webos.notification/createToast");
        compare(toast.message, "Camera Uploads: Downloading album...");
        compare(toast.sourceId, "org.webosports.app.photos");
        compare(toast.type, "light", "goes by: not kept in the notification list");
        compare(toast.iconUrl, app.syncGlyph);
        compare(app.notice, "", "a banner, not the in-app notice");
        // ...a dashboard while it runs: the account's icon, the album, what it does
        var dash = findChild(app, "keepDashboardLoader");
        verify(dash.active);
        compare(dash.item.title, "Camera Uploads");
        compare(dash.item.count, 1);
        compare(dash.item.smallIcon, app.syncGlyph);
        compare(dash.item.icon.toString(), app.libraryIcon({ accountId: "acc-dropbox", templateId: (app.store.accounts["acc-dropbox"] || {}).templateId }).toString());
        compare(findChild(dash.item, "keepDashboardText").text, "Downloading album...");
        // Two at once: the latest, and how many
        var other = { _id: "alb-other", title: "Other", accountId: "acc-dropbox" };
        app.keepStarted(other);
        compare(dash.item.count, 2);
        compare(dash.item.title, "Other");
        verify(findChild(dash.item, "keepDashboardCount").visible);
        app.keepStarted(other);
        compare(dash.item.count, 2, "the same album once");
        var banners = bus.callsTo("luna://com.webos.notification/createToast").length;
        app.keepEnded(other, null);
        compare(dash.item.count, 1);
        compare(dash.item.title, "Camera Uploads");
        compare(bus.callsTo("luna://com.webos.notification/createToast").length, banners, "failed: the store tells, no banner");
        // A tap opens the album
        dash.item.tapped();
        compare(launches[launches.length - 1].id, "org.webosports.app.photos");
        compare(launches[launches.length - 1].params, { albumID: "alb-dropbox" });
        // Swiped away: away while this one comes down
        dash.item.dismissed();
        wait(0);
        verify(!dash.active);
        // ...a banner when it is done, and the dashboard gone
        app.keepEnded(app.store.album("alb-dropbox"), { keep: true, photos: 2, fetched: 2, failed: 0 });
        compare(lastCall("luna://com.webos.notification/createToast").message, "Camera Uploads: Download completed");
        verify(!app.keepDashboardDismissed, "the next one has its dashboard again");
        verify(!dash.active);
        // Let go of: no banner
        var albums = Fixtures.albums().map(function(a) { if (a._id === "alb-dropbox") a.keep = true; return a; });
        app.store.setEntries(albums, Fixtures.images(), Fixtures.videos());
        bus.replies["luna://com.palm.service.photos/keepAlbum"] = { returnValue: true, keep: false };
        bus.calls = bus.calls.filter(function(c) { return c.uri !== "luna://com.webos.notification/createToast"; });
        app.toggleKeep(app.store.album("alb-dropbox"));
        compare(lastCall("luna://com.palm.service.photos/keepAlbum"), { albumId: "alb-dropbox", keep: false }, "kept: no longer");
        compare(bus.callsTo("luna://com.webos.notification/createToast").length, 0, "no banner for that");
        verify(!dash.active);
        // Some could not come down: how many did
        app.store.setEntries(Fixtures.albums(), Fixtures.images(), Fixtures.videos());
        bus.replies["luna://com.palm.service.photos/keepAlbum"] = { returnValue: true, keep: true, photos: 13, fetched: 11, failed: 2 };
        app.toggleKeep(app.store.album("alb-dropbox"));
        compare(lastCall("luna://com.palm.service.photos/keepAlbum"), { albumId: "alb-dropbox", keep: true });
        compare(lastCall("luna://com.webos.notification/createToast").message, "Camera Uploads: 11 of 13 pictures downloaded");
        verify(!dash.active);
        bus.replies["luna://com.palm.service.photos/keepAlbum"] = { returnValue: false, errorText: "not enough free space" };
        app.toggleKeep(app.store.album("alb-dropbox"));
        compare(app.noticeTitle, "Could not keep the album on the device");
        app.closeAlbum();
    }
}
