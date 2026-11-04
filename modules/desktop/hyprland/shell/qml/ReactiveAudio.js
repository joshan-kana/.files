// One event-driven reactive state, shared by every surface. The analyser
// already publishes 96 bands; this stage extracts musical movement without
// allocating an additional audio pipeline.
function clamp(value) {
  return Math.max(0, Math.min(1, Number.isFinite(value) ? value : 0));
}

function approach(current, target, seconds, rate) {
  return (
    current + (target - current) * (1 - Math.exp(-Math.max(0, seconds) * rate))
  );
}

function advanceAudio(state, frame, seconds) {
  const dt = Math.max(0.001, Math.min(0.08, seconds));
  const level = clamp(Math.max(frame.rms, frame.peak * 0.35));
  const present = clamp((level - 0.003) / 0.032);
  const sub = clamp(frame.sub);
  const bass = clamp(frame.bass);
  const mid = clamp(frame.mid);
  const high = clamp(frame.high);
  const peak = clamp(frame.peak);

  // The slow amplitude baseline learns an ongoing 808 rather than treating
  // its level as a new beat. Kick attacks are identified independently.
  if (!state.baselineReady && present > 0.02) {
    state.bassBaseline = bass;
    state.peakBaseline = peak;
    state.rmsBaseline = level;
    state.midBaseline = mid;
    state.fluxBaseline = 0;
    state.baselineReady = true;
  }

  // Sub-bass below 60 Hz is deliberately excluded from onset detection.
  // Kick punches contain transients in 60-250 Hz and 250-2000 Hz even when
  // a sustained 30-60 Hz 808 is much louder.
  const bands = frame.bands || [];
  const previous = state.previousBands;
  if (previous.length !== bands.length) {
    previous.length = bands.length;
    for (let i = 0; i < bands.length; ++i)
      previous[i] = Math.sqrt(clamp(bands[i] || 0));
  }
  let punch = 0,
    attack = 0,
    punchBins = 0,
    attackBins = 0;
  const lower = Math.max(1, frame.lowHz || 20);
  const upper = Math.max(lower + 1, frame.highHz || 20000);
  const logSpan = Math.log(upper / lower);
  for (let i = 0; i < bands.length; ++i) {
    const hz = lower * Math.exp(logSpan * (i / Math.max(1, bands.length - 1)));
    const value = Math.sqrt(clamp(bands[i]));
    const rise = Math.max(0, value - (previous[i] || 0));
    previous[i] = value;
    if (hz >= 60 && hz < 250) {
      punch += rise;
      ++punchBins;
    } else if (hz >= 250 && hz < 2100) {
      attack += rise;
      ++attackBins;
    }
  }
  const flux =
    (0.62 * punch) / Math.max(1, punchBins) +
    (0.38 * attack) / Math.max(1, attackBins);
  const relativeBass = Math.max(0, bass - state.bassBaseline);
  const relativePeak = Math.max(0, peak - state.peakBaseline);
  const relativeRms = Math.max(0, level - state.rmsBaseline);
  const novelty = Math.max(0, flux - state.fluxBaseline);
  const score = clamp(
    novelty * 5.0 +
      relativeBass * 1.4 +
      relativePeak * 0.9 +
      relativeRms * 0.65,
  );
  state.fluxBaseline = approach(state.fluxBaseline, flux, dt, 0.9);
  state.bassBaseline = approach(state.bassBaseline, bass, dt, 0.65);
  state.peakBaseline = approach(state.peakBaseline, peak, dt, 1.05);
  state.rmsBaseline = approach(state.rmsBaseline, level, dt, 0.75);
  state.midBaseline = approach(state.midBaseline, mid, dt, 0.7);

  state.sinceKick += dt;
  const onset =
    present > 0.04 && novelty > 0.014 && score > 0.13 && state.sinceKick >= 0.11
      ? score
      : 0;
  if (onset > 0) state.sinceKick = 0;
  state.kick = approach(state.kick, onset, dt, onset > state.kick ? 58 : 5.2);

  const bodyTarget =
    present *
    clamp(Math.sqrt(mid) * 0.7 + Math.max(0, mid - state.midBaseline) * 0.65);
  const detailTarget = present * clamp(Math.sqrt(high) * 0.7);
  state.body = approach(
    state.body,
    bodyTarget,
    dt,
    bodyTarget > state.body ? 8 : 3.4,
  );
  state.treble = approach(
    state.treble,
    detailTarget,
    dt,
    detailTarget > state.treble ? 11 : 5,
  );
  state.presence = approach(
    state.presence,
    present,
    dt,
    present > state.presence ? 7 : 2.5,
  );

  // Sustained low frequencies preserve a subtle foundation, never an
  // illumination pulse. Kicks accelerate the flow without lifting alpha.
  const foundation =
    state.presence *
    (0.42 + 0.1 * Math.sqrt(sub) + 0.13 * Math.sqrt(bass) + 0.22 * state.body);
  state.sustain = approach(state.sustain, foundation, dt, 4);
  state.beatPulse = state.kick;
  state.motionAmount = clamp(
    0.17 + state.body * 0.35 + state.treble * 0.17 + state.kick * 0.31,
  );
  state.flowPhase =
    (state.flowPhase +
      dt *
        (0.49 + 0.21 * state.body + 0.28 * state.treble + 1.8 * state.kick)) %
    (2 * Math.PI);
}
