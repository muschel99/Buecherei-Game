#!/usr/bin/env python3
"""Kleine Rückmelde-Geräusche (seit der großen Überarbeitung, „mehr satisfying“) – selbst erzeugt, nichts heruntergeladen:
  assets/audio/furniture/place_1..4.wav – Möbel abstellen: weiches Holz-„Tock“ (gedämpfte Holz-Eigentöne + dumpfer Stoß)
  assets/audio/furniture/pick_1..3.wav  – Möbel aufheben: kleines, weiches „Plopp“ nach oben
  assets/audio/furniture/paint_1..3.wav – Wand streichen / Boden legen: Pinsel- bzw. Rollenstrich (gefiltertes Rauschen)
  assets/audio/ui/coins_1..3.wav        – Geld bekommen: zwei, drei kleine Münzen klimpern
Eigene Aufnahme? Einfach die Datei ersetzen (auch .ogg mit gleichem Namen; Varianten _1, _2 …). Das Script schreibt nur,
wenn die Datei fehlt (--force: neu). Braucht Python 3 mit numpy.

Aufruf (Terminal, im Projektordner):
    python3 tools/make_feedback_sounds.py
"""
import os
import sys
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RATE = 44100
RNG = np.random.default_rng(2611)


def write(folder, name, samples, peak=0.6):
    path = os.path.join(ROOT, "assets", "audio", folder, name)
    if os.path.exists(path) and "--force" not in sys.argv:
        print("vorhanden, bleibt:", path)
        return
    # sanft ein- und ausblenden (kein Knacken)
    fade = min(len(samples) // 4, int(RATE * 0.004))
    samples[:fade] *= np.linspace(0.0, 1.0, fade)
    samples[-fade * 4:] *= np.linspace(1.0, 0.0, fade * 4)
    top = np.max(np.abs(samples)) or 1.0
    data = (samples / top * peak * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print("geschrieben:", path)


def t_axis(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def lowpass(x, cutoff):
    """Einfacher Tiefpass (ein Pol), mehrfach für weichere Kanten."""
    a = np.exp(-2.0 * np.pi * cutoff / RATE)
    y = np.zeros_like(x)
    prev = 0.0
    for i, v in enumerate(x):
        prev = (1 - a) * v + a * prev
        y[i] = prev
    return y


def bandpass(x, low, high):
    return lowpass(x, high) - lowpass(lowpass(x, high), low)


def wood_knock(base):
    """Holz auf Holzboden: ein paar gedämpfte Eigentöne (unharmonisch), ein dumpfer Stoß und ein kurzes Klicken."""
    t = t_axis(0.42)
    out = np.zeros_like(t)
    for ratio, amp, decay in ((1.0, 1.0, 0.07), (2.32, 0.55, 0.045), (4.1, 0.28, 0.03), (6.3, 0.12, 0.02)):
        f = base * ratio * RNG.uniform(0.97, 1.03)
        out += amp * np.exp(-t / decay) * np.sin(2 * np.pi * f * t + RNG.uniform(0, 6.28))
    thump = np.exp(-t / 0.05) * np.sin(2 * np.pi * (base * 0.42) * t * (1 - 0.3 * t))
    click = lowpass(RNG.uniform(-1, 1, len(t)) * np.exp(-t / 0.0025), 3500)
    return out * 0.7 + thump * 0.9 + click * 0.9


def lift_pop():
    """Weiches Plopp: kurzer Ton, der nach oben gleitet, mit etwas Luft."""
    t = t_axis(0.16)
    f = 260 + 520 * (t / t[-1]) ** 0.7
    phase = 2 * np.pi * np.cumsum(f) / RATE
    tone = np.sin(phase) * np.exp(-t / 0.045) * (1 - np.exp(-t / 0.004))
    air = bandpass(RNG.uniform(-1, 1, len(t)), 500, 2600) * np.exp(-t / 0.03) * 0.35
    return tone + air


def brush(length):
    """Pinsel/Rolle: gefiltertes Rauschen, das an- und abschwillt, leicht schwankend."""
    t = t_axis(length)
    noise = RNG.uniform(-1, 1, len(t))
    body = bandpass(noise, 300, 2200)
    hiss = bandpass(noise, 2500, 7000) * 0.35
    env = np.minimum(1.0, t / 0.05) * np.clip((length - t) / 0.18, 0.0, 1.0)
    wobble = 0.75 + 0.25 * np.sin(2 * np.pi * RNG.uniform(5.0, 8.0) * t)
    return (body + hiss) * env * wobble


def coin(start, pitch):
    """Kleine Münze: helle, unharmonische Metall-Teiltöne, schnelles Ausklingen."""
    t = t_axis(0.5)
    out = np.zeros_like(t)
    for ratio, amp, decay in ((1.0, 1.0, 0.16), (1.47, 0.6, 0.12), (2.09, 0.42, 0.09), (2.76, 0.25, 0.07)):
        out += amp * np.exp(-t / decay) * np.sin(2 * np.pi * pitch * ratio * t)
    out += lowpass(RNG.uniform(-1, 1, len(t)) * np.exp(-t / 0.002), 8000) * 0.4
    shifted = np.zeros(int(RATE * 0.7))
    i = int(RATE * start)
    shifted[i:i + len(out)] += out[:len(shifted) - i]
    return shifted


def main():
    for k, base in enumerate((185.0, 205.0, 170.0, 225.0)):
        write("furniture", "place_%d.wav" % (k + 1), wood_knock(base), peak=0.7)
    for k in range(3):
        write("furniture", "pick_%d.wav" % (k + 1), lift_pop(), peak=0.5)
    for k, length in enumerate((0.42, 0.5, 0.36)):
        write("furniture", "paint_%d.wav" % (k + 1), brush(length), peak=0.45)
    for k in range(3):
        mix = coin(0.0, RNG.uniform(2600, 3000)) + coin(RNG.uniform(0.05, 0.09), RNG.uniform(3100, 3500)) * 0.8
        if k != 1:
            mix += coin(RNG.uniform(0.12, 0.17), RNG.uniform(2800, 3300)) * 0.6
        write("ui", "coins_%d.wav" % (k + 1), mix, peak=0.42)


if __name__ == "__main__":
    main()
