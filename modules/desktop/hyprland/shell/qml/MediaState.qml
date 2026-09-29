import QtQuick
import Quickshell.Services.Mpris

QtObject {
    id: media

    readonly property var players: Mpris.players.values
    readonly property var player: selectPlayer()

    readonly property bool available: player !== null
    readonly property bool playing: available && player.isPlaying

    readonly property string title: available ? (player.trackTitle || "Unknown track") : ""
    readonly property string artist: available ? (player.trackArtist || player.identity || "Unknown artist") : ""
    readonly property string album: available ? (player.trackAlbum || "") : ""
    readonly property string artUrl: available ? (player.trackArtUrl || "") : ""
    readonly property string identity: available ? (player.identity || "") : ""
    readonly property real position: available && player.positionSupported ? player.position : 0
    readonly property real length: available && player.lengthSupported ? player.length : 0

    function selectPlayer(): var {
        if (players.length === 0)
            return null;

        for (const candidate of players) {
            if (candidate.isPlaying)
                return candidate;
        }

        for (const candidate of players) {
            if (candidate.trackTitle && candidate.trackTitle.length > 0)
                return candidate;
        }

        return players[0];
    }

    function togglePlaying(): void {
        if (available && player.canTogglePlaying)
            player.togglePlaying();
    }

    function next(): void {
        if (available && player.canGoNext)
            player.next();
    }

    function previous(): void {
        if (available && player.canGoPrevious)
            player.previous();
    }

    function seek(seconds: real): void {
        if (available && player.canSeek)
            player.seek(seconds);
    }

    function refreshPosition(): void {
        if (available && player.positionSupported)
            player.positionChanged();
    }
}
