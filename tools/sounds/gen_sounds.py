"""Synthesizes every sound effect and the music loop for the game as 16-bit mono WAV files.

Usage:  python gen_sounds.py <output_dir>
"""
import sys
import wave
import numpy as np

SR = 44100
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, attack=0.005, release=0.1, curve=2.0):
    e = np.ones(n)
    a = max(1, int(SR * attack))
    r = max(1, int(SR * release))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r) ** curve
    return e


def sine(freq, dur, vol=1.0):
    t = t_axis(dur)
    f = freq if np.ndim(freq) else np.full_like(t, freq)
    phase = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(phase) * vol


def square(freq, dur, vol=1.0, duty=0.5):
    t = t_axis(dur)
    f = freq if np.ndim(freq) else np.full_like(t, freq)
    phase = (np.cumsum(f) / SR) % 1.0
    return np.where(phase < duty, 1.0, -1.0) * vol


def saw(freq, dur, vol=1.0):
    t = t_axis(dur)
    f = freq if np.ndim(freq) else np.full_like(t, freq)
    phase = (np.cumsum(f) / SR) % 1.0
    return (phase * 2 - 1) * vol


def noise(dur, vol=1.0):
    return rng.uniform(-1, 1, int(SR * dur)) * vol


def lowpass(x, k=0.1):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += (v - acc) * k
        y[i] = acc
    return y


def note(freq, dur, kind="sine", vol=0.6, attack=0.005, release=None, curve=2.0):
    release = release if release is not None else dur * 0.8
    w = {"sine": sine, "square": square, "saw": saw}[kind](freq, dur, 1.0)
    return w * env(len(w), attack, release, curve) * vol


def mix(*parts, length=None):
    n = length or max(len(p) for p, _ in parts)
    out = np.zeros(n)
    for p, off in parts:
        s = int(off * SR)
        e = min(n, s + len(p))
        if e > s:
            out[s:e] += p[: e - s]
    return out


