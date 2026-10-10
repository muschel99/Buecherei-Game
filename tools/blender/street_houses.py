"""Baukasten für individuelle Häuser (seit Etappe 4g, Teil 2b).

Jedes Haus der Straße bekommt ein eigenes Modell aus einer "Beschreibung" (spec, ein dict):
Wandmaterial, Geschosse, Dachform, Traufe, Fensterstürze, Eckquader, Fenster (Breite,
Sprossen, was dahinter ist), Tür, Stufen, Erker, Balkon, Fachwerk, Vorgarten mit Zaun …
Benutzt von tools/blender/build_street.py. Alles in Godot-Koordinaten (siehe style_lib.py),
Ursprung unten in der Mitte der Hausfront (Gehweg), Vorderseite +z.

Farben: Wand = Wandfarbe des Hauses (Rolle "wall"), Fensterrahmen und Tür = Türfarbe
(Rolle "door"), Fensterläden und Blumenkästen = Akzentfarbe (Rolle "accent").
"""

import math
import random

import style_lib as S
import style_parts as P
from style_lib import Mat, V

TRIM = Mat("stone_trim")
CREAM = Mat("paint", color=(0.86, 0.84, 0.78))
JOINERY = Mat("paint", "door")
ACCENT = Mat("paint", "accent")
IRON = Mat("metal")
GOLD = Mat("gold")
LEAD = Mat("metal")
TIMBER = Mat("timber")
GLASS = Mat("glass", glass=True)
POT = Mat("terracotta")
PLINTH = Mat("render", color=(0.42, 0.4, 0.38))
RIDGE = Mat("terracotta", color=(1, 1, 1))
CHIMNEY_BRICK = Mat("brick", color=(0.58, 0.33, 0.25))

ROOF_MATS = {"slate": Mat("slate"), "clay": Mat("clay_tile")}
WALL_LAYERS = {"brick": "brick", "render": "render", "stone": "stone", "roughcast": "roughcast"}

# Vorhangstoffe und Wandfarben der Räume hinter den Fenstern (sRGB)
CURTAINS = [(0.86, 0.82, 0.72), (0.62, 0.66, 0.56), (0.72, 0.52, 0.5), (0.74, 0.6, 0.36), (0.5, 0.3, 0.3),
            (0.42, 0.48, 0.56), (0.8, 0.74, 0.62)]
ROOM_WALLS = [(0.86, 0.8, 0.66), (0.74, 0.78, 0.7), (0.84, 0.74, 0.68), (0.78, 0.8, 0.82), (0.88, 0.84, 0.74)]


def wall_mat(layer):
    return Mat(WALL_LAYERS[layer], "wall")


# ---------------------------------------------------------------------------------------------
# Fenster
# ---------------------------------------------------------------------------------------------

def sash(b, x, y0, w, h, reveal, panes, frame=JOINERY, z=0.0):
    """Fensterrahmen mit Glas. panes: "sash22" (2 über 2), "sash66" (6 über 6), "topbars"
    (nur oben Sprossen), "plain" (1 über 1), "casement" (zwei Flügel, Oberlicht), "french"
    (bodentiefe Flügeltür)."""
    b.push(b.move(0, 0, z))
    x0, x1 = x - w / 2, x + w / 2
    y1 = y0 + h
    zg = -reveal + 0.03
    b.quad(V(x0, y0, zg), V(x1, y0, zg), V(x1, y1, zg), V(x0, y1, zg), GLASS)
    f = 0.055
    zf0, zf1 = zg - 0.012, zg + 0.055
    b.box((x0, y0, zf0), (x0 + f, y1, zf1), frame)
    b.box((x1 - f, y0, zf0), (x1, y1, zf1), frame)
    b.box((x0 + f, y1 - f, zf0), (x1 - f, y1, zf1), frame, skip=("left", "right"))
    b.box((x0 + f, y0, zf0), (x1 - f, y0 + f, zf1), frame, skip=("left", "right"))
    bar = 0.022
    if panes in ("sash22", "sash66", "topbars", "plain"):
        mid = y0 + h * 0.5
        b.box((x0 + f, mid - 0.03, zf0), (x1 - f, mid + 0.03, zf1 + 0.015), frame, skip=("left", "right"))
        cols, rows = {"sash22": (2, 1), "sash66": (3, 2), "topbars": (3, 2), "plain": (1, 1)}[panes]
        b.glazing_bars(x0 + f, mid + 0.03, x1 - f, y1 - f, zf0, zf1 - 0.015, cols, rows, bar, frame)
        if panes in ("sash22", "sash66"):
            b.glazing_bars(x0 + f, y0 + f, x1 - f, mid - 0.03, zf0, zf1 - 0.015, cols, rows, bar, frame)
    elif panes in ("casement", "french"):
        top = y1 - (0.32 if h > 1.0 else 0.2)
        b.box((x0 + f, top - 0.025, zf0), (x1 - f, top + 0.025, zf1), frame, skip=("left", "right"))
        b.box((x - 0.03, y0 + f, zf0), (x + 0.03, top - 0.025, zf1), frame, skip=("top", "bottom"))
        rows = 3 if panes == "casement" else 4
        for side in (-1, 1):
            a0, a1 = sorted((x + side * 0.03, x + side * (w / 2 - f)))
            b.glazing_bars(a0, y0 + f, a1, top - 0.025, zf0, zf1 - 0.015, 2 if w > 0.8 else 1, rows, bar, frame)
        b.glazing_bars(x0 + f, top + 0.025, x1 - f, y1 - f, zf0, zf1 - 0.015, 3, 1, bar, frame)
    b.pop()
    return zg


def backdrop(b, kind, x0, x1, y0, y1, zg, room, rnd, floor=0):
    """Was hinter dem Glas ist. room = (rx0, rx1, floor_y, ceil_y, depth) – Platz für einen Raum.
    kind: closed (Vorhang zu), nets (Gardine unten, Raum dahinter), blind (Rollo halb unten),
    dim (nur Seitenvorhänge, dämmriger Raum), living (Wohnzimmer), kitchen (Küche)."""
    z = zg - 0.012
    fabric = Mat("fabric", color=rnd.choice(CURTAINS))
    w = x1 - x0
    if kind == "closed":
        _drape(b, x0, x1, y0, y1, z, fabric, folds=max(3, int(w / 0.12)))
        return
    rx0, rx1, fy, cy, depth = room
    if kind in ("living", "kitchen"):
        (_living_room if kind == "living" else _kitchen)(b, rx0, rx1, fy, cy, z - 0.01, depth, rnd)
    else:
        _shallow_room(b, rx0, rx1, max(fy, y0 - 0.3), min(cy, y1 + 0.3), z - 0.01, 0.7, rnd, glow=0.05 if kind == "dim" else 0.12,
                      floor=floor)
    # Seitenvorhänge
    cw = w * rnd.uniform(0.16, 0.24)
    for a0, a1 in ((x0, x0 + cw), (x1 - cw, x1)):
        _drape(b, a0, a1, y0, y1, z, fabric, folds=3)
    if kind == "nets":
        net = Mat("fabric", color=(0.92, 0.9, 0.84), glow=0.05)
        _drape(b, x0 + cw - 0.02, x1 - cw + 0.02, y0, y0 + (y1 - y0) * 0.5, z + 0.003, net, folds=int(w / 0.06))
        b.tube([V(x0, y0 + (y1 - y0) * 0.5 + 0.02, z + 0.006), V(x1, y0 + (y1 - y0) * 0.5 + 0.02, z + 0.006)], 0.006, GOLD, segments=4)
    elif kind == "blind":
        drop = (y1 - y0) * rnd.uniform(0.3, 0.5)
        b.poly([V(x0 + 0.02, y1 - drop, z + 0.004), V(x1 - 0.02, y1 - drop, z + 0.004), V(x1 - 0.02, y1, z + 0.004), V(x0 + 0.02, y1, z + 0.004)],
               Mat("fabric", color=(0.9, 0.86, 0.76), glow=0.04))
        b.box((x0 + 0.02, y1 - drop - 0.02, z + 0.002), (x1 - 0.02, y1 - drop, z + 0.012), TIMBER)


def _drape(b, x0, x1, y0, y1, z, mat, folds=4):
    """Vorhang mit Falten (Zickzack), Vorderseite zur Straße."""
    n = max(2, folds * 2)
    for k in range(n):
        a = x0 + (x1 - x0) * k / n
        c = x0 + (x1 - x0) * (k + 1) / n
        za = z - (0.02 if k % 2 else 0.0)
        zc = z - (0.0 if k % 2 else 0.02)
        b.poly([V(a, y0, za), V(c, y0, zc), V(c, y1, zc), V(a, y1, za)], mat)


def _room_shell(b, rx0, rx1, fy, cy, z, depth, wall_color, glow):
    b.room((rx0, fy, z - depth), (rx1, cy, z),
           {"floor": Mat("boards", color=(0.58, 0.42, 0.3), glow=glow * 0.8),
            "ceiling": Mat("plain", color=(0.9, 0.88, 0.82), glow=glow),
            "back": Mat("render", color=wall_color, glow=glow), "left": Mat("render", color=wall_color, glow=glow),
            "right": Mat("render", color=wall_color, glow=glow)})


def _shallow_room(b, rx0, rx1, fy, cy, z, depth, rnd, glow=0.12, floor=0):
    """Kleiner Raum hinter Gardine/Rollo. Was man an der Wand sieht, wechselt: Bild, Regal,
    Uhr, Spiegel, Pflanze, Lampe – oder nichts. Oben (von der Straße aus) oft nur die Decke
    mit einer Lampe."""
    color = rnd.choice(ROOM_WALLS)
    _room_shell(b, rx0, rx1, fy, cy, z, depth, color, glow)
    cx = (rx0 + rx1) / 2 + rnd.uniform(-0.25, 0.25)
    zb = z - depth + 0.01
    choices = ["picture", "shelf", "clock", "mirror", "plant", "lamp", "nothing"]
    weights = [2, 3, 1, 1, 2, 2, 2] if floor == 0 else [1, 1, 1, 0, 1, 1, 2]
    if floor > 0:
        choices.append("ceiling")
        weights.append(5)
    content = rnd.choices(choices, weights=weights)[0]
    my = fy + (cy - fy) * 0.6
    if content == "picture":
        pw, ph = rnd.uniform(0.25, 0.45), rnd.uniform(0.2, 0.35)
        b.box((cx - pw, my - ph, zb), (cx + pw, my + ph, zb + 0.025), Mat("timber", glow=glow))
        b.box((cx - pw + 0.04, my - ph + 0.04, zb + 0.025), (cx + pw - 0.04, my + ph - 0.04, zb + 0.03), Mat("plain", color=rnd.choice(CURTAINS), glow=glow))
    elif content == "shelf":
        for y in (my - 0.3, my + 0.1):
            b.box((cx - 0.45, y, zb), (cx + 0.45, y + 0.025, zb + 0.22), Mat("timber", glow=glow))
            x = cx - 0.4
            while x < cx + 0.35:
                t = rnd.uniform(0.03, 0.06)
                hgt = rnd.uniform(0.18, 0.26)
                if rnd.random() < 0.2:
                    b.cylinder(V(x + 0.05, y + 0.025, zb + 0.1), 0.05, 0.16, Mat("plain", color=rnd.choice(CURTAINS), glow=glow), segments=8)
                    x += 0.12
                else:
                    b.box((x, y + 0.025, zb + 0.03), (x + t, y + 0.025 + hgt, zb + 0.19), Mat("plain", color=rnd.choice(CURTAINS), glow=glow))
                    x += t + 0.005
    elif content == "clock":
        b.cylinder(V(cx, my, zb), 0.16, 0.03, Mat("timber", glow=glow), segments=16, axis="z", caps=(True, True))
        b.cylinder(V(cx, my, zb + 0.03), 0.13, 0.008, Mat("plain", color=(0.94, 0.92, 0.86), glow=glow), segments=16, axis="z", caps=(True, True))
    elif content == "mirror":
        b.box((cx - 0.25, my - 0.4, zb), (cx + 0.25, my + 0.4, zb + 0.03), GOLD)
        b.box((cx - 0.21, my - 0.36, zb + 0.03), (cx + 0.21, my + 0.36, zb + 0.035), Mat("plain", color=(0.7, 0.74, 0.76), glow=glow + 0.05))
    elif content == "plant":
        b.cylinder(V(cx, fy, z - 0.35), 0.14, 0.32, Mat("terracotta", glow=glow * 0.5), segments=10)
        b.sphere(V(cx, fy + 0.6, z - 0.35), 0.3, Mat("foliage", color=(0.3, 0.44, 0.22), glow=glow * 0.5), rings=5, segments=10, jitter=0.15, seed=rnd.randrange(999))
    elif content == "lamp":
        lx = rx0 + 0.25 if rnd.random() < 0.5 else rx1 - 0.25
        b.cylinder(V(lx, fy + 1.0, zb + 0.3), 0.16, 0.22, Mat("plain", color=(1.0, 0.86, 0.62), glow=0.9), segments=10, radius_top=0.1, caps=(True, True))
    elif content == "ceiling":
        # Hängelampe und Stuckrosette – mehr sieht man von unten nicht
        lz = z - depth * 0.5
        b.cylinder(V(cx, cy - 0.005, lz), 0.18, 0.005, Mat("plain", color=(0.94, 0.92, 0.86), glow=glow), segments=14)
        b.tube([V(cx, cy, lz), V(cx, cy - 0.4, lz)], 0.006, LEAD, segments=4)
        b.cylinder(V(cx, cy - 0.55, lz), 0.17, 0.16, Mat("plain", color=rnd.choice(CURTAINS)), segments=12, radius_top=0.08, caps=(True, True))
        b.sphere(V(cx, cy - 0.56, lz), 0.05, Mat("plain", color=(1.0, 0.88, 0.66), glow=1.0), rings=3, segments=6)


