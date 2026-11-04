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
  // Nine log-frequency zones map directly onto the frame's nine fixed
  // gradient stops. Each zone tracks local content and attacks; no periodic
  // phase or wall-clock animation can make a steady note appear rhythmic.
  const totals = Array(9).fill(0);
  const peaks = Array(9).fill(0);
  const rises = Array(9).fill(0);
  const counts = Array(9).fill(0);
  const lower = Math.max(1, frame.lowHz || 20);
  const upper = Math.max(lower + 1, frame.highHz || 20000);
  const logSpan = Math.log(upper / lower);
  for (let i = 0; i < bands.length; ++i) {
    const hz = lower * Math.exp(logSpan * (i / Math.max(1, bands.length - 1)));
    const value = Math.sqrt(clamp(bands[i]));
    const rise = Math.max(0, value - (previous[i] || 0));
    previous[i] = value;
    const zone = hz < 60 ? 0 : Math.min(8, 1 + Math.floor(Math.log2(hz / 60)));
    totals[zone] += value;
    peaks[zone] = Math.max(peaks[zone], value);
    rises[zone] += rise;
    counts[zone]++;
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
  // A detected attack reaches its peak in the same analyser frame. It is
  // independent of sustained 808 levels and decays in roughly 140 ms.
  state.kick = Math.max(clamp(onset * 1.9), approach(state.kick, 0, dt, 22));

  const bodyTarget =
    present *
    clamp(Math.sqrt(mid) * 0.7 + Math.max(0, mid - state.midBaseline) * 0.65);
  const detailTarget = present * clamp(Math.sqrt(high) * 0.7);
  state.body = approach(
    state.body,
    bodyTarget,
    dt,
    bodyTarget > state.body ? 38 : 15,
  );
  state.treble = approach(
    state.treble,
    detailTarget,
    dt,
    detailTarget > state.treble ? 42 : 18,
  );
  state.presence = approach(
    state.presence,
    present,
    dt,
    present > state.presence ? 32 : 25,
  );

  // The steady foundation controls only a faint ambient tint. It never
  // drives a traveling phase or a global brightness pulse.
  const foundation =
    state.presence *
    (0.14 +
      0.055 * Math.sqrt(sub) +
      0.075 * Math.sqrt(bass) +
      0.1 * state.body);
  state.sustain = approach(
    state.sustain,
    foundation,
    dt,
    present > 0.01 ? 30 : 24,
  );
  state.beatPulse = state.kick;
  state.motionAmount = clamp(
    state.body * 0.35 + state.treble * 0.22 + state.kick * 0.35,
  );

  // A held 808 supplies only a faint base. Each band also has a separate
  // adaptive transient baseline, making a new kick stand out even over
  // continuous 808, loud mids, and busy treble. No oscillator is involved.
  const scales = [0.23, 0.95, 1.08, 1.22, 1.32, 1.38, 1.42, 1.45, 1.48];
  const previousLevels = state.spectrumLevels || [];
  const previousImpulses = state.impulseLevels || [];
  const previousBaselines = state.bandBaselines || [];
  const levels = Array(9);
  const impulses = Array(9);
  const baselines = Array(9);
  for (let zone = 0; zone < levels.length; zone++) {
    const count = Math.max(1, counts[zone]);
    const mean = totals[zone] / count;
    const transient = rises[zone] / count;
    const target =
      present *
      clamp(
        scales[zone] * (0.55 * mean + 0.45 * peaks[zone] + 1.6 * transient),
      );
    const previousLevel = previousLevels[zone] || 0;
    levels[zone] = approach(
      previousLevel,
      target,
      dt,
      target > previousLevel ? 65 : 18,
    );

    const reference = previousBaselines[zone] || 0;
    const relative = Math.max(0, target - reference);
    // Absolute rises count even if sustained levels are already high.
    // Higher bands contribute their own events without masking the kick.
    const attackTarget =
      present *
      clamp(
        transient * (zone === 0 ? 0.4 : 6.5) +
          relative * (zone === 0 ? 0.12 : 1.7),
      );
    const previousImpulse = previousImpulses[zone] || 0;
    impulses[zone] = approach(
      previousImpulse,
      attackTarget,
      dt,
      attackTarget > previousImpulse ? 100 : 24,
    );
    baselines[zone] = approach(reference, target, dt, 1.9);
  }
  state.spectrumLevels = levels;
  state.impulseLevels = impulses;
  state.bandBaselines = baselines;
}
