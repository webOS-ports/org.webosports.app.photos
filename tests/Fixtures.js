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
 * The db8 entries of the test library, as the media indexer and the photos
 * service write them, over the files in tests/data (root): the camera's
 * album (two pictures, a video in DCIM), Holiday (pictures, a broken file,
 * a video), Movies (a folder with only a video), an empty album, a hidden
 * album, and a Dropbox account's album with one picture.
 */

function albums() {
    return [
        { _id: "alb-camera", path: "camera://", name: "", accountId: "", type: "local", showAlbum: true,
          modifiedTime: 1791430579, total: { images: 2 } },
        { _id: "alb-holiday", path: ROOT + "/pictures/Holiday", name: "Holiday", accountId: "", type: "local",
          showAlbum: true, modifiedTime: 1791351651, total: { images: 4 } },
        { _id: "alb-empty", path: "/media/internal/Empty", name: "Empty", accountId: "", type: "local",
          showAlbum: true, modifiedTime: 1791000000, total: { images: 0 } },
        { _id: "alb-hidden", path: "/media/internal/Hidden", name: "Hidden", accountId: "", type: "local",
          showAlbum: false, modifiedTime: 1791500000 },
        { _id: "alb-shots", path: "/media/internal/screencaptures", name: "screencaptures", accountId: "",
          type: "local", showAlbum: true, modifiedTime: 1790000000, total: { images: 0 } },
        { _id: "alb-dropbox", path: "/media/internal/.photosApp/com.palm.dropbox/me/Camera Uploads",
          name: "Camera Uploads", accountId: "acc-dropbox", type: "com.palm.dropbox", aid: "/Camera Uploads",
          showAlbum: true, modifiedTime: 1791400000, total: { images: 1 } }
    ];
}

function images() {
    return [
        { _id: "img-c1", albumId: "alb-camera", path: ROOT + "/pictures/DCIM/2026-10-08-05-36-18.jpg",
          mediaType: "image", type: "local", createdTime: 1791430500, appCacheComplete: true,
          appGridThumbnail: { path: ROOT + "/thumbs/small-thumb.jpg", cached: true,
                              dimensions: { "output-width": 80, "output-height": 60 } } },
        { _id: "img-c2", albumId: "alb-camera", path: ROOT + "/pictures/DCIM/2026-10-08-05-37-19.jpg",
          mediaType: "image", type: "local", createdTime: 1791430560, appCacheComplete: true },
        { _id: "img-h1", albumId: "alb-holiday", path: ROOT + "/pictures/Holiday/beach.jpg", mediaType: "image",
          type: "local", createdTime: 1791351600, appCacheComplete: true },
        { _id: "img-h2", albumId: "alb-holiday", path: ROOT + "/pictures/Holiday/forest.png", mediaType: "image",
          type: "local", createdTime: 1791351500, appCacheComplete: true },
        { _id: "img-h3", albumId: "alb-holiday", path: ROOT + "/pictures/Holiday/panorama.jpg", mediaType: "image",
          type: "local", modifiedTime: 1791351400, appCacheComplete: true },
        { _id: "img-h4", albumId: "alb-holiday", path: ROOT + "/pictures/Holiday/broken.jpg", mediaType: "image",
          type: "local", createdTime: 1791351300, appCacheComplete: true },
        { _id: "img-x", albumId: "alb-hidden", path: "/media/internal/Hidden/x.jpg", mediaType: "image",
          type: "local", createdTime: 1 },
        { _id: "img-d1", albumId: "alb-dropbox", path: ROOT + "/pictures/cloud/IMG_0001.jpg", mediaType: "image",
          type: "com.palm.dropbox", accountId: "acc-dropbox", createdTime: 1791400000,
          appCacheComplete: true, "com.palm.dropbox": { pid: "id:abc" } }
    ];
}

function videos() {
    return [
        { _id: "vid-c", albumId: "", albumPath: "", path: ROOT + "/pictures/DCIM/2026-10-08-05-38-22.mp4",
          mediaType: "video", type: "local", createdTime: 1791430600, duration: 0, lastPlayTime: 0,
          appGridThumbnail: { path: ROOT + "/thumbs/video-poster.jpg",
                              dimensions: { "output-width": 0, "output-height": 0 } } },
        { _id: "vid-h", albumId: "", albumPath: "", path: ROOT + "/pictures/Holiday/clip.mp4", mediaType: "video",
          type: "local", createdTime: 1791351550, duration: 95, lastPlayTime: 30 },
        { _id: "vid-m", albumId: "", albumPath: "", path: ROOT + "/Movies/film.mkv", mediaType: "video",
          type: "local", createdTime: 1791000500, duration: 5400, lastPlayTime: 0 }
    ];
}

var ROOT = "";
