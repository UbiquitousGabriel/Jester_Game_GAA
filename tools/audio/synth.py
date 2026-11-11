#!/usr/bin/env python3
"""Synthesises every sound effect and music track for The Jester's Court.

No samples: everything is built from oscillators, noise and envelopes with
numpy, then encoded to OGG Vorbis with ffmpeg.

    python3 tools/audio/synth.py            # everything
    python3 tools/audio/synth.py sfx        # effects only
    python3 tools/audio/synth.py music      # music only
    python3 tools/audio/synth.py music title  # one track

Outputs assets/audio/sfx/*.ogg and assets/audio/music/*.ogg. Music tracks are
rendered as seamless loops (the reverb tail is folded back onto the start).
"""
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, fftconvolve, sosfilt

ROOT = Path(__file__).resolve().parents[2]
SFX_DIR = ROOT / "assets" / "audio" / "sfx"
MUSIC_DIR = ROOT / "assets" / "audio" / "music"
SR = 44100
RNG = np.random.default_rng(7)


# ---------------------------------------------------------------------------
# Basic building blocks
# ---------------------------------------------------------------------------

def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def env_adsr(n, a=0.005, d=0.05, s=0.6, r=0.1):
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    s_n = max(n - a_n - d_n - r_n, 0)
    e = np.concatenate([
        np.linspace(0, 1, max(a_n, 1), endpoint=False),
        np.linspace(1, s, max(d_n, 1), endpoint=False),
        np.full(s_n, s),
        np.linspace(s, 0, max(r_n, 1)),
    ])
    if len(e) < n:
        e = np.pad(e, (0, n - len(e)))
    return e[:n]


def env_exp(n, decay):
    return np.exp(-np.arange(n) / SR / max(decay, 1e-4))


def phase_from_freq(freq):
    """freq: array (Hz per sample) -> phase in cycles."""
    return np.cumsum(freq) / SR


def osc(shape, freq, n=None):
    if np.isscalar(freq):
        freq = np.full(n, float(freq))
    ph = phase_from_freq(freq)
    frac = ph % 1.0
    if shape == "sine":
        return np.sin(2 * np.pi * ph)
    if shape == "square":
        return np.where(frac < 0.5, 1.0, -1.0)
    if shape == "pulse25":
        return np.where(frac < 0.25, 1.0, -1.0)
    if shape == "saw":
        return 2.0 * frac - 1.0
    if shape == "tri":
        return 4.0 * np.abs(frac - 0.5) - 1.0
    raise ValueError(shape)


def noise(n):
    return RNG.uniform(-1, 1, n)


def lowpass(x, cutoff, order=2):
    cutoff = min(cutoff, SR * 0.45)
    sos = butter(order, cutoff, "low", fs=SR, output="sos")
    return sosfilt(sos, x)


def highpass(x, cutoff, order=2):
    sos = butter(order, cutoff, "high", fs=SR, output="sos")
    return sosfilt(sos, x)


def bandpass(x, lo, hi, order=2):
    sos = butter(order, [lo, min(hi, SR * 0.45)], "band", fs=SR, output="sos")
    return sosfilt(sos, x)


def sweep_filter(x, start, end, kind="low", steps=24):
    """Piecewise filter sweep (cheap and good enough for whooshes)."""
    out = np.zeros_like(x)
    chunks = np.array_split(np.arange(len(x)), steps)
    for i, idx in enumerate(chunks):
        if len(idx) == 0:
            continue
        f = start * (end / start) ** (i / max(steps - 1, 1))
        if kind == "band":
            seg = bandpass(x[max(idx[0] - 512, 0):idx[-1] + 1], f * 0.7, f * 1.4)
        elif kind == "high":
            seg = highpass(x[max(idx[0] - 512, 0):idx[-1] + 1], f)
        else:
            seg = lowpass(x[max(idx[0] - 512, 0):idx[-1] + 1], f)
        out[idx] = seg[-len(idx):]
    return out


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) if len(x) else 0
    return x * (peak / m) if m > 0 else x


def fade(x, fin=0.002, fout=0.02):
    n = len(x)
    a, b = int(fin * SR), int(fout * SR)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def at(x, offset, total=None):
    pad = np.zeros(int(offset * SR))
    y = np.concatenate([pad, x])
    if total:
        y = np.pad(y, (0, max(int(total * SR) - len(y), 0)))
    return y


def reverb_ir(seconds=1.6, damp=3000.0, seed=3):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    ir = rng.uniform(-1, 1, n) * np.exp(-np.arange(n) / SR * (6.9 / seconds))
    ir = lowpass(ir, damp)
    ir[0] = 0
    return ir / np.sqrt(np.sum(ir ** 2))


def add_reverb(x, wet=0.2, seconds=1.4, damp=3500.0):
    ir = reverb_ir(seconds, damp)
    y = fftconvolve(x, ir)[: len(x) + len(ir)]
    dry = np.pad(x, (0, len(y) - len(x)))
    return dry * (1 - wet * 0.5) + y * wet


def write_ogg(path, data, stereo=None, quality=4):
    path.parent.mkdir(parents=True, exist_ok=True)
    if stereo is not None:
        frames = np.stack([data, stereo], axis=1)
        channels = 2
    else:
        frames = data[:, None]
        channels = 1
    pcm = (np.clip(frames, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(channels)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name,
                        "-c:a", "libvorbis", "-q:a", str(quality), str(path)], check=True)
        Path(tmp.name).unlink()


# ---------------------------------------------------------------------------
# Instruments (return mono note buffers)
# ---------------------------------------------------------------------------

def karplus(freq, dur, bright=0.5, decay=0.996):
    n = int(dur * SR)
    period = max(int(SR / freq), 2)
    buf = RNG.uniform(-1, 1, period)
    buf = lowpass(buf, 1500 + 9000 * bright) if period > 16 else buf
    out = np.zeros(n)
    # Vectorised by blocks of one period.
    pos = 0
    cur = buf.copy()
    while pos < n:
        take = min(period, n - pos)
        out[pos:pos + take] = cur[:take]
        nxt = decay * 0.5 * (cur + np.roll(cur, -1))
        cur = nxt
        pos += period
    return out * env_adsr(n, 0.001, 0.02, 1.0, 0.03)


