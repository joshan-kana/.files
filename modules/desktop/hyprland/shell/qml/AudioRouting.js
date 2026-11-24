// Stereo balance only: never reinterpret multichannel or mono devices.
function stereoIndices(channels, left, right) {
  if (!channels || channels.length !== 2) return null;
  const l = channels.indexOf(left);
  const r = channels.indexOf(right);
  return l >= 0 && r >= 0 ? [l, r] : null;
}

function balance(volumes, indices) {
  if (!indices || !volumes || volumes.length !== 2) return 0;
  const l = volumes[indices[0]];
  const r = volumes[indices[1]];
  return Math.max(l, r) > 0 ? (r - l) / Math.max(l, r) : 0;
}

function balancedVolumes(volumes, indices, position) {
  if (
    !indices ||
    !volumes ||
    volumes.length !== 2 ||
    !Number.isFinite(position)
  )
    return null;
  const peak = Math.max(...volumes);
  const value = Math.max(-1, Math.min(1, position));
  const result = [...volumes];
  result[indices[0]] = peak * (1 - Math.max(0, value));
  result[indices[1]] = peak * (1 + Math.min(0, value));
  return result;
}

function linkedDevice(groups, stream, capture) {
  if (!stream) return null;
  for (const group of groups) {
    const endpoint = capture ? group.source : group.target;
    const other = capture ? group.target : group.source;
    if (
      other &&
      other.id === stream.id &&
      endpoint &&
      !endpoint.isStream &&
      endpoint.audio
    )
      return endpoint;
  }
  return null;
}
