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

import "../qml/js/Library.js" as Library
import "../qml/js/Images.js" as Images
import "Fixtures.js" as Fixtures

/*
 * qml/js/Library.js: how the db8 entries make albums, the names webOS gave
 * them, the libraries and accounts, selections and the photos service's
 * specs, the delete dialog's words, slideshows, formatting; and
 * qml/js/Images.js, which of the drawn pictures a screen shows.
 */
TestCase {
    name: "Library"

    function build() {
        Fixtures.ROOT = "/r";
        return Library.build(Fixtures.albums(), Fixtures.images(), Fixtures.videos(), "/r/pictures");
    }

    function test_paths() {
        compare(Library.dirname("/a/b/c.jpg"), "/a/b");
        compare(Library.dirname("/c.jpg"), "/");
        compare(Library.dirname("c.jpg"), "");
        compare(Library.basename("/a/b/c.jpg"), "c.jpg");
        compare(Library.fileUrl("/a b/#1?.jpg"), "file:///a%20b/%231%3F.jpg");
        compare(Library.fileUrl("https://x/y.jpg"), "https://x/y.jpg");
        compare(Library.fileUrl(""), "");
    }

    function test_cameraFolder() {
        verify(Library.isCameraFolder("/media/internal/DCIM"));
        verify(Library.isCameraFolder("/media/internal/dcim/100ANDRO"));
        verify(!Library.isCameraFolder("/media/internal/DCIMfoo"));
        verify(!Library.isCameraFolder("/media/internal/Pictures/DCIM"));
        verify(Library.isCameraFolder("/r/pictures/DCIM", "/r/pictures"));
    }

    function test_cloud() {
        verify(Library.isCloud({ accountId: "a1", type: "com.palm.dropbox" }));
        verify(!Library.isCloud({ accountId: "", type: "local" }));
        verify(!Library.isCloud({ accountId: "local" }));
        verify(!Library.isCloud({ accountId: "a1", type: "local" }));
        verify(!Library.isCloud(null));
        compare(Library.capabilityKey({ accountId: "a1", type: "com.palm.dropbox" }), "com.palm.dropbox");
        compare(Library.capabilityKey({ accountId: "", type: "local" }), "local");
        var caps = { local: { deletePhoto: true }, "com.palm.dropbox": { deletePhoto: false } };
        verify(Library.capability(caps, { type: "local" }, "deletePhoto"));
        verify(!Library.capability(caps, { accountId: "a", type: "com.palm.dropbox" }, "deletePhoto"));
        verify(!Library.capability(caps, { accountId: "a", type: "com.palm.other" }, "deletePhoto"));
        verify(!Library.capability(null, { type: "local" }, "deletePhoto"));
        compare(Library.accountType("com.palm.boxnet"), "boxnet");
        compare(Library.accountType(""), "");
    }

    function test_titles() {
        compare(Library.albumTitle({ path: "camera://", name: "" }), "Photo roll");
        compare(Library.albumTitle({ path: "/media/internal/screencaptures", name: "screencaptures" }), "Screen captures");
        compare(Library.albumTitle({ path: "/usr/share/wallpapers", name: "wallpapers" }), "Wallpapers");
        compare(Library.albumTitle({ path: "/media/internal/x", name: "downloads" }), "Downloads");
        compare(Library.albumTitle({ path: "/media/internal/x", name: "" }), "Unnamed album");
        compare(Library.albumTitle({ path: "/media/internal/x", name: "Trip" }), "Trip");
        // A cloud album keeps its own name.
        compare(Library.albumTitle({ path: "/p", name: "photos", accountId: "a", type: "com.palm.x" }), "photos");
        compare(Library.albumTitle(null), "");
    }

    function test_rename_add() {
        verify(Library.canRename({ path: "/media/internal/Trip" }));
        verify(!Library.canRename({ path: "camera://" }));
        verify(!Library.canRename({ path: "/p", accountId: "a", type: "com.palm.x" }));
        verify(!Library.canRename({ path: "/p", virtual: true }));
        verify(!Library.canRename(null));
        verify(Library.canAddTo({ path: "/media/internal/Trip" }));
        verify(!Library.canAddTo({ path: "camera://" }));
        verify(!Library.canAddTo({ path: "/x", virtual: true }));
    }

    function test_build() {
        var lib = build();
        var ids = lib.albums.map(function(a) { return a._id; });
        // Hidden left out; newest first; a folder of videos only made up.
        verify(ids.indexOf("alb-hidden") < 0);
        compare(ids[0], "alb-camera");
        verify(ids.indexOf("video:/r/Movies") >= 0);
        var cam = lib.byId["alb-camera"];
        compare(cam.images, 2);
        compare(cam.videos, 1, "the DCIM video in the camera's album");
        compare(cam.title, "Photo roll");
        compare(cam.cover._id, "vid-c", "the newest is the cover");
        var hol = lib.byId["alb-holiday"];
        compare(hol.images, 4);
        compare(hol.videos, 1);
        compare(lib.items["alb-holiday"].map(function(i) { return i._id; }),
                ["img-h1", "vid-h", "img-h2", "img-h3", "img-h4"], "newest first, modifiedTime when no createdTime");
        compare(lib.byItemId["vid-h"].albumId, "alb-holiday");
        var movies = lib.byId["video:/r/Movies"];
        verify(movies.virtual);
        compare(movies.title, "Movies");
        compare(movies.videos, 1);
        compare(movies.modifiedTime, 1791000500);
        compare(lib.byId["alb-empty"].images, 0);
        compare(lib.byId["alb-empty"].cover, null);
        // An image of an album not there is left out.
        verify(!lib.byItemId["img-x"]);
    }

    function test_build_cameraVideosWithoutAlbum() {
        var lib = Library.build([], [], [{ _id: "v", path: "/media/internal/DCIM/a.mp4", createdTime: 5 }]);
        compare(lib.albums.length, 1);
        compare(lib.albums[0].path, "camera://");
        compare(lib.albums[0].title, "Photo roll");
        compare(lib.items[lib.albums[0]._id][0].mediaType, "video");
    }

    function test_build_empty() {
        var lib = Library.build(null, null, null);
        compare(lib.albums.length, 0);
    }

    function test_albumsOf() {
        var lib = build();
        compare(Library.albumsOf(lib.albums, "all").length, lib.albums.length);
        compare(Library.albumsOf(lib.albums, "acc-dropbox").map(function(a) { return a._id; }), ["alb-dropbox"]);
        verify(Library.albumsOf(lib.albums, "local").every(function(a) { return !Library.isCloud(a); }));
        compare(Library.albumsOf(lib.albums, "local").length, lib.albums.length - 1);
    }

    function test_libraries() {
        var libs = Library.libraries({
            local: { syncStatus: "idle" },
            b: { templateId: "com.palm.onedrive", username: "zed", syncStatus: "syncing" },
            a: { templateId: "com.palm.dropbox", username: "Bob" },
            c: { templateId: "com.palm.dropbox", username: "alice" },
            f: { templateId: "com.palm.facebook", username: "Face" },
            off: { templateId: "com.palm.box", username: "x", isEnabled: false }
        }, "My TouchPad");
        compare(libs.map(function(l) { return l.title; }), ["My TouchPad", "Face", "alice", "Bob", "zed"]);
        compare(libs[4].type, "onedrive");
        verify(Library.isSyncing(libs[4]));
        verify(!Library.isSyncing(libs[0]));
        compare(Library.libraries(null, "D").length, 1);
    }

    function test_mergeAccounts() {
        var a = Library.mergeAccounts({}, { accounts: { local: { syncStatus: "idle" }, x: { syncStatus: "idle" } } });
        compare(Object.keys(a).length, 2);
        var b = Library.mergeAccounts(a, { accountId: "x", syncStatus: "syncing", returnValue: true });
        compare(b.x.syncStatus, "syncing");
        verify(!b.x.hasOwnProperty("returnValue"));
        compare(a.x.syncStatus, "idle", "the old map is not changed");
        var c = Library.mergeAccounts(b, { accounts: { local: {} } });
        compare(Object.keys(c), ["local"]);
    }

    function test_counts() {
        compare(Library.countLabel({ images: 1, videos: 0 }), "1 image");
        compare(Library.countLabel({ images: 0, videos: 0 }), "0 images");
        compare(Library.countLabel({ images: 3, videos: 2 }), "3 images, 2 videos");
        compare(Library.countLabel({ images: 0, videos: 1 }), "1 video");
        compare(Library.countLabel(null), "");
    }

    function test_deleteMessage() {
        compare(Library.deleteMessage(1, 0, false), "Are you sure you want to delete this image?");
        compare(Library.deleteMessage(0, 1, false), "Are you sure you want to delete this video?");
        compare(Library.deleteMessage(3, 0, false), "Are you sure you want to delete these 3 images?");
        compare(Library.deleteMessage(0, 2, false), "Are you sure you want to delete these 2 videos?");
        compare(Library.deleteMessage(2, 1, false), "Are you sure you want to delete these 3 items?");
        compare(Library.deleteMessage(1, 0, true), "This permanently deletes the photo from your cloud account. It can't be undone.");
        compare(Library.deleteMessage(0, 1, true), "This permanently deletes the video from your cloud account. It can't be undone.");
        compare(Library.deleteMessage(2, 0, true), "This permanently deletes the selected photos from your cloud account. It can't be undone.");
    }

    function test_selection() {
        var items = [{ _id: "a" }, { _id: "b" }, { _id: "c" }];
        var s = Library.newSelection();
        compare(Library.selectedCount(s, 3), 0);
        s = Library.toggle(s, "b");
        verify(Library.isSelected(s, "b"));
        verify(!Library.isSelected(s, "a"));
        compare(Library.selectedCount(s, 3), 1);
        var s2 = Library.toggle(s, "b");
        verify(!Library.isSelected(s2, "b"));
        verify(Library.isSelected(s, "b"), "toggle makes a new selection");
        s = Library.selectAll(true);
        compare(Library.selectedCount(s, 3), 3);
        s = Library.toggle(s, "a");
        compare(Library.selectedItems(s, items).map(function(i) { return i._id; }), ["b", "c"]);
        compare(Library.selectedCount(s, 3), 2);
        compare(Library.spec(s, "alb"), { sourceAlbum: "alb", photos: ["a"], exclude: true });
        compare(Library.spec(Library.selectAll(false), "alb", "t"), { sourceAlbum: "alb", photos: [], exclude: false, targetAlbum: "t" });
        compare(Library.specForIds(["x", "y"], "video:/m"), { sourceAlbum: null, photos: ["x", "y"], exclude: false });
    }

    function test_targetAlbums() {
        var lib = build();
        var t = Library.targetAlbums(lib.albums, "alb-holiday", false).map(function(a) { return a._id; });
        verify(t.indexOf("alb-holiday") < 0, "not the current one");
        verify(t.indexOf("alb-camera") < 0, "not the camera's");
        verify(t.indexOf("video:/r/Movies") < 0, "not a made-up one");
        verify(t.indexOf("alb-dropbox") >= 0);
        verify(t.indexOf("alb-empty") >= 0);
        var v = Library.targetAlbums(lib.albums, "alb-holiday", true).map(function(a) { return a._id; });
        verify(v.indexOf("alb-dropbox") < 0, "videos only to the device's albums");
    }

    function test_pictures() {
        compare(Library.viewPath({ path: "/a.jpg", appScreenNail: { path: "/s.jpg" } }), "/s.jpg");
        compare(Library.viewPath({ path: "/a.jpg" }), "/a.jpg");
        compare(Library.viewPath({ appOriginal: "/o.jpg" }), "/o.jpg");
        compare(Library.viewPath(null), "");
        var small = { path: "/a.jpg", appGridThumbnail: { path: "/t.jpg", dimensions: { "output-width": 80, "output-height": 60 } } };
        compare(Library.thumbnailPath(small, 100), "/t.jpg");
        compare(Library.thumbnailPath(small, 200), "/a.jpg", "too small: the file");
        compare(Library.thumbnailPath(small, 0), "/t.jpg");
        compare(Library.thumbnailPath({ path: "/v.mp4", mediaType: "video" }, 100), "", "no file for a video");
        compare(Library.thumbnailPath({ path: "/v.mp4", mediaType: "video", appGridThumbnail: { path: "/p.jpg",
                 dimensions: { "output-width": 0, "output-height": 0 } } }, 300), "/p.jpg");
    }

    function test_format() {
        compare(Library.formatDuration(0), "0:00");
        compare(Library.formatDuration(65), "1:05");
        compare(Library.formatDuration(3723), "1:02:03");
        compare(Library.formatDuration(-3), "0:00");
        compare(Library.formatDate(0), "");
        var d = new Date(2026, 9, 8, 12, 0, 0);
        compare(Library.formatDate(d.getTime() / 1000), "October 8, 2026");
        compare(Library.relativeTime(100, 130), "Just now");
        compare(Library.relativeTime(100, 160), "1 minute ago");
        compare(Library.relativeTime(0, 3599), "59 minutes ago");
        compare(Library.relativeTime(0, 3600), "1 hour ago");
        compare(Library.relativeTime(0, 86400 * 3), "3 days ago");
        compare(Library.relativeTime(0, 86400), "1 day ago");
    }

    function test_serviceError() {
        compare(Library.serviceError(null), "Unknown error");
        compare(Library.serviceError({ errorCode: 6 }), "Network error");
        compare(Library.serviceError({ msg: "Need a valid album name" }), "Need a valid album name");
        compare(Library.serviceError({ response: "No specs" }), "No specs");
        compare(Library.serviceError({ errorCode: 99 }), "Unknown error");
    }

    function test_slideshow() {
        var lib = build();
        var list = Library.slideshowPlaylist(lib, ["alb-camera", "alb-holiday"]);
        compare(list.map(function(i) { return i._id; }),
                ["img-c1", "img-c2", "img-h4", "img-h3", "img-h2", "img-h1"], "pictures only, oldest first");
        compare(Library.slideshowAlbums(lib.albums, []).indexOf("alb-empty"), -1);
        compare(Library.slideshowAlbums(lib.albums, ["alb-holiday"]), ["alb-holiday"]);
        compare(Library.slideshowAlbums(lib.albums, ["gone"]).length, 3, "a choice of nothing there is all");
        var seq = [0.9, 0.1, 0.5];
        var n = 0;
        var s = Library.shuffled([1, 2, 3, 4], function() { return seq[n++ % seq.length]; });
        compare(s.slice().sort(), [1, 2, 3, 4]);
        compare(s, [3, 2, 1, 4], "i=3: j=3, i=2: j=0, i=1: j=1");
        compare(Library.wrap(-1, 4), 3);
        compare(Library.wrap(4, 4), 0);
        compare(Library.wrap(2, 0), 0);
        compare(Library.slideshowIntervals[1].ms, 10000);
        compare(Library.slideshowIntervals.length, 7);
    }

    function test_removal() {
        var items = [{ _id: "a" }, { _id: "c" }];
        compare(Library.indexAfterRemoval(items, "c", 0), 1, "still there");
        compare(Library.indexAfterRemoval(items, "b", 1), 1, "the next takes its place");
        compare(Library.indexAfterRemoval(items, "d", 2), 1, "the last went: the one before");
        compare(Library.indexAfterRemoval([], "a", 0), -1);
    }

    function test_names_launch() {
        verify(Library.validAlbumName(" Trip "));
        verify(!Library.validAlbumName("  "));
        verify(!Library.validAlbumName("a/b"));
        verify(!Library.validAlbumName(".."));
        compare(Library.launchTarget({ albumID: "a", pictureID: "p" }), { albumId: "a", pictureId: "p" });
        compare(Library.launchTarget({ albumID: "a" }), { albumId: "a", pictureId: null });
        compare(Library.launchTarget({ target: "/x" }), null);
        compare(Library.launchTarget(null), null);
    }

    // Never blown up, and only twice the pixels where it is worth it
    function test_images() {
        compare(Images.scale(10), 1);   // the TouchPad, the drawn pixels
        compare(Images.scale(10.4), 1);
        compare(Images.scale(11), 2);   // the mindphone
        compare(Images.scale(16), 2);   // the Q25
        compare(Images.scale(20.4), 2);
        compare(Images.scale(21), 3);
        compare(Images.scale(26), 3);   // the Nexus 5
        compare(Images.scale(40), 3);   // no 4x: made smaller from 3x
        compare(Images.scale(6), 1);
        verify(/\/qml\/images\/2x\/icn-delete\.png$/.test(Images.url("icn-delete", 16)), Images.url("icn-delete", 16));
        verify(Images.hasPressed("icn-delete"));
        verify(!Images.hasPressed("icn-more"), "icn-more has no pressed state");
    }
}