def inst_pluck(m, dur, vel=1.0):
    return karplus(mtof(m), dur + 0.3, 0.6) * vel * 0.6


def inst_harpsichord(m, dur, vel=1.0):
    f = mtof(m)
    x = mix(karplus(f, dur + 0.4, 0.95, 0.997), 0.3 * karplus(f * 2, dur + 0.3, 1.0, 0.995))
    return x * vel * 0.45


def inst_lead(m, dur, vel=1.0, shape="pulse25", vib=5.5):
    n = int((dur + 0.08) * SR)
    t = np.arange(n) / SR
    vib_amt = np.clip((t - 0.15) * 3, 0, 1) * 0.006
    f = mtof(m) * (1 + vib_amt * np.sin(2 * np.pi * vib * t))
    x = 0.6 * osc(shape, f) + 0.4 * osc("tri", f)
    x = lowpass(x, 4200)
    return x * env_adsr(n, 0.01, 0.08, 0.7, 0.07) * vel * 0.32


def inst_accordion(m, dur, vel=1.0):
    n = int((dur + 0.1) * SR)
    t = np.arange(n) / SR
    f = mtof(m)
    x = osc("saw", f * 1.003, n) * 0.5 + osc("square", f * 0.997, n) * 0.35 + osc("saw", f * 2.0, n) * 0.15
    x = lowpass(x, 2600)
    trem = 1 + 0.12 * np.sin(2 * np.pi * 6.0 * t)
    return x * trem * env_adsr(n, 0.03, 0.1, 0.8, 0.09) * vel * 0.22


def inst_organ(m, dur, vel=1.0):
    n = int((dur + 0.15) * SR)
    f = mtof(m)
    x = sum(a * osc("sine", f * h, n) for h, a in [(1, 1), (2, 0.5), (3, 0.3), (4, 0.2), (6, 0.1), (8, 0.08)])
    return x * env_adsr(n, 0.02, 0.05, 0.9, 0.14) * vel * 0.16


def inst_strings(m, dur, vel=1.0):
    n = int((dur + 0.4) * SR)
    t = np.arange(n) / SR
    f = mtof(m)
    x = np.zeros(n)
    for d in (-0.006, 0.0, 0.0055):
        x += osc("saw", f * (1 + d) * (1 + 0.003 * np.sin(2 * np.pi * 5 * t + d * 900)), n)
    x = lowpass(x, 2200)
    return x * env_adsr(n, 0.18, 0.2, 0.85, 0.35) * vel * 0.09


def inst_bass(m, dur, vel=1.0):
    n = int((dur + 0.05) * SR)
    f = mtof(m)
    x = osc("tri", f, n) * 0.8 + osc("square", f, n) * 0.15
    x = lowpass(x, 900)
    return x * env_adsr(n, 0.005, 0.1, 0.7, 0.05) * vel * 0.5


def inst_tuba(m, dur, vel=1.0):
    n = int((dur + 0.05) * SR)
    f = mtof(m)
    x = osc("saw", f, n) * 0.6 + osc("sine", f, n) * 0.6
    x = lowpass(x, 700)
    return x * env_adsr(n, 0.02, 0.1, 0.6, 0.06) * vel * 0.5


def inst_bell(m, dur, vel=1.0):
    n = int((dur + 1.2) * SR)
    t = np.arange(n) / SR
    f = mtof(m)
    mod = np.sin(2 * np.pi * f * 3.5 * t) * 2.2 * np.exp(-t * 4)
    x = np.sin(2 * np.pi * f * t + mod)
    return x * env_exp(n, 0.9) * vel * 0.25


def inst_glock(m, dur, vel=1.0):
    n = int((dur + 0.8) * SR)
    t = np.arange(n) / SR
    f = mtof(m)
    x = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 8)
    return x * env_exp(n, 0.45) * vel * 0.22


def inst_choir(m, dur, vel=1.0):
    n = int((dur + 0.5) * SR)
    t = np.arange(n) / SR
    f = mtof(m)
    x = np.zeros(n)
    for d in (-0.004, 0.003, 0.0):
        x += osc("saw", f * (1 + d) * (1 + 0.004 * np.sin(2 * np.pi * 4.6 * t)), n)
    # Two formant bands for an "ah".
    x = bandpass(x, 600, 1300) + 0.6 * bandpass(x, 2200, 3000)
    return x * env_adsr(n, 0.3, 0.2, 0.9, 0.45) * vel * 0.18


INSTRUMENTS = {
    "pluck": inst_pluck, "harpsichord": inst_harpsichord, "lead": inst_lead,
    "accordion": inst_accordion, "organ": inst_organ, "strings": inst_strings,
    "bass": inst_bass, "tuba": inst_tuba, "bell": inst_bell, "glock": inst_glock,
    "choir": inst_choir,
}


# Drums -----------------------------------------------------------------------

def drum_kick(vel=1.0):
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = 45 + 110 * np.exp(-t * 30)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, 0.12)
    return x * vel * 0.9


def drum_snare(vel=1.0):
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    tone = np.sin(2 * np.pi * 190 * t) * env_exp(n, 0.04)
    nz = bandpass(noise(n), 1500, 8000) * env_exp(n, 0.07)
    return (tone * 0.5 + nz) * vel * 0.45


def drum_hat(vel=1.0, open_=False):
    n = int((0.25 if open_ else 0.06) * SR)
    x = highpass(noise(n), 7000) * env_exp(n, 0.08 if open_ else 0.018)
    return x * vel * 0.3


def drum_tamb(vel=1.0):
    n = int(0.18 * SR)
    x = bandpass(noise(n), 6000, 12000) * env_exp(n, 0.05)
    jing = sum(np.sin(2 * np.pi * f * np.arange(n) / SR) for f in (5200, 6700, 8100)) * env_exp(n, 0.06) * 0.15
    return (x + jing) * vel * 0.3


def drum_block(vel=1.0, pitch=1.0):
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * 900 * pitch * t) * env_exp(n, 0.025) + 0.3 * np.sin(2 * np.pi * 2300 * pitch * t) * env_exp(n, 0.01)
    return x * vel * 0.4


