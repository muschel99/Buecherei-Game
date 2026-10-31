#!/usr/bin/env python3
"""Sprechblasen und Gemurmel für plaudernde Passanten (seit Etappe 6c) – selbst erzeugt, nichts aus dem
Internet. Schreibt nur Dateien, die noch fehlen: Eigene Bilder und Geräusche (gleicher Name) werden nie
überschrieben.

    python3 tools/make_chat_assets.py

- assets/textures/ui/bubbles/<symbol>.png  Sprechblase mit Symbol (128 x 128, Hintergrund durchsichtig):
  heart, book, cup, sun, flower, note, cat, star, cake. Eigene Symbole: einfach weitere PNGs dazulegen.
- assets/audio/sfx/murmur/syl_<nn>.wav     freundliche, unverständliche Silben (wie bei Animal Crossing):
  aus Vokal-Formanten gerechnet, 22050 Hz mono. Eigene Silben: weitere .wav/.ogg dazulegen oder ersetzen.
"""

import math
import os
import random
import struct
import wave
import zlib

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BUBBLE_DIR = os.path.join(ROOT, "assets", "textures", "ui", "bubbles")
MURMUR_DIR = os.path.join(ROOT, "assets", "audio", "sfx", "murmur")
SIZE = 128
SS = 4  # Überabtastung für weiche Kanten


# --- Bilder ---

def write_png(path, rgba):
    h, w, _ = rgba.shape
    raw = b"".join(b"\x00" + rgba[y].tobytes() for y in range(h))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)) + \
        chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


class Canvas:
    """Zeichenfläche in Einheiten 0..1 (x rechts, y unten), überabgetastet."""

    def __init__(self):
        n = SIZE * SS
        ys, xs = np.mgrid[0:n, 0:n]
        self.x = (xs + 0.5) / n
        self.y = (ys + 0.5) / n
        self.rgb = np.zeros((n, n, 3))
        self.a = np.zeros((n, n))

    def paint(self, mask, color, alpha=1.0):
        m = np.clip(mask, 0, 1) * alpha
        c = np.array(color, dtype=float)
        self.rgb = self.rgb * (1 - m[..., None]) + c * m[..., None]
        self.a = self.a * (1 - m) + m

    def circle(self, cx, cy, r):
        return (np.hypot(self.x - cx, self.y - cy) <= r).astype(float)

    def ring(self, cx, cy, r, w):
        d = np.hypot(self.x - cx, self.y - cy)
        return ((d <= r + w / 2) & (d >= r - w / 2)).astype(float)

    def ellipse(self, cx, cy, rx, ry, ang=0.0):
        ca, sa = math.cos(ang), math.sin(ang)
        dx, dy = self.x - cx, self.y - cy
        u = (dx * ca + dy * sa) / rx
        v = (-dx * sa + dy * ca) / ry
        return (u * u + v * v <= 1).astype(float)

    def rrect(self, x0, y0, x1, y1, r):
        cx = np.clip(self.x, x0 + r, x1 - r)
        cy = np.clip(self.y, y0 + r, y1 - r)
        return (np.hypot(self.x - cx, self.y - cy) <= r).astype(float)

    def poly(self, pts):
        inside = np.zeros_like(self.x, dtype=bool)
        n = len(pts)
        for i in range(n):
            x0, y0 = pts[i]
            x1, y1 = pts[(i + 1) % n]
            cond = (y0 > self.y) != (y1 > self.y)
            with np.errstate(divide="ignore", invalid="ignore"):
                xi = (x1 - x0) * (self.y - y0) / (y1 - y0 + 1e-12) + x0
            inside ^= cond & (self.x < xi)
        return inside.astype(float)

    def line(self, pts, w):
        m = np.zeros_like(self.x)
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            dx, dy = x1 - x0, y1 - y0
            t = np.clip(((self.x - x0) * dx + (self.y - y0) * dy) / (dx * dx + dy * dy + 1e-12), 0, 1)
            d = np.hypot(self.x - (x0 + t * dx), self.y - (y0 + t * dy))
            m = np.maximum(m, (d <= w / 2).astype(float))
        return m

    def image(self):
        n = SIZE
        rgb = self.rgb.reshape(n, SS, n, SS, 3).mean(axis=(1, 3))
        a = self.a.reshape(n, SS, n, SS).mean(axis=(1, 3))
        out = np.zeros((n, n, 4), dtype=np.uint8)
        out[..., :3] = np.clip(rgb / np.maximum(a[..., None], 1e-6) * 255, 0, 255)
        out[..., 3] = np.clip(a * 255, 0, 255)
        return out


INK = (0.32, 0.25, 0.22)