def _inner_door(b, x, fy, z0, z1, facing, ceiling_y):
    """Innentür an einer Seitenwand eines Raums (facing = +1: Wand links, Tür zeigt nach +x)."""
    h = min(2.05, ceiling_y - fy - 0.15)
    door = Mat("paint", color=(0.86, 0.84, 0.78), glow=0.1)
    x_in = x + facing * 0.02
    lo, hi = sorted((x, x_in))
    b.box((lo, fy, z0 - 0.08), (hi, fy + h + 0.08, z1 + 0.08), Mat("paint", color=(0.8, 0.78, 0.72), glow=0.1))
    lo2, hi2 = sorted((x_in, x_in + facing * 0.015))
    b.box((lo2, fy, z0), (hi2, fy + h, z1), door)
    for py0, py1 in ((0.25, 0.9), (1.05, h - 0.15)):
        b.box((lo2 + (0.0 if facing > 0 else -0.008), fy + py0, z0 + 0.1), (hi2 + (0.008 if facing > 0 else 0.0), fy + py1, z1 - 0.1), door)
    b.sphere(V(x_in + facing * 0.05, fy + 1.0, z1 - 0.12), 0.025, GOLD, rings=3, segments=6)


def _living_room(b, rx0, rx1, fy, cy, z, depth, rnd):
    """Wohnzimmer: Dielen, Teppich, Sofa an der Rückwand, Stehlampe, Bild, Bücherregal, Pflanze."""
    _room_shell(b, rx0, rx1, fy, cy, z, depth, rnd.choice(ROOM_WALLS), 0.14)
    zb = z - depth
    cx = (rx0 + rx1) / 2
    sofa = Mat("fabric", color=rnd.choice([(0.42, 0.5, 0.46), (0.6, 0.4, 0.36), (0.36, 0.4, 0.5), (0.7, 0.6, 0.42)]), glow=0.06)
    b.box((cx - 0.9, fy, zb + 0.05), (cx + 0.9, fy + 0.45, zb + 0.85), sofa)
    b.box((cx - 0.9, fy + 0.45, zb + 0.05), (cx + 0.9, fy + 0.9, zb + 0.28), sofa)
    for s in (-1, 1):
        b.box((cx + s * 0.9 - 0.12, fy, zb + 0.05), (cx + s * 0.9 + 0.12, fy + 0.62, zb + 0.85), sofa)
    for k in range(2):
        b.box((cx - 0.5 + k * 0.7, fy + 0.45, zb + 0.28), (cx - 0.15 + k * 0.7, fy + 0.8, zb + 0.4), Mat("fabric", color=rnd.choice(CURTAINS), glow=0.06))
    b.box((cx - 1.1, fy, zb + 1.1), (cx + 1.1, fy + 0.008, zb + 2.3), Mat("fabric", color=(0.66, 0.46, 0.4), glow=0.08))
    b.box((cx - 0.45, fy, zb + 1.35), (cx + 0.45, fy + 0.42, zb + 1.85), Mat("timber", glow=0.08))
    b.box((cx - 0.35, cy - 1.15, zb + 0.005), (cx + 0.35, cy - 0.65, zb + 0.03), GOLD)
    b.box((cx - 0.31, cy - 1.11, zb + 0.03), (cx + 0.31, cy - 0.69, zb + 0.035), Mat("plain", color=(0.55, 0.62, 0.6), glow=0.12))
    lx = rx1 - 0.35
    b.cylinder(V(lx, fy, zb + 0.4), 0.14, 0.03, Mat("gold", glow=0.05), segments=10)
    b.cylinder(V(lx, fy, zb + 0.4), 0.012, 1.45, Mat("gold", glow=0.05), segments=6)
    b.cylinder(V(lx, fy + 1.35, zb + 0.4), 0.22, 0.28, Mat("plain", color=(1.0, 0.88, 0.66), glow=1.0), segments=12, radius_top=0.15, caps=(True, True))
    sx = rx0 + 0.02
    b.box((sx, fy, zb + 0.6), (sx + 0.32, fy + 1.9, zb + 1.6), Mat("timber", glow=0.06))
    for k, y in enumerate((fy + 0.4, fy + 0.85, fy + 1.3)):
        zz = zb + 0.65
        while zz < zb + 1.5:
            t = rnd.uniform(0.03, 0.06)
            hgt = rnd.uniform(0.22, 0.32)
            b.box((sx + 0.32, y, zz), (sx + 0.35, y + hgt, zz + t), Mat("plain", color=rnd.choice(CURTAINS), glow=0.08))
            zz += t + 0.004
    _inner_door(b, rx1, fy, zb + 1.3, zb + 2.15, -1, cy)
    b.cylinder(V(rx0 + 0.6, fy, z - 0.45), 0.15, 0.3, Mat("terracotta", glow=0.05), segments=10)
    b.sphere(V(rx0 + 0.6, fy + 0.55, z - 0.45), 0.25, Mat("foliage", color=(0.3, 0.44, 0.22), glow=0.06), rings=5, segments=10, jitter=0.15, seed=rnd.randrange(999))


def _kitchen(b, rx0, rx1, fy, cy, z, depth, rnd):
    """Küche: Unterschränke mit Arbeitsplatte, offene Regale mit Tellern, Hängelampe, Kräuter."""
    _room_shell(b, rx0, rx1, fy, cy, z, depth, (0.9, 0.88, 0.8), 0.16)
    zb = z - depth
    cab = Mat("paint", color=rnd.choice([(0.56, 0.62, 0.54), (0.42, 0.5, 0.58), (0.82, 0.78, 0.68), (0.6, 0.44, 0.36)]), glow=0.08)
    b.box((rx0, fy, zb), (rx1, fy + 0.88, zb + 0.6), cab)
    width = rx1 - rx0
    for k in range(int(width / 0.6)):
        a = rx0 + 0.04 + k * 0.6
        b.frame(a + 0.05, fy + 0.12, a + 0.5, fy + 0.78, zb + 0.6, zb + 0.612, 0.02, cab)
        b.sphere(V(a + 0.45, fy + 0.7, zb + 0.62), 0.015, GOLD, rings=3, segments=6)
    b.box((rx0, fy + 0.88, zb), (rx1, fy + 0.92, zb + 0.63), Mat("timber", glow=0.1))
    b.box((rx0, fy + 0.92, zb), (rx1, fy + 1.5, zb + 0.01), Mat("plain", color=(0.86, 0.88, 0.86), glow=0.12))
    for y in (fy + 1.6, fy + 1.95):
        b.box((rx0 + 0.1, y, zb), (rx1 - 0.1, y + 0.03, zb + 0.25), Mat("timber", glow=0.1))
        x = rx0 + 0.2
        while x < rx1 - 0.25:
            if rnd.random() < 0.6:
                b.box((x - 0.1, y + 0.03, zb + 0.04), (x + 0.1, y + 0.22, zb + 0.06), Mat("plain", color=(0.9, 0.9, 0.86), glow=0.1))
            else:
                b.cylinder(V(x, y + 0.03, zb + 0.12), 0.05, 0.14, Mat("plain", color=rnd.choice(CURTAINS), glow=0.08), segments=8)
            x += 0.26
    b.cylinder(V((rx0 + rx1) / 2 - 0.4, fy + 0.92, zb + 0.3), 0.08, 0.16, Mat("plain", color=(0.7, 0.3, 0.26), glow=0.08), segments=10, radius_top=0.06)
    lx = (rx0 + rx1) / 2
    b.tube([V(lx, cy, z - depth * 0.55), V(lx, cy - 0.6, z - depth * 0.55)], 0.006, LEAD, segments=4)
    b.cylinder(V(lx, cy - 0.85, z - depth * 0.55), 0.22, 0.25, Mat("paint", color=(0.24, 0.3, 0.26), glow=0.05), segments=12, radius_top=0.05, caps=(True, True))
    b.sphere(V(lx, cy - 0.85, z - depth * 0.55), 0.07, Mat("plain", color=(1.0, 0.88, 0.66), glow=1.0), rings=4, segments=8)
    b.box((lx - 0.5, fy, z - depth * 0.6), (lx + 0.5, fy + 0.75, z - depth * 0.6 + 0.7), Mat("timber", glow=0.08), skip=("bottom",))
    _inner_door(b, rx0, fy, zb + 0.75, zb + 1.6, 1, cy)


def window_unit(b, spec, x, y0, w, h, panes, backdrop_kind, room, rnd, reveal=0.13, lintel=None, sill=True, shutters=0.0,
                floor=0):
    """Ein komplettes Fenster: Rahmen, Glas, Dahinter, Sohlbank, Sturz, Läden.
    shutters = Platz (m) neben dem Fenster je Seite für Läden (0 = keine)."""
    zg = sash(b, x, y0, w, h, reveal, panes)
    backdrop(b, backdrop_kind, x - w / 2 + 0.05, x + w / 2 - 0.05, y0 + 0.05, y0 + h - 0.05, zg, room, rnd, floor)
    lintel = lintel or spec["lintel"]
    x0, x1 = x - w / 2, x + w / 2
    top = y0 + h
    if sill and panes != "french":
        if spec["sill"] == "stone":
            b.box((x0 - 0.08, y0 - 0.08, 0), (x1 + 0.08, y0, 0.09), TRIM)
        else:
            b.box((x0 - 0.04, y0 - 0.06, 0), (x1 + 0.04, y0, 0.07), JOINERY)
    _lintel(b, lintel, x, x0, x1, top, w, spec)
    # Läden nur, wo daneben genug Platz ist (nicht in Eckquadern, Nachbarfenstern, Türen)
    start = 0.13 if lintel == "architrave" else 0.02
    sw = min(w / 2 * 0.95, shutters - start)
    if sw >= 0.28:
        for side in (-1, 1):
            sx0, sx1 = sorted((x + side * (w / 2 + start), x + side * (w / 2 + start + sw)))
            b.box((sx0, y0, 0.0), (sx1, top, 0.035), ACCENT)
            n = int(h / 0.08)
            for k in range(1, n):
                yy = y0 + h * k / n
                b.box((sx0 + 0.04, yy - 0.012, 0.035), (sx1 - 0.04, yy, 0.045), ACCENT, skip=("back",))


