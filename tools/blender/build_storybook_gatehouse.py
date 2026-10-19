"""Torhaus im Bilderbuch-Stil (Vorlagebild der Entwicklerin): unten Backstein mit großem Rundbogen
aus Sandstein (Bogensteine mit Schlussstein, Kämpfer, Ecksteine), dahinter ein Gewölbe durch das
ganze Haus; darüber ein grünes Schildband mit dem Schild „Alte Torgasse“ (Bild der Entwicklerin:
assets/textures/signs/gatehouse_fascia.png – frei gestaltbar, 2048 x 187 Pixel), ein vorkragendes
Fachwerk-Obergeschoss mit Terrakotta-Gefachen, vier Fenster mit Blumenkästen (noch ohne
Pflanzen), Ziegeldach mit Gaube und Schornstein, Wandlaternen und Töpfe an den Pfeilern. Vorder-
und Rückseite sind gleich gestaltet (man sieht das Tor von beiden Seiten).

Haus "GateStreet/Gatehouse" (Haustyp gatehouse: 9,8 m breit, 6 m tief, Traufe 9,4 m; Bogen 6,5 m
breit, Kämpfer 2,6 m, Scheitel 5,85 m – die Öffnung bleibt frei, die Straße baut das Spiel).

Aufruf:
  blender -b --factory-startup --python tools/blender/build_storybook_gatehouse.py [-- --render [--quick] [--only=a,b]] [--no-game] [--force]
Ergebnis: assets/models/houses/gatehouse.glb und assets/models/source/houses/gatehouse_storybook.blend.
"""

import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_storybook_shop as FS  # noqa: E402
import storybook_common as SC  # noqa: E402
import storybook_greenery as GR  # noqa: E402
import storybook_lib as SB  # noqa: E402
import storybook_town as T  # noqa: E402
from storybook_lib import Body  # noqa: E402

BLEND = os.path.join(SC.ROOT, "assets", "models", "source", "houses", "gatehouse_storybook.blend")
STAMP = os.path.join(os.path.dirname(BLEND), "gatehouse_storybook.stamp")
GAME_GLB = os.path.join(SC.ROOT, "assets", "models", "houses", "gatehouse.glb")

W, D, E = 9.8, 6.0, 9.4
HW = W / 2
A = 6.5 / 2                         # halbe Durchfahrt
SPRING = 2.6                        # Kämpferlinie
MASON, BAND, JETTY = 6.4, 0.5, 0.25
PITCH = 40.0
SPAN = D / 2 + JETTY + 0.3          # Traufe 30 cm vor dem Fachwerk
RIDGE = E + SPAN * math.tan(math.radians(PITCH))
WIN_X, WIN_Z0, WIN_W, WIN_H = (-3.3, -1.1, 1.1, 3.3), 7.4, 0.95, 1.25
DORMER = (0.5, 2.95, 0.7)           # Gaube: von y, bis y, halbe Breite
SETTLE = {"wave": 0.012, "wavelength": 3.4, "lean": -0.0015, "roof_sag": 0.07, "ridge_tilt": -0.03, "eaves_sag": 0.03}
OBSTACLES = {}


def roof_z(y):
    """Höhe der vorderen Dachfläche über y."""
    return E + (y + SPAN - D / 2) * math.tan(math.radians(PITCH))


