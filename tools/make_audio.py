"""Synthesizes every sound effect and music loop for Embers of Thornvale.

Run:  python3 tools/make_audio.py
Writes WAV effects to assets/audio/sfx/ and OGG music loops to assets/audio/music/.
Needs numpy, scipy and ffmpeg (for the OGG music). Everything is generated from
fixed seeds, so re-running gives the same sounds. Tweak a function and re-run to change one.
"""
import os
import subprocess
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
SFX_DIR = os.path.join(ROOT, "sfx")
MUS_DIR = os.path.join(ROOT, "music")
rng = np.random.default_rng(7)


# ------------------------------------------------------------------ building blocks
def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def phase(freq):
    """freq: scalar or array (Hz) -> phase array (radians)"""
    if np.isscalar(freq):
        return None
    return 2 * np.pi * np.cumsum(freq) / SR


def sweep(f0, f1, dur, curve=1.0):
    t = np.linspace(0, 1, int(SR * dur))
    return f0 + (f1 - f0) * t ** curve


def sine(freq, dur=None):
    if np.isscalar(freq):
        return np.sin(2 * np.pi * freq * t_axis(dur))
    return np.sin(phase(freq))


def square(freq, dur=None, duty=0.5):
    if np.isscalar(freq):
        ph = (freq * t_axis(dur)) % 1.0
    else:
        ph = (np.cumsum(freq) / SR) % 1.0
    return np.where(ph < duty, 1.0, -1.0) * 0.6


def saw(freq, dur=None):
    if np.isscalar(freq):
        ph = (freq * t_axis(dur)) % 1.0
    else:
        ph = (np.cumsum(freq) / SR) % 1.0
    return (2 * ph - 1) * 0.7


