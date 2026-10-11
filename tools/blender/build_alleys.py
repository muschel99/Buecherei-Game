"""Baut die Gassen-Modelle (seit Etappe 4g, Inspiration: drei Bilder in Game design/Inspiration).

Aufruf (Terminal, im Projektordner):
    godot --headless --path . res://scenes/tools/export_layout.tscn      (Lage aus dem Spiel)
    blender -b --factory-startup --python tools/blender/build_alleys.py

Ergebnis (Koordinaten wie unter "Outside" im Spiel, y = 0 = Gehweg):
    assets/models/world/alley_library.glb   Gasse neben der Bücherei: hohe Hauswände (Rückseiten
                                            der Häuser), am Ende ein kleiner Garten mit Baum und
                                            runder Bank, dahinter angedeutete Häuser
    assets/models/world/alley_opposite.glb  Kleine Gasse gegenüber: verläuft sich hinter ihrem Ende
                                            zwischen Steinbögen
    assets/models/source/alleys.blend       zum Anschauen
Die Kollisionen (Wände, Ende) baut das Spiel selbst (Alley, OppositeAlley); Baum und Bank
bringen eigene Kollisionen mit ("-colonly").
"""

import bpy
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import style_lib as S  # noqa: E402
import style_parts as P  # noqa: E402
import style_plants as PL  # noqa: E402
import street_houses as H  # noqa: E402
from style_lib import Mat, V  # noqa: E402

LAYOUT = json.load(open(os.path.join(S.ROOT, "assets", "models", "source", "layout.json")))
OUT = os.path.join(S.ROOT, "assets", "models", "world")

BRICKS = [Mat("brick", color=(0.58, 0.34, 0.26)), Mat("brick", color=(0.5, 0.3, 0.24)), Mat("brick", color=(0.64, 0.42, 0.32))]
RENDER = Mat("render", color=(0.86, 0.82, 0.72))
RUBBLE = Mat("stone", color=(0.72, 0.6, 0.44))
RUBBLE_DARK = Mat("stone", color=(0.6, 0.5, 0.38))
SLATE = Mat("slate")
WOOD = Mat("timber", color=(1.25, 1.15, 1.0))
GRASS = Mat("foliage", color=(0.36, 0.46, 0.24))
SOIL = Mat("plain", color=(0.24, 0.19, 0.14))
FLAG = Mat("paving", color=(1.0, 0.98, 0.94))
SPEC = {"lintel": "flat", "sill": "stone", "frame_cream": True, "wall": "brick"}


def _local_blocks(b, parts):
    """Ecken (Welt-Koordinaten) als Kästen (lo, hi) in den aktuellen Bau-Koordinaten von b."""
    inv = b.xf.inverted()
    out = []
    for p0, p1 in parts:
        corners = [inv @ V(x, y, z) for x in (p0.x, p1.x) for y in (p0.y, p1.y) for z in (p0.z, p1.z)]
        out.append((V(min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)),
                    V(max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners))))
    return out


