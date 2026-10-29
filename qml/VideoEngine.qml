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
import QtMultimedia

/*
 * One video playing: Qt Multimedia's MediaPlayer with its picture and
 * sound, behind the small interface the full-screen view uses (the tests
 * put a stand-in with the same one in its place:
 * tests/qml/mocks/FakeEngine.qml).
 */
Item {
    id: engine

    property url source
    // The picture over the whole area, cropped, rather than all of it.
    property bool fill: false
    readonly property bool playing: player.playbackState === MediaPlayer.PlayingState
    readonly property bool ended: player.mediaStatus === MediaPlayer.EndOfMedia
    readonly property int position: player.position
    readonly property int duration: player.duration
    readonly property bool seekable: player.seekable
    property string errorText: ""

    function play() { player.play(); }
    function pause() { player.pause(); }
    function stop() { player.stop(); }
    // Before the file is loaded a seek is kept and made once it is.
    property int _pendingSeek: -1
    function seek(ms) {
        if (player.mediaStatus === MediaPlayer.LoadingMedia || player.mediaStatus === MediaPlayer.NoMedia)
            _pendingSeek = ms;
        else
            player.position = ms;
    }

    onSourceChanged: errorText = ""

    VideoOutput {
        id: output
        anchors.fill: parent
        fillMode: engine.fill ? VideoOutput.PreserveAspectCrop : VideoOutput.PreserveAspectFit
    }

    MediaPlayer {
        id: player
        source: engine.source
        videoOutput: output
        audioOutput: AudioOutput { }
        onMediaStatusChanged: {
            if (engine._pendingSeek >= 0 && mediaStatus !== MediaPlayer.LoadingMedia && mediaStatus !== MediaPlayer.NoMedia) {
                position = engine._pendingSeek;
                engine._pendingSeek = -1;
            }
        }
        onErrorOccurred: function(error, errorString) {
            // webOS said "Video is corrupted" for a decoding error.
            engine.errorText = error === MediaPlayer.FormatError ? "Video is corrupted"
                             : (errorString !== "" ? errorString : "This video cannot be played.");
        }
    }
}
