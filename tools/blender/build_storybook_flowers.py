"""Blumenladen im Bilderbuch-Stil (Vorlagebild der Entwicklerin): cremefarbener Putz mit
Ecksteinen, Ladenfront in Farngrün mit dem Schild „Blumenladen“ (Bild der Entwicklerin), Tür mit
Rautenoberlicht, langer Pflanzkasten über dem Schild, Blumenampeln an Wandarmen, Hollandrad mit
Körben, viele Töpfe und Eimer, Kreidetafel. Pflanzen kommen später – jetzt nur Töpfe und Kästen
mit Erde.

Haus "Opposite/Opposite1_4" (Haustyp residential: 5,4 m breit, 8 m tief, Traufe 7,0 m), gegenüber
der Bücherei, links neben der Bäckerei. Bausteine: storybook_town.py.

Aufruf:
  blender -b --factory-startup --python tools/blender/build_storybook_flowers.py [-- --render [--quick] [--only=a,b]] [--no-game] [--force]
Ergebnis: assets/models/houses/flower_shop.glb und assets/models/source/houses/flower_shop_storybook.blend.
"""

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_storybook_shop as FS  # noqa: E402
import storybook_common as SC  # noqa: E402
import storybook_lib as SB  # noqa: E402
import storybook_town as T  # noqa: E402
from storybook_lib import Body  # noqa: E402

BLEND = os.path.join(SC.ROOT, "assets", "models", "source", "houses", "flower_shop_storybook.blend")
STAMP = os.path.join(os.path.dirname(BLEND), "flower_shop_storybook.stamp")
GAME_GLB = os.path.join(SC.ROOT, "assets", "models", "houses", "flower_shop.glb")

W, D, E = 5.4, 8.0, 7.0
HW = W / 2
PITCH = 30.0
SPAN = D / 2 + 0.3                # Traufe vorn 30 cm vor der Wand
RIDGE = E + SPAN * math.tan(math.radians(PITCH))
HEAD = 2.8
FASCIA_H = 0.55
SHOP_X = 2.4
DOOR_HALF = 0.52
UP_X, UP_Z0, UP_W, UP_H = (-1.25, 1.25), 4.3, 1.0, 1.4
FRONT = ((-HW, 0.0), (HW, 0.0))
SETTLE = {"wave": 0.02, "wavelength": 2.8, "lean": -0.0025, "roof_sag": 0.05, "ridge_tilt": 0.02, "eaves_sag": 0.025}

OBSTACLES = {
    "Fahrrad": ((-1.4, -0.45), (1.9, 0.62), 1.1),
    "Topf Ecke links": ((-2.5, -0.5), (0.4, 0.4), 0.36),
    "Blumenständer": ((1.42, -0.48), (1.24, 0.46), 0.55),
    "Kreidetafel": ((2.35, -0.66), (0.56, 0.42), 0.85),
}
# Stufenständer vor dem rechten Schaufenster (Bild der Entwicklerin): zwei Stufen aus Holz, hinten
# Zinkeimer mit Schnittblumen, vorn kleine Töpfe; bleibt im Streifen 0,65 m vor der Wand (Gehweg frei)
STAND_X = (0.8, 2.04)
STAND_STEPS = ((-0.26, -0.5, 0.42), (-0.5, -0.71, 0.2))   # (y hinten, y vorn, Höhe); Brüstung ragt 24 cm vor


def fx(x):
    return x + HW


