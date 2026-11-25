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

// MPRIS Rate must be nonzero and within the player's advertised range.
// Crossing zero is valid for a player that supports reverse playback.
function adjustedRate(rate, minRate, maxRate, delta) {
  if (
    ![rate, minRate, maxRate, delta].every(Number.isFinite) ||
    minRate >= maxRate ||
    rate === 0 ||
    rate < minRate ||
    rate > maxRate ||
    delta === 0
  )
    return rate;
  const bounded = (value) => Math.max(minRate, Math.min(maxRate, value));
  const step = (value) => Math.round(value * 100) / 100;
  let next = bounded(step(rate + delta));
  if (next === 0) next = bounded(step(rate + delta * 2));
  return next === 0 ? rate : next;
}
