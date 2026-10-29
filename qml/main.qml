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
        onFailed: function(title, detail) {
            appWindow.noticeTitle = title;
            appWindow.notice = detail;
        }
        onRevisionChanged: appWindow.checkCurrent()
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

    function libraryAlbums() {
        return Library.albumsOf(photoStore.lib.albums, source);
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
            return { label: a.title, key: a._id };
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
        launchApp("com.palm.app.email", { attachments: [{ name: Library.basename(item.path), path: item.path,
                                                         fullPath: item.path, mimeType: item.mediaType === "video" ? "video/*" : "image/*" }] });
    }

    // systemservice crops and scales the picture for the screen and hands
    // back the wallpaper to store as the preference.
    function setWallpaper(item) {
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

    // An album's name, new or renamed
    LC.PromptDialog {
        id: nameDialog
        objectName: "nameDialog"
        anchors.fill: parent
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
            text: "Preferences & Accounts"
            onTriggered: appWindow.launchApp("com.palm.app.accounts", {})
        }
    }

    /* {"albumID", "pictureID"}, {"target"}, exhibition; for the tests
     * {"snapshot": "<png path>"}, a picture of the window drawn by the app. */
    LaunchParams {
        window: appWindow
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
        if (typeof params.snapshot === "string" && params.snapshot.charAt(0) === "/")
            snapshot(params.snapshot);
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

    function snapshot(path) {
        root.grabToImage(function(result) { result.saveToFile(path); });
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

    /*
     * The picture full screen covers the status bar and gesture area too
     * (luna-next-cardshell's "LuneOS_fullscreen" window property, as Videos
     * does; a flick up from the bottom edge still leaves it).
     */
    readonly property bool fullScreen: pictureView.isOpen || slideshowView.isOpen
    onFullScreenChanged: setWindowProperty("LuneOS_fullscreen", fullScreen ? "true" : "false")

    /*
     * The screen kept on while a video plays or a slideshow runs:
     * luna-displaymanager's "requestBlock" for as long as the call stays
     * open. Needs "display.operation".
     */
    readonly property bool keepScreenOn: active && (pictureView.playing || (slideshowView.isOpen && slideshowView.running))
    property var screenBlockCall: null
    onKeepScreenOnChanged: {
        if (keepScreenOn && !screenBlockCall) {
            screenBlockCall = appWindow.busSubscribe("luna://com.palm.display/control/setProperty",
                                                JSON.stringify({ "requestBlock": true, "client": "org.webosports.app.photos" }),
                                                function() {},
                                                function(error) { console.warn("Could not keep the screen on: " + error); })
                              || ({});
        } else if (!keepScreenOn && screenBlockCall) {
            if (typeof screenBlockCall.cancel === "function")
                screenBlockCall.cancel();
            screenBlockCall = null;
        }
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
            visible: !pictureView.isOpen && !slideshowView.isOpen

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
        if (pictureView.handleBack())
            return true;
        if (albumView.handleBack())
            return true;
        if (albumId !== "") {
            albumId = "";
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