def facade(M, C, tag):
    """Eine Torseite im Rahmen „Front bei y = 0, außen -y“ (Rückseite: um 180° gedreht gesetzt)."""
    fm = SC.front_matrix(0.0, 0.0, 0.0)
    # Backsteinwand mit Bogenöffnung (etwas größer als der Bogen: die Bogensteine fassen sie ein)
    b = Body(tag + " Mauer", M["pub_brick"], C["walls"], seed=1, vary=0.03)
    b.box((0, 0.225, (MASON + BAND) / 2), (W, 0.45, MASON + BAND), step=0.25, dent=0.006, dent_scale=1.5)
    wall = b.build()
    # Der Ausschnitt beginnt unter dem Boden (die Fahrbahn liegt tiefer als der Gehweg)
    SB.boolean_cut(wall, [SB.slab_cutter([(-A - 0.03, -0.6), (A + 0.03, -0.6)] + SB.arc_points(A + 0.03, SPRING, A + 0.03, n=32), fm,
                                         -1.0, 2.0)])
    SC.add_bevel(wall, 0.012)
    st = Body(tag + " Bogensteine", M["stone"], C["walls"], seed=2, vary=0.08, bevel=0.012)
    n = 17
    for k in range(n):
        t = math.pi * (k + 0.5) / n
        key = k == n // 2
        depth = 0.56 if key else (0.46 if k % 2 else 0.4)
        r = A + 0.005 + depth / 2
        w = 2 * (A + 0.2) * math.sin(math.pi / (2 * n)) * (1.18 if key else 0.94)
        m = SC.front_matrix(0, SPRING, 0.0) @ Matrix.Translation((r * math.cos(t), r * math.sin(t), 0.02 if not key else 0.04)) @ \
            Matrix.Rotation(t - math.pi / 2, 4, "Z")
        st.box((0, 0, 0), (w, depth, 0.1 if not key else 0.14), step=0.4, dent=0.004, matrix=m)
    # Ecksteine am Bogen (bis zum Kämpfer) und an den Hauskanten, Kämpfersteine
    rows = math.ceil((SPRING - 0.08) / 0.3)
    h = (SPRING - 0.08) / rows
    for k in range(rows):
        wdt = 0.52 if k % 2 == 0 else 0.36
        for side in (-1, 1):
            st.box((side * (A + 0.005 + wdt / 2), -0.01, k * h + h / 2), (wdt, 0.1, h - 0.012), step=0.4, dent=0.004,
                   turn=(0, T.RND.uniform(-1.2, 1.2), 0))
    for side in (-1, 1):
        st.box((side * (A + 0.35), -0.03, SPRING), (0.76, 0.14, 0.17), step=0.4, dent=0.004)
    for k in range(int((MASON - 0.2) / 0.3) + 1):
        wdt = 0.46 if k % 2 == 0 else 0.3
        for side in (-1, 1):
            st.box((side * (HW - wdt / 2), -0.01, k * 0.3 + 0.15), (wdt, 0.1, 0.288), step=0.4, dent=0.004,
                   turn=(0, T.RND.uniform(-1.2, 1.2), 0))
    st.build()
    # Schildband (grün) mit dem Schild der Entwicklerin
    sb = Body(tag + " Schildband", M["bottle"], C["shop"], seed=3, vary=0.04, bevel=0.012)
    sb.box((0, (0.1 - JETTY) / 2, MASON + BAND / 2), (W, 0.1 + JETTY, BAND), step=0.3, dent=0.003)
    sb.box((0, -JETTY - 0.02, MASON + 0.03), (W, 0.07, 0.06), step=0.3, dent=0.002)
    sb.build()
    h = BAND - 0.08
    sg = Body(tag + " Schild", SC.sign_material("gatehouse", "fascia"), C["shop"], seed=4, vary=0.0)
    sg.panel(SC.front_matrix(0.0, MASON + BAND / 2, -JETTY + 0.005, T.RND.uniform(-0.3, 0.3)), h * 2048 / 187, h, 0.04)
    sg.build()
    # Fachwerk-Obergeschoss: Gefache (Terrakotta) mit Fensteröffnungen, Balken davor
    up = Body(tag + " Gefache", M["infill"], C["walls"], seed=5, vary=0.05)
    up.box((0, -JETTY + 0.15, (MASON + BAND + E) / 2), (W, 0.3, E - MASON - BAND), step=0.25, dent=0.006, dent_scale=1.5)
    upw = up.build()
    T.cut(upw, [((-HW, -JETTY), (HW, -JETTY), x + HW, WIN_Z0, WIN_W, WIN_H, 0.0, 0.0) for x in WIN_X])
    tb = Body(tag + " Fachwerk", M["oak_dark"], C["walls"], seed=6, vary=0.08, bevel=0.01)
    y = -JETTY - 0.012
    z0, z1 = MASON + BAND, E
    tb.box((0, y, z0 + 0.09), (W + 0.04, 0.08, 0.18), step=0.3, dent=0.004)
    tb.box((0, y, z1 - 0.09), (W + 0.04, 0.08, 0.18), step=0.3, dent=0.004)
    posts = [-HW + 0.08, -3.85, -2.75, -1.65, -0.55, 0.55, 1.65, 2.75, 3.85, HW - 0.08]
    for x in posts:
        tb.box((x, y, (z0 + z1) / 2), (0.16, 0.07, z1 - z0), step=0.3, dent=0.004)
    for k in range(len(posts) - 1):
        a, c = posts[k], posts[k + 1]
        window = any(abs((a + c) / 2 - wx) < 0.1 for wx in WIN_X)
        if window:
            tb.box(((a + c) / 2, y, WIN_Z0 - 0.08), (c - a, 0.07, 0.15), step=0.3, dent=0.004)
            tb.box(((a + c) / 2, y, WIN_Z0 + WIN_H + 0.08), (c - a, 0.07, 0.15), step=0.3, dent=0.004)
        else:
            # Andreaskreuz im Feld zwischen den Fenstern
            for sgn in (-1, 1):
                p0 = Vector((a + 0.06 if sgn > 0 else c - 0.06, y, z0 + 0.16))
                p1 = Vector((c - 0.06 if sgn > 0 else a + 0.06, y, z1 - 0.16))
                tb.span(p0, p1, 0.065 if sgn > 0 else 0.06, 0.14, step=0.3, dent=0.003)
    tb.build()
    for k, x in enumerate(WIN_X):
        wm = SC.front_matrix(x, WIN_Z0, -JETTY)
        name = "%s Fenster %d" % (tag, k + 1)
        FS.window(M, C, name, 0, 0, WIN_W, WIN_H, 0, panes=(2, 2), surround=False, hood=False, fm=wm, frame="bottle_dark")
        SC.planter_box(M, C["pots"], name + " Blumenkasten", wm @ Matrix.Translation((0, -0.06, 0.06)), WIN_W + 0.16, 0.2, 0.2,
                       seed=40 + k, gap=0.08, mat="box")
        kb = Body(name + " Konsolen", M["lamp_iron"], C["pots"], seed=45 + k, bevel=0.003)
        for sx in (-WIN_W / 2 + 0.06, WIN_W / 2 - 0.06):
            kb.tube([wm @ Vector((sx, -0.32, 0.03)), wm @ Vector((sx, -0.07, 0.34)), wm @ Vector((sx, -0.07, 0.03))], 0.009, segs=6,
                    round_ends=True)
        kb.build()
    # Wandlaternen auf den Pfeilern, Töpfe am Fuß; Glyzinie wächst wild über die Pfeiler und den Bogen
    # Bogen als Treppe aus Streifen (so darf die Glyzinie in die Zwickel neben und über dem Rundbogen)
    holes = [(HW - A - 0.18, 0.0, HW + A + 0.18, SPRING), (0.0, MASON - 0.12, W, MASON + BAND + 0.1)]
    R = A + 0.32
    v = SPRING
    while v < SPRING + R:
        half = math.sqrt(max(0.0, R * R - (v - SPRING) ** 2))
        holes.append((HW - half - 0.05, v, HW + half + 0.05, v + 0.2))
        v += 0.2
    roots = []
    rr = random.Random(771 if tag == "Vorn" else 772)   # eigener Zufall: der Rest des Hauses bleibt, wie er ist
    for side in (-1, 1):
        T.wall_lantern(M, C, "%s Laterne %s" % (tag, "links" if side < 0 else "rechts"), side * (A + 0.98), 3.55, seed=130 + side)
        holes.append((HW + side * (A + 0.98) - 0.24, 3.2, HW + side * (A + 0.98) + 0.24, 3.95))   # Wandlaterne
        for j, (dx, r, hgt, mat) in enumerate(((0.62, 0.22, 0.44, "pot"), (1.02, 0.18, 0.36, "pot_dark"))):
            holes.append((HW + side * (A + dx) - r - 0.06, 0.0, HW + side * (A + dx) + r + 0.06, hgt + 0.15))
        roots.append((HW + side * (HW - 0.28), 0.0))
    GR.plant_palette(M)
    ivy = GR.Plant(M, C["deco"], seed=771 if tag == "Vorn" else 772)
    GR.wall_ivy(ivy, W, MASON - 0.15, holes, rr, lambda u, v, w: (u - HW, -w, v), roots, reach=(0.45, 1.0), kind="wisteria",
                bumps=[(0.0, 0.5, 0.06)], density=0.8)
    ivy.build()
    for side in (-1, 1):
        for j, (dx, r, hgt, mat) in enumerate(((0.62, 0.22, 0.44, "pot"), (1.02, 0.18, 0.36, "pot_dark"))):
            x = side * (A + dx)
            SC.pot(M, C["pots"], "%s Topf %s %d" % (tag, "links" if side < 0 else "rechts", j + 1), (x, -0.32, 0.0), r, hgt,
                   150 + j + (side > 0) * 5, mat=mat, style="classic" if j else "tall")