def _lintel(b, style, x, x0, x1, top, w, spec):
    wall = wall_mat(spec["wall"])
    if style == "flat":
        b.box((x0 - 0.1, top, 0), (x1 + 0.1, top + 0.2, 0.03), TRIM, skip=("back",))
    elif style == "key":
        b.box((x0 - 0.12, top, 0), (x1 + 0.12, top + 0.2, 0.03), TRIM, skip=("back",))
        b.box((x - 0.07, top - 0.03, 0), (x + 0.07, top + 0.24, 0.06), TRIM, skip=("back",))
    elif style in ("brick_arch", "segment"):
        mat = wall if style == "brick_arch" else TRIM
        n = max(5, int((w + 0.2) / (0.075 if style == "brick_arch" else 0.16)))
        for k in range(n):
            t = (k + 0.5) / n
            bx = x0 - 0.1 + (w + 0.2) * t
            lift = 0.07 * math.sin(math.pi * t)
            half = (w + 0.2) / n / 2 - 0.006
            b.box((bx - half, top + lift, 0), (bx + half, top + lift + 0.22, 0.025), mat, skip=("back",))
    elif style == "architrave":
        b.frame(x0, top - 0.01, x1, top, 0.0, 0.04, 0.1, TRIM, bottom=False)
        b.box((x0 - 0.1, top + 0.1, 0), (x1 + 0.1, top + 0.24, 0.05), TRIM, skip=("back",))
        b.extrude_x([(0, top + 0.24), (0, top + 0.34), (0.12, top + 0.34), (0.12, top + 0.3), (0.06, top + 0.24)],
                    x0 - 0.18, x1 + 0.18, TRIM)
    elif style == "hood":
        b.extrude_x([(0, top + 0.08), (0, top + 0.2), (0.15, top + 0.2), (0.15, top + 0.15), (0.08, top + 0.08)],
                    x0 - 0.16, x1 + 0.16, TRIM)
        for s in (-1, 1):
            cx = x + s * (w / 2 + 0.1)
            b.box((cx - 0.04, top - 0.12, 0), (cx + 0.04, top + 0.08, 0.1), TRIM, skip=("back",))
    elif style == "timber":
        b.box((x0 - 0.12, top, 0), (x1 + 0.12, top + 0.16, 0.035), TIMBER, skip=("back",))


# ---------------------------------------------------------------------------------------------
# Tür, Stufen, Erker, Balkon
# ---------------------------------------------------------------------------------------------

def door_unit(b, spec, x, rnd):
    """Haustür in der Laibung (Türfarbe), Oberlicht mit Glas, Stufen davor."""
    steps = spec.get("steps", 0)
    rise = 0.15
    base = steps * rise
    reveal = 0.13 + (0.25 if steps >= 2 else 0.0)
    width = spec.get("door_width", 1.0)
    hw = width / 2
    height = 2.15
    fan = 0.42
    top = base + height + fan
    z = -reveal
    # Stufen: die obere in der Laibung, die untere steht nur wenig vor (darüber eine Rampe)
    if steps >= 2:
        b.box((x - hw, 0, z), (x + hw, base, 0.0), TRIM, skip=("back",))
        b.box((x - hw - 0.12, 0, 0.0), (x + hw + 0.12, rise, 0.28), TRIM)
        b.ramp(x - hw - 0.12, x + hw + 0.12, 0.3, 0.0, rise + 0.01)
    elif steps == 1:
        b.box((x - hw - 0.08, 0, z), (x + hw + 0.08, rise, 0.24), TRIM, skip=("back",))
        b.ramp(x - hw - 0.08, x + hw + 0.08, 0.26, 0.0, rise + 0.01)
    else:
        b.box((x - hw, 0, z), (x + hw, 0.12, 0.02), TRIM, skip=("back",))
    if reveal > 0.13:
        # Tiefe Türnische (bei zwei Stufen): Laibung bis zur Tür weiterführen
        wm = wall_mat(spec.get("ground_wall", spec["wall"]))
        b.face([V(x - hw, 0, -0.13), V(x - hw, top, -0.13), V(x - hw, top, z), V(x - hw, 0, z)], wm, (1, 0, 0))
        b.face([V(x + hw, 0, -0.13), V(x + hw, top, -0.13), V(x + hw, top, z), V(x + hw, 0, z)], wm, (-1, 0, 0))
        b.face([V(x - hw, top, -0.13), V(x + hw, top, -0.13), V(x + hw, top, z), V(x - hw, top, z)], wm, (0, -1, 0))
    f = 0.07
    b.box((x - hw, base, z), (x - hw + f, top, z + 0.06), JOINERY)
    b.box((x + hw - f, base, z), (x + hw, top, z + 0.06), JOINERY)
    b.box((x - hw + f, top - f, z), (x + hw - f, top, z + 0.06), JOINERY, skip=("left", "right"))
    b.box((x - hw + f, base + height, z), (x + hw - f, base + height + 0.06, z + 0.06), JOINERY, skip=("left", "right"))
    dx0, dx1 = x - hw + f, x + hw - f
    leaf = spec.get("door_leaf", "panel")
    b.box((dx0, base, z - 0.02), (dx1, base + height, z + 0.03), JOINERY, skip=("back",))
    if leaf == "panel":
        for (py0, py1) in ((0.3, 0.95), (1.1, height - 0.15)):
            for (px0, px1) in ((dx0 + 0.08, x - 0.04), (x + 0.04, dx1 - 0.08)):
                b.frame(px0, base + py0, px1, base + py1, z + 0.03, z + 0.045, 0.025, JOINERY)
    else:
        # Obere Hälfte verglast (Glas, dahinter dunkler Flur)
        b.frame(dx0 + 0.1, base + 0.3, dx1 - 0.1, base + 0.95, z + 0.03, z + 0.045, 0.025, JOINERY)
        gy0, gy1 = base + 1.15, base + height - 0.12
        b.quad(V(dx0 + 0.1, gy0, z + 0.035), V(dx1 - 0.1, gy0, z + 0.035), V(dx1 - 0.1, gy1, z + 0.035), V(dx0 + 0.1, gy1, z + 0.035), GLASS)
        b.quad(V(dx0 + 0.1, gy0, z + 0.01), V(dx1 - 0.1, gy0, z + 0.01), V(dx1 - 0.1, gy1, z + 0.01), V(dx0 + 0.1, gy1, z + 0.01),
               Mat("plain", color=(0.3, 0.26, 0.22), glow=0.1))
        b.frame(dx0 + 0.1, gy0, dx1 - 0.1, gy1, z + 0.03, z + 0.05, 0.03, JOINERY)
    b.box((x - 0.12, base + 1.0, z + 0.03), (x + 0.12, base + 1.04, z + 0.042), GOLD)
    b.cylinder(V(x, base + 1.5, z + 0.03), 0.035, 0.015, GOLD, segments=10, axis="z", caps=(True, True))
    b.sphere(V(dx1 - 0.08, base + 1.02, z + 0.06), 0.028, GOLD, rings=4, segments=8)
    gy0 = base + height + 0.06
    b.quad(V(dx0, gy0, z + 0.015), V(dx1, gy0, z + 0.015), V(dx1, top - f, z + 0.015), V(dx0, top - f, z + 0.015), GLASS)
    b.quad(V(dx0, gy0, z - 0.01), V(dx1, gy0, z - 0.01), V(dx1, top - f, z - 0.01), V(dx0, top - f, z - 0.01),
           Mat("plain", color=(0.86, 0.82, 0.72), glow=0.25))
    if spec.get("fanlight", "bars") == "fan":
        cx = x
        for k in range(1, 6):
            a = math.pi * k / 6
            b.tube([V(cx, gy0 + 0.02, z + 0.03), V(cx - math.cos(a) * (hw - f), gy0 + math.sin(a) * (fan - 0.1), z + 0.03)], 0.008, JOINERY, segments=4)
    else:
        for k in range(1, 4):
            bx = dx0 + (dx1 - dx0) * k / 4
            b.box((bx - 0.012, gy0, z + 0.015), (bx + 0.012, top - f, z + 0.04), JOINERY)
    style = spec["door_style"]
    if style == "simple":
        _lintel(b, spec["lintel"] if spec["lintel"] != "timber" else "timber", x, x - hw, x + hw, top, width, spec)
    elif style == "pilaster":
        col = CREAM if rnd.random() < 0.5 else TRIM
        for side in (-1, 1):
            px = x + side * (hw + 0.1)
            b.box((px - 0.09, 0, 0), (px + 0.09, top, 0.09), col, skip=("back",))
            b.box((px - 0.11, 0, 0), (px + 0.11, 0.25, 0.11), col, skip=("back",))
            b.box((px - 0.11, top - 0.12, 0), (px + 0.11, top, 0.11), col, skip=("back",))
        b.box((x - hw - 0.24, top, 0), (x + hw + 0.24, top + 0.2, 0.1), col, skip=("back",))
        b.extrude_x([(0, top + 0.2), (0, top + 0.32), (0.18, top + 0.32), (0.18, top + 0.28), (0.12, top + 0.2)],
                    x - hw - 0.3, x + hw + 0.3, col)
    elif style == "hood":
        # Vordach auf zwei geschwungenen Konsolen
        y = top + 0.08
        for side in (-1, 1):
            px = x + side * (hw + 0.12)
            b.box((px - 0.05, y - 0.45, 0), (px + 0.05, y, 0.12), JOINERY, skip=("back",))
            b.tube([V(px, y - 0.45, 0.02), V(px, y - 0.2, 0.25), V(px, y, 0.48)], 0.03, JOINERY, segments=5)
        b.slab([V(x - hw - 0.3, y + 0.08, 0.55), V(x + hw + 0.3, y + 0.08, 0.55), V(x + hw + 0.3, y + 0.22, 0.0), V(x - hw - 0.3, y + 0.22, 0.0)][::-1], 0.08, CREAM)
        b.slab([V(x - hw - 0.32, y + 0.09, 0.57), V(x + hw + 0.32, y + 0.09, 0.57), V(x + hw + 0.32, y + 0.24, 0.0), V(x - hw - 0.32, y + 0.24, 0.0)][::-1], 0.02, LEAD)
    elif style == "porch":
        _porch(b, x, hw, top, spec)
    return (x - hw - (0.12 if steps else 0.0), x + hw + (0.12 if steps else 0.0), top)


def _porch(b, x, hw, top, spec, depth=0.75):
    hw2 = hw + 0.35
    y = top + 0.15
    for side in (-1, 1):
        cx = x + side * (hw2 - 0.1)
        b.box((cx - 0.13, 0, depth - 0.23), (cx + 0.13, 0.25, depth + 0.03), TRIM)
        b.cylinder(V(cx, 0.25, depth - 0.1), 0.08, y - 0.45, CREAM, segments=12, radius_top=0.07)
        b.box((cx - 0.11, y - 0.2, depth - 0.21), (cx + 0.11, y, depth + 0.01), CREAM)
        b.colliders.append(((cx - 0.14, 0, depth - 0.24), (cx + 0.14, 2.2, depth + 0.04)))
    b.box((x - hw2 - 0.05, y, -0.02), (x + hw2 + 0.05, y + 0.25, depth + 0.08), CREAM, skip=("back",))
    apex = y + 0.25 + 0.45
    b.slab([V(x - hw2 - 0.08, y + 0.25, depth + 0.1), V(x + hw2 + 0.08, y + 0.25, depth + 0.1), V(x, apex, depth + 0.1)], depth + 0.1, CREAM)
    roof = ROOF_MATS[spec["roof_mat"]]
    for side in (-1, 1):
        lo = V(x + side * (hw2 + 0.12), y + 0.22, depth + 0.14)
        hi = V(x, apex + 0.05, depth + 0.14)
        pts = [lo, hi, V(hi.x, hi.y, -0.02), V(lo.x, lo.y, -0.02)]
        b.slab(pts if side < 0 else pts[::-1], 0.05, roof)


