#!/usr/bin/env python3
"""Rumpeln der Reifen auf dem Kopfsteinpflaster (seit Etappe 6f): erzeugt assets/audio/vehicles/road_rumble.ogg –
tiefes, weiches Grummeln mit kleinen, unregelmäßigen Stößen der Steine, als nahtlose Schleife (4 s, mono).
Das Spiel spielt es unter dem Motor jedes Autos, lauter je schneller es fährt (VehicleModel, road_rumble_volume_db).
Eigene Aufnahme? Einfach die .ogg ersetzen – das Script schreibt nur, wenn die Datei fehlt (--force: neu).

Aufruf (Terminal, im Projektordner; braucht numpy und ffmpeg):
    python3 tools/make_road_rumble.py
    FFMPEG=/pfad/zu/ffmpeg python3 tools/make_road_rumble.py --force
"""
import math
import os
import shutil
import subprocess
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "vehicles", "road_rumble.ogg")
FFMPEG = os.environ.get("FFMPEG") or shutil.which("ffmpeg") or "ffmpeg"
RATE = 44100
SECONDS = 4.0
# Lautstärke (RMS in dBFS) wie die übrigen Fahrzeug-Geräusche
LEVEL = -26.0


def lowpass(x, cutoff):
    """Einfacher Tiefpass (zwei Pole hintereinander), arbeitet über das Schleifenende hinweg."""
    a = math.exp(-2.0 * math.pi * cutoff / RATE)
    y = np.zeros_like(x)
    for _ in range(2):
        prev = 0.0
        # zweimal durchlaufen, damit der Anfang schon „eingeschwungen“ ist (nahtlose Schleife)
        for _pass in range(2):
            for i in range(len(x)):
                prev = (1.0 - a) * x[i] + a * prev
                y[i] = prev
        x = y.copy()
    return y


def main():
    if os.path.exists(OUT) and "--force" not in sys.argv:
        print("Gibt es schon:", OUT)
        return
    rng = np.random.default_rng(7)
    n = int(RATE * SECONDS)
    # Grummeln: tiefes Rauschen
    rumble = lowpass(rng.standard_normal(n), 140.0)
    rumble /= np.max(np.abs(rumble)) + 1e-9
    # Stöße der Pflastersteine: kurze, tiefe Klopfer in unregelmäßigem Abstand (über das Ende hinweg verteilt)
    bumps = np.zeros(n)
    t = 0.0
    while t < SECONDS:
        t += rng.uniform(0.055, 0.12)
        start = int(t * RATE) % n
        freq = rng.uniform(55.0, 95.0)
        amp = rng.uniform(0.35, 1.0)
        length = int(0.05 * RATE)
        k = np.arange(length)
        burst = amp * np.sin(2.0 * math.pi * freq * k / RATE) * np.exp(-k / (0.012 * RATE))
        idx = (start + k) % n
        bumps[idx] += burst
    bumps = lowpass(bumps, 260.0)
    bumps /= np.max(np.abs(bumps)) + 1e-9
    mix = 0.55 * rumble + 0.65 * bumps
    rms = math.sqrt(float(np.mean(mix ** 2)))
    mix *= 10 ** (LEVEL / 20.0) / max(rms, 1e-9)
    mix = np.clip(mix, -0.98, 0.98).astype(np.float32)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    cmd = [FFMPEG, "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "1", "-i", "-", "-c:a", "libvorbis",
           "-q:a", "4", OUT]
    subprocess.run(cmd, input=mix.tobytes(), check=True)
    print("Geschrieben:", OUT)


if __name__ == "__main__":
    main()