def body(M, C):
    """Gewölbe, Wände der Durchfahrt, Seitenwände, Giebel, Zimmer oben."""
    v = Body("Gewölbe", M["vault"], C["walls"], seed=10, vary=0.05)
    outline = [(math.cos(t) * (A + 0.42), math.sin(t) * (A + 0.42)) for t in [math.pi * k / 32 for k in range(33)]] + \
              [(math.cos(t) * (A + 0.002), math.sin(t) * (A + 0.002)) for t in [math.pi * (32 - k) / 32 for k in range(33)]]
    v.slab(outline, D - 0.04, Matrix.Translation((0, D - 0.02, SPRING)) @ Matrix.Rotation(math.pi / 2, 4, "X"), dent=0.002)
    for side in (-1, 1):
        v.box((side * (A + 0.21), D / 2, (SPRING + 0.06) / 2), (0.42, D - 0.04, SPRING + 0.06), step=0.4, dent=0.004)
    v.build()
    s = Body("Seitenwände und Giebel", M["plaster_side"], C["walls"], seed=11, vary=0.04, bevel=0.01)
    for p0, p1 in (((HW, -JETTY), (HW, D + JETTY)), ((-HW, D + JETTY), (-HW, -JETTY))):
        # unten (Mauerwerk) bündig mit Vorder- und Rückseite, oben um die Vorkragung länger
        T.wall_run(s, p0, p1, 0.0, MASON - 0.02, step=0.5, ext=(-JETTY, -JETTY))
        T.wall_run(s, p0, p1, MASON - 0.02, E, step=0.5)
        s.slab([(0.0, E - 0.03), (D + 2 * JETTY, E - 0.03), (D / 2 + JETTY, RIDGE - 0.3)], 0.3,
               T.wall_matrix(p0, p1) @ Matrix.Translation((0, 0, -0.3)), dent=0.006)
    s.build()
    rm = Body("Zimmer oben", M["in_dark"], C["inside"], seed=12, vary=0.04)
    rm.box((0, D / 2, MASON + BAND + 0.05), (W - 0.6, D, 0.1), step=0.8, dent=0.003)
    rm.box((0, D / 2, E - 0.3), (W - 0.6, D, 0.1), step=0.8, dent=0.003)
    rm.box((0, D / 2, (MASON + BAND + E) / 2), (W - 0.6, 0.1, E - MASON - BAND), step=0.8, dent=0.003)
    rm.build()
    for x in WIN_X:
        for y in (1.0, D - 1.0):
            SC.add_light("Zimmerlicht", (x, y, 8.4), 2700, 16, C["light"], radius=0.15)
    for y in (1.5, D - 1.5):
        SC.add_light("Gewölbelicht", (0.0, y, 5.0), 2800, 40, C["light"], radius=0.2)


