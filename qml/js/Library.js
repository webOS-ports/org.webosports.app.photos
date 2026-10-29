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
 * The library: albums and their photos and videos as the media indexer and
 * the photos service keep them in db8, put together the way webOS 3.0's
 * Photos & Videos showed them. Plain functions, tested by tst_library.
 *
 * Albums are com.palm.media.image.album:1 entries: the indexer makes one
 * per folder with pictures (the camera's DCIM is "camera://"), the photos
 * service one per cloud album and per album made in the app. Pictures are
 * com.palm.media.image.file:1 entries with the album's _id in albumId.
 * The indexer gives videos (com.palm.media.video.file:1) no album, so a
 * video goes to the album of its folder; videos in a folder without
 * pictures make an album of their own here ("video:<folder>"), which only
 * the app knows of.
 */

var cameraAlbumPath = "camera://";
var videoAlbumPrefix = "video:";

// The names webOS gave its own folders (AlbumLocalizationHackDbService).
var folderNames = {
    "/media/internal/downloads": "Downloads",
    "/media/internal/messaging": "Messaging",
    "/media/internal/screencaptures": "Screen captures",
    "/media/internal/wallpapers": "Wallpapers",
    "/usr/share/wallpapers": "Wallpapers"
};
var albumNames = {
    "miscellaneous": "Miscellaneous",
    "photo roll": "Photo roll",
    "photos": "Photos",
    "downloads": "Downloads",
    "messaging": "Messaging",
    "screencaptures": "Screen captures",
    "screen captures": "Screen captures",
    "wallpapers": "Wallpapers",
    "profile pictures": "Profile Pictures"
};

function dirname(path) {
    var s = String(path || "");
    var i = s.lastIndexOf("/");
    return i > 0 ? s.substring(0, i) : (i === 0 ? "/" : "");
}

function basename(path) {
    var s = String(path || "");
    return s.substring(s.lastIndexOf("/") + 1);
}

// "file:///a b.jpg" for an Image's source; a URL is kept as it is.
function fileUrl(path) {
    if (!path)
        return "";
    if (/^[a-z]+:\/\//i.test(path))
        return path;
    return "file://" + encodeURI(path).replace(/#/g, "%23").replace(/\?/g, "%3F");
}

// The indexer's rule for the camera's folder: DCIM in any case, directly
// under the storage root, and what is below it.
function isCameraFolder(folder, root) {
    var r = root || "/media/internal";
    var f = String(folder || "");
    if (f.toLowerCase().indexOf((r + "/dcim").toLowerCase()) !== 0)
        return false;
    var rest = f.substring(r.length + 5);
    return rest === "" || rest.charAt(0) === "/";
}

// A cloud entry (album or picture): an account's, not the device's.
function isCloud(entry) {
    return !!entry && !!entry.accountId && entry.accountId !== "local" && entry.type !== "local";
}

// The key of the photos service's capabilities for an album or a picture:
// "local" or the account's template id (which is the entry's type). webOS
// 3.0 looked the multi-select's Delete up by accountId, which no cloud
// album had capabilities under.
function capabilityKey(entry) {
    return isCloud(entry) ? String(entry.type || "") : "local";
}

function capability(caps, entry, name) {
    var c = caps ? caps[capabilityKey(entry)] : null;
    return !!(c && c[name]);
}

// "com.palm.boxnet" -> "boxnet": the last part of a template id.
function accountType(templateId) {
    var parts = String(templateId || "").split(".");
    return parts[parts.length - 1];
}

function albumTitle(album) {
    if (!album)
        return "";
    if (album.path === cameraAlbumPath)
        return "Photo roll";
    if (!isCloud(album) && folderNames[album.path])
        return folderNames[album.path];
    var name = String(album.name || "");
    if (name === "")
        return "Unnamed album";
    var known = albumNames[name.toLowerCase()];
    return known && !isCloud(album) ? known : name;
}

// The camera's album and the albums only this app knows are not renamed,
// nor cloud ones (the service renames device albums only).
function canRename(album) {
    return !!album && !album.virtual && album.path !== cameraAlbumPath && !isCloud(album);
}

// Where pictures may be added: not the camera's, not a folder of videos.
function canAddTo(album) {
    return !!album && !album.virtual && String(album.path || "").indexOf("camera:") !== 0;
}

function itemTime(item) {
    return item ? (item.createdTime || item.modifiedTime || 0) : 0;
}

// Newest first, then by name so that the order holds still.
function compareItems(a, b) {
    var d = itemTime(b) - itemTime(a);
    if (d !== 0)
        return d;
    var pa = basename(a.path), pb = basename(b.path);
    return pa < pb ? -1 : (pa > pb ? 1 : 0);
}

function compareAlbums(a, b) {
    var d = (b.modifiedTime || 0) - (a.modifiedTime || 0);
    if (d !== 0)
        return d;
    var ta = albumTitle(a).toLowerCase(), tb = albumTitle(b).toLowerCase();
    return ta < tb ? -1 : (ta > tb ? 1 : 0);
}

/*
 * The library from the db8 entries:
 *   { albums: [album...], byId: { id: album }, items: { albumId: [item...] },
 *     byItemId: { id: item } }
 * Each album gets images, videos (counts), cover (its newest item) and
 * title; albums with showAlbum false are left out, as webOS did.
 */
function build(albumEntries, imageEntries, videoEntries, root) {
    var albums = [];
    var byId = {};
    var byPath = {};
    var items = {};
    var byItemId = {};

    (albumEntries || []).forEach(function(e) {
        if (!e || !e._id || e.showAlbum === false || e.toBeDeleted === true)
            return;
        var a = {};
        for (var k in e)
            a[k] = e[k];
        a.images = 0;
        a.videos = 0;
        a.cover = null;
        a.virtual = false;
        albums.push(a);
        byId[a._id] = a;
        items[a._id] = [];
        if (!isCloud(a) && a.path)
            byPath[a.path] = a;
    });

    function add(album, item) {
        items[album._id].push(item);
        if (item.mediaType === "video")
            album.videos++;
        else
            album.images++;
        if (itemTime(item) > (album.modifiedTime || 0) && album.virtual)
            album.modifiedTime = itemTime(item);
    }

    (imageEntries || []).forEach(function(e) {
        if (!e || !e._id)
            return;
        var album = byId[e.albumId];
        if (!album)
            return;
        var item = copyItem(e, "image");
        byItemId[item._id] = item;
        add(album, item);
    });

    (videoEntries || []).forEach(function(e) {
        if (!e || !e._id || !e.path)
            return;
        var folder = dirname(e.path);
        var album = (e.albumId && byId[e.albumId]) || null;
        if (!album)
            album = isCameraFolder(folder, root) ? byPath[cameraAlbumPath] : byPath[folder];
        if (!album) {
            var path = isCameraFolder(folder, root) ? cameraAlbumPath : folder;
            var id = videoAlbumPrefix + path;
            album = byId[id];
            if (!album) {
                album = { _id: id, path: path, name: path === cameraAlbumPath ? "" : basename(folder),
                          accountId: "", type: "local", modifiedTime: 0, images: 0, videos: 0,
                          cover: null, virtual: true, showAlbum: true };
                albums.push(album);
                byId[id] = album;
                byPath[path] = album;
                items[id] = [];
            }
        }
        var item = copyItem(e, "video");
        item.albumId = album._id;
        byItemId[item._id] = item;
        add(album, item);
    });

    albums.forEach(function(a) {
        items[a._id].sort(compareItems);
        a.cover = items[a._id].length > 0 ? items[a._id][0] : null;
        a.title = albumTitle(a);
    });
    albums.sort(compareAlbums);
    return { albums: albums, byId: byId, items: items, byItemId: byItemId };
}

function copyItem(e, mediaType) {
    var item = {};
    for (var k in e)
        item[k] = e[k];
    item.mediaType = e.mediaType || mediaType;
    return item;
}

/*
 * The albums of one library: "all", "local" (the device) or an accountId.
 */
function albumsOf(albums, source) {
    if (!source || source === "all")
        return albums.slice();
    return albums.filter(function(a) {
        return source === "local" ? !isCloud(a) : a.accountId === source;
    });
}

/*
 * The libraries for the panel, from subscribeToAccountsInfo's accounts:
 * the device first, then the cloud accounts by service and name (webOS:
 * local, Facebook, templateId, alias).
 */
function libraries(accounts, deviceName) {
    var list = [];
    var cloud = [];
    for (var id in (accounts || {})) {
        var a = accounts[id];
        if (id === "local")
            continue;
        if (a && a.isEnabled === false)
            continue;
        cloud.push({ accountId: id, templateId: (a && a.templateId) || "", title: (a && a.username) || id,
                     syncStatus: (a && a.syncStatus) || "idle", type: accountType(a && a.templateId) });
    }
    cloud.sort(function(x, y) {
        var fx = x.templateId === "com.palm.facebook" ? 0 : 1;
        var fy = y.templateId === "com.palm.facebook" ? 0 : 1;
        if (fx !== fy)
            return fx - fy;
        if (x.templateId !== y.templateId)
            return x.templateId < y.templateId ? -1 : 1;
        return x.title.toLowerCase() < y.title.toLowerCase() ? -1 : (x.title.toLowerCase() > y.title.toLowerCase() ? 1 : 0);
    });
    var local = accounts && accounts.local;
    list.push({ accountId: "local", templateId: "", title: deviceName || "My Device",
                syncStatus: (local && local.syncStatus) || "idle", type: "local" });
    return list.concat(cloud);
}

// subscribeToAccountsInfo's later answers carry one account; merges it.
function mergeAccounts(accounts, update) {
    var out = {};
    var k;
    if (update && update.accounts) {
        for (k in update.accounts)
            out[k] = update.accounts[k];
        return out;
    }
    for (k in (accounts || {}))
        out[k] = accounts[k];
    if (update && update.accountId) {
        var a = {};
        var before = out[update.accountId] || {};
        for (k in before)
            a[k] = before[k];
        for (k in update)
            if (k !== "returnValue")
                a[k] = update[k];
        out[update.accountId] = a;
    }
    return out;
}

function isSyncing(account) {
    return !!account && !!account.syncStatus && account.syncStatus !== "idle";
}

function plural(n, one, many) {
    return n === 1 ? one : many.replace("#{num}", n);
}

function imagesLabel(n) {
    return plural(n, "1 image", "#{num} images");
}

function videosLabel(n) {
    return plural(n, "1 video", "#{num} videos");
}

function countLabel(album) {
    if (!album)
        return "";
    var parts = [];
    if (album.images > 0 || album.videos === 0)
        parts.push(imagesLabel(album.images));
    if (album.videos > 0)
        parts.push(videosLabel(album.videos));
    return parts.join(", ");
}

/*
 * What the delete dialog says (webOS 3.0's AlbumModeMultiselectControls and
 * PictureMode, with webos-synergy-revival's words for a cloud account,
 * which deletes from the account itself).
 */
function deleteMessage(images, videos, cloud) {
    var count = images + videos;
    if (cloud) {
        if (count === 1)
            return videos === 1 ? "This permanently deletes the video from your cloud account. It can't be undone."
                                : "This permanently deletes the photo from your cloud account. It can't be undone.";
        return "This permanently deletes the selected photos from your cloud account. It can't be undone.";
    }
    if (count === 1)
        return videos === 1 ? "Are you sure you want to delete this video?" : "Are you sure you want to delete this image?";
    if (videos === 0)
        return "Are you sure you want to delete these " + count + " images?";
    if (images === 0)
        return "Are you sure you want to delete these " + count + " videos?";
    return "Are you sure you want to delete these " + count + " items?";
}

/*
 * A selection in an album: the ids picked or, after Select All, the ids
 * left out ("inverted"), as webOS's PhotoSelection kept it.
 */
function newSelection() {
    return { inverted: false, keys: {} };
}

function isSelected(sel, id) {
    var has = !!(sel && sel.keys[id]);
    return sel && sel.inverted ? !has : has;
}

function toggle(sel, id) {
    var keys = {};
    for (var k in sel.keys)
        keys[k] = true;
    if (keys[id])
        delete keys[id];
    else
        keys[id] = true;
    return { inverted: sel.inverted, keys: keys };
}

function selectAll(all) {
    return { inverted: all === true, keys: {} };
}

function selectedItems(sel, items) {
    return (items || []).filter(function(i) { return isSelected(sel, i._id); });
}

function selectedCount(sel, total) {
    var n = Object.keys(sel.keys).length;
    return sel.inverted ? total - n : n;
}

// The photos service's spec for a selection of an album: by its ids or, all
// but some, with "exclude".
function spec(sel, albumId, targetAlbum) {
    var s = { sourceAlbum: (albumId && albumId.indexOf(videoAlbumPrefix) !== 0) ? albumId : null,
              photos: Object.keys(sel.keys), exclude: sel.inverted };
    if (targetAlbum !== undefined)
        s.targetAlbum = targetAlbum;
    return s;
}

// The spec for given ids (a virtual album cannot be named to the service,
// so its selections are sent as the ids themselves).
function specForIds(ids, albumId, targetAlbum) {
    return spec({ inverted: false, keys: ids.reduce(function(m, id) { m[id] = true; return m; }, {}) },
                albumId, targetAlbum);
}

// The albums "Add to Album" offers: those pictures can go into, without the
// current one; only device albums for a video (webOS's LocalAlbumPicker).
function targetAlbums(albums, currentId, hasVideo) {
    return albums.filter(function(a) {
        return a._id !== currentId && canAddTo(a) && (!hasVideo || !isCloud(a));
    });
}

/*
 * Pictures: the screen-size copy when the service made one, else the
 * file. The grid's thumbnail when it is big enough for the cell.
 */
function viewPath(item) {
    if (!item)
        return "";
    if (item.appScreenNail && item.appScreenNail.path)
        return item.appScreenNail.path;
    return item.path || item.appOriginal || "";
}

function thumbnailPath(item, cellPixels) {
    if (!item)
        return "";
    var t = item.appGridThumbnail;
    if (t && t.path) {
        var d = t.dimensions || {};
        var w = d["output-width"] || 0;
        var h = d["output-height"] || 0;
        // The indexer makes them gridUnit * 8 wide: on a large cell the file
        // itself, scaled down, looks better. 0x0: written by an older one.
        if (!cellPixels || Math.max(w, h) >= cellPixels * 0.75 || (w === 0 && h === 0 && item.mediaType === "video"))
            return t.path;
    }
    return item.mediaType === "video" ? "" : (item.path || item.appOriginal || "");
}

// "1:05", "1:02:03"
function formatDuration(seconds) {
    var s = Math.max(0, Math.floor(seconds || 0));
    var h = Math.floor(s / 3600);
    var m = Math.floor((s % 3600) / 60);
    var r = s % 60;
    var mm = h > 0 && m < 10 ? "0" + m : String(m);
    return (h > 0 ? h + ":" : "") + mm + ":" + (r < 10 ? "0" : "") + r;
}

var monthNames = ["January", "February", "March", "April", "May", "June", "July", "August",
                  "September", "October", "November", "December"];

// "October 8, 2026" from seconds since the epoch.
function formatDate(seconds) {
    if (!(seconds > 0))
        return "";
    var d = new Date(seconds * 1000);
    return monthNames[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear();
}

// A comment's time, as webOS's PictureComments said it.
function relativeTime(seconds, nowSeconds) {
    var diff = Math.max(0, Math.floor((nowSeconds || 0) - (seconds || 0)));
    if (diff < 60)
        return "Just now";
    var min = Math.floor(diff / 60);
    if (min < 60)
        return min === 1 ? "1 minute ago" : min + " minutes ago";
    var hour = Math.floor(min / 60);
    if (hour < 24)
        return hour === 1 ? "1 hour ago" : hour + " hours ago";
    var day = Math.floor(hour / 24);
    return day === 1 ? "1 day ago" : day + " days ago";
}

// The photos service's error codes (webOS's PhotosAndVideosService).
var serviceErrors = ["Unknown error", "Unable to access database", "Unable to merge details into database",
                     "Unable to add entry to database", "Unable to delete entry from database",
                     "Unable to fetch data from database", "Network error", "Syncing failed",
                     "Remote service failed to respond", "File-copy failed"];

function serviceError(reply) {
    if (!reply)
        return serviceErrors[0];
    if (typeof reply.errorCode === "number" && serviceErrors[reply.errorCode])
        return serviceErrors[reply.errorCode];
    var text = reply.msg || reply.error || reply.errorText || reply.response;
    return typeof text === "string" && text !== "" ? text : serviceErrors[0];
}

/*
 * Slideshow: the pictures of the albums (videos left out), in album order
 * then oldest first, as webOS's SlideshowPlayList played them.
 */
function slideshowPlaylist(lib, albumIds) {
    var out = [];
    albumIds.forEach(function(id) {
        var list = (lib.items[id] || []).filter(function(i) { return i.mediaType !== "video"; });
        out = out.concat(list.slice().reverse());
    });
    return out;
}

// The albums a slideshow over the whole library plays: those with pictures.
function slideshowAlbums(albums, selectedIds) {
    var withImages = albums.filter(function(a) { return a.images > 0; });
    var chosen = withImages.filter(function(a) { return selectedIds && selectedIds.indexOf(a._id) >= 0; });
    return (chosen.length > 0 ? chosen : withImages).map(function(a) { return a._id; });
}

// Fisher-Yates, with the random source given for the tests.
function shuffled(list, random) {
    var r = random || Math.random;
    var out = list.slice();
    for (var i = out.length - 1; i > 0; i--) {
        var j = Math.floor(r() * (i + 1));
        var t = out[i];
        out[i] = out[j];
        out[j] = t;
    }
    return out;
}

// Next and previous go round at the ends.
function wrap(index, count) {
    if (count <= 0)
        return 0;
    return ((index % count) + count) % count;
}

var slideshowIntervals = [
    { label: "5 seconds", ms: 5000 },
    { label: "10 seconds", ms: 10000 },
    { label: "30 seconds", ms: 30000 },
    { label: "1 minute", ms: 60000 },
    { label: "5 minutes", ms: 300000 },
    { label: "30 minutes", ms: 1800000 },
    { label: "1 hour", ms: 3600000 }
];

/*
 * Where a picture shown full screen goes when it is deleted: the one after
 * it, or the one before at the end, or nowhere (-1).
 */
function indexAfterRemoval(items, removedId, oldIndex) {
    if (!items || items.length === 0)
        return -1;
    for (var i = 0; i < items.length; i++)
        if (items[i]._id === removedId)
            return i;
    return Math.min(Math.max(oldIndex, 0), items.length - 1);
}

// An album name the user typed: trimmed, not empty, one path component.
function validAlbumName(name) {
    var n = String(name || "").trim();
    return n !== "" && n !== "." && n !== ".." && !/[\/\u0000]/.test(n);
}

// Launch parameters (webOS's albumID and pictureID).
function launchTarget(params) {
    if (!params)
        return null;
    var album = typeof params.albumID === "string" && params.albumID !== "" ? params.albumID : null;
    var picture = typeof params.pictureID === "string" && params.pictureID !== "" ? params.pictureID : null;
    if (!album && !picture)
        return null;
    return { albumId: album, pictureId: picture };
}
