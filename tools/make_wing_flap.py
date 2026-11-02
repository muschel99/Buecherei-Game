#!/usr/bin/env python3
"""Flattern beim Auffliegen der Vögel (seit Etappe 6g): erzeugt assets/audio/ambience/bird_flap_1..3.ogg –
kurzes, weiches Flügelschlagen (ein paar schnelle Schläge, jeder ein gedämpfter Luftstoß, zum Ende leiser),
etwa 0,6–0,9 s, mono. Unter den Aufnahmen der Entwicklerin gibt es kein Flattern; darum per Script.
Das Spiel spielt eine zufällige Variante, wenn ein Schwarm auffliegt (BirdLife, bird_flap_volume_db).
Eigene Aufnahme? Einfach die .ogg-Dateien ersetzen – das Script schreibt nur fehlende Dateien (--force: neu).

Aufruf (Terminal, im Projektordner; braucht numpy und ffmpeg):
    python3 tools/make_wing_flap.py
    FFMPEG=/pfad/zu/ffmpeg python3 tools/make_wing_flap.py --force
"""
import math
import os
import shutil
import subprocess
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "ambience", "bird_flap_%d.ogg")
FFMPEG = os.environ.get("FFMPEG") or shutil.which("ffmpeg") or "ffmpeg"
RATE = 44100
# Lautstärke (RMS in dBFS) wie die übrigen Tiergeräusche
LEVEL = -24.0


def one_pole(x, cutoff, high=False):
    a = math.exp(-2.0 * math.pi * cutoff / RATE)
    y = np.zeros_like(x)
    prev = 0.0
    for i in range(len(x)):
        prev = (1.0 - a) * x[i] + a * prev
        y[i] = prev
    return x - y if high else y


def flap(seed):
    rng = np.random.default_rng(seed)
    beats = rng.integers(6, 10)
    rate = rng.uniform(13.0, 17.0)           # Flügelschläge je Sekunde
    seconds = beats / rate + 0.25
    n = int(RATE * seconds)
    out = np.zeros(n)
    noise = rng.standard_normal(n)
    # Luftstoß: Rauschen, Bandpass (tiefer Teil weich, hoher Teil abgeschnitten)
    air = one_pole(one_pole(noise, 2600.0), 280.0, high=True)
    for b in range(beats):
        t0 = b / rate + rng.uniform(-0.006, 0.006)
        start = max(0, int(t0 * RATE))
        length = int(RATE / rate * 0.85)
        k = np.arange(length)
        # Hüllkurve je Schlag: schneller Anstieg, weiches Abklingen; spätere Schläge leiser
        env = (1.0 - np.exp(-k / (0.004 * RATE))) * np.exp(-k / (0.022 * RATE))
        amp = (1.0 - 0.07 * b) * rng.uniform(0.8, 1.0)
        end = min(n, start + length)
        out[start:end] += air[start:end] * env[:end - start] * amp
    # Ein- und Ausblenden
    fade = int(0.01 * RATE)
    out[:fade] *= np.linspace(0.0, 1.0, fade)
    out[-fade * 6:] *= np.linspace(1.0, 0.0, fade * 6)
    rms = math.sqrt(float(np.mean(out ** 2)))
    out *= 10 ** (LEVEL / 20.0) / max(rms, 1e-9)
    return np.clip(out, -0.98, 0.98).astype(np.float32)


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    for i in (1, 2, 3):
        path = OUT % i
        if os.path.exists(path) and "--force" not in sys.argv:
            print("Gibt es schon:", path)
            continue
        data = flap(40 + i)
        cmd = [FFMPEG, "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "1", "-i", "-", "-c:a", "libvorbis",
               "-q:a", "4", path]
        subprocess.run(cmd, input=data.tobytes(), check=True)
        print("Geschrieben:", path)


if __name__ == "__main__":
    main()