def bay(b, spec, cx, width, depth, height, rnd, room):
    """Erker im Erdgeschoss (drei Glasseiten, dahinter ein Raum), Brüstung in Wandfarbe."""
    hw = width / 2
    pts = [(cx - hw - depth, 0.0), (cx - hw, depth), (cx + hw, depth), (cx + hw + depth, 0.0)]
    sill = 0.75
    head = height - 0.3
    wall = wall_mat(spec["wall"])
    kind = rnd.choice(["nets", "living", "nets"])
    for i in range(3):
        (ax, az), (bx, bz) = pts[i], pts[i + 1]
        a, c = V(ax, 0, az), V(bx, 0, bz)
        along = c - a
        ln = along.length
        along.normalize()
        n = V(-along.z, 0, along.x)
        b.push(S.Matrix.Translation(a) @ S.Matrix(((along.x, 0, n.x, 0), (0, 1, 0, 0), (along.z, 0, n.z, 0), (0, 0, 0, 1))))
        b.box((0, 0, -0.02), (ln, sill, 0.0), wall, skip=("back",))
        b.box((-0.02, sill, -0.02), (ln + 0.02, sill + 0.06, 0.06), TRIM, skip=("back",))
        sash(b, ln / 2, sill + 0.06, ln - 0.02, head - sill - 0.06, 0.04, spec["panes"] if spec["panes"] != "french" else "sash22")
        cw = ln * 0.18
        fab = Mat("fabric", color=rnd.choice(CURTAINS))
        for a0, a1 in ((0.05, 0.05 + cw), (ln - 0.05 - cw, ln - 0.05)):
            _drape(b, a0, a1, sill + 0.1, head - 0.05, -0.03, fab, folds=2)
        if kind == "nets":
            _drape(b, 0.05 + cw, ln - 0.05 - cw, sill + 0.1, sill + 0.1 + (head - sill) * 0.45, -0.028, Mat("fabric", color=(0.92, 0.9, 0.84), glow=0.05), folds=int(ln / 0.06))
        b.box((0, head, -0.02), (ln, height, 0.0), JOINERY, skip=("back",))
        b.pop()
    # Innen: Boden, Decke und dahinter ein Raum durch eine Öffnung in der Hauswand
    rx0, rx1, fy, cy, rdepth = room
    inner = [V(px, fy, pz) for px, pz in pts]
    b.face(inner, Mat("boards", color=(0.58, 0.42, 0.3), glow=0.1), (0, 1, 0))
    b.face([V(p.x, head, p.z) for p in inner], Mat("plain", color=(0.9, 0.88, 0.82), glow=0.14), (0, -1, 0))
    if kind == "living":
        _living_room(b, rx0, rx1, fy, cy, 0.0, rdepth, rnd)
    else:
        _shallow_room(b, rx0, rx1, fy, cy, 0.0, 1.2, rnd)
    over = 0.06
    roof = [V(pts[0][0] - over, height, 0.0), V(pts[1][0] - over * 0.4, height, pts[1][1] + over),
            V(pts[2][0] + over * 0.4, height, pts[2][1] + over), V(pts[3][0] + over, height, 0.0)]
    b.slab([V(p.x, p.y + 0.08, p.z) for p in roof], 0.08, CREAM)
    peak = [V(p.x, height + 0.08, p.z) for p in roof]
    top = [V(pts[0][0] + 0.15, height + 0.34, 0.0), V(pts[1][0] + 0.1, height + 0.34, pts[1][1] - 0.2),
           V(pts[2][0] - 0.1, height + 0.34, pts[2][1] - 0.2), V(pts[3][0] - 0.15, height + 0.34, 0.0)]
    rm = ROOF_MATS[spec["roof_mat"]]
    for i in range(3):
        b.poly([peak[i], peak[i + 1], top[i + 1], top[i]], rm)
    b.poly([top[0], top[1], top[2], top[3]], rm)
    for px, pz in pts[1:3]:
        b.cylinder(V(px, 0, pz), 0.05, height, JOINERY, segments=8, caps=(False, True))
    for i in range(3):
        (ax, az), (bx2, bz) = pts[i], pts[i + 1]
        b.colliders.append(((min(ax, bx2), 0, 0), (max(ax, bx2), 1.0, max(az, bz))))
    return (cx - hw - depth, 0.0, cx + hw + depth, height)


def balcony(b, kind, x, y_floor, w, rnd):
    """Kleiner Balkon vor einem bodentiefen Fenster: juliet (nur Geländer) oder stone (Platte auf
    Konsolen mit Eisengeländer)."""
    if kind == "stone":
        d = 0.5
        x0, x1 = x - w / 2 - 0.25, x + w / 2 + 0.25
        b.box((x0, y_floor - 0.12, 0), (x1, y_floor, d), TRIM)
        for cx in (x0 + 0.12, x1 - 0.12):
            b.box((cx - 0.06, y_floor - 0.45, 0), (cx + 0.06, y_floor - 0.12, 0.12), TRIM, skip=("back",))
            b.beam(V(cx, y_floor - 0.45, 0.06), V(cx, y_floor - 0.12, d - 0.08), 0.1, 0.06, TRIM)
        _railing(b, [V(x0 + 0.04, y_floor, 0.0), V(x0 + 0.04, y_floor, d - 0.04), V(x1 - 0.04, y_floor, d - 0.04), V(x1 - 0.04, y_floor, 0.0)], 0.95)
        for cx in (x0 + 0.25, x1 - 0.25):
            b.cylinder(V(cx, y_floor, d - 0.2), 0.1, 0.2, POT, segments=10, radius_top=0.12)
            b.sphere(V(cx, y_floor + 0.3, d - 0.2), 0.13, P.leaf(rnd.randrange(3)), rings=4, segments=8, jitter=0.15, seed=rnd.randrange(99))
            P.blossom_cluster(b, (cx, y_floor + 0.3, d - 0.2), 0.12, rnd.choice(["rose", "white", "coral"]), rnd, count=8)
    else:
        x0, x1 = x - w / 2 - 0.05, x + w / 2 + 0.05
        _railing(b, [V(x0, y_floor + 0.05, 0.03), V(x0, y_floor + 0.05, 0.14), V(x1, y_floor + 0.05, 0.14), V(x1, y_floor + 0.05, 0.03)], 0.8)


def _railing(b, path, height):
    """Eisengeländer entlang einer Linie (Handlauf, Stäbe, Fußleiste)."""
    for i in range(len(path) - 1):
        a, c = path[i], path[i + 1]
        b.tube([a + V(0, height, 0), c + V(0, height, 0)], 0.018, IRON, segments=5)
        b.tube([a + V(0, 0.08, 0), c + V(0, 0.08, 0)], 0.012, IRON, segments=4)
        n = max(1, int((c - a).length / 0.11))
        for k in range(n + 1):
            p = a + (c - a) * (k / n)
            b.box((p.x - 0.008, p.y + 0.08, p.z - 0.008), (p.x + 0.008, p.y + height, p.z + 0.008), IRON, skip=("bottom", "top"))
            if k % 4 == 2:
                b.sphere(p + V(0, height * 0.55, 0), 0.025, IRON, rings=3, segments=6)


def fence(b, w, z, gate_x0, gate_x1):
    """Niedrige Mauer mit Eisenzaun vor dem Vorgarten, Lücke mit Törchen am Weg."""
    for a0, a1 in ((-w + 0.02, gate_x0), (gate_x1, w - 0.02)):
        if a1 - a0 < 0.05:
            continue
        b.box((a0, 0, z - 0.12), (a1, 0.35, z + 0.12), TRIM)
        b.box((a0 - 0.01, 0.35, z - 0.14), (a1 + 0.01, 0.4, z + 0.14), TRIM)
        n = int((a1 - a0) / 0.12)
        for k in range(n + 1):
            x = a0 + 0.04 + (a1 - a0 - 0.08) * k / max(1, n)
            b.box((x - 0.009, 0.4, z - 0.009), (x + 0.009, 1.15, z + 0.009), IRON, skip=("bottom",))
            b.cylinder(V(x, 1.15, z), 0.018, 0.06, IRON, segments=6, radius_top=0.0, caps=(True, False))
        b.tube([V(a0, 1.05, z), V(a1, 1.05, z)], 0.012, IRON, segments=4)
        b.tube([V(a0, 0.5, z), V(a1, 0.5, z)], 0.012, IRON, segments=4)
        for px in (a0, a1):
            b.box((px - 0.11, 0, z - 0.11), (px + 0.11, 1.2, z + 0.11), TRIM)
            b.box((px - 0.13, 1.2, z - 0.13), (px + 0.13, 1.27, z + 0.13), TRIM)
    # Törchen (geschlossen)
    n = int((gate_x1 - gate_x0) / 0.1)
    for k in range(1, n):
        x = gate_x0 + (gate_x1 - gate_x0) * k / n
        b.box((x - 0.009, 0.08, z - 0.009), (x + 0.009, 1.05, z + 0.009), IRON)
    b.tube([V(gate_x0 + 0.1, 1.0, z), V(gate_x1 - 0.1, 1.0, z)], 0.012, IRON, segments=4)
    b.tube([V(gate_x0 + 0.1, 0.15, z), V(gate_x1 - 0.1, 0.15, z)], 0.012, IRON, segments=4)
    b.colliders.append(((-w, 0, z - 0.15), (w, 1.2, z + 0.15)))


def front_garden(b, w, setback, path_x, rnd):
    """Vorgarten: Plattenweg zur Tür, Beete mit Lavendel, Buchs und Rosen."""
    z0, z1 = 0.0, -setback
    b.box((path_x - 0.5, 0, z1), (path_x + 0.5, 0.02, z0), Mat("paving", color=(0.92, 0.9, 0.86)), skip=("bottom",))
    for a0, a1 in ((-w, path_x - 0.5), (path_x + 0.5, w)):
        if a1 - a0 < 0.3:
            continue
        b.box((a0, 0, z1), (a1, 0.06, z0 - 0.15), Mat("plain", color=(0.24, 0.18, 0.13)), skip=("bottom",))
        x = a0 + 0.3
        while x < a1 - 0.2:
            z = z1 + rnd.uniform(0.35, setback - 0.45)
            r = rnd.uniform(0.18, 0.3)
            b.sphere(V(x, r * 0.8, z), r, P.leaf(rnd.randrange(3)), rings=5, segments=9, squash=0.8, jitter=0.15, seed=rnd.randrange(999))
            if rnd.random() < 0.6:
                P.blossom_cluster(b, (x, r * 0.8, z), r, rnd.choice(["lavender", "rose", "white"]), rnd, count=10)
            x += rnd.uniform(0.45, 0.7)


def ivy(b, x, z, top, rnd, spread=0.8):
    """Efeu an der Fassade: Polster aus Laub, die nach oben schmaler werden."""
    y = 0.2
    while y < top:
        t = y / top
        width = spread * (1.0 - 0.6 * t)
        for _ in range(3):
            px = x + rnd.uniform(-width, width)
            r = rnd.uniform(0.16, 0.26) * (1 - 0.4 * t)
            b.sphere(V(px, y, z + r * 0.35), r, P.leaf(rnd.randrange(3)), rings=4, segments=8, squash=0.9, jitter=0.2, seed=rnd.randrange(999))
        y += 0.32


# ---------------------------------------------------------------------------------------------
# Fachwerk
# ---------------------------------------------------------------------------------------------

def timber_frame(b, x0, x1, y0, y1, holes, rnd, z=0.0):
    """Fachwerk auf einer Putzfläche: Schwelle, Rähm, Ständer neben den Fenstern, Streben
    (abwechselnd) und Brüstungskreuze unter den Fenstern."""
    t = 0.16
    d = 0.035
    b.box((x0, y0, z), (x1, y0 + t, z + d), TIMBER, skip=("back",))
    b.box((x0, y1 - t, z), (x1, y1, z + d), TIMBER, skip=("back",))
    posts = {round(x0, 3), round(x1 - t, 3)}
    for hx0, hy0, hx1, hy1 in holes:
        posts.add(round(hx0 - t, 3))
        posts.add(round(hx1, 3))
        b.box((hx0 - t, hy0 - t, z), (hx1 + t, hy0, z + d), TIMBER, skip=("back",))
        b.box((hx0 - t, hy1, z), (hx1 + t, hy1 + t, z + d), TIMBER, skip=("back",))
        # Andreaskreuz unter dem Fenster
        if hy0 - t - (y0 + t) > 0.35:
            _brace(b, hx0, y0 + t, hx1, hy0 - t, z, d)
            _brace(b, hx1, y0 + t, hx0, hy0 - t, z, d)
    xs = sorted(p for p in posts if x0 - 0.01 <= p <= x1 - t + 0.01)
    for px in xs:
        b.box((px, y0 + t, z), (px + t, y1 - t, z + d), TIMBER, skip=("back",))
    # Felder ohne Fenster: Streben
    for k in range(len(xs) - 1):
        a, c = xs[k] + t, xs[k + 1]
        if c - a < 0.4:
            continue
        mid = (a + c) / 2
        if any(hx0 - t - 0.01 <= mid <= hx1 + t + 0.01 for hx0, _, hx1, _ in holes):
            continue
        if c - a > 1.4:
            post = mid - t / 2
            b.box((post, y0 + t, z), (post + t, y1 - t, z + d), TIMBER, skip=("back",))
            _brace(b, a, y0 + t, post, y1 - t, z, d)
            _brace(b, c, y0 + t, post + t, y1 - t, z, d)
        elif rnd.random() < 0.5:
            _brace(b, a, y0 + t, c, y1 - t, z, d)
        else:
            _brace(b, a, y0 + t, c, y1 - t, z, d)
            _brace(b, c, y0 + t, a, y1 - t, z, d)


