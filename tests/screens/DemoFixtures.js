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

.pragma library

/*
 * The db8 entries of the demo library that tools/make-demo-library.sh puts
 * in build/demo (ROOT): the camera's album (two pictures and a video), Nature,
 * Night Sky, and a Dropbox account's Camera Uploads. The README's screenshots
 * are taken of it (tst_screens.qml).
 */

var ROOT = "";

function pic(id, album, file, time, type) {
    var e = { _id: id, albumId: album, path: ROOT + "/pictures/" + file, mediaType: "image",
              type: type || "local", createdTime: time, appCacheComplete: true };
    if (type) {
        e.accountId = "acc-dropbox";
        e[type] = { pid: "id:" + id };
    }
    return e;
}

function albums() {
    return [
        { _id: "alb-camera", path: "camera://", name: "", accountId: "", type: "local", showAlbum: true,
          modifiedTime: 1791430579, total: { images: 2 } },
        { _id: "alb-nature", path: ROOT + "/pictures/Nature", name: "Nature", accountId: "", type: "local",
          showAlbum: true, modifiedTime: 1791351651, total: { images: 4 } },
        { _id: "alb-night", path: ROOT + "/pictures/Night Sky", name: "Night Sky", accountId: "", type: "local",
          showAlbum: true, modifiedTime: 1791251651, total: { images: 2 } },
        { _id: "alb-dropbox", path: "/media/internal/.photosApp/com.palm.dropbox/me/Camera Uploads",
          name: "Camera Uploads", accountId: "acc-dropbox", type: "com.palm.dropbox", aid: "/Camera Uploads",
          showAlbum: true, modifiedTime: 1791400000, total: { images: 2 } }
    ];
}

function images() {
    return [
        pic("img-c1", "alb-camera", "DCIM/moonrise.jpg", 1791430500),
        pic("img-c2", "alb-camera", "DCIM/orangesunset.jpg", 1791430560),
        pic("img-n1", "alb-nature", "Nature/plant.jpg", 1791351600),
        pic("img-n2", "alb-nature", "Nature/iceplant.jpg", 1791351500),
        pic("img-n3", "alb-nature", "Nature/butterfly.jpg", 1791351400),
        pic("img-n4", "alb-nature", "Nature/bubbles.jpg", 1791351300),
        pic("img-s1", "alb-night", "Night Sky/milkyway.jpg", 1791251600),
        pic("img-s2", "alb-night", "Night Sky/iceveins.jpg", 1791251500),
        pic("img-d1", "alb-dropbox", "cloud/wyoming.jpg", 1791400000, "com.palm.dropbox"),
        pic("img-d2", "alb-dropbox", "cloud/snowtracks.jpg", 1791399000, "com.palm.dropbox")
    ];
}

function videos() {
    return [
        { _id: "vid-c", albumId: "", albumPath: "", path: ROOT + "/pictures/DCIM/2026-10-08-05-38-22.mp4",
          mediaType: "video", type: "local", createdTime: 1791430600, duration: 42, lastPlayTime: 0,
          appGridThumbnail: { path: ROOT + "/thumbs/video-poster.jpg",
                              dimensions: { "output-width": 960, "output-height": 540 } } }
    ];
}