def house_back(b, a, c, height, mat, rnd, windows=True, roof=True, pipes=True, ivy_roots=(), ivy_holes=(), parts=None):
    """Rückwand eines Hauses von a nach c (x, z), Vorderseite zeigt nach rechts der Linie a→c
    gesehen von oben (in die Gasse). Mit kleinen Fenstern, Fallrohr, Traufe und Dachansatz.
    ivy_roots = Stellen (entlang der Wand, Mitte = 0), an denen Efeu aus dem Boden wächst; er
    lässt Fenster, Fallrohr und ivy_holes (Rechtecke) frei. parts = Liste, in die die Ecken
    (Welt-Koordinaten) von Fensterbänken und Fallrohr kommen (für Töpfe davor)."""
    xf, ln = H._facade_xf(a, c)
    b.push(xf)
    half = ln / 2
    holes = []
    if windows:
        x = -half + rnd.uniform(0.8, 1.4)
        while x < half - 0.8:
            for y0 in (0.9, 3.9) if height > 5 else (0.9,):
                if rnd.random() < 0.7:
                    holes.append((x - 0.38, y0, x + 0.38, y0 + 1.25))
            x += rnd.uniform(2.2, 3.2)
    b.wall_with_holes(-half, half, 0.0, height, 0.0, holes, mat, reveal=0.12)
    for x0, y0, x1, y1 in holes:
        H.window_unit(b, SPEC, (x0 + x1) / 2, y0, x1 - x0, y1 - y0, rnd.choice(["sash22", "sash66", "casement"]),
                      rnd.choice(["closed", "nets", "blind"]), (x0 - 0.2, x1 + 0.2, y0 - 0.5, y1 + 0.3, 0.5), rnd, reveal=0.12)
    if roof:
        b.box((-half, height - 0.18, 0.0), (half, height, 0.25), H.CREAM, skip=("back",))
        b.slab([V(-half + 0.003, height, 0.35), V(half - 0.003, height, 0.35), V(half - 0.003, height + 1.6, -1.6), V(-half + 0.003, height + 1.6, -1.6)],
               0.06, SLATE)
        b.cylinder(V(-half + 0.003, height + 0.02, 0.32), 0.05, ln - 0.006, H.LEAD, segments=6, caps=(True, True), axis="x")
    blocked = [(x0 - 0.2, y0 - 0.3, x1 + 0.2, y1 + 0.35) for x0, y0, x1, y1 in holes] + list(ivy_holes)
    pipe = None
    if pipes:
        # Fallrohr nur dort, wo es an keinem Fenster vorbeiläuft
        spots = [-half + 0.4 + 0.1 * k for k in range(int((ln - 0.8) / 0.1) + 1)]
        spots = [x for x in spots if all(x < x0 - 0.25 or x > x1 + 0.25 for x0, _, x1, _ in holes)]
        if spots:
            px = rnd.choice(spots)
            pipe = px
            # Endet oben im Traufbrett (nicht genau auf dessen Oberkante)
            b.cylinder(V(px, 0.0, 0.07), 0.04, height - (0.17 if roof else 0.0), H.LEAD, segments=8, caps=(True, True))
            blocked.append((px - 0.08, 0.0, px + 0.08, height + 1.0))
            if parts is not None:
                parts.append((xf @ V(px - 0.06, 0.0, 0.0), xf @ V(px + 0.06, height, 0.13)))
    if parts is not None:
        for x0, y0, x1, y1 in holes:
            # Fensterbank und Rahmen ragen etwas vor die Wand
            parts.append((xf @ V(x0 - 0.1, y0 - 0.2, 0.0), xf @ V(x1 + 0.1, y1 + 0.1, 0.2)))
    b.box((-half, 0.0, 0.0), (half, 0.28, 0.03), H.PLINTH, skip=("back", "bottom"))
    for x in ivy_roots:
        PL.ivy_wall(b, x, 0.0, min(height - 0.6, 4.2), rnd, x_min=-half + 0.05, x_max=half - 0.05, holes=blocked, stems=6,
                    spread=1.1, bumps=[(-half, 0.0, half, 0.32, 0.03)])
    b.pop()
    return pipe


def tree(b, x, z, rnd, height=5.8, space=None):
    """Laubbaum wie in der Vorlage (style_plants.tree): Stamm mit Rinde, Äste, dichte Krone aus
    Laubzweigen; space hält die Krone aus den Mauern."""
    PL.tree(b, V(x, 0.0, z), height, rnd, space or PL.NO_SPACE)
    b.colliders.append(((x - 0.3, 0, z - 0.3), (x + 0.3, 2.0, z + 0.3)))


