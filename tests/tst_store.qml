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

import "../qml"
import "mocks"
import "Fixtures.js" as Fixtures

/*
 * PhotoStore against a stand-in bus (mocks/FakeBus.qml): the photos
 * service's accounts and capabilities, what each change sends it and what
 * a failure says, the permission request, the account templates' icons.
 */
TestCase {
    id: test
    name: "Store"

    FakeBus {
        id: bus
    }

    PhotoStore {
        id: store
        readDb: false
        call: bus.call
        subscribe: bus.subscribe
        permissionTimeout: 300
    }

    SignalSpy {
        id: failures
        target: store
        signalName: "failed"
    }

    function init() {
        bus.calls = [];
        bus.replies = {};
        failures.clear();
        Fixtures.ROOT = "/r";
        store.setEntries(Fixtures.albums(), Fixtures.images(), Fixtures.videos());
    }

    function last(method) {
        var c = bus.callsTo("luna://com.palm.service.photos/" + method);
        verify(c.length > 0, method + " called");
        return c[c.length - 1].params;
    }

    function test_entries() {
        compare(store.status, "ready");
        verify(store.album("alb-holiday") !== null);
        compare(store.itemsOf("alb-holiday").length, 5);
        compare(store.item("img-h1").path, "/r/pictures/Holiday/beach.jpg");
        compare(store.itemByPath("/r/pictures/Holiday/beach.jpg")._id, "img-h1");
        compare(store.itemByPath("/nope"), null);
        var rev = store.revision;
        store.setEntries([], [], []);
        compare(store.revision, rev + 1);
        compare(store.lib.albums.length, 0);
    }

    function test_connect() {
        store.connect();
        verify(store.serviceAvailable);
        verify(store.can({ type: "local" }, "deleteAlbum"));
        verify(!store.can({ accountId: "acc-dropbox", type: "com.palm.dropbox" }, "deleteAlbum"));
        verify(store.can({ accountId: "acc-dropbox", type: "com.palm.dropbox" }, "deletePhoto"));
        compare(store.libraries.length, 2);
        compare(store.libraries[1].title, "me@example.com");
        verify(bus.callsTo("luna://com.palm.service.photos/generateThumbnails").length > 0);
        compare(bus.callsTo("luna://com.palm.service.accounts/listAccountTemplates")[0].params.capability, "PHOTO.UPLOAD");
        // A sync starts and ends with an error.
        bus.push({ accountId: "acc-dropbox", syncStatus: "syncing" });
        compare(store.libraries[1].syncStatus, "syncing");
        bus.push({ accountId: "acc-dropbox", syncStatus: "idle", error: "Network down" });
        compare(store.libraries[1].syncStatus, "idle");
        compare(failures.count, 1);
        compare(failures.signalArguments[0][0], "Syncing failed");
        compare(failures.signalArguments[0][1], "Network down");
    }

    function test_noService() {
        bus.replies = { "luna://com.palm.service.photos/getAccountsCapability": { busError: "Unknown service" } };
        store.serviceAvailable = false;
        store.capabilities = {};
        store.connect();
        verify(!store.capabilities.local);
        compare(failures.count, 0);
    }

    function test_templateIcons() {
        bus.replies = { "luna://com.palm.service.accounts/listAccountTemplates": { returnValue: true, results: [
            { templateId: "com.palm.dropbox", icon: { loc_32x32: "/a/32.png", loc_48x48: "/a/48.png" } },
            { templateId: "com.palm.box", icon: { loc_32x32: "/b/32.png" } },
            { templateId: "com.palm.none" }] } };
        store._readTemplates();
        compare(store.templateIcons["com.palm.dropbox"], "/a/48.png");
        compare(store.templateIcons["com.palm.box"], "/b/32.png");
        verify(!store.templateIcons["com.palm.none"]);
    }

    function test_changes() {
        var done = [];
        store.createAlbum("  Trip ", [], function(ok) { done.push(ok); });
        compare(last("createAlbum"), { name: "Trip", accountId: "local" });
        store.createAlbum("Trip", [{ sourceAlbum: "a", photos: ["x"], exclude: false }]);
        compare(last("createAlbum").specs.length, 1);
        store.renameAlbum("alb-holiday", "Summer ");
        compare(last("renameAlbum"), { albumId: "alb-holiday", newName: "Summer" });
        store.deleteAlbum("alb-empty");
        compare(last("deleteAlbum"), ["alb-empty"], "the ids are the payload");
        store.addPhotos("alb-empty", [{ sourceAlbum: "alb-holiday", photos: ["img-h1"], exclude: false, targetAlbum: "alb-empty" }]);
        compare(last("addPhotos").targetAlbum, "alb-empty");
        store.deletePhotos([{ sourceAlbum: "alb-holiday", photos: [], exclude: true }]);
        compare(last("deletePhotos").specs[0].exclude, true);
        compare(done, [true]);
        compare(failures.count, 0);
    }

    function test_failures() {
        bus.replies = {
            "luna://com.palm.service.photos/renameAlbum": { returnValue: false, msg: "An album with that name exists" },
            "luna://com.palm.service.photos/deletePhotos": { returnValue: false, errorCode: 8 },
            "luna://com.palm.service.photos/createAlbum": { busError: "Service does not exist" }
        };
        var result = null;
        store.renameAlbum("alb-holiday", "x", function(ok) { result = ok; });
        compare(result, false);
        store.deletePhotos([]);
        store.createAlbum("x");
        compare(failures.count, 3);
        compare(failures.signalArguments[0][0], "Failed to rename album");
        compare(failures.signalArguments[0][1], "An album with that name exists");
        compare(failures.signalArguments[1][0], "Failed to delete photos");
        compare(failures.signalArguments[1][1], "Remote service failed to respond");
        compare(failures.signalArguments[2][0], "Failed to create album");
        compare(failures.signalArguments[2][1], "Service does not exist");
    }

    function test_screenNail_comments() {
        store.requestScreenNail(store.item("img-h1"));
        compare(last("generateImgForBigView"), { _id: "img-h1" });
        bus.calls = [];
        store.requestScreenNail(store.item("vid-h"));
        store.requestScreenNail({ _id: "s", appScreenNail: { path: "/s.jpg" } });
        compare(bus.callsTo("luna://com.palm.service.photos/generateImgForBigView").length, 0);
        var got = null;
        store.getComments(store.item("img-d1"), function(c) { got = c; });
        compare(got.length, 1);
        compare(got[0].user, "Ann");
        store.addComment(store.item("img-d1"), "Hi");
        compare(last("addPhotoComments"), { photo: { _id: "img-d1" }, text: "Hi" });
    }

    function test_sync() {
        store.syncAccount("acc-dropbox");
        compare(last("syncSingleAccount"), { accountId: "acc-dropbox" });
        bus.calls = [];
        store.syncAccount("local");
        verify(bus.callsTo("luna://com.palm.service.photos/remoteSyncAlbums").length === 1);
    }

    function test_permission() {
        // Each of the three kinds is refused on its own: one question, and
        // no answer yet is no refusal yet.
        bus.replies = { "luna://com.palm.mediapermissions/request": null };
        store._asked = false;
        store._failedRead("db: permission denied", -3963);
        store._failedRead("db: permission denied", -3963);
        store._failedRead("db: permission denied", -3963);
        compare(bus.callsTo("luna://com.palm.mediapermissions/request").length, 1);
        compare(store.status, "loading");
        tryCompare(store, "status", "error", 2000);
        bus.calls = [];
        bus.replies = { "luna://com.palm.mediapermissions/request": { returnValue: true, isAllowed: false } };
        store._asked = false;
        store._failedRead("db: permission denied", -3963);
        compare(bus.callsTo("luna://com.palm.mediapermissions/request")[0].params.rights.read,
                ["com.palm.media.image.file:1", "com.palm.media.video.file:1", "com.palm.media.image.album:1"]);
        compare(store.status, "denied");
        // Asked once: a second refusal is the end of it.
        store._failedRead("db: permission denied", -3963);
        compare(bus.callsTo("luna://com.palm.mediapermissions/request").length, 1);
        compare(store.status, "denied");
        // No answer at all: an error, not loading for ever.
        bus.replies = { "luna://com.palm.mediapermissions/request": null };
        store.retryPermission();
        compare(store.status, "loading");
        tryCompare(store, "status", "error", 2000);
        store._failedRead("db: broken", -1000);
        compare(store.status, "error");
        compare(store.errorText, "db: broken");
    }

    function test_lastPlayTime() {
        store.setLastPlayTime("vid-h", 42.7);
        compare(store.item("vid-h").lastPlayTime, 42);
        store.setLastPlayTime("img-h1", 3);
        verify(!store.item("img-h1").lastPlayTime, "a picture has none");
        store.setLastPlayTime("gone", 3);
    }
}
