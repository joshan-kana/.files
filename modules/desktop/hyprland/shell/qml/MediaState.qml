import QtQuick
import Quickshell.Services.Mpris

QtObject {
    id: media

    readonly property var players: Mpris.players.values
    property string preferredPlayerId: ""
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
    readonly property bool seekable: available && player.canSeek && player.positionSupported && player.lengthSupported

    function playerId(candidate): string {
        if (!candidate)
            return "";

        return candidate.dbusName || candidate.uniqueId || candidate.identity || "";
    }

    function selectPlayer(): var {
        if (players.length === 0)
            return null;

        if (preferredPlayerId.length > 0) {
            for (const candidate of players) {
                if (playerId(candidate) === preferredPlayerId)
                    return candidate;
            }
        }

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

    function cyclePlayer(): void {
        if (players.length === 0) {
            preferredPlayerId = "";
            return;
        }

        const current = player;
        const index = players.indexOf(current);
        const nextIndex = index < 0 ? 0 : (index + 1) % players.length;
        preferredPlayerId = playerId(players[nextIndex]);
    }

    function togglePlaying(): void {
        if (!available)
            return;

        if (player.isPlaying) {
            if (player.canPause)
                player.pause();
        } else if (player.canPlay) {
            player.play();
        }
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

    function seekTo(seconds: real): void {
        if (!available || !player.canSeek || !player.positionSupported || !player.lengthSupported)
            return;

        player.position = Math.max(0, Math.min(player.length, seconds));
    }

    function toggleShuffle(): void {
        if (available && player.shuffleSupported)
            player.shuffle = !player.shuffle;
    }

    function refreshPosition(): void {
        if (available && player.positionSupported)
            player.positionChanged();
    }
}