def drum_timpani(vel=1.0, m=41):
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    f = mtof(m) * (1 + 0.04 * np.exp(-t * 12))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.4 * np.sin(2 * np.pi * np.cumsum(f * 1.5) / SR)
    x += lowpass(noise(n), 400) * np.exp(-t * 30) * 0.6
    return x * env_exp(n, 0.5) * vel * 0.6


def drum_tick(vel=1.0, tock=False):
    n = int(0.05 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * (1800 if not tock else 1300) * t) * env_exp(n, 0.006)
    x += highpass(noise(n), 4000) * env_exp(n, 0.004) * 0.4
    return x * vel * 0.4


DRUMS = {
    "K": drum_kick, "S": drum_snare, "h": drum_hat, "H": lambda v: drum_hat(v, True),
    "t": drum_tamb, "b": drum_block, "B": lambda v: drum_block(v, 0.7), "T": drum_timpani,
    "k": drum_tick, "c": lambda v: drum_tick(v, True),
}


# ---------------------------------------------------------------------------
# Composer
# ---------------------------------------------------------------------------

MODES = {
    "major": [0, 2, 4, 5, 7, 9, 11],
    "minor": [0, 2, 3, 5, 7, 8, 10],
    "harmonic": [0, 2, 3, 5, 7, 8, 11],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "mixolydian": [0, 2, 4, 5, 7, 9, 10],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
}


