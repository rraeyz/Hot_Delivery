"""Synthesizes all game sound effects and the music loop (original, no license issues).
Run: python3 tools/make_audio.py   -> writes assets/audio/*.wav
"""
import os
import wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(1)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, r=0.1):
    e = np.ones(n)
    na, nr = int(SR * a), int(SR * r)
    if na:
        e[:na] = np.linspace(0, 1, na)
    if nr:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


def lowpass(x, k=0.1):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += k * (v - acc)
        y[i] = acc
    return y


def square(f, tt):
    return np.sign(np.sin(2 * np.pi * f * tt))


def save(name, x, vol=0.8):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = (x / m * vol * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(x.tobytes())


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def main():
    os.makedirs(OUT, exist_ok=True)
    # engine: exactly 60 cycles of 60 Hz in 1 s -> seamless loop
    tt = t(1.0)
    eng = 0.6 * np.sign(np.sin(2 * np.pi * 60 * tt)) + 0.3 * np.sin(2 * np.pi * 120 * tt) + 0.2 * np.sin(2 * np.pi * 180 * tt + 1)
    eng *= 0.75 + 0.25 * np.sin(2 * np.pi * 10 * tt)
    save("engine", lowpass(eng, 0.25), 0.5)
    tt = t(0.45)
    save("horn", (square(415, tt) + square(523, tt)) * env(len(tt), 0.01, 0.08) * 0.5, 0.6)
    tt = t(0.18)
    save("pickup", np.sin(2 * np.pi * (500 + 1800 * tt) * tt) * env(len(tt), 0.002, 0.08))
    a, b = t(0.08), t(0.5)
    cash = np.concatenate([np.sin(2 * np.pi * 1318 * a) * env(len(a), 0.001, 0.02),
                           (np.sin(2 * np.pi * 1760 * b) + 0.5 * np.sin(2 * np.pi * 2637 * b)) * np.exp(-6 * b)])
    save("cash", cash, 0.6)
    tt = t(0.7)
    crash = noise(0.7) * np.exp(-5 * tt) + np.sin(2 * np.pi * (90 - 50 * tt) * tt) * np.exp(-6 * tt) * 1.5
    save("crash", lowpass(crash, 0.4), 0.9)
    tt = t(0.4)
    save("fall", np.sin(2 * np.pi * (900 - 1500 * tt) * tt) * env(len(tt), 0.01, 0.1), 0.5)
    tt = t(0.35)
    save("splash", lowpass(noise(0.35), 0.35) * np.exp(-9 * tt), 0.7)
    tt = t(0.3)
    save("splat", lowpass(noise(0.3), 0.15) * np.exp(-12 * tt) + np.sin(2 * np.pi * 120 * tt) * np.exp(-20 * tt), 0.8)
    tt = t(0.25)
    save("thud", np.sin(2 * np.pi * (140 - 200 * tt) * tt) * np.exp(-14 * tt), 0.8)
    tt = t(0.15)
    save("bump", (np.sin(2 * np.pi * 80 * tt) + 0.3 * noise(0.15)) * np.exp(-25 * tt), 0.7)
    tt = t(0.35)
    save("throw", lowpass(noise(0.35), 0.08 + 0.4 * 0) * np.sin(np.pi * tt / 0.35), 0.6)
    notes = [523, 659, 784, 1047]
    cheer = np.concatenate([square(f, t(0.09)) * env(int(SR * 0.09), 0.002, 0.03) for f in notes] +
                           [square(1047, t(0.3)) * np.exp(-5 * t(0.3))])
    save("cheer", lowpass(cheer, 0.3), 0.45)
    tt = t(0.18)
    bark1 = (np.sin(2 * np.pi * (520 - 600 * tt) * tt) + 0.5 * noise(0.18)) * np.exp(-12 * tt)
    save("bark", lowpass(np.concatenate([bark1, np.zeros(int(SR * 0.08)), bark1]), 0.3), 0.8)
    tt = t(0.6)
    save("coo", np.sin(2 * np.pi * 320 * tt) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * tt)) * env(len(tt), 0.05, 0.2), 0.5)
    tt = t(1.2)
    save("wind", lowpass(noise(1.2), 0.05) * np.sin(np.pi * tt / 1.2), 0.6)
    tt = t(0.6)
    save("whistle", np.sin(2 * np.pi * 2800 * tt + 3 * np.sin(2 * np.pi * 30 * tt)) * env(len(tt), 0.01, 0.1), 0.5)
    tt = t(0.05)
    save("click", np.sin(2 * np.pi * 1200 * tt) * np.exp(-60 * tt), 0.5)
    make_music()


def make_music():
    bpm = 132
    beat = 60 / bpm
    bars = 16
    total = int(SR * beat * 4 * bars)
    out = np.zeros(total)
    # chords: I V vi IV / I IV V I in C, as semitone offsets from C4
    prog = [[0, 4, 7], [7, 11, 14], [9, 12, 16], [5, 9, 12]] * 2 + [[0, 4, 7], [5, 9, 12], [7, 11, 14], [0, 4, 7]] * 2
    mel_rng = np.random.default_rng(7)
    scale = [0, 2, 4, 5, 7, 9, 11, 12, 14, 16]

    def f(semi, octave=0):
        return 261.63 * 2 ** ((semi + 12 * octave) / 12)

    def add(start, dur, sig):
        i = int(start * SR)
        n = min(len(sig), total - i)
        out[i:i + n] += sig[:n]

    for bar in range(bars):
        chord = prog[bar % len(prog)]
        t0 = bar * 4 * beat
        for b in range(4):
            tb = t0 + b * beat
            # bass on beats
            tt = t(beat * 0.9)
            add(tb, 0, 0.35 * square(f(chord[0], -2), tt) * np.exp(-3 * tt))
            # arpeggio 8ths
            for e in range(2):
                tt = t(beat * 0.45)
                note = chord[(b * 2 + e) % 3]
                add(tb + e * beat / 2, 0, 0.12 * square(f(note, 1), tt) * np.exp(-8 * tt))
            # drums
            tt = t(0.15)
            if b % 2 == 0:
                add(tb, 0, 0.6 * np.sin(2 * np.pi * (110 - 300 * tt) * tt) * np.exp(-20 * tt))
            else:
                add(tb, 0, 0.25 * rng.uniform(-1, 1, len(tt)) * np.exp(-25 * tt))
            tt = t(0.04)
            add(tb + beat / 2, 0, 0.08 * rng.uniform(-1, 1, len(tt)) * np.exp(-60 * tt))
        # melody: two notes per beat, chord tones favoured
        if bar % 8 not in (3, 7):
            for s in range(8):
                if mel_rng.random() < 0.3:
                    continue
                if mel_rng.random() < 0.6:
                    note = chord[mel_rng.integers(0, 3)] + 12
                else:
                    note = scale[mel_rng.integers(0, len(scale))] + 12
                tt = t(beat * 0.48)
                sig = 0.16 * (np.sin(2 * np.pi * f(note) * tt) + 0.3 * square(f(note), tt)) * np.exp(-4 * tt)
                add(t0 + s * beat / 2, 0, sig)
    save("music", lowpass(out, 0.5), 0.6)


if __name__ == "__main__":
    main()
