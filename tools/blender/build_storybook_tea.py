"""Teeladen („Teestube“) im Bilderbuch-Stil (Vorlagebild der Entwicklerin, dort noch als Buchladen
eingeräumt – hier stehen Tee, Dosen und Kannen darin): Eckhaus aus Backstein mit abgeschrägter
Ecke, schwarze Ladenfront mit Goldkante auf der Seite zur langen Straße (Tür links, langes
Schaufenster rechts), Schild „Teestube“ und Hängeschild mit Teekanne (Bilder der Entwicklerin),
Klappläden in Schiefergrau, Steinstürze, Blumenkästen und Ampeln (noch ohne Pflanzen).

Haus "StraightEnd/Corner" (Haustyp corner_90): Vorderseite 6 m, Ecke 2,2 m schräg, Seite 7 m,
7 m tief, Traufe 6,8 m. Grundriss genau wie CornerHouseFacade (storybook_town.corner_outline).
Kanten: S0 Vorderseite (zur Seitenstraße), S1 Abschrägung, S2 Seitenfassade (zur langen Straße,
mit dem Laden), S3 hinten, S4 Brandwand.

Aufruf:
  blender -b --factory-startup --python tools/blender/build_storybook_tea.py [-- --render [--quick] [--only=a,b]] [--no-game] [--force]
Ergebnis: assets/models/houses/tea_shop.glb und assets/models/source/houses/tea_shop_storybook.blend.
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

BLEND = os.path.join(SC.ROOT, "assets", "models", "source", "houses", "tea_shop_storybook.blend")
STAMP = os.path.join(os.path.dirname(BLEND), "tea_shop_storybook.stamp")
GAME_GLB = os.path.join(SC.ROOT, "assets", "models", "houses", "tea_shop.glb")

W, D, E = 6.0, 7.0, 6.8
OUT = T.corner_outline(W, D, 90.0, 2.2, 7.0)
S0, S1, S2, S3, S4 = (T.seg(OUT, i) for i in range(5))
STREET = (0, 1, 2)                    # Kanten zur Straße
RISE, RUN = 1.6, 2.2
HEAD, FASCIA_H = 2.75, 0.7
UP_Z0, UP_H = 4.0, 1.45
DOOR_X, DOOR_HALF = 0.95, 0.48
SHOP = (0.25, 5.05)                   # Ladenöffnung entlang S2
SETTLE = {"wave": 0.02, "wavelength": 3.2, "lean": -0.002, "roof_sag": 0.04, "ridge_tilt": 0.0, "eaves_sag": 0.02}

# Fenster: (Kante, Mitte x, Unterkante, Breite, Höhe, Läden)
WINDOWS = [(S0, 2.4, 0.85, 1.0, 1.6, True), (S1, 1.1, 0.85, 0.8, 1.6, False),
           (S0, 1.15, UP_Z0, 0.9, UP_H, True), (S0, 3.3, UP_Z0, 0.9, UP_H, True), (S1, 1.1, UP_Z0, 0.8, UP_H, False),
           (S2, 1.6, UP_Z0, 1.0, UP_H, True), (S2, 3.95, UP_Z0, 1.0, UP_H, True)]


def openings():
    ops = [(*S2, (SHOP[0] + SHOP[1]) / 2, 0.0, SHOP[1] - SHOP[0], HEAD, 0.0, 0.0)]
    for p, x, z, w, h, _ in WINDOWS:
        ops.append((*p, x, z, w, h, T.RND.uniform(-1.0, 1.0), 0.0))
    return ops


def walls(M, C, ops):
    b = Body("Mauern (Backstein)", M["brick"], C["walls"], seed=1, vary=0.03)
    T.outline_walls(b, OUT, STREET + (3,), 0.0, E, step=0.22)
    T.cut(b.build(), ops)
    p = Body("Brandwand", M["plaster_side"], C["walls"], seed=2, vary=0.04, bevel=0.01)
    T.outline_walls(p, OUT, (4,), 0.0, E, step=0.5)
    p.build()
    # Gurtgesims über dem Laden und Traufgesims rundherum (cremefarbener Stein)
    g = Body("Gesimse", M["trim"], C["walls"], seed=3, vary=0.04, bevel=0.01)
    T.band(g, OUT, (0, 1), HEAD + FASCIA_H - 0.05, 0.12, -0.02, 0.08)
    T.band(g, OUT, STREET, E - 0.34, 0.12, -0.02, 0.1)
    T.band(g, OUT, STREET, E - 0.22, 0.12, -0.02, 0.2)
    T.band(g, OUT, STREET, E - 0.1, 0.1, -0.02, 0.32)
    g.build()


def roof(M, C):
    T.hip_roof(M, C, "Dach", OUT, [True, True, True, False, False], E, RISE, RUN, 0.36, "roof", cap_mat="clay_dark",
               skip=lambda p: abs(p.x + 1.4) < 0.5 and abs(p.y - 4.6) < 0.6)
    T.chimney(M, C, "Schornstein", (-1.4, 4.6, E + RISE - 0.3), (0.62, 0.8), E + RISE + 1.0, "brick", pots=2, seed=11)
    r = Body("Dachrinne und Fallrohr", M["bronze"], C["roof"], seed=6)
    off = T.offset_polygon(OUT, [-0.44 if i in STREET else 0.0 for i in range(len(OUT))])
    r.tube([off[k].to_3d() + Vector((0, 0, E + 0.03)) for k in range(4)], 0.055, segs=10, round_ends=True)
    m = T.canon(*S0, 0.12)
    r.tube([m @ Vector((0, 0.44, E)), m @ Vector((0, 0.16, E - 0.35)), m @ Vector((0, 0.09, E - 0.7)), m @ Vector((0, 0.09, 0.15)),
            m @ Vector((0, 0.18, 0.03))], 0.034, segs=10, smooth=2, round_ends=True)
    r.build()


def windows(M, C, ops):
    for k, (p, x, z, w, h, sh) in enumerate(WINDOWS):
        fm = T.wall_matrix(*p, x, z, 0.0, ops[1 + k][6])
        name = "Fenster %d" % (k + 1)
        FS.window(M, C, name, 0, 0, w, h, 0, panes=(2, 2) if z > 2 else (2, 3), surround=False, hood=False, fm=fm, frame="frame",
                  curtains=z > 2)
        T.lintel_sill(M, C, name, fm, w, h, seed=60 + k)
        if sh:
            T.shutters(M, C, name, fm, w, h, mat="shutter", open_off=T.RND.uniform(6, 12), seed=70 + k)
        if z > 2 and p is not S1:
            SC.planter_box(M, C["pots"], name + " Blumenkasten", fm @ Matrix.Translation((0, -0.06, 0.1)), w + 0.2, 0.2, 0.2, seed=40 + k,
                           gap=0.1, mat="box")
            kb = Body(name + " Konsolen", M["lamp_iron"], C["pots"], seed=45 + k, bevel=0.003)
            for sx in (-w / 2 + 0.06, w / 2 - 0.06):
                kb.tube([fm @ Vector((sx, -0.36, 0.04)), fm @ Vector((sx, -0.07, 0.4)), fm @ Vector((sx, -0.07, 0.04))], 0.009, segs=6,
                        round_ends=True)
            kb.build()


def shopfront(M, C):
    fm = T.wall_matrix(*S2)
    for x in (SHOP[0] - 0.1, SHOP[1] + 0.1):
        T.pilaster(M, C, "Pilaster %.1f" % x, fm, x, HEAD, HEAD, "tea_black", seed=20 + int(x))
    x0, x1 = DOOR_X + DOOR_HALF + 0.14, SHOP[1] + 0.03
    T.shop_window(M, C, "Schaufenster", T.wall_matrix(*S2, (x0 + x1) / 2, 0.0, 0.0, T.RND.uniform(-0.3, 0.3)), x1 - x0, "tea_black",
                  head=HEAD, transom=2.2, transom_bars=7, mullions=3, seed=22)
    T.door(M, C, "Ladentür", T.wall_matrix(*S2, DOOR_X, 0.0, 0.0, T.RND.uniform(-0.4, 0.4)), DOOR_HALF, HEAD, "tea_black", "tea_black",
           glazed=False, transom="bars")
    length = SHOP[1] + 0.25
    T.fascia(M, C, "Schildkasten", T.wall_matrix(*S2, length / 2), length, HEAD, FASCIA_H, "tea_black",
             signs=[(3.25 - length / 2, 2.4, SC.sign_material("corner_90", "fascia"), 768 / 192)], depth=0.3)
    gl = Body("Schildkasten Goldkante", M["gold"], C["shop"], seed=25, vary=0.03)
    gl.box((length / 2, HEAD + 0.035, 0.3), (length - 0.04, 0.025, 0.025), step=0.4, dent=0.001, matrix=fm)
    gl.box((length / 2, HEAD + FASCIA_H - 0.035, 0.3), (length - 0.04, 0.025, 0.025), step=0.4, dent=0.001, matrix=fm)
    gl.build()
    # Straßenlaterne am Wandarm auf der Seite zur langen Straße (dort steht sonst kein Licht)
    T.placed(C["deco"], T.canon(*S2, 5.5), T.street_lantern, M, C, "Straßenlaterne", 0.0, 4.1, seed=140)
    T.placed(C["deco"], T.canon(*S2, 0.35), SC.projecting_sign, M, C["deco"], "Hängeschild", (0.0, 0.0, 4.35),
             SC.sign_material("corner_90", "hanging"), 0.56, 0.56 * 478 / 512, outline=SB.round_outline(arch=0.12))


def tea_inside(M, C, ops):
    """Teestube: altrosa Wände, Dielen, Regale voller Teedosen, Theke mit Kannen, Auslage hinter
    dem Schaufenster; oben warme Zimmer."""
    lin = Body("Laden Wände", M["tea_wall_in"], C["inside"], seed=50, vary=0.03)
    T.outline_walls(lin, OUT, range(5), 0.0, 3.3, thick=0.03, inset=0.3, step=0.6)
    T.cut(lin.build(), [o for o in ops if o[3] < 2.0], bevel=0)
    up = Body("Zimmer oben Wände", M["in_dark"], C["inside"], seed=51, vary=0.04)
    T.outline_walls(up, OUT, range(5), 3.45, E - 0.4, thick=0.03, inset=0.3, step=0.8)
    T.cut(up.build(), [o for o in ops if o[3] > 2.0], bevel=0)
    T.floor_slab(M, C, "Laden Dielen", "wood_in", OUT, 0.29, 0.0, 0.06)
    T.floor_slab(M, C, "Laden Decke", "in_paper", OUT, 0.29, 3.28, 0.1)
    T.floor_slab(M, C, "Zimmer oben Boden", "in_dark", OUT, 0.29, 3.39, 0.06)
    T.floor_slab(M, C, "Zimmer oben Decke", "in_dark", OUT, 0.29, E - 0.45, 0.06)
    wood = Body("Regale und Theke", M["pub_wood_in"], C["inside"], seed=52, vary=0.06, bevel=0.006)
    tins = {k: Body("Teedosen %s" % k, M["tin_" + k], C["inside"], seed=53 + i, vary=0.06, bevel=0.003)
            for i, k in enumerate(("red", "green", "cream", "blue"))}
    china = Body("Teekannen und Gläser", M["china"], C["inside"], seed=58, vary=0.04)
    rnd = T.RND
    keys = list(tins)
    # Wandregal an der Brandwand (gegenüber dem Schaufenster) und an der Rückwand
    for p, x0, x1 in ((S4, 0.6, 6.4), (S3, 0.4, 3.6)):
        m = T.wall_matrix(*p)
        for zz in (0.95, 1.4, 1.85, 2.3, 2.75):
            wood.box(((x0 + x1) / 2, zz, -0.48), (x1 - x0, 0.035, 0.32), step=0.5, dent=0.002, matrix=m)
            x = x0 + 0.1
            while x < x1 - 0.12:
                r = rnd.uniform(0.045, 0.06)
                h = rnd.uniform(0.11, 0.17)
                c = m @ Vector((x + r, zz + 0.018, -0.48))
                if rnd.random() < 0.15:
                    china.lathe([(0.0, 0.0), (r, 0.0), (r, h * 0.85), (r * 0.7, h), (0.0, h)], c, segs=12)
                else:
                    t = tins[keys[rnd.randrange(4)]]
                    t.lathe([(0.0, 0.0), (r, 0.0), (r, h), (r * 1.04, h + 0.004), (r * 1.04, h + 0.02), (0.0, h + 0.022)], c, segs=14)
                x += 2 * r + rnd.uniform(0.015, 0.04)
        for xs in (x0, (x0 + x1) / 2, x1):
            wood.box((xs, 1.9, -0.48), (0.04, 2.0, 0.34), step=0.5, dent=0.002, matrix=m)
    # Theke mit Kannen
    tm = T.wall_matrix(*S4, 3.2)
    wood.box((0, 0.5, -1.6), (2.2, 1.0, 0.6), step=0.4, dent=0.003, matrix=tm)
    wood.box((0, 1.02, -1.6), (2.3, 0.05, 0.66), step=0.4, dent=0.002, matrix=tm)
    for k, dx in enumerate((-0.7, 0.0, 0.7)):
        T.teapot(china, tm @ Vector((dx, 1.05, -1.6)), 0.16, rnd, yaw=rnd.uniform(0, 360))
    # Auslage hinter dem Schaufenster: Tisch mit Kannen und Dosen
    am = T.wall_matrix(*S2, 3.3)
    wood.box((0, 0.42, -0.75), (2.4, 0.84, 0.5), step=0.4, dent=0.003, matrix=am)
    wood.box((0, 0.86, -0.75), (2.5, 0.04, 0.56), step=0.4, dent=0.002, matrix=am)
    for k, dx in enumerate((-0.9, -0.3, 0.35, 0.95)):
        if k % 2 == 0:
            T.teapot(china, am @ Vector((dx, 0.88, -0.75)), 0.15, rnd, yaw=rnd.uniform(0, 360))
        else:
            for j in range(3):
                tins[keys[(k + j) % 4]].lathe([(0.0, 0.0), (0.06, 0.0), (0.06, 0.16), (0.062, 0.165), (0.062, 0.18), (0.0, 0.182)],
                                            am @ Vector((dx - 0.13 + 0.13 * j, 0.88, -0.75 + (j % 2) * 0.1)), segs=14)
    wood.build()
    for t in tins.values():
        t.build()
    china.build()
    for p, x in ((S2, 1.5), (S2, 3.8), (S0, 2.4)):
        SC.add_light("Ladenlicht", tuple(T.canon(*p, x, 2.9, -1.5) @ Vector((0, 0, 0))), 2900, 55, C["light"], radius=0.2)
    for p, x, z, w, h, _ in WINDOWS:
        if z > 2:
            SC.add_light("Zimmerlicht", tuple(T.canon(*p, x, 5.3, -1.2) @ Vector((0, 0, 0))), 2700, 18, C["light"], radius=0.15)


OBSTACLES = {}


def outside(M, C):
    """Pflanzkästen unter dem Schaufenster, Topf an der Ecke, Ampeln an der Abschrägung und am
    Pilaster neben der Tür (Pflanzen kommen später)."""
    for k, x in enumerate((2.5, 4.05)):
        T.placed(C["pots"], T.canon(*S2, x), SC.planter_box, M, C["pots"], "Pflanzkasten %d" % (k + 1), SC.front_matrix(0.0, 0.0, 0.0),
                 1.2, 0.38, 0.34, seed=60 + k, gap=T.FRONT_CLEAR, mat="box", rail=False)
        OBSTACLES["Pflanzkasten %d" % (k + 1)] = T.obstacle(*S2, x, T.FRONT_CLEAR + 0.19, (1.26, 0.44), 0.38)
    T.placed(C["pots"], T.canon(*S2, 5.3), SC.pot, M, C["pots"], "Topf hinten", (0.0, -T.pot_out(0.22), 0.0), 0.22, 0.44, 63, mat="pot_dark")
    OBSTACLES["Topf hinten"] = T.obstacle(*S2, 5.3, T.pot_out(0.22), (0.48, 0.48), 0.46)
    T.placed(C["pots"], T.canon(*S1, 1.1), SC.pot, M, C["pots"], "Topf an der Ecke", (0.0, -0.36, 0.0), 0.24, 0.48, 64, mat="pot",
             style="tall")
    OBSTACLES["Topf an der Ecke"] = T.obstacle(*S1, 1.1, 0.36, (0.52, 0.52), 0.5)
    T.placed(C["deco"], T.canon(*S1, 1.1), T.hanging_basket, M, C, "Blumenampel Ecke", 0.0, 3.25, reach=0.55, drop=0.38, seed=81)
    T.placed(C["deco"], T.canon(*S2, 0.12), T.hanging_basket, M, C, "Blumenampel Tür", 0.0, HEAD - 0.12, reach=0.62, drop=0.34,
             seed=83)


def build_scene():
    T.reseed(1931)
    M, C = T.house_scene("Teeladen (Bilderbuch)")
    ops = openings()
    walls(M, C, ops)
    roof(M, C)
    windows(M, C, ops)
    shopfront(M, C)
    tea_inside(M, C, ops)
    outside(M, C)
    house = [o for k, c in C.items() if k not in ("env", "collision") for o in c.objects]
    T.settle_free(house, SETTLE, E, E + RISE, party_x=(-W / 2,))
    cols = SC.colliders(C, OBSTACLES)
    T.placed(C["env"], T.canon(*S2, seg_mid(S2)), SC.pavement, M, C, seed=340)
    return M, C, cols


def seg_mid(p):
    return T.seg_len(*p) / 2


VIEWS = {
    "tee_laden": ((10.5, 3.6, 1.8), (3.0, 3.8, 3.2), 34, (1500, 1200)),
    "tee_ecke": ((8.5, -6.0, 2.0), (1.6, 1.8, 3.4), 30, (1500, 1200)),
    "tee_tuer": ((5.6, 1.4, 1.6), (3.0, 2.6, 1.6), 30, (1400, 1000)),
    "tee_vorn": ((0.0, -10.5, 2.0), (0.0, 0.0, 3.6), 32, (1400, 1100)),
}


if __name__ == "__main__":
    T.run(build_scene, BLEND, STAMP, GAME_GLB, VIEWS, "build_storybook_tea.py")