def walls(M, C):
    b = Body("Fassade (Putz)", M["plaster"], C["walls"], seed=1, vary=0.03)
    T.wall_run(b, *FRONT, 0.0, E, step=0.22)
    wall = b.build()
    ops = [(*FRONT, fx(0.0), 0.0, 2 * SHOP_X, HEAD, 0.0, 0.0)]
    for x in UP_X:
        ops.append((*FRONT, fx(x), UP_Z0, UP_W, UP_H, T.RND.uniform(-1.2, 1.2), 0.0))
    T.cut(wall, ops)
    s = Body("Brandwände, Rückwand und Giebel", M["plaster_side"], C["walls"], seed=2, vary=0.04, bevel=0.01)
    T.wall_run(s, (HW, 0.0), (HW, D), 0.0, E, step=0.5)
    T.wall_run(s, (-HW, D), (-HW, 0.0), 0.0, E, step=0.5)
    T.wall_run(s, (HW, D), (-HW, D), 0.0, E, step=0.5)
    for p0, p1 in (((HW, 0.0), (HW, D)), ((-HW, D), (-HW, 0.0))):
        # Giebeldreieck in der Brandwand, knapp unter der Dachfläche
        s.slab([(0.0, E - 0.03), (D, E - 0.03), (D / 2, RIDGE - 0.14)], 0.3, T.wall_matrix(p0, p1) @ Matrix.Translation((0, 0, -0.3)),
               dent=0.006)
    s.build()
    # Ecksteine (Sandstein, lang und kurz im Wechsel) an beiden Kanten
    q = Body("Ecksteine", M["stone"], C["walls"], seed=3, vary=0.08, bevel=0.012)
    z, k = HEAD + FASCIA_H + 0.45, 0
    while z + 0.3 < E - 0.45:
        wdt = 0.42 if k % 2 == 0 else 0.27
        for side in (-1, 1):
            q.box((side * (HW - wdt / 2 - 0.004), -0.025, z + 0.14), (wdt, 0.06, 0.27), step=0.3, dent=0.004,
                  turn=(0, T.RND.uniform(-1.2, 1.2), 0))
        z += 0.3
        k += 1
    q.build()
    return ops


def roof(M, C):
    frame = Matrix.Translation((0, D / 2, 0))
    T.pitched_roof(M, C, "Dach", frame, W, SPAN, E, PITCH, "slate", seed=8, ends=(0.02, 0.02),
                   skip=lambda p: any(abs(p.x - cx) < 0.45 and 2.3 < p.y < 3.4 for cx in (-HW + 0.5, HW - 0.5)))
    zr = lambda y: E + (SPAN - abs(y - D / 2)) * math.tan(math.radians(PITCH))  # noqa: E731
    for k, cx in enumerate((-HW + 0.5, HW - 0.5)):
        T.chimney(M, C, "Schornstein %s" % ("links" if k == 0 else "rechts"), (cx, 2.85, zr(2.85) - 0.5), (0.62, 0.8), RIDGE + 0.55,
                  "brick", pots=1 + k, seed=11 + 5 * k)
    # Traufgesims (cremefarben) und Dachrinne
    g = Body("Traufgesims", M["trim"], C["walls"], seed=5, vary=0.04, bevel=0.01)
    g.box((0, -0.04, E - 0.3), (W + 0.02, 0.12, 0.12), step=0.3, dent=0.004)
    g.box((0, -0.1, E - 0.16), (W + 0.04, 0.24, 0.12), step=0.3, dent=0.004)
    g.box((0, -0.16, E - 0.05), (W + 0.06, 0.36, 0.1), step=0.3, dent=0.004)
    g.build()
    r = Body("Dachrinne und Fallrohr", M["bronze"], C["roof"], seed=6)
    r.tube([(-HW - 0.02, -0.4, E + 0.04), (0, -0.41, E + 0.02), (HW + 0.02, -0.4, E + 0.04)], 0.055, segs=10, round_ends=True)
    px = HW - 0.1
    r.tube([(px, -0.4, E), (px, -0.16, E - 0.35), (px, -0.09, E - 0.7), (px, -0.09, HEAD + FASCIA_H + 0.3)], 0.034, segs=10, smooth=2,
           round_ends=True)
    r.build()