def round_bench(b, x, z, rnd):
    """Runde Holzbank um den Stamm: Sitzring aus Latten, Lehne aus senkrechten Latten, Beine,
    zwei Kissen; daneben ein Hocker mit Tasse und Buch."""
    r_in, r_out, seat = 0.42, 0.95, 0.45
    n = 28
    for k in range(n):
        a0 = 2 * math.pi * k / n
        a1 = 2 * math.pi * (k + 0.8) / n
        pts = [V(x + r_in * math.cos(a0), seat, z + r_in * math.sin(a0)), V(x + r_out * math.cos(a0), seat, z + r_out * math.sin(a0)),
               V(x + r_out * math.cos(a1), seat, z + r_out * math.sin(a1)), V(x + r_in * math.cos(a1), seat, z + r_in * math.sin(a1))]
        b.face(pts, WOOD, (0, 1, 0))
        b.face([V(p.x, seat - 0.04, p.z) for p in pts], WOOD, (0, -1, 0))
        am = (a0 + a1) / 2
        b.face([V(x + r_out * math.cos(a0), seat - 0.04, z + r_out * math.sin(a0)), V(x + r_out * math.cos(a1), seat - 0.04, z + r_out * math.sin(a1)),
                V(x + r_out * math.cos(a1), seat, z + r_out * math.sin(a1)), V(x + r_out * math.cos(a0), seat, z + r_out * math.sin(a0))],
               WOOD, (math.cos(am), 0, math.sin(am)))
        # Lehne: Latte am inneren Rand
        bx, bz = x + (r_in + 0.03) * math.cos(am), z + (r_in + 0.03) * math.sin(am)
        b.push(b.move(bx, 0, bz) @ b.turn_y(-math.degrees(am) + 90))
        b.box((-0.035, seat, -0.015), (0.035, seat + 0.45, 0.015), WOOD)
        b.pop()
    ring = [V(x + (r_in + 0.03) * math.cos(a), seat + 0.45, z + (r_in + 0.03) * math.sin(a)) for a in [2 * math.pi * k / 24 for k in range(25)]]
    b.tube(ring, 0.025, WOOD, segments=5, caps=False)
    for k in range(8):
        a = 2 * math.pi * k / 8
        for r in (r_in + 0.05, r_out - 0.06):
            b.box((x + r * math.cos(a) - 0.03, 0, z + r * math.sin(a) - 0.03), (x + r * math.cos(a) + 0.03, seat - 0.04, z + r * math.sin(a) + 0.03), WOOD)
    for k, (a, c) in enumerate(((0.4, (0.86, 0.84, 0.76)), (1.0, (0.5, 0.58, 0.46)))):
        cx, cz = x + 0.62 * math.cos(a), z + 0.62 * math.sin(a)
        b.push(b.move(cx, seat, cz) @ b.turn_y(-math.degrees(a) + 90))
        b.box((-0.2, 0.0, -0.06), (0.2, 0.36, 0.06), Mat("fabric", color=c))
        b.pop()
    sx, sz = x + 1.35 * math.cos(0.7), z + 1.35 * math.sin(0.7)
    b.box((sx - 0.22, 0.38, sz - 0.16), (sx + 0.22, 0.42, sz + 0.16), WOOD)
    for dx in (-0.18, 0.18):
        for dz in (-0.12, 0.12):
            b.box((sx + dx - 0.02, 0, sz + dz - 0.02), (sx + dx + 0.02, 0.38, sz + dz + 0.02), WOOD)
    b.cylinder(V(sx - 0.08, 0.42, sz), 0.04, 0.08, Mat("plain", color=(0.94, 0.92, 0.86)), segments=8)
    b.box((sx + 0.0, 0.42, sz - 0.08), (sx + 0.16, 0.45, sz + 0.06), Mat("plain", color=(0.4, 0.5, 0.42)))
    # Kollision: zwei Kästen über Kreuz (fast rund, die Ecken stehen kaum über)
    b.colliders.append(((x - r_out, 0, z - 0.55), (x + r_out, 0.5, z + 0.55)))
    b.colliders.append(((x - 0.55, 0, z - r_out), (x + 0.55, 0.5, z + r_out)))
    b.colliders.append(((sx - 0.24, 0, sz - 0.18), (sx + 0.24, 0.45, sz + 0.18)))


def shrub(b, x, z, rnd, size=0.45, palette=None, space=None):
    """Strauch (style_plants.shrub); mit palette Blütenbälle obenauf."""
    PL.shrub(b, V(x, 0.0, z), size * 1.1, size * 1.7, rnd, palette if palette in PL.BLOSSOMS else None, space or PL.NO_SPACE)


def hosta(b, x, z, rnd, space=None):
    """Funkie oder Farn im Beet."""
    if rnd.random() < 0.6:
        PL.hosta(b, V(x, 0.0, z), rnd.uniform(0.4, 0.5), rnd, space or PL.NO_SPACE)
    else:
        PL.fern(b, V(x, 0.0, z), rnd.uniform(0.5, 0.65), rnd, space or PL.NO_SPACE)