def _brace(b, xa, ya, xb, yb, z, d, width=0.13):
    """Schräge Strebe von (xa, ya) nach (xb, yb) als flaches Brett vor der Wand."""
    a, c = V(xa, ya, 0), V(xb, yb, 0)
    u = (c - a).normalized()
    n = V(-u.y, u.x, 0) * (width / 2)
    pts = [a - n, c - n, c + n, a + n]
    b.slab([V(p.x, p.y, z + d * 0.8) for p in pts] if (pts[1] - pts[0]).cross(pts[2] - pts[0]).z > 0 else
           [V(p.x, p.y, z + d * 0.8) for p in reversed(pts)], d * 0.8, TIMBER)


# ---------------------------------------------------------------------------------------------
# Dach, Seiten, Schornstein, Traufe, Ecken
# ---------------------------------------------------------------------------------------------

def side_profile(spec):
    """Umriss des Hauses von der Seite (z, y): von der Traufe vorn über den First bis hinten."""
    E, D = spec["eaves"], spec["depth"]
    fz = spec["roof_front_z"]
    bz = -D - 0.2
    roof = spec["roof"]
    if roof == "mansard":
        k = spec["mansard_height"]
        return [(fz, E), (fz - 0.85, E + k), (-D / 2, E + k + 0.7), (bz + 0.85, E + k), (bz, E)]
    if roof == "front_gable":
        return [(fz, E), (bz, E)]
    rise = (D / 2 + fz) * math.tan(math.radians(spec["pitch"]))
    return [(fz, E), (-D / 2, E + rise), (bz, E)]


def roof_and_walls(b, spec):
    """Dach (Satteldach, Mansarddach, Giebel zur Straße), Seiten-/Brandwände mit Aufkantung,
    Rückwand, Traufe hinten."""
    W, D, E = spec["width"], spec["depth"], spec["eaves"]
    w = W / 2
    rm = ROOF_MATS[spec["roof_mat"]]
    # Seiten passend zur Front: gleiches Material wie die oberen Geschosse (früher Backstein)
    side = wall_mat(spec.get("upper_wall", spec["wall"]))
    if spec["roof"] == "front_gable":
        _front_gable_roof(b, spec, rm, side)
        return
    prof = side_profile(spec)
    for i in range(len(prof) - 1):
        (za, ya), (zc, yc) = prof[i], prof[i + 1]
        b.face([V(-w, ya, za), V(w, ya, za), V(w, yc, zc), V(-w, yc, zc)], rm, (0, 1, 0))
    ridge_i = max(range(len(prof)), key=lambda i: prof[i][1])
    if spec["roof"] != "mansard":
        rz, ry = prof[ridge_i]
        b.cylinder(V(-w, ry + 0.02, rz), 0.09, W, RIDGE if spec["roof_mat"] == "clay" else Mat("terracotta", color=(0.55, 0.55, 0.58)), segments=8, caps=(True, True), axis="x")
    for s in (-1, 1):
        x = s * w
        # Giebel über der Traufe (die Wand darunter baut _side_walls, mit Fenstern wo frei)
        pts = [V(x, E, 0)] + [V(x, y + 0.1, z) for z, y in prof] + [V(x, E, -D)]
        b.face(pts, side, (s, 0, 0))
        xc = s * (w - 0.17)
        for i in range(len(prof) - 1):
            (za, ya), (zc, yc) = prof[i], prof[i + 1]
            pa, pc = V(xc, ya - 0.08, za), V(xc, yc - 0.08, zc)
            b.beam(pa, pc, 0.3, 0.2, side)
            b.beam(pa + V(0, 0.2, 0), pc + V(0, 0.2, 0), 0.34, 0.045, TRIM)
        rz, ry = prof[ridge_i]
        b.box((xc - 0.18, ry + 0.08, rz - 0.2), (xc + 0.18, ry + 0.2, rz + 0.2), TRIM)
    b.quad(V(w, 0, -D), V(-w, 0, -D), V(-w, E, -D), V(w, E, -D), side)
    bz = -D - 0.2
    b.box((-w, E - 0.22, bz), (w, E + 0.01, -D), CREAM, skip=("front",))


def _front_gable_roof(b, spec, rm, side):
    """Giebel zur Straße: First quer zur Straße, Giebeldreieck vorn (Fachwerk oder Wand)."""
    W, D, E = spec["width"], spec["depth"], spec["eaves"]
    w = W / 2
    ov = 0.35
    rise = w * math.tan(math.radians(spec["pitch"]))
    ry = E + rise
    fz = spec.get("gable_front_z", 0.0) + ov
    bz = -D - 0.2
    for s in (-1, 1):
        lo = V(s * (w + 0.02), E - 0.02, fz)
        hi = V(0, ry, fz)
        pts = [lo, hi, V(0, ry, bz), V(lo.x, lo.y, bz)]
        b.slab(pts if s < 0 else pts[::-1], 0.06, rm)
        # Ortgang (verziert, Holz) vorn
        b.beam(V(s * (w + 0.04), E - 0.2, fz + 0.01), V(0, ry - 0.12, fz + 0.01), 0.05, 0.2, spec.get("barge_mat", TIMBER))
    b.cylinder(V(0, ry + 0.03, bz), 0.08, fz - bz, RIDGE if spec["roof_mat"] == "clay" else Mat("terracotta", color=(0.55, 0.55, 0.58)), segments=8, axis="z", caps=(True, True))
    b.cylinder(V(0, ry - 0.3, fz + 0.04), 0.035, 0.75, TIMBER, segments=6, radius_top=0.012)
    b.face([V(w, 0, -D), V(-w, 0, -D), V(-w, E, -D), V(w, E, -D), V(0, ry, -D)], side, (0, 0, -1))


def gable_triangle(b, spec, rnd):
    """Vorderes Giebeldreieck (bei Giebel zur Straße) mit Fenster, ggf. Fachwerk."""
    W, E = spec["width"], spec["eaves"]
    w = W / 2
    rise = w * math.tan(math.radians(spec["pitch"]))
    z = spec.get("gable_front_z", 0.0)
    wh, ww = 0.95, 0.75
    gy0 = E + 0.35
    hole = (-ww / 2, gy0, ww / 2, gy0 + wh)
    mat = wall_mat(spec["upper_wall"])
    # Giebelwand mit Fensterloch, genau unter den Dachschrägen: seitliche Trapeze, Streifen
    # unter dem Fenster (mit Laibung) und das Dreieck über dem Fenster
    b.push(b.move(0, 0, z))
    top_y = gy0 + wh
    half_at = w * (1 - (top_y - E) / rise)
    for s in (-1, 1):
        b.face([V(s * w, E, 0), V(s * ww / 2, E, 0), V(s * ww / 2, top_y, 0), V(s * half_at, top_y, 0)], mat, (0, 0, 1))
    b.wall_with_holes(-ww / 2 - 0.001, ww / 2 + 0.001, E, top_y, 0.0, [hole], mat, reveal=0.12)
    b.face([V(-half_at, top_y, 0), V(half_at, top_y, 0), V(0, E + rise, 0)], mat, (0, 0, 1))
    room = (-ww / 2 - 0.3, ww / 2 + 0.3, gy0 - 0.4, gy0 + wh + 0.2, 0.9)
    window_unit(b, spec, 0.0, gy0, ww, wh, "casement" if spec.get("fachwerk") else spec["panes"],
                rnd.choice(["closed", "dim", "nets"]), room, rnd, reveal=0.12, lintel="timber" if spec.get("fachwerk") else "flat")
    if spec.get("fachwerk"):
        t = 0.16
        b.box((-w, E, 0), (w, E + t, 0.035), TIMBER, skip=("back",))
        for s in (-1, 1):
            b.box((s * (ww / 2) - (t if s < 0 else 0), E + t, 0), (s * (ww / 2) + (0 if s < 0 else t), gy0 + wh + t, 0.035), TIMBER, skip=("back",))
            _brace(b, s * (w - 0.1), E + t, s * (ww / 2 + t), gy0 + wh * 0.8, 0.0, 0.035)
        b.box((-ww / 2 - t, gy0 + wh, 0), (ww / 2 + t, gy0 + wh + t, 0.035), TIMBER, skip=("back",))
        b.box((-0.08, gy0 + wh + t, 0), (0.08, E + rise - 0.3, 0.035), TIMBER, skip=("back",))
    b.pop()


def chimney(b, x, z, base_y, top_y, pots=2, mat=CHIMNEY_BRICK):
    hw, hd = 0.31, 0.45
    b.box((x - hw, base_y, z - hd), (x + hw, top_y - 0.1, z + hd), mat, skip=("bottom", "top"))
    b.box((x - hw - 0.05, top_y - 0.1, z - hd - 0.05), (x + hw + 0.05, top_y, z + hd + 0.05), TRIM)
    b.box((x - hw - 0.04, top_y - 0.3, z - hd - 0.04), (x + hw + 0.04, top_y - 0.22, z + hd + 0.04), TRIM)
    for k in range(pots):
        pz = z + (k - (pots - 1) / 2) * (2 * hd / pots)
        b.cylinder(V(x, top_y, pz), 0.1, 0.36, POT, segments=10, radius_top=0.08, caps=(False, False))
        b.cylinder(V(x, top_y + 0.36, pz), 0.095, 0.05, POT, segments=10, caps=(True, False))
        b.cylinder(V(x, top_y + 0.4, pz), 0.07, 0.012, Mat("plain", color=(0.06, 0.05, 0.05)), segments=10)
        b.poly([V(x + 0.095 * math.cos(a), top_y + 0.41, pz - 0.095 * math.sin(a)) for a in [2 * math.pi * k2 / 10 for k2 in range(10)]], POT)


def eaves(b, spec):
    W, E = spec["width"], spec["eaves"]
    w = W / 2
    style = spec["eaves_style"]
    wall = wall_mat(spec["wall" if spec.get("upper_wall") is None else "upper_wall"])
    if spec["roof"] == "parapet":
        h = 0.75 if spec.get("balustrade") else 0.55
        b.box((-w, E, -0.36), (w, E + h, 0.0), wall, skip=("top",))
        b.box((-w, E - 0.25, 0), (w, E - 0.1, 0.06), TRIM, skip=("back",))
        if spec.get("balustrade"):
            b.box((-w, E + 0.02, -0.02), (w, E + 0.12, 0.08), TRIM)
            n = int(W / 0.2)
            for k in range(n):
                bx = -w + 0.15 + (W - 0.3) * k / max(1, n - 1)
                b.cylinder(V(bx, E + 0.12, 0.02), 0.045, 0.5, TRIM, segments=8, radius_top=0.035)
            b.box((-w - 0.02, E + 0.62, -0.38), (w + 0.02, E + 0.72, 0.1), TRIM)
            b.box((-w, E + h, -0.36), (w, E + h + 0.01, -0.0), TRIM)
        else:
            b.box((-w - 0.02, E + h, -0.38), (w + 0.02, E + h + 0.07, 0.05), TRIM)
        return
    if style == "dentil":
        x = -w + 0.06
        while x + 0.08 < w:
            b.box((x, E - 0.2, 0), (x + 0.08, E - 0.08, 0.08), TRIM, skip=("back",))
            x += 0.18
        b.box((-w, E - 0.08, 0), (w, E, 0.28), TRIM, skip=("back",))
    elif style == "corbel":
        for k, d in enumerate((0.05, 0.1, 0.16)):
            b.box((-w, E - 0.3 + k * 0.08, 0), (w, E - 0.22 + k * 0.08, d), wall, skip=("back",))
        b.box((-w, E - 0.06, 0), (w, E, 0.28), JOINERY, skip=("back",))
    elif style == "modillion":
        x = -w + 0.15
        while x + 0.1 < w:
            b.box((x, E - 0.22, 0), (x + 0.07, E - 0.06, 0.2), TRIM, skip=("back",))
            x += 0.42
        b.extrude_x([(0, E - 0.08), (0, E), (0.3, E), (0.3, E - 0.06), (0.22, E - 0.08)], -w - 0.01, w + 0.01, TRIM)
        b.box((-w, E - 0.32, 0), (w, E - 0.22, 0.05), TRIM, skip=("back",))
    elif style == "fascia":
        b.box((-w, E - 0.22, 0), (w, E, 0.28), JOINERY, skip=("back",))
        b.box((-w, E - 0.24, 0), (w, E - 0.22, 0.29), JOINERY, skip=("back",))
    else:
        b.extrude_x([(0, E - 0.25), (0, E), (0.28, E), (0.28, E - 0.07), (0.16, E - 0.13), (0.1, E - 0.25)],
                    -w - 0.01, w + 0.01, TRIM)
    b.cylinder(V(-w, E + 0.03, 0.24), 0.055, W, LEAD, segments=8, caps=(True, True), axis="x")