def upper(M, C, ops):
    for k, x in enumerate(UP_X):
        fm = T.wall_matrix(*FRONT, fx(x), UP_Z0, 0.0, ops[1 + k][6])
        FS.window(M, C, "Fenster %d" % (k + 1), 0, 0, UP_W, UP_H, 0, panes=(2, 2), surround=False, hood=False, fm=fm)
        T.lintel_sill(M, C, "Fenster %d" % (k + 1), fm, UP_W, UP_H, seed=60 + k)
        SC.planter_box(M, C["pots"], "Blumenkasten %d" % (k + 1), fm @ Matrix.Translation((0, -0.06, 0.1)), UP_W + 0.24, 0.2, 0.2,
                       seed=40 + k, gap=0.1, mat="box_green")
        kb = Body("Blumenkasten %d Konsolen" % (k + 1), M["lamp_iron"], C["pots"], seed=45 + k, bevel=0.003)
        for sx in (-UP_W / 2 + 0.06, UP_W / 2 - 0.06):
            kb.tube([fm @ Vector((sx, -0.36, 0.04)), fm @ Vector((sx, -0.07, 0.4)), fm @ Vector((sx, -0.07, 0.04))], 0.009, segs=6,
                    round_ends=True)
        kb.build()
    SC.projecting_sign(M, C["deco"], "Ausleger-Schild", (0.0, 0.0, 5.45), SC.sign_material("flower_shop", "hanging"), 0.56,
                       0.56 * 478 / 512, outline=SB.round_outline(arch=0.12))
    # Straßenlaterne am Wandarm rechts neben dem Fenster: leuchtet gegenüber der Bücherei-Tür
    # (zwischen den Laternen an Opposite1_3 und Opposite2_1)
    T.street_lantern(M, C, "Straßenlaterne", HW - 0.6, 4.05, seed=140)


def shopfront(M, C):
    fm = T.wall_matrix(*FRONT)
    for side in (-1, 1):
        T.pilaster(M, C, "Pilaster %s" % ("links" if side < 0 else "rechts"), fm, fx(side * (HW - 0.15)), HEAD, HEAD, "fern", seed=20 + side)
    for side in (-1, 1):
        x0, x1 = sorted((side * (DOOR_HALF + 0.14), side * (SHOP_X + 0.03)))
        T.shop_window(M, C, "Schaufenster %s" % ("links" if side < 0 else "rechts"),
                      T.wall_matrix(*FRONT, fx((x0 + x1) / 2), 0.0, 0.0, T.RND.uniform(-0.4, 0.4)), x1 - x0, "fern", head=HEAD,
                      transom=2.2, transom_bars=4, mullions=1, seed=22 + side)
    T.door(M, C, "Ladentür", T.wall_matrix(*FRONT, fx(0.0), 0.0, 0.0, T.RND.uniform(-0.4, 0.4)), DOOR_HALF, HEAD, "fern", "fern_dark",
           glazed=True, transom="lattice", panes=(1, 2))
    T.fascia(M, C, "Schildkasten", T.wall_matrix(*FRONT, fx(0.0)), W + 0.04, HEAD, FASCIA_H, "fern",
             signs=[(0.0, 4.4, SC.sign_material("flower_shop", "fascia"), 2048 / 185)], depth=0.3)
    # Langer Pflanzkasten über dem Schild auf Konsolen (Erde, noch ohne Pflanzen)
    top = HEAD + FASCIA_H + 0.2
    SC.planter_box(M, C["pots"], "Pflanzkasten über dem Schild", SC.front_matrix(0.0, top, -0.08), W - 0.3, 0.26, 0.24, seed=48,
                   gap=0.04, mat="box")
    kb = Body("Pflanzkasten Konsolen", M["lamp_iron"], C["pots"], seed=49, bevel=0.003)
    for sx in (-HW + 0.4, -0.9, 0.9, HW - 0.4):
        kb.tube([(sx, -0.1, top - 0.3), (sx, -0.42, top - 0.02), (sx, -0.1, top - 0.02)], 0.01, segs=6, round_ends=True)
    kb.build()
    # Blumenampeln vorn an den Pilastern
    for side in (-1, 1):
        T.hanging_basket(M, C, "Blumenampel %s" % ("links" if side < 0 else "rechts"), side * (HW - 0.3), HEAD - 0.1, reach=0.6,
                         drop=0.36, radius=0.17, seed=80 + side)