def roof(M, C):
    dx, dy0, dy1 = DORMER[2], DORMER[0], DORMER[1]

    def skip(p):
        # nur am Schornstein aussparen; unter der Gaube liegen die Ziegel verdeckt im Gaubenkörper
        return abs(p.x - 3.3) < 0.45 and abs(p.y - 3.6) < 0.5
    T.pitched_roof(M, C, "Dach", Matrix.Translation((0, D / 2, 0)), W, SPAN, E, PITCH, "clay", cap_mat="clay_dark", ends=(0.1, 0.1),
                   skip=skip, seed=20)
    T.chimney(M, C, "Schornstein", (3.3, 3.6, RIDGE - 0.6), (0.6, 0.75), RIDGE + 1.0, "pub_brick", pots=2, seed=21)
    # Gaube: Gefach mit Fenster, kleines Satteldach, Ortgang
    z0 = roof_z(dy0) - 0.25
    eaves = z0 + 1.2
    g = Body("Gaube", M["infill"], C["roof"], seed=22, vary=0.05)
    g.box((0, (dy0 + dy1) / 2, (z0 + eaves) / 2), (2 * dx, dy1 - dy0, eaves - z0), step=0.25, dent=0.004)
    dsp = dx + 0.08
    dpitch = 45.0
    dridge = eaves + dsp * math.tan(math.radians(dpitch))
    g.slab([(-dx, eaves - 0.02), (dx, eaves - 0.02), (0.0, dridge - 0.14)], dy1 - dy0 - 0.1,
           Matrix.Translation((0, dy1 - 0.05, 0)) @ Matrix.Rotation(math.pi / 2, 4, "X"), dent=0.003)
    gw = g.build()
    T.cut(gw, [((-dx, dy0), (dx, dy0), dx, z0 + 0.35, 0.62, 0.62, 0.0, 0.0)])
    FS.window(M, C, "Gaubenfenster", 0, 0, 0.62, 0.62, 0, panes=(2, 2), surround=False, hood=False,
              fm=SC.front_matrix(0.0, z0 + 0.35, dy0), frame="bottle_dark")
    frame = Matrix(((0, -1, 0, 0), (1, 0, 0, (dy0 + dy1) / 2 - 0.05), (0, 0, 1, 0), (0, 0, 0, 1)))
    T.pitched_roof(M, C, "Gaubendach", frame, dy1 - dy0 + 0.1, dsp, eaves, dpitch, "clay", cap_mat="clay_dark", ends=(0.0, 0.1), seed=23)
    gb = Body("Gaube Ortgang", M["oak_dark"], C["roof"], seed=24, vary=0.05, bevel=0.008)
    for side in (-1, 1):
        gb.span(Vector((side * (dsp + 0.04), dy0 - 0.13, eaves - 0.08)), Vector((0.0, dy0 - 0.13, dridge + 0.08)), 0.04, 0.16, step=0.3,
                dent=0.002)
    gb.box((0, dy0 - 0.03, z0 + 0.1), (2 * dx + 0.04, 0.08, 0.14), step=0.3, dent=0.002)
    for side in (-1, 1):
        gb.box((side * (dx - 0.04), dy0 - 0.03, (z0 + eaves) / 2), (0.1, 0.08, eaves - z0), step=0.3, dent=0.002)
    gb.build()
    # Dachrinnen vorn und hinten
    r = Body("Dachrinnen", M["bronze"], C["roof"], seed=25)
    for side in (-1, 1):
        y = D / 2 + side * (SPAN + 0.05)
        r.tube([(-HW - 0.06, y, E + 0.03), (0, y, E + 0.01), (HW + 0.06, y, E + 0.03)], 0.055, segs=10, round_ends=True)
    r.build()