def quoins(b, w, y0, y1):
    """Große Ecksteine an beiden Hauskanten (abwechselnd lang und kurz)."""
    y = y0
    k = 0
    while y + 0.28 < y1:
        long_ = k % 2 == 0
        for s in (-1, 1):
            lo, hi = sorted((s * w, s * (w - (0.46 if long_ else 0.3))))
            b.box((lo, y, 0), (hi, y + 0.27, 0.04), TRIM, skip=("back",))
        y += 0.3
        k += 1


def string_course(b, w, y, style, wall):
    if style == "band":
        b.box((-w, y - 0.06, 0), (w, y + 0.06, 0.05), TRIM, skip=("back",))
    elif style == "double":
        b.box((-w, y - 0.1, 0), (w, y - 0.04, 0.04), TRIM, skip=("back",))
        b.box((-w, y + 0.02, 0), (w, y + 0.1, 0.06), TRIM, skip=("back",))
    elif style == "brick":
        b.box((-w, y - 0.08, 0), (w, y + 0.08, 0.04), wall, skip=("back",))


# ---------------------------------------------------------------------------------------------
# Das ganze Haus
# ---------------------------------------------------------------------------------------------

def build_house(name, spec):
    """Baut ein Haus aus seiner Beschreibung."""
    rnd = random.Random(spec["seed"])
    b = S.Builder(name)
    W, E = spec["width"], spec["eaves"]
    w = W / 2
    setback = spec.get("setback", 0.0)
    b.push(b.move(0, 0, -setback))
    roof_and_walls(b, spec)
    storeys = spec["storeys"]
    ys = [0.0]
    for h in storeys:
        ys.append(ys[-1] + h)
    wall_ground = wall_mat(spec.get("ground_wall", spec["wall"]))
    wall_upper = wall_mat(spec.get("upper_wall", spec["wall"]))
    rooms_left = spec.get("rooms", 0)
    shop = spec.get("shop")
    edge = 0.46 if spec.get("quoins") else 0.1
    # --- Erdgeschoss ---
    cols = spec["columns"]
    door_i = spec["door_col"]
    holes_g = []
    door_rect = None
    g_y0, g_h = spec["ground_window"]
    bay_i = spec.get("bay_col", -1)
    for i, (x, ww) in enumerate(cols):
        if shop:
            break
        if i == door_i:
            steps = spec.get("steps", 0)
            door_rect = (x - spec.get("door_width", 1.0) / 2, 0.0, x + spec.get("door_width", 1.0) / 2, steps * 0.15 + 2.57)
            holes_g.append(door_rect)
        elif i == bay_i:
            holes_g.append((x - 0.9, 0.15, x + 0.9, storeys[0] - 0.55))
        else:
            holes_g.append((x - ww / 2, g_y0, x + ww / 2, g_y0 + g_h))
    if shop:
        shopfront_flowers(b, spec, rnd, ys[1])
    else:
        b.wall_with_holes(-w, w, 0.0, ys[1], 0.0, holes_g, wall_ground, reveal=0.13)
    # Sockel – mit Lücke an der Tür (früher lief er davor entlang)
    gaps = sorted([(door_rect[0] - 0.02, door_rect[2] + 0.02)] if door_rect else [])
    if bay_i >= 0:
        x = cols[bay_i][0]
        gaps.append((x - 1.45, x + 1.45))
        gaps.sort()
    a = -w
    for g0, g1 in (gaps + [(w, w)]) if not shop else []:
        if g0 - a > 0.02:
            b.box((a, 0, 0), (g0, 0.32, 0.035), PLINTH, skip=("back", "bottom"))
        a = max(a, g1)
    door_pad = 0.27 if spec["door_style"] in ("pilaster", "porch") else 0.1
    ground_open = [((x - spec.get("door_width", 1.0) / 2 - door_pad, x + spec.get("door_width", 1.0) / 2 + door_pad) if i == door_i else
                    (x - 1.0, x + 1.0) if i == bay_i else (x - ww / 2, x + ww / 2)) for i, (x, ww) in enumerate(cols)]
    for i, (x, ww) in enumerate(cols):
        if shop:
            break
        if i == door_i:
            door_unit(b, spec, x, rnd)
        elif i == bay_i:
            room = (max(-w + 0.15, x - 1.4), min(w - 0.15, x + 1.4), 0.15, storeys[0] - 0.35, 2.6)
            # Wand-Laibung des Durchgangs zum Erker
            bay(b, spec, x, 1.1, 0.45, storeys[0] - 0.3, rnd, room)
        else:
            kind, rooms_left = _pick_backdrop(spec, rnd, rooms_left, 0)
            room = _room_box(cols, i, w, 0.15, storeys[0] - 0.3, kind)
            window_unit(b, spec, x, g_y0, ww, g_h, spec["panes_ground"], kind, room, rnd,
                        shutters=_shutter_space(ground_open, i, w, edge) if spec.get("shutters") else 0.0)
    if spec.get("quoins"):
        quoins(b, w, 0.35, ys[-1] - 0.3)
    # --- Obergeschosse ---
    for fl in range(1, len(storeys)):
        base, topy = ys[fl], ys[fl + 1]
        jetty = spec.get("jetty", 0.0) if spec.get("fachwerk") else 0.0
        b.push(b.move(0, 0, jetty))
        f_y0 = base + spec["upper_sill"]
        # Im obersten Geschoss Platz für Sturz und Traufgesims lassen
        top_floor = fl == len(storeys) - 1 and spec["roof"] != "front_gable"
        f_h = min(spec["upper_window_h"], topy - f_y0 - (0.8 if top_floor else 0.45))
        holes = []
        french_i = spec.get("balcony_col", -1) if fl == spec.get("balcony_floor", 1) else -1
        for i, (x, ww) in enumerate(spec["upper_columns"]):
            if i == french_i:
                holes.append((x - ww / 2, base + 0.08, x + ww / 2, f_y0 + f_h))
            else:
                holes.append((x - ww / 2, f_y0, x + ww / 2, f_y0 + f_h))
        b.wall_with_holes(-w, w, base, topy, 0.0, holes, wall_upper, reveal=0.13)
        if jetty > 0:
            # Vorkragung: Unterseite und Seiten des überstehenden Stücks
            b.face([V(-w, base, 0.0), V(w, base, 0.0), V(w, base, -jetty), V(-w, base, -jetty)], TIMBER, (0, -1, 0))
            for s in (-1, 1):
                b.face([V(s * w, base, 0), V(s * w, topy, 0), V(s * w, topy, -jetty), V(s * w, base, -jetty)], wall_upper, (s, 0, 0))
            n = int(W / 0.5)
            for k in range(n + 1):
                bx = -w + 0.08 + (W - 0.16) * k / n
                b.box((bx - 0.06, base - 0.16, -jetty), (bx + 0.06, base, 0.02), TIMBER)
        if spec.get("fachwerk"):
            timber_frame(b, -w, w, base, topy, holes, rnd)
        for i, (x, ww) in enumerate(spec["upper_columns"]):
            if i == french_i:
                window_unit(b, spec, x, base + 0.08, ww, f_y0 + f_h - base - 0.08, "french",
                            rnd.choice(["nets", "dim", "blind"]), _room_box(spec["upper_columns"], i, w, base + 0.05, topy - 0.25, "nets"), rnd,
                            lintel=spec["lintel"], sill=False)
                balcony(b, spec.get("balcony", "juliet"), x, base + 0.08, ww, rnd)
                continue
            kind, rooms_left = _pick_backdrop(spec, rnd, rooms_left, fl)
            room = _room_box(spec["upper_columns"], i, w, base + 0.05, topy - 0.25, kind)
            upper_open = [(cx - cw / 2, cx + cw / 2) for cx, cw in spec["upper_columns"]]
            window_unit(b, spec, x, f_y0, ww, f_h, spec["panes"], kind, room, rnd,
                        lintel="timber" if spec.get("fachwerk") else None,
                        shutters=_shutter_space(upper_open, i, w, edge) if spec.get("shutters") else 0.0, floor=fl)
            if spec.get("flower_boxes") and fl == 1 and (shop or rnd.random() < 0.7):
                P.flower_box(b, x - ww / 2 - 0.04, x + ww / 2 + 0.04, f_y0 + 0.005, 0.0, 0.19, ACCENT,
                             [rnd.choice(["rose", "white", "coral", "lavender"]), rnd.choice(["white", "rose", "lavender"])], seed=rnd.randrange(999))
        b.pop()
        if fl < len(storeys) and not spec.get("fachwerk"):
            string_course(b, w, base, spec["string"], wall_upper)
    # --- Dachgeschoss: Giebel, Gauben, Traufe, Schornsteine ---
    if spec["roof"] == "front_gable":
        gable_triangle(b, spec, rnd)
    else:
        eaves(b, spec)
        for k, dx in enumerate(spec.get("dormers", [])):
            if spec["roof"] == "mansard":
                _mansard_dormer(b, spec, dx, rnd)
            else:
                _dormer(b, spec, dx, rnd)
    for side in spec.get("chimneys", []):
        prof = side_profile(spec)
        top = max(y for _, y in prof) if spec["roof"] != "front_gable" else E + w * math.tan(math.radians(spec["pitch"]))
        if spec["roof"] == "front_gable":
            chimney(b, side * (w - 0.9), -spec["depth"] * 0.6, E, top + 0.6, pots=rnd.randint(1, 3))
        else:
            chimney(b, side * (w - 0.36), -spec["depth"] / 2, top - 0.6, top + rnd.uniform(0.8, 1.2), pots=rnd.randint(1, 4))
    if spec.get("downpipe", True):
        b.cylinder(V((w - 0.1) * spec.get("downpipe_side", 1), 0.0, 0.07), 0.04, E + 0.05, LEAD, segments=8, caps=(True, True))
    _side_walls(b, spec, rnd, ys)
    if spec.get("ivy"):
        ivy(b, spec["ivy"] * (w - 0.5), 0.0, ys[-1] * 0.85, rnd)
    if shop:
        shop_outside_flowers(b, spec, rnd)
    # --- Vor dem Haus ---
    if door_rect and spec.get("pots") and not shop:
        dx = cols[door_i][0]
        for s in spec["pots"]:
            _door_pot(b, dx + s * (spec.get("door_width", 1.0) / 2 + 0.35 + (0.15 if spec.get("steps") else 0.0)), 0.25, rnd)
    b.pop()
    if setback > 0:
        px = cols[door_i][0] if door_rect else 0.0
        front_garden(b, w, setback, px, rnd)
        fence(b, w, 0.12, px - 0.5, px + 0.5)
    return b


def _shutter_space(openings, i, w, edge):
    """Freier Platz neben Öffnung i (kleinster Abstand links/rechts zur nächsten Öffnung bzw.
    Hauskante, abzüglich Eckquader) – so breit dürfen Läden höchstens sein."""
    x0, x1 = openings[i]
    left = x0 - (openings[i - 1][1] if i > 0 else -w + edge)
    right = (openings[i + 1][0] if i + 1 < len(openings) else w - edge) - x1
    if i > 0:
        left /= 2
    if i + 1 < len(openings):
        right /= 2
    return max(0.0, min(left, right) - 0.04)