def brick_wall(b, x0, x1, z0, z1, height, mat):
    """Schlichte, hohe Backsteinwand (Kasten) mit Abdeckung – schließt Lücken zwischen Häusern."""
    b.box((x0, 0.0, z0), (x1, height, z1), mat)
    b.box((x0 - 0.04, height, z0), (x1 + 0.04, height + 0.12, z1), RUBBLE_DARK, skip=("bottom",))


def library_alley():
    L = LAYOUT
    rnd = random.Random(31)
    b = S.Builder("alley_library")
    lx, fx = L["library_x"], L["far_x"]
    end = L["alley_end_z"]
    gz = end - L["garden_depth"]
    gx = fx - L["garden_extra_width"]
    h = L["wall_height"]
    # Hauswände: Bücherei-Seite (hinter der Bücherei), gegenüber bis zum Garten, Garten rundherum
    # Richtung a → c so, dass die Vorderseite in die Gasse bzw. den Garten zeigt
    lib_parts, far_parts = [], []
    lib_pipe = house_back(b, (lx, L["library_back_z"]), (lx, end + 0.6), h, BRICKS[0], rnd, parts=lib_parts)
    if lib_pipe is not None:
        # Rohr in Welt-z (Wand läuft von library_back_z bis end + 0,6 in +z)
        lib_pipe += (L["library_back_z"] + end + 0.6) / 2
    house_back(b, (fx, gz), (fx, L["neighbor_back_z"]), h, BRICKS[1], rnd, parts=far_parts)
    house_back(b, (gx, gz), (fx, gz), h - 0.6, RENDER, rnd)
    house_back(b, (gx, end + 0.6), (gx, gz), h - 0.4, BRICKS[2], rnd)
    # Hinten: niedriger Holzzaun, dahinter angedeutete Häuser mit Giebeln
    fz = end + 0.15
    for x in [gx + 0.1 + k * 0.12 for k in range(int((lx - gx) / 0.12))]:
        b.box((x, 0, fz), (x + 0.09, 1.25, fz + 0.03), Mat("timber", color=(1.1, 1.05, 0.95)))
    for y in (0.3, 1.0):
        b.box((gx, y, fz + 0.03), (lx, y + 0.08, fz + 0.06), Mat("timber", color=(1.1, 1.05, 0.95)))
    bz = end + 2.5
    # Zwischen den Seitenwänden und den Häusern hinter dem Zaun: Backsteinwände bis an die
    # Häuser (sonst sieht man hinten seitlich aus der Welt hinaus)
    brick_wall(b, lx, lx + 0.3, end + 0.6, bz + 0.05, h, BRICKS[0])
    brick_wall(b, gx - 0.3, gx, end + 0.6, bz + 0.05, h - 0.4, BRICKS[2])
    for k, (x0, x1, hh, mat) in enumerate(((gx - 1.0, (gx + lx) / 2, 6.6, BRICKS[1]), ((gx + lx) / 2, lx + 1.5, 7.3, RENDER))):
        house_back(b, (x1, bz), (x0, bz), hh, mat, rnd, pipes=False)
        mx = (x0 + x1) / 2
        b.face([V(x0, hh, bz), V(x1, hh, bz), V(mx, hh + 2.0, bz)], mat, (0, 0, -1))
        for s in (-1, 1):
            lo = V(x0 if s < 0 else x1, hh - 0.05, bz - 0.3)
            hi = V(mx, hh + 2.05, bz - 0.3)
            pts = [lo, hi, V(hi.x, hi.y, bz + 4.0), V(lo.x, lo.y, bz + 4.0)]
            b.slab(pts if s < 0 else pts[::-1], 0.06, Mat("clay_tile"))
    # Boden zwischen Zaun und Häusern (Sträucher) und Garten
    b.face([V(gx, 0.01, fz + 0.05), V(lx + 1.5, 0.01, fz + 0.05), V(lx + 1.5, 0.01, bz), V(gx, 0.01, bz)], GRASS, (0, 1, 0))
    # Hecke hinter dem Zaun: bleibt zwischen Zaun, Seitenmauern und den Häusern dahinter
    hedge = PL.Space().plane((0, 0, fz + 0.08), (0, 0, 1)).plane((0, 0, bz - 0.12), (0, 0, -1)) \
        .plane((gx, 0, 0), (1, 0, 0), gap=0.05).plane((lx, 0, 0), (-1, 0, 0), gap=0.05).floor(0.01)
    for x in [gx + 0.4 + k * 0.7 for k in range(int((lx - gx) / 0.7))]:
        shrub(b, x, fz + 1.0 + rnd.uniform(-0.3, 0.4), rnd, rnd.uniform(0.5, 0.75), rnd.choice([None, "hydrangea", "rose"]), space=hedge)
    b.face([V(gx, 0.005, gz), V(fx, 0.005, gz), V(fx, 0.005, end), V(gx, 0.005, end)], GRASS, (0, 1, 0))
    # Trittsteine von der Gasse zur Bank
    # Baum mit Bank: Lage wie im Spiel (StreetLayout.garden_tree – dort sitzen die Sitzplätze)
    tx, tz = L["garden_tree"]
    for k in range(5):
        px = fx + 0.2 - k * 0.55
        pz = tz + 0.9 + math.sin(k) * 0.25
        b.cylinder(V(px, 0.0, pz), rnd.uniform(0.2, 0.26), 0.02, FLAG, segments=9, caps=(True, False))
    # Beete: Abstand zu den Hauswänden (Fensterbänke stehen vor), nichts in Zaun und Bank
    garden = PL.Space().plane((gx, 0, 0), (1, 0, 0), gap=0.2).plane((0, 0, gz), (0, 0, 1), gap=0.2).plane((0, 0, fz - 0.03), (0, 0, -1)) \
        .plane((lx, 0, 0), (-1, 0, 0), gap=0.2).floor(0.01).cylinder(tx, tz, 1.0, -1.0, 0.95)
    tree(b, tx, tz, rnd, space=PL.Space().plane((gx, 0, 0), (1, 0, 0), gap=0.25).plane((lx, 0, 0), (-1, 0, 0), gap=0.25)
         .plane((0, 0, gz), (0, 0, 1), gap=0.25))
    round_bench(b, tx, tz, rnd)
    # Beete an den Rändern: Funkien, Farne, Hortensien, Buchs
    for k in range(9):
        a = rnd.random()
        px = gx + 0.45 + a * (fx - gx - 0.9)
        pz = gz + 0.5 if k % 2 == 0 else end - 0.5
        if k % 3:
            hosta(b, px, pz, rnd, space=garden)
        else:
            shrub(b, px, pz, rnd, 0.5, rnd.choice(["hydrangea", "white", "rose"]), space=garden)
    for pz in (gz + 1.2, gz + 2.6, gz + 4.2, end - 0.6):
        hosta(b, gx + 0.45, pz, rnd, space=garden)
    # In der Gasse: ein paar Töpfe und eine Wandlaterne
    # Töpfe in unregelmäßigen Gruppen an der Wand der Bücherei (Rohr und Laterne bleiben frei)
    b.push(b.move(lx, 0, 0) @ b.turn_y(-90))
    for start, direction, count in ((5.25, 1, 3), (8.0, 1, 2)):
        if lib_pipe is not None and abs(start + direction * 0.5 - lib_pipe) < 0.9:
            start += 1.0 * direction
        PL.pot_cluster(b, start, rnd, direction=direction, count=count, depth=0.62, max_len=1.0, wall_z=0.035,
                       blocks=_local_blocks(b, lib_parts))
    b.pop()
    # Gegenüber an der Nachbarwand eine kleine Gruppe (lokal x = -Welt-z), nicht vor dem Fallrohr
    b.push(b.move(fx, 0, 0) @ b.turn_y(90))
    blocks = _local_blocks(b, far_parts)
    start = -7.6
    while any(lo.x - 0.75 < start < hi.x + 0.05 and lo.y < 0.5 for lo, hi in blocks) and start < -5.0:
        start += 0.2
    PL.pot_cluster(b, start, rnd, direction=1, count=2, depth=0.5, max_len=0.8, wall_z=0.035, blocks=blocks)
    b.pop()
    b.push(b.move(lx, 0, 7.8) @ b.turn_y(-90))
    P.wall_lantern(b, 0.0, 2.7, 0.0)
    b.pop()
    return b


