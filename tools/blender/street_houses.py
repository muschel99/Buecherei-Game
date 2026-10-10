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
CLEAR = Mat("glass", glass="clear")
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


# Glatte, fein gefugte Ziegel (Bögen über Fenstern, Gesimse) – bewusst anders als die Wand
GAUGED = [Mat("terracotta", color=(0.78, 0.46, 0.36)), Mat("terracotta", color=(0.7, 0.4, 0.31))]


def wall_mat(layer):
    return Mat(WALL_LAYERS[layer], "wall")


# ---------------------------------------------------------------------------------------------
# Fenster
# ---------------------------------------------------------------------------------------------

def sash(b, x, y0, w, h, reveal, panes, frame=JOINERY, z=0.0, glass=GLASS):
    """Fensterrahmen mit Glas. panes: "sash22" (2 über 2), "sash66" (6 über 6), "topbars"
    (nur oben Sprossen), "plain" (1 über 1), "casement" (zwei Flügel, Oberlicht), "french"
    (bodentiefe Flügeltür)."""
    b.push(b.move(0, 0, z))
    x0, x1 = x - w / 2, x + w / 2
    y1 = y0 + h
    zg = -reveal + 0.03
    b.quad(V(x0, y0, zg), V(x1, y0, zg), V(x1, y1, zg), V(x0, y1, zg), glass)
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
    if kind == "none":
        # Dahinter liegt ein echter Raum (Laden): nichts zusätzlich bauen
        return
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
                floor=0, closed=False, glass=GLASS):
    """Ein komplettes Fenster: Rahmen, Glas, Dahinter, Sohlbank, Sturz, Läden.
    shutters = Platz (m) neben dem Fenster je Seite für Läden (0 = keine); closed = Läden zu."""
    frame = CREAM if spec.get("frame_cream") else JOINERY
    zg = sash(b, x, y0, w, h, reveal, panes, frame=frame, glass=glass)
    if not (closed and shutters > 0.0):
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
    # Fensterläden: am Fensterrahmen angeschlagen und leicht aufgeklappt (6–15°, je Laden
    # etwas anders) oder ganz zu. Immer beide oder keiner – nie ein einzelner Laden.
    if shutters > 0.0:
        start = 0.13 if lintel == "architrave" else 0.03
        leaves = []
        for side in (-1, 1):
            sw = w / 2 * 0.95
            angle = 180.0 - 0.5 if closed else rnd.uniform(6.0, 15.0)
            while not closed and angle < 70.0 and start + sw * math.cos(math.radians(angle)) > shutters:
                angle += 5.0
            if not closed and start + sw * math.cos(math.radians(angle)) > shutters:
                leaves = []
                break
            leaves.append((side, w / 2 + start if closed else sw, angle))
        for side, sw, angle in leaves:
            hinge = x + side * (w / 2 + start)
            b.push(b.move(hinge, 0.0, 0.03) @ b.turn_y(angle if side < 0 else -angle))
            lo_x, hi_x = sorted((0.0, side * sw))
            b.box((lo_x, y0, 0.0), (hi_x, top, 0.035), ACCENT)
            n = int(h / 0.08)
            # Lamellen auf der Seite, die zur Straße zeigt (beim geschlossenen Laden die Rückseite)
            zf = (0.035, 0.045) if not closed else (-0.01, 0.0)
            for k in range(1, n):
                yy = y0 + h * k / n
                b.box((lo_x + 0.04, yy - 0.012, zf[0]), (hi_x - 0.04, yy, zf[1]), ACCENT, skip=("front",) if closed else ("back",))
            b.pop()
            for hy in (y0 + 0.2, top - 0.2):
                b.cylinder(V(hinge, hy - 0.05, 0.04), 0.012, 0.1, IRON, segments=6, caps=(True, True))


