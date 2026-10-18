"""Wolle- und Stoffladen im Bilderbuch-Stil (Vorlagebild der Entwicklerin): Eckhaus mit sanft
abgeknickter Front (30°), cremefarbener Putz, taubenblaue Schaufenster links und rechts, die
Tür in der Abschrägung. Das Schildband mit Gesims läuft ohne Fuge um beide Ecken; das Schild
„Wolle & Stoff“ (Bild der Entwicklerin, corner_30_fascia.png) steht je einmal über den beiden
Schaufenstern, nicht über der Tür. Blumenampeln neben der Tür, Hängeschild, viele Töpfe und
Kübel (noch ohne Pflanzen), Kreidetafel; innen Regale voller Wollknäuel.

Haus "GateStreet/Corner" (Haustyp corner_30): Vorderseite 6 m, Abschrägung 2,2 m, Seite 5 m ab
der Ecke, 8 m tief, Traufe 7 m. Kanten: S0 Vorderseite, S1 Abschrägung (Tür), S2 Seitenfassade,
S3 Ende der Seite, S4 hinten, S5 Brandwand.

Aufruf:
  blender -b --factory-startup --python tools/blender/build_storybook_wool.py [-- --render [--quick] [--only=a,b]] [--no-game] [--force]
Ergebnis: assets/models/houses/wool_shop.glb und assets/models/source/houses/wool_shop_storybook.blend.
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

BLEND = os.path.join(SC.ROOT, "assets", "models", "source", "houses", "wool_shop_storybook.blend")
STAMP = os.path.join(os.path.dirname(BLEND), "wool_shop_storybook.stamp")
GAME_GLB = os.path.join(SC.ROOT, "assets", "models", "houses", "wool_shop.glb")

W, D, E = 6.0, 8.0, 7.0
OUT = T.corner_outline(W, D, 30.0, 2.2, 5.0)
S0, S1, S2, S3, S4, S5 = (T.seg(OUT, i) for i in range(6))
L0, L1, L2 = (T.seg_len(*s) for s in (S0, S1, S2))
STREET = (0, 1, 2)
RISE, RUN = 1.6, 2.2
HEAD, FASCIA_H, FASCIA_D = 2.8, 0.7, 0.3
UP_Z0, UP_H = 4.1, 1.5
DOOR_HALF = 0.5
WIN0 = (0.97, 4.53)                  # Schaufenster entlang S0
WIN2 = (0.33, 3.4)                   # Schaufenster entlang S2
SETTLE = {"wave": 0.02, "wavelength": 3.0, "lean": -0.002, "roof_sag": 0.04, "ridge_tilt": 0.0, "eaves_sag": 0.02}
SIGN = (768, 192)

UPPER = [(S0, 1.6, 0.95, True), (S0, 3.6, 0.95, True), (S1, 1.0, 0.85, False), (S2, 1.0, 0.95, True), (S2, 2.8, 0.95, True)]


def openings():
    ops = [(*S0, (WIN0[0] + WIN0[1]) / 2, 0.0, WIN0[1] - WIN0[0] - 0.04, HEAD, 0.0, 0.0),
           (*S1, L1 / 2, 0.0, 2 * DOOR_HALF + 0.24, HEAD, 0.0, 0.0),
           (*S2, (WIN2[0] + WIN2[1]) / 2, 0.0, WIN2[1] - WIN2[0] - 0.04, HEAD, 0.0, 0.0)]
    for p, x, w, _ in UPPER:
        ops.append((*p, x, UP_Z0, w, UP_H, T.RND.uniform(-1.2, 1.2), 0.0))
    return ops


def walls(M, C, ops):
    b = Body("Mauern (Putz)", M["plaster"], C["walls"], seed=1, vary=0.03)
    T.outline_walls(b, OUT, STREET, 0.0, E, step=0.22)
    T.cut(b.build(), ops)
    p = Body("Seiten- und Brandwände", M["plaster_side"], C["walls"], seed=2, vary=0.04, bevel=0.01)
    T.outline_walls(p, OUT, (3, 4, 5), 0.0, E, step=0.5)
    p.build()
    g = Body("Traufgesims", M["trim"], C["walls"], seed=3, vary=0.04, bevel=0.01)
    T.band(g, OUT, STREET, E - 0.34, 0.12, -0.02, 0.1)
    T.band(g, OUT, STREET, E - 0.22, 0.12, -0.02, 0.2)
    T.band(g, OUT, STREET, E - 0.1, 0.1, -0.02, 0.32)
    g.build()


def roof(M, C):
    T.hip_roof(M, C, "Dach", OUT, [True, True, True, False, False, False], E, RISE, RUN, 0.36, "clay", cap_mat="clay_dark",
               skip=lambda p: abs(p.x + 1.6) < 0.45 and abs(p.y - 5.6) < 0.5)
    T.chimney(M, C, "Schornstein", (-1.6, 5.6, E + RISE - 0.3), (0.55, 0.7), E + RISE + 0.9, "brick", pots=1, seed=11)
    r = Body("Dachrinne und Fallrohr", M["bronze"], C["roof"], seed=6)
    off = T.offset_polygon(OUT, [-0.44 if i in STREET else 0.0 for i in range(len(OUT))])
    r.tube([off[k].to_3d() + Vector((0, 0, E + 0.03)) for k in range(4)], 0.055, segs=10, round_ends=True)
    m = T.canon(*S0, 0.14)
    r.tube([m @ Vector((0, 0.44, E)), m @ Vector((0, 0.16, E - 0.35)), m @ Vector((0, 0.09, E - 0.7)), m @ Vector((0, 0.09, 0.15)),
            m @ Vector((0, 0.18, 0.03))], 0.034, segs=10, smooth=2, round_ends=True)
    r.build()


def upper(M, C, ops):
    for k, (p, x, w, box) in enumerate(UPPER):
        fm = T.wall_matrix(*p, x, UP_Z0, 0.0, ops[3 + k][6])
        name = "Fenster %d" % (k + 1)
        FS.window(M, C, name, 0, 0, w, UP_H, 0, panes=(2, 2), surround=False, hood=False, fm=fm, frame="frame")
        T.lintel_sill(M, C, name, fm, w, UP_H, seed=60 + k)
        if box:
            SC.planter_box(M, C["pots"], name + " Blumenkasten", fm @ Matrix.Translation((0, -0.06, 0.1)), w + 0.2, 0.2, 0.2, seed=40 + k,
                           gap=0.1, mat="box")
            kb = Body(name + " Konsolen", M["lamp_iron"], C["pots"], seed=45 + k, bevel=0.003)
            for sx in (-w / 2 + 0.06, w / 2 - 0.06):
                kb.tube([fm @ Vector((sx, -0.36, 0.04)), fm @ Vector((sx, -0.07, 0.4)), fm @ Vector((sx, -0.07, 0.04))], 0.009, segs=6,
                        round_ends=True)
            kb.build()
    T.placed(C["deco"], T.canon(*S1, 1.85), SC.projecting_sign, M, C["deco"], "Hängeschild", (0.0, 0.0, 4.15),
             SC.sign_material("corner_30", "hanging"), 0.52, 0.52 * 478 / 512, outline=SB.round_outline(arch=0.12))


def shopfront(M, C):
    sign = SC.sign_material("corner_30", "fascia")
    # Pilaster an den Enden der Schaufenster
    for p, x in ((S0, WIN0[0] - 0.12), (S0, WIN0[1] + 0.12), (S2, WIN2[0] - 0.12), (S2, WIN2[1] + 0.12)):
        T.pilaster(M, C, "Pilaster", T.wall_matrix(*p), x, HEAD, HEAD, "blue", width=0.26, seed=20 + int(10 * x))
    for name, p, (x0, x1) in (("Schaufenster links", S0, WIN0), ("Schaufenster rechts", S2, WIN2)):
        T.shop_window(M, C, name, T.wall_matrix(*p, (x0 + x1) / 2, 0.0, 0.0, T.RND.uniform(-0.3, 0.3)), x1 - x0, "blue", head=HEAD,
                      transom=2.25, transom_bars=int((x1 - x0) / 0.4), mullions=2, seed=22 + len(name))
    T.door(M, C, "Ladentür", T.wall_matrix(*S1, L1 / 2, 0.0, 0.0, T.RND.uniform(-0.4, 0.4)), DOOR_HALF, HEAD, "blue", "blue_dark",
           glazed=False, transom="bars")
    # Schildband: drei Kästen, die an den Ecken ineinanderlaufen; Schild nur über den Fenstern
    reach = FASCIA_D + 0.16
    e0 = T.band_ext(OUT, 0, reach, STREET)
    e1 = T.band_ext(OUT, 1, reach, STREET)
    e2 = T.band_ext(OUT, 2, reach, STREET)
    a, b = WIN0[0] - 0.3, L0 + e0[1]
    T.fascia(M, C, "Schildband links", T.wall_matrix(*S0, (a + b) / 2), b - a, HEAD, FASCIA_H, "blue",
             signs=[((WIN0[0] + WIN0[1]) / 2 - (a + b) / 2, 2.4, sign, SIGN[0] / SIGN[1])], depth=FASCIA_D)
    a, b = -e1[0], L1 + e1[1]
    T.fascia(M, C, "Schildband Tür", T.wall_matrix(*S1, (a + b) / 2), b - a, HEAD, FASCIA_H, "blue", depth=FASCIA_D)
    a, b = -e2[0], WIN2[1] + 0.3
    T.fascia(M, C, "Schildband rechts", T.wall_matrix(*S2, (a + b) / 2), b - a, HEAD, FASCIA_H, "blue",
             signs=[((WIN2[0] + WIN2[1]) / 2 - (a + b) / 2, 2.4, sign, SIGN[0] / SIGN[1])], depth=FASCIA_D)


def wool_inside(M, C, ops):
    """Laden: cremefarbene Wände, Dielen, hinter jedem Schaufenster ein Regal voller Wollknäuel in
    vielen Farben, unten Stoffballen; oben warme Zimmer."""
    lin = Body("Laden Wände", M["wool_wall_in"], C["inside"], seed=50, vary=0.03)
    T.outline_walls(lin, OUT, range(6), 0.0, 3.35, thick=0.03, inset=0.3, step=0.6)
    T.cut(lin.build(), [o for o in ops if o[3] < 2.0], bevel=0)
    up = Body("Zimmer oben Wände", M["in_dark"], C["inside"], seed=51, vary=0.04)
    T.outline_walls(up, OUT, range(6), 3.5, E - 0.4, thick=0.03, inset=0.3, step=0.8)
    T.cut(up.build(), [o for o in ops if o[3] > 2.0], bevel=0)
    T.floor_slab(M, C, "Laden Dielen", "wood_in", OUT, 0.29, 0.0, 0.06)
    T.floor_slab(M, C, "Laden Decke", "in_paper", OUT, 0.29, 3.33, 0.1)
    T.floor_slab(M, C, "Zimmer oben Boden", "in_dark", OUT, 0.29, 3.44, 0.06)
    T.floor_slab(M, C, "Zimmer oben Decke", "in_dark", OUT, 0.29, E - 0.45, 0.06)
    wood = Body("Wollregale", M["wood_in"], C["inside"], seed=52, vary=0.06, bevel=0.006)
    colors = ("yarn_blue", "yarn_lilac", "yarn_mint", "mustard", "sage", "rust", "blush", "linen")
    yarn = {k: Body("Wolle %s" % k, M[k], C["inside"], seed=60 + i, vary=0.08) for i, k in enumerate(colors)}
    rnd = T.RND
    for p, (x0, x1) in ((S0, WIN0), (S2, WIN2)):
        m = T.wall_matrix(*p)
        a, b = x0 + 0.15, x1 - 0.15
        depth = -1.15
        for zz in (0.45, 0.8, 1.15, 1.5, 1.85, 2.2):
            wood.box(((a + b) / 2, zz, depth), (b - a, 0.035, 0.34), step=0.5, dent=0.002, matrix=m)
            x = a + 0.08
            k = rnd.randrange(len(colors))
            while x < b - 0.08:
                r = rnd.uniform(0.05, 0.062)
                if zz < 0.5:
                    # Stoffballen liegend
                    yarn[colors[k % len(colors)]].tube([m @ Vector((x, zz + 0.07, depth - 0.15)), m @ Vector((x, zz + 0.07, depth + 0.15))],
                                                       0.06, segs=12, round_ends=True)
                    x += 0.14
                else:
                    yarn[colors[k % len(colors)]].blob(m @ Vector((x + r, zz + 0.018 + r * 0.92, depth + rnd.uniform(-0.05, 0.05))), r,
                                                       subdiv=1, lump=0.08)
                    x += 2 * r + 0.01
                if rnd.random() < 0.35:
                    k += 1
        for xs in (a, (a + b) / 2, b):
            wood.box((xs, 1.25, depth), (0.04, 2.5, 0.36), step=0.5, dent=0.002, matrix=m)
        wood.box(((a + b) / 2, 1.25, depth - 0.18), (b - a, 2.5, 0.02), step=0.5, dent=0.002, matrix=m)
    wood.build()
    for y in yarn.values():
        y.build()
    for p, x in ((S0, 2.75), (S2, 1.9), (S1, 1.1)):
        SC.add_light("Ladenlicht", tuple(T.canon(*p, x, 2.9, -0.7) @ Vector((0, 0, 0))), 3100, 50, C["light"], radius=0.2)
    for p, x, w, _ in UPPER:
        SC.add_light("Zimmerlicht", tuple(T.canon(*p, x, 5.5, -1.2) @ Vector((0, 0, 0))), 2700, 18, C["light"], radius=0.15)


OBSTACLES = {}


def outside(M, C):
    """Viele Töpfe und Kübel an der Hauswand (Pflanzen kommen später), Ampeln neben der Tür,
    Kreidetafel links von der Tür."""
    rnd = T.RND
    pots = [(S0, 0.35, 0.25, 0.5, "tub", "pot_dark"), (S0, 1.35, 0.17, 0.34, "classic", "pot"), (S0, 2.05, 0.14, 0.28, "bowl", "pot_light"),
            (S0, 3.1, 0.18, 0.36, "tall", "pot"), (S0, 3.75, 0.15, 0.3, "classic", "pot_dark"),
            (S2, 0.75, 0.16, 0.32, "classic", "pot_light"), (S2, 1.45, 0.2, 0.4, "tall", "pot"), (S2, 2.25, 0.14, 0.27, "bowl", "pot_dark"),
            (S2, 3.0, 0.17, 0.34, "classic", "pot"), (S2, 3.65, 0.24, 0.48, "tub", "pot_light")]
    for k, (p, x, r, h, style, mat) in enumerate(pots):
        out = r + 0.12 + rnd.uniform(0.0, 0.05)
        T.placed(C["pots"], T.canon(*p, x), SC.pot, M, C["pots"], "Topf %d" % (k + 1), (0.0, -out, 0.0), r, h, 70 + k, mat=mat, style=style)
        OBSTACLES["Topf %d" % (k + 1)] = T.obstacle(*p, x, out, (2 * r + 0.08, 2 * r + 0.08), h + 0.04)
    T.placed(C["pots"], T.canon(*S1, 0.2), SC.zinc_tub, M, C["pots"], "Zinkeimer an der Tür", (0.0, -0.3, 0.0), 85)
    OBSTACLES["Zinkeimer an der Tür"] = T.obstacle(*S1, 0.2, 0.3, (0.5, 0.5), 0.36)
    T.placed(C["deco"], T.canon(*S0, 4.35), SC.chalkboard, M, C["deco"], (0.0, -0.62), 8, SC.sign_material("corner_30", "chalkboard"))
    OBSTACLES["Kreidetafel"] = T.obstacle(*S0, 4.35, 0.62, (0.56, 0.42), 0.85)
    for k, x in enumerate((0.16, L1 - 0.16)):
        T.placed(C["deco"], T.canon(*S1, x), T.hanging_basket, M, C, "Blumenampel %d" % (k + 1), 0.0, HEAD - 0.12, reach=0.55, drop=0.34,
                 seed=90 + 3 * k)


def build_scene():
    T.reseed(1919)
    M, C = T.house_scene("Wolleladen (Bilderbuch)")
    ops = openings()
    walls(M, C, ops)
    roof(M, C)
    upper(M, C, ops)
    shopfront(M, C)
    wool_inside(M, C, ops)
    outside(M, C)
    house = [o for k, c in C.items() if k not in ("env", "collision") for o in c.objects]
    T.settle_free(house, SETTLE, E, E + RISE, party_x=(-W / 2,))
    cols = SC.colliders(C, OBSTACLES)
    T.placed(C["env"], T.canon(*S1, L1 / 2), SC.pavement, M, C, seed=350)
    return M, C, cols


VIEWS = {
    "wolle_vorn": ((5.5, -10.5, 2.2), (2.6, 0.6, 3.6), 30, (1600, 1150)),
    "wolle_tuer": ((3.9, -3.2, 1.6), (2.9, 0.3, 2.2), 30, (1400, 1100)),
    "wolle_ecke_links": ((0.5, -4.5, 3.4), (3.4, 0.0, 3.2), 30, (1400, 1000)),
    "wolle_fenster": ((1.8, -3.4, 1.4), (2.6, 0.8, 1.4), 32, (1400, 1000)),
}


if __name__ == "__main__":
    T.run(build_scene, BLEND, STAMP, GAME_GLB, VIEWS, "build_storybook_wool.py")