def arch(b, x0, x1, z, depth, spring, top, mat, rnd):
    """Steinbogen über der Gasse (Bogen zwischen x0 und x1, Kämpfer bei spring), darüber Mauer
    bis top; dick wie depth (von z nach -z)."""
    a = (x1 - x0) / 2
    cx = (x0 + x1) / 2
    segs = 12
    pts = [(cx - a * math.cos(math.pi * k / segs), spring + a * math.sin(math.pi * k / segs)) for k in range(segs + 1)]
    for zz, out in ((z, 1), (z - depth, -1)):
        for k in range(segs):
            (px, py), (qx, qy) = pts[k], pts[k + 1]
            b.face([V(px, py, zz), V(qx, qy, zz), V(qx, top, zz), V(px, top, zz)], mat, (0, 0, out))
        for k in range(segs):
            (px, py), (qx, qy) = pts[k], pts[k + 1]
            ox0, oy0 = cx - (a + 0.3) * math.cos(math.pi * k / segs), spring + (a + 0.3) * math.sin(math.pi * k / segs)
            ox1, oy1 = cx - (a + 0.3) * math.cos(math.pi * (k + 1) / segs), spring + (a + 0.3) * math.sin(math.pi * (k + 1) / segs)
            q = [V(px, py, zz + out * 0.04), V(qx, qy, zz + out * 0.04), V(ox1, oy1, zz + out * 0.04), V(ox0, oy0, zz + out * 0.04)]
            b.face(q, RUBBLE_DARK if k % 2 else RUBBLE, (0, 0, out))
    for k in range(segs):
        (px, py), (qx, qy) = pts[k], pts[k + 1]
        mx, my = (px + qx) / 2, (py + qy) / 2
        b.face([V(px, py, z + 0.04), V(qx, qy, z + 0.04), V(qx, qy, z - depth - 0.04), V(px, py, z - depth - 0.04)], RUBBLE_DARK,
               (cx - mx, spring - my, 0))