def _side_walls(b, spec, rnd, ys):
    """Seitenwände bis zur Traufe im Material der Front. Wo die Seite frei sichtbar ist (Gasse,
    Ende der Reihe), bekommt sie Fenster; wo nur ein Stück vorn frei ist (Nachbar zurück-
    gesetzt), Efeu statt Fenster (spec["exposed"]: {Seite: ("full",) / ("partial", Länge)})."""
    W, D = spec["width"], spec["depth"]
    w = W / 2
    exposed = spec.get("exposed", {})
    for s in (-1, 1):
        info = exposed.get(s)
        b.push(b.move(s * w, 0, 0) @ b.turn_y(90 * s))
        lo, hi = sorted((0.0, s * D))
        for fl in range(len(spec["storeys"])):
            y0, y1 = ys[fl], ys[fl + 1]
            mat = wall_mat(spec.get("ground_wall", spec["wall"]) if fl == 0 else spec.get("upper_wall", spec["wall"]))
            holes = []
            if info and info[0] == "full":
                if fl == 0:
                    wy0, wh = 0.85, min(1.6, y1 - y0 - 1.35)
                else:
                    wy0 = y0 + 0.75
                    wh = min(1.55, y1 - wy0 - (0.8 if fl == len(spec["storeys"]) - 1 else 0.45))
                u = 1.6
                while u < D - 1.0:
                    holes.append((s * u - 0.45, wy0, s * u + 0.45, wy0 + wh))
                    u += 2.6
            b.wall_with_holes(lo, hi, y0, y1, 0.0, holes, mat, reveal=0.13)
            for k, (hx0, hy0, hx1, hy1) in enumerate(holes):
                kind = rnd.choices(["closed", "nets", "blind", "dim"], weights=[3, 4, 2, 2])[0]
                room = (hx0 - 0.25, hx1 + 0.25, y0 + 0.05, y1 - 0.25, 0.7)
                window_unit(b, spec, (hx0 + hx1) / 2, hy0, hx1 - hx0, hy1 - hy0, spec["panes"], kind, room, rnd,
                            lintel="timber" if spec.get("fachwerk") else None, floor=fl)
            if spec.get("fachwerk") and fl > 0 and info:
                timber_frame(b, lo, hi, y0, y1, holes, rnd)
        if info and info[0] == "partial" and info[1] > 0.4:
            # Nur vorn ein Stück frei: Efeu statt Fenster
            ivy(b, s * info[1] / 2, 0.0, ys[-1] * 0.8, rnd, spread=min(0.9, info[1] / 2 - 0.1))
        b.pop()


def _pick_backdrop(spec, rnd, rooms_left, floor):
    if rooms_left > 0 and floor == spec.get("room_floor", 0) and rnd.random() < 0.8:
        return spec.get("room_kind", "living"), rooms_left - 1
    return rnd.choices(["closed", "nets", "blind", "dim"], weights=[3, 4, 2, 2])[0], rooms_left


def _room_box(cols, i, w, floor_y, ceil_y, kind):
    """Platz für den Raum hinter Fenster i: bis zur Mitte zu den Nachbarfenstern."""
    x = cols[i][0]
    left = (cols[i - 1][0] + x) / 2 if i > 0 else -w + 0.15
    right = (cols[i + 1][0] + x) / 2 if i + 1 < len(cols) else w - 0.15
    depth = 2.8 if kind in ("living", "kitchen") else 0.7
    return (left + 0.02, right - 0.02, floor_y, ceil_y, depth)


def _door_pot(b, x, z, rnd):
    kind = rnd.choice(["lavender", "box", "rose", "fern"])
    h = 0.35
    b.cylinder(V(x, 0, z), 0.13, h, POT, segments=12, radius_top=0.16, caps=(False, True))
    if kind == "box":
        b.cylinder(V(x, h, z), 0.13, 0.5, P.leaf(1), segments=10, radius_top=0.02, caps=(True, True))
    else:
        b.sphere(V(x, h + 0.12, z), 0.17, P.leaf(rnd.randrange(3)), rings=5, segments=10, squash=0.8, jitter=0.12, seed=rnd.randrange(999))
        if kind != "fern":
            P.blossom_cluster(b, (x, h + 0.13, z), 0.16, "lavender" if kind == "lavender" else "rose", rnd, count=10)
    b.colliders.append(((x - 0.17, 0, z - 0.17), (x + 0.17, 0.6, z + 0.17)))


def _dormer(b, spec, cx, rnd, gw=0.45):
    """Gaube im vorderen Satteldach (Schiefer- oder Ziegelwangen, Fensterrahmen in Türfarbe)."""
    E, D = spec["eaves"], spec["depth"]
    fz = spec["roof_front_z"]
    rise = (D / 2 + fz) * math.tan(math.radians(spec["pitch"]))
    slope = rise / (fz + D / 2)
    dz = -0.7
    base = E + (fz - dz) * slope - 0.06
    top = base + 1.0
    ridge = top + 0.34
    back = fz - (ridge + 0.05 - E) / slope - 0.1
    rm = ROOF_MATS[spec["roof_mat"]]
    win_lo, win_hi = base + 0.2, top - 0.1
    b.wall_with_holes(cx - gw, cx + gw, base, top, dz, [(cx - 0.28, win_lo, cx + 0.28, win_hi)], rm, reveal=0.08, reveal_mat=JOINERY)
    b.push(b.move(0, 0, dz))
    window_unit(b, spec, cx, win_lo, 0.56, win_hi - win_lo, "casement" if spec["panes"] == "casement" else "sash22",
                rnd.choice(["closed", "dim", "nets"]), (cx - 0.4, cx + 0.4, base, top + 0.2, 0.6), rnd, reveal=0.08, lintel="none", sill=False)
    b.pop()
    b.quad(V(cx - gw, base, back), V(cx - gw, base, dz), V(cx - gw, top, dz), V(cx - gw, top, back), rm)
    b.quad(V(cx + gw, base, dz), V(cx + gw, base, back), V(cx + gw, top, back), V(cx + gw, top, dz), rm)
    b.poly([V(cx - gw, top, dz), V(cx + gw, top, dz), V(cx, ridge, dz)], JOINERY)
    for s2 in (-1, 1):
        lo = V(cx + s2 * (gw + 0.08), top - 0.06, dz + 0.12)
        hi = V(cx, ridge + 0.05, dz + 0.12)
        pts = [lo, hi, V(hi.x, hi.y, back), V(lo.x, lo.y, back)]
        b.slab(pts if s2 < 0 else pts[::-1], 0.05, rm)
        b.beam(lo + V(0, -0.13, 0.0), hi + V(0, -0.13, 0.0), 0.04, 0.12, JOINERY)


def _mansard_dormer(b, spec, cx, rnd, gw=0.42):
    """Gaube im steilen unteren Teil eines Mansarddachs (flache Abdeckung)."""
    E = spec["eaves"]
    fz = spec["roof_front_z"]
    k = spec["mansard_height"]
    dz = fz - 0.25
    base = E + 0.25 * k / 0.85 - 0.05
    top = E + k - 0.05
    back = fz - 0.85 - 0.2
    rm = ROOF_MATS[spec["roof_mat"]]
    win_lo, win_hi = base + 0.15, top - 0.18
    b.wall_with_holes(cx - gw, cx + gw, base, top, dz, [(cx - 0.3, win_lo, cx + 0.3, win_hi)], JOINERY, reveal=0.06)
    b.push(b.move(0, 0, dz))
    window_unit(b, spec, cx, win_lo, 0.6, win_hi - win_lo, "sash22", rnd.choice(["closed", "dim", "nets", "blind"]),
                (cx - 0.4, cx + 0.4, base, top, 0.5), rnd, reveal=0.06, lintel="none", sill=False)
    b.pop()
    for s in (-1, 1):
        b.face([V(cx + s * gw, base, dz), V(cx + s * gw, top, dz), V(cx + s * gw, top, back), V(cx + s * gw, base, back)], rm, (s, 0, 0))
    b.box((cx - gw - 0.06, top, back), (cx + gw + 0.06, top + 0.12, dz + 0.08), LEAD)


# ---------------------------------------------------------------------------------------------
# Blumenladen (Konzeptbild "flowershop.png"): salbeigrüne Ladenfront, Blumen innen und davor
# ---------------------------------------------------------------------------------------------

