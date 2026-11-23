"""Deterministic sound synthesis for Modern Ships (no external samples).

Run:  python3 tools/audio/synth.py game/assets/audio
Writes 44.1 kHz / 16-bit mono WAVs. Loop files are made seamless by crossfading their tail into their head.
"""
import os
import sys
import wave

import numpy as np

SR = 44100
OUT = sys.argv[1] if len(sys.argv) > 1 else "game/assets/audio"
rng = np.random.default_rng(1234)


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def noise(dur):
    return rng.uniform(-1.0, 1.0, int(dur * SR))


def exp_sweep(f0, f1, dur):
    t = t_axis(dur)
    return f0 * (f1 / f0) ** (t / dur)


def osc(freq, kind="sine"):
    phase = np.cumsum(freq) / SR
    if kind == "saw":
        return 2.0 * (phase - np.floor(phase + 0.5))
    if kind == "square":
        return np.sign(np.sin(2 * np.pi * phase))
    return np.sin(2 * np.pi * phase)


def biquad(x, fc, q=0.707, mode="lp"):
    """Time-varying RBJ biquad. fc: scalar or array (Hz)."""
    fc = np.broadcast_to(np.asarray(fc, dtype=float), x.shape)
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(len(x)):
        w0 = 2 * np.pi * min(fc[i], SR * 0.45) / SR
        cw, sw = np.cos(w0), np.sin(w0)
        alpha = sw / (2 * q)
        if mode == "lp":
            b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
        elif mode == "hp":
            b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
        else:  # band-pass
            b0, b1, b2 = alpha, 0.0, -alpha
        a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
        yi = (b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1, y2, y1 = x1, x[i], y1, yi
        y[i] = yi
    return y


def env(dur, attack, decay_to_end=True, curve=4.0):
    t = t_axis(dur)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = np.exp(-curve * t / dur) if decay_to_end else np.ones_like(t)
    return a * d


def crackle(dur, density, amp=1.0):
    x = np.zeros(int(dur * SR))
    n = int(dur * density)
    idx = rng.integers(0, len(x) - 200, n)
    for i in idx:
        L = rng.integers(20, 160)
        x[i:i + L] += rng.uniform(-1, 1, L) * np.exp(-np.arange(L) / (L / 4)) * amp
    return x


def pad(x, dur):
    n = int(dur * SR)
    return np.pad(x, (0, max(0, n - len(x))))[:n]


def norm(x, peak=0.9):
    m = np.max(np.abs(x))
    return x / m * peak if m > 0 else x


def make_loop(x, fade=0.08):
    n = int(fade * SR)
    head, tail = x[:n].copy(), x[-n:].copy()
    w = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = head * w + tail * (1 - w)
    return x


def write(name, x, peak=0.9):
    x = norm(x, peak)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", name, round(len(x) / SR, 3), "s")


# ---------------------------------------------------------------- railgun

def charge():
    d = 1.2
    f = exp_sweep(60, 1500, d)
    x = osc(f, "saw") + osc(f * 1.012, "saw") + 0.4 * osc(f * 0.5, "square")
    x = biquad(x, exp_sweep(250, 5200, d), q=5.0)
    x += crackle(d, 40, 0.6) * np.linspace(0, 1, int(d * SR)) ** 2
    return x * np.linspace(0.02, 1.0, int(d * SR)) ** 1.5


def overcharge_loop():
    d = 1.0
    t = t_axis(d)
    f = 1550 + 40 * np.sin(2 * np.pi * 6 * t)
    x = osc(f, "saw") * 0.6 + osc(f * 0.5, "square") * 0.25 + 0.5 * np.sin(2 * np.pi * 110 * t)
    x = biquad(x, 4800, q=2.0)
    x *= 0.8 + 0.2 * np.sin(2 * np.pi * 12 * t)
    x += crackle(d + 0.08, 60, 0.8)[: len(x)]
    return make_loop(np.concatenate([x, x[: int(0.08 * SR)]]))


def fire():
    d = 3.2
    t = t_axis(d)
    boom = biquad(noise(d), exp_sweep(6000, 70, d), q=0.9) * env(d, 0.004, curve=2.6)
    sub = osc(exp_sweep(110, 22, d)) * env(d, 0.003, curve=4.5) * 1.7
    crack = biquad(noise(d), 2400, mode="hp") * np.exp(-t / 0.03) * 1.0
    zap = osc(exp_sweep(2600, 160, d)) * np.exp(-t / 0.07) * 0.5
    rumble = biquad(noise(d), 140) * np.exp(-t / 1.3) * np.minimum(1, t / 0.15) * 1.4
    return boom + sub + crack + zap + rumble


def misfire():
    d = 1.4
    x = crackle(d, 160, 1.0) * np.exp(-t_axis(d) / 0.5)
    x += osc(exp_sweep(1300, 70, d), "saw") * np.exp(-t_axis(d) / 0.35) * 0.6
    x += osc(exp_sweep(90, 30, d)) * np.exp(-t_axis(d) / 0.3)
    return biquad(x, 6000)


def recharge():
    d = 0.6
    t = t_axis(d)
    x = osc(exp_sweep(320, 980, d)) * (0.6 + 0.4 * np.sin(2 * np.pi * 22 * t))
    return x * np.sin(np.pi * t / d) ** 2 * 0.5


# ---------------------------------------------------------------- impacts & weapons

def impact():
    d = 1.5
    x = biquad(noise(d), exp_sweep(1400, 70, d)) * env(d, 0.006, curve=3.5)
    x += osc(exp_sweep(80, 30, d)) * env(d, 0.004, curve=6.0)
    return x


def explosion():
    d = 2.4
    t = t_axis(d)
    x = biquad(noise(d), exp_sweep(2600, 60, d), q=0.8) * env(d, 0.01, curve=2.6)
    x *= 0.75 + 0.25 * np.sin(2 * np.pi * 7 * t + 3 * np.sin(2 * np.pi * 2 * t))
    x += crackle(d, 30, 0.5) * np.exp(-t / 0.9)
    x += osc(exp_sweep(70, 25, d)) * env(d, 0.005, curve=4.0) * 1.2
    return x


def flak():
    d = 0.14
    x = biquad(noise(d), 1600, q=1.4, mode="bp") * np.exp(-t_axis(d) / 0.025) * 3
    x += biquad(noise(d), 300) * np.exp(-t_axis(d) / 0.04)
    return x


def enemy_gun():
    d = 0.18
    x = biquad(noise(d), 900, q=1.2, mode="bp") * np.exp(-t_axis(d) / 0.03) * 3
    x += osc(exp_sweep(160, 60, d)) * np.exp(-t_axis(d) / 0.05)
    return x


def shell_whistle():
    d = 1.8
    t = t_axis(d)
    x = osc(exp_sweep(1900, 650, d)) * (0.3 + 0.7 * t / d)
    x += biquad(noise(d), 2500, q=3.0, mode="bp") * 0.4 * t / d
    return x * np.minimum(1, (d - t) / 0.05)


def torpedo():
    d = 1.6
    t = t_axis(d)
    x = osc(exp_sweep(110, 40, d)) * np.exp(-t / 0.12) * 1.2
    bub = biquad(noise(d), 700) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t))
    return x + bub * env(d, 0.05, curve=2.0)