def flower_inside(M, C):
    """Laden: hellgrüne Wände, Dielen, Regale mit leeren Töpfen und Vasen, Zinkeimer, Werktisch,
    Hängetöpfe an der Decke."""
    xi = SHOP_X - 0.03
    yb = 4.2
    r = Body("Laden Wände", M["flower_wall_in"], C["inside"], seed=50, vary=0.03)
    T.wall_run(r, (xi + 0.03, 0.02), (xi + 0.03, yb), 0.0, 3.35, thick=0.03, step=0.6)
    T.wall_run(r, (-xi - 0.03, yb), (-xi - 0.03, 0.02), 0.0, 3.35, thick=0.03, step=0.6)
    T.wall_run(r, (xi + 0.03, yb), (-xi - 0.03, yb), 0.0, 3.35, thick=0.08, step=0.6)
    r.build()
    c = Body("Laden Decke", M["in_paper"], C["inside"], seed=51, vary=0.03)
    c.box((0, yb / 2, 3.3), (2 * xi + 0.06, yb, 0.1), step=0.6, dent=0.002)
    c.build()
    fl = Body("Laden Dielen", M["wood_in"], C["inside"], seed=52, vary=0.1)
    x = -xi
    while x < xi - 0.01:
        bw = min(T.RND.uniform(0.15, 0.2), xi - x)
        fl.box((x + bw / 2, yb / 2 + 0.01, 0.04), (bw - 0.006, yb - 0.02, 0.08), step=0.8, dent=0.002)
        x += bw
    fl.build()
    wood = Body("Regale und Werktisch", M["wood_in"], C["inside"], seed=53, vary=0.06, bevel=0.006)
    for zz in (0.9, 1.4, 1.9, 2.4):
        wood.box((0, yb - 0.22, zz), (2 * xi - 0.2, 0.32, 0.035), step=0.4, dent=0.002)
    for sx in (-xi + 0.15, -0.8, 0.8, xi - 0.15):
        wood.box((sx, yb - 0.22, 1.25), (0.04, 0.34, 2.5), step=0.4, dent=0.002)
    wood.box((0, yb - 1.4, 0.45), (1.6, 0.6, 0.9), step=0.4, dent=0.003)
    wood.box((0, yb - 1.4, 0.92), (1.7, 0.66, 0.05), step=0.4, dent=0.002)
    for side in (-1, 1):
        # Stufenpodeste hinter den Schaufenstern
        cx = side * (DOOR_HALF + 0.14 + SHOP_X) / 2
        for k, (yy, zz) in enumerate(((0.55, 0.3), (0.85, 0.6), (1.15, 0.9))):
            wood.box((cx, yy, zz / 2), (1.4, 0.3, zz), step=0.4, dent=0.002)
    wood.build()
    rnd = T.RND
    for i in range(9):
        zz = (0.9, 1.4, 1.9)[i % 3]
        px = -xi + 0.4 + (2 * xi - 0.8) * (i // 3) / 2 + rnd.uniform(-0.15, 0.15)
        SC.pot(M, C["inside"], "Regal Topf %d" % i, (px, yb - 0.22, zz + 0.018), rnd.uniform(0.07, 0.1), rnd.uniform(0.12, 0.17), 100 + i,
               mat=("pot", "pot_light", "pot_dark")[i % 3], style=("classic", "bowl", "tall")[i % 3])
    for side in (-1, 1):
        cx = side * (DOOR_HALF + 0.14 + SHOP_X) / 2
        for k, (yy, zz) in enumerate(((0.55, 0.3), (0.85, 0.6), (1.15, 0.9))):
            for j in range(3):
                px = cx - 0.45 + 0.45 * j + rnd.uniform(-0.05, 0.05)
                if (j + k) % 3 == 1:
                    SC.flower_bucket(M, C["inside"], "Eimer %d %d %d" % (side, k, j), (px, yy, zz), 0.12, 0.26, 200 + 10 * k + j + (side > 0) * 50)
                else:
                    SC.pot(M, C["inside"], "Topf %d %d %d" % (side, k, j), (px, yy, zz), rnd.uniform(0.1, 0.14), rnd.uniform(0.16, 0.24),
                           300 + 10 * k + j + (side > 0) * 50, mat=("pot", "pot_light")[j % 2], style=("classic", "tall")[k % 2])
    # Eimer am Boden gleich hinter der Tür, Vase mit Strauß auf dem Werktisch, Hängetöpfe unter der Decke
    for i, x in enumerate((-0.38, 0.38)):
        SC.flower_bucket(M, C["inside"], "Eimer an der Tür %d" % (i + 1), (x, 0.5, 0.08), 0.13, 0.32, 260 + i)
    SC.flower_bucket(M, C["inside"], "Vase Werktisch", (0.35, yb - 1.4, 0.945), 0.07, 0.2, 265, mat="pot_light", style="vase")
    ch = Body("Hängetöpfe Ketten", M["lamp_iron"], C["inside"], seed=266)
    for i, (x, y) in enumerate(((-1.3, 0.75), (1.3, 0.75), (0.0, 1.6))):
        base = Vector((x, y, 2.45))
        SC.pot(M, C["inside"], "Hängetopf %d" % (i + 1), tuple(base), 0.13, 0.15, 267 + i, mat="pot_light", style="bowl", spot="basket")
        for k in range(3):
            a = 2 * math.pi * k / 3
            ch.tube([base + Vector((math.cos(a) * 0.13, math.sin(a) * 0.13, 0.14)), Vector((x, y, 3.25))], 0.003, segs=4)
    ch.build()
    up = Body("Zimmer oben", M["in_dark"], C["inside"], seed=58, vary=0.04)
    up.box((0, 2.6, 3.62), (W - 0.6, 4.6, 0.1), step=0.8, dent=0.003)
    up.box((0, 2.6, E - 0.4), (W - 0.6, 4.6, 0.1), step=0.8, dent=0.003)
    up.box((0, 4.9, (3.6 + E) / 2), (W - 0.6, 0.1, E - 3.6), step=0.8, dent=0.003)
    for sx in (-1, 1):
        up.box((sx * (HW - 0.32), 2.6, (3.6 + E) / 2), (0.04, 4.6, E - 3.6), step=0.8, dent=0.003)
    up.build()
    for x in (-1.2, 1.2):
        SC.add_light("Ladenlicht", (x, 1.5, 2.9), 3100, 60, C["light"], radius=0.2)
    for x in UP_X:
        SC.add_light("Zimmerlicht", (x, 1.2, 5.4), 2700, 22, C["light"], radius=0.15)


def outside(M, C):
    """Hollandrad vor dem linken Fenster, Töpfe und Eimer (leer, mit Erde), Kreidetafel rechts."""
    # Rad und Topf mit Abstand: das Hinterrad (mit Schutzblech) endet 4 cm vor dem Topf, das
    # Vorderrad steht vor der Türplatte
    T.bicycle(M, C, "Fahrrad", -1.35, -0.45, seed=90, flowers=True)
    SC.pot(M, C["pots"], "Topf Ecke links", (-2.5, -0.5, 0.0), 0.16, 0.33, 61, mat="pot_dark", style="classic")
    flower_stand(M, C)
    SC.chalkboard(M, C["deco"], (2.35, -0.66), -14, SC.sign_material("flower_shop", "chalkboard"))
    # Kletterrosen an den Pfeilern der Ladenfront (bis unter die Ampel-Arme)
    for side in (-1, 1):
        SC.plant_spot("climber", (side * (HW - 0.15), -0.16, 0.0), (0.42, 0.3, HEAD - 0.45), 0.0, hint="rose")


def flower_stand(M, C):
    """Stufenständer aus Holz vor dem rechten Schaufenster: Rahmen, Bretter, hinten drei Zinkeimer mit
    Schnittblumen, vorn vier kleine Töpfe (Pflanzen setzt das Spiel ein)."""
    rnd = T.RND
    x0, x1 = STAND_X
    wd = Body("Blumenständer", M["box"], C["pots"], seed=70, vary=0.08, bevel=0.006)
    for (yb, yf, hh) in STAND_STEPS:
        # Brett je Stufe (drei Latten), darunter eine Schürze
        n = 3
        for k in range(n):
            ya = yb + (yf - yb) * k / n
            yz = yb + (yf - yb) * (k + 1) / n
            wd.box(((x0 + x1) / 2, (ya + yz) / 2, hh - 0.015), (x1 - x0, abs(yz - ya) - 0.008, 0.03), step=0.5, dent=0.002)
        wd.box(((x0 + x1) / 2, yf + 0.012, hh - 0.06), (x1 - x0 - 0.04, 0.022, 0.09), step=0.5, dent=0.002)
    for sx in (x0 + 0.03, (x0 + x1) / 2, x1 - 0.03):
        for (yb, yf, hh) in STAND_STEPS:
            wd.box((sx, yf + 0.03, (hh - 0.03) / 2), (0.05, 0.05, hh - 0.03), step=0.5, dent=0.002)
        wd.box((sx, STAND_STEPS[0][0] - 0.03, STAND_STEPS[0][2] / 2), (0.05, 0.05, STAND_STEPS[0][2] - 0.03), step=0.5, dent=0.002)
        wd.box((sx, (STAND_STEPS[0][0] + STAND_STEPS[1][1]) / 2, 0.06), (0.045, abs(STAND_STEPS[1][1] - STAND_STEPS[0][0]), 0.04), step=0.5,
               dent=0.002)
    wd.build()
    (yb, yf, hh) = STAND_STEPS[0]
    for i, x in enumerate((1.0, 1.42, 1.84)):
        SC.flower_bucket(M, C["pots"], "Eimer hinten %d" % (i + 1), (x + rnd.uniform(-0.03, 0.03), (yb + yf) / 2, hh),
                         rnd.uniform(0.11, 0.125), rnd.uniform(0.24, 0.3), 72 + i)
    (yb, yf, hh) = STAND_STEPS[1]
    for i, x in enumerate((0.94, 1.26, 1.58, 1.9)):
        r = rnd.uniform(0.09, 0.11)
        SC.pot(M, C["pots"], "Topf vorn %d" % (i + 1), (x, (yb + yf) / 2 - 0.005, hh + 0.008), min(r, 0.095), rnd.uniform(0.15, 0.19), 76 + i,
               mat=("pot", "pot_light", "pot_dark", "pot")[i], style=("classic", "bowl", "classic", "tall")[i])


def build_scene():
    T.reseed(1923)
    M, C = T.house_scene("Blumenladen (Bilderbuch)")
    ops = walls(M, C)
    roof(M, C)
    upper(M, C, ops)
    shopfront(M, C)
    flower_inside(M, C)
    outside(M, C)
    house = [o for k, c in C.items() if k not in ("env", "collision") for o in c.objects]
    SC.settle(house, SETTLE, HW, E, RIDGE)
    cols = SC.colliders(C, OBSTACLES)
    SC.pavement(M, C, seed=330)
    return M, C, cols


VIEWS = {
    "blumen_vorn": ((0.0, -12.5, 1.75), (0.0, 0.0, 4.4), 38, (1300, 1500)),
    "blumen_laden": ((1.0, -4.6, 1.6), (0.0, 0.0, 1.8), 30, (1600, 1100)),
    "blumen_rad": ((-1.1, -2.7, 1.25), (-1.45, -0.45, 0.6), 34, (1400, 1000)),
    "blumen_rad_seite": ((-3.6, -1.3, 1.0), (-1.45, -0.45, 0.55), 34, (1400, 1000)),
    "blumen_ampel": ((-1.6, -2.3, 2.2), (-2.55, -0.45, 2.3), 34, (1100, 1000)),
    "blumen_korb": ((-0.55, -1.35, 1.3), (-0.8, -0.45, 0.85), 32, (1200, 1000)),
}


if __name__ == "__main__":
    T.run(build_scene, BLEND, STAMP, GAME_GLB, VIEWS, "build_storybook_flowers.py")