def opposite_alley():
    L = LAYOUT
    rnd = random.Random(47)
    b = S.Builder("alley_opposite")
    x0, x1 = L["opposite_alley_x0"], L["opposite_alley_x1"]
    z0 = L["opposite_end_z"] + 0.2
    z_end = L["opposite_end_z"] - L["opposite_back_depth"]
    h = 6.5
    # Den Boden (großes Kopfsteinpflaster bis hinten) legt das Spiel selbst (OppositeAlley)
    # Wände aus Bruchstein (hoch, wie Häuser), mit kleinen Fenstern, Efeu, Schild
    # Efeu an der linken Wand: lässt die Bögen frei (lokal x = Mitte der Wand - Welt-z)
    mid = (z0 + z_end) / 2
    arch_holes = [(mid - zz - 0.15, 0.0, mid - zz + 0.75, h) for zz in (z0 - 2.5, z0 - 6.5, z0 - 10.0)]
    # Wo links Töpfe stehen, wächst kein Efeu am Boden
    arch_holes += [(mid - pz - 0.6, 0.0, mid - pz + 0.6, 0.9) for pz in (z0 - 1.5, z0 - 5.6, z0 - 9.4)]
    wall_parts = []
    for xw, face in ((x0, 1), (x1, -1)):
        a, c = ((xw, z0), (xw, z_end)) if face > 0 else ((xw, z_end), (xw, z0))
        house_back(b, a, c, h, RUBBLE, rnd, windows=True, roof=False, pipes=False,
                   ivy_roots=(mid - (z0 - 3.5), mid - (z0 - 7.6)) if face > 0 else (), ivy_holes=arch_holes, parts=wall_parts)
    # Drei Bögen, der hinterste etwas tiefer
    for k, zz in enumerate((z0 - 2.5, z0 - 6.5, z0 - 10.0)):
        arch(b, x0, x1, zz, 0.6, 2.4 + 0.1 * k, h, RUBBLE, rnd)
    # Ende: Wand mit Tür und Laterne (warm beleuchtet), damit man nicht ins Leere schaut
    b.face([V(x0, 0, z_end), V(x1, 0, z_end), V(x1, h, z_end), V(x0, h, z_end)], RUBBLE, (0, 0, 1))
    dx = (x0 + x1) / 2
    b.box((dx - 0.45, 0.0, z_end), (dx + 0.45, 2.1, z_end + 0.05), Mat("timber", color=(0.9, 0.75, 0.6)))
    b.box((dx - 0.55, 2.1, z_end), (dx + 0.55, 2.25, z_end + 0.08), RUBBLE_DARK)
    P.wall_lantern(b, dx + 0.75, 2.6, z_end)
    b.box((x0 + 0.02, 0, z_end + 1.6), (x0 + 0.04, 6.0, z_end + 1.7), Mat("plain", color=(1.0, 0.9, 0.7), glow=0.15))
    # Ein paar kleine Töpfe dicht an den Wänden (Passanten kommen hier durch)
    # Töpfe in Gruppen an beiden Wänden (Pflanzlöcher des Efeus und die Mitte bleiben frei)
    for wall_x, turn, starts in ((x0, 90, ((z0 - 1.05, -1, 2), (z0 - 5.1, -1, 3), (z0 - 9.2, -1, 1))),
                                 (x1, -90, ((z0 - 2.9, -1, 1), (z0 - 8.3, -1, 2)))):
        b.push(b.move(wall_x, 0, 0) @ b.turn_y(turn))
        for zz, direction, count in starts:
            # lokal x läuft bei turn 90 entgegen Welt-z, bei -90 mit Welt-z
            lx_ = -zz if turn == 90 else zz
            d_ = direction if turn == -90 else -direction
            PL.pot_cluster(b, lx_, rnd, direction=d_, count=count, depth=0.44, max_len=0.9, wall_z=0.035,
                           blocks=[blk for blk in _local_blocks(b, wall_parts) if blk[0].z > -0.1])
        b.pop()
    return b


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    os.makedirs(OUT, exist_ok=True)
    check = "--check" in sys.argv
    if check:
        S.SHOW_BACKFACES = True
    for func, name in ((library_alley, "alley_library"), (opposite_alley, "alley_opposite")):
        b = func()
        glb = os.path.join(OUT, name + ".glb")
        tris = S.write_glb(b, glb)
        S.write_import_settings(glb)
        print("%s: %d Dreiecke" % (name, tris))
        S.to_blender(b, {"wall": (0.6, 0.35, 0.27), "door": (0.2, 0.25, 0.3), "accent": (0.2, 0.3, 0.25)})
    blend = os.path.join(S.ROOT, "assets", "models", "source", "alleys.blend")
    if check:
        S.setup_render(resolution=(900, 700), samples=10)
        L = LAYOUT
        out = os.path.join(S.ROOT, "screenshots", "blender")
        cx = (L["library_x"] + L["far_x"]) / 2
        S.render_view(os.path.join(out, "alley-lib1.png"), (cx, 1.6, L["alley_start_z"] + 1.0), (cx, 2.0, L["alley_end_z"]), lens=24)
        S.render_view(os.path.join(out, "alley-lib2.png"), (cx + 0.6, 1.6, L["alley_end_z"] - 7.5), (cx - 2.5, 1.5, L["alley_end_z"] - 2.0), lens=22)
        S.render_view(os.path.join(out, "alley-lib3.png"), (cx, 9.0, L["alley_start_z"] - 3.0), (cx - 1.5, 2.0, L["alley_end_z"] - 3.0), lens=24)
        ox = (L["opposite_alley_x0"] + L["opposite_alley_x1"]) / 2
        S.render_view(os.path.join(out, "alley-opp1.png"), (ox, 1.6, L["opposite_front_z"] + 0.5), (ox, 1.8, L["opposite_end_z"] - 8.0), lens=24)
        S.render_view(os.path.join(out, "alley-opp2.png"), (ox, 1.6, L["opposite_end_z"] + 0.6), (ox, 2.0, L["opposite_end_z"] - 10.0), lens=24)
    bpy.ops.wm.save_as_mainfile(filepath=blend, relative_remap=True, compress=True)


if __name__ == "__main__":
    main()