def tri(freq, dur=None):
    if np.isscalar(freq):
        ph = (freq * t_axis(dur)) % 1.0
    else:
        ph = (np.cumsum(freq) / SR) % 1.0
    return 2 * np.abs(2 * ph - 1) - 1


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def lp(x, cut, order=2):
    b, a = signal.butter(order, min(cut, SR / 2 - 100) / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def hp(x, cut, order=2):
    b, a = signal.butter(order, cut / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi, SR / 2 - 100) / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def sweep_filter(x, f0, f1, kind="low", steps=24):
    """filter whose cutoff moves from f0 to f1 over the sound"""
    out = np.zeros_like(x)
    n = len(x)
    seg = max(1, n // steps)
    zi = None
    for i in range(steps):
        s, e = i * seg, (n if i == steps - 1 else (i + 1) * seg)
        f = f0 + (f1 - f0) * (i / max(1, steps - 1))
        if kind == "low":
            b, a = signal.butter(2, min(f, SR / 2 - 100) / (SR / 2), "low")
        else:
            bw = f * 0.5
            b, a = signal.butter(2, [max(30, f - bw) / (SR / 2), min(f + bw, SR / 2 - 100) / (SR / 2)], "band")
        if zi is None:
            zi = signal.lfilter_zi(b, a) * 0
        out[s:e], zi = signal.lfilter(b, a, x[s:e], zi=zi)
    return out


def env(n, a=0.005, d=0.1, s=0.0, r=0.05, sustain_time=0.0):
    """ADSR envelope of length n samples"""
    A, D, S_t, R = int(a * SR), int(d * SR), int(sustain_time * SR), int(r * SR)
    e = np.concatenate([
        np.linspace(0, 1, max(A, 1)),
        np.linspace(1, s, max(D, 1)),
        np.full(S_t, s),
        np.linspace(s, 0, max(R, 1)),
    ])
    if len(e) < n:
        e = np.concatenate([e, np.zeros(n - len(e))])
    return e[:n]


def decay(n, k):
    return np.exp(-np.arange(n) / SR * k)


def fit(x, n):
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def mix(*parts):
    n = max(len(p) for p in parts)
    return sum(fit(p, n) for p in parts)


def at(x, offset, total):
    out = np.zeros(int(total * SR))
    s = int(offset * SR)
    e = min(len(out), s + len(x))
    out[s:e] += x[: e - s]
    return out


def pluck(freq, dur, bright=0.5):
    """Karplus-Strong plucked string"""
    n = int(SR * dur)
    period = max(2, int(SR / freq))
    buf = rng.uniform(-1, 1, period * 4)
    buf = lp(buf, min(freq * 8, 9000))[-period:]
    buf = buf / (np.max(np.abs(buf)) or 1)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = (1 - bright * 0.5) * 0.996 * (buf[i % period] + buf[(i + 1) % period]) * 0.5 + bright * 0.5 * 0.996 * buf[i % period]
    a = min(n, int(SR * 0.004))
    out[:a] *= np.linspace(0, 1, a)
    return out


def bell(freq, dur):
    t = t_axis(dur)
    mod = np.sin(2 * np.pi * freq * 3.5 * t) * decay(len(t), 6) * 2.0
    return np.sin(2 * np.pi * freq * t + mod) * decay(len(t), 4)


def norm(x, peak=0.85):
    m = np.max(np.abs(x)) or 1
    return x / m * peak


def fade_edges(x, ms=4):
    n = int(SR * ms / 1000)
    if len(x) > 2 * n:
        x[:n] *= np.linspace(0, 1, n)
        x[-n:] *= np.linspace(1, 0, n)
    return x


def save_sfx(name, x, peak=0.8):
    x = fade_edges(norm(np.asarray(x, dtype=float), peak))
    wavfile.write(os.path.join(SFX_DIR, name + ".wav"), SR, (x * 32767).astype(np.int16))


# ------------------------------------------------------------------ sound effects
def make_sfx():
    os.makedirs(SFX_DIR, exist_ok=True)
    S = {}
    d = 0.18
    S["swing"] = sweep_filter(noise(d), 2400, 700, "band") * env(int(SR * d), 0.02, 0.16)
    d = 0.26
    S["swing_heavy"] = sweep_filter(noise(d), 1100, 250, "band") * env(int(SR * d), 0.03, 0.22) + sine(sweep(120, 60, d)) * env(int(SR * d), 0.04, 0.2) * 0.4
    d = 0.14
    S["hit"] = mix(sine(sweep(170, 55, d)) * decay(int(SR * d), 30), lp(noise(0.03), 3000) * decay(int(SR * 0.03), 120) * 0.8)
    d = 0.3
    S["hit_crit"] = mix(S["hit"], (square(1250, d) * 0.4 + sine(1870, d) * 0.4) * decay(int(SR * d), 14))
    S["bow"] = mix(pluck(196, 0.3, 0.2) * 0.8, sweep_filter(noise(0.18), 3000, 1500, "band") * env(int(SR * 0.18), 0.01, 0.15) * 0.5)
    d = 0.1
    S["arrow_hit"] = mix(bp(noise(d), 900, 2500) * decay(int(SR * d), 50), sine(sweep(320, 140, d)) * decay(int(SR * d), 35))
    d = 0.28
    f = sweep(820, 1500, d) + 40 * np.sin(2 * np.pi * 30 * t_axis(d))
    S["bolt"] = mix(sine(f) * env(int(SR * d), 0.01, 0.26) * 0.7, hp(noise(d), 5000) * decay(int(SR * d), 20) * 0.25)
    d = 0.4
    S["fire_cast"] = mix(sweep_filter(noise(d), 300, 2500) * env(int(SR * d), 0.08, 0.32), sine(sweep(180, 420, d)) * env(int(SR * d), 0.05, 0.35) * 0.5)
    d = 0.9
    S["explosion"] = mix(sweep_filter(noise(d), 2200, 150) * decay(int(SR * d), 5), sine(sweep(85, 30, d)) * decay(int(SR * d), 6) * 1.2)
    d = 0.65
    shimmer = sum(sine(f0, d) * decay(int(SR * d), 6 + i) for i, f0 in enumerate(rng.uniform(1800, 4200, 7)))
    S["frost"] = mix(shimmer * 0.5, hp(noise(d), 3500) * env(int(SR * d), 0.01, 0.6) * 0.5)
    d = 0.45
    gate = (rng.uniform(0, 1, int(d * 60)) > 0.45).astype(float).repeat(int(SR / 60) + 1)[: int(SR * d)]
    S["lightning"] = hp(noise(d), 1200) * gate * decay(int(SR * d), 5) + sine(sweep(120, 50, d)) * decay(int(SR * d), 8) * 0.4
    notes = [523.25, 659.25, 783.99, 1046.5]
    S["heal"] = sum(at(bell(f, 0.5) * 0.6, i * 0.07, 0.8) for i, f in enumerate(notes))
    d = 0.42
    S["buff"] = mix(square(sweep(280, 880, d), duty=0.3) * env(int(SR * d), 0.02, 0.38) * 0.4, at(bell(1318.5, 0.4), 0.18, d))
    d = 0.2
    S["dash"] = sweep_filter(noise(d), 500, 2800, "band") * env(int(SR * d), 0.01, 0.19)
    d = 0.24
    S["dodge"] = sweep_filter(noise(d), 1400, 500, "band") * env(int(SR * d), 0.03, 0.2) * 0.8
    d = 0.32
    f = np.concatenate([sweep(900, 300, d / 2), sweep(300, 1400, d / 2)])
    S["blink"] = mix(sine(f) * env(len(f), 0.01, 0.3) * 0.7, hp(noise(d), 6000) * decay(int(SR * d), 10) * 0.3)
    d = 0.32
    S["enemy_die"] = mix(lp(noise(d), 900) * decay(int(SR * d), 12), sine(sweep(420, 70, d)) * decay(int(SR * d), 9) * 0.8)
    d = 0.2
    S["hurt"] = mix(square(sweep(240, 110, d), duty=0.35) * decay(int(SR * d), 14) * 0.6, lp(noise(d), 1500) * decay(int(SR * d), 25) * 0.6)
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5]
    S["level_up"] = sum(at((square(f, 0.35, 0.25) * 0.35 + sine(f, 0.35) * 0.5) * decay(int(SR * 0.35), 7), i * 0.08, 1.0) for i, f in enumerate(notes))
    S["pickup_sigil"] = mix(bell(1567.98, 0.5), at(bell(2093.0, 0.45), 0.08, 0.55))
    d = 0.15
    S["pickup_potion"] = sine(sweep(380, 820, d)) * env(int(SR * d), 0.005, 0.14)
    S["potion"] = sum(at(sine(sweep(f, f * 0.6, 0.09)) * env(int(SR * 0.09), 0.005, 0.08), i * 0.11, 0.4) for i, f in enumerate([520, 460, 400]))
    S["loot"] = mix(square(1318.5, 0.08, 0.5) * decay(int(SR * 0.08), 20) * 0.5, at(square(1760, 0.18, 0.5) * decay(int(SR * 0.18), 14) * 0.5, 0.07, 0.25))
    S["loot_rare"] = sum(at(bell(f, 0.45) * 0.6, i * 0.06, 0.75) for i, f in enumerate([1046.5, 1318.5, 1567.98, 2093.0]))
    d = 0.28
    clank = sum(sine(f, d) * decay(int(SR * d), k) for f, k in [(1830, 18), (2650, 22), (3420, 26), (910, 14)])
    S["equip"] = mix(clank * 0.4, bp(noise(0.05), 2500, 6000) * decay(int(SR * 0.05), 60))
    S["ui_click"] = square(1100, 0.035, 0.5) * decay(int(SR * 0.035), 90)
    S["ui_open"] = mix(sine(660, 0.08) * env(int(SR * 0.08), 0.004, 0.07), at(sine(990, 0.1) * env(int(SR * 0.1), 0.004, 0.09), 0.06, 0.16))
    S["ui_close"] = mix(sine(990, 0.08) * env(int(SR * 0.08), 0.004, 0.07), at(sine(660, 0.1) * env(int(SR * 0.1), 0.004, 0.09), 0.06, 0.16))
    S["dialog"] = sine(sweep(560, 640, 0.05)) * env(int(SR * 0.05), 0.004, 0.045)
    d = 1.4
    vib = 85 + 12 * np.sin(2 * np.pi * 7 * t_axis(d)) + sweep(10, -25, d)
    roar = saw(vib) + saw(vib * 1.51) * 0.6 + lp(noise(d), 700) * 0.8
    S["boss_roar"] = np.tanh(lp(roar, 1400) * 2.5) * env(int(SR * d), 0.15, 0.4, 0.7, 0.6, 0.3)
    d = 1.6
    S["boss_summon"] = mix(lp(noise(d), 160) * np.linspace(0, 1, int(SR * d)) ** 1.5 * 3, sine(sweep(60, 160, d)) * np.linspace(0, 1, int(SR * d)) * 0.6)
    d = 2.2
    S["boss_die"] = mix(S["explosion"] * 1.2, at(np.tanh(lp(saw(sweep(140, 40, 1.8)) + lp(noise(1.8), 500), 1000) * 2) * decay(int(SR * 1.8), 1.8) * 0.8, 0.1, d))
    notes = [440.0, 392.0, 349.23, 293.66]
    S["death"] = sum(at((tri(f, 0.6) * 0.5 + sine(f / 2, 0.6) * 0.4) * decay(int(SR * 0.6), 3), i * 0.28, 1.6) for i, f in enumerate(notes))
    chord = [261.63, 329.63, 392.0, 523.25]
    swell = sum(saw(f, 1.8) * 0.25 + sine(f * 2, 1.8) * 0.2 for f in chord)
    S["trophy"] = mix(lp(swell, 2400) * env(int(SR * 1.8), 0.5, 0.6, 0.6, 0.7, 0.2), at(bell(1046.5, 1.0), 0.3, 1.8), at(bell(1567.98, 1.0), 0.5, 1.8))
    d = 0.16
    S["enemy_shot"] = square(sweep(520, 200, d), duty=0.4) * decay(int(SR * d), 16) * 0.6
    d = 0.22
    S["orb_shot"] = sine(300 + 60 * np.sin(2 * np.pi * 25 * t_axis(d))) * env(int(SR * d), 0.01, 0.2)
    S["trap"] = mix(bp(noise(0.06), 2000, 7000) * decay(int(SR * 0.06), 70), sine(sweep(900, 400, 0.12)) * decay(int(SR * 0.12), 30) * 0.5)
    d = 1.1
    f = np.concatenate([sweep(380, 720, 0.35), sweep(720, 680, 0.4), sweep(680, 480, 0.35)])
    f = f + 9 * np.sin(2 * np.pi * 5.5 * np.arange(len(f)) / SR)
    S["howl"] = lp(sine(f) + 0.3 * sine(f * 2), 2000) * env(len(f), 0.12, 0.3, 0.8, 0.4, 0.3)
    d = 0.45
    S["smoke"] = lp(noise(d), 700) * env(int(SR * d), 0.01, 0.42)
    d = 0.45
    S["shield"] = mix(sine(sweep(300, 620, d)) * env(int(SR * d), 0.02, 0.4) * 0.5, sine(sweep(303, 626, d)) * env(int(SR * d), 0.02, 0.4) * 0.5, at(bell(1244.5, 0.35), 0.15, d))
    S["step"] = lp(noise(0.06), 600) * decay(int(SR * 0.06), 60)
    chord = [220.0, 277.18, 329.63]
    S["rune"] = mix(sum(sine(f, 1.0) for f in chord) * env(int(SR * 1.0), 0.2, 0.5, 0.3, 0.3, 0.1) * 0.4, at(bell(880, 0.8), 0.1, 1.0))
    d = 0.3
    S["slam"] = mix(sine(sweep(110, 35, 0.5)) * decay(int(SR * 0.5), 7) * 1.3, lp(noise(0.5), 800) * decay(int(SR * 0.5), 9))
    d = 0.9
    S["meteor_fall"] = sine(sweep(2200, 350, d, 0.7)) * env(int(SR * d), 0.05, 0.8) * 0.6 + hp(noise(d), 2000) * np.linspace(0, 1, int(SR * d)) * 0.3
    S["menu_start"] = sum(at(bell(f, 0.6) * 0.6, i * 0.1, 0.9) for i, f in enumerate([392.0, 523.25, 659.25]))
    for k, v in S.items():
        save_sfx(k, v, 0.55 if k in ("ui_click", "step", "dialog") else 0.8)
    print("sfx:", len(S))


# ------------------------------------------------------------------ music
NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def chord_notes(name, octave=4):
    """'Em', 'G', 'Bb', 'D/E' style names -> list of midi notes (root, third, fifth)"""
    name = name.split("/")[0]
    minor = name.endswith("m")
    root = name[:-1] if minor else name
    r = 12 * (octave + 1) + NOTE[root]
    return [r, r + (3 if minor else 4), r + 7]


def pad(freq, dur, bright=1800):
    x = sum(saw(freq * (1 + det), dur) for det in (-0.006, 0.0, 0.007)) / 3
    return lp(x, bright) * env(int(SR * dur), dur * 0.3, 0.1, 1.0, dur * 0.35, dur * 0.25)


def soft_lead(freq, dur):
    t = t_axis(dur)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5 * t) * np.clip(t * 3, 0, 1)
    x = sine(freq * vib) * 0.8 + tri(freq * vib) * 0.25
    return x * env(len(t), 0.04, 0.15, 0.6, min(0.2, dur * 0.4), max(0, dur - 0.4))


