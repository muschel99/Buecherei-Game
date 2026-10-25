"""Bäckerei im Bilderbuch-Stil (Vorlagebild der Entwicklerin): schmales Haus mit dem Giebel zur
Straße, cremefarbener Putz, Ladenfront in Tannengrün mit dem Schild „Bäckerei“ (Bild der
Entwicklerin), rot-weiße Markise aus einem Stück Stoff, Schaufenster voller Brot, rote
Blumenkästen (noch ohne Pflanzen), Töpfe und Kreidetafel vor dem Laden.

Haus "Opposite/Opposite1_5" (Haustyp terrace_45: 4,5 m breit, 8 m tief, Traufe 6,4 m), gegenüber
der Bücherei rechts neben dem Blumenladen. Bausteine: storybook_town.py.

Aufruf:
  blender -b --factory-startup --python tools/blender/build_storybook_bakery.py [-- --render [--quick] [--only=a,b]] [--no-game] [--force]
Ergebnis: assets/models/houses/bakery.glb (Spiel) und assets/models/source/houses/bakery_storybook.blend
(Einzelteile zum Weiterbauen; bearbeitete Fassung ins Spiel: export_storybook.py).
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

BLEND = os.path.join(SC.ROOT, "assets", "models", "source", "houses", "bakery_storybook.blend")
STAMP = os.path.join(os.path.dirname(BLEND), "bakery_storybook.stamp")
GAME_GLB = os.path.join(SC.ROOT, "assets", "models", "houses", "bakery.glb")

W, D, E = 4.5, 8.0, 6.4
HW = W / 2
PITCH = 50.0
RIDGE = E + (HW + 0.02) * math.tan(math.radians(PITCH))
HEAD = 2.75                       # Oberkante Schaufenster
FASCIA_H = 0.6
SHOP_X = 1.95                     # Ladenöffnung bis ±SHOP_X
DOOR_HALF = 0.5
UP_X, UP_Z0, UP_W, UP_H = (-1.05, 1.05), 4.0, 0.92, 1.32
GABLE_Z0, GABLE_W, GABLE_H = 6.8, 0.6, 0.74
FRONT = ((-HW, 0.0), (HW, 0.0))
SETTLE = {"wave": 0.018, "wavelength": 2.6, "lean": -0.002, "roof_sag": 0.05, "ridge_tilt": 0.03, "eaves_sag": 0.02}

OBSTACLES = {
    "Pflanzkasten links": ((-1.5, -0.43), (0.78, 0.42), 0.4),
    "Topf an der Tür links": ((-0.86, -0.48), (0.44, 0.44), 0.42),
    "Topf an der Tür rechts": ((0.86, -0.46), (0.4, 0.4), 0.4),
    "Kreidetafel": ((1.42, -0.56), (0.56, 0.42), 0.85),
}


def fx(x):
    """Weltkoordinate x → Lage entlang der Frontwand (die Wand beginnt links bei -HW)."""
    return x + HW


def walls(M, C):
    # Front mit Giebeldreieck, Öffnungen: Ladenfront, zwei Fenster oben, Giebelfenster
    b = Body("Fassade (Putz)", M["plaster"], C["walls"], seed=1, vary=0.03)
    T.wall_run(b, *FRONT, 0.0, E, step=0.22)
    b.slab([(0.0, E - 0.03), (W, E - 0.03), (W / 2, RIDGE - 0.12)], 0.3, T.wall_matrix(*FRONT) @ Matrix.Translation((0, 0, -0.312)), dent=0.006)
    wall = b.build()
    # schmales Giebelgesims über der Fuge zwischen Wand und Giebeldreieck
    gb = Body("Giebelgesims", M["trim"], C["walls"], seed=9, vary=0.04, bevel=0.012)
    gb.box((W / 2, E - 0.01, 0.03), (W + 0.03, 0.11, 0.07), step=0.4, dent=0.002, matrix=T.wall_matrix(*FRONT))
    gb.build()
    ops = [(*FRONT, fx(0.0), 0.0, 2 * SHOP_X, HEAD, 0.0, 0.0)]
    for k, x in enumerate(UP_X):
        ops.append((*FRONT, fx(x), UP_Z0, UP_W, UP_H, T.RND.uniform(-1.2, 1.2), 0.0))
    ops.append((*FRONT, fx(0.0), GABLE_Z0, GABLE_W, GABLE_H, 0.6, 0.0))
    T.cut(wall, ops)
    # Brandwände, Rückwand mit Giebel
    # Seitenwand zur kleinen Gasse (rechts): Putz wie vorn, mit zwei Fenstern und Blumenkasten
    sw = Body("Seitenwand Gasse", M["plaster"], C["walls"], seed=3, vary=0.03)
    T.wall_run(sw, (HW, 0.0), (HW, D), 0.0, E, step=0.5)
    side_wall = sw.build()
    # unten hinter dem Laden (der Laden reicht bis 4 m), oben in die Zimmer
    side_ops = [((HW, 0.0), (HW, D), 5.2, 0.9, 0.85, 1.4, 0.6, 0.0), ((HW, 0.0), (HW, D), 1.6, UP_Z0, 0.85, 1.3, -0.8, 0.0),
                ((HW, 0.0), (HW, D), 4.2, UP_Z0, 0.85, 1.3, 0.5, 0.0)]
    T.cut(side_wall, side_ops, bevel=0.012)
    for k, (p0, p1, x, z, w, h, turn, _) in enumerate(side_ops):
        fm = T.wall_matrix(p0, p1, x, z, 0.0, turn)
        FS.window(M, C, "Seitenfenster %d" % (k + 1), 0, 0, w, h, 0, panes=(2, 2), surround=True, hood=False, fm=fm)
        if z > 2:
            SC.planter_box(M, C["pots"], "Seitenfenster %d Blumenkasten" % (k + 1), fm @ Matrix.Translation((0, -0.08, 0.08)), w + 0.2, 0.2,
                           0.2, seed=70 + k, gap=0.1, mat="box_red")
        # warmer Raum dahinter
        rm = Body("Seitenraum %d" % (k + 1), M["in_dark"], C["inside"], seed=80 + k, vary=0.04)
        rm.box((0, 0.6, -1.3), (1.8, 2.0, 0.08), step=1, dent=0.0, matrix=fm)
        for sx in (-0.9, 0.9):
            rm.box((sx, 0.6, -0.8), (0.08, 2.0, 1.0), step=1, dent=0.0, matrix=fm)
        rm.box((0, -0.35, -0.8), (1.8, 0.08, 1.0), step=1, dent=0.0, matrix=fm)
        rm.box((0, 1.55, -0.8), (1.8, 0.08, 1.0), step=1, dent=0.0, matrix=fm)
        rm.build()
    s = Body("Brandwände und Rückwand", M["plaster_side"], C["walls"], seed=2, vary=0.04, bevel=0.01)
    T.wall_run(s, (-HW, D), (-HW, 0.0), 0.0, E, step=0.5)
    T.wall_run(s, (HW, D), (-HW, D), 0.0, E, step=0.5)
    s.slab([(0.0, E - 0.03), (W, E - 0.03), (W / 2, RIDGE - 0.12)], 0.3, T.wall_matrix((HW, D), (-HW, D)) @ Matrix.Translation((0, 0, -0.312)),
           dent=0.006)
    s.build()
    return ops


def roof(M, C):
    """Steiles Satteldach, First von vorn nach hinten; vorn Ortgangbretter und eine kleine Spitze."""
    frame = Matrix(((0, -1, 0, 0), (1, 0, 0, (D - 0.4) / 2), (0, 0, 1, 0), (0, 0, 0, 1)))
    T.pitched_roof(M, C, "Dach", frame, D + 0.4, HW + 0.02, E, PITCH, "clay", cap_mat="clay_dark", seed=8)
    w = Body("Ortgangbretter", M["oak_dark"], C["roof"], seed=9, vary=0.05, bevel=0.01)
    for side in (-1, 1):
        lo = Vector((side * (HW + 0.06), -0.43, E - 0.12))
        hi = Vector((0.0, -0.43, RIDGE + 0.1))
        w.span(lo, hi, 0.05, 0.24, step=0.4, dent=0.003)
        # kleine Knaggen unter dem Brett
        for t in (0.25, 0.55):
            p = lo.lerp(hi, t) + Vector((0, 0.1, -0.16))
            w.box(tuple(p), (0.07, 0.24, 0.08), step=1, dent=0.002)
    w.box((0.0, -0.43, RIDGE + 0.05), (0.1, 0.07, 0.18), step=1, dent=0.002)
    w.build()
    f = Body("Firstspitze", M["lamp_iron"], C["roof"], seed=10, bevel=0.003)
    f.tube([(0.0, -0.43, RIDGE + 0.12), (0.0, -0.43, RIDGE + 0.5)], 0.012, segs=8, round_ends=True)
    f.blob((0.0, -0.43, RIDGE + 0.3), 0.03, subdiv=1, lump=0.0)
    f.build()


def upper(M, C, ops):
    """Fenster oben mit cremefarbenen Faschen, Vorhängen und roten Blumenkästen auf Konsolen."""
    for k, x in enumerate(UP_X):
        turn = ops[1 + k][6]
        fm = T.wall_matrix(*FRONT, fx(x), UP_Z0, 0.0, turn)
        FS.window(M, C, "Fenster %d" % (k + 1), 0, 0, UP_W, UP_H, 0, panes=(2, 2), surround=True, hood=False, fm=fm)
        SC.planter_box(M, C["pots"], "Blumenkasten %d" % (k + 1), fm @ Matrix.Translation((0, -0.08, 0.08)), UP_W + 0.2, 0.2, 0.2,
                       seed=40 + k, gap=0.1, mat="box_red")
        kb = Body("Blumenkasten %d Konsolen" % (k + 1), M["lamp_iron"], C["pots"], seed=45 + k, bevel=0.003)
        for sx in (-UP_W / 2 + 0.05, UP_W / 2 - 0.05):
            kb.tube([fm @ Vector((sx, -0.38, 0.04)), fm @ Vector((sx, -0.09, 0.38)), fm @ Vector((sx, -0.09, 0.04))], 0.009, segs=6,
                    round_ends=True)
        kb.build()
    fm = T.wall_matrix(*FRONT, fx(0.0), GABLE_Z0, 0.0, ops[3][6])
    FS.window(M, C, "Giebelfenster", 0, 0, GABLE_W, GABLE_H, 0, panes=(2, 2), surround=True, hood=False, fm=fm)
    g = Body("Fallrohr", M["bronze"], C["roof"], seed=12)
    px = -HW + 0.07
    g.tube([(px, -0.2, E - 0.05), (px, -0.1, E - 0.3), (px, -0.08, E - 0.6), (px, -0.08, 0.15), (px, -0.16, 0.03)], 0.034, segs=10,
           smooth=2, round_ends=True)
    for z in (1.2, 2.9, 4.4, 5.8):
        g.lathe([(0.0, 0.0), (0.048, 0.0), (0.05, 0.02), (0.048, 0.04), (0.0, 0.04)], (px, -0.08, z), segs=12)
    g.tube([(px - 0.02, -0.38, E - 0.02), (px, -0.2, E - 0.05)], 0.05, segs=10, round_ends=True)
    g.build()


def shopfront(M, C):
    fm = T.wall_matrix(*FRONT)
    for side in (-1, 1):
        T.pilaster(M, C, "Pilaster %s" % ("links" if side < 0 else "rechts"), fm, fx(side * (HW - 0.15)), HEAD, HEAD, "petrol", seed=20 + side)
    for side in (-1, 1):
        x0, x1 = sorted((side * (DOOR_HALF + 0.14), side * (SHOP_X + 0.03)))
        T.shop_window(M, C, "Schaufenster %s" % ("links" if side < 0 else "rechts"),
                      T.wall_matrix(*FRONT, fx((x0 + x1) / 2), 0.0, 0.0, T.RND.uniform(-0.4, 0.4)), x1 - x0, "petrol", head=HEAD,
                      transom=2.25, transom_bars=3, mullions=1, seed=22 + side)
    T.door(M, C, "Ladentür", T.wall_matrix(*FRONT, fx(0.0), 0.0, 0.0, T.RND.uniform(-0.4, 0.4)), DOOR_HALF, HEAD, "petrol", "petrol_dark",
           glazed=True, transom="bars", panes=(2, 3))
    sign = SC.sign_material("bakery_shop", "fascia")
    T.fascia(M, C, "Schildkasten", T.wall_matrix(*FRONT, fx(0.0)), W + 0.04, HEAD, FASCIA_H, "petrol",
             signs=[(0.0, 3.7, sign, 2048 / 224)], depth=0.3)
    # Markise unter dem Schild, vor dem Schildkasten
    T.placed(C["shop"], Matrix.Translation((0, -0.3, 0)), T.cloth_awning, M, C, "Markise", W - 0.3, HEAD - 0.03, 0.95, 0.4,
             valance=0.22, mat="awning_red", seed=3)


def bakery_inside(M, C):
    """Laden hinter den Fenstern: Honigfarbene Wände, Dielen, Decke, Stufenregale voller Brot,
    Theke, Körbe; oben ein warmes Zimmer."""
    xi = SHOP_X - 0.03
    yb = 4.0
    r = Body("Laden Wände", M["bakery_wall_in"], C["inside"], seed=50, vary=0.03)
    T.wall_run(r, (xi + 0.03, 0.02), (xi + 0.03, yb), 0.0, 3.3, thick=0.03, step=0.6)
    T.wall_run(r, (-xi - 0.03, yb), (-xi - 0.03, 0.02), 0.0, 3.3, thick=0.03, step=0.6)
    T.wall_run(r, (xi + 0.03, yb), (-xi - 0.03, yb), 0.0, 3.3, thick=0.08, step=0.6)
    r.build()
    c = Body("Laden Decke", M["in_paper"], C["inside"], seed=51, vary=0.03)
    c.box((0, yb / 2, 3.25), (2 * xi + 0.06, yb, 0.1), step=0.6, dent=0.002)
    c.build()
    fl = Body("Laden Dielen", M["wood_in"], C["inside"], seed=52, vary=0.1)
    x = -xi
    while x < xi - 0.01:
        bw = min(T.RND.uniform(0.15, 0.2), xi - x)
        fl.box((x + bw / 2, yb / 2 + 0.01, 0.04), (bw - 0.006, yb - 0.02, 0.08), step=0.8, dent=0.002)
        x += bw
    fl.build()
    # Stufenregale hinter den Schaufenstern (drei Böden, nach hinten höher)
    wood = Body("Brotregale", M["wood_in"], C["inside"], seed=53, vary=0.06, bevel=0.006)
    loaves = Body("Brote", M["bread"], C["inside"], seed=54, vary=0.12)
    dark = Body("Brote dunkel", M["bread_dark"], C["inside"], seed=55, vary=0.12)
    for side in (-1, 1):
        cx = side * (DOOR_HALF + 0.14 + SHOP_X + 0.03) / 2
        ww = SHOP_X - DOOR_HALF - 0.4
        for k, (yy, zz) in enumerate(((0.45, 0.72), (0.75, 1.1), (1.05, 1.48), (1.35, 1.86))):
            wood.box((cx, yy, zz), (ww, 0.32, 0.035), step=0.4, dent=0.002)
            n = 5 if k % 2 == 0 else 4
            for i in range(n):
                px = cx - ww / 2 + 0.12 + (ww - 0.24) * i / max(1, n - 1)
                kind = (i + k + (side > 0)) % 3
                if kind == 0:
                    loaves.blob((px, yy, zz + 0.07), 0.085, subdiv=2, lump=0.08, scale=(1.0, 0.95, 0.62))
                elif kind == 1:
                    dark.blob((px, yy, zz + 0.06), 0.1, subdiv=2, lump=0.06, scale=(1.1, 0.7, 0.5))
                else:
                    loaves.tube([(px - 0.12, yy - 0.02, zz + 0.04), (px, yy, zz + 0.055), (px + 0.12, yy + 0.02, zz + 0.04)], 0.035, segs=8,
                                smooth=1, round_ends=True)
        for sx in (-ww / 2 + 0.02, ww / 2 - 0.02):
            wood.box((cx + sx, 0.9, 1.0), (0.04, 1.2, 2.0), step=0.4, dent=0.002)
        # Körbe mit Brötchen auf dem Boden vor dem Regal
        T.basket(M, C, "Korb %s" % ("links" if side < 0 else "rechts"), Vector((cx, 0.3, 0.08)), (0.4, 0.28, 0.16), 57 + side)
        for i in range(6):
            loaves.blob((cx - 0.12 + 0.08 * (i % 4), 0.25 + 0.08 * (i // 4), 0.22), 0.045, subdiv=1, lump=0.1, scale=(1, 1, 0.7))
    # Theke hinten und Regal an der Rückwand
    wood.box((0, yb - 1.2, 0.5), (1.8, 0.5, 1.0), step=0.4, dent=0.003)
    wood.box((0, yb - 1.2, 1.03), (1.9, 0.56, 0.05), step=0.4, dent=0.002)
    for zz in (1.2, 1.6, 2.0):
        wood.box((0, yb - 0.2, zz), (2.6, 0.3, 0.035), step=0.4, dent=0.002)
        for i in range(7):
            px = -1.1 + 2.2 * i / 6
            (loaves if i % 2 else dark).blob((px, yb - 0.2, zz + 0.07), 0.08, subdiv=2, lump=0.06, scale=(1.0, 0.9, 0.6))
    wood.build()
    loaves.build()
    dark.build()
    # Zimmer oben
    up = Body("Zimmer oben", M["in_dark"], C["inside"], seed=58, vary=0.04)
    up.box((0, 2.6, 3.42), (W - 0.6, 4.6, 0.1), step=0.8, dent=0.003)
    up.box((0, 2.6, E - 0.35), (W - 0.6, 4.6, 0.1), step=0.8, dent=0.003)
    up.box((0, 4.9, (3.4 + E) / 2), (W - 0.6, 0.1, E - 3.4), step=0.8, dent=0.003)
    # rechts keine Innenwand: dort schauen die Seitenfenster hinein (eigene Räume dahinter)
    up.box((-(HW - 0.32), 2.6, (3.4 + E) / 2), (0.04, 4.6, E - 3.4), step=0.8, dent=0.003)
    up.build()
    for x in (-1.0, 1.0):
        SC.add_light("Ladenlicht", (x, 1.4, 2.8), 2900, 60, C["light"], radius=0.2)
    for x in UP_X:
        SC.add_light("Zimmerlicht", (x, 1.2, 5.0), 2700, 22, C["light"], radius=0.15)


def outside(M, C):
    """Vor dem Laden: Pflanzkasten links, Töpfe neben der Tür, Kreidetafel und großer Kübel rechts."""
    # Alles frei vor Brüstung und Pilastern (T.pot_out)
    SC.planter_box(M, C["pots"], "Pflanzkasten links", SC.front_matrix(-1.5, 0.0, 0.0), 0.74, 0.36, 0.36, seed=60, gap=T.FRONT_CLEAR,
                   mat="box", rail=False)
    SC.pot(M, C["pots"], "Topf an der Tür links", (-0.86, -T.pot_out(0.2), 0.0), 0.2, 0.4, 61, mat="pot")
    SC.pot(M, C["pots"], "Topf an der Tür rechts", (0.86, -T.pot_out(0.18), 0.0), 0.18, 0.38, 62, mat="pot_light")
    # Kreidetafel dicht an der Wand; an der Ecke zur kleinen Gasse bleibt der schmale Gehweg frei
    SC.chalkboard(M, C["deco"], (1.42, -0.56), -8, SC.sign_material("bakery_shop", "chalkboard"))


def build_scene():
    T.reseed(1907)
    M, C = T.house_scene("Bäckerei (Bilderbuch)")
    ops = walls(M, C)
    roof(M, C)
    upper(M, C, ops)
    shopfront(M, C)
    bakery_inside(M, C)
    outside(M, C)
    house = [o for k, c in C.items() if k not in ("env", "collision") for o in c.objects]
    SC.settle(house, SETTLE, HW, E, RIDGE)
    cols = SC.colliders(C, OBSTACLES)
    SC.pavement(M, C, seed=320, half=3.4)
    return M, C, cols


VIEWS = {
    "baeckerei_vorn": ((0.0, -11.0, 1.75), (0.0, 0.0, 4.4), 38, (1100, 1500)),
    "baeckerei_laden": ((1.2, -4.2, 1.6), (0.0, 0.0, 1.9), 30, (1600, 1100)),
    "baeckerei_markise": ((2.6, -2.8, 1.5), (0.4, -0.6, 2.5), 30, (1400, 1000)),
    "baeckerei_unten": ((0.3, -1.3, 1.5), (0.0, -0.4, 2.8), 26, (1400, 1000)),
    "baeckerei_giebel": ((1.5, -5.5, 6.5), (0.0, 0.0, 7.4), 30, (1200, 1000)),
}


if __name__ == "__main__":
    T.run(build_scene, BLEND, STAMP, GAME_GLB, VIEWS, "build_storybook_bakery.py")
