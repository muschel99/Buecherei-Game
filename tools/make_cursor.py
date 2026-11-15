"""Mauszeiger im Cozy-Stil (Wunsch der Entwicklerin nach Etappe 8b: „ein süßerer Cursor – runder Pfeil, ohne Herz“).

Zeichnet zwei kleine Bilder ohne fremde Bibliotheken (eigene Kantenglättung, PNG von Hand geschrieben):
    assets/ui/cursors/cursor_arrow.png   runder Pfeil in Creme mit warmbraunem Rand und weichem Schatten
    assets/ui/cursors/cursor_hover.png   derselbe Pfeil zartrosa (über Knöpfen und allem, was man anklicken kann)
Die Spitze liegt bei HOTSPOT (CozyCursor in scripts/ui/cozy_cursor.gd stellt sie im Spiel ein).

Aufruf (Terminal, im Projektordner):  python3 tools/make_cursor.py [--force]
Schreibt nur fehlende Bilder (eigene Bilder werden nie überschrieben); mit --force neu.
"""

import math
import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "ui", "cursors")
SIZE = 40
HOTSPOT = (4, 3)
# Grundform des Pfeils (Pixel, Spitze oben links); sie wird um ROUND weich aufgeblasen -> runde Ecken
SHAPE = [(5.5, 4.5), (5.5, 27.0), (11.0, 22.5), (15.0, 31.0), (19.0, 29.2), (15.2, 21.0), (22.5, 21.0)]
ROUND = 2.2       # Rundung der Ecken (px)
OUTLINE = 2.0     # Breite des Rands (px)
SHADOW = (1.4, 2.0)
INK = (107, 70, 52)
CREAM = (255, 248, 232)
ROSE = (250, 206, 210)
SHADOW_RGBA = (60, 35, 20, 70)
SAMPLES = 4


def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    qx, qy = ax + t * dx, ay + t * dy
    return math.hypot(px - qx, py - qy)


def inside(px, py, poly):
    hit = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit


def sdf(px, py, poly):
    d = min(seg_dist(px, py, *poly[i], *poly[(i + 1) % len(poly)]) for i in range(len(poly)))
    return -d if inside(px, py, poly) else d


def over(dst, src):
    """src über dst legen (beide RGBA 0..1)."""
    sa = src[3]
    da = dst[3] * (1.0 - sa)
    a = sa + da
    if a <= 0.0:
        return (0.0, 0.0, 0.0, 0.0)
    return tuple((src[k] * sa + dst[k] * da) / a for k in range(3)) + (a,)


def render(fill):
    rows = []
    for y in range(SIZE):
        row = bytearray()
        for x in range(SIZE):
            shadow = body = edge = 0.0
            for sy in range(SAMPLES):
                for sx in range(SAMPLES):
                    px = x + (sx + 0.5) / SAMPLES
                    py = y + (sy + 0.5) / SAMPLES
                    d = sdf(px, py, SHAPE) - ROUND
                    if sdf(px - SHADOW[0], py - SHADOW[1], SHAPE) - ROUND - 0.6 <= 0.0:
                        shadow += 1
                    if d <= 0.0:
                        body += 1
                        if d > -OUTLINE:
                            edge += 1
            n = SAMPLES * SAMPLES
            color = (0.0, 0.0, 0.0, 0.0)
            color = over(color, tuple(c / 255.0 for c in SHADOW_RGBA[:3]) + (SHADOW_RGBA[3] / 255.0 * shadow / n,))
            fill_part = (body - edge) / n
            color = over(color, tuple(c / 255.0 for c in fill) + (fill_part,))
            color = over(color, tuple(c / 255.0 for c in INK) + (edge / n,))
            row += bytes(int(round(max(0.0, min(1.0, c)) * 255)) for c in color)
        rows.append(bytes(row))
    return rows


def write_png(path, rows):
    raw = b"".join(b"\x00" + r for r in rows)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def main():
    force = "--force" in sys.argv
    os.makedirs(OUT, exist_ok=True)
    for name, fill in (("cursor_arrow.png", CREAM), ("cursor_hover.png", ROSE)):
        path = os.path.join(OUT, name)
        if os.path.exists(path) and not force:
            print("vorhanden, nicht überschrieben:", path)
            continue
        write_png(path, render(fill))
        print("geschrieben:", path)


if __name__ == "__main__":
    main()
