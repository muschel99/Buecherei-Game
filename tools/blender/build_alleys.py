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
SETTS = Mat("setts", color=(1.05, 1.0, 0.95))
SPEC = {"lintel": "flat", "sill": "stone", "frame_cream": True, "wall": "brick"}


def house_back(b, a, c, height, mat, rnd, windows=True, roof=True, pipes=True):
    """Rückwand eines Hauses von a nach c (x, z), Vorderseite zeigt nach rechts der Linie a→c
    gesehen von oben (in die Gasse). Mit kleinen Fenstern, Fallrohr, Traufe und Dachansatz."""
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
        b.slab([V(-half, height, 0.35), V(half, height, 0.35), V(half, height + 1.6, -1.6), V(-half, height + 1.6, -1.6)], 0.06, SLATE)
        b.cylinder(V(-half, height + 0.02, 0.32), 0.05, ln, H.LEAD, segments=6, caps=(True, True), axis="x")
    if pipes:
        px = -half + rnd.uniform(0.4, ln - 0.4)
        b.cylinder(V(px, 0.0, 0.07), 0.04, height, H.LEAD, segments=8, caps=(True, True))
    b.box((-half, 0.0, 0.0), (half, 0.28, 0.03), H.PLINTH, skip=("back", "bottom"))
    b.pop()


def tree(b, x, z, rnd, height=5.8):
    """Laubbaum wie in der Vorlage: kräftiger Stamm, der sich in Äste teilt, lockere Krone aus
    vielen Laubbüscheln."""
    bark = Mat("timber", color=(0.75, 0.68, 0.6))
    trunk_top = 2.2
    b.tube([V(x, 0, z), V(x + 0.05, 1.0, z), V(x - 0.04, trunk_top, z + 0.03)], lambda t: 0.26 - 0.08 * t, bark, segments=10)
    for k in range(5):
        r = 0.25 + 0.2 * (k % 2)
        b.sphere(V(x + r * math.cos(k * 1.3), 0.05, z + r * math.sin(k * 1.3)), 0.12, bark, rings=3, segments=6, squash=0.5)
    tips = []
    for k in range(6):
        a = 2 * math.pi * k / 6 + rnd.uniform(-0.3, 0.3)
        spread = rnd.uniform(1.2, 2.0)
        top = height - rnd.uniform(0.3, 1.4)
        mid = V(x + math.cos(a) * spread * 0.4, trunk_top + 1.1, z + math.sin(a) * spread * 0.4)
        tip = V(x + math.cos(a) * spread, top, z + math.sin(a) * spread)
        b.tube([V(x, trunk_top - 0.2, z), mid, tip], lambda t: 0.14 - 0.11 * t, bark, segments=6)
        tips.append(tip)
        for j in range(2):
            a2 = a + rnd.uniform(-0.8, 0.8)
            twig = tip + V(math.cos(a2) * 0.6, rnd.uniform(-0.2, 0.4), math.sin(a2) * 0.6)
            b.tube([mid + (tip - mid) * 0.6, twig], 0.03, bark, segments=4)
            tips.append(twig)
    greens = [Mat("foliage", color=c) for c in ((0.42, 0.52, 0.28), (0.34, 0.46, 0.22), (0.5, 0.58, 0.32))]
    for tip in tips:
        for j in range(3):
            p = tip + V(rnd.uniform(-0.5, 0.5), rnd.uniform(-0.3, 0.4), rnd.uniform(-0.5, 0.5))
            b.sphere(p, rnd.uniform(0.45, 0.75), rnd.choice(greens), rings=5, segments=9, jitter=0.25, seed=rnd.randrange(9999))
    b.sphere(V(x, height - 0.4, z), 1.1, greens[1], rings=6, segments=10, jitter=0.3, seed=rnd.randrange(9999))
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
    b.colliders.append(((x - r_out, 0, z - r_out), (x + r_out, 0.5, z + r_out)))
    b.colliders.append(((sx - 0.24, 0, sz - 0.18), (sx + 0.24, 0.45, sz + 0.18)))


def shrub(b, x, z, rnd, size=0.45, palette=None):
    b.sphere(V(x, size * 0.7, z), size, P.leaf(rnd.randrange(3)), rings=5, segments=9, squash=0.8, jitter=0.2, seed=rnd.randrange(9999))
    if palette:
        P.blossom_cluster(b, (x, size * 0.75, z), size, palette, rnd, count=int(size * 30))