def kick(dur=0.35):
    return sine(sweep(130, 40, dur, 0.4)) * decay(int(SR * dur), 9)


def snare(dur=0.2):
    return mix(bp(noise(dur), 1500, 7000) * decay(int(SR * dur), 18) * 0.7, sine(sweep(220, 160, dur)) * decay(int(SR * dur), 25) * 0.5)


def hat(dur=0.05):
    return hp(noise(dur), 7000) * decay(int(SR * dur), 70)


def hand_drum(dur=0.25):
    return mix(sine(sweep(210, 150, dur)) * decay(int(SR * dur), 16), lp(noise(0.03), 2000) * decay(int(SR * 0.03), 80) * 0.4)


def render_track(name, bpm, chords, scale, *, bars_per_chord=2, repeats=2, pad_oct=3, bright=1500, lead="lead",
                 arp=True, arp_inst="pluck", bass=True, drums=None, melody_density=0.55, seed=1, lead_oct=5, vol=0.75):
    local = np.random.default_rng(seed)
    beat = 60.0 / bpm
    bar = beat * 4
    n_bars = len(chords) * bars_per_chord * repeats
    total = n_bars * bar
    out = np.zeros(int(SR * (total + 4)))

    def put(x, t0, g=1.0):
        s = int(t0 * SR)
        e = s + len(x)
        out[s:e] += x * g

    # motif: one bar of melody rhythm reused with variation
    rhythms = [[0, 1, 1.5, 2, 3], [0, 0.5, 1, 2, 2.5, 3], [0, 1.5, 2, 3], [0, 1, 2, 2.5, 3.5]]
    motif = rhythms[seed % len(rhythms)]
    scale_midi = [12 * (lead_oct + 1) + NOTE[n] for n in scale]
    scale_midi = scale_midi + [m + 12 for m in scale_midi]
    for b in range(n_bars):
        ci = (b // bars_per_chord) % len(chords)
        cn = chords[ci]
        t0 = b * bar
        notes = chord_notes(cn, pad_oct)
        if b % bars_per_chord == 0:
            for m in notes:
                put(pad(midi(m), bar * bars_per_chord + 0.5, bright), t0, 0.16)
        if bass:
            root = chord_notes(cn, 2)[0]
            for k in range(4 if drums == "boss" else 2):
                step = beat if drums == "boss" else beat * 2
                put(tri(midi(root), step * 0.95) * env(int(SR * (step * 0.95)), 0.01, 0.2, 0.6, 0.1, step * 0.5), t0 + k * step, 0.3)
        if arp:
            seq = notes + [notes[1] + 12, notes[2] + 12, notes[0] + 12]
            steps = 8
            for k in range(steps):
                m = seq[[0, 1, 2, 3, 4, 3, 2, 1][k]] + 12
                tt = t0 + k * beat / 2
                if arp_inst == "pluck":
                    put(pluck(midi(m), beat * 1.2, 0.35), tt, 0.16)
                else:
                    put(bell(midi(m), beat * 1.5), tt, 0.09)
        # melody: phrase on odd bar pairs, rest on others for breathing room
        if lead and (b // 2) % 2 == 1 or (lead and b >= n_bars - 2 and b % 2 == 0):
            chord_pcs = {m % 12 for m in notes}
            prev = None
            for k, r in enumerate(motif):
                if local.random() > melody_density + 0.3:
                    continue
                cands = [m for m in scale_midi if (m % 12) in chord_pcs] if k == 0 else scale_midi
                if prev is not None:
                    cands = [m for m in cands if abs(m - prev) <= 5] or cands
                m = cands[local.integers(len(cands))]
                prev = m
                nxt = motif[k + 1] if k + 1 < len(motif) else 4
                dur = (nxt - r) * beat * 0.95
                if lead == "lead":
                    put(soft_lead(midi(m), dur + 0.1), t0 + r * beat, 0.2)
                elif lead == "bell":
                    put(bell(midi(m), dur + 0.8), t0 + r * beat, 0.16)
                elif lead == "saw":
                    x = lp(saw(midi(m), dur + 0.05), 2500) * env(int(SR * (dur + 0.05)), 0.01, 0.1, 0.7, 0.05, dur * 0.7)
                    put(x, t0 + r * beat, 0.14)
        if drums == "boss":
            for k in range(4):
                put(kick(), t0 + k * beat, 0.55)
                put(hat(), t0 + k * beat + beat / 2, 0.18)
            put(snare(), t0 + beat, 0.4)
            put(snare(), t0 + 3 * beat, 0.4)
        elif drums == "hand":
            for k, g in [(0, 0.35), (1.5, 0.2), (2, 0.28), (3, 0.2), (3.5, 0.15)]:
                put(hand_drum(), t0 + k * beat, g)
    # wrap the tail into the start so the loop is seamless
    n = int(SR * total)
    loop = out[:n].copy()
    tail = out[n:]
    loop[: len(tail)] += tail[: n]
    loop = loop / (np.max(np.abs(loop)) or 1) * vol
    wav = os.path.join(MUS_DIR, name + ".wav")
    wavfile.write(wav, SR, (loop * 32767).astype(np.int16))
    ogg = os.path.join(MUS_DIR, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", ogg], check=True)
    os.remove(wav)
    print("music:", name, "%.1fs" % total)


def make_music():
    os.makedirs(MUS_DIR, exist_ok=True)
    render_track("title", 70, ["Dm", "Bb", "F", "C"], ["D", "E", "F", "G", "A", "Bb", "C"], lead="bell", arp_inst="bell", bright=1300, seed=3)
    render_track("meadow", 92, ["G", "Em", "C", "D"], ["G", "A", "B", "D", "E"], lead="lead", seed=5, bright=1800)
    render_track("thornwood", 80, ["Em", "D", "C", "D"], ["E", "F#", "G", "A", "B", "C#", "D"], lead="lead", drums="hand", seed=8, bright=1200, lead_oct=4)
    render_track("mire", 62, ["Am", "F", "Dm", "E"], ["A", "B", "C", "D", "E", "F", "G#"], lead="bell", arp=False, seed=11, bright=900, melody_density=0.35)
    render_track("peaks", 72, ["D", "G", "Bm", "A"], ["D", "E", "F#", "G#", "A", "B", "C#"], lead="bell", arp_inst="bell", seed=13, bright=2200)
    render_track("boss", 132, ["Cm", "Ab", "Bb", "G"], ["C", "D", "Eb", "F", "G", "Ab", "B"], lead="saw", drums="boss", seed=17, bright=2600, bars_per_chord=1, repeats=4, vol=0.8)


if __name__ == "__main__":
    make_sfx()
    make_music()