def add(out, p, off):
    s = int(off * SR)
    e = min(len(out), s + len(p))
    if e > s:
        out[s:e] += p[: e - s]


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def save(path, x, gain=0.9):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * gain
    data = (x * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", path, f"{len(x)/SR:.2f}s")


def make_buy():
    a = note(1318, 0.12, "square", 0.35, release=0.1) + note(1318, 0.12, "sine", 0.4, release=0.1)
    b = note(1760, 0.45, "square", 0.3, release=0.4, curve=1.5) + note(1760, 0.45, "sine", 0.5, release=0.4, curve=1.5)
    n = noise(0.05, 0.4) * env(int(SR * 0.05), 0.001, 0.04)
    return mix((a, 0.0), (b, 0.09), (n, 0.0), length=int(SR * 0.6))


def make_collect():
    notes = [midi(m) for m in (72, 76, 79, 84)]
    parts = [(note(f, 0.18, "sine", 0.5, release=0.16) + note(f * 2, 0.18, "sine", 0.15, release=0.12), i * 0.06) for i, f in enumerate(notes)]
    return mix(*parts, length=int(SR * 0.5))


def make_click():
    return mix((note(900, 0.05, "square", 0.4, release=0.04), 0.0), (note(1400, 0.04, "sine", 0.3, release=0.03), 0.0))


def make_jump():
    f = np.linspace(260, 620, int(SR * 0.16))
    w = sine(f, 0.16, 0.6) * env(len(f), 0.004, 0.12)
    return w


def make_land():
    n = lowpass(noise(0.14), 0.05) * env(int(SR * 0.14), 0.001, 0.12) * 2.0
    s = sine(np.linspace(120, 50, int(SR * 0.14)), 0.14, 0.7) * env(int(SR * 0.14), 0.001, 0.12)
    return n + s


def make_step(freq=180, seed=0):
    r = np.random.default_rng(seed)
    n = lowpass(r.uniform(-1, 1, int(SR * 0.07)), 0.12) * env(int(SR * 0.07), 0.001, 0.06) * 2.5
    s = sine(freq, 0.07, 0.35) * env(int(SR * 0.07), 0.001, 0.05)
    return n + s


def make_swing():
    n = noise(0.28)
    out = np.zeros_like(n)
    acc = 0.0
    for i in range(len(n)):
        k = 0.02 + 0.5 * (i / len(n)) ** 2
        acc += (n[i] - acc) * k
        out[i] = acc
    return out * env(len(out), 0.03, 0.18) * 2.0


def make_hit():
    n = lowpass(noise(0.3), 0.08) * env(int(SR * 0.3), 0.001, 0.25) * 2.0
    s = sine(np.linspace(220, 55, int(SR * 0.3)), 0.3, 0.9) * env(int(SR * 0.3), 0.001, 0.26)
    bonk = note(520, 0.12, "square", 0.25, release=0.1)
    return mix((n, 0.0), (s, 0.0), (bonk, 0.0), length=int(SR * 0.35))


def make_steal():
    f = np.linspace(300, 900, int(SR * 0.35))
    w = square(f, 0.35, 0.3) * env(len(f), 0.01, 0.3) + sine(f * 1.5, 0.35, 0.3) * env(len(f), 0.01, 0.3)
    return w


def make_alarm():
    dur = 2.0
    t = t_axis(dur)
    f = np.where((t * 2.5) % 1.0 < 0.5, 620.0, 880.0)
    w = square(f, dur, 0.35) + saw(f * 0.5, dur, 0.2)
    return w * env(len(w), 0.01, 0.05)


def make_deliver():
    ns = [midi(m) for m in (67, 72, 76, 79, 84)]
    parts = [(note(f, 0.28, "square", 0.22, release=0.25) + note(f, 0.28, "sine", 0.4, release=0.25), i * 0.08) for i, f in enumerate(ns)]
    return mix(*parts, length=int(SR * 0.85))


def make_error():
    a = note(200, 0.16, "saw", 0.45, release=0.12)
    b = note(150, 0.22, "saw", 0.45, release=0.2)
    return mix((a, 0.0), (b, 0.15), length=int(SR * 0.4))


def make_lock():
    f = np.linspace(1400, 200, int(SR * 0.4))
    zap = square(f, 0.4, 0.3) * env(len(f), 0.003, 0.35)
    hum = sine(110, 0.5, 0.35) * env(int(SR * 0.5), 0.02, 0.4)
    return mix((zap, 0.0), (hum, 0.1), length=int(SR * 0.65))


def make_unlock():
    f = np.linspace(200, 1100, int(SR * 0.3))
    return square(f, 0.3, 0.3) * env(len(f), 0.003, 0.25)


def make_rebirth():
    ns = [midi(m) for m in (60, 64, 67, 72, 76, 79, 84, 88)]
    parts = [(note(f, 0.5, "sine", 0.45, release=0.45) + note(f * 2, 0.5, "sine", 0.15, release=0.4), i * 0.09) for i, f in enumerate(ns)]
    shimmer = noise(1.0, 0.15) * np.linspace(0, 1, int(SR * 1.0)) * env(int(SR * 1.0), 0.01, 0.5)
    parts.append((shimmer, 0.3))
    return mix(*parts, length=int(SR * 1.5))


def make_rare():
    ns = [(midi(67), 0.0), (midi(67), 0.14), (midi(72), 0.28), (midi(76), 0.45), (midi(79), 0.62)]
    parts = [(note(f, 0.4, "square", 0.22, release=0.35) + note(f, 0.4, "sine", 0.4, release=0.35), off) for f, off in ns]
    return mix(*parts, length=int(SR * 1.1))


def make_shop():
    return make_collect()


def make_sell():
    a = note(900, 0.1, "sine", 0.5, release=0.08)
    b = note(600, 0.18, "sine", 0.5, release=0.15)
    return mix((a, 0.0), (b, 0.09), length=int(SR * 0.3))


def make_pop():
    f = np.linspace(500, 1200, int(SR * 0.08))
    return sine(f, 0.08, 0.6) * env(len(f), 0.002, 0.07)


def make_music():
    bpm = 118
    beat = 60.0 / bpm
    bars = 16
    total = bars * 4 * beat
    n = int(SR * total)
    out = np.zeros(n)
    prog = [(48, [60, 64, 67]), (55, [59, 62, 67]), (57, [60, 64, 69]), (53, [60, 65, 69])]
    lead_scale = [72, 74, 76, 79, 81, 79, 76, 74]
    for bar in range(bars):
        root, chord = prog[bar % 4]
        base = bar * 4 * beat
        for b in range(4):
            # bass on every beat, offbeat chord stabs
            add(out, note(midi(root), beat * 0.9, "square", 0.22, release=beat * 0.7), base + b * beat)
            for c in chord:
                add(out, note(midi(c), beat * 0.4, "square", 0.07, release=beat * 0.35), base + b * beat + beat * 0.5)
        # lead melody (eighth notes), a little variation per bar
        for i in range(8):
            if (i + bar) % 3 == 2 and bar % 2 == 1:
                continue
            m = lead_scale[(i * (1 + bar % 2) + bar) % len(lead_scale)]
            add(out, note(midi(m), beat * 0.45, "sine", 0.18, release=beat * 0.4) + note(midi(m), beat * 0.45, "square", 0.05, release=beat * 0.3), base + i * beat * 0.5)
        # hi-hat
        for i in range(8):
            h = noise(0.04, 0.12) * env(int(SR * 0.04), 0.001, 0.035)
            add(out, h, base + i * beat * 0.5)
        # kick on beats 1 and 3
        for b in (0, 2):
            k = sine(np.linspace(150, 45, int(SR * 0.18)), 0.18, 0.7) * env(int(SR * 0.18), 0.001, 0.16)
            add(out, k, base + b * beat)
    return out


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    sounds = {
        "buy": make_buy(), "collect": make_collect(), "click": make_click(), "jump": make_jump(),
        "land": make_land(), "step1": make_step(180, 1), "step2": make_step(150, 2),
        "swing": make_swing(), "hit": make_hit(), "steal": make_steal(), "alarm": make_alarm(),
        "deliver": make_deliver(), "error": make_error(), "lock": make_lock(), "unlock": make_unlock(),
        "rebirth": make_rebirth(), "rare": make_rare(), "shop": make_shop(), "sell": make_sell(), "pop": make_pop(),
    }
    for name, data in sounds.items():
        save(f"{out}/{name}.wav", data, 0.85)
    save(f"{out}/music.wav", make_music(), 0.55)


if __name__ == "__main__":
    main()