def splash():
    d = 1.1
    t = t_axis(d)
    x = biquad(noise(d), exp_sweep(3200, 400, d)) * env(d, 0.005, curve=3.0)
    for k in range(6):
        t0 = rng.uniform(0.1, 0.8)
        f = rng.uniform(500, 1200)
        x += np.sin(2 * np.pi * f * (1 + 2 * np.clip(t - t0, 0, None)) * np.clip(t - t0, 0, None)) * np.exp(-np.clip(t - t0, 0, None) / 0.04) * (t > t0) * 0.15
    return x


def thunder(seed):
    r = np.random.default_rng(seed)
    d = 3.6
    t = t_axis(d)
    x = biquad(r.uniform(-1, 1, len(t)), 260 + 80 * seed, q=0.7)
    e = np.zeros_like(t)
    for k in range(4):
        t0 = r.uniform(0.0, 1.2)
        e += np.exp(-np.clip(t - t0, 0, None) / r.uniform(0.4, 1.1)) * (t > t0) * r.uniform(0.4, 1.0)
    return x * e * np.minimum(1, t / 0.08)


def rain_loop():
    d = 4.0
    x = biquad(biquad(noise(d + 0.1), 6000), 400, mode="hp")
    x += crackle(d + 0.1, 900, 0.25)
    return make_loop(x, fade=0.1)


def reload_done():
    d = 0.7
    t = t_axis(d)
    clunk = biquad(noise(d), 600) * np.exp(-t / 0.04) * 1.5 + osc(exp_sweep(140, 60, d)) * np.exp(-t / 0.06)
    hum = osc(np.full(len(t), 220.0)) * 0.25 + osc(np.full(len(t), 440.0)) * 0.12
    return clunk + hum * np.exp(-t / 0.35) * np.minimum(1, t / 0.05)


def telegraph():
    d = 0.5
    t = t_axis(d)
    bell = sum(np.sin(2 * np.pi * f * t) * a for f, a in ((1180, 1.0), (2360, 0.4), (3540, 0.2)))
    return bell * np.exp(-t / 0.12) + noise(d) * np.exp(-t / 0.004) * 0.4


def projectile_whoosh():
    d = 1.4
    t = t_axis(d)
    x = biquad(noise(d), exp_sweep(4500, 300, d), q=2.5, mode="bp") * 2.0
    return x * np.exp(-t / 0.45) * np.minimum(1, t / 0.01)


def ui_click():
    d = 0.06
    t = t_axis(d)
    return np.sin(2 * np.pi * 2100 * t) * np.exp(-t / 0.012) + noise(d) * np.exp(-t / 0.003) * 0.3


write("charge", pad(charge(), 1.2), 0.8)
write("overcharge_loop", overcharge_loop(), 0.6)
write("fire", fire(), 0.95)
write("misfire", misfire(), 0.85)
write("recharge", recharge(), 0.45)
write("impact", impact(), 0.9)
write("explosion", explosion(), 0.9)
write("flak", flak(), 0.6)
write("enemy_gun", enemy_gun(), 0.6)
write("shell_whistle", shell_whistle(), 0.5)
write("torpedo", torpedo(), 0.7)
write("splash", splash(), 0.7)
for i in range(3):
    write("thunder_%d" % i, thunder(i), 0.8)
write("rain_loop", rain_loop(), 0.35)
write("ui_click", ui_click(), 0.5)
write("reload_done", reload_done(), 0.6)
write("telegraph", telegraph(), 0.45)
write("projectile_whoosh", projectile_whoosh(), 0.6)