def bubble(c):
    """Sprechblase: cremeweiß mit weichem Rand und Zipfel unten links."""
    c.paint(np.maximum(c.rrect(0.06, 0.06, 0.94, 0.8, 0.2), c.poly([(0.24, 0.72), (0.42, 0.74), (0.18, 0.95)])), (0.62, 0.55, 0.5))
    c.paint(np.maximum(c.rrect(0.08, 0.08, 0.92, 0.78, 0.18), c.poly([(0.26, 0.7), (0.4, 0.72), (0.2, 0.91)])), (0.99, 0.97, 0.92))


def heart(c):
    col = (0.88, 0.32, 0.38)
    c.paint(c.circle(0.4, 0.37, 0.12), col)
    c.paint(c.circle(0.6, 0.37, 0.12), col)
    c.paint(c.poly([(0.29, 0.42), (0.71, 0.42), (0.5, 0.66)]), col)
    c.paint(c.ellipse(0.38, 0.33, 0.04, 0.025, -0.6), (1, 1, 1), 0.6)


def book(c):
    c.paint(c.poly([(0.22, 0.3), (0.5, 0.36), (0.5, 0.64), (0.22, 0.58)]), (0.96, 0.92, 0.82))
    c.paint(c.poly([(0.78, 0.3), (0.5, 0.36), (0.5, 0.64), (0.78, 0.58)]), (0.93, 0.88, 0.78))
    c.paint(c.line([(0.22, 0.3), (0.5, 0.36), (0.78, 0.3), (0.78, 0.58), (0.5, 0.64), (0.22, 0.58), (0.22, 0.3)], 0.03), (0.55, 0.32, 0.25))
    c.paint(c.line([(0.5, 0.36), (0.5, 0.64)], 0.025), (0.55, 0.32, 0.25))
    for k in range(3):
        y = 0.4 + k * 0.06
        c.paint(c.line([(0.27, y), (0.45, y + 0.04)], 0.012), INK, 0.5)
        c.paint(c.line([(0.55, y + 0.04), (0.73, y)], 0.012), INK, 0.5)


def cup(c):
    c.paint(c.ring(0.66, 0.5, 0.07, 0.035), (0.32, 0.55, 0.58))
    c.paint(c.rrect(0.32, 0.38, 0.64, 0.66, 0.06), (0.32, 0.55, 0.58))
    c.paint(c.rrect(0.34, 0.39, 0.62, 0.45, 0.03), (0.58, 0.38, 0.24))
    c.paint(c.ellipse(0.48, 0.68, 0.2, 0.03), (0.75, 0.72, 0.68))
    for x in (0.42, 0.53):
        pts = [(x + 0.025 * math.sin(t * 6.3), 0.32 - t * 0.14) for t in np.linspace(0, 1, 12)]
        c.paint(c.line(pts, 0.022), (0.7, 0.68, 0.66), 0.8)


def sun(c):
    col = (0.98, 0.76, 0.22)
    for k in range(8):
        a = k * math.pi / 4
        c.paint(c.poly([(0.5 + math.cos(a - 0.18) * 0.15, 0.44 + math.sin(a - 0.18) * 0.15),
                        (0.5 + math.cos(a) * 0.27, 0.44 + math.sin(a) * 0.27),
                        (0.5 + math.cos(a + 0.18) * 0.15, 0.44 + math.sin(a + 0.18) * 0.15)]), col)
    c.paint(c.circle(0.5, 0.44, 0.14), (0.99, 0.84, 0.3))
    for x in (0.45, 0.55):
        c.paint(c.circle(x, 0.42, 0.014), INK)
    c.paint(c.line([(0.45, 0.48), (0.5, 0.5), (0.55, 0.48)], 0.014), INK)


def flower(c):
    for k in range(5):
        a = k * math.tau / 5 - math.pi / 2
        c.paint(c.circle(0.5 + math.cos(a) * 0.12, 0.43 + math.sin(a) * 0.12, 0.09), (0.94, 0.58, 0.7))
    c.paint(c.circle(0.5, 0.43, 0.07), (0.98, 0.82, 0.3))
    c.paint(c.line([(0.5, 0.55), (0.5, 0.7)], 0.03), (0.38, 0.6, 0.32))


def note(c):
    col = (0.42, 0.34, 0.6)
    c.paint(c.ellipse(0.4, 0.6, 0.075, 0.055, -0.4), col)
    c.paint(c.ellipse(0.62, 0.55, 0.075, 0.055, -0.4), col)
    c.paint(c.line([(0.46, 0.6), (0.46, 0.3)], 0.03), col)
    c.paint(c.line([(0.68, 0.55), (0.68, 0.25)], 0.03), col)
    c.paint(c.poly([(0.45, 0.28), (0.69, 0.22), (0.69, 0.3), (0.45, 0.36)]), col)


