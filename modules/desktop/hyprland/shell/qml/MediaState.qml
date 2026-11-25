import QtQuick
import Quickshell.Services.Mpris
import "MediaSelection.js" as Selection

QtObject {
    id: media

    required property AppearancePreferences appearance
    readonly property int seekSeconds: appearance.mediaSeekSeconds
    readonly property int seekIntervalIndex: appearance.seekIntervals.indexOf(seekSeconds)
    readonly property bool canDecreaseSeekInterval: seekIntervalIndex > 0
    readonly property bool canIncreaseSeekInterval: seekIntervalIndex >= 0 && seekIntervalIndex < appearance.seekIntervals.length - 1

    readonly property var players: Mpris.players.values
    property string preferredPlayerId: ""
    readonly property var player: selectPlayer()

    readonly property bool available: player !== null
    readonly property bool playing: available && player.isPlaying
    readonly property bool canTogglePlaying: available && (player.isPlaying ? player.canPause : player.canPlay)
    readonly property bool canGoNext: available && player.canGoNext
    readonly property bool canGoPrevious: available && player.canGoPrevious

    readonly property string title: available ? (player.trackTitle || "Unknown track") : ""
    readonly property string artist: available ? (player.trackArtist || player.identity || "Unknown artist") : ""
    readonly property string album: available ? (player.trackAlbum || "") : ""
    readonly property string artUrl: available ? (player.trackArtUrl || "") : ""
    readonly property string identity: available ? (player.identity || "") : ""
    // Optional local .lrc sidecar. A remote MPRIS URI is never fetched, and
    // neither the title nor audio is sent to a lyrics service.
    readonly property string lyricsPath: {
        const source = available && player.metadata ? String(player.metadata["xesam:url"] || "") : "";
        if (!source.startsWith("file:///"))
            return "";
        const filePath = decodeURIComponent(source.slice(7).split(/[?#]/)[0]);
        return /\.[^/.]+$/.test(filePath) ? filePath.replace(/\.[^/.]+$/, ".lrc") : "";
    }

    readonly property real position: available && player.positionSupported ? player.position : 0
    readonly property real length: available && player.lengthSupported ? player.length : 0
    readonly property bool seekable: available && player.canSeek && player.positionSupported && player.lengthSupported
    readonly property string persistentPreference: appearance.mediaPreferredPlayer
    readonly property bool preferredCurrent: available && persistentPreference !== "" && stablePlayerId(player) === persistentPreference
    readonly property bool canRaise: available && player.canRaise
    readonly property bool rateAvailable: available && player.canControl && [player.rate, player.minRate, player.maxRate].every(Number.isFinite) && player.minRate < player.maxRate && player.rate !== 0 && player.rate >= player.minRate && player.rate <= player.maxRate
    readonly property real rate: rateAvailable ? player.rate : 1
    onPlayersChanged: {
        if (preferredPlayerId !== "" && !players.some(candidate => playerId(candidate) === preferredPlayerId))
            preferredPlayerId = "";
    }

    function stablePlayerId(candidate: var): string {
        return Selection.stablePlayerId(candidate);
    }

    function useAutomaticSelection(): void {
        preferredPlayerId = "";
        appearance.setMediaPreferredPlayer("");
    }

    function preferCurrentPlayer(): void {
        if (!available)
            return;
        const identity = stablePlayerId(player);
        if (identity) {
            preferredPlayerId = "";
            appearance.setMediaPreferredPlayer(identity);
        }
    }

    function resetPreferredPlayer(): void {
        preferredPlayerId = "";
        appearance.resetMediaPreferredPlayer();
    }

    function adjustRate(delta: real): void {
        if (!rateAvailable)
            return;
        const next = Selection.adjustedRate(rate, player.minRate, player.maxRate, delta);
        if (next !== rate)
            player.rate = next;
    }

    readonly property int playerCount: players.length
    readonly property int selectedPlayerIndex: available ? players.indexOf(player) : -1
    readonly property bool shuffleAvailable: available && player.shuffleSupported
    readonly property bool shuffled: shuffleAvailable && player.shuffle
    readonly property bool repeatAvailable: available && player.loopSupported
    readonly property int repeatState: repeatAvailable ? player.loopState : MprisLoopState.None
    readonly property string repeatLabel: repeatState === MprisLoopState.Track ? "ONE" : repeatState === MprisLoopState.Playlist ? "ALL" : "OFF"

    function playerId(candidate): string {
        return Selection.playerId(candidate);
    }

    function selectPlayer(): var {
        return Selection.choosePlayer(players, preferredPlayerId, persistentPreference);
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

    function raisePlayer(): void {
        if (canRaise)
            player.raise();
    }

    function togglePlaying(): void {
        if (!canTogglePlaying)
            return;

        if (player.isPlaying) {
            if (player.canPause)
                player.pause();
        } else if (player.canPlay) {
            player.play();
        }
    }

    function next(): void {
        if (canGoNext)
            player.next();
    }

    function previous(): void {
        if (canGoPrevious)
            player.previous();
    }

    function seek(seconds: real): void {
        if (available && player.canSeek)
            player.seek(seconds);
    }

    function seekStep(direction: int): void {
        seek(direction * seekSeconds);
    }

    function adjustSeekStep(direction: int): void {
        appearance.adjustMediaSeek(direction);
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

    function toggleRepeat(): void {
        if (!repeatAvailable)
            return;
        player.loopState = repeatState === MprisLoopState.None ? MprisLoopState.Playlist : repeatState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
    }

    function refreshPosition(): void {
        if (available && player.positionSupported)
            player.positionChanged();
    }
}