def _bucket(b, x, z, rnd, palette=None, height=0.32, radius=0.13, y=0.0, tall=False, blossoms=12):
    """Zinkeimer mit einem Strauß (Stiele, Blätter, Blüten)."""
    b.cylinder(V(x, y, z), radius * 0.85, height, P.ZINC, segments=10, radius_top=radius, caps=(True, False))
    b.cylinder(V(x, y + height - 0.03, z), radius * 0.95, 0.02, P.SOIL, segments=10)
    stem_h = 0.35 if not tall else 0.6
    b.sphere(V(x, y + height + stem_h * 0.4, z), radius * 1.1, P.leaf(rnd.randrange(3)), rings=4, segments=8,
             squash=1.4 if tall else 0.9, jitter=0.15, seed=rnd.randrange(999))
    P.blossom_cluster(b, (x, y + height + stem_h * 0.55, z), radius * 1.15, palette or rnd.choice(list(P.BLOSSOMS)), rnd,
                      count=blossoms if not tall else max(4, blossoms * 3 // 4), size=0.04)


def shopfront_flowers(b, spec, rnd, s0):
    """Ladenfront des Blumenladens: Pilaster und Schild (Bild "fascia"), zwei Schaufenster mit
    Sprossen-Oberlicht, mittige Glastür; dahinter ein kleiner Laden voller Blumen."""
    W = spec["width"]
    w = W / 2
    pil = 0.32
    fascia_lo, fascia_hi = s0 - 0.45, s0 - 0.02
    head = fascia_lo - 0.1
    door_half = 0.55
    post = 0.1
    sill = 0.62
    transom = head - 0.5
    jz = 0.13
    # Pilaster mit Kapitell, Schild, Gesims
    for side in (-1, 1):
        lo_x, hi_x = sorted((side * w, side * (w - pil)))
        b.box((lo_x, 0, 0), (hi_x, fascia_hi, 0.15), JOINERY, skip=("back",))
        b.box((lo_x - 0.02, 0, 0), (hi_x + 0.02, 0.3, 0.18), JOINERY, skip=("back", "bottom"))
        b.box((lo_x - 0.03, fascia_lo - 0.2, 0), (hi_x + 0.03, fascia_lo, 0.2), JOINERY, skip=("back",))
    b.box((-w + pil, fascia_lo, 0), (w - pil, fascia_hi, 0.17), JOINERY, skip=("back", "front"))
    b.poly([V(-w + pil, fascia_lo, 0.17), V(w - pil, fascia_lo, 0.17), V(w - pil, fascia_hi, 0.17), V(-w + pil, fascia_hi, 0.17)],
           Mat("plain", sign="fascia"), uvs=[(0, 0), (1, 0), (1, 1), (0, 1)])
    b.extrude_x([(0, fascia_hi), (0, s0 + 0.12), (0.28, s0 + 0.12), (0.28, fascia_hi + 0.08), (0.2, fascia_hi + 0.02), (0.17, fascia_hi)],
                -w - 0.03, w + 0.03, JOINERY)
    b.box((-w - 0.03, s0 + 0.12, 0), (w + 0.03, s0 + 0.14, 0.29), LEAD, skip=("back",))
    b.box((-w + pil, head, 0), (w - pil, fascia_lo, jz), JOINERY, skip=("back",))
    # Innenraum (leicht beleuchtet) – die Innenseite der Front zeigt in den Raum
    xi = w - 0.12
    floor_y, ceil_y, zb = 0.1, s0 - 0.25, -4.6
    shop_floor = Mat("boards", color=(0.6, 0.45, 0.32), glow=0.1)
    b.room((-xi, floor_y, zb), (xi, ceil_y, -0.03),
           {"floor": shop_floor, "ceiling": Mat("plain", color=(0.92, 0.9, 0.84), glow=0.16),
            "back": Mat("render", color=(0.86, 0.88, 0.8), glow=0.16), "left": Mat("render", color=(0.86, 0.88, 0.8), glow=0.16),
            "right": Mat("render", color=(0.86, 0.88, 0.8), glow=0.16)})
    windows = []
    for side in (-1, 1):
        lo_x, hi_x = sorted((side * (w - pil), side * (door_half + post)))
        windows.append((lo_x, hi_x))
    holes = [(lo, sill, hi, head) for lo, hi in windows] + [(-door_half - post, floor_y, door_half + post, transom)]
    b.push(b.move(0, 0, -0.03) @ b.turn_y(180))
    b.wall_with_holes(-xi, xi, floor_y, ceil_y, 0.0, [(-h[2], h[1], -h[0], h[3]) for h in holes],
                      Mat("render", color=(0.86, 0.88, 0.8), glow=0.16), reveal=0.03)
    b.pop()
    # Schaufenster: Brüstung, Sohlbank, große Scheiben, Oberlicht mit kleinen Scheiben
    for lo_x, hi_x in windows:
        b.box((lo_x, 0, 0), (hi_x, sill - 0.05, 0.1), JOINERY, skip=("back",))
        b.frame(lo_x + 0.1, 0.12, hi_x - 0.1, sill - 0.17, 0.1, 0.12, 0.03, JOINERY)
        b.box((lo_x - 0.01, sill - 0.05, 0), (hi_x + 0.01, sill + 0.02, 0.16), JOINERY, skip=("back",))
        b.box((lo_x, transom, -0.03), (hi_x, transom + 0.07, jz), JOINERY)
        for xx in (lo_x, hi_x - 0.05):
            b.box((xx, sill + 0.02, -0.03), (xx + 0.05, head, jz - 0.02), JOINERY, skip=("top", "bottom"))
        gz = 0.06
        b.quad(V(lo_x, sill + 0.02, gz), V(hi_x, sill + 0.02, gz), V(hi_x, head, gz), V(lo_x, head, gz), GLASS)
        span = hi_x - lo_x
        for k in (1, 2):
            mx = lo_x + span * k / 3
            b.box((mx - 0.025, sill + 0.02, gz - 0.02), (mx + 0.025, transom, jz - 0.03), JOINERY)
        n = max(4, int(span / 0.28))
        for k in range(1, n):
            mx = lo_x + span * k / n
            b.box((mx - 0.012, transom + 0.07, gz - 0.02), (mx + 0.012, head, jz - 0.03), JOINERY)
        b.box((lo_x, transom + 0.07 + (head - transom - 0.07) / 2 - 0.01, gz - 0.02), (hi_x, transom + 0.07 + (head - transom - 0.07) / 2 + 0.01, jz - 0.03), JOINERY)
        # Auslage innen: Stufenpodest mit Eimern
        for k, (dz0, dy) in enumerate(((-0.15, 0.0), (-0.5, 0.25))):
            b.box((lo_x + 0.08, floor_y, dz0 - 0.33), (hi_x - 0.08, sill - 0.04 + dy, dz0), Mat("timber", glow=0.08))
            x = lo_x + 0.25
            while x < hi_x - 0.2:
                _bucket(b, x, dz0 - 0.16, rnd, y=sill - 0.04 + dy, height=0.24, radius=0.1, tall=k == 1, blossoms=8)
                x += rnd.uniform(0.3, 0.38)
    # Glastür in der Mitte mit Oberlicht
    x0, x1 = -door_half, door_half
    for lo, hi in ((x0 - post, x0), (x1, x1 + post)):
        b.box((lo, 0, -0.03), (hi, head, jz), JOINERY, skip=("top",))
    b.box((x0, transom, -0.03), (x1, transom + 0.07, jz), JOINERY)
    b.quad(V(x0, transom + 0.07, 0.06), V(x1, transom + 0.07, 0.06), V(x1, head, 0.06), V(x0, head, 0.06), GLASS)
    for k in range(1, 4):
        mx = x0 + (x1 - x0) * k / 4
        b.box((mx - 0.012, transom + 0.07, 0.04), (mx + 0.012, head, jz - 0.03), JOINERY)
    dz = -0.05
    fw = 0.09
    b.box((x0 - 0.02, 0, dz - 0.3), (x1 + 0.02, 0.08, 0.06), Mat("paving", color=(0.92, 0.9, 0.86)), skip=("back",))
    for lo, hi in ((x0, x0 + fw), (x1 - fw, x1)):
        b.box((lo, 0.08, dz - 0.05), (hi, transom, dz), JOINERY)
    for ya, yb in ((0.08, 0.32), (0.92, 1.0), (transom - 0.1, transom)):
        b.box((x0 + fw, ya, dz - 0.05), (x1 - fw, yb, dz), JOINERY)
    b.box((x0 + fw, 0.32, dz - 0.04), (x1 - fw, 0.92, dz - 0.01), JOINERY)
    b.quad(V(x0 + fw, 1.0, dz - 0.025), V(x1 - fw, 1.0, dz - 0.025), V(x1 - fw, transom - 0.1, dz - 0.025), V(x0 + fw, transom - 0.1, dz - 0.025), GLASS)
    b.sphere(V(x1 - fw - 0.06, 1.0, dz + 0.04), 0.03, GOLD, rings=4, segments=8)
    b.box((-0.12, 1.55, dz - 0.012), (0.12, 1.65, dz - 0.004), Mat("plain", color=(0.93, 0.9, 0.82)))
    # Im Laden: Regale mit Eimern, Theke, getrocknete Sträuße an der Decke
    for side in (-1, 1):
        sx = side * (xi - 0.2)
        for y in (0.55, 1.35):
            b.box((sx - 0.2, y - 0.03, -3.9), (sx + 0.2, y, -1.0), Mat("timber", glow=0.08))
            z = -1.25
            while z > -3.8:
                _bucket(b, sx, z, rnd, y=y, height=0.2, radius=0.08, blossoms=5)
                z -= rnd.uniform(0.45, 0.6)
    b.box((-1.0, floor_y, -4.0), (1.0, 1.0, -3.4), Mat("paint", "door", glow=0.08))
    b.box((-1.05, 1.0, -4.05), (1.05, 1.04, -3.35), Mat("timber", glow=0.1))
    _bucket(b, 0.5, -3.7, rnd, y=1.04, height=0.2, radius=0.09)
    for k in range(6):
        hx = -1.4 + k * 0.55
        b.tube([V(hx, ceil_y, -2.2), V(hx, ceil_y - 0.25, -2.2)], 0.004, Mat("plain", color=(0.6, 0.55, 0.4)), segments=3)
        b.sphere(V(hx, ceil_y - 0.4, -2.2), 0.12, Mat("plain", color=rnd.choice([(0.72, 0.56, 0.42), (0.66, 0.48, 0.5), (0.7, 0.66, 0.5)]), glow=0.08),
                 rings=4, segments=7, squash=1.5, jitter=0.2, seed=rnd.randrange(999))
    for z in (-1.4, -3.0):
        b.tube([V(0, ceil_y, z), V(0, ceil_y - 0.5, z)], 0.006, LEAD, segments=4)
        b.sphere(V(0, ceil_y - 0.62, z), 0.13, Mat("plain", color=(1.0, 0.88, 0.66), glow=1.0), rings=5, segments=10)
    # Grün über dem Schild: Polster mit Blüten, Ranken hängen herab
    x = -w + 0.2
    while x < w - 0.1:
        r = rnd.uniform(0.15, 0.22)
        b.sphere(V(x, s0 + 0.2 + r * 0.4, 0.15), r, P.leaf(rnd.randrange(3)), rings=4, segments=8, squash=0.7, jitter=0.18, seed=rnd.randrange(999))
        if rnd.random() < 0.6:
            P.blossom_cluster(b, (x, s0 + 0.2 + r * 0.45, 0.15), r, rnd.choice(["rose", "white", "lavender"]), rnd, count=8)
        x += rnd.uniform(0.3, 0.45)
    for k in range(9):
        sx = -w + 0.3 + (W - 0.6) * rnd.random()
        P.trailing_strand(b, (sx, s0 + 0.18, 0.3), rnd.uniform(0.2, 0.45), rnd, palette=rnd.choice([None, "rose", "white"]))
    # Hängekörbe an beiden Pilastern
    for side in (-1, 1):
        P.hanging_basket(b, side * (w - pil / 2), fascia_lo - 0.25, 0.15, 0.45, seed=rnd.randrange(999))


def shop_outside_flowers(b, spec, rnd):
    """Vor dem Blumenladen: links eine Blumentreppe mit Eimern, rechts ein Fahrrad mit
    Blumenkorb und ein paar Eimer, dazu die Kreidetafel (Bild "chalkboard")."""
    w = spec["width"] / 2
    # Blumentreppe (drei Stufen, Holz) links
    x0, x1 = -w + 0.75, -0.85
    for k, (zz, hh) in enumerate(((0.45, 0.25), (0.28, 0.5), (0.11, 0.75))):
        b.box((x0, 0, zz - 0.17), (x1, hh, zz + 0.17), Mat("timber"))
        x = x0 + 0.17
        while x < x1 - 0.12:
            _bucket(b, x, zz, rnd, y=hh, height=0.22, radius=0.09, tall=k == 2, blossoms=9)
            x += 0.26
    b.colliders.append(((x0, 0, -0.06), (x1, 0.9, 0.62)))
    # Rechts: Fahrrad mit Korb, davor zwei Eimer am Boden
    _bicycle(b, 1.55, 0.28, rnd)
    for xx, zz in ((0.95, 0.5), (2.25, 0.55)):
        _bucket(b, xx, zz, rnd, height=0.34, radius=0.14, tall=True)
        b.colliders.append(((xx - 0.16, 0, zz - 0.16), (xx + 0.16, 0.8, zz + 0.16)))
    P.chalkboard(b, -w + 0.38, 0.5, Mat("plain", sign="chalkboard"), facing=10)


def _bicycle(b, x, z, rnd):
    """Altes Damenrad, an die Brüstung gelehnt, mit Blumenkorb vorn."""
    frame = Mat("paint", color=(0.42, 0.55, 0.45))
    r = 0.33
    b.push(b.move(x, 0, z) @ S.Matrix.Rotation(math.radians(4), 4, "Z"))
    for cx in (-0.55, 0.55):
        ring = [V(cx + r * math.cos(a), r + r * math.sin(a), 0) for a in [2 * math.pi * k / 20 for k in range(21)]]
        b.tube(ring, 0.018, Mat("plain", color=(0.12, 0.12, 0.12)), segments=5, caps=False)
        for k in range(8):
            a = math.pi * k / 8
            b.tube([V(cx - r * 0.9 * math.cos(a), r - r * 0.9 * math.sin(a), 0), V(cx + r * 0.9 * math.cos(a), r + r * 0.9 * math.sin(a), 0)],
                   0.003, IRON, segments=3, caps=False)
    seat = V(-0.2, 0.92, 0)
    bars = V(0.45, 0.98, 0)
    crank = V(-0.05, r, 0)
    b.tube([V(-0.55, r, 0), crank, seat], 0.016, frame, segments=5)
    b.tube([crank, V(0.4, 0.78, 0), bars], 0.016, frame, segments=5)
    b.tube([V(0.55, r, 0), V(0.4, 0.78, 0)], 0.016, frame, segments=5)
    b.tube([V(-0.55, r, 0), seat], 0.014, frame, segments=5)
    b.box((-0.32, 0.92, -0.07), (-0.08, 0.97, 0.07), Mat("plain", color=(0.35, 0.22, 0.14)))
    b.tube([V(0.45, 0.98, -0.25), V(0.45, 0.98, 0.25)], 0.014, IRON, segments=5)
    # Korb mit Blumen
    b.box((0.5, 0.78, -0.17), (0.82, 0.98, 0.17), Mat("plain", color=(0.62, 0.48, 0.3)))
    b.sphere(V(0.66, 1.02, 0), 0.17, P.leaf(0), rings=4, segments=8, squash=0.8, jitter=0.2, seed=rnd.randrange(999))
    P.blossom_cluster(b, (0.66, 1.03, 0), 0.17, "rose", rnd, count=14, size=0.045)
    P.blossom_cluster(b, (0.66, 1.03, 0), 0.17, "white", rnd, count=6, size=0.045)
    b.pop()
    b.colliders.append(((x - 0.95, 0, z - 0.2), (x + 0.95, 1.1, z + 0.2)))