def cat(c):
    col = (0.9, 0.62, 0.38)
    c.paint(c.poly([(0.32, 0.36), (0.36, 0.2), (0.45, 0.32)]), col)
    c.paint(c.poly([(0.68, 0.36), (0.64, 0.2), (0.55, 0.32)]), col)
    c.paint(c.ellipse(0.5, 0.46, 0.19, 0.16), col)
    for x in (0.43, 0.57):
        c.paint(c.ellipse(x, 0.44, 0.022, 0.03), INK)
    c.paint(c.poly([(0.48, 0.5), (0.52, 0.5), (0.5, 0.525)]), (0.85, 0.4, 0.45))
    for s in (-1, 1):
        c.paint(c.line([(0.5 + s * 0.08, 0.52), (0.5 + s * 0.2, 0.5)], 0.01), INK, 0.7)


def star(c):
    pts = []
    for k in range(10):
        a = k * math.pi / 5 - math.pi / 2
        r = 0.22 if k % 2 == 0 else 0.1
        pts.append((0.5 + math.cos(a) * r, 0.45 + math.sin(a) * r))
    c.paint(c.poly(pts), (0.98, 0.78, 0.25))


def cake(c):
    c.paint(c.poly([(0.28, 0.62), (0.72, 0.62), (0.72, 0.44), (0.28, 0.5)]), (0.96, 0.86, 0.66))
    c.paint(c.poly([(0.28, 0.5), (0.72, 0.44), (0.72, 0.4), (0.28, 0.46)]), (0.95, 0.6, 0.66))
    c.paint(c.line([(0.28, 0.555), (0.72, 0.52)], 0.025), (0.95, 0.6, 0.66))
    c.paint(c.circle(0.62, 0.36, 0.05), (0.85, 0.2, 0.25))
    c.paint(c.line([(0.62, 0.32), (0.66, 0.24)], 0.012), (0.38, 0.55, 0.3))


ICONS = {"heart": heart, "book": book, "cup": cup, "sun": sun, "flower": flower, "note": note, "cat": cat, "star": star, "cake": cake}


def make_bubbles():
    os.makedirs(BUBBLE_DIR, exist_ok=True)
    made = 0
    for name, draw in ICONS.items():
        path = os.path.join(BUBBLE_DIR, name + ".png")
        if os.path.exists(path):
            continue
        c = Canvas()
        bubble(c)
        draw(c)
        write_png(path, c.image())
        made += 1
    print("Sprechblasen: %d neu (%d vorhanden)" % (made, len(ICONS) - made))


# --- Gemurmel ---

RATE = 22050
# Vokale: Formanten (Hz) – a, e, i, o, u, ä, ö
VOWELS = [(800, 1200, 2500), (420, 2000, 2600), (300, 2250, 3000), (500, 880, 2400), (340, 760, 2300), (620, 1700, 2500), (420, 1500, 2300)]


def syllable(rng, base):
    dur = rng.uniform(0.085, 0.15)
    n = int(RATE * dur)
    t = np.arange(n) / RATE
    f1, f2, f3 = VOWELS[rng.randrange(len(VOWELS))]
    # Tonhöhe mit kleiner Melodie (hoch oder runter gleitend, wie eine fröhliche Frage)
    glide = rng.choice([1.0, 1.0, 1.12, 0.9, 1.18])
    f0 = base * np.linspace(1.0, glide, n) * (1 + 0.012 * np.sin(2 * math.pi * 6 * t))
    phase = 2 * math.pi * np.cumsum(f0) / RATE
    out = np.zeros(n)
    for k in range(1, 22):
        freq = base * k
        if freq > 4800:
            break
        amp = sum(math.exp(-((freq - f) / bw) ** 2) for f, bw in ((f1, 160), (f2, 220), (f3, 320)))
        out += (amp + 0.04) / k ** 0.6 * np.sin(phase * k)
    # weicher Konsonant am Anfang (gefiltertes Rauschen), manchmal
    if rng.random() < 0.6:
        m = int(RATE * rng.uniform(0.008, 0.02))
        noise = np.convolve(np.array([rng.uniform(-1, 1) for _ in range(m)]), np.ones(4) / 4, mode="same")
        out[:m] += noise * 0.35 * np.linspace(1, 0, m)
    env = np.minimum(1.0, t / 0.01) * np.exp(-np.maximum(0.0, t - dur * 0.45) / (dur * 0.25))
    out *= env
    out /= max(1e-6, np.max(np.abs(out)))
    return (out * 0.5 * 32767).astype(np.int16)


def make_murmur(count=28):
    os.makedirs(MURMUR_DIR, exist_ok=True)
    rng = random.Random(1918)
    made = 0
    for i in range(count):
        path = os.path.join(MURMUR_DIR, "syl_%02d.wav" % (i + 1))
        base = rng.uniform(210, 280)
        data = syllable(rng, base)
        if os.path.exists(path):
            continue
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(data.tobytes())
        made += 1
    print("Gemurmel: %d Silben neu (%d vorhanden)" % (made, count - made))


if __name__ == "__main__":
    make_bubbles()
    make_murmur()
