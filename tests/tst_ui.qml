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

    function startApp(withService) {
        bus.calls = [];
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
        tryVerify(function() { return findChild(find("library-acc-dropbox"), "syncSpinner") !== null; });
        bus.push({ accountId: "acc-dropbox", syncStatus: "idle", error: "Network down" });
        tryCompare(app, "notice", "Network down");
        compare(app.noticeTitle, "Syncing failed");
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
        compare(labels, ["New Album", "Sync Now", "Preferences & Accounts"]);
        app.appMenu.itemAt(2).triggered();
        compare(launches[0].id, "com.palm.app.accounts");
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
}