def _lintel(b, style, x, x0, x1, top, w, spec):
    wall = wall_mat(spec["wall"])
    if style == "flat":
        b.box((x0 - 0.1, top, 0), (x1 + 0.1, top + 0.2, 0.03), TRIM, skip=("back",))
    elif style == "key":
        b.box((x0 - 0.12, top, 0), (x1 + 0.12, top + 0.2, 0.03), TRIM, skip=("back",))
        b.box((x - 0.07, top - 0.03, 0), (x + 0.07, top + 0.24, 0.06), TRIM, skip=("back",))
    elif style in ("brick_arch", "segment"):
        n = max(5, int((w + 0.2) / (0.075 if style == "brick_arch" else 0.16)))
        for k in range(n):
            t = (k + 0.5) / n
            bx = x0 - 0.1 + (w + 0.2) * t
            lift = 0.07 * math.sin(math.pi * t)
            half = (w + 0.2) / n / 2 - 0.006
            mat = GAUGED[k % 2] if style == "brick_arch" else TRIM
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
    b.face([V(w, 0, -D), V(-w, 0, -D), V(-w, E, -D), V(0, ry, -D), V(w, E, -D)], side, (0, 0, -1))


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
            b.box((-w, E - 0.3 + k * 0.08, 0), (w, E - 0.22 + k * 0.08, d), GAUGED[k % 2], skip=("back",))
        b.box((-w, E - 0.06, 0), (w, E, 0.28), JOINERY, skip=("back",))
    elif style == "modillion":
        x = -w + 0.15
        while x + 0.1 < w:
            b.box((x, E - 0.22, 0), (x + 0.07, E - 0.06, 0.2), TRIM, skip=("back",))
            x += 0.42
        b.extrude_x([(0, E - 0.08), (0, E), (0.3, E), (0.3, E - 0.06), (0.22, E - 0.08)], -w - 0.01, w + 0.01, TRIM)
        b.box((-w, E - 0.32, 0), (w, E - 0.22, 0.05), TRIM, skip=("back",))
    elif style == "gutter":
        b.box((-w, E - 0.16, 0), (w, E, 0.27), CREAM, skip=("back",))
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
        b.box((-w, y - 0.08, 0), (w, y + 0.08, 0.04), GAUGED[0], skip=("back",))


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
        SHOPFRONTS[shop][0](b, spec, rnd, ys[1])
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
                        shutters=_shutter_space(ground_open, i, w, 0.05) if spec.get("shutters") else 0.0,
                        closed=spec.get("closed_ground", False) or rnd.random() < spec.get("closed_share", 0.0))
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
                        shutters=_shutter_space(upper_open, i, w, 0.05) if spec.get("shutters") else 0.0, floor=fl,
                        closed=rnd.random() < spec.get("closed_share", 0.0))
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
        SHOPFRONTS[shop][1](b, spec, rnd)
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
    Hauskante; zwischen zwei Öffnungen die Hälfte) – so weit dürfen aufgeklappte Läden reichen."""
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
            if info and info[0] == "full" and spec.get("side_ground_window"):
                # Laden mit Raum dahinter: nur ein Fenster vorn im Erdgeschoss (mit Blick hinein)
                if fl == 0:
                    holes = []
                    for z0, wy0, z1, wy1 in side_window_holes(spec)[s]:
                        lx0, lx1 = sorted((-s * z0, -s * z1))  # lokales x = -s * Welt-z
                        holes.append((lx0, wy0, lx1, wy1))
            elif info and info[0] == "full":
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
                if spec.get("side_ground_window") and fl == 0:
                    kind = "none"
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
                      Mat("render", color=(0.86, 0.88, 0.8), glow=0.16), reveal=0.0)
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
        b.quad(V(lo_x, sill + 0.02, gz), V(hi_x, sill + 0.02, gz), V(hi_x, head, gz), V(lo_x, head, gz), CLEAR)
        span = hi_x - lo_x
        for k in (1, 2):
            mx = lo_x + span * k / 3
            b.box((mx - 0.025, sill + 0.02, gz - 0.02), (mx + 0.025, transom, jz - 0.03), JOINERY)
        n = max(4, int(span / 0.28))
        for k in range(1, n):
            mx = lo_x + span * k / n
            b.box((mx - 0.012, transom + 0.07, gz - 0.02), (mx + 0.012, head, jz - 0.03), JOINERY)
        # Auslage innen: Stufenpodest mit Eimern
        for k, (dz0, dy) in enumerate(((-0.15, 0.0), (-0.5, 0.25))):
            b.box((lo_x + 0.08, floor_y, dz0 - 0.33), (hi_x - 0.08, sill - 0.04 + dy, dz0), Mat("timber", glow=0.08))
            x = lo_x + 0.25
            while x < hi_x - 0.2:
                _bucket(b, x, dz0 - 0.16, rnd, y=sill - 0.04 + dy, height=0.24, radius=0.1, tall=k == 1, blossoms=8)
                x += rnd.uniform(0.3, 0.38)
    # Glastür in der Mitte mit Oberlicht
    x0, x1 = -door_half, door_half
    # Pfosten reichen bis hinter das Türblatt (keine Lücke, nichts liegt doppelt)
    for lo, hi in ((x0 - post, x0), (x1, x1 + post)):
        b.box((lo, 0, -0.12), (hi, head, jz), JOINERY, skip=("top",))
    b.box((x0, transom, -0.12), (x1, transom + 0.07, jz), JOINERY)
    b.quad(V(x0, transom + 0.07, 0.06), V(x1, transom + 0.07, 0.06), V(x1, head, 0.06), V(x0, head, 0.06), CLEAR)
    # Rautengitter im Oberlicht der Tür
    ty0, ty1 = transom + 0.07, head
    n = 5
    for k in range(-n, n + 1):
        a = V(x0 + (x1 - x0) * (k / n), ty0, 0.07)
        for d in (1, -1):
            c = V(a.x + d * (ty1 - ty0), ty1, 0.07)
            # nur das Stück innerhalb des Oberlichts
            pts = []
            for t in [i / 8 for i in range(9)]:
                p2 = a + (c - a) * t
                if x0 <= p2.x <= x1:
                    pts.append(p2)
            if len(pts) >= 2:
                b.tube(pts, 0.006, Mat("metal"), segments=3)
    dz = -0.05
    fw = 0.09
    b.box((x0 - 0.02, 0, dz - 0.3), (x1 + 0.02, 0.08, 0.06), Mat("paving", color=(0.92, 0.9, 0.86)), skip=("back",))
    for lo, hi in ((x0, x0 + fw), (x1 - fw, x1)):
        b.box((lo, 0.08, dz - 0.05), (hi, transom, dz), JOINERY)
    for ya, yb in ((0.08, 0.32), (0.92, 1.0), (transom - 0.1, transom)):
        b.box((x0 + fw, ya, dz - 0.05), (x1 - fw, yb, dz), JOINERY)
    b.box((x0 + fw, 0.32, dz - 0.04), (x1 - fw, 0.92, dz - 0.01), JOINERY)
    b.quad(V(x0 + fw, 1.0, dz - 0.025), V(x1 - fw, 1.0, dz - 0.025), V(x1 - fw, transom - 0.1, dz - 0.025), V(x0 + fw, transom - 0.1, dz - 0.025), CLEAR)
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
    # Mehr Blumen im Laden: Tisch mit gebundenen Sträußen in Papier, Hängepflanzen, Regal mit
    # Töpfen an der Rückwand, Kranz, Gießkanne, Eimer am Boden
    g = 0.14
    wood = Mat("timber", color=(1.1, 1.0, 0.9), glow=g * 0.6)
    b.box((-0.7, floor_y + 0.74, -3.0), (0.7, floor_y + 0.8, -2.3), wood)
    for lx in (-0.64, 0.64):
        for lz in (-2.94, -2.36):
            b.box((lx - 0.03, floor_y, lz - 0.03), (lx + 0.03, floor_y + 0.74, lz + 0.03), wood)
    for k in range(6):
        px = -0.5 + (k % 3) * 0.5
        pz = -2.85 + (k // 3) * 0.4
        b.cylinder(V(px, floor_y + 0.8, pz), 0.05, 0.18, Mat("plain", color=(0.86, 0.8, 0.68), glow=g * 0.5), segments=8, radius_top=0.12, caps=(True, False))
        b.sphere(V(px, floor_y + 1.05, pz), 0.1, P.leaf(k), rings=4, segments=8, jitter=0.15, seed=rnd.randrange(999))
        P.blossom_cluster(b, (px, floor_y + 1.07, pz), 0.1, rnd.choice(list(P.BLOSSOMS)), rnd, count=8)
    for y in (0.95, 1.5, 2.05):
        b.box((-xi + 0.3, y - 0.03, zb), (xi - 0.3, y, zb + 0.3), wood)
        x = -xi + 0.45
        while x < xi - 0.4:
            b.cylinder(V(x, y, zb + 0.15), 0.07, 0.13, POT, segments=10, radius_top=0.09)
            b.sphere(V(x, y + 0.2, zb + 0.15), 0.11, P.leaf(rnd.randrange(3)), rings=4, segments=8, jitter=0.18, seed=rnd.randrange(999))
            if rnd.random() < 0.5:
                P.blossom_cluster(b, (x, y + 0.21, zb + 0.15), 0.1, rnd.choice(["rose", "white", "lavender"]), rnd, count=6)
            x += rnd.uniform(0.28, 0.36)
    for k in range(5):
        hx = -1.6 + k * 0.8
        hz = -1.5 - (k % 2) * 0.9
        b.tube([V(hx, ceil_y, hz), V(hx, ceil_y - 0.5, hz)], 0.004, Mat("plain", color=(0.5, 0.45, 0.35)), segments=3)
        b.cylinder(V(hx, ceil_y - 0.7, hz), 0.1, 0.18, POT, segments=10, radius_top=0.13)
        b.sphere(V(hx, ceil_y - 0.48, hz), 0.15, P.leaf(k), rings=4, segments=8, jitter=0.2, seed=rnd.randrange(999))
        for q in range(4):
            P.trailing_strand(b, (hx + 0.1 * math.cos(q * 1.6), ceil_y - 0.55, hz + 0.1 * math.sin(q * 1.6)), rnd.uniform(0.3, 0.6), rnd)
    b.push(b.move(xi, 0, -2.6) @ b.turn_y(-90))
    ring = [V(0.25 * math.cos(a), 1.9 + 0.25 * math.sin(a), 0.05) for a in [2 * math.pi * k / 16 for k in range(17)]]
    b.tube(ring, 0.05, P.leaf(1), segments=6, caps=False)
    for k in range(5):
        a = 2 * math.pi * k / 5
        b.sphere(V(0.25 * math.cos(a), 1.9 + 0.25 * math.sin(a), 0.1), 0.04, Mat("plain", color=(0.86, 0.45, 0.5)), rings=3, segments=6)
    b.pop()
    b.cylinder(V(1.3, floor_y, -1.3), 0.12, 0.25, P.ZINC, segments=10, caps=(True, True))
    b.tube([V(1.42, floor_y + 0.12, -1.3), V(1.6, floor_y + 0.3, -1.3)], 0.015, P.ZINC, segments=5)
    for x, z in ((-1.4, -3.9), (-1.0, -3.95), (1.1, -3.9), (1.45, -3.85), (-1.6, -1.2)):
        _bucket(b, x, z, rnd, height=0.32, radius=0.12, tall=rnd.random() < 0.5, blossoms=8)
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
    # Hängekörbe an beiden Pilastern, Efeu rankt an den Pilastern herab
    for side in (-1, 1):
        P.hanging_basket(b, side * (w - pil / 2), fascia_lo - 0.25, 0.15, 0.45, seed=rnd.randrange(999))
        for k in range(4):
            P.trailing_strand(b, (side * (w - 0.05 - k * 0.07), s0 + 0.15, 0.2), rnd.uniform(0.6, 1.3), rnd)


def shop_outside_flowers(b, spec, rnd):
    """Vor dem Blumenladen (wie im Konzeptbild): links ein Holzregal mit Eimern und davor das
    Fahrrad mit Blumenkorb, rechts eine Blumenstufe, Eimer am Boden und die Kreidetafel (Bild
    "chalkboard"); oben Hängekörbe an beiden Ecken und ein Hängeschild (Bild "hanging")."""
    w = spec["width"] / 2
    E = spec["eaves"]
    # Links: niedriges Regal unter dem Fenster, davor das Fahrrad
    x0, x1 = -w + 0.45, -0.8
    b.box((x0, 0.0, 0.05), (x1, 0.45, 0.42), Mat("timber"))
    x = x0 + 0.17
    while x < x1 - 0.1:
        _bucket(b, x, 0.24, rnd, y=0.45, height=0.22, radius=0.1, blossoms=9)
        x += 0.27
    b.colliders.append(((x0, 0, 0.05), (x1, 0.9, 0.42)))
    _bicycle(b, (x0 + x1) / 2 - 0.05, 0.62, rnd)
    for xx in (x0 + 0.05, x1 + 0.02):
        _bucket(b, xx, 0.28, rnd, height=0.34, radius=0.13, tall=True, blossoms=10)
    # Rechts: Blumenstufe (drei Stufen) und Eimer am Boden
    x0, x1 = 0.8, w - 0.5
    for k, (zz, hh) in enumerate(((0.47, 0.25), (0.3, 0.5), (0.13, 0.75))):
        b.box((x0, 0, zz - 0.17), (x1, hh, zz + 0.17), Mat("timber"))
        x = x0 + 0.17
        while x < x1 - 0.12:
            _bucket(b, x, zz, rnd, y=hh, height=0.22, radius=0.09, tall=k == 2, blossoms=9)
            x += 0.26
    b.colliders.append(((x0, 0, -0.06), (x1, 0.9, 0.64)))
    _bucket(b, x0 - 0.18, 0.62, rnd, height=0.34, radius=0.14, tall=True, blossoms=10)
    b.colliders.append(((x0 - 0.34, 0, 0.46), (x0 - 0.02, 0.8, 0.78)))
    P.chalkboard(b, w - 0.3, 0.72, Mat("plain", sign="chalkboard"), facing=-12)
    # Oben: Hängekörbe an den Ecken und das grüne Hängeschild
    for side in (-1, 1):
        P.hanging_basket(b, side * (w - 0.35), E - 0.45, 0.04, 0.5, seed=rnd.randrange(999))
    P.projecting_sign(b, 0.15, E - 0.75, 0.0, Mat("paint", "door"), Mat("plain", sign="hanging"))


def _bicycle(b, x, z, rnd):
    """Altes Damenrad, an die Brüstung gelehnt, mit Blumenkorb vorn."""
    frame = Mat("paint", color=(0.42, 0.55, 0.45))
    r = 0.33
    b.push(b.move(x, 0.0, z))
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


# ---------------------------------------------------------------------------------------------
# Pub (Inspiration "Westminster Arms"): dunkelgrüne Holzfront, große Sprossenfenster mit
# geätztem Glas unten, Doppeltür, Laternen, Hängekörbe; innen Tresen mit Flaschen
# ---------------------------------------------------------------------------------------------

def _room_side_wall(b, s, xi, zb, zf, y0, y1, mat, holes_z):
    """Seitenwand eines Ladenraums bei x = s * xi (zeigt in den Raum), mit Öffnungen
    holes_z = [(z0, y0, z1, y1)] in Weltkoordinaten (für Seitenfenster)."""
    b.push(b.move(s * xi, 0, 0) @ b.turn_y(-90 * s))
    lo, hi = sorted((zb * s, zf * s))
    holes = []
    for hz0, hy0, hz1, hy1 in holes_z:
        lx0, lx1 = sorted((hz0 * s, hz1 * s))  # lokales x = s * Welt-z
        holes.append((lx0, hy0, lx1, hy1))
    b.wall_with_holes(lo, hi, y0, y1, 0.0, holes, mat, reveal=0.0)
    b.pop()


def side_window_holes(spec):
    """Seitenfenster im Erdgeschoss (Weltkoordinaten z0, y0, z1, y1) je Seite – dieselben wie in
    _side_walls, damit Innenwand und Außenwand zusammenpassen."""
    out = {}
    for s, info in spec.get("exposed", {}).items():
        if info[0] != "full" or not spec.get("side_ground_window"):
            continue
        wy0 = 0.85
        wh = min(1.6, spec["storeys"][0] - 1.35)
        out[s] = [(-1.6 - 0.45, wy0, -1.6 + 0.45, wy0 + wh)]
    return out


def shopfront_pub(b, spec, rnd, s0):
    """Pub wie im Inspirationsbild (unten, 2. von links): fast schwarze Holzfront, viel Efeu
    über dem Schild, kleines Holzschild mittig (Bild "fascia"), rundes Hängeschild, große
    klare Fenster, Menütafel im Fenster. Innen eine dunkle, gemütliche Gaststube: Tresen mit
    Spiegel und Flaschen, Zinnkrüge, Kamin, Sitznischen mit grünem Leder, Bilder, Kerzen."""
    W = spec["width"]
    w = W / 2
    pil = 0.3
    fascia_lo, fascia_hi = s0 - 0.6, s0 - 0.02
    head = fascia_lo - 0.08
    door_half = 0.55
    post = 0.1
    sill = 0.62
    jz = 0.13
    transom = head - 0.42
    dz = -0.3
    for side in (-1, 1):
        lo_x, hi_x = sorted((side * w, side * (w - pil)))
        b.box((lo_x, 0, 0), (hi_x, fascia_hi, 0.16), JOINERY, skip=("back",))
        b.box((lo_x - 0.02, 0, 0), (hi_x + 0.02, 0.3, 0.19), JOINERY, skip=("back", "bottom"))
        b.box((lo_x - 0.03, fascia_lo - 0.18, 0), (hi_x + 0.03, fascia_hi + 0.04, 0.21), JOINERY, skip=("back",))
    b.box((-w + pil, fascia_lo, 0), (w - pil, fascia_hi, 0.18), JOINERY, skip=("back", "front"))
    b.poly([V(-w + pil, fascia_lo, 0.18), V(w - pil, fascia_lo, 0.18), V(w - pil, fascia_hi, 0.18), V(-w + pil, fascia_hi, 0.18)],
           Mat("plain", sign="fascia"), uvs=[(0, 0), (1, 0), (1, 1), (0, 1)])
    b.extrude_x([(0, fascia_hi), (0, s0 + 0.12), (0.3, s0 + 0.12), (0.3, fascia_hi + 0.08), (0.2, fascia_hi)],
                -w - 0.03, w + 0.03, JOINERY)
    b.box((-w + pil, head, 0), (w - pil, fascia_lo, jz), JOINERY, skip=("back",))

    # --- Gaststube (dunkel und warm) ---
    xi = w - 0.13
    floor_y, ceil_y, zb, zf = 0.1, s0 - 0.3, -5.2, -0.03
    g = 0.07
    panel = Mat("paint", color=(0.14, 0.2, 0.16), glow=g)
    paper = Mat("fabric", color=(0.42, 0.14, 0.14), glow=g)
    wood = Mat("timber", color=(0.8, 0.7, 0.62), glow=g)
    mahogany = Mat("timber", color=(0.7, 0.42, 0.32), glow=g + 0.02)
    brass = Mat("gold", glow=0.08)
    leather = Mat("fabric", color=(0.2, 0.32, 0.24), glow=g)
    b.face([V(-xi, floor_y, zf), V(xi, floor_y, zf), V(xi, floor_y, zb), V(-xi, floor_y, zb)],
           Mat("boards", color=(0.4, 0.27, 0.18), glow=0.06), (0, 1, 0))
    b.face([V(-xi, ceil_y, zf), V(xi, ceil_y, zf), V(xi, ceil_y, zb), V(-xi, ceil_y, zb)], Mat("plain", color=(0.5, 0.4, 0.3), glow=0.08), (0, -1, 0))
    b.face([V(-xi, floor_y, zb), V(xi, floor_y, zb), V(xi, ceil_y, zb), V(-xi, ceil_y, zb)], paper, (0, 0, 1))
    side_holes = side_window_holes(spec)
    for s in (-1, 1):
        _room_side_wall(b, s, xi, zb, zf, floor_y, ceil_y, paper, side_holes.get(s, []))
    windows = []
    for side in (-1, 1):
        lo_x, hi_x = sorted((side * (w - pil), side * (door_half + post)))
        windows.append((lo_x, hi_x))
    holes = [(lo, sill, hi, head) for lo, hi in windows] + [(-door_half - post, floor_y, door_half + post, head)]
    b.push(b.move(0, 0, zf) @ b.turn_y(180))
    b.wall_with_holes(-xi, xi, floor_y, ceil_y, 0.0, [(-h[2], h[1], -h[0], h[3]) for h in holes], paper, reveal=0.0)
    b.pop()
    # Vertäfelung bis Brusthöhe rundherum (mit Lücken für die Seitenfenster), Bilderleiste
    for s in (-1, 1):
        zs = sorted([zb + 0.02, zf - 0.02] + [v for hz0, _, hz1, _ in side_holes.get(s, []) for v in (hz0, hz1)])
        for k in range(0, len(zs) - 1, 2):
            a0, a1 = zs[k], zs[k + 1]
            lo2, hi2 = sorted((s * xi, s * (xi - 0.03)))
            b.box((lo2, floor_y, a0), (hi2, 1.2, a1), panel)
            b.box((lo2 - 0.005, 1.2, a0), (hi2 + 0.005, 1.25, a1), wood)
            b.box((lo2, 2.35, a0), (hi2, 2.38, a1), brass)
    b.box((-xi, floor_y, zb), (xi, 1.2, zb + 0.03), panel)
    for z in (-0.9, -1.9, -2.9, -3.9):
        b.box((-xi, ceil_y - 0.2, z - 0.11), (xi, ceil_y, z + 0.11), Mat("timber", color=(0.45, 0.35, 0.28), glow=0.05))
    # Tresen hinten mit Messing-Fußleiste, Hockern, Zapfhähnen
    bz0, bz1 = -3.9, -3.35
    b.box((-1.7, floor_y, bz0), (1.7, 1.05, bz1), mahogany)
    for k in range(6):
        px = -1.55 + k * 0.62
        b.frame(px, 0.3, px + 0.42, 0.85, bz1, bz1 + 0.012, 0.03, mahogany)
    b.box((-1.78, 1.05, bz0 - 0.03), (1.78, 1.11, bz1 + 0.06), Mat("timber", color=(0.5, 0.3, 0.22), glow=0.1))
    b.tube([V(-1.7, 0.22, bz1 + 0.12), V(1.7, 0.22, bz1 + 0.12)], 0.018, brass, segments=6)
    for k in range(4):
        tx = -0.75 + k * 0.5
        b.cylinder(V(tx, 1.11, -3.55), 0.03, 0.06, brass, segments=8)
        b.cylinder(V(tx, 1.17, -3.55), 0.014, 0.3, brass, segments=6)
        b.cylinder(V(tx, 1.47, -3.55), 0.03, 0.14, Mat("paint", color=(0.12, 0.1, 0.08), glow=0.05), segments=8, caps=(True, True))
    for k in range(4):
        sx = -1.3 + k * 0.85
        b.cylinder(V(sx, floor_y, bz1 + 0.45), 0.02, 0.72, Mat("timber", glow=0.05), segments=6)
        b.cylinder(V(sx, floor_y + 0.72, bz1 + 0.45), 0.17, 0.06, leather, segments=12, caps=(True, True))
    # Rückbuffet: Spiegel mit Goldrahmen, Regale mit leuchtenden Flaschen, Zinnkrüge an der Decke
    b.box((-1.9, 1.3, zb + 0.01), (1.9, 2.7, zb + 0.06), Mat("timber", color=(0.6, 0.38, 0.28), glow=g))
    b.box((-0.7, 1.45, zb + 0.06), (0.7, 2.5, zb + 0.07), Mat("plain", color=(0.55, 0.5, 0.42), glow=0.18))
    b.frame(-0.7, 1.45, 0.7, 2.5, zb + 0.06, zb + 0.09, 0.06, brass)
    for side in (-1, 1):
        for y in (1.5, 1.9, 2.3):
            x0s, x1s = sorted((side * 0.8, side * 1.85))
            b.box((x0s, y - 0.025, zb + 0.06), (x1s, y, zb + 0.28), wood)
            x = x0s + 0.06
            while x < x1s - 0.05:
                c = rnd.choice([(0.2, 0.45, 0.2), (0.55, 0.22, 0.1), (0.8, 0.62, 0.25), (0.3, 0.3, 0.5), (0.7, 0.7, 0.62)])
                hgt = rnd.uniform(0.22, 0.3)
                b.cylinder(V(x, y, zb + 0.16), 0.035, hgt * 0.65, Mat("plain", color=c, glow=0.35), segments=7, caps=(True, False))
                b.cylinder(V(x, y + hgt * 0.65, zb + 0.16), 0.035, hgt * 0.35, Mat("plain", color=c, glow=0.35), segments=7, radius_top=0.012)
                x += rnd.uniform(0.085, 0.12)
    b.box((-1.7, ceil_y - 0.32, bz0 - 0.05), (1.7, ceil_y - 0.26, bz0 + 0.05), wood)
    for k in range(9):
        mx = -1.6 + k * 0.4
        b.tube([V(mx, ceil_y - 0.32, bz0), V(mx, ceil_y - 0.42, bz0)], 0.006, brass, segments=3)
        b.cylinder(V(mx, ceil_y - 0.62, bz0), 0.055, 0.2, Mat("metal", color=(0.7, 0.7, 0.72), glow=0.08), segments=8, caps=(True, True))
    # Kamin an der rechten Wand mit Feuer, Kaminsims, Bild darüber
    fz = -2.4
    b.push(b.move(xi, 0, fz) @ b.turn_y(-90))
    stone = Mat("stone", color=(0.6, 0.56, 0.5), glow=0.06)
    b.box((-0.75, floor_y, 0.0), (0.75, 1.25, 0.35), stone)
    b.box((-0.85, 1.25, 0.0), (0.85, 1.33, 0.42), wood)
    b.box((-0.45, floor_y, 0.35), (0.45, 0.85, 0.351), Mat("plain", color=(0.06, 0.04, 0.03)))
    b.sphere(V(0, floor_y + 0.18, 0.3), 0.22, Mat("plain", color=(1.0, 0.55, 0.15), glow=1.0), rings=4, segments=8, squash=0.8, jitter=0.25, seed=3)
    for k in range(3):
        b.cylinder(V(-0.2 + k * 0.2, floor_y, 0.3), 0.05, 0.06, Mat("timber", color=(0.4, 0.3, 0.2)), segments=6, axis="x")
    b.box((-0.6, 0.0, 0.35), (0.6, floor_y + 0.02, 0.8), stone)
    for k in (-0.6, 0.6):
        b.cylinder(V(k, 1.33, 0.2), 0.035, 0.18, Mat("plain", color=(0.95, 0.92, 0.84)), segments=8)
        b.sphere(V(k, 1.54, 0.2), 0.025, Mat("plain", color=(1.0, 0.8, 0.4), glow=1.0), rings=3, segments=6)
    b.box((-0.45, 1.6, 0.0), (0.45, 2.25, 0.04), brass)
    b.box((-0.4, 1.65, 0.04), (0.4, 2.2, 0.045), Mat("plain", color=(0.35, 0.42, 0.32), glow=0.1))
    b.pop()
    # Sitznische links: zwei hohe Bänke mit grünem Leder, Tisch mit Kerzenlaterne
    nz = -2.3
    b.push(b.move(-xi, 0, nz) @ b.turn_y(90))
    for bx, flip in ((-0.75, 1), (0.75, -1)):
        b.box((bx - 0.25, floor_y, 0.0), (bx + 0.25, floor_y + 0.45, 0.9), mahogany)
        b.box((bx - 0.24, floor_y + 0.45, 0.02), (bx + 0.24, floor_y + 0.52, 0.88), leather)
        back = bx - flip * 0.2
        b.box((min(back, back - flip * 0.08), floor_y, 0.0), (max(back, back - flip * 0.08), floor_y + 1.35, 0.9), mahogany)
        b.box((min(back, back + flip * 0.06), floor_y + 0.55, 0.05), (max(back, back + flip * 0.06), floor_y + 1.2, 0.85), leather)
    b.box((-0.35, floor_y + 0.72, 0.1), (0.35, floor_y + 0.76, 0.85), wood)
    b.box((-0.05, floor_y, 0.42), (0.05, floor_y + 0.72, 0.52), wood)
    b.box((-0.05, floor_y + 0.76, 0.42), (0.05, floor_y + 0.92, 0.52), Mat("plain", color=(1.0, 0.82, 0.5), glow=0.9))
    b.box((-0.06, floor_y + 0.92, 0.41), (0.06, floor_y + 0.95, 0.53), Mat("metal"))
    b.box((-0.55, 1.55, 0.0), (0.55, 2.15, 0.035), brass)
    b.box((-0.5, 1.6, 0.035), (0.5, 2.1, 0.04), Mat("plain", color=(0.62, 0.52, 0.36), glow=0.1))
    b.pop()
    # Runde Tische in der Mitte mit Kerzen, Teppich, Lampen mit warmem Licht
    b.box((-0.9, floor_y, -2.9), (0.9, floor_y + 0.006, -1.5), Mat("fabric", color=(0.45, 0.16, 0.14), glow=0.05))
    for tx, tz in ((-0.35, -1.25), (0.55, -2.35)):
        b.cylinder(V(tx, floor_y + 0.74, tz), 0.32, 0.04, wood, segments=14, caps=(True, True))
        b.cylinder(V(tx, floor_y, tz), 0.04, 0.74, Mat("metal"), segments=6)
        b.cylinder(V(tx, floor_y + 0.78, tz), 0.03, 0.08, Mat("plain", color=(0.95, 0.92, 0.84)), segments=8)
        b.sphere(V(tx, floor_y + 0.9, tz), 0.02, Mat("plain", color=(1.0, 0.8, 0.4), glow=1.0), rings=3, segments=6)
        for k in range(2):
            a = math.pi * k + 0.6
            b.cylinder(V(tx + 0.5 * math.cos(a), floor_y, tz + 0.5 * math.sin(a)), 0.16, 0.46, leather, segments=10, caps=(False, True))
    for x, z in ((-1.0, -1.4), (0.6, -1.4), (0.0, -3.0)):
        b.tube([V(x, ceil_y, z), V(x, ceil_y - 0.55, z)], 0.006, LEAD, segments=4)
        b.cylinder(V(x, ceil_y - 0.75, z), 0.15, 0.2, brass, segments=10, radius_top=0.05, caps=(True, False))
        b.sphere(V(x, ceil_y - 0.75, z), 0.06, Mat("plain", color=(1.0, 0.78, 0.45), glow=1.0), rings=3, segments=8)

    # --- Fenster: große klare Scheiben, oben kleine Scheiben ---
    for k, (lo_x, hi_x) in enumerate(windows):
        b.box((lo_x, 0, 0), (hi_x, sill - 0.05, 0.11), JOINERY, skip=("back",))
        b.frame(lo_x + 0.1, 0.12, hi_x - 0.1, sill - 0.17, 0.11, 0.13, 0.03, JOINERY)
        b.box((lo_x - 0.01, sill - 0.05, 0), (hi_x + 0.01, sill + 0.02, 0.17), JOINERY, skip=("back",))
        b.box((lo_x, floor_y, zf - 0.02), (hi_x, sill + 0.02, zf), panel)
        for xx in (lo_x, hi_x - 0.06):
            b.box((xx, sill + 0.02, zf - 0.02), (xx + 0.06, head, jz - 0.02), JOINERY, skip=("top", "bottom"))
        gz = 0.06
        b.quad(V(lo_x, sill + 0.02, gz), V(hi_x, sill + 0.02, gz), V(hi_x, head, gz), V(lo_x, head, gz), CLEAR)
        b.box((lo_x, transom - 0.03, gz - 0.02), (hi_x, transom + 0.03, jz - 0.03), JOINERY)
        b.glazing_bars(lo_x + 0.06, transom + 0.03, hi_x - 0.06, head, gz - 0.02, jz - 0.04, 4, 1, 0.022, JOINERY)
        mid = (lo_x + hi_x) / 2
        b.box((mid - 0.025, sill + 0.02, gz - 0.02), (mid + 0.025, transom, jz - 0.03), JOINERY)
        b.box((lo_x, sill - 0.02, zf - 0.25), (hi_x, sill + 0.02, zf), wood)
        if k == 0:
            b.box((lo_x + 0.2, sill + 0.05, -0.25), (lo_x + 0.75, sill + 0.95, -0.22), Mat("timber", glow=0.1))
            b.box((lo_x + 0.24, sill + 0.09, -0.22), (lo_x + 0.71, sill + 0.91, -0.215), Mat("plain", color=(0.13, 0.14, 0.13), glow=0.05))
            for r in range(5):
                yy = sill + 0.75 - r * 0.13
                b.box((lo_x + 0.3, yy, -0.215), (lo_x + 0.3 + rnd.uniform(0.2, 0.36), yy + 0.02, -0.212), Mat("plain", color=(0.9, 0.9, 0.86), glow=0.2))
        else:
            b.cylinder(V(mid, sill + 0.02, -0.15), 0.1, 0.18, POT, segments=10, radius_top=0.12)
            b.sphere(V(mid, sill + 0.38, -0.15), 0.2, P.leaf(1), rings=5, segments=10, jitter=0.18, seed=rnd.randrange(99))
    # --- Tür in tiefer Nische: Laibung und Decke als feste Blöcke (kein Durchblick) ---
    x0, x1 = -door_half, door_half
    for lo, hi in ((x0 - post, x0), (x1, x1 + post)):
        b.box((lo, 0, dz - 0.06), (hi, head, jz), JOINERY, skip=("top",))
    b.box((x0, transom, dz - 0.06), (x1, transom + 0.07, jz), JOINERY)
    b.quad(V(x0, transom + 0.07, 0.06), V(x1, transom + 0.07, 0.06), V(x1, head, 0.06), V(x0, head, 0.06), CLEAR)
    b.glazing_bars(x0, transom + 0.07, x1, head, 0.04, jz - 0.03, 3, 1, 0.022, JOINERY)
    b.box((x0, transom + 0.07, dz - 0.06), (x1, head, 0.03), Mat("plain", color=(0.4, 0.3, 0.2), glow=0.1), skip=("front",))
    b.box((x0 - 0.02, 0, dz - 0.05), (x1 + 0.02, 0.08, 0.06), Mat("paving", color=(0.6, 0.58, 0.55)), skip=("back",))
    f = 0.09
    b.box((x0, 0.08, dz - 0.05), (x1, 0.9, dz), JOINERY)
    b.box((x0, transom - 0.1, dz - 0.05), (x1, transom, dz), JOINERY)
    b.box((x0, 0.9, dz - 0.05), (x0 + f, transom - 0.1, dz), JOINERY)
    b.box((x1 - f, 0.9, dz - 0.05), (x1, transom - 0.1, dz), JOINERY)
    b.quad(V(x0 + f, 0.9, dz - 0.025), V(x1 - f, 0.9, dz - 0.025), V(x1 - f, transom - 0.1, dz - 0.025), V(x0 + f, transom - 0.1, dz - 0.025), CLEAR)
    b.glazing_bars(x0 + f, 0.9, x1 - f, transom - 0.1, dz - 0.04, dz - 0.02, 2, 3, 0.02, JOINERY)
    b.sphere(V(x1 - f - 0.05, 1.0, dz + 0.04), 0.03, GOLD, rings=4, segments=8)
    # Efeu über dem Schild, Ranken an den Seiten
    x = -w
    while x < w:
        r = rnd.uniform(0.2, 0.3)
        b.sphere(V(x, s0 + 0.25, 0.18), r, P.leaf(rnd.randrange(3)), rings=4, segments=8, squash=0.8, jitter=0.2, seed=rnd.randrange(999))
        x += rnd.uniform(0.25, 0.35)
    for k in range(18):
        sx = -w + 0.1 + (W - 0.2) * rnd.random()
        P.trailing_strand(b, (sx, s0 + 0.15, 0.32), rnd.uniform(0.4, 1.1) if abs(sx) > 0.9 else rnd.uniform(0.15, 0.35), rnd)
    for side in (-1, 1):
        for k in range(6):
            P.trailing_strand(b, (side * (w - 0.05 - k * 0.05), s0 + 0.2, 0.22), rnd.uniform(1.2, 2.4), rnd)
    P.projecting_sign(b, w - 0.15, s0 + 0.95, 0.0, JOINERY, Mat("plain", sign="hanging"), round_=True)


def pub_outside(b, spec, rnd):
    """Vor dem Pub: Bistrotisch mit zwei Stühlen, Töpfe mit Grün, Kreidetafel."""
    w = spec["width"] / 2
    dark = Mat("paint", "door")
    tx, tz = w - 0.75, 0.62
    b.cylinder(V(tx, 0.74, tz), 0.3, 0.03, dark, segments=16, caps=(True, True))
    b.cylinder(V(tx, 0.04, tz), 0.03, 0.7, IRON, segments=6)
    b.cylinder(V(tx, 0.0, tz), 0.2, 0.04, IRON, segments=12, caps=(True, True))
    for cx in (tx - 0.52, tx + 0.52):
        b.box((cx - 0.19, 0.44, tz - 0.19), (cx + 0.19, 0.48, tz + 0.19), Mat("timber"))
        for dx in (-0.16, 0.16):
            for dz2 in (-0.16, 0.16):
                b.box((cx + dx - 0.015, 0, tz + dz2 - 0.015), (cx + dx + 0.015, 0.44, tz + dz2 + 0.015), IRON)
        back = cx + (0.18 if cx > tx else -0.18)
        b.box((back - 0.015, 0.48, tz - 0.19), (back + 0.015, 0.9, tz + 0.19), Mat("timber"))
    b.colliders.append(((tx - 0.75, 0, tz - 0.32), (tx + 0.75, 0.9, tz + 0.32)))
    P.chalkboard(b, -w + 0.55, 0.5, Mat("plain", sign="chalkboard"), facing=8)
    for x in (-0.95, 0.95):
        b.cylinder(V(x, 0, 0.32), 0.17, 0.42, POT, segments=12, radius_top=0.2, caps=(False, True))
        b.sphere(V(x, 0.7, 0.32), 0.27, P.leaf(rnd.randrange(3)), rings=5, segments=10, squash=1.2, jitter=0.18, seed=rnd.randrange(99))
        b.colliders.append(((x - 0.22, 0, 0.1), (x + 0.22, 0.9, 0.54)))


def shop_shell(b, spec, rnd, s0, wall_color, floor_mat, glow=0.16, door_half=0.5):
    """Gemeinsame Ladenfront: Pilaster, Schild (Bild "fascia"), Gesims, zwei Schaufenster mit
    klarem Glas und kleinen Scheiben oben, Glastür mit festen Pfosten (kein Durchblick), Raum
    dahinter mit Seitenwänden. Gibt die Maße zurück (für Einrichtung und Deko)."""
    W = spec["width"]
    w = W / 2
    pil = 0.28
    fascia_lo, fascia_hi = s0 - 0.45, s0 - 0.02
    head = fascia_lo - 0.1
    post = 0.09
    sill = 0.58
    jz = 0.13
    transom = head - 0.42
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
    xi = w - 0.13
    floor_y, ceil_y, zb, zf = 0.1, s0 - 0.25, -4.6, -0.03
    wall = Mat("render", color=wall_color, glow=glow)
    b.face([V(-xi, floor_y, zf), V(xi, floor_y, zf), V(xi, floor_y, zb), V(-xi, floor_y, zb)], floor_mat, (0, 1, 0))
    b.face([V(-xi, ceil_y, zf), V(xi, ceil_y, zf), V(xi, ceil_y, zb), V(-xi, ceil_y, zb)], Mat("plain", color=(0.92, 0.9, 0.84), glow=glow), (0, -1, 0))
    b.face([V(-xi, floor_y, zb), V(xi, floor_y, zb), V(xi, ceil_y, zb), V(-xi, ceil_y, zb)], wall, (0, 0, 1))
    side_holes = side_window_holes(spec)
    for s in (-1, 1):
        _room_side_wall(b, s, xi, zb, zf, floor_y, ceil_y, wall, side_holes.get(s, []))
    windows = []
    for side in (-1, 1):
        lo_x, hi_x = sorted((side * (w - pil), side * (door_half + post)))
        windows.append((lo_x, hi_x))
    holes = [(lo, sill, hi, head) for lo, hi in windows] + [(-door_half - post, floor_y, door_half + post, head)]
    b.push(b.move(0, 0, zf) @ b.turn_y(180))
    b.wall_with_holes(-xi, xi, floor_y, ceil_y, 0.0, [(-h[2], h[1], -h[0], h[3]) for h in holes], wall, reveal=0.0)
    b.pop()
    for lo_x, hi_x in windows:
        b.box((lo_x, 0, 0), (hi_x, sill - 0.05, 0.1), JOINERY, skip=("back",))
        b.frame(lo_x + 0.09, 0.12, hi_x - 0.09, sill - 0.16, 0.1, 0.12, 0.03, JOINERY)
        b.box((lo_x - 0.01, sill - 0.05, 0), (hi_x + 0.01, sill + 0.02, 0.16), JOINERY, skip=("back",))
        b.box((lo_x, floor_y, zf - 0.02), (hi_x, sill + 0.02, zf), JOINERY)
        b.box((lo_x, sill - 0.02, zf - 0.3), (hi_x, sill + 0.02, zf), Mat("timber", glow=glow * 0.6))
        for xx in (lo_x, hi_x - 0.05):
            b.box((xx, sill + 0.02, zf - 0.02), (xx + 0.05, head, jz - 0.02), JOINERY, skip=("top", "bottom"))
        gz = 0.06
        b.quad(V(lo_x, sill + 0.02, gz), V(hi_x, sill + 0.02, gz), V(hi_x, head, gz), V(lo_x, head, gz), CLEAR)
        b.box((lo_x, transom - 0.03, gz - 0.02), (hi_x, transom + 0.03, jz - 0.03), JOINERY)
        n = max(3, int((hi_x - lo_x) / 0.3))
        b.glazing_bars(lo_x + 0.05, transom + 0.03, hi_x - 0.05, head, gz - 0.02, jz - 0.04, n, 1, 0.022, JOINERY)
        mid = (lo_x + hi_x) / 2
        b.box((mid - 0.022, sill + 0.02, gz - 0.02), (mid + 0.022, transom, jz - 0.03), JOINERY)
    # Glastür
    x0, x1 = -door_half, door_half
    dz = -0.06
    for lo, hi in ((x0 - post, x0), (x1, x1 + post)):
        b.box((lo, 0, dz - 0.08), (hi, head, jz), JOINERY, skip=("top",))
    b.box((x0, transom, dz - 0.08), (x1, transom + 0.07, jz), JOINERY)
    b.quad(V(x0, transom + 0.07, 0.06), V(x1, transom + 0.07, 0.06), V(x1, head, 0.06), V(x0, head, 0.06), CLEAR)
    b.glazing_bars(x0, transom + 0.07, x1, head, 0.04, jz - 0.03, 3, 1, 0.022, JOINERY)
    b.box((x0 - 0.02, 0, dz - 0.3), (x1 + 0.02, 0.08, 0.06), Mat("paving", color=(0.92, 0.9, 0.86)), skip=("back",))
    fw = 0.09
    for lo, hi in ((x0, x0 + fw), (x1 - fw, x1)):
        b.box((lo, 0.08, dz - 0.05), (hi, transom, dz), JOINERY)
    for ya, yb in ((0.08, 0.32), (0.92, 1.0), (transom - 0.1, transom)):
        b.box((x0 + fw, ya, dz - 0.05), (x1 - fw, yb, dz), JOINERY)
    b.box((x0 + fw, 0.32, dz - 0.04), (x1 - fw, 0.92, dz - 0.01), JOINERY)
    b.quad(V(x0 + fw, 1.0, dz - 0.025), V(x1 - fw, 1.0, dz - 0.025), V(x1 - fw, transom - 0.1, dz - 0.025), V(x0 + fw, transom - 0.1, dz - 0.025), CLEAR)
    b.sphere(V(x1 - fw - 0.06, 1.0, dz + 0.04), 0.03, GOLD, rings=4, segments=8)
    return {"w": w, "xi": xi, "floor_y": floor_y, "ceil_y": ceil_y, "zb": zb, "zf": zf, "windows": windows, "sill": sill,
            "head": head, "fascia_lo": fascia_lo, "pil": pil, "glow": glow}


YARN = [(0.86, 0.6, 0.58), (0.92, 0.82, 0.62), (0.62, 0.72, 0.62), (0.58, 0.66, 0.78), (0.74, 0.58, 0.72), (0.9, 0.88, 0.82),
        (0.78, 0.46, 0.36), (0.42, 0.52, 0.48), (0.8, 0.68, 0.5), (0.52, 0.46, 0.6), (0.66, 0.3, 0.32), (0.86, 0.76, 0.7)]


def _yarn(b, x, y, z, r, color, glow, rnd):
    """Wollknäuel: leicht flache Kugel mit ein paar Fadenringen."""
    m = Mat("fabric", color=color, glow=glow)
    b.sphere(V(x, y + r * 0.9, z), r, m, rings=5, segments=9, squash=0.9, jitter=0.05, seed=rnd.randrange(999))
    ring = [V(x + r * 1.01 * math.cos(a), y + r * 0.9 + r * 0.5 * math.sin(a), z + r * 0.6 * math.sin(a)) for a in [2 * math.pi * k / 10 for k in range(11)]]
    b.tube(ring, 0.004, m, segments=3, caps=False)


def shopfront_wool(b, spec, rnd, s0):
    """Wolle- und Stoffladen (Inspiration "Wolleshop"): taubenblaue Front, innen Fächerregale
    voller Wollknäuel, Körbe, ein Tisch mit Stoffballen, hängende Stofftaschen, ein Sessel
    mit Strickdecke, warme Hängelampen."""
    m = shop_shell(b, spec, rnd, s0, (0.92, 0.88, 0.8), Mat("boards", color=(0.72, 0.58, 0.42), glow=0.1))
    xi, fy, cy, zb, g = m["xi"], m["floor_y"], m["ceil_y"], m["zb"], m["glow"]
    wood = Mat("timber", color=(1.15, 1.05, 0.95), glow=g * 0.7)
    # Rückwand: Fächerregal bis unter die Decke
    cols, rows = 7, 5
    rw = 2 * xi - 0.2
    for r in range(rows + 1):
        y = fy + 0.15 + (cy - fy - 0.35) * r / rows
        b.box((-xi + 0.1, y, zb), (xi - 0.1, y + 0.025, zb + 0.38), wood)
    for c in range(cols + 1):
        x = -xi + 0.1 + rw * c / cols
        b.box((x - 0.012, fy + 0.15, zb), (x + 0.012, cy - 0.2, zb + 0.38), wood)
    for r in range(rows):
        y = fy + 0.15 + (cy - fy - 0.35) * r / rows + 0.025
        for c in range(cols):
            x = -xi + 0.1 + rw * (c + 0.5) / cols
            color = YARN[(r * 3 + c * 5) % len(YARN)]
            for k in range(3):
                _yarn(b, x - 0.09 + k * 0.09, y, zb + 0.2 + (k % 2) * 0.06, 0.05, color, g * 0.6, rnd)
    # Seitenwände: Stoffballen stehend und Wandhaken mit Taschen
    for s in (-1, 1):
        x = s * (xi - 0.2)
        b.box((x - 0.18, fy, -3.9), (x + 0.18, fy + 0.6, -1.3), wood)
        z = -1.45
        while z > -3.8:
            c = rnd.choice(YARN)
            b.cylinder(V(x, fy + 0.6, z), 0.07, 0.75, Mat("fabric", color=c, glow=g * 0.6), segments=8, caps=(True, True))
            z -= 0.17
        for k in range(3):
            hz = -1.8 - k * 0.7
            b.tube([V(s * xi, 2.15, hz), V(s * (xi - 0.12), 2.15, hz)], 0.008, Mat("timber"), segments=4)
            b.box((s * (xi - 0.03) - 0.02, 1.45, hz - 0.2), (s * (xi - 0.03) + 0.02, 2.1, hz + 0.2), Mat("fabric", color=(0.9, 0.86, 0.76), glow=g * 0.6))
    # Tisch in der Mitte mit gefalteten Stoffen, Körbe mit Wolle am Boden
    b.box((-0.75, fy + 0.74, -2.9), (0.75, fy + 0.8, -2.0), wood)
    for lx in (-0.68, 0.68):
        for lz in (-2.83, -2.07):
            b.box((lx - 0.03, fy, lz - 0.03), (lx + 0.03, fy + 0.74, lz + 0.03), wood)
    y = fy + 0.8
    for k in range(5):
        c = YARN[(k * 4) % len(YARN)]
        x0 = -0.62 + (k % 3) * 0.42
        z0 = -2.8 + (k // 3) * 0.42
        hgt = y
        for j in range(rnd.randint(2, 4)):
            t = rnd.uniform(0.03, 0.05)
            b.box((x0, hgt, z0), (x0 + 0.36, hgt + t, z0 + 0.34), Mat("fabric", color=YARN[(k * 4 + j * 7) % len(YARN)], glow=g * 0.6))
            hgt += t
    for bx, bz in ((-0.9, -1.4), (0.95, -1.6), (-1.1, -3.6)):
        b.cylinder(V(bx, fy, bz), 0.22, 0.28, Mat("plain", color=(0.66, 0.5, 0.32), glow=g * 0.5), segments=12, radius_top=0.26, caps=(True, False))
        for k in range(5):
            a = 2 * math.pi * k / 5
            _yarn(b, bx + 0.12 * math.cos(a), fy + 0.2, bz + 0.12 * math.sin(a), 0.07, rnd.choice(YARN), g * 0.6, rnd)
    # Sessel mit Strickdecke hinten rechts
    b.box((xi - 0.85, fy, -3.9), (xi - 0.25, fy + 0.45, -3.3), Mat("fabric", color=(0.88, 0.84, 0.74), glow=g * 0.6))
    b.box((xi - 0.85, fy + 0.45, -3.9), (xi - 0.25, fy + 1.0, -3.75), Mat("fabric", color=(0.88, 0.84, 0.74), glow=g * 0.6))
    b.box((xi - 0.75, fy + 0.46, -3.88), (xi - 0.35, fy + 0.95, -3.7), Mat("fabric", color=(0.74, 0.58, 0.5), glow=g * 0.6))
    # Hängelampen
    for x, z in ((-0.6, -2.4), (0.6, -2.4), (0.0, -1.2)):
        b.tube([V(x, cy, z), V(x, cy - 0.45, z)], 0.005, LEAD, segments=4)
        b.cylinder(V(x, cy - 0.65, z), 0.14, 0.2, Mat("gold", glow=0.05), segments=10, radius_top=0.05, caps=(True, False))
        b.sphere(V(x, cy - 0.64, z), 0.055, Mat("plain", color=(1.0, 0.86, 0.6), glow=1.0), rings=3, segments=8)
    # Schaufenster-Auslage: Körbe mit Knäueln und Stoffstapel auf dem Fensterbrett
    for lo_x, hi_x in m["windows"]:
        x = lo_x + 0.25
        while x < hi_x - 0.2:
            _yarn(b, x, m["sill"] + 0.02, -0.2, 0.07, rnd.choice(YARN), g * 0.6, rnd)
            x += 0.2
    # Grün über dem Schild
    w = m["w"]
    x = -w + 0.2
    while x < w - 0.1:
        r = rnd.uniform(0.14, 0.2)
        b.sphere(V(x, s0 + 0.2 + r * 0.4, 0.15), r, P.leaf(rnd.randrange(3)), rings=4, segments=8, squash=0.7, jitter=0.18, seed=rnd.randrange(999))
        x += rnd.uniform(0.35, 0.5)
    for k in range(6):
        P.trailing_strand(b, (-w + 0.3 + (2 * w - 0.6) * rnd.random(), s0 + 0.18, 0.3), rnd.uniform(0.2, 0.5), rnd)
    P.projecting_sign(b, w - 0.15, s0 + 0.9, 0.0, JOINERY, Mat("plain", sign="hanging"))


def wool_outside(b, spec, rnd):
    """Vor dem Wolleladen: Holzbank mit Körben (Wolle, gefaltete Stoffe), Topf mit Lavendel, Tafel."""
    w = spec["width"] / 2
    bx0, bx1 = -w + 0.35, -0.65
    b.box((bx0, 0.38, 0.1), (bx1, 0.43, 0.48), Mat("timber"))
    for lx in (bx0 + 0.05, bx1 - 0.05):
        b.box((lx - 0.03, 0, 0.12), (lx + 0.03, 0.38, 0.46), Mat("timber"))
    for k, x in enumerate((bx0 + 0.25, bx0 + 0.65)):
        if x > bx1 - 0.15:
            break
        b.cylinder(V(x, 0.43, 0.29), 0.15, 0.18, Mat("plain", color=(0.66, 0.5, 0.32)), segments=10, radius_top=0.17, caps=(True, False))
        for j in range(4):
            a = 2 * math.pi * j / 4
            _yarn(b, x + 0.08 * math.cos(a), 0.56, 0.29 + 0.08 * math.sin(a), 0.06, rnd.choice(YARN), 0.0, rnd)
    b.colliders.append(((bx0, 0, 0.08), (bx1, 0.8, 0.5)))
    # Tafel rechts neben der Tür – nicht an der Kante zur Gasse (dort gehen Passanten entlang)
    P.chalkboard(b, 0.85, 0.5, Mat("plain", sign="chalkboard"), facing=-10)


def _basket(b, x, y, z, r, h, g=0.0):
    """Weidenkorb (offen) am Ort (x, y, z)."""
    b.cylinder(V(x, y, z), r * 0.85, h, Mat("plain", color=(0.62, 0.46, 0.28), glow=g), segments=12, radius_top=r, caps=(True, False))
    ring = [V(x + r * math.cos(a), y + h, z + r * math.sin(a)) for a in [2 * math.pi * k / 16 for k in range(17)]]
    b.tube(ring, 0.012, Mat("plain", color=(0.55, 0.4, 0.24), glow=g), segments=4, caps=False)


def shopfront_bakery(b, spec, rnd, s0):
    """Bäckerei (Inspiration "Bäckerei") im schmalen Haus: Petrol mit Gold, rot-weiße Markise,
    Schaufenster mit Brot auf Stufen und Lichterkette; innen Brotregale bis zur Decke mit Körben,
    Glastheke mit Kuchen und Gebäck, Karofliesen, Kreidetafel mit Preisen, Mehlsäcke, Lampen."""
    m = shop_shell(b, spec, rnd, s0, (0.93, 0.89, 0.8), Mat("plain", color=(0.9, 0.87, 0.8), glow=0.1), door_half=0.45)
    xi, fy, cy, zb, zf, g = m["xi"], m["floor_y"], m["ceil_y"], m["zb"], m["zf"], m["glow"]
    w = m["w"]
    wood = Mat("timber", color=(1.05, 0.9, 0.8), glow=g * 0.6)
    # Karofliesen
    dark = Mat("plain", color=(0.22, 0.3, 0.3), glow=g * 0.3)
    t = 0.3
    x = -xi
    k = 0
    while x < xi - 0.01:
        z = zb
        j = 0
        while z < zf - 0.01:
            if (k + j) % 2 == 0:
                x1 = min(x + t, xi)
                z1 = min(z + t, zf)
                b.face([V(x, fy + 0.002, z), V(x1, fy + 0.002, z), V(x1, fy + 0.002, z1), V(x, fy + 0.002, z1)], dark, (0, 1, 0))
            z += t
            j += 1
        x += t
        k += 1
    # Rückwand: Brotregal bis zur Decke mit Körben und Laiben
    b.box((-xi, fy, zb), (xi, cy, zb + 0.05), wood)
    rows = [0.5, 0.95, 1.4, 1.85, 2.3]
    for y in rows:
        b.box((-xi + 0.05, y - 0.03, zb), (xi - 0.05, y, zb + 0.4), wood)
        x = -xi + 0.2
        while x < xi - 0.15:
            if rnd.random() < 0.35:
                _basket(b, x + 0.08, y, zb + 0.2, 0.13, 0.12, g * 0.4)
                for q in range(3):
                    _loaf(b, x + 0.03 + q * 0.06, y + 0.08, zb + 0.2, rnd, g)
                x += 0.32
            else:
                _loaf(b, x, y, zb + 0.2, rnd, g)
                x += rnd.uniform(0.15, 0.2)
    # Glastheke quer durch den Laden mit Kuchen, Torten und Gebäck
    tz = zb + 1.2
    b.box((-xi + 0.3, fy, tz - 0.3), (xi - 0.3, fy + 0.55, tz + 0.3), Mat("timber", color=(0.8, 0.55, 0.42), glow=g * 0.6))
    b.box((-xi + 0.3, fy + 0.55, tz - 0.3), (xi - 0.3, fy + 0.6, tz + 0.3), Mat("timber", color=(0.6, 0.4, 0.28), glow=g * 0.6))
    b.box((-xi + 0.34, fy + 0.6, tz - 0.26), (xi - 0.34, fy + 1.05, tz + 0.26), CLEAR)
    b.box((-xi + 0.3, fy + 1.05, tz - 0.3), (xi - 0.3, fy + 1.08, tz + 0.3), wood)
    x = -xi + 0.5
    while x < xi - 0.4:
        r = rnd.random()
        if r < 0.3:
            b.cylinder(V(x, fy + 0.6, tz), 0.13, 0.12, Mat("plain", color=rnd.choice([(0.92, 0.84, 0.72), (0.5, 0.3, 0.22), (0.92, 0.72, 0.74)]), glow=g * 0.6),
                       segments=14, caps=(True, True))
            b.sphere(V(x, fy + 0.74, tz), 0.02, Mat("plain", color=(0.8, 0.2, 0.2), glow=g), rings=3, segments=6)
            x += 0.32
        else:
            for q in range(3):
                b.sphere(V(x + q * 0.07, fy + 0.63, tz - 0.08 + rnd.uniform(0, 0.16)), 0.035,
                         Mat("plain", color=rnd.choice([(0.86, 0.62, 0.34), (0.94, 0.86, 0.7), (0.6, 0.36, 0.22)]), glow=g * 0.5),
                         rings=3, segments=7, squash=0.6)
            x += 0.25
    b.box((xi - 0.75, fy + 1.08, tz - 0.22), (xi - 0.45, fy + 1.2, tz + 0.02), Mat("gold", glow=0.05))
    for q in range(2):
        cx = -0.3 + q * 0.6
        b.cylinder(V(cx, fy + 1.08, tz + 0.05), 0.02, 0.18, Mat("plain", color=(0.95, 0.94, 0.9), glow=g), segments=6)
        b.cylinder(V(cx, fy + 1.26, tz + 0.05), 0.16, 0.012, Mat("plain", color=(0.95, 0.94, 0.9), glow=g), segments=14, caps=(True, True))
        b.cylinder(V(cx, fy + 1.272, tz + 0.05), 0.12, 0.1, Mat("plain", color=(0.94, 0.8, 0.82), glow=g * 0.6), segments=14, caps=(True, True))
    # Kreidetafel mit Preisen an der Seitenwand, Mehlsäcke, Brotkorb am Boden
    b.push(b.move(-xi, 0, zb + 2.3) @ b.turn_y(90))
    b.box((-0.45, 1.3, 0.0), (0.45, 2.1, 0.03), wood)
    b.box((-0.41, 1.34, 0.03), (0.41, 2.06, 0.035), Mat("plain", color=(0.12, 0.13, 0.12), glow=0.03))
    for r in range(5):
        b.box((-0.32, 1.9 - r * 0.13, 0.035), (-0.32 + rnd.uniform(0.3, 0.6), 1.92 - r * 0.13, 0.038), Mat("plain", color=(0.9, 0.9, 0.86), glow=0.2))
    b.pop()
    for q, (sx, sz) in enumerate(((xi - 0.3, zb + 2.0), (xi - 0.32, zb + 2.45))):
        b.sphere(V(sx, fy + 0.28, sz), 0.24, Mat("fabric", color=(0.88, 0.82, 0.7), glow=g * 0.5), rings=5, segments=9, squash=1.25)
    _basket(b, -xi + 0.4, fy, zb + 3.2, 0.24, 0.3, g * 0.4)
    for q in range(6):
        b.push(b.move(-xi + 0.4 + rnd.uniform(-0.08, 0.08), fy + 0.25, zb + 3.2 + rnd.uniform(-0.08, 0.08)) @ S.Matrix.Rotation(rnd.uniform(-0.3, 0.3), 4, "Z"))
        b.cylinder(V(0, 0, 0), 0.03, 0.55, Mat("plain", color=(0.78, 0.55, 0.3), glow=g * 0.5), segments=6, radius_top=0.025, caps=(True, True))
        b.pop()
    # Auslage im Schaufenster: Stufen mit Brot, Lichterkette
    for lo_x, hi_x in m["windows"]:
        for k2, (dz, dy) in enumerate(((-0.2, 0.0), (-0.45, 0.32), (-0.7, 0.64))):
            b.box((lo_x + 0.08, m["sill"] - 0.02 + dy, dz - 0.22), (hi_x - 0.08, m["sill"] + dy, dz), wood)
            x = lo_x + 0.18
            while x < hi_x - 0.12:
                _loaf(b, x, m["sill"] + dy, dz - 0.11, rnd, g)
                x += rnd.uniform(0.15, 0.2)
        for q in range(int((hi_x - lo_x) / 0.15)):
            x = lo_x + 0.08 + q * 0.15
            y = m["head"] - 0.1 - 0.08 * math.sin(math.pi * (x - lo_x) / (hi_x - lo_x))
            b.sphere(V(x, y, -0.1), 0.016, Mat("plain", color=(1.0, 0.85, 0.55), glow=1.0), rings=3, segments=6)
    for x, z in ((-0.5, zb + 2.6), (0.5, zb + 2.6), (0.0, zb + 1.2)):
        b.tube([V(x, cy, z), V(x, cy - 0.45, z)], 0.005, LEAD, segments=4)
        b.cylinder(V(x, cy - 0.65, z), 0.16, 0.2, Mat("gold", glow=0.05), segments=10, radius_top=0.05, caps=(True, False))
        b.sphere(V(x, cy - 0.64, z), 0.06, Mat("plain", color=(1.0, 0.85, 0.58), glow=1.0), rings=3, segments=8)
    # Markise über der ganzen Front
    _shop_awning(b, -w + 0.1, w - 0.1, m["fascia_lo"] - 0.02, 0.2, 1.0, 0.5)


def bakery_outside(b, spec, rnd):
    """Vor der Bäckerei: zwei Holzkisten mit Blumen (wie im Bild), Kreidetafel."""
    w = spec["width"] / 2
    # Nur links (rechts geht der Weg aus der kleinen Gasse vorbei)
    for x in (-w + 0.6,):
        b.box((x - 0.32, 0, 0.2), (x + 0.32, 0.38, 0.55), Mat("timber"))
        for q in range(4):
            px = x - 0.24 + q * 0.16
            b.sphere(V(px, 0.45, 0.37), 0.11, P.leaf(q), rings=4, segments=8, jitter=0.15, seed=rnd.randrange(99))
            P.blossom_cluster(b, (px, 0.47, 0.37), 0.1, rnd.choice(["coral", "rose", "white"]), rnd, count=6)
        b.colliders.append(((x - 0.34, 0, 0.18), (x + 0.34, 0.7, 0.57)))
    P.chalkboard(b, 0.0 + 0.85, 0.75, Mat("plain", sign="chalkboard"), facing=-8)


SHOPFRONTS = {"flowers": (shopfront_flowers, shop_outside_flowers), "pub": (shopfront_pub, pub_outside),
              "wool": (shopfront_wool, wool_outside), "bakery": (shopfront_bakery, bakery_outside)}


# ---------------------------------------------------------------------------------------------
# Eckhaus mit abgeschrägter Ecke (corner_90, corner_30): kleiner Laden in der Schräge
# ---------------------------------------------------------------------------------------------

def corner_footprint(spec):
    """Grundriss (x, z) wie CornerHouseFacade.footprint()."""
    w = spec["width"] / 2
    ang = math.radians(spec["corner_angle"])
    along = (math.cos(ang), -math.sin(ang))
    cut = spec["chamfer_width"] / (2 * math.cos(ang / 2))
    side = spec["depth"] if spec["corner_angle"] >= 89.9 else spec["side_length"]
    corner = (w, 0.0)
    side_end = (corner[0] + along[0] * side, corner[1] + along[1] * side)
    pts = [(-w, 0.0), (w - cut, 0.0), (w + along[0] * cut, along[1] * cut), side_end]
    if spec["corner_angle"] < 89.9:
        back = (-math.sin(ang), -math.cos(ang))
        t = (spec["depth"] + side_end[1]) / math.cos(ang)
        pts.append((side_end[0] + back[0] * max(0.0, t), side_end[1] + back[1] * max(0.0, t)))
    pts.append((-w, -spec["depth"]))
    return pts


def _offset(points, d):
    """Konvexes Vieleck (gegen den Uhrzeigersinn von oben in x/-z) um d nach außen versetzen."""
    n = len(points)
    out = []
    for i in range(n):
        p0, p1, p2 = points[i - 1], points[i], points[(i + 1) % n]
        n0 = _out_normal(p0, p1)
        n1 = _out_normal(p1, p2)
        a = (p0[0] + n0[0] * d, p0[1] + n0[1] * d)
        da = (p1[0] - p0[0], p1[1] - p0[1])
        c = (p1[0] + n1[0] * d, p1[1] + n1[1] * d)
        dc = (p2[0] - p1[0], p2[1] - p1[1])
        den = da[0] * dc[1] - da[1] * dc[0]
        t = ((c[0] - a[0]) * dc[1] - (c[1] - a[1]) * dc[0]) / den
        out.append((a[0] + da[0] * t, a[1] + da[1] * t))
    return out


def _out_normal(a, c):
    dx, dz = c[0] - a[0], c[1] - a[1]
    ln = math.hypot(dx, dz)
    return (-dz / ln, dx / ln)  # außen (wie CornerHouseFacade: Vorderkante zeigt nach +z)


def _facade_xf(a, c):
    """Wand-Koordinaten (x entlang a→c, +z nach außen), Ursprung in der Mitte."""
    dx, dz = c[0] - a[0], c[1] - a[1]
    ln = math.hypot(dx, dz)
    ax, az = dx / ln, dz / ln
    ox, oz = _out_normal(a, c)
    mx, mz = (a[0] + c[0]) / 2, (a[1] + c[1]) / 2
    return S.Matrix(((ax, 0, ox, mx), (0, 1, 0, 0), (az, 0, oz, mz), (0, 0, 0, 1))), ln


def _point_in(poly, x, z, margin=0.0):
    """Liegt (x, z) im konvexen Grundriss (mit Abstand margin zu allen Kanten)?"""
    n = len(poly)
    for i in range(n):
        a, c = poly[i], poly[(i + 1) % n]
        nx, nz = _out_normal(a, c)
        if (x - a[0]) * nx + (z - a[1]) * nz > -margin:
            return False
    return True


def build_corner(name, spec):
    """Eckhaus mit Laden im Erdgeschoss: große Schaufenster an den Straßenseiten, Ladentür
    (in der Schräge oder auf spec["door_edge"]), dahinter ein eingerichteter Raum über die
    ganze Grundfläche (Bäckerei oder Teestube, spec["shop"]). Obergeschoss mit Schiebefenstern."""
    rnd = random.Random(spec["seed"])
    b = S.Builder(name)
    E = spec["eaves"]
    pts = corner_footprint(spec)
    storeys = spec["storeys"]
    ys = [0.0]
    for h in storeys:
        ys.append(ys[-1] + h)
    wall = wall_mat(spec["wall"])
    n = len(pts)
    door_edge = spec.get("door_edge", 1)
    reveal = 0.13
    head = ys[1] - 0.75
    sill = 0.55
    floor_y = 0.1
    ceil_y = ys[1] - 0.3
    inset = _offset(pts, -reveal)
    shop = spec.get("shop", "bakery")
    g = 0.14
    room_wall = Mat("render", color=spec.get("room_color", (0.9, 0.86, 0.76)), glow=g)
    for i in range(n):
        a, c = pts[i], pts[(i + 1) % n]
        xf, ln = _facade_xf(a, c)
        b.push(xf)
        half = ln / 2
        street = i < 3
        has_door = i == door_edge
        dx = 0.0 if door_edge == 1 else -half + 1.0
        # Erdgeschoss: Tür und Schaufenster-Felder
        ground_holes, shop_spans = [], []
        if has_door:
            ground_holes.append((dx - 0.55, 0.0, dx + 0.55, 2.6))
        if street:
            lo, hi = -half + 0.35, half - 0.35
            spans = [(lo, hi)]
            if has_door:
                spans = [(lo, dx - 0.75), (dx + 0.75, hi)]
            for s0, s1 in spans:
                if s1 - s0 >= 0.8:
                    shop_spans.append((s0, s1))
                    ground_holes.append((s0, sill, s1, head))
        b.wall_with_holes(-half, half, 0.0, ys[1], 0.0, ground_holes, wall, reveal=reveal)
        for s0, s1 in shop_spans:
            _corner_shop_window(b, spec, s0, s1, sill, head, reveal, rnd, shop)
        # Obergeschosse
        for fl in range(1, len(storeys)):
            y0, y1 = ys[fl], ys[fl + 1]
            holes, units = [], []
            if street:
                count = 1 if i == 1 else max(1, int((ln - 0.6) / 1.6))
                for k in range(count):
                    x = -half + ln * (k + 0.5) / count
                    top_floor = fl == len(storeys) - 1
                    ww, wy = 0.95, y0 + 0.75
                    wh = min(1.6, y1 - wy - (0.8 if top_floor else 0.45))
                    holes.append((x - ww / 2, wy, x + ww / 2, wy + wh))
                    units.append((x, wy, ww, wh))
            b.wall_with_holes(-half, half, y0, y1, 0.0, holes, wall, reveal=reveal)
            for x, wy, ww, wh in units:
                room = (x - ww / 2 - 0.3, x + ww / 2 + 0.3, y0 + 0.05, y1 - 0.25, 1.0)
                window_unit(b, spec, x, wy, ww, wh, spec["panes"], rnd.choices(["closed", "nets", "blind", "dim"], [3, 4, 2, 2])[0],
                            room, rnd, floor=fl)
        if street:
            pl = [(-half, dx - 0.6), (dx + 0.6, half)] if has_door else [(-half, half)]
            for p0, p1 in pl:
                if p1 - p0 > 0.05:
                    b.box((p0, 0, 0), (p1, 0.32, 0.035), PLINTH, skip=("back", "bottom"))
            b.box((-half, ys[1] - 0.05, 0), (half, ys[1] + 0.07, 0.05), TRIM, skip=("back",))
            b.box((-half, E - 0.25, 0), (half, E - 0.1, 0.07), TRIM, skip=("back",))
            # Schildband über den Schaufenstern (Türfarbe mit Goldlinie)
            if shop_spans:
                b.box((-half + 0.1, head + 0.12, 0), (half - 0.1, ys[1] - 0.12, 0.08), JOINERY, skip=("back",))
                b.box((-half + 0.16, ys[1] - 0.2, 0.08), (half - 0.16, ys[1] - 0.185, 0.085), GOLD, skip=("back",))
                b.box((-half + 0.16, head + 0.19, 0.08), (half - 0.16, head + 0.205, 0.085), GOLD, skip=("back",))
            if shop == "bakery":
                for s0, s1 in shop_spans:
                    _shop_awning(b, s0 - 0.05, s1 + 0.05, head + 0.1, 0.1, 0.9, 0.45)
        if has_door:
            b.push(b.move(dx, 0, 0))
            _corner_door(b, spec, rnd)
            b.pop()
            if spec.get("hanging_sign"):
                P.projecting_sign(b, dx + 1.35, ys[1] + 0.75, 0.0, JOINERY, Mat("plain", sign="hanging"))
        # Innenwand des Ladens (zeigt in den Raum), mit denselben Öffnungen
        ia, ic = inset[i], inset[(i + 1) % n]
        mx, mz = (a[0] + c[0]) / 2, (a[1] + c[1]) / 2
        ux, uz = (c[0] - a[0]) / ln, (c[1] - a[1]) / ln
        la = (ia[0] - mx) * ux + (ia[1] - mz) * uz
        lc = (ic[0] - mx) * ux + (ic[1] - mz) * uz
        b.push(b.move(0, 0, -reveal) @ b.turn_y(180))
        b.wall_with_holes(-lc, -la, floor_y, ceil_y, 0.0, [(-h[2], max(h[1], floor_y), -h[0], h[3]) for h in ground_holes], room_wall, reveal=0.0)
        b.pop()
        # Einrichtung an den hinteren Wänden (Regale)
        if not street:
            b.push(b.move(0, 0, -reveal))
            _corner_wall_furniture(b, shop, la, lc, floor_y, ceil_y, rnd, g)
            b.pop()
        b.pop()
    # Boden und Decke des Ladens
    floor_mat = Mat("plain", color=(0.9, 0.86, 0.78), glow=g * 0.6) if shop == "bakery" else Mat("boards", color=(0.6, 0.44, 0.3), glow=g * 0.6)
    b.face([V(p[0], floor_y, p[1]) for p in inset], floor_mat, (0, 1, 0))
    b.face([V(p[0], ceil_y, p[1]) for p in inset], Mat("plain", color=(0.92, 0.9, 0.84), glow=g), (0, -1, 0))
    _corner_shop_contents(b, shop, inset, floor_y, ceil_y, rnd, g)
    # Walmdach, oben flach
    outer = _offset(pts, 0.25)
    run = 2.0
    inner = _offset(pts, -run)
    rise = spec["roof_rise"]
    rm = ROOF_MATS[spec["roof_mat"]]
    for i in range(n):
        j = (i + 1) % n
        quad = [V(outer[i][0], E, outer[i][1]), V(outer[j][0], E, outer[j][1]), V(inner[j][0], E + rise, inner[j][1]), V(inner[i][0], E + rise, inner[i][1])]
        b.face(quad, rm, (0, 1, 0))
        b.face([V(outer[i][0], E - 0.18, outer[i][1]), V(outer[j][0], E - 0.18, outer[j][1]), V(outer[j][0], E, outer[j][1]), V(outer[i][0], E, outer[i][1])],
               CREAM, (_out_normal(pts[i], pts[j])[0], 0, _out_normal(pts[i], pts[j])[1]))
        b.face([V(outer[i][0], E - 0.18, outer[i][1]), V(outer[j][0], E - 0.18, outer[j][1]), V(pts[j][0], E - 0.18, pts[j][1]), V(pts[i][0], E - 0.18, pts[i][1])],
               CREAM, (0, -1, 0))
    b.face([V(p[0], E + rise, p[1]) for p in inner], Mat("metal"), (0, 1, 0))
    cx = sum(p[0] for p in inner) / len(inner)
    cz = sum(p[1] for p in inner) / len(inner)
    chimney(b, cx - 0.6, cz - 0.4, E + rise - 0.2, E + rise + 1.0, pots=2)
    return b


def _shop_awning(b, x0, x1, y_top, z_wall, reach, drop):
    """Gestreifte Markise (Akzentfarbe), beidseitig, mit Volant."""
    canvas = Mat("canvas", "accent")
    a, c = V(x0, y_top, z_wall), V(x1, y_top, z_wall)
    d, e = V(x1, y_top - drop, reach), V(x0, y_top - drop, reach)
    b.poly([a, c, d, e], canvas, both=True)
    b.poly([V(x0, y_top - drop - 0.18, reach), V(x1, y_top - drop - 0.18, reach), d, e], canvas, both=True)
    b.cylinder(V(x0, y_top - drop, reach - 0.02), 0.016, x1 - x0, LEAD, segments=6, caps=(True, True), axis="x")
    b.box((x0 - 0.03, y_top - 0.05, 0.0), (x1 + 0.03, y_top + 0.06, z_wall + 0.03), JOINERY)


def _corner_shop_window(b, spec, s0, s1, sill, head, reveal, rnd, shop):
    """Schaufenster in einer Wandöffnung: klares Glas, Rahmen, Sprossen oben, Brüstung außen,
    innen eine Auslage (Brotregal bzw. Teedosen und Etagere)."""
    zg = -0.08
    b.quad(V(s0, sill, zg), V(s1, sill, zg), V(s1, head, zg), V(s0, head, zg), CLEAR)
    if shop == "tea":
        # Innen raues Glas (nur von drinnen sichtbar): man sieht das Straßenende nur verschwommen
        b.poly([V(s1, sill, zg - 0.008), V(s0, sill, zg - 0.008), V(s0, head, zg - 0.008), V(s1, head, zg - 0.008)],
               Mat("glass", glass="inner"))
    f = 0.06
    zf0, zf1 = -reveal, -0.02
    for xx in (s0, s1 - f):
        b.box((xx, sill, zf0), (xx + f, head, zf1), JOINERY)
    b.box((s0 + f, head - f, zf0), (s1 - f, head, zf1), JOINERY, skip=("left", "right"))
    b.box((s0 + f, sill, zf0), (s1 - f, sill + f, zf1), JOINERY, skip=("left", "right"))
    tr = head - 0.4
    b.box((s0 + f, tr - 0.025, zf0), (s1 - f, tr + 0.025, zf1), JOINERY, skip=("left", "right"))
    nb = max(3, int((s1 - s0) / 0.28))
    b.glazing_bars(s0 + f, tr + 0.025, s1 - f, head - f, zf0, zf1 - 0.01, nb, 1, 0.02, JOINERY)
    mids = max(1, int((s1 - s0) / 1.1))
    for k in range(1, mids + 1):
        mx = s0 + (s1 - s0) * k / (mids + 1)
        b.box((mx - 0.02, sill + f, zf0), (mx + 0.02, tr - 0.025, zf1), JOINERY)
    b.box((s0 - 0.05, sill - 0.06, 0), (s1 + 0.05, sill, 0.12), JOINERY)
    b.box((s0, 0.0, 0.0), (s1, sill - 0.06, 0.06), JOINERY, skip=("back", "bottom"))
    b.frame(s0 + 0.08, 0.12, s1 - 0.08, sill - 0.16, 0.06, 0.08, 0.025, JOINERY)
    # Auslage hinter dem Glas
    g = 0.14
    wood = Mat("timber", glow=g * 0.7)
    for k, (dz, dy) in enumerate(((-0.35, 0.0), (-0.6, 0.35), (-0.85, 0.7))):
        b.box((s0 + 0.08, sill - 0.04 + dy, dz - 0.2), (s1 - 0.08, sill + dy, dz), wood)
        x = s0 + 0.2
        while x < s1 - 0.15:
            if shop == "bakery":
                _loaf(b, x, sill + dy, dz - 0.1, rnd, g)
                x += rnd.uniform(0.17, 0.24)
            elif shop == "wool":
                _yarn(b, x, sill + dy, dz - 0.1, 0.06, rnd.choice(YARN), g * 0.6, rnd)
                x += 0.15
            else:
                c = rnd.choice([(0.55, 0.2, 0.22), (0.2, 0.32, 0.28), (0.82, 0.7, 0.42), (0.3, 0.3, 0.42), (0.86, 0.82, 0.74)])
                b.cylinder(V(x, sill + dy, dz - 0.1), 0.05, 0.13, Mat("paint", color=c, glow=g * 0.6), segments=10, caps=(True, True))
                x += 0.13
    if shop == "bakery":
        # Lichterkette oben im Fenster
        for k in range(int((s1 - s0) / 0.18)):
            x = s0 + 0.1 + k * 0.18
            y = head - 0.12 - 0.08 * math.sin(math.pi * (x - s0) / (s1 - s0))
            b.sphere(V(x, y, -0.12), 0.018, Mat("plain", color=(1.0, 0.85, 0.55), glow=1.0), rings=3, segments=6)


def _loaf(b, x, y, z, rnd, g):
    """Brot oder Gebäck (gestreckte, flache Kugel in Krustenfarbe)."""
    crust = rnd.choice([(0.72, 0.48, 0.26), (0.62, 0.38, 0.2), (0.82, 0.62, 0.36), (0.52, 0.32, 0.18)])
    sx = rnd.uniform(0.06, 0.1)
    b.push(b.move(x, y, z) @ S.Matrix.Diagonal((1.0, 0.65, rnd.uniform(0.7, 1.3), 1.0)))
    b.sphere(V(0, sx * 0.9, 0), sx, Mat("plain", color=crust, glow=g * 0.5), rings=4, segments=8, jitter=0.06, seed=rnd.randrange(999))
    b.pop()


def _corner_wall_furniture(b, shop, la, lc, floor_y, ceil_y, rnd, g):
    """Regale an einer Innenwand (Wand-Koordinaten: x entlang, Raum bei -z ab z = 0)."""
    x0, x1 = sorted((la, lc))
    x0, x1 = x0 + 0.3, x1 - 0.3
    if x1 - x0 < 0.6:
        return
    wood = Mat("timber", color=(1.1, 0.95, 0.85), glow=g * 0.6)
    b.box((x0, floor_y, -0.42), (x1, floor_y + 0.85, 0.0), wood)
    for y in (1.3, 1.7, 2.1):
        b.box((x0, y - 0.025, -0.3), (x1, y, 0.0), wood)
        x = x0 + 0.12
        while x < x1 - 0.1:
            if shop == "bakery":
                _loaf(b, x, y, -0.15, rnd, g)
                x += rnd.uniform(0.16, 0.24)
            elif shop == "wool":
                _yarn(b, x, y, -0.15, 0.06, rnd.choice(YARN), g * 0.6, rnd)
                x += 0.14
            else:
                c = rnd.choice([(0.55, 0.2, 0.22), (0.2, 0.32, 0.28), (0.82, 0.7, 0.42), (0.3, 0.3, 0.42), (0.86, 0.82, 0.74),
                                (0.42, 0.26, 0.2)])
                b.cylinder(V(x, y, -0.15), 0.055, rnd.uniform(0.12, 0.18), Mat("paint", color=c, glow=g * 0.6), segments=10, caps=(True, True))
                x += 0.14
    for k in range(int((x1 - x0) / 0.8)):
        b.box((x0 + 0.1 + k * 0.8, floor_y + 0.12, -0.43), (x0 + 0.7 + k * 0.8, floor_y + 0.72, -0.42), Mat("timber", color=(0.9, 0.8, 0.7), glow=g * 0.5))


def _corner_shop_contents(b, shop, poly, floor_y, ceil_y, rnd, g):
    """Mitte des Ladens: Bäckerei = Glastheke mit Kuchen und Karofliesen, Teestube = Tische mit
    Tischdecken, Teekannen und Etagere. Dazu Hängelampen."""
    cx = sum(p[0] for p in poly) / len(poly)
    cz = sum(p[1] for p in poly) / len(poly)
    if shop == "bakery":
        dark = Mat("plain", color=(0.24, 0.3, 0.3), glow=g * 0.4)
        xs = [p[0] for p in poly]
        zs = [p[1] for p in poly]
        t = 0.33
        x = min(xs)
        k = 0
        while x < max(xs):
            z = min(zs)
            j = 0
            while z < max(zs):
                if (k + j) % 2 == 0 and _point_in(poly, x + t / 2, z + t / 2, t * 0.75):
                    b.face([V(x, floor_y + 0.002, z), V(x + t, floor_y + 0.002, z), V(x + t, floor_y + 0.002, z + t), V(x, floor_y + 0.002, z + t)],
                           dark, (0, 1, 0))
                z += t
                j += 1
            x += t
            k += 1
        # Glastheke mit Kuchen und Gebäck
        tx0, tx1, tz = cx - 1.2, cx + 1.2, cz - 0.6
        wood = Mat("timber", color=(0.8, 0.55, 0.4), glow=g * 0.6)
        b.box((tx0, floor_y, tz - 0.3), (tx1, floor_y + 0.55, tz + 0.3), wood)
        b.box((tx0, floor_y + 0.55, tz - 0.3), (tx1, floor_y + 0.6, tz + 0.3), Mat("timber", color=(0.6, 0.4, 0.28), glow=g * 0.6))
        b.box((tx0 + 0.04, floor_y + 0.6, tz - 0.26), (tx1 - 0.04, floor_y + 1.0, tz + 0.26), CLEAR)
        b.box((tx0, floor_y + 1.0, tz - 0.3), (tx1, floor_y + 1.03, tz + 0.3), wood)
        x = tx0 + 0.2
        while x < tx1 - 0.15:
            if rnd.random() < 0.4:
                b.cylinder(V(x, floor_y + 0.6, tz), 0.12, 0.1, Mat("plain", color=rnd.choice([(0.9, 0.82, 0.7), (0.72, 0.5, 0.42), (0.9, 0.7, 0.72)]), glow=g * 0.6),
                           segments=12, caps=(True, True))
                x += 0.3
            else:
                _loaf(b, x, floor_y + 0.6, tz + rnd.uniform(-0.1, 0.1), rnd, g)
                x += 0.18
        b.box((cx + 0.6, floor_y + 1.03, tz - 0.2), (cx + 1.0, floor_y + 1.15, tz + 0.05), Mat("gold", glow=0.05))
    elif shop == "wool":
        # Tisch mit Stoffstapeln, Körbe voller Knäuel, Stoffballen stehend, ein Sessel
        wood = Mat("timber", color=(1.15, 1.05, 0.95), glow=g * 0.6)
        b.box((cx - 0.8, floor_y + 0.74, cz - 0.45), (cx + 0.8, floor_y + 0.8, cz + 0.45), wood)
        for lx in (-0.72, 0.72):
            for lz in (-0.38, 0.38):
                b.box((cx + lx - 0.03, floor_y, cz + lz - 0.03), (cx + lx + 0.03, floor_y + 0.74, cz + lz + 0.03), wood)
        for k in range(6):
            x0 = cx - 0.7 + (k % 3) * 0.48
            z0 = cz - 0.38 + (k // 3) * 0.42
            hgt = floor_y + 0.8
            for j in range(rnd.randint(2, 5)):
                tt = rnd.uniform(0.03, 0.05)
                b.box((x0, hgt, z0), (x0 + 0.4, hgt + tt, z0 + 0.36), Mat("fabric", color=YARN[(k * 5 + j * 3) % len(YARN)], glow=g * 0.6))
                hgt += tt
        for dx, dz in ((-1.3, 0.9), (1.2, 1.0), (1.3, -1.0)):
            x, z = cx + dx, cz + dz
            if _point_in(poly, x, z, 0.35):
                _basket(b, x, floor_y, z, 0.24, 0.3, g * 0.4)
                for k in range(6):
                    a = 2 * math.pi * k / 6
                    _yarn(b, x + 0.12 * math.cos(a), floor_y + 0.22, z + 0.12 * math.sin(a), 0.07, rnd.choice(YARN), g * 0.6, rnd)
        for k in range(7):
            x, z = cx - 1.4 + k * 0.14, cz - 1.3
            if _point_in(poly, x, z, 0.15):
                b.cylinder(V(x, floor_y, z), 0.065, 1.0, Mat("fabric", color=YARN[k % len(YARN)], glow=g * 0.6), segments=8, caps=(True, True))
    else:
        cloth = Mat("fabric", color=(0.94, 0.92, 0.86), glow=g * 0.6)
        spots = []
        for dx, dz in ((-1.2, 0.6), (0.6, 0.9), (-0.6, -1.0), (1.1, -0.8), (0.0, 0.0)):
            x, z = cx + dx, cz + dz
            if _point_in(poly, x, z, 0.8):
                spots.append((x, z))
        for x, z in spots:
            b.cylinder(V(x, floor_y, z), 0.42, 0.7, cloth, segments=16, radius_top=0.36, caps=(False, True))
            b.cylinder(V(x, floor_y + 0.7, z), 0.37, 0.02, cloth, segments=16, caps=(False, True))
            _teapot(b, x + 0.08, floor_y + 0.72, z - 0.05, rnd, g)
            for k in range(2):
                a = math.pi * k + rnd.uniform(0, 1)
                chx, chz = x + 0.62 * math.cos(a), z + 0.62 * math.sin(a)
                b.cylinder(V(chx, floor_y + 0.44, chz), 0.2, 0.04, Mat("fabric", color=(0.66, 0.46, 0.48), glow=g * 0.5), segments=10, caps=(True, True))
                for lk in range(4):
                    la = 2 * math.pi * lk / 4 + 0.4
                    b.cylinder(V(chx + 0.14 * math.cos(la), floor_y, chz + 0.14 * math.sin(la)), 0.015, 0.44, Mat("metal"), segments=4)
        # Etagere auf dem letzten Tisch
        if spots:
            x, z = spots[-1]
            b.cylinder(V(x - 0.12, floor_y + 0.72, z + 0.1), 0.006, 0.38, Mat("gold"), segments=4)
            for k, r in enumerate((0.15, 0.12, 0.09)):
                y = floor_y + 0.74 + k * 0.13
                b.cylinder(V(x - 0.12, y, z + 0.1), r, 0.01, Mat("plain", color=(0.95, 0.94, 0.9), glow=g), segments=12, caps=(True, True))
                for j in range(4):
                    a = 2 * math.pi * j / 4
                    b.sphere(V(x - 0.12 + r * 0.55 * math.cos(a), y + 0.03, z + 0.1 + r * 0.55 * math.sin(a)), 0.025,
                             Mat("plain", color=rnd.choice([(0.92, 0.7, 0.72), (0.86, 0.72, 0.5), (0.7, 0.5, 0.36)]), glow=g * 0.5), rings=3, segments=6)
    for dx, dz in ((-0.8, 0.0), (0.8, 0.0), (0.0, -1.0)):
        x, z = cx + dx, cz + dz
        if not _point_in(poly, x, z, 0.3):
            continue
        b.tube([V(x, ceil_y, z), V(x, ceil_y - 0.45, z)], 0.005, LEAD, segments=4)
        b.cylinder(V(x, ceil_y - 0.65, z), 0.16, 0.2, Mat("gold", glow=0.05), segments=10, radius_top=0.05, caps=(True, False))
        b.sphere(V(x, ceil_y - 0.64, z), 0.06, Mat("plain", color=(1.0, 0.85, 0.58), glow=1.0), rings=3, segments=8)


def _teapot(b, x, y, z, rnd, g):
    c = rnd.choice([(0.9, 0.88, 0.84), (0.55, 0.62, 0.7), (0.78, 0.55, 0.55)])
    m = Mat("plain", color=c, glow=g * 0.6)
    b.sphere(V(x, y + 0.07, z), 0.07, m, rings=5, segments=10, squash=0.85)
    b.tube([V(x + 0.06, y + 0.06, z), V(x + 0.11, y + 0.1, z), V(x + 0.13, y + 0.12, z)], lambda t: 0.012 - 0.006 * t, m, segments=5)
    b.tube([V(x - 0.06, y + 0.1, z), V(x - 0.1, y + 0.08, z), V(x - 0.065, y + 0.04, z)], 0.008, m, segments=4)
    b.sphere(V(x, y + 0.14, z), 0.015, m, rings=3, segments=6)


def _corner_door(b, spec, rnd):
    """Ladentür in der Abschrägung, Schild darüber (Bild "fascia"), Laterne."""
    x0, x1 = -0.55, 0.55
    top = 2.25
    z = -0.13
    b.box((x0, 0, z), (x1, 0.1, 0.02), TRIM, skip=("back",))
    for lo, hi in ((x0, x0 + 0.07), (x1 - 0.07, x1)):
        b.box((lo, 0.1, z), (hi, 2.6, z + 0.06), JOINERY)
    b.box((x0 + 0.07, top, z), (x1 - 0.07, 2.6, z + 0.06), JOINERY, skip=("left", "right"))
    b.quad(V(x0 + 0.07, top + 0.06, z + 0.02), V(x1 - 0.07, top + 0.06, z + 0.02), V(x1 - 0.07, 2.53, z + 0.02), V(x0 + 0.07, 2.53, z + 0.02), GLASS)
    b.quad(V(x0 + 0.07, top + 0.06, z - 0.01), V(x1 - 0.07, top + 0.06, z - 0.01), V(x1 - 0.07, 2.53, z - 0.01), V(x0 + 0.07, 2.53, z - 0.01),
           Mat("plain", color=(0.86, 0.8, 0.66), glow=0.3))
    dx0, dx1 = x0 + 0.07, x1 - 0.07
    b.box((dx0, 0.1, z - 0.02), (dx1, top, z + 0.03), JOINERY, skip=("back",))
    b.quad(V(dx0 + 0.08, 1.0, z + 0.032), V(dx1 - 0.08, 1.0, z + 0.032), V(dx1 - 0.08, top - 0.12, z + 0.032), V(dx0 + 0.08, top - 0.12, z + 0.032), CLEAR)
    b.sphere(V(dx1 - 0.06, 1.0, z + 0.06), 0.028, GOLD, rings=4, segments=8)
    sw, sh = 1.6, 0.4
    b.box((-sw / 2, 2.75, 0), (sw / 2, 2.75 + sh, 0.08), JOINERY, skip=("back", "front"))
    b.poly([V(-sw / 2, 2.75, 0.08), V(sw / 2, 2.75, 0.08), V(sw / 2, 2.75 + sh, 0.08), V(-sw / 2, 2.75 + sh, 0.08)],
           Mat("plain", sign="fascia"), uvs=[(0, 0), (1, 0), (1, 1), (0, 1)])
    for side in (-1, 1):
        P.hanging_basket(b, side * 0.95, 3.0, 0.0, 0.4, seed=rnd.randrange(99))


# ---------------------------------------------------------------------------------------------
# Torhaus: Backstein mit hellem Rundbogen, gewölbte Durchfahrt, Schildband, Fachwerk darüber
# ---------------------------------------------------------------------------------------------

def build_gatehouse(name, spec):
    rnd = random.Random(spec["seed"])
    b = S.Builder(name)
    W, D, E = spec["width"], spec["depth"], spec["eaves"]
    w = W / 2
    a = spec["passage_width"] / 2
    spring = spec["arch_spring"]
    mh = spec["masonry_height"]
    band = spec["sign_band_height"]
    top = mh + band
    brick = wall_mat("brick")
    segs = 18
    arch = [(-a * math.cos(math.pi * k / segs), spring + a * math.sin(math.pi * k / segs)) for k in range(segs + 1)]
    # Front (z=0) und Rückseite (z=-D): Pfeiler und Zwickel um den Bogen
    for z, out in ((0.0, 1), (-D, -1)):
        b.face([V(-w, 0, z), V(-a, 0, z), V(-a, top, z), V(-w, top, z)], brick, (0, 0, out))
        b.face([V(a, 0, z), V(w, 0, z), V(w, top, z), V(a, top, z)], brick, (0, 0, out))
        for k in range(segs):
            (px, py), (qx, qy) = arch[k], arch[k + 1]
            b.face([V(px, py, z), V(qx, qy, z), V(qx, top, z), V(px, top, z)], brick, (0, 0, out))
        # Bogensteine (hell), Schlussstein, Kämpfer
        ring = 0.42
        for k in range(segs):
            (px, py), (qx, qy) = arch[k], arch[k + 1]
            ang0, ang1 = math.pi * k / segs, math.pi * (k + 1) / segs
            ox0, oy0 = -(a + ring) * math.cos(ang0), spring + (a + ring) * math.sin(ang0)
            ox1, oy1 = -(a + ring) * math.cos(ang1), spring + (a + ring) * math.sin(ang1)
            g = 0.012
            pts = [V(px, py, z), V(qx, qy, z), V(ox1, oy1, z), V(ox0, oy0, z)]
            cx = sum(p.x for p in pts) / 4
            cy = sum(p.y for p in pts) / 4
            pts = [V(cx + (p.x - cx) * (1 - g * 4), cy + (p.y - cy) * (1 - g * 4), z + out * 0.05) for p in pts]
            b.slab(pts if out > 0 else pts[::-1], 0.05, TRIM)
        kz = z + out * 0.09
        ky = spring + a
        b.slab([V(-0.2, ky - 0.05, kz), V(0.2, ky - 0.05, kz), V(0.26, ky + 0.55, kz), V(-0.26, ky + 0.55, kz)][::(1 if out > 0 else -1)], 0.09, TRIM)
        for side in (-1, 1):
            lo, hi = sorted((side * a, side * (a + 0.5)))
            b.box((lo, spring - 0.2, min(z, z + out * 0.07)), (hi, spring, max(z, z + out * 0.07)), TRIM)
            # Helle Steine an den Bogenseiten bis zum Boden (abwechselnd lang und kurz)
            yy = 0.0
            kk = 0
            while yy + 0.2 < spring - 0.2:
                hgt = min(0.34, spring - 0.2 - yy)
                lo2, hi2 = sorted((side * a, side * (a + (0.46 if kk % 2 == 0 else 0.3))))
                b.box((lo2, yy + 0.01, min(z, z + out * 0.05)), (hi2, yy + hgt - 0.01, max(z, z + out * 0.05)), TRIM)
                yy += hgt
                kk += 1
        # Ecksteine
        y = 0.35
        k = 0
        while y + 0.3 < mh:
            for side in (-1, 1):
                lo, hi = sorted((side * w, side * (w - (0.5 if k % 2 == 0 else 0.3))))
                b.box((lo, y, min(z, z + out * 0.04)), (hi, y + 0.28, max(z, z + out * 0.04)), TRIM)
            y += 0.31
            k += 1
        b.box((-w, 0, min(z, z + out * 0.035)), (-a, 0.35, max(z, z + out * 0.035)), PLINTH)
        b.box((a, 0, min(z, z + out * 0.035)), (w, 0.35, max(z, z + out * 0.035)), PLINTH)
    # Seitenwände
    for side in (-1, 1):
        b.face([V(side * w, 0, 0), V(side * w, 0, -D), V(side * w, top, -D), V(side * w, top, 0)], brick, (side, 0, 0))
    # Durchfahrt: Wände bis zum Kämpfer und Gewölbe durchgehend aus hellem Stein
    light_stone = Mat("stone", color=(0.8, 0.76, 0.66))
    for side in (-1, 1):
        b.face([V(side * a, 0, 0), V(side * a, 0, -D), V(side * a, spring, -D), V(side * a, spring, 0)], light_stone, (-side, 0, 0))
    vault = light_stone
    # Gewölbe weich schattiert (Normale je Ecke zur Bogenmitte), sonst wirkt es streifig
    for k in range(segs):
        (px, py), (qx, qy) = arch[k], arch[k + 1]
        np_ = V(-px, spring - py, 0).normalized()
        nq = V(-qx, spring - qy, 0).normalized()
        pts = [V(px, py, 0), V(qx, qy, 0), V(qx, qy, -D), V(px, py, -D)]
        nrm = [np_, nq, nq, np_]
        n = (pts[1] - pts[0]).cross(pts[2] - pts[0])
        if n.dot(np_ + nq) < 0:
            pts, nrm = pts[::-1], nrm[::-1]
        b.poly(pts, vault, normals=nrm)
    # Wandlaternen links und rechts vom Bogen an der Vorderwand
    for side in (-1, 1):
        P.wall_lantern(b, side * (a + 0.95), spring + 1.0, 0.05)
    # Laternen im Bogen
    for side in (-1, 1):
        lx = side * (a - 0.02)
        b.box((lx - 0.12, spring - 0.1, -1.0), (lx + 0.12, spring + 0.3, -0.8), IRON)
        b.box((lx - 0.1, spring - 0.08, -0.98), (lx + 0.1, spring + 0.28, -0.82), Mat("plain", color=(1.0, 0.85, 0.55), glow=1.0))
    # Schildband mit Bild (vorn)
    b.box((-w, mh, 0), (w, top, 0.1), JOINERY, skip=("back", "front"))
    b.face([V(-w, mh, 0.1), V(w, mh, 0.1), V(w, top, 0.1), V(-w, top, 0.1)], JOINERY, (0, 0, 1))
    sw = 4.6
    b.poly([V(-sw / 2, mh + 0.04, 0.102), V(sw / 2, mh + 0.04, 0.102), V(sw / 2, top - 0.04, 0.102), V(-sw / 2, top - 0.04, 0.102)],
           Mat("plain", sign="fascia"), uvs=[(0, 0), (1, 0), (1, 1), (0, 1)])
    b.box((-w, mh, -D - 0.1), (w, top, -D), JOINERY, skip=("front",))
    # Obergeschoss in Fachwerk, vorkragend
    jetty = spec["jetty"]
    up_spec = dict(spec, wall="render", upper_wall="render", lintel="timber", panes="casement", frame_cream=False)
    for z0, out in ((jetty, 1), (-D - jetty, -1)):
        b.push(b.move(0, 0, z0) @ (b.turn_y(0) if out > 0 else b.turn_y(180)))
        holes = []
        xs = [-3.2, -1.1, 1.1, 3.2]
        for x in xs:
            holes.append((x - 0.5, top + 0.6, x + 0.5, top + 0.6 + 1.4))
        b.wall_with_holes(-w, w, top, E, 0.0, holes, wall_mat("render"), reveal=0.12)
        timber_frame(b, -w, w, top, E, holes, rnd)
        for x0, y0, x1, y1 in holes:
            window_unit(b, up_spec, (x0 + x1) / 2, y0, x1 - x0, y1 - y0, "casement", rnd.choice(["closed", "nets", "dim"]),
                        (x0 - 0.3, x1 + 0.3, top + 0.1, E - 0.2, 0.8), rnd, reveal=0.12, lintel="timber", floor=1)
            if out > 0:
                P.flower_box(b, x0 - 0.04, x1 + 0.04, y0 + 0.005, 0.0, 0.18, ACCENT, ["rose", "white"], seed=rnd.randrange(999))
        b.face([V(-w, top, 0), V(w, top, 0), V(w, top, -jetty), V(-w, top, -jetty)], TIMBER, (0, -1, 0))
        n = int(W / 0.5)
        for k in range(n + 1):
            bx = -w + 0.08 + (W - 0.16) * k / n
            b.box((bx - 0.06, top - 0.16, -jetty), (bx + 0.06, top, 0.02), TIMBER)
        b.pop()
    for side in (-1, 1):
        b.face([V(side * w, top, jetty), V(side * w, top, -D - jetty), V(side * w, E, -D - jetty), V(side * w, E, jetty)], wall_mat("render"), (side, 0, 0))
    # Dach: Satteldach (First parallel zur Straße), Giebel an den Seiten, Gaube
    fz = jetty + 0.3
    bz = -D - jetty - 0.3
    ridge_z = -D / 2
    rise = (fz - ridge_z) * math.tan(math.radians(spec["pitch"]))
    ry = E + rise
    rm = ROOF_MATS[spec["roof_mat"]]
    # Dachflächen als Platten (auch von unten geschlossen)
    b.slab([V(-w - 0.2, E, fz), V(w + 0.2, E, fz), V(w + 0.2, ry, ridge_z), V(-w - 0.2, ry, ridge_z)], 0.07, rm)
    b.slab([V(w + 0.2, E, bz), V(-w - 0.2, E, bz), V(-w - 0.2, ry, ridge_z), V(w + 0.2, ry, ridge_z)], 0.07, rm)
    for side in (-1, 1):
        b.face([V(side * w, E, jetty), V(side * w, E, -D - jetty), V(side * w, ry - 0.05, ridge_z)], wall_mat("render"), (side, 0, 0))
    b.cylinder(V(-w - 0.2, ry + 0.02, ridge_z), 0.09, W + 0.4, RIDGE, segments=8, caps=(True, True), axis="x")
    for z0, out in ((fz, 1), (bz, -1)):
        b.box((-w - 0.2, E - 0.2, min(z0, z0 - out * 0.3)), (w + 0.2, E, max(z0, z0 - out * 0.3)), TIMBER)
    dspec = dict(spec, roof_front_z=fz, depth=D, eaves=E)
    dspec["depth"] = 2 * (fz - ridge_z)
    b.push(b.move(0, 0, 0))
    _dormer(b, dict(dspec, panes="casement"), 0.0, rnd, gw=0.55)
    b.pop()
    chimney(b, w - 0.8, ridge_z, ry - 0.8, ry + 1.0, pots=3)
    return b