def build_scene():
    T.reseed(1888 + 9)
    M, C = T.house_scene("Torhaus (Bilderbuch)", inside="Zimmer oben")
    T.placed(C["walls"], Matrix(), facade, M, C, "Vorn")
    T.placed(C["walls"], Matrix.Translation((0, D, 0)) @ Matrix.Rotation(math.pi, 4, "Z"), facade, M, C, "Hinten")
    body(M, C)
    roof(M, C)
    for side in (-1, 1):
        for j, (dx, r) in enumerate(((0.62, 0.22), (1.02, 0.18))):
            OBSTACLES["Topf vorn %d %d" % (side, j)] = ((side * (A + dx), -0.32), (2 * r + 0.08, 2 * r + 0.08), 0.46)
            OBSTACLES["Topf hinten %d %d" % (side, j)] = ((-side * (A + dx), D + 0.32), (2 * r + 0.08, 2 * r + 0.08), 0.46)
    house = [o for k, c in C.items() if k not in ("env", "collision") for o in c.objects]
    T.settle_free(house, SETTLE, E, RIDGE, party_x=(-HW, HW))
    cols = SC.colliders(C, OBSTACLES)
    SC.pavement(M, C, seed=360)
    return M, C, cols


VIEWS = {
    "torhaus_vorn": ((0.0, -17.0, 2.2), (0.0, 0.0, 6.4), 34, (1500, 1400)),
    "torhaus_bogen": ((2.4, -6.0, 1.7), (0.0, 2.0, 3.8), 26, (1500, 1100)),
    "torhaus_fachwerk": ((-3.5, -6.5, 6.5), (-1.6, 0.0, 8.2), 30, (1500, 1100)),
    "torhaus_hinten": ((-1.5, 22.0, 2.5), (0.0, 6.0, 6.4), 32, (1500, 1300)),
}


if __name__ == "__main__":
    T.run(build_scene, BLEND, STAMP, GAME_GLB, VIEWS, "build_storybook_gatehouse.py")