class Song:
    def __init__(self, name, bpm, beats_per_bar, root, mode, progression, seed,
                 bars_per_chord=1, swing=0.0):
        self.name = name
        self.bpm = bpm
        self.bpb = beats_per_bar
        self.root = root
        self.scale = MODES[mode]
        self.prog = progression
        self.bars_per_chord = bars_per_chord
        self.rng = np.random.default_rng(seed)
        self.beat = 60.0 / bpm
        self.swing = swing
        self.bars = len(progression) * bars_per_chord
        self.length = self.bars * self.bpb * self.beat
        self.tracks = {}

    def degree(self, d, octave=0):
        """Scale degree (0-based, may exceed 6) -> MIDI note."""
        o, i = divmod(d, 7)
        return self.root + 12 * (o + octave) + self.scale[i]

    def chord(self, bar):
        return self.prog[(bar // self.bars_per_chord) % len(self.prog)]

    def chord_tones(self, bar, octave=0):
        c = self.chord(bar)
        return [self.degree(c + k, octave) for k in (0, 2, 4)]

    def time(self, bar, beat):
        b = beat
        if self.swing and (beat * 2) % 2 == 1:
            b += self.swing * 0.5
        return (bar * self.bpb + b) * self.beat

    def note(self, track, inst, m, start, dur, vel=1.0, pan=0.0):
        self.tracks.setdefault(track, []).append((inst, m, start, dur, vel, pan))

    def hit(self, track, kind, start, vel=1.0, pan=0.0):
        self.tracks.setdefault(track, []).append(("drum:" + kind, 0, start, 0, vel, pan))

    def render(self, levels=None, reverb=0.22, room=1.6):
        levels = levels or {}
        n = int(self.length * SR)
        tail = int(3.0 * SR)
        left = np.zeros(n + tail)
        right = np.zeros(n + tail)
        for track, events in self.tracks.items():
            lvl = levels.get(track, 1.0)
            for inst, m, start, dur, vel, pan in events:
                if inst.startswith("drum:"):
                    buf = DRUMS[inst[5:]](vel)
                else:
                    buf = INSTRUMENTS[inst](m, dur, vel)
                s = int(start * SR)
                e = min(s + len(buf), n + tail)
                buf = buf[: e - s] * lvl
                left[s:e] += buf * np.sqrt(0.5 * (1 - pan))
                right[s:e] += buf * np.sqrt(0.5 * (1 + pan))
        out = []
        for ch in (left, right):
            ch = add_reverb(ch, reverb, room)
            # Fold everything past the loop point back onto the start.
            loop = ch[:n].copy()
            rest = ch[n:]
            k = min(len(rest), n)
            loop[:k] += rest[:k]
            out.append(loop)
        peak = max(np.max(np.abs(out[0])), np.max(np.abs(out[1])))
        g = 0.85 / peak if peak > 0 else 1.0
        # Gentle soft clip for glue.
        return [np.tanh(o * g * 1.1) / np.tanh(1.1) for o in out]


# Melody generation: a motif per phrase, varied, built on chord tones.
RHYTHMS_4 = [
    [(0, 1), (1, 1), (2, 1.5), (3.5, 0.5)],
    [(0, 0.5), (0.5, 0.5), (1, 1), (2, 2)],
    [(0, 1.5), (1.5, 0.5), (2, 1), (3, 1)],
    [(0, 0.75), (0.75, 0.25), (1, 0.5), (1.5, 0.5), (2, 1), (3, 1)],
    [(0, 2), (2, 1), (3, 1)],
    [(0, 0.5), (0.5, 0.5), (1, 0.5), (1.5, 0.5), (2, 0.5), (2.5, 0.5), (3, 1)],
]
RHYTHMS_3 = [
    [(0, 1), (1, 1), (2, 1)],
    [(0, 2), (2, 1)],
    [(0, 1.5), (1.5, 0.5), (2, 1)],
    [(0, 0.5), (0.5, 0.5), (1, 1), (2, 1)],
    [(0, 1), (1, 0.5), (1.5, 0.5), (2, 1)],
]


def make_melody(song, octave, density=1.0, leap=2):
    rng = song.rng
    pool = RHYTHMS_3 if song.bpb == 3 else RHYTHMS_4
    if song.bpb == 6:
        pool = [[(0, 1.5), (1.5, 1.5), (3, 1.5), (4.5, 1.5)], [(0, 1), (1, 0.5), (1.5, 1.5), (3, 3)],
                [(0, 1.5), (1.5, 1), (2.5, 0.5), (3, 3)], [(0, 0.5), (0.5, 0.5), (1, 0.5), (1.5, 1.5), (3, 1.5), (4.5, 1.5)]]
    # Motifs: A and B, each one bar of rhythm + contour.
    motifs = []
    for _ in range(2):
        rhythm = pool[rng.integers(len(pool))]
        if density < 1.0 and rng.random() > density:
            rhythm = pool[1 if song.bpb != 6 else 0]
        contour = [int(rng.integers(-leap, leap + 1)) for _ in rhythm]
        motifs.append((rhythm, contour))
    phrase = [0, 0, 1, 0] if song.bars >= 4 else [0, 1]
    notes = []
    cur = 4 + 7 * 0  # degree, relative to the root octave
    for bar in range(song.bars):
        rhythm, contour = motifs[phrase[(bar // 2) % len(phrase)] if bar % 2 == 0 else (phrase[(bar // 2) % len(phrase)] + bar) % 2]
        chord = song.chord(bar)
        last = bar % 4 == 3
        for i, (beat, dur) in enumerate(rhythm):
            cur += contour[i]
            strong = beat == int(beat) and int(beat) % (3 if song.bpb in (3, 6) else 2) == 0
            if strong:
                # Snap to the nearest chord tone.
                tones = [chord + k + 7 * o for o in (-1, 0, 1, 2) for k in (0, 2, 4)]
                cur = min(tones, key=lambda d: abs(d - cur))
            cur = int(np.clip(cur, 0, 12))
            if last and i == len(rhythm) - 1:
                cur = min([chord + 7, chord, chord + 14], key=lambda d: abs(d - cur))
            notes.append((bar, beat, dur, song.degree(cur, octave)))
        # Occasional variation of the motif contour for the next bars.
        if rng.random() < 0.3:
            j = int(rng.integers(len(contour)))
            contour[j] = int(rng.integers(-leap, leap + 1))
    return notes


def add_melody(song, track, inst, octave, vel=1.0, density=1.0, pan=0.0, legato=0.95, leap=2, bars=None):
    for bar, beat, dur, m in make_melody(song, octave, density, leap):
        if bars and bar not in bars:
            continue
        song.note(track, inst, m, song.time(bar, beat), dur * song.beat * legato, vel * (1.0 if beat == 0 else 0.85), pan)


def add_bass(song, inst, style, octave=-2, vel=1.0):
    for bar in range(song.bars):
        c = song.chord(bar)
        root = song.degree(c, octave)
        fifth = song.degree(c + 4, octave)
        if style == "oompah":  # waltz / march: root on 1, fifth on the other strong beat
            song.note("bass", inst, root, song.time(bar, 0), song.beat * 0.9, vel)
            if song.bpb == 4:
                song.note("bass", inst, fifth, song.time(bar, 2), song.beat * 0.9, vel * 0.9)
        elif style == "walk":
            for b in range(song.bpb):
                m = [root, song.degree(c + 2, octave), fifth, song.degree(c + 5, octave)][b % 4]
                song.note("bass", inst, m, song.time(bar, b), song.beat * 0.85, vel)
        elif style == "pulse":
            for b in range(song.bpb * 2):
                song.note("bass", inst, root, song.time(bar, b * 0.5), song.beat * 0.4, vel * (1.0 if b % 2 == 0 else 0.7))
        elif style == "long":
            song.note("bass", inst, root, song.time(bar, 0), song.beat * song.bpb * 0.98, vel)
        elif style == "six":
            song.note("bass", inst, root, song.time(bar, 0), song.beat * 2.5, vel)
            song.note("bass", inst, fifth, song.time(bar, 3), song.beat * 2.5, vel * 0.85)


def add_chords(song, inst, style, octave=0, vel=1.0, pan=0.0):
    for bar in range(song.bars):
        tones = song.chord_tones(bar, octave)
        if style == "pah":  # off-beat chord stabs (waltz 2 & 3, march 2 & 4)
            beats = [1, 2] if song.bpb == 3 else [1, 3] if song.bpb == 4 else [1.5, 4.5]
            for b in beats:
                for m in tones:
                    song.note("chords", inst, m, song.time(bar, b), song.beat * 0.45, vel * 0.8, pan)
        elif style == "pad":
            for m in tones:
                song.note("chords", inst, m, song.time(bar, 0), song.beat * song.bpb, vel, pan)
        elif style == "arp":
            seq = tones + [tones[1] + 12, tones[0] + 12, tones[2]]
            steps = song.bpb * 2
            for i in range(steps):
                song.note("chords", inst, seq[i % len(seq)], song.time(bar, i * 0.5), song.beat * 0.5, vel * (1.0 if i % 2 == 0 else 0.75), pan)
        elif style == "arp16":
            seq = tones + [tones[0] + 12]
            for i in range(song.bpb * 4):
                song.note("chords", inst, seq[i % len(seq)], song.time(bar, i * 0.25), song.beat * 0.25, vel * (1.0 if i % 4 == 0 else 0.6), pan)


def add_drums(song, pattern, vel=1.0):
    """pattern: list of strings per beat-subdivision (one char per step),
    e.g. {"K": "x...x...", "S": "..x...x."} with steps per bar."""
    for bar in range(song.bars):
        for kind, steps in pattern.items():
            per = len(steps)
            for i, ch in enumerate(steps):
                if ch == ".":
                    continue
                v = vel * (1.0 if ch == "X" else 0.7 if ch == "x" else 0.45)
                beat = i * song.bpb / per
                song.hit("drums", kind, song.time(bar, beat), v, 0.0)


# ---------------------------------------------------------------------------
# The soundtrack
# ---------------------------------------------------------------------------

def track_title():
    s = Song("title", 112, 3, 62, "major", [0, 3, 4, 0, 5, 3, 1, 4], seed=11)
    add_bass(s, "tuba", "oompah", -2, 0.8)
    add_chords(s, "accordion", "pah", 0, 0.8, 0.2)
    add_melody(s, "mel", "glock", 1, 0.9, pan=-0.2)
    add_melody(s, "mel2", "lead", 0, 0.6, density=0.6, pan=0.25)
    add_drums(s, {"t": "..x..x", "B": "x....."})
    return s, {"mel2": 0.7}


def track_intro():
    s = Song("intro", 70, 4, 57, "minor", [0, 5, 3, 4, 0, 5, 6, 4], seed=12)
    add_chords(s, "strings", "pad", -1, 0.9)
    add_bass(s, "bass", "long", -2, 0.6)
    add_melody(s, "mel", "bell", 1, 0.7, density=0.5)
    return s, {}


def track_ending():
    s = Song("ending", 84, 3, 65, "major", [0, 4, 5, 3, 0, 1, 4, 0], seed=13, bars_per_chord=2)
    add_chords(s, "strings", "pad", 0, 1.0)
    add_chords(s, "harpsichord", "arp", 0, 0.5, 0.3)
    add_bass(s, "bass", "long", -2, 0.6)
    add_melody(s, "mel", "lead", 1, 0.7, density=0.7, pan=-0.2)
    add_melody(s, "mel2", "glock", 2, 0.5, density=0.5, pan=0.3)
    return s, {"mel2": 0.6}


def track_carnival():
    # A crooked festival waltz: oom-pah-pah, accordion, glockenspiel tune.
    s = Song("carnival_gate", 156, 3, 60, "mixolydian", [0, 0, 3, 4, 0, 5, 1, 4, 0, 3, 6, 4, 0, 5, 4, 0], seed=21)
    add_bass(s, "tuba", "oompah", -2, 0.9)
    add_chords(s, "accordion", "pah", 0, 0.75, 0.25)
    add_melody(s, "mel", "lead", 1, 0.85, pan=-0.15, leap=2)
    add_melody(s, "mel2", "glock", 2, 0.55, density=0.5, pan=0.3)
    add_drums(s, {"K": "x.....", "t": "..x.x.", "b": "......"})
    return s, {"mel2": 0.6}


def track_walls():
    # Brisk rampart march in minor: snare rolls, low brass, pluck ostinato.
    s = Song("outer_walls", 118, 4, 57, "dorian", [0, 0, 6, 6, 5, 5, 4, 4, 0, 3, 6, 4], seed=22)
    add_bass(s, "tuba", "oompah", -2, 0.9)
    add_chords(s, "pluck", "arp", 0, 0.6, -0.3)
    add_melody(s, "mel", "lead", 1, 0.8, pan=0.15, leap=2)
    add_chords(s, "strings", "pad", 0, 0.4)
    add_drums(s, {"K": "X.......x.......", "S": "....x.......x.xx", "h": "x.x.x.x.x.x.x.x."})
    return s, {"chords": 0.8}


def track_gardens():
    # Gentle 6/8 pastoral with a sad bell; harp-like arpeggios.
    s = Song("royal_gardens", 96, 6, 64, "dorian", [0, 3, 0, 4, 5, 3, 6, 4], seed=23)
    add_bass(s, "bass", "six", -2, 0.6)
    add_chords(s, "pluck", "arp", 0, 0.55, 0.25)
    add_melody(s, "mel", "lead", 1, 0.6, density=0.6, pan=-0.2, leap=1)
    for bar in range(0, s.bars, 2):
        s.note("bell", "bell", s.degree(s.chord(bar), 0), s.time(bar, 0), 2.0, 0.6, 0.4)
    add_drums(s, {"t": "...x.....x..", "B": "x..........."})
    return s, {"bell": 0.7}


def track_halls():
    # Courtly minuet: harpsichord, strings, ornamental lead.
    s = Song("grand_halls", 132, 3, 67, "major", [0, 4, 0, 4, 5, 1, 4, 0, 3, 0, 1, 4, 0, 3, 4, 0], seed=24)
    add_bass(s, "bass", "walk", -2, 0.7)
    add_chords(s, "harpsichord", "arp", 0, 0.55, 0.3)
    add_melody(s, "mel", "harpsichord", 1, 0.9, pan=-0.25, leap=2)
    add_chords(s, "strings", "pad", 0, 0.35)
    return s, {"chords": 0.85}


def track_clockworks():
    # Ticking machine: 16th arps, wood-block clock, low pulse bass.
    s = Song("clockworks", 128, 4, 58, "phrygian", [0, 0, 1, 1, 0, 0, 6, 5], seed=25)
    add_bass(s, "bass", "pulse", -2, 0.75)
    add_chords(s, "glock", "arp16", 1, 0.45, 0.3)
    add_melody(s, "mel", "lead", 0, 0.65, density=0.6, pan=-0.2, leap=1)
    add_drums(s, {"k": "x...x...x...x...", "c": "..x...x...x...x.", "K": "x.......x..x....", "S": "........x......."})
    return s, {}


def track_throne():
    # Dark, grand: organ, choir, timpani.
    s = Song("throne_spire", 88, 4, 53, "harmonic", [0, 5, 3, 4, 0, 6, 3, 4], seed=26)
    add_chords(s, "organ", "pad", 0, 0.9)
    add_chords(s, "choir", "pad", 1, 0.5)
    add_bass(s, "bass", "long", -2, 0.8)
    add_melody(s, "mel", "lead", 1, 0.6, density=0.5, pan=0.2, leap=1)
    add_drums(s, {"T": "x.......x......."})
    return s, {}


def track_boss():
    # Frantic circus gallop.
    s = Song("boss", 168, 4, 62, "harmonic", [0, 0, 5, 4, 0, 0, 1, 4], seed=31)
    add_bass(s, "tuba", "pulse", -2, 0.9)
    add_chords(s, "accordion", "pah", 0, 0.8, 0.25)
    add_melody(s, "mel", "lead", 1, 0.9, pan=-0.15, leap=3)
    add_chords(s, "strings", "pad", 0, 0.5)
    add_drums(s, {"K": "X...x...X...x...", "S": "....X.......X..x", "h": "x.x.x.x.x.x.x.x.", "t": "..x...x...x...x."})
    return s, {}


def track_boss_king():
    s = Song("boss_king", 150, 4, 50, "harmonic", [0, 5, 1, 4, 0, 5, 6, 4], seed=32)
    add_chords(s, "organ", "pad", 0, 0.8)
    add_chords(s, "choir", "pad", 1, 0.5)
    add_bass(s, "bass", "pulse", -2, 0.9)
    add_melody(s, "mel", "lead", 1, 0.85, pan=0.15, leap=3)
    add_drums(s, {"K": "X..x..x.X..x..x.", "S": "....X.......X...", "T": "x.......x.......", "h": "x.x.x.x.x.x.x.x."})
    return s, {}


TRACKS = {
    "title": track_title, "intro": track_intro, "ending": track_ending,
    "carnival_gate": track_carnival, "outer_walls": track_walls, "royal_gardens": track_gardens,
    "grand_halls": track_halls, "clockworks": track_clockworks, "throne_spire": track_throne,
    "boss": track_boss, "boss_king": track_boss_king,
}


def render_track(name, repeats=2):
    song, levels = TRACKS[name]()
    # Long enough to not wear out: repeat the progression with fresh melodies.
    if song.length < 50.0:
        base_tracks = song.tracks
        base_len = song.length
        reps = int(np.ceil(60.0 / base_len))
        all_tracks = {}
        for r in range(reps):
            fresh, _ = TRACKS[name]()
            fresh.rng = np.random.default_rng(1000 + r)
            for k, evs in fresh.tracks.items():
                for e in evs:
                    all_tracks.setdefault(k, []).append((e[0], e[1], e[2] + r * base_len, e[3], e[4], e[5]))
        song.tracks = all_tracks
        song.length = base_len * reps
        song.bars *= reps
    left, right = song.render(levels)
    write_ogg(MUSIC_DIR / f"{name}.ogg", left, right, quality=4)
    print(f"music {name}: {song.length:.1f}s")


# Ambience beds --------------------------------------------------------------

def amb_wind():
    n = int(24 * SR)
    t = np.arange(n) / SR
    x = lowpass(noise(n), 500) * (0.6 + 0.4 * np.sin(2 * np.pi * t / 8.0))
    x += bandpass(noise(n), 700, 1400) * 0.25 * (0.5 + 0.5 * np.sin(2 * np.pi * t / 6.0 + 1))
    return x


def amb_garden():
    n = int(24 * SR)
    x = lowpass(noise(n), 900) * 0.3
    # Crickets and distant birds.
    for i in range(40):
        s = RNG.uniform(0, 23)
        f = RNG.uniform(3800, 5200)
        d = int(0.25 * SR)
        tt = np.arange(d) / SR
        chirp = np.sin(2 * np.pi * f * tt) * (np.sin(2 * np.pi * 30 * tt) > 0) * env_exp(d, 0.12)
        x[int(s * SR):int(s * SR) + d] += chirp[: max(0, min(d, n - int(s * SR)))] * 0.15
    return x


def amb_halls():
    n = int(24 * SR)
    x = lowpass(noise(n), 250) * 0.5
    for i in range(10):
        s = int(RNG.uniform(0, 22) * SR)
        d = int(1.5 * SR)
        drip = drum_block(0.15, RNG.uniform(1.2, 2.0))
        x[s:s + len(drip)] += drip
    return add_reverb(x, 0.5, 2.5)[:n]


def amb_gears():
    n = int(24 * SR)
    x = lowpass(noise(n), 200) * 0.4
    for i in range(0, 48):
        s = int(i * 0.5 * SR)
        k = drum_tick(0.25, i % 2 == 1)
        x[s:s + len(k)] += k
    t = np.arange(n) / SR
    x += osc("saw", 55 + 2 * np.sin(2 * np.pi * t / 5), n) * 0.04
    return x


AMBIENCE = {"amb_wind": amb_wind, "amb_garden": amb_garden, "amb_halls": amb_halls, "amb_gears": amb_gears}


def render_ambience(name):
    x = AMBIENCE[name]()
    # Crossfade the ends for a seamless loop.
    k = int(1.0 * SR)
    head = x[:k].copy()
    x = x[k:]
    x[-k:] = x[-k:] * np.linspace(1, 0, k) + head * np.linspace(0, 1, k)
    write_ogg(MUSIC_DIR / f"{name}.ogg", norm(x, 0.5), quality=2)
    print(f"ambience {name}")


# ---------------------------------------------------------------------------
# Sound effects
# ---------------------------------------------------------------------------

def sfx_sweep(f0, f1, dur, shape="sine", decay=None):
    n = int(dur * SR)
    f = np.geomspace(f0, f1, n)
    x = osc(shape, f)
    e = env_exp(n, decay) if decay else env_adsr(n, 0.003, dur * 0.3, 0.5, dur * 0.4)
    return x * e


def whoosh(dur=0.22, lo=500, hi=3000, level=0.8):
    n = int(dur * SR)
    x = sweep_filter(noise(n), lo, hi, "band")
    e = np.sin(np.linspace(0, np.pi, n)) ** 1.5
    return x * e * level


def thump(f0=140, f1=50, dur=0.18):
    n = int(dur * SR)
    f = np.geomspace(f0, f1, n)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, dur * 0.35)


def crack(dur=0.06, lo=1500):
    n = int(dur * SR)
    return highpass(noise(n), lo) * env_exp(n, dur * 0.25)


def jingle(base=2600, dur=0.35, count=4, level=0.3):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for i in range(count):
        f = base * (1 + 0.37 * i) * RNG.uniform(0.98, 1.02)
        off = int(RNG.uniform(0, 0.04) * SR)
        y = np.sin(2 * np.pi * f * t) * env_exp(n, 0.08)
        x[off:] += y[: n - off]
    return x * level


def tone(m, dur, shape="sine", decay=0.15, vel=1.0):
    n = int(dur * SR)
    return osc(shape, mtof(m), n) * env_exp(n, decay) * vel


def arpeggio(notes, step, shape="pulse25", decay=0.12, vel=0.5):
    parts = [at(lowpass(tone(m, step * 3, shape, decay, vel), 5000), i * step) for i, m in enumerate(notes)]
    return mix(*parts)


SFX = {
    # Movement
    "jump": lambda: mix(sfx_sweep(300, 720, 0.12, "tri") * 0.5, whoosh(0.1, 800, 2400, 0.25)),
    "jump_big": lambda: mix(sfx_sweep(120, 420, 0.3, "saw") * 0.3, whoosh(0.3, 300, 1500, 0.6)),
    "land": lambda: mix(thump(160, 60, 0.1) * 0.6, lowpass(crack(0.05, 300), 1800) * 0.4),
    "land_heavy": lambda: mix(thump(110, 35, 0.3), lowpass(noise(int(0.25 * SR)), 900) * env_exp(int(0.25 * SR), 0.06) * 0.6),
    "dash": lambda: mix(whoosh(0.18, 700, 5000, 0.9), jingle(3000, 0.2, 3, 0.15)),
    "phantom": lambda: mix(whoosh(0.22, 400, 3000, 0.6), add_reverb(sfx_sweep(900, 300, 0.25, "sine"), 0.5, 0.6)[: int(0.5 * SR)] * 0.4),
    "pogo": lambda: mix(sfx_sweep(220, 880, 0.14, "square") * 0.25, tone(84, 0.25, "tri", 0.08, 0.4), jingle(2800, 0.25, 3, 0.18)),
    "vault": lambda: mix(thump(200, 70, 0.12), sfx_sweep(200, 900, 0.25, "tri") * 0.4, whoosh(0.25, 400, 2000, 0.4)),
    "perfect": lambda: arpeggio([84, 88, 91, 96], 0.05, "pulse25", 0.1, 0.35),
    "twirl": lambda: mix(*[at(whoosh(0.12, 900, 2600, 0.5), i * 0.09) for i in range(4)]),
    "wallkick": lambda: mix(thump(260, 120, 0.08) * 0.6, crack(0.04, 2000) * 0.4, sfx_sweep(400, 900, 0.1, "tri") * 0.3),
    "fall": lambda: mix(sfx_sweep(900, 120, 0.7, "tri", 0.4) * 0.45, whoosh(0.6, 2000, 300, 0.3)),
    "hurt": lambda: mix(sfx_sweep(500, 150, 0.22, "square") * 0.3, thump(180, 80, 0.15) * 0.7, jingle(2200, 0.3, 4, 0.2)),
    "die": lambda: mix(arpeggio([72, 68, 65, 60, 55], 0.09, "square", 0.15, 0.35), thump(120, 40, 0.5) * 0.6),
    "heal": lambda: mix(arpeggio([72, 76, 79, 84], 0.06, "tri", 0.2, 0.4), jingle(3200, 0.5, 5, 0.12)),
    # Hammer
    "swing": lambda: whoosh(0.16, 900, 3500, 0.7),
    "swing_heavy": lambda: mix(whoosh(0.3, 300, 1800, 1.0), thump(90, 50, 0.2) * 0.2),
    "swing_finisher": lambda: mix(whoosh(0.22, 500, 4000, 0.9), jingle(2400, 0.3, 4, 0.2)),
    "charge": lambda: mix(sfx_sweep(150, 600, 0.8, "saw") * 0.12 * np.linspace(0.3, 1, int(0.8 * SR)), jingle(2000, 0.8, 6, 0.06)),
    "hit": lambda: mix(thump(220, 90, 0.12) * 0.8, crack(0.05, 2500) * 0.5, tone(77, 0.15, "tri", 0.05, 0.35)),
    "hit_heavy": lambda: mix(thump(160, 40, 0.3), crack(0.09, 1200) * 0.7, lowpass(noise(int(0.3 * SR)), 1200) * env_exp(int(0.3 * SR), 0.08) * 0.5, tone(65, 0.3, "tri", 0.1, 0.4)),
    "thunk": lambda: mix(thump(300, 140, 0.08) * 0.6, drum_block(0.5, 0.8)),
    "slam": lambda: mix(thump(100, 30, 0.6) * 1.0, lowpass(noise(int(0.6 * SR)), 700) * env_exp(int(0.6 * SR), 0.15) * 0.8, crack(0.1, 800) * 0.4),
    "parry": lambda: mix(tone(96, 0.35, "sine", 0.15, 0.5), tone(103, 0.3, "sine", 0.1, 0.3), crack(0.04, 4000) * 0.5),
    "chain_hit": lambda: mix(thump(180, 70, 0.14) * 0.8, drum_block(0.6, 1.3), crack(0.05, 2000) * 0.4),
    "ricochet": lambda: mix(sfx_sweep(1800, 600, 0.12, "tri") * 0.3, crack(0.04, 3000) * 0.4),
    "chain_milestone": lambda: mix(arpeggio([72, 76, 79, 84, 88], 0.05, "pulse25", 0.15, 0.4), jingle(3000, 0.6, 6, 0.2)),
    # Enemies
    "enemy_hurt": lambda: mix(sfx_sweep(420, 200, 0.12, "square") * 0.2, thump(200, 100, 0.08) * 0.4),
    "enemy_defeat": lambda: mix(sfx_sweep(600, 80, 0.35, "square", 0.15) * 0.25, lowpass(noise(int(0.3 * SR)), 2500) * env_exp(int(0.3 * SR), 0.07) * 0.5, jingle(2600, 0.3, 3, 0.15)),
    "clank": lambda: mix(tone(88, 0.3, "square", 0.05, 0.15), tone(95, 0.25, "sine", 0.08, 0.35), tone(81, 0.4, "sine", 0.12, 0.3), crack(0.04, 3000) * 0.6),
    "crossbow": lambda: mix(crack(0.05, 1500) * 0.5, thump(400, 200, 0.06) * 0.4, whoosh(0.15, 2000, 5000, 0.4)),
    "bark": lambda: mix(bandpass(noise(int(0.18 * SR)), 300, 1200) * env_adsr(int(0.18 * SR), 0.01, 0.05, 0.5, 0.08), sfx_sweep(280, 160, 0.18, "saw") * 0.3),
    "spring": lambda: mix(*[at(sfx_sweep(200 + 60 * i, 500 + 80 * i, 0.07, "tri") * (0.4 - 0.08 * i), i * 0.06) for i in range(4)]),
    "wisp": lambda: add_reverb(sfx_sweep(600, 1200, 0.4, "sine") * 0.4, 0.5, 0.8)[: int(0.9 * SR)],
    "drop": lambda: sfx_sweep(1200, 300, 0.3, "tri") * 0.4,
    "cannon": lambda: mix(thump(90, 30, 0.6), lowpass(noise(int(0.5 * SR)), 1200) * env_exp(int(0.5 * SR), 0.1) * 0.9),
    "cast": lambda: mix(add_reverb(arpeggio([79, 83, 86], 0.04, "sine", 0.2, 0.4), 0.5, 0.6)[: int(0.8 * SR)], whoosh(0.3, 600, 3000, 0.3)),
    "pillar": lambda: mix(thump(80, 30, 0.5), whoosh(0.5, 300, 4000, 0.8)),
    "blink": lambda: mix(sfx_sweep(2000, 400, 0.12, "sine") * 0.4, sfx_sweep(400, 2000, 0.12, "sine") * 0.3),
    "spin": lambda: mix(*[at(whoosh(0.1, 1200, 3000, 0.4), i * 0.08) for i in range(6)]),
    "shatter": lambda: mix(*[at(tone(int(RNG.integers(88, 108)), 0.3, "sine", 0.06, 0.25), RNG.uniform(0, 0.15)) for _ in range(12)], crack(0.1, 3000) * 0.7),
    "whirr": lambda: sfx_sweep(80, 260, 0.6, "saw") * 0.25 * np.linspace(1, 0.2, int(0.6 * SR)),
    "wind_down": lambda: sfx_sweep(300, 60, 0.8, "saw") * 0.25,
    "shot_pop": lambda: mix(crack(0.04, 1500) * 0.5, thump(300, 150, 0.06) * 0.3),
    # Bosses
    "boss_roar": lambda: mix(bandpass(noise(int(1.0 * SR)), 150, 900) * env_adsr(int(1.0 * SR), 0.1, 0.2, 0.7, 0.5) * 0.9, sfx_sweep(110, 70, 1.0, "saw") * 0.35),
    "boss_defeat": lambda: mix(thump(80, 25, 1.2), arpeggio([60, 64, 67, 72, 76, 79, 84], 0.09, "pulse25", 0.3, 0.35), jingle(2400, 1.2, 8, 0.2)),
    "whip": lambda: mix(whoosh(0.12, 1500, 6000, 0.5), at(crack(0.03, 3000), 0.1)),
    "throw": lambda: whoosh(0.2, 600, 2500, 0.6),
    "whoosh": lambda: whoosh(0.35, 300, 2400, 0.8),
    "toll": lambda: mix(add_reverb(inst_bell(38, 2.0, 1.4), 0.4, 2.0)[: int(3.0 * SR)], thump(70, 40, 0.5) * 0.5),
    "hiss": lambda: highpass(noise(int(0.8 * SR)), 3000) * env_adsr(int(0.8 * SR), 0.2, 0.1, 0.8, 0.3) * 0.35,
    "steam": lambda: highpass(noise(int(1.2 * SR)), 1500) * env_adsr(int(1.2 * SR), 0.02, 0.2, 0.8, 0.5) * 0.6,
    "summon": lambda: add_reverb(arpeggio([67, 70, 74, 79], 0.05, "saw", 0.15, 0.25), 0.5, 0.8)[: int(1.0 * SR)],
    "cards": lambda: mix(*[at(crack(0.02, 3000) * 0.4, i * 0.025) for i in range(7)]),
    "gate_slam": lambda: mix(thump(70, 30, 0.8), drum_timpani(0.6, 36), crack(0.1, 600) * 0.6),
    "gate_open": lambda: mix(sfx_sweep(120, 260, 0.9, "saw") * 0.15, arpeggio([67, 72, 76], 0.1, "tri", 0.3, 0.3)),
    # Pickups and UI
    "bell": lambda: mix(tone(96, 0.3, "sine", 0.1, 0.35), tone(103, 0.25, "sine", 0.06, 0.15)),
    "bells": lambda: mix(*[at(mix(tone(96 + (i % 3) * 3, 0.3, "sine", 0.1, 0.25), tone(103, 0.2, "sine", 0.05, 0.1)), i * 0.04) for i in range(10)]),
    "heart": lambda: mix(arpeggio([72, 76, 79, 84, 88], 0.07, "tri", 0.3, 0.45), jingle(3000, 0.6, 5, 0.15)),
    "page": lambda: mix(bandpass(noise(int(0.2 * SR)), 1500, 6000) * env_adsr(int(0.2 * SR), 0.02, 0.05, 0.3, 0.1) * 0.5),
    "shrine": lambda: add_reverb(mix(inst_bell(72, 1.0, 0.8), at(inst_bell(79, 1.0, 0.6), 0.12), at(inst_bell(84, 1.2, 0.6), 0.24)), 0.5, 1.5)[: int(2.5 * SR)],
    "talk": lambda: mix(*[at(tone(int(RNG.integers(64, 76)), 0.06, "square", 0.03, 0.15), i * 0.06) for i in range(3)]),
    "fanfare": lambda: add_reverb(mix(
        arpeggio([60, 64, 67, 72], 0.12, "pulse25", 0.4, 0.4),
        at(mix(tone(72, 1.0, "pulse25", 0.6, 0.3), tone(76, 1.0, "tri", 0.6, 0.3), tone(79, 1.0, "tri", 0.6, 0.3)), 0.5),
        at(jingle(2600, 1.0, 8, 0.2), 0.5)), 0.3, 1.2)[: int(2.2 * SR)],
    "fanfare_small": lambda: mix(arpeggio([72, 79, 84], 0.08, "pulse25", 0.25, 0.35), jingle(3000, 0.5, 4, 0.15)),
    "buy": lambda: mix(arpeggio([84, 91], 0.07, "pulse25", 0.15, 0.35), *[at(tone(96, 0.2, "sine", 0.06, 0.2), 0.14 + i * 0.05) for i in range(4)]),
    "deny": lambda: mix(tone(50, 0.25, "square", 0.12, 0.2), at(tone(47, 0.3, "square", 0.15, 0.2), 0.12)),
    "equip": lambda: mix(drum_block(0.6, 1.4), at(tone(88, 0.2, "tri", 0.08, 0.3), 0.03)),
    "click": lambda: drum_block(0.6, 1.6),
    "tick": lambda: drum_block(0.35, 2.0),
}


def render_sfx(names=None):
    for name, fn in SFX.items():
        if names and name not in names:
            continue
        x = fn()
        x = fade(norm(x, 0.85), 0.001, 0.02)
        write_ogg(SFX_DIR / f"{name}.ogg", x, quality=5)
    print(f"sfx: {len(SFX)} sounds")


def main():
    args = sys.argv[1:]
    what = args[0] if args else "all"
    names = args[1:]
    if what in ("all", "sfx"):
        render_sfx(names)
    if what in ("all", "music"):
        for name in TRACKS:
            if not names or name in names:
                render_track(name)
        for name in AMBIENCE:
            if not names or name in names:
                render_ambience(name)


if __name__ == "__main__":
    main()
