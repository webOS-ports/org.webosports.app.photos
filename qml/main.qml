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
import QtQuick.Controls
import QtQuick.Controls.LuneOS 2.0
import QtCore as Core

import Eos.Window 0.1
import LunaNext.Common 0.1
import LuneOS.Service 1.0
import LuneOS.System 1.0

import LuneOS.Components 1.0 as LC
import LuneOS.Forms 1.0 as Forms
import "components"
import "js/Library.js" as Library
import "js/Images.js" as Images

/*
 * Photos & Videos: the pictures and videos on the device and in the cloud
 * accounts, by album, as webOS 3.0's app showed them.
 *
 * On a wide window the libraries and albums are a panel on the left and
 * the library or album on the right; on a narrow one the panel is the
 * first page and an album opens over it. A picture or video opens full
 * screen; a slideshow plays an album, the library, or from a picture.
 *
 * Launched with {"albumID": id, "pictureID": id} it opens that album or
 * picture (webOS's parameters); with {"target": path} a picture or video
 * of the library, by its file; with {"windowType": "dockModeWindow",
 * "dockMode": true} - exhibition - the slideshow in the dock window. The
 * back gesture (an Escape key) closes what is open, then the app.
 */
WebOSWindow {
    id: appWindow

    title: "Photos & Videos"
    width: Settings.displayWidth
    height: Settings.displayHeight
    visible: true
    color: "#1a1a1a"
    windowType: "_WEBOS_WINDOW_TYPE_CARD"

    // The panel beside the album from this width on (webOS's sliding
    // pane: 540 px on the TouchPad).
    readonly property bool wide: width >= Units.gu(68)
    // A phone on its side: too short for a bar at the bottom as well as the top.
    readonly property bool compact: width > height && height < Units.gu(50)
    readonly property real headerHeight: (height < Units.gu(70) || width < Units.gu(50)) ? Units.gu(7)
                                                                                     : Units.gu(8)
    readonly property bool active: Qt.application.state === Qt.ApplicationActive

    property alias store: photoStore
    property alias prefs: preferences
    property alias panel: libraryPanel
    property alias libraryGrid: libraryGrid
    property alias albumView: albumView
    property alias picture: pictureView
    property alias slideshow: slideshowView
    property alias appMenu: appMenu
    property alias sheet: sheet
    property alias preferencesView: prefsView
    property alias confirm: confirmDialog
    property alias nameDialog: nameDialog
    property alias printer: printer

    // "all", "local" or an accountId: the library on the right.
    property string source: "all"
    property string sourceTitle: "All Photos & Videos"
    property string sourceIcon: Images.url("icn-all-photos", Units.gridUnit)
    // The album open, "" for the library.
    property string albumId: ""
    readonly property var currentAlbum: { photoStore.revision; return photoStore.album(albumId); }

    // Says what went wrong, at the top, until dismissed.
    property string notice: ""
    property string noticeTitle: ""

    // The back gesture in the library ends the app (not in the tests).
    property bool quitOnBack: true
    signal quitRequested()
    // What the app asked another app to do (the tests read it).
    signal launched(string appId, var params)

    PreferencesModel {
        id: preferences
    }

    PhotoStore {
        id: photoStore
        readDb: appWindow.readDb
        call: appWindow.busCall
        subscribe: appWindow.busSubscribe
        deviceName: appWindow.deviceName
        // Something that did not work out, which the user only needs to know: a banner, as
        // webOS tells of a sync that failed
        onFailed: function(title, detail) { appWindow.banner(detail ? title + ": " + detail : title); }
        onRevisionChanged: appWindow.checkCurrent()
        onFetchingOriginal: function(item) { pictureView.flash("Downloading the picture"); }
        onKeeping: function(album) { appWindow.keepStarted(album); }
    }

    // The device's name, as webOS's "My TouchPad".
    property string deviceName: "My Device"

    LunaService {
        id: service
        name: "org.webosports.app.photos"
    }

    // function(uri, json, onReply, onError): the calls to other apps and the
    // system, and subscriptions (returning an object with cancel()); the
    // tests replace them, the video engine, and reading db8.
    property var busCall: function(uri, json, onReply, onError) {
        return service.call(uri, json, onReply || function() {}, onError || function() {});
    }
    property var busSubscribe: function(uri, json, onReply, onError) {
        return service.subscribe(uri, json, onReply || function() {}, onError || function() {});
    }
    property url engineSource: Qt.resolvedUrl("VideoEngine.qml")
    property bool readDb: true

    function launchApp(appId, params) {
        launched(appId, params);
        busCall("luna://com.webos.service.applicationManager/launch",
                JSON.stringify({ id: appId, params: params || {} }), null,
                function(error) { console.warn("Photos: cannot launch " + appId + ": " + error); });
    }

    // An album that went (deleted here or elsewhere): back to the library.
    function checkCurrent() {
        if (albumId !== "" && !photoStore.album(albumId)) {
            albumId = "";
            albumView.cancelSelection();
        }
        pictureView.libraryChanged();
        slideshowView.libraryChanged();
    }

    function showSource(src) {
        source = src;
        if (src === "all") {
            sourceTitle = "All Photos & Videos";
            sourceIcon = Images.url("icn-all-photos", Units.gridUnit);
        } else {
            var libs = photoStore.libraries;
            for (var i = 0; i < libs.length; i++) {
                if (libs[i].accountId === src) {
                    sourceTitle = libs[i].title;
                    sourceIcon = libraryIcon(libs[i]);
                }
            }
        }
        albumId = "";
        albumView.cancelSelection();
        if (src !== "all")
            photoStore.syncAccount(src);
    }

    function libraryIcon(lib) {
        if (!lib || lib.accountId === "local")
            return Images.url("icn-my-touchpad", Units.gridUnit);
        var icon = photoStore.templateIcons[lib.templateId];
        return icon ? Library.fileUrl(icon) : Images.url("cloud", Units.gridUnit);
    }

    function openAlbum(id) {
        albumView.cancelSelection();
        albumId = id;
    }

    // Back from an album: to the album it is in, else to the library.
    function closeAlbum() {
        var a = photoStore.album(albumId);
        albumView.cancelSelection();
        albumId = a && a.parent ? a.parent : "";
    }

    function openPicture(albumIdToShow, itemId, autoPlay) {
        if (albumIdToShow)
            albumId = albumIdToShow;
        pictureView.open(albumId, itemId, autoPlay === true);
    }

    // The albums a slideshow plays: one, or the library's with pictures.
    function startSlideshow(albumIds, startItemId) {
        var list = Library.slideshowPlaylist(photoStore.lib, albumIds);
        if (list.length === 0) {
            noticeTitle = "";
            notice = "Please download more photos to play slideshow.";
            return;
        }
        slideshowView.start(list, startItemId || "", false);
    }

    // The library's albums, sub-albums too (what its slideshow plays)
    function libraryAlbums() {
        return Library.albumsOf(photoStore.lib.albums, source);
    }

    // The ones it shows: those in no other album
    function libraryTopAlbums() {
        return Library.topLevel(libraryAlbums());
    }

    // --- dialogs ------------------------------------------------------------------

    // "Add to Album": the albums pictures can go into, and a new one.
    function chooseAlbum(items, sourceAlbumId) {
        if (items.length === 0) {
            confirmDialog.ask({ title: "No items selected", message: "No items selected for adding to album.", rejectText: "" });
            return;
        }
        var hasVideo = items.some(function(i) { return i.mediaType === "video"; });
        var choices = Library.targetAlbums(photoStore.lib.albums, sourceAlbumId, hasVideo).map(function(a) {
            return { label: Library.pathTitle(photoStore.lib, a), key: a._id };
        });
        choices.unshift({ label: "Create New Album", key: "" });
        var ids = items.map(function(i) { return i._id; });
        sheet.show("Add to Album", choices.map(function(c) {
            c.action = function() {
                var spec = Library.specForIds(ids, sourceAlbumId, c.key !== "" ? c.key : undefined);
                if (c.key === "")
                    appWindow.askNewAlbum([spec]);
                else
                    photoStore.addPhotos(c.key, [spec]);
            };
            return c;
        }));
    }

    function askNewAlbum(specs) {
        nameDialog.ask({ title: "New Album", acceptText: "Create Album", valid: Library.validAlbumName,
                         onAccepted: function(name) { photoStore.createAlbum(name.trim(), specs || []); } });
    }

    function askRename(album) {
        if (!Library.canRename(album))
            return;
        nameDialog.ask({ title: "Rename Album", text: album.title, acceptText: "Rename", valid: Library.validAlbumName,
                         onAccepted: function(name) { photoStore.renameAlbum(album._id, name.trim()); } });
    }

    // Keep on Device: the album's pictures all brought down, and never dropped
    function toggleKeep(album) {
        if (!Library.canKeep(album))
            return;
        var keep = album.keep !== true;
        photoStore.keepAlbum(album, keep, function(r) {
            if (keep)
                appWindow.keepEnded(album, r);
        });
    }

    readonly property string appId: "org.webosports.app.photos"
    // The glyph webOS's sync banners and dashboards show (enyo syncui's
    // notification-small-sync.png, also in systemui)
    readonly property string syncGlyph: "/usr/palm/applications/com.palm.systemui/images/notification-small-sync.png"

    // --- Keep on Device, as webOS's sync tells of a sync --------------------------
    // A banner when it starts, a dashboard while it runs, a banner when it is done.

    // The albums coming down, the latest last: [{ _id, title, icon }]
    property var keepingAlbums: []
    // Swiped away: it stays away until the albums coming down now are done
    property bool keepDashboardDismissed: false

    function keepStarted(album) {
        if (keepingAlbums.some(function(a) { return a._id === album._id; }))
            return;
        // The account's icon, as the sync dashboard has it
        var lib = { accountId: album.accountId, templateId: (photoStore.accounts[album.accountId] || {}).templateId };
        keepingAlbums = keepingAlbums.concat([{ _id: album._id, title: album.title, icon: libraryIcon(lib).toString() }]);
        banner(album.title + ": Downloading album...");
    }

    // r null: it failed, and the store has said so
    function keepEnded(album, r) {
        keepingAlbums = keepingAlbums.filter(function(a) { return a._id !== album._id; });
        if (keepingAlbums.length === 0)
            keepDashboardDismissed = false;
        if (!r)
            return;
        // The ones that did not come down come when they are opened
        banner(album.title + ": " + (r.failed > 0 ? (r.photos - r.failed) + " of " + r.photos + " pictures downloaded"
                                                  : "Download completed"));
    }

    // A banner, as PalmSystem.addBannerMessage posts one: a "light" toast, which goes by
    // and leaves nothing in the notification list
    function banner(message) {
        busCall("luna://com.webos.notification/createToast",
                JSON.stringify({ type: "light", sourceId: appId, message: message, iconUrl: syncGlyph }),
                null, function(error) { console.warn("Photos: no banner: " + error); });
    }

    Loader {
        id: keepDashboardLoader
        objectName: "keepDashboardLoader"
        active: appWindow.keepingAlbums.length > 0 && !appWindow.keepDashboardDismissed
        sourceComponent: KeepDashboard {
            readonly property var latest: appWindow.keepingAlbums[appWindow.keepingAlbums.length - 1] || {}
            title: latest.title || ""
            icon: latest.icon || ""
            count: appWindow.keepingAlbums.length
            smallIcon: appWindow.syncGlyph
            onTapped: appWindow.launchApp(appWindow.appId, { albumID: latest._id })
            // Later: this runs in the window's own signal
            onDismissed: Qt.callLater(function() { appWindow.keepDashboardDismissed = true; })
        }
    }

    function askDeleteAlbum(album) {
        confirmDialog.ask({ title: "Delete Album", message: "Are you sure you want to delete this album?",
                            acceptText: "Delete Album", destructive: true,
                            onAccepted: function() { photoStore.deleteAlbum(album._id); } });
    }

    // Pictures and videos of an album, after asking.
    function askDelete(items, album, selection, done) {
        if (items.length === 0) {
            confirmDialog.ask({ title: "No items selected", message: "No items selected for deletion.", rejectText: "" });
            return;
        }
        var videos = items.filter(function(i) { return i.mediaType === "video"; }).length;
        var cloud = items.some(function(i) { return Library.isCloud(i); });
        confirmDialog.ask({ title: "Delete", message: Library.deleteMessage(items.length - videos, videos, cloud),
                            acceptText: "Delete", destructive: true, onAccepted: function() {
            var albumKey = album ? album._id : "";
            var spec = selection && !(album && album.virtual) ? Library.spec(selection, albumKey)
                                                              : Library.specForIds(items.map(function(i) { return i._id; }), albumKey);
            photoStore.deletePhotos([spec]);
            if (done)
                done();
        } });
    }

    // Email, the only way webOS 3.0 shared a picture.
    function share(item) {
        photoStore.withOriginal(item, function(item) {
            launchApp("com.palm.app.email", { attachments: [{ name: Library.basename(item.path), path: item.path,
                                                             fullPath: item.path, mimeType: item.mediaType === "video" ? "video/*" : "image/*" }] });
        });
    }

    // Print the whole picture, not a cloud photo's preview.
    function printPicture(item) {
        photoStore.withOriginal(item, function(item) {
            printer.printItem(item, sheet);
        });
    }

    // systemservice crops and scales the picture for the screen and hands
    // back the wallpaper to store as the preference.
    function setWallpaper(item) {
        photoStore.withOriginal(item, _setWallpaper);
    }

    function _setWallpaper(item) {
        busCall("luna://com.webos.service.systemservice/wallpaper/importWallpaper",
                JSON.stringify({ target: item.path }), function(message) {
            var r = JSON.parse(message.payload);
            if (!r.returnValue || !r.wallpaper) {
                appWindow.noticeTitle = "";
                appWindow.notice = "The picture could not be made the wallpaper.";
                return;
            }
            appWindow.busCall("luna://com.webos.service.systemservice/setPreferences",
                              JSON.stringify({ wallpaper: r.wallpaper }), function() {
                pictureView.flash("Wallpaper set");
            }, null);
        }, function(error) {
            appWindow.noticeTitle = "";
            appWindow.notice = "The picture could not be made the wallpaper: " + error;
        });
    }

    LC.ActionSheet {
        id: sheet
        objectName: "actionSheet"
        anchors.fill: parent
        z: 50
    }

    // Asks before what cannot be undone; a notice has one button
    LC.ConfirmDialog {
        id: confirmDialog
        objectName: "confirmDialog"
        anchors.fill: parent
        z: 60
        visible: false
        dialogHeight: Units.gu(22)
        dialogWidth: Math.min(Units.gu(34), parent ? parent.width - Units.gu(2) : Units.gu(34))
    }

    // An album's name, new or renamed. The dialog sizes itself to the part
    // of the window above the keyboard: anchoring it to fill the window
    // would undo that and centre it behind the keyboard.
    LC.PromptDialog {
        id: nameDialog
        objectName: "nameDialog"
        z: 60
        visible: false
        dialogHeight: Units.gu(20)
        dialogWidth: Math.min(Units.gu(34), parent ? parent.width - Units.gu(2) : Units.gu(34))
    }

    Printer {
        id: printer
        call: appWindow.busCall
        onMessage: function(text) { pictureView.flash(text); }
    }

    // --- app menu -----------------------------------------------------------------

    function openAppMenu() {
        if (!pictureView.isOpen && !slideshowView.isOpen)
            appMenu.popup(0, 0);
    }

    Menu {
        id: appMenu
        objectName: "appMenu"
        LuneOSMenu.appMenuStyle: true

        MenuItem {
            text: "New Album"
            enabled: photoStore.serviceAvailable
            onTriggered: appWindow.askNewAlbum([])
        }
        MenuItem {
            text: "Sync Now"
            enabled: photoStore.serviceAvailable
            onTriggered: photoStore.syncAll()
        }
        MenuItem {
            objectName: "keepMenuItem"
            text: "Keep on Device"
            checkable: true
            checked: !!appWindow.currentAlbum && appWindow.currentAlbum.keep === true
            // The app menu is static: greyed out where it does not apply
            enabled: photoStore.serviceAvailable && appWindow.albumId !== "" && Library.canKeep(appWindow.currentAlbum)
            onTriggered: appWindow.toggleKeep(appWindow.currentAlbum)
        }
        MenuItem {
            text: "Preferences & Accounts"
            onTriggered: prefsView.open()
        }
    }

    /* {"albumID", "pictureID"}, {"target"}, exhibition; for the tests
     * {"snapshot": "<png path>"}, a picture of the window drawn by the app. */
    LaunchParams {
        window: appWindow
        snapshotItem: root
        onLaunched: function(params) { appWindow.handleLaunch(params); }
        onAppMenuRequested: appWindow.openAppMenu()
    }

    property bool exhibitionWanted: false

    function handleLaunch(params) {
        if (!params)
            return;
        if (params.dockMode === true || params.windowType === "dockModeWindow") {
            exhibitionWanted = true;
            return;
        }
        var t = Library.launchTarget(params);
        if (t) {
            pendingLaunch = t;
            applyLaunch();
        } else if (typeof params.target === "string" && params.target !== "") {
            pendingLaunch = { path: LC.FileLists.localPath(params.target) };
            applyLaunch();
        }
    }

    // Kept until the library knows the album or the file.
    property var pendingLaunch: null
    Connections {
        target: photoStore
        function onRevisionChanged() { appWindow.applyLaunch(); }
    }

    function applyLaunch() {
        var t = pendingLaunch;
        if (!t || photoStore.status !== "ready")
            return;
        var item = null;
        if (t.path) {
            item = photoStore.itemByPath(t.path);
        } else if (t.pictureId) {
            item = photoStore.item(t.pictureId);
        }
        var album = t.albumId ? photoStore.album(t.albumId) : (item ? photoStore.album(item.albumId) : null);
        if (!album && !item)
            return;
        pendingLaunch = null;
        slideshowView.stop();
        if (album)
            openAlbum(album._id);
        if (item)
            openPicture(album ? album._id : "", item._id, false);
    }

    Loader {
        id: exhibitionLoader
        active: appWindow.exhibitionWanted
        sourceComponent: ExhibitionWindow {
            store: photoStore
            prefs: preferences
            onVisibleChanged: if (!visible) appWindow.exhibitionWanted = false
        }
    }
    property alias exhibition: exhibitionLoader

    // The picture full screen covers the status bar and gesture area too;
    // a flick up from the bottom edge still leaves it.
    readonly property bool fullScreen: pictureView.isOpen || slideshowView.isOpen
    WindowFullScreen {
        window: appWindow
        active: appWindow.fullScreen
    }

    // The screen kept on while a video plays or a slideshow runs. Needs
    // "display.operation".
    readonly property bool keepScreenOn: active && (pictureView.playing || (slideshowView.isOpen && slideshowView.running))
    KeepScreenOn {
        clientName: "org.webosports.app.photos"
        subscribe: appWindow.busSubscribe
        active: appWindow.keepScreenOn
    }

    onActiveChanged: {
        if (!active) {
            pictureView.pause();
            slideshowView.pause();
        } else {
            slideshowView.resume();
        }
    }

    FocusScope {
        id: root
        anchors.fill: parent
        focus: true

        Item {
            id: browser
            anchors.fill: parent
            visible: !pictureView.isOpen && !slideshowView.isOpen && !prefsView.isOpen

            LibraryPanel {
                id: libraryPanel
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: appWindow.wide ? Math.min(Units.gu(32), parent.width * 0.4) : parent.width
                visible: appWindow.wide || appWindow.albumId === ""
            }

            Item {
                id: content
                anchors.left: appWindow.wide ? libraryPanel.right : parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                LibraryGrid {
                    id: libraryGrid
                    anchors.fill: parent
                    visible: appWindow.wide && appWindow.albumId === ""
                }
                AlbumView {
                    id: albumView
                    anchors.fill: parent
                    album: appWindow.currentAlbum
                    visible: appWindow.albumId !== ""
                }
            }

            // What went wrong, until dismissed.
            Forms.StatusNotice {
                id: noticeBar
                objectName: "notice"
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Units.gu(1)
                visible: appWindow.notice !== ""
                title: appWindow.noticeTitle
                text: appWindow.notice
                z: 10
                onDismissed: { appWindow.notice = ""; appWindow.noticeTitle = ""; }
            }
        }

        PreferencesView {
            id: prefsView
            anchors.fill: parent
        }

        PictureView {
            id: pictureView
            anchors.fill: parent
            engineSource: appWindow.engineSource
            onClosed: root.forceActiveFocus()
        }

        SlideshowView {
            id: slideshowView
            anchors.fill: parent
            onClosed: function(lastItemId) {
                // From a picture: back on the one that was showing.
                if (pictureView.isOpen && lastItemId !== "")
                    pictureView.show(lastItemId);
                root.forceActiveFocus();
            }
        }

        // The back gesture arrives as Escape (see LunaNext.Common's
        // EventType): it closes what is open, and then the app.
        Keys.onReleased: function(event) {
            if (event.key !== Qt.Key_Escape)
                return;
            event.accepted = true;
            if (appWindow.handleBack())
                return;
            appWindow.quitRequested();
            if (appWindow.quitOnBack)
                Qt.quit();
        }
    }

    function handleBack() {
        if (sheet.back())
            return true;
        if (confirmDialog.opened) {
            confirmDialog.rejected();
            return true;
        }
        if (nameDialog.opened) {
            nameDialog.reject();
            return true;
        }
        if (slideshowView.isOpen) {
            slideshowView.stop();
            return true;
        }
        if (prefsView.handleBack())
            return true;
        if (pictureView.handleBack())
            return true;
        if (albumView.handleBack())
            return true;
        if (albumId !== "") {
            closeAlbum();
            return true;
        }
        if (source !== "all" && wide) {
            showSource("all");
            return true;
        }
        return false;
    }

    Component.onCompleted: {
        photoStore.load();
        photoStore.connect();
    }
}
