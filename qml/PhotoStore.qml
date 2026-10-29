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

import LuneOS.Service 1.0

import "js/Library.js" as Library

/*
 * The photos and videos, and what is done with them.
 *
 * Reading: the albums, pictures and videos in db8 (js/Library.js says how
 * they fit together), watched, so what the indexer finds and the photos
 * service syncs or changes shows up by itself. db8 refuses an app without
 * a grant on the indexer's kinds (-3963); com.palm.mediapermissions then
 * asks the user once, as Music's library does.
 *
 * Doing: com.palm.service.photos (app-services), webOS 3.0's photos
 * service written anew for LuneOS, under its old method names - it brings
 * the cloud accounts' albums down, makes thumbnails and screen-size
 * copies, and creates, renames and deletes albums and copies and deletes
 * pictures, a cloud picture in the cloud as well. The app never touches a
 * file itself.
 */
Item {
    id: store

    readonly property string albumKind: "com.palm.media.image.album:1"
    readonly property string imageKind: "com.palm.media.image.file:1"
    readonly property string videoKind: "com.palm.media.video.file:1"
    readonly property string photosService: "luna://com.palm.service.photos/"

    property string clientName: "org.webosports.app.photos"
    // The storage the indexer scans, whose DCIM is the camera's album.
    property string storageRoot: "/media/internal"
    // The device, in the libraries panel (webOS: "My TouchPad").
    property string deviceName: "My Device"

    // { albums, byId, items, byItemId } (js/Library.js build())
    property var lib: Library.build([], [], [])
    // Bumped whenever lib changes; views rebuild on it.
    property int revision: 0
    // "loading", "ready", "denied" or "error"
    property string status: "loading"
    property string errorText: ""

    // subscribeToAccountsInfo's accounts: { accountId: { syncStatus, isEnabled, username, templateId } }
    property var accounts: ({})
    // getAccountsCapability's: { local: {...}, <templateId>: {...} }
    property var capabilities: ({})
    // Account template icons: { templateId: path }
    property var templateIcons: ({})
    // Whether the photos service answered at all: without it nothing can
    // be changed, only looked at.
    property bool serviceAvailable: false
    readonly property var libraries: Library.libraries(accounts, deviceName)

    // What went wrong with something asked of the service (shown by main.qml).
    signal failed(string title, string detail)

    // function(uri, json, onReply(message), onError(text)) and the same
    // for a subscription, returning an object with cancel(): the bus,
    // replaceable by the tests.
    property var call: function(uri, json, onReply, onError) {
        return bus.call(uri, json, onReply, onError);
    }
    property var subscribe: function(uri, json, onReply, onError) {
        return bus.subscribe(uri, json, onReply, onError);
    }
    // false in the tests, which hand the entries in with setEntries().
    property bool readDb: true
    property int permissionTimeout: 15000

    property var _albums: []
    property var _images: []
    property var _videos: []
    property bool _asked: false
    // A request is out: the other kinds' refusals are the same question.
    property bool _asking: false
    property var _accountsCall: null

    LunaService {
        id: bus
        name: store.clientName
    }

    // The three kinds, every page, watched; each answer waits a moment for
    // the others and for the bursts of an indexer scan or a sync.
    Db8Model {
        id: albumModel
        query: ({ where: [{ prop: "showAlbum", op: "=", val: true }], limit: 500 })
        allPages: true
        watch: true
        onStatusChanged: if (status === "ready") store._took("albums", albumModel)
        onError: function(errorText, errorCode) { store._failedRead(errorText, errorCode); }
    }
    Db8Model {
        id: imageModel
        query: ({ select: ["_id", "albumId", "path", "appOriginal", "mediaType", "type", "accountId",
                           "createdTime", "modifiedTime", "appGridThumbnail", "appScreenNail",
                           "appCacheComplete", "size", "comments"], limit: 500 })
        allPages: true
        watch: true
        onStatusChanged: if (status === "ready") store._took("images", imageModel)
        onError: function(errorText, errorCode) { store._failedRead(errorText, errorCode); }
    }
    Db8Model {
        id: videoModel
        query: ({ select: ["_id", "albumId", "path", "mediaType", "type", "createdTime", "modifiedTime",
                           "duration", "lastPlayTime", "appGridThumbnail", "size", "title"], limit: 500 })
        allPages: true
        watch: true
        onStatusChanged: if (status === "ready") store._took("videos", videoModel)
        onError: function(errorText, errorCode) { store._failedRead(errorText, errorCode); }
    }

    property var _got: ({})
    function _took(which, model) {
        var rows = [];
        for (var i = 0; i < model.count; i++)
            rows.push(model.get(i));
        if (which === "albums")
            _albums = rows;
        else if (which === "images")
            _images = rows;
        else
            _videos = rows;
        var got = _got;
        got[which] = true;
        _got = got;
        // The first full answer at once; changes after a pause.
        if (status !== "ready" && got.albums && got.images && got.videos)
            _rebuild();
        else if (status === "ready")
            rebuildTimer.restart();
    }

    Timer {
        id: rebuildTimer
        interval: 700
        onTriggered: store._rebuild()
    }

    function _failedRead(text, code) {
        if (code === -3963 && _asking)
            return;
        if (code === -3963 && !_asked) {
            _asked = true;
            _askPermission();
            return;
        }
        errorText = text;
        status = code === -3963 ? "denied" : "error";
    }

    Timer {
        id: permissionTimer
        interval: store.permissionTimeout
        onTriggered: {
            store._asking = false;
            store.errorText = "Photos & Videos cannot ask for access to your pictures: the permission service does not answer.";
            store.status = "error";
        }
    }

    function _askPermission() {
        status = "loading";
        _asking = true;
        permissionTimer.restart();
        call("luna://com.palm.mediapermissions/request",
             JSON.stringify({ rights: { read: [imageKind, videoKind, albumKind] } }),
             function(message) {
                 permissionTimer.stop();
                 store._asking = false;
                 var r = JSON.parse(message.payload);
                 if (r.isAllowed)
                     store.load();
                 else
                     store.status = "denied";
             }, function() {
                 permissionTimer.stop();
                 store._asking = false;
                 store.status = "denied";
             });
    }

    function retryPermission() {
        _asked = true;
        _askPermission();
    }

    function load() {
        if (!readDb)
            return;
        if (albumModel.kind === "") {
            albumModel.kind = albumKind;
            imageModel.kind = imageKind;
            videoModel.kind = videoKind;
        } else {
            albumModel.refresh();
            imageModel.refresh();
            videoModel.refresh();
        }
    }

    // The entries as they are in db8 (the tests' way in, too).
    function setEntries(albums, images, videos) {
        _albums = albums || [];
        _images = images || [];
        _videos = videos || [];
        _rebuild();
    }

    function _rebuild() {
        lib = Library.build(_albums, _images, _videos, storageRoot);
        status = "ready";
        revision++;
    }

    function album(id) {
        return lib.byId[id] || null;
    }

    function itemsOf(albumId) {
        return lib.items[albumId] || [];
    }

    function item(id) {
        return lib.byItemId[id] || null;
    }

    function itemByPath(path) {
        for (var id in lib.byItemId)
            if (lib.byItemId[id].path === path)
                return lib.byItemId[id];
        return null;
    }

    function can(entry, name) {
        return Library.capability(capabilities, entry, name);
    }

    // --- the photos service --------------------------------------------------------

    // Calls a method; reply(r) gets the parsed answer, failing ones too.
    function _service(method, params, reply) {
        call(photosService + method, JSON.stringify(params), function(message) {
            var r = null;
            try {
                r = JSON.parse(message.payload);
            } catch (e) {
                r = { returnValue: false, errorText: String(e) };
            }
            if (reply)
                reply(r);
        }, function(error) {
            if (reply)
                reply({ returnValue: false, errorText: String(error) });
        });
    }

    // Each change: a title for when it fails (webOS's dashboard titles).
    function _change(method, params, failTitle, done) {
        _service(method, params, function(r) {
            if (!r || !r.returnValue)
                store.failed(failTitle, Library.serviceError(r));
            if (done)
                done(!!(r && r.returnValue), r);
        });
    }

    // The accounts and their sync status, and what each one can do. The
    // subscription syncs every account, as webOS's app did at start.
    function connect() {
        _service("getAccountsCapability", {}, function(r) {
            if (r && r.returnValue) {
                store.serviceAvailable = true;
                store.capabilities = r.AccountsCapability || {};
            }
        });
        if (_accountsCall && typeof _accountsCall.cancel === "function")
            _accountsCall.cancel();
        _accountsCall = subscribe(photosService + "subscribeToAccountsInfo", JSON.stringify({ subscribe: true }),
                                  function(message) {
            var r = JSON.parse(message.payload);
            if (!r.returnValue)
                return;
            store.serviceAvailable = true;
            store.accounts = Library.mergeAccounts(store.accounts, r);
            if (r.error && r.accountId)
                store.failed("Syncing failed", String(r.error));
            if (r.accounts)
                store._readTemplates();
        }, function(error) {
            console.warn("Photos: the photos service does not answer: " + error);
        }) || null;
        _service("generateThumbnails", {}, null);
    }

    // The account templates' icons, for the libraries of the cloud accounts.
    function _readTemplates() {
        call("luna://com.palm.service.accounts/listAccountTemplates", JSON.stringify({ capability: "PHOTO.UPLOAD" }),
             function(message) {
            var r = JSON.parse(message.payload);
            var icons = {};
            (r.results || []).forEach(function(t) {
                var icon = t.icon || {};
                var path = icon.loc_48x48 || icon.loc_32x32 || "";
                if (path !== "")
                    icons[t.templateId] = path;
            });
            store.templateIcons = icons;
        }, function() {});
    }

    function syncAll() {
        _service("remoteSyncAlbums", {}, null);
    }

    function syncAccount(accountId) {
        if (accountId && accountId !== "local" && accountId !== "all")
            _service("syncSingleAccount", { accountId: accountId }, null);
        else
            syncAll();
    }

    function createAlbum(name, specs, done) {
        var p = { name: name.trim(), accountId: "local" };
        if (specs && specs.length > 0)
            p.specs = specs;
        _change("createAlbum", p, "Failed to create album", done);
    }

    function renameAlbum(albumId, newName, done) {
        _change("renameAlbum", { albumId: albumId, newName: newName.trim() }, "Failed to rename album", done);
    }

    // The service takes the ids as the payload itself.
    function deleteAlbum(albumId, done) {
        _change("deleteAlbum", [albumId], "Failed to delete album", done);
    }

    function addPhotos(targetAlbum, specs, done) {
        _change("addPhotos", { targetAlbum: targetAlbum, specs: specs }, "Failed to add photos to album", done);
    }

    function deletePhotos(specs, done) {
        _change("deletePhotos", { specs: specs }, "Failed to delete photos", done);
    }

    // The screen-size copy of a picture, for the full-screen view.
    function requestScreenNail(item) {
        if (item && item._id && !(item.appScreenNail && item.appScreenNail.path) && item.mediaType !== "video")
            _service("generateImgForBigView", { _id: item._id }, null);
    }

    // A thumbnail that did not load: made again (webOS reset its entry).
    function regenerateThumbnails() {
        _service("generateThumbnails", {}, null);
    }

    function getComments(item, done) {
        _service("getPhotoComments", { _id: item._id }, function(r) {
            done(r && r.returnValue ? (r.comments || r.results || []) : null);
        });
    }

    function addComment(item, text, done) {
        _change("addPhotoComments", { photo: { _id: item._id }, text: text }, "Failed to add comment", done);
    }

    // Where a video was left, written back as webOS's player did.
    function setLastPlayTime(id, seconds) {
        var entry = lib.byItemId[id];
        if (!entry || entry.mediaType !== "video")
            return;
        entry.lastPlayTime = Math.floor(seconds);
        if (readDb)
            videoModel.merge([{ _id: id, lastPlayTime: entry.lastPlayTime }]);
    }

    Component.onDestruction: {
        if (_accountsCall && typeof _accountsCall.cancel === "function")
            _accountsCall.cancel();
    }
}
