function stablePlayerId(candidate) {
  return candidate
    ? candidate.desktopEntry ||
        candidate.identity ||
        (candidate.dbusName || "").split(".instance")[0]
    : "";
}

function playerId(candidate) {
  return candidate
    ? candidate.dbusName || candidate.uniqueId || candidate.identity || ""
    : "";
}

function choosePlayer(players, sessionChoice, persistentChoice) {
  if (!players.length) return null;
  const selected = players.find(
    (candidate) =>
      playerId(candidate) === sessionChoice && sessionChoice !== "",
  );
  if (selected) return selected;
  const preferred = persistentChoice
    ? players.filter(
        (candidate) => stablePlayerId(candidate) === persistentChoice,
      )
    : [];
  if (preferred.length)
    return preferred.find((candidate) => candidate.isPlaying) || preferred[0];
  return (
    players.find((candidate) => candidate.isPlaying) ||
    players.find(
      (candidate) => candidate.trackTitle && candidate.trackTitle.length > 0,
    ) ||
    players[0]
  );
}