def hosta(b, x, z, rnd):
    """Funkie / Farn: ein Kranz aus Blättern."""
    m = Mat("foliage", color=rnd.choice([(0.36, 0.5, 0.24), (0.46, 0.56, 0.3), (0.3, 0.42, 0.22)]))
    for k in range(9):
        a = 2 * math.pi * k / 9 + rnd.uniform(-0.2, 0.2)
        tip = V(x + 0.42 * math.cos(a), 0.3 + rnd.uniform(-0.05, 0.1), z + 0.42 * math.sin(a))
        b.tube([V(x, 0.02, z), V(x + 0.2 * math.cos(a), 0.4, z + 0.2 * math.sin(a)), tip], lambda t: 0.05 + 0.05 * math.sin(math.pi * t), m, segments=4)


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
    house_back(b, (lx, L["library_back_z"]), (lx, end + 0.6), h, BRICKS[0], rnd)
    house_back(b, (fx, gz), (fx, L["neighbor_back_z"]), h, BRICKS[1], rnd)
    house_back(b, (gx, gz), (fx, gz), h - 0.6, RENDER, rnd)
    house_back(b, (gx, end + 0.6), (gx, gz), h - 0.4, BRICKS[2], rnd)
    # Hinten: niedriger Holzzaun, dahinter angedeutete Häuser mit Giebeln
    fz = end + 0.15
    for x in [gx + 0.1 + k * 0.12 for k in range(int((lx - gx) / 0.12))]:
        b.box((x, 0, fz), (x + 0.09, 1.25, fz + 0.03), Mat("timber", color=(1.1, 1.05, 0.95)))
    for y in (0.3, 1.0):
        b.box((gx, y, fz + 0.03), (lx, y + 0.08, fz + 0.06), Mat("timber", color=(1.1, 1.05, 0.95)))
    bz = end + 2.5
    for k, (x0, x1, hh, mat) in enumerate(((gx - 1.0, (gx + lx) / 2, 6.6, BRICKS[1]), ((gx + lx) / 2, lx + 1.5, 7.3, RENDER))):
        house_back(b, (x1, bz), (x0, bz), hh, mat, rnd)
        mx = (x0 + x1) / 2
        b.face([V(x0, hh, bz), V(x1, hh, bz), V(mx, hh + 2.0, bz)], mat, (0, 0, -1))
        for s in (-1, 1):
            lo = V(x0 if s < 0 else x1, hh - 0.05, bz - 0.3)
            hi = V(mx, hh + 2.05, bz - 0.3)
            pts = [lo, hi, V(hi.x, hi.y, bz + 4.0), V(lo.x, lo.y, bz + 4.0)]
            b.slab(pts if s < 0 else pts[::-1], 0.06, Mat("clay_tile"))
    # Boden zwischen Zaun und Häusern (Sträucher) und Garten
    b.face([V(gx, 0.01, fz + 0.05), V(lx + 1.5, 0.01, fz + 0.05), V(lx + 1.5, 0.01, bz), V(gx, 0.01, bz)], GRASS, (0, 1, 0))
    for x in [gx + 0.4 + k * 0.7 for k in range(int((lx - gx) / 0.7))]:
        shrub(b, x, fz + 1.0 + rnd.uniform(-0.3, 0.4), rnd, rnd.uniform(0.5, 0.75), rnd.choice([None, "hydrangea", "rose"]))
    b.face([V(gx, 0.005, gz), V(fx, 0.005, gz), V(fx, 0.005, end), V(gx, 0.005, end)], GRASS, (0, 1, 0))
    # Trittsteine von der Gasse zur Bank
    tx, tz = (gx + fx) / 2 - 0.1, gz + L["garden_depth"] * 0.5
    for k in range(5):
        px = fx + 0.2 - k * 0.55
        pz = tz + 0.9 + math.sin(k) * 0.25
        b.cylinder(V(px, 0.0, pz), rnd.uniform(0.2, 0.26), 0.02, FLAG, segments=9, caps=(True, False))
    tree(b, tx, tz, rnd)
    round_bench(b, tx, tz, rnd)
    # Beete an den Rändern: Funkien, Farne, Hortensien, Buchs
    for k in range(9):
        a = rnd.random()
        px = gx + 0.45 + a * (fx - gx - 0.9)
        pz = gz + 0.5 if k % 2 == 0 else end - 0.5
        if k % 3:
            hosta(b, px, pz, rnd)
        else:
            shrub(b, px, pz, rnd, 0.5, rnd.choice(["hydrangea", "white", "rose"]))
    for pz in (gz + 1.2, gz + 2.6, gz + 4.2, end - 0.6):
        hosta(b, gx + 0.45, pz, rnd)
    # In der Gasse: ein paar Töpfe und eine Wandlaterne
    for pz in (6.5, 9.0):
        x = lx - 0.35
        b.cylinder(V(x, 0, pz), 0.17, 0.4, H.POT, segments=12, radius_top=0.2, caps=(False, True))
        shrub(b, x, pz, rnd, 0.28, rnd.choice(["rose", "lavender"]))
        b.colliders.append(((x - 0.22, 0, pz - 0.22), (x + 0.22, 0.8, pz + 0.22)))
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
    z_end = z0 - 13.0
    h = 6.5
    # Boden: Kopfsteinpflaster, das sich nach hinten zieht
    b.face([V(x0 - 0.05, 0.0, z0), V(x1 + 0.05, 0.0, z0), V(x1 + 0.05, 0.0, z_end), V(x0 - 0.05, 0.0, z_end)], SETTS, (0, 1, 0))
    # Wände aus Bruchstein (hoch, wie Häuser), mit kleinen Fenstern, Efeu, Schild
    for xw, face in ((x0, 1), (x1, -1)):
        a, c = ((xw, z0), (xw, z_end)) if face > 0 else ((xw, z_end), (xw, z0))
        house_back(b, a, c, h, RUBBLE, rnd, windows=True, roof=False, pipes=False)
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
    # Hängendes Holzschild und Laterne am zweiten Bogen, Pflanzen an den Wänden
    for k in range(6):
        pz = z0 - 1.0 - k * 1.9
        side = x0 + 0.3 if k % 2 == 0 else x1 - 0.3
        b.cylinder(V(side, 0, pz), 0.14, 0.32, H.POT, segments=10, radius_top=0.17, caps=(False, True))
        shrub(b, side, pz, rnd, 0.24, rnd.choice(["rose", "white", None]))
    # Efeu an der linken Wand (als Laubpolster an der Wand entlang)
    for k in range(14):
        pz = z0 - 0.5 - k * 0.75
        for j in range(int(rnd.uniform(1, 6))):
            b.sphere(V(x0 + 0.05, 0.4 + j * 0.55 + rnd.uniform(-0.1, 0.1), pz + rnd.uniform(-0.2, 0.2)), rnd.uniform(0.18, 0.28),
                     P.leaf(rnd.randrange(3)), rings=4, segments=7, squash=0.9, jitter=0.2, seed=rnd.randrange(9999))
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


main()
