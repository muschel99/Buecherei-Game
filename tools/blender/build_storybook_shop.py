"""Modegeschäft "Zwirn und Zwirbel" im Bilderbuch-Stil – eigenes Modell nach dem Vorlagebild
der Entwicklerin (warme Kinderbuch-Illustration: cremefarbener Putz, taubenblaue Ladenfront,
terrakotta-rosa Markisen, Gauben mit Blumenkästen, Efeu, Buchsbäume, Kopfsteinpflaster).

Unabhängig von den bisherigen Modellen (build_houses.py bleibt, wie es ist).

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_storybook_shop.py
    blender -b --factory-startup --python tools/blender/build_storybook_shop.py -- --render
    blender -b --factory-startup --python tools/blender/build_storybook_shop.py -- --render --quick

Ergebnis:
    assets/models/source/houses/fashion_shop_storybook.blend   zum Anschauen und Weiterbauen (Einzelteile)
    assets/models/houses/fashion_shop.glb (+ .import)         fürs Spiel (Teile je Material zusammengefasst,
                                                              Knoten "Model" in scenes/world/houses/fashion_shop.tscn)
    assets/materials/storybook/*.tres                         Godot-Materialien (Shader storybook.gdshader)
    screenshots/blender/storybook/*.png                       Bilder (mit --render)
Mit --no-game nur die .blend (ohne Spiel-Dateien).

Aufbau in Blender (Outliner): Sammlung "Modegeschäft (Bilderbuch)" mit Mauern, Dach, Fenster,
Laden, Innen, Pflanzen, Deko, Licht; "Umgebung (nur Vorschau)" = Gehweg und Pflaster.
Jedes Teil ist ein geschlossener Körper (prüfbar: am Ende steht die Zahl offener Kanten).

Maße wie das Modegeschäft im Spiel: 5,4 m breit, 8 m tief, Traufe 6,8 m – so kann das Modell
später an derselben Stelle stehen (Wege und Kollision bleiben).
"""

import bpy
import math
import os
import random
import sys
import zlib

from mathutils import Matrix, Vector, noise

sys.path.insert(0, os.path.dirname(__file__))
import storybook_common as SC  # noqa: E402
import storybook_lib as SB  # noqa: E402
import storybook_parts as SP  # noqa: E402
from storybook_common import add_bevel, add_light, front_matrix  # noqa: E402
from storybook_lib import Body  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLEND = os.path.join(ROOT, "assets", "models", "source", "houses", "fashion_shop_storybook.blend")

W, D, E = 5.4, 8.0, 6.8          # Breite, Tiefe, Traufhöhe
HW = W / 2
PITCH = 38.0                      # Dachneigung (Grad)
EAVES_Y = -0.32                   # Dachkante vorn
RIDGE_Y = D / 2
RIDGE = E + (RIDGE_Y - EAVES_Y) * math.tan(math.radians(PITCH))
SLOPE = (RIDGE_Y - EAVES_Y) / math.cos(math.radians(PITCH))
SHOP_TOP = 3.62                   # Oberkante Ladengesims
WIN_X = (-1.7, 0.0, 1.7)          # Fenster im Obergeschoss
WIN_W, WIN_Z0, WIN_H = 0.92, 4.3, 1.58
DORMER_X, DORMER_FY = (-1.85, 1.85), 0.62   # Gauben: Mitte und Lage der Front

# Wölbung dieses Hauses (jedes Haus bekommt eigene Werte)
SETTLE = {"wave": 0.018, "wavelength": 3.4, "lean": 0.004, "roof_sag": 0.075, "ridge_tilt": 0.035, "eaves_sag": 0.025}

RND = random.Random(1907)


# --- Hilfen ---

def roof_point(x, s, h=0.0):
    """Punkt auf der vorderen Dachfläche: s = Weg hangaufwärts ab der Traufe, h = über der Fläche."""
    a = math.radians(PITCH)
    return Vector((x, EAVES_Y + s * math.cos(a) - h * math.sin(a), E + s * math.sin(a) + h * math.cos(a)))


def roof_z(y):
    """Höhe der vorderen Dachfläche über der Stelle y."""
    return E + (y - EAVES_Y) * math.tan(math.radians(PITCH))


# --- Mauern, Gesimse, Dach ---

def walls(M, C):
    # Obere Front aus Putz, Fensteröffnungen leicht schief ausgeschnitten
    b = Body("Fassade oben (Putz)", M["plaster"], C["walls"], seed=1, vary=0.03)
    b.box((0, 0.15, (SHOP_TOP - 0.12 + E) / 2), (W, 0.3, E - SHOP_TOP + 0.12), step=0.22, dent=0.007, dent_scale=1.5)
    wall = b.build()
    cuts = [SB.cutter((0, WIN_H / 2, 0), (WIN_W, WIN_H, 1.0), matrix=front_matrix(x + dx, WIN_Z0, 0.0, t)) for x, dx, t in WIN_JITTER]
    SB.boolean_cut(wall, cuts)
    add_bevel(wall, 0.012)
    # Seitenwände, Rückwand, Giebel
    b = Body("Seitenwände und Giebel", M["plaster_side"], C["walls"], seed=2, vary=0.04, bevel=0.01)
    for side in (-1, 1):
        b.box((side * (HW - 0.15), D / 2 + 0.01, E / 2), (0.3, D - 0.02, E), step=0.4, dent=0.006)
        m = Matrix.Translation((side * HW - (0.3 if side > 0 else 0), 0, 0)) @ Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
        b.slab([(0.0, E), (D, E), (RIDGE_Y, RIDGE + 0.05)], 0.3, m, dent=0.006)
    b.box((0, D - 0.15, E / 2), (W - 0.6, 0.3, E), step=0.5, dent=0.006)
    b.build()
    # Ecksteine (Sandstein, abwechselnd lang und kurz) und Gurtgesims über dem Laden
    b = Body("Ecksteine", M["stone"], C["walls"], seed=3, vary=0.08, bevel=0.012)
    z = SHOP_TOP + 0.26
    k = 0
    while z + 0.3 < E - 0.45:
        long_ = k % 2 == 0
        wdt = 0.4 if long_ else 0.26
        for side in (-1, 1):
            b.box((side * (HW - wdt / 2 - 0.004), -0.025, z + 0.14), (wdt, 0.06, 0.27), step=0.3, dent=0.004,
                  turn=(0, RND.uniform(-1.2, 1.2), 0))
        z += 0.3
        k += 1
    b.build()
    b = Body("Gurtgesims", M["trim"], C["walls"], seed=4, vary=0.04, bevel=0.012)
    b.box((0, -0.04, SHOP_TOP + 0.16), (W + 0.02, 0.1, 0.13), step=0.3, dent=0.004)
    b.build()


def eaves_cornice(M, C):
    """Traufgesims mit Zahnschnitt (jeder Zahn etwas anders) und Dachrinne."""
    b = Body("Traufgesims", M["trim"], C["walls"], seed=5, vary=0.04, bevel=0.01)
    b.box((0, 0.0, E - 0.36), (W + 0.04, 0.16, 0.1), step=0.3, dent=0.004)
    x = -HW + 0.09
    while x < HW - 0.08:
        b.box((x, -0.08, E - 0.265), (0.07 * RND.uniform(0.92, 1.08), 0.09, 0.09), step=1, dent=0.003,
              turn=(0, RND.uniform(-2, 2), 0))
        x += 0.145
    b.box((0, -0.06, E - 0.17), (W + 0.06, 0.24, 0.1), step=0.3, dent=0.004)
    b.box((0, -0.1, E - 0.075), (W + 0.1, 0.36, 0.1), step=0.3, dent=0.004)
    b.build()
    b = Body("Dachrinne", M["bronze"], C["roof"], seed=6)
    b.tube([(-HW - 0.05, -0.36, E + 0.02), (0, -0.37, E + 0.0), (HW + 0.05, -0.36, E + 0.02)], 0.055, segs=10)
    b.build()


def roof(M, C):
    a = math.radians(PITCH)
    rm = Matrix.Translation(roof_point(0, 0)) @ Matrix.Rotation(-a, 4, "X") @ Matrix(((1, 0, 0, 0), (0, -1, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1)))
    # Dachflächen (Körper mit Dicke), vorn und hinten
    b = Body("Dachflächen", M["roof"], C["roof"], seed=7, vary=0.04, bevel=0.01)
    front = Matrix.Translation(roof_point(0, SLOPE / 2, -0.09)) @ Matrix.Rotation(a, 4, "X")
    b.box((0, 0, 0), (W + 0.3, SLOPE, 0.16), step=0.3, dent=0.006, matrix=front)
    back_center = Vector((0, 2 * RIDGE_Y - roof_point(0, SLOPE / 2, -0.09).y, roof_point(0, SLOPE / 2, -0.09).z))
    back = Matrix.Translation(back_center) @ Matrix.Rotation(-a, 4, "X")
    b.box((0, 0, 0), (W + 0.3, SLOPE, 0.16), step=0.4, dent=0.006, matrix=back)
    b.build()
    # Ziegel in Reihen auf der Vorderseite: versetzt, jeder etwas anders breit und schief
    b = Body("Dachziegel", M["roof"], C["roof"], seed=8, vary=0.13, bevel=0.006)
    row = 0
    s = 0.02
    sin_a = math.sin(a)

    def covered(x, s):
        """Liegt der Ziegel unter Ziergiebel, Gaube oder Schornstein? (Nur dort fehlen Ziegel.)"""
        h = s * sin_a
        if abs(x) < 1.36 and h + 0.04 < 1.1 * (1 - abs(x) / 1.36):
            return True
        for cx in DORMER_X:
            dx = abs(x - cx)
            base = roof_z(DORMER_FY) - 0.18
            s_front = (DORMER_FY - EAVES_Y) / math.cos(a)
            if dx < 0.52 and s > s_front - 0.12 and E + h < base + 0.96 + 0.52 * (1 - dx / 0.64) + 0.12:
                return True
        for cx in (-HW + 0.42, HW - 0.42):
            if abs(x - cx) < 0.36 and (2.22 - EAVES_Y) / math.cos(a) < s + 0.15 < (3.18 - EAVES_Y) / math.cos(a):
                return True
        return False
    while s < SLOPE - 0.15:
        x = -HW - 0.12 + (0.13 if row % 2 else 0.0)
        while x < HW + 0.1:
            tw = 0.25 * RND.uniform(0.85, 1.12)
            cx = x + tw / 2
            if not covered(cx, s + 0.15) and abs(cx) < HW + 0.1:
                p = roof_point(cx, s + 0.15, 0.012)
                m = Matrix.Translation(p) @ Matrix.Rotation(a - math.radians(RND.uniform(2.5, 5.5)), 4, "X") @ \
                    Matrix.Rotation(math.radians(RND.uniform(-2.5, 2.5)), 4, "Z")
                b.box((0, 0, 0), (tw - 0.012, 0.3, 0.022), step=1, dent=0.003, matrix=m)
            x += tw
        s += 0.205
        row += 1
    b.build()
    # First (Terrakotta-Halbrund) und Ortgänge
    b = Body("First", M["terra"], C["roof"], seed=9, vary=0.07, bevel=0.0)
    b.tube([(-HW - 0.12, RIDGE_Y, RIDGE + 0.05), (0, RIDGE_Y, RIDGE + 0.07), (HW + 0.12, RIDGE_Y, RIDGE + 0.05)], 0.09, segs=10, wobble=0.04)
    b.build()


def pediment(M, C):
    """Ziergiebel in der Mitte: Putzdreieck, Terrakotta-Abdeckung, Rosette, kleines Dach dahinter."""
    turn = RND.uniform(-1.2, 1.2)
    b = Body("Ziergiebel", M["trim"], C["walls"], seed=10, vary=0.04, bevel=0.01)
    m = Matrix.Translation((0, -0.12, E - 0.02)) @ Matrix.Rotation(math.radians(turn), 4, "Y") @ \
        Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    b.slab([(-1.2, 0.0), (1.2, 0.0), (0.0, 1.0)], 1.8, m, dent=0.005)
    # Rosette: Scheibe mit Blütenblättern
    rz = E + 0.36
    b.lathe([(0.0, 0.0), (0.19, 0.0), (0.2, 0.03), (0.16, 0.06), (0.0, 0.065)], (0, -0.12, rz), segs=20, dent=0.002, turn=(90, 0))
    for k in range(8):
        ang = 2 * math.pi * k / 8 + 0.2
        c = Vector((0.1 * math.cos(ang), -0.19, rz + 0.1 * math.sin(ang)))
        b.blob(c, 0.035, subdiv=1, lump=0.1, scale=(1, 0.6, 1))
    b.blob((0, -0.2, rz), 0.045, subdiv=1, lump=0.08, scale=(1, 0.7, 1))
    b.build()
    b = Body("Ziergiebel Abdeckung", M["terra"], C["roof"], seed=11, vary=0.07, bevel=0.012)
    for side in (-1, 1):
        b.span((side * 1.36, -0.2, E - 0.04), (0, -0.2, E + 1.1), 0.12, 0.11, step=0.25)
    b.build()
    b = Body("Ziergiebel Dach", M["roof"], C["roof"], seed=12, vary=0.08, bevel=0.008)
    for side in (-1, 1):
        lo, hi = Vector((side * 1.34, -0.14, E + 0.02)), Vector((0, -0.14, E + 1.12))
        mid = (lo + hi) / 2
        d = (hi - lo)
        ang = math.atan2(d.z, abs(d.x)) * side
        m = Matrix.Translation(mid + Vector((0, 0.95, -0.03))) @ Matrix.Rotation(ang, 4, "Y")
        b.box((0, 0, 0), (d.length, 1.9, 0.06), step=0.3, dent=0.004, matrix=m)
    b.build()


def chimneys(M, C):
    for side in (-1, 1):
        x = side * (HW - 0.42)
        y = 2.7
        base = roof_z(y) - 0.4
        top = base + 2.05
        t = RND.uniform(-1.4, 1.4)
        b = Body("Schornstein %s" % ("links" if side < 0 else "rechts"), M["brick"], C["roof"], seed=20 + side, vary=0.04, bevel=0.01)
        b.box((x, y, (base + top) / 2), (0.62, 0.86, top - base), step=0.25, dent=0.006, turn=(t, RND.uniform(-1, 1), 0))
        b.build()
        b = Body("Schornstein Abdeckung %s" % ("links" if side < 0 else "rechts"), M["trim"], C["roof"], seed=22 + side, bevel=0.01)
        b.box((x + t * 0.01, y, top + 0.04), (0.74, 0.98, 0.09), step=0.3, dent=0.004, turn=(t, 0, 0))
        b.build()
        b = Body("Schornstein Töpfe %s" % ("links" if side < 0 else "rechts"), M["terra"], C["roof"], seed=24 + side, vary=0.1)
        for k, dy in enumerate((-0.2, 0.2)):
            h = 0.38 + 0.08 * k
            b.lathe([(0.11, 0.0), (0.095, h * 0.7), (0.11, h * 0.8), (0.11, h), (0.075, h), (0.075, 0.06)],
                    (x + t * 0.012, y + dy, top + 0.08), segs=14, dent=0.003, turn=(RND.uniform(-3, 3), RND.uniform(-3, 3)))
        b.build()


# --- Fenster ---

def window(M, C, name, cx, z0, w, h, turn, panes=(2, 2), wall_y=0.0, surround=True, curtains=True, hood=True,
           sill=True, fm=None, frame="frame"):
    """Schiebefenster mit Rahmen, Sprossen, Glas und Vorhängen; alles in derselben leicht
    schiefen Ebene (turn) wie die ausgeschnittene Öffnung. fm = Ebene direkt vorgeben."""
    fm = fm or front_matrix(cx, z0, wall_y, turn)   # lokal: x quer, y hoch, z zur Straße
    b = Body("%s Rahmen" % name, M[frame], C["windows"], seed=zlib.crc32(name.encode()) % 1000, vary=0.03, bevel=0.006)
    back = -0.12
    f = 0.065
    hx = w / 2
    def lbox(c, s, step=0.3):
        b.box(c, s, step=step, dent=0.002, matrix=fm)
    lbox((-hx + f / 2, h / 2, back), (f, h, 0.07))
    lbox((hx - f / 2, h / 2, back), (f, h, 0.07))
    lbox((0, f / 2, back), (w - 2 * f, f, 0.07))
    lbox((0, h - f / 2, back), (w - 2 * f, f, 0.07))
    lbox((0, h / 2, back + 0.012), (w - 2 * f, 0.055, 0.075))
    for half, dz in ((0, 0.0), (1, 0.014)):
        y0 = f + half * (h / 2 - f + 0.03)
        y1 = y0 + h / 2 - f - 0.03
        for c in range(1, panes[0]):
            xx = -hx + f + (w - 2 * f) * c / panes[0]
            lbox((xx, (y0 + y1) / 2, back - 0.005 + dz), (0.026, y1 - y0, 0.045))
        for r in range(1, panes[1]):
            yy = y0 + (y1 - y0) * r / panes[1]
            lbox((0, yy, back - 0.005 + dz), (w - 2 * f, 0.026, 0.045))
    b.build()
    g = Body("%s Glas" % name, M["glass"], C["windows"], seed=1)
    g.box((0, h / 2, back - 0.03), (w - 0.02, h - 0.02, 0.006), step=10, dent=0.0, matrix=fm)
    g.build()
    if curtains:
        c = Body("%s Vorhänge" % name, M["curtain"], C["windows"], seed=zlib.crc32(name.encode()) % 977, vary=0.05)
        for side in (-1, 1):
            cw = w * RND.uniform(0.26, 0.34)
            x0 = side * hx - (cw if side > 0 else 0) + side * 0.02
            folds = RND.randint(4, 6)
            origin = fm @ Vector((x0, 0.02, back - 0.12))
            u = (fm.to_3x3() @ Vector((cw, 0, 0)))
            v = (fm.to_3x3() @ Vector((0, h - 0.06, 0)))
            c.sheet(origin, u, v, 16, 10, 0.008,
                    offset=lambda uu, vv, f_=folds: 0.025 * math.sin(uu * math.pi * f_) * (0.6 + 0.4 * vv))
        c.build()
    if surround:
        s = Body("%s Faschen" % name, M["trim"], C["windows"], seed=zlib.crc32(name.encode()) % 991, vary=0.04, bevel=0.01)
        sw = 0.1
        for x0, x1, y0, y1 in ((-hx - sw, -hx, -0.02, h + sw), (hx, hx + sw, -0.02, h + sw), (-hx, hx, h, h + sw)):
            s.box(((x0 + x1) / 2, (y0 + y1) / 2, 0.025), (x1 - x0, y1 - y0, 0.05), step=0.3, dent=0.003, matrix=fm)
        if sill:
            s.box((0, -0.045, 0.09), (w + 0.34, 0.09, 0.22), step=0.3, dent=0.004, matrix=fm)
            for sx in (-hx - 0.05, hx + 0.05):
                s.box((sx, -0.16, 0.04), (0.09, 0.15, 0.08), step=1, dent=0.003, matrix=fm)
        if hood:
            s.box((0, h + sw + 0.05, 0.05), (w + 0.36, 0.1, 0.1), step=0.3, dent=0.003, matrix=fm)
            s.box((0, h + sw + 0.13, 0.08), (w + 0.48, 0.07, 0.16), step=0.3, dent=0.003, matrix=fm)
            for sx in (-hx - 0.13, hx + 0.13):
                s.box((sx, h + sw - 0.04, 0.06), (0.08, 0.16, 0.12), step=1, dent=0.003, matrix=fm)
        s.build()
    return fm


def upper_windows(M, C):
    for k, (x, dx, t) in enumerate(WIN_JITTER):
        fm = window(M, C, "Fenster %d" % (k + 1), x + dx, WIN_Z0, WIN_W, WIN_H, t)
        SC.planter_box(M, C["pots"], "Blumenkasten Fenster %d" % (k + 1), fm, WIN_W + 0.16, 0.22, 0.24, seed=40 + k)


def dormers(M, C):
    a = math.radians(PITCH)
    for k, cx in enumerate(DORMER_X):
        t = RND.uniform(-1.8, 1.8)
        fy = DORMER_FY
        base = roof_z(fy) - 0.18
        top = base + 1.0
        name = "Gaube %s" % ("links" if cx < 0 else "rechts")
        fm = front_matrix(cx, base, fy, t)
        b = Body("%s Wände und Giebel" % name, M["trim"], C["walls"], seed=60 + k, vary=0.04)
        depth = (top + 0.45 - E) / math.tan(a) + EAVES_Y - fy + 0.3
        # Hausform: Wände bis 1,0 m, darüber der Giebel bis knapp unter das Dach
        roof_at = lambda x: 0.96 + (0.52 / 0.64) * (0.64 - abs(x)) - 0.012
        b.slab([(-0.5, 0.0), (0.5, 0.0), (0.5, roof_at(0.5)), (0.0, roof_at(0.0)), (-0.5, roof_at(-0.5))], depth,
               fm @ Matrix.Translation((0, 0, -depth)), dent=0.004)
        wall = b.build()
        cut = SB.cutter((0, 0.56, -0.2), (0.54, 0.64, 0.5), matrix=fm)
        SB.boolean_cut(wall, [cut])
        add_bevel(wall, 0.012)
        ro = Body("%s Rosette" % name, M["trim"], C["walls"], seed=68 + k, vary=0.03, bevel=0.004)
        ro.lathe([(0.0, 0.0), (0.075, 0.0), (0.08, 0.015), (0.06, 0.03), (0.0, 0.035)], fm @ Vector((0, 1.2, -0.005)), segs=18,
                 turn=(90, 0))
        ro.build()
        window(M, C, name + " Fenster", 0, 0, 0.54, 0.64, t, panes=(2, 2), surround=False, hood=False,
               fm=fm @ Matrix.Translation((0, 0.24, 0)))
        sill = Body("%s Fensterbank" % name, M["trim"], C["walls"], seed=66 + k, bevel=0.008)
        sill.box((0, 0.2, 0.05), (0.7, 0.04, 0.14), step=0.3, dent=0.002, matrix=fm)
        sill.build()
        # Satteldach der Gaube (Terrakotta) mit cremefarbenen Ortgangbrettern
        r = Body("%s Dach" % name, M["terra"], C["roof"], seed=62 + k, vary=0.08, bevel=0.01)
        ridge = fm @ Vector((0, 1.48, 0.12))
        for side in (-1, 1):
            eave = fm @ Vector((side * 0.64, 0.96, 0.12))
            mid = (eave + ridge) / 2
            d = ridge - eave
            ang = math.atan2(d.z, abs(d.x)) * side
            m = Matrix.Translation(mid + Vector((0, depth / 2 - 0.12, 0.03))) @ Matrix.Rotation(ang, 4, "Y")
            r.box((0, 0, 0), (d.length + 0.04, depth + 0.1, 0.07), step=0.25, dent=0.004, matrix=m)
        r.build()
        tr = Body("%s Ortgang" % name, M["trim"], C["roof"], seed=64 + k, vary=0.03, bevel=0.008)
        for side in (-1, 1):
            tr.span(fm @ Vector((side * 0.66, 0.9, 0.16)), fm @ Vector((0, 1.45, 0.16)), 0.05, 0.13, step=0.3)
        tr.blob(fm @ Vector((0, 1.56, 0.16)), 0.04, subdiv=1, lump=0.1)
        tr.build()
        SC.planter_box(M, C["pots"], "Blumenkasten %s" % name, fm @ Matrix.Translation((0, 0.22, 0)), 0.64, 0.15, 0.16,
                       seed=70 + k, gap=0.0)


# --- Laden im Erdgeschoss ---

def shopfront(M, C):
    t_sign = RND.uniform(-0.5, 0.5)
    b = Body("Ladenfront Pfeiler", M["blue"], C["shop"], seed=80, vary=0.04, bevel=0.012)
    for side in (-1, 1):
        x0, x1 = sorted((side * HW, side * (HW - 0.36)))
        cx = (x0 + x1) / 2
        b.box((cx, -0.09, 1.45), (0.36, 0.2, 2.9), step=0.25, dent=0.004)
        b.box((cx, -0.11, 0.17), (0.42, 0.24, 0.34), step=0.3, dent=0.004)
        # aufgesetzte Füllung
        for (px0, px1, pz0, pz1) in ((x0 + 0.06, x0 + 0.09, 0.55, 2.35), (x1 - 0.09, x1 - 0.06, 0.55, 2.35),
                                     (x0 + 0.06, x1 - 0.06, 0.52, 0.55), (x0 + 0.06, x1 - 0.06, 2.35, 2.38)):
            b.box(((px0 + px1) / 2, -0.2, (pz0 + pz1) / 2), (px1 - px0, 0.025, pz1 - pz0), step=0.3, dent=0.002)
        # Kapitell (Konsole) über dem Pfeiler
        b.box((cx, -0.14, 2.72), (0.42, 0.3, 0.18), step=0.3, dent=0.004)
        b.box((cx, -0.17, 3.15), (0.46, 0.36, 0.6), step=0.3, dent=0.004)
    # Gesims über dem Schild
    b.box((0, -0.15, 3.48), (W + 0.06, 0.32, 0.1), step=0.3, dent=0.004)
    b.box((0, -0.19, 3.58), (W + 0.1, 0.4, 0.09), step=0.3, dent=0.004)
    b.build()
    g = Body("Ladenfront Goldrollen", M["gold"], C["shop"], seed=81, vary=0.04)
    for side in (-1, 1):
        cx = side * (HW - 0.18)
        g.tube([(cx - 0.17, -0.36, 2.95), (cx + 0.17, -0.36, 2.95)], 0.055, segs=10)
    g.build()
    # Ladenschild: Bild der Entwicklerin (assets/textures/signs/fashion_shop_fascia.png) auf
    # einer Schild-Platte, Seitenverhältnis wie das Bild
    sm = front_matrix(0, 3.13, -0.24, t_sign)
    s = Body("Ladenschild", SC.sign_material("fashion_shop", "fascia"), C["shop"], seed=82, vary=0.0)
    s.panel(sm @ Matrix.Translation((0, 0, -0.2)), W - 0.74, (W - 0.74) * 219 / 2048, 0.2)
    s.build()
    # Schaufenster: Brüstung, Bank, Pfosten, Kämpfer, Glas
    f = Body("Schaufenster Rahmen", M["blue"], C["shop"], seed=84, vary=0.03, bevel=0.008)
    gl = Body("Schaufenster Glas", M["glass"], C["shop"], seed=85)
    for side in (-1, 1):
        x0, x1 = sorted((side * (HW - 0.36), side * 0.74))
        cx, ww = (x0 + x1) / 2, x1 - x0
        t = RND.uniform(-0.4, 0.4)
        fm = front_matrix(cx, 0, 0.0, t)
        def fb(c, sz, step=0.3):
            f.box(c, sz, step=step, dent=0.003, matrix=fm)
        fb((0, 0.28, 0.1), (ww, 0.56, 0.14))
        fb((-ww / 2 + 0.16, 0.28, 0.18), (0.03, 0.34, 0.02))
        fb((ww / 2 - 0.16, 0.28, 0.18), (0.03, 0.34, 0.02))
        fb((0, 0.12, 0.18), (ww - 0.3, 0.03, 0.02))
        fb((0, 0.44, 0.18), (ww - 0.3, 0.03, 0.02))
        fb((0, 0.59, 0.12), (ww + 0.04, 0.07, 0.2))
        fb((-ww / 2 + 0.04, 1.74, 0.06), (0.08, 2.3, 0.1))
        fb((ww / 2 - 0.04, 1.74, 0.06), (0.08, 2.3, 0.1))
        fb((0, 2.86, 0.06), (ww, 0.12, 0.1))
        fb((0, 2.3, 0.06), (ww - 0.08, 0.06, 0.1))
        for i in range(1, 4):
            fb((-ww / 2 + 0.08 + (ww - 0.16) * i / 4, 2.57, 0.05), (0.026, 0.5, 0.05))
        gl.box((0, 1.74, 0.03), (ww - 0.1, 2.24, 0.006), step=10, dent=0.0, matrix=fm)
        awning(M, C, side, cx, ww)
    f.build()
    gl.build()
    door(M, C)
    window_display(M, C)


def awning(M, C, side, cx, ww):
    """Markise: Stoff mit leichtem Durchhang, Volant vorn, Seitenwangen; Stange und Halter."""
    tilt = RND.uniform(-2.5, 2.5)
    droop = RND.uniform(0.0, 0.03)
    name = "Markise %s" % ("links" if side < 0 else "rechts")
    b = Body(name, M["awning"], C["shop"], seed=90 + side, vary=0.03)
    x0, x1 = cx - ww / 2 - 0.04, cx + ww / 2 + 0.04
    top = Vector((x0, -0.14, 2.95))
    reach, drop = 0.85, 0.5 + math.radians(tilt) * 0.85
    b.sheet(top, (x1 - x0, 0, 0), (0, -reach, -drop), 18, 8, 0.012,
            offset=lambda u, v: -(0.025 * math.sin(math.pi * v) + droop * math.sin(math.pi * u)) * 1.0)
    fy, fz = -0.14 - reach, 2.95 - drop
    b.sheet((x0, fy, fz), (x1 - x0, 0, 0), (0, 0, -0.2), 18, 3, 0.012,
            offset=lambda u, v: 0.006 * math.sin(u * 40))
    for xx in (x0, x1):
        b.slab([(0.14, 2.95), (0.14 + reach, fz), (0.14 + reach, fz - 0.2), (0.14 + 0.3, fz - 0.05)], 0.012,
               Matrix.Translation((xx - (0.012 if xx > cx else 0), 0, 0)) @ Matrix(((0, 0, 1, 0), (-1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1))))
    b.build()
    r = Body(name + " Stange", M["iron"], C["shop"], seed=92 + side)
    r.tube([(x0, fy + 0.02, fz + 0.01), (x1, fy + 0.02, fz + 0.01)], 0.016, segs=8)
    r.build()


def door(M, C):
    """Ladentür in einer Nische: Glas oben, Füllung unten, halbrundes Oberlicht mit Strahlen.
    Oberlicht in derselben Ebene wie das Türblatt, die Nische ist oben geschlossen (Decke)."""
    t = RND.uniform(-0.6, 0.6)
    fm = front_matrix(0, 0, 0.0, t)
    b = Body("Tür Rahmen und Nische", M["blue"], C["shop"], seed=100, vary=0.04, bevel=0.008)
    def fb(c, s, step=0.3):
        b.box(c, s, step=step, dent=0.003, matrix=fm)
    dz = -0.3
    lift = 0.025
    for side in (-1, 1):
        # Pfosten breit genug, dass sie auch schief noch den Schaufensterrahmen überlappen
        fb((side * 0.71, 1.48, 0.0), (0.18, 2.96, 0.2))
        # Nischenwand bis unter den Kopf (vorher nur bis 2,4 m: oben offen)
        fb((side * 0.6, 1.46, -0.17), (0.04, 2.92, 0.3))
    fb((0, 2.92, 0.0), (1.48, 0.1, 0.2))
    # Nischendecke von der Front bis hinter das Oberlicht
    fb((0, 2.9, -0.19), (1.24, 0.04, 0.36))
    # Oberlicht direkt auf der Türzarge: Fuß hb, halbe Breite ax, Höhe ay
    hb, ax, ay = 2.36, 0.56, 0.5
    # Zwickel neben dem Bogen
    for side in (-1, 1):
        arc = [(side * ax * math.cos(q), hb + ay * math.sin(q)) for q in [math.pi / 2 * k / 8 for k in range(9)]]
        pts = [(side * 0.6, hb)] + arc + [(side * 0.6, 2.9)]
        if side < 0:
            pts = list(reversed(pts))
        b.slab(pts, 0.04, fm @ Matrix.Translation((0, 0, dz - 0.02)), dent=0.002)
    # Türblatt (steht auf der Platte, 2,5 cm höher)
    # Türblatt überlappt die Zarge ringsum um 5 mm (keine Lücke)
    fb((-0.435, 1.155 + lift, dz), (0.1, 2.25, 0.05))
    fb((0.435, 1.155 + lift, dz), (0.1, 2.25, 0.05))
    fb((0, 0.18 + lift, dz), (0.78, 0.36, 0.05))
    fb((0, 0.95 + lift, dz), (0.78, 0.1, 0.05))
    fb((0, 2.21 + lift, dz), (0.78, 0.1, 0.05))
    fb((0, 0.62 + lift, dz - 0.005), (0.78, 0.56, 0.04))
    fb((0, 0.62 + lift, dz + 0.03), (0.52, 0.38, 0.02))
    b.build()
    # Türzarge (cremefarben) rund um das Türblatt
    z = Body("Türzarge", M["frame"], C["shop"], seed=105, vary=0.03, bevel=0.012)
    for side in (-1, 1):
        z.box((side * 0.53, 1.16 + lift, dz), (0.1, 2.32, 0.16), step=0.3, dent=0.002, matrix=fm)
    z.box((0, 2.29 + lift, dz), (1.16, 0.09, 0.16), step=0.3, dent=0.002, matrix=fm)
    z.build()
    g = Body("Tür Glas", M["glass"], C["shop"], seed=101)
    # Scheibe reicht ringsum in Rahmen und Riegel hinein (keine Spalten)
    g.box((0, 1.6 + lift, dz), (0.8, 1.22, 0.006), step=10, dent=0, matrix=fm)
    g.box((0, hb + ay / 2, dz), (2 * ax + 0.06, ay, 0.006), step=10, dent=0, matrix=fm)
    g.build()
    ar = Body("Oberlicht Sprossen", M["frame"], C["shop"], seed=102, vary=0.03)
    arc = [fm @ Vector((ax * math.cos(math.pi * k / 20), hb + ay * math.sin(math.pi * k / 20), dz)) for k in range(21)]
    ar.tube(arc, 0.022, segs=8)
    hub = fm @ Vector((0, hb + 0.01, dz))
    for k in range(1, 6):
        q = math.pi * k / 6
        ar.tube([hub, fm @ Vector(((ax - 0.02) * math.cos(q), hb + 0.01 + (ay - 0.02) * math.sin(q), dz))], 0.011, segs=6)
    ar.lathe([(0.0, 0.0), (0.08, 0.0), (0.08, 0.02), (0.0, 0.03)], fm @ Vector((0, hb + 0.01, dz + 0.012)), segs=16, turn=(90, 0))
    ar.tube([fm @ Vector((-ax - 0.02, hb, dz)), fm @ Vector((ax + 0.02, hb, dz))], 0.02, segs=8)
    ar.build()
    # "Geöffnet"-Kärtchen vor der Türscheibe an einer Schnur (Bild fashion_shop_open.png)
    card = Body("Tür Geöffnet-Schild", SC.sign_material("fashion_shop", "open"), C["shop"], seed=106, vary=0.0)
    card.panel(fm @ Matrix.Translation((0, 1.62 + lift, dz + 0.006)), 0.26, 0.26 * 152 / 360, 0.008)
    card.build()
    cord = Body("Tür Geöffnet-Schild Schnur", M["iron"], C["shop"], seed=107)
    for sx in (-0.1, 0.1):
        cord.tube([fm @ Vector((sx, 1.62 + lift + 0.05, dz + 0.01)), fm @ Vector((0.0, 1.95 + lift, dz + 0.01))], 0.0015, segs=5,
                  round_ends=True)
    cord.blob(fm @ Vector((0.0, 1.95 + lift, dz + 0.012)), 0.006, subdiv=1, lump=0.0)
    cord.build()
    k = Body("Tür Knauf und Briefschlitz", M["gold"], C["shop"], seed=103)
    k.blob(fm @ Vector((0.33, 1.02 + lift, dz + 0.06)), 0.03, subdiv=2, lump=0.05)
    k.box((0, 0.98 + lift, dz + 0.035), (0.28, 0.04, 0.02), step=1, dent=0.001, matrix=fm)
    k.build()
    # Eine flache Steinplatte vor und in der Türnische (2,5 cm hoch, keine Treppe): darüber
    # läuft man ohne Stolpern, sie braucht im Spiel keine eigene Kollision
    st = Body("Türplatte", M["stone"], C["shop"], seed=104, vary=0.06, bevel=0.012)
    st.box((0, -0.05, 0.01), (1.3, 0.66, 0.03), step=0.3, dent=0.002)
    st.build()


def window_display(M, C):
    """Laden hinter den Schaufenstern: Auslage, vier Schneiderpuppen, Raum mit Regalen und Licht."""
    r = Body("Laden Raum", M["in_wall"], C["inside"], seed=110, vary=0.03)
    r.box((0, 5.6, 1.6), (W - 0.6, 0.12, 3.2), step=0.6, dent=0.004)
    for side in (-1, 1):
        r.box((side * (HW - 0.36), 2.9, 1.6), (0.1, 5.4, 3.2), step=0.6, dent=0.004)
    r.build()
    c = Body("Laden Decke", M["in_paper"], C["inside"], seed=111, vary=0.03)
    c.box((0, 2.9, 3.05), (W - 0.6, 5.4, 0.1), step=0.6, dent=0.003)
    c.build()
    fl = Body("Laden Dielen", M["wood_in"], C["inside"], seed=112, vary=0.1)
    x = -HW + 0.36
    while x < HW - 0.36:
        bw = RND.uniform(0.14, 0.2)
        fl.box((x + bw / 2, 2.9, 0.04), (bw - 0.006, 5.4, 0.08), step=0.8, dent=0.002)
        x += bw
    fl.build()
    disp = Body("Auslage Podest", M["wood_in"], C["inside"], seed=113, vary=0.05, bevel=0.01)
    for side in (-1, 1):
        cx = side * (HW / 2 + 0.2)
        disp.box((cx, 0.55, 0.3), (1.6, 0.8, 0.6), step=0.4, dent=0.004)
    disp.build()
    # Regal an der Rückwand mit gefalteten Stoffen
    sh = Body("Regal", M["wood_in"], C["inside"], seed=114, vary=0.06, bevel=0.006)
    stack = {k: Body("Stoffe %s" % k, M[k], C["inside"], seed=115 + i, vary=0.08) for i, k in enumerate(("mustard", "sage", "rust", "blush", "linen"))}
    for z in (1.0, 1.5, 2.0, 2.5):
        sh.box((0, 5.4, z), (3.2, 0.32, 0.035), step=0.6, dent=0.002)
        xx = -1.45
        while xx < 1.4:
            key = RND.choice(list(stack))
            hgt = 0.0
            for n in range(RND.randint(2, 4)):
                th = RND.uniform(0.035, 0.06)
                stack[key].box((xx + 0.14, 5.4, z + 0.02 + hgt + th / 2), (0.26, 0.26, th), step=1, dent=0.006,
                               turn=(0, 0, RND.uniform(-4, 4)))
                hgt += th
            xx += RND.uniform(0.32, 0.4)
    for xx in (-1.62, 1.62):
        sh.box((xx, 5.4, 1.75), (0.04, 0.32, 1.6), step=0.6, dent=0.002)
    sh.build()
    for body in stack.values():
        body.build()
    # Pendelleuchten
    lamp = Body("Pendelleuchten", M["bulb"], C["inside"], seed=120)
    cord = Body("Pendelleuchten Kabel", M["iron"], C["inside"], seed=121)
    for y in (1.6, 3.6):
        cord.tube([(0, y, 3.0), (0, y, 2.55)], 0.006, segs=5)
        lamp.lathe([(0.0, 0.0), (0.14, 0.04), (0.15, 0.14), (0.06, 0.25), (0.0, 0.27)], (0, y, 2.3), segs=16)
        add_light("Pendellicht", (0, y, 2.25), 2700, 70, C["light"], radius=0.08)
    lamp.build()
    cord.build()
    add_light("Laden Grundlicht", (0, 2.6, 2.9), 3000, 260, C["light"], kind="AREA", size=2.5)
    for side in (-1, 1):
        add_light("Schaufensterlicht", (side * 1.55, 0.45, 2.75), 2700, 45, C["light"], radius=0.1)
    # Schneiderpuppen mit Kleidern
    for (x, y, key, kind, yaw) in ((-1.95, 0.5, "mustard", "dress", 15), (-1.2, 0.62, "sage", "coat", -10),
                                   (1.2, 0.62, "rust", "coat", 8), (1.95, 0.5, "blush", "dress", -18)):
        mannequin(M, C, x, y, 0.6, M[key], kind, yaw)


def mannequin(M, C, x, y, z, cloth, kind, yaw):
    n = "Schneiderpuppe %s" % cloth.name.split()[-1]
    st = Body(n + " Ständer", M["wood_in"], C["inside"], seed=int(abs(x) * 100))
    st.tube([(x, y, z + 0.02), (x, y, z + 0.82)], 0.016, segs=8)
    for k in range(3):
        a = 2 * math.pi * k / 3 + math.radians(yaw)
        st.tube([(x, y, z + 0.2), (x + 0.24 * math.cos(a), y + 0.24 * math.sin(a), z + 0.01)], 0.012, segs=6)
    st.lathe([(0.0, 0.0), (0.02, 0.0), (0.025, 0.03), (0.0, 0.05)], (x, y, z + 1.62), segs=10)
    st.build()
    body = Body(n + " Körper", M["linen"], C["inside"], seed=int(abs(x) * 101))
    body.lathe([(0.0, 0.0), (0.15, 0.0), (0.16, 0.08), (0.12, 0.28), (0.16, 0.45), (0.15, 0.55), (0.06, 0.6), (0.045, 0.66), (0.0, 0.68)],
               (x, y, z + 0.92), segs=18, dent=0.004)
    body.build()
    c = Body(n + " Kleid", cloth, C["inside"], seed=int(abs(x) * 103), vary=0.04)
    if kind == "dress":
        c.lathe([(0.0, 0.0), (0.33, 0.0), (0.3, 0.12), (0.2, 0.42), (0.135, 0.6), (0.0, 0.61)], (x, y, z + 0.38), segs=24, wave=0.07, waves=9,
                dent=0.005)
        c.lathe([(0.0, 0.0), (0.135, 0.0), (0.168, 0.2), (0.16, 0.32), (0.07, 0.36), (0.0, 0.37)], (x, y, z + 1.0), segs=18, dent=0.003)
        belt = Body(n + " Gürtel", M["sign"], C["inside"], seed=3)
        belt.lathe([(0.0, 0.0), (0.137, 0.0), (0.137, 0.03), (0.0, 0.031)], (x, y, z + 0.98), segs=18)
        belt.build()
    else:
        c.lathe([(0.0, 0.0), (0.25, 0.0), (0.2, 0.3), (0.165, 0.62), (0.175, 0.86), (0.165, 0.98), (0.07, 1.02), (0.0, 1.03)],
                (x, y, z + 0.35), segs=22, wave=0.04, waves=7, dent=0.004)
        bt = Body(n + " Knöpfe", M["gold"], C["inside"], seed=4)
        a = math.radians(yaw) - math.pi / 2
        for k in range(4):
            hz = z + 0.8 + k * 0.13
            rr = 0.175
            bt.blob((x + rr * math.cos(a), y + rr * math.sin(a), hz), 0.012, subdiv=1, lump=0.05)
        bt.build()
    c.build()


# --- Laternen und Licht ---

def lanterns(M, C):
    """Wandlaternen links und rechts: Wandplatte, geschwungener Arm mit Schnecke, daran hängt
    der gemeinsame Laternenkopf (storybook_parts.lantern_head, wie an der Straße)."""
    for side in (-1, 1):
        x = side * (HW - 0.2)
        name = "Wandlaterne %s" % ("links" if side < 0 else "rechts")
        ir = Body(name + " Arm", M["lamp_iron"], C["deco"], seed=130 + side, vary=0.03, bevel=0.005)
        ir.box((x, -0.02, 4.36), (0.12, 0.04, 0.26), step=1, dent=0.001)
        arm = [(x, -0.04, 4.4), (x, -0.16, 4.44), (x, -0.3, 4.43), (x, -0.38, 4.4)]
        ir.tube(arm, 0.014, segs=8, smooth=2, round_ends=True)
        SP.scroll(ir, (x, -0.13, 4.33), 0.07, x, turns=1.3, thick=0.008, start=1.2)
        ir.tube([(x, -0.38, 4.4), (x, -0.38, 4.33)], 0.008, segs=8, round_ends=True)
        ir.build()
        SP.lantern_head(M, C["deco"], name, (x, -0.38, 3.91), scale=0.58, hanging=True, seed=132 + side)
        add_light(name + " Licht", (x, -0.38, 4.06), 2700, 22, C["light"], radius=0.04)
    # Ausleger-Schild (Bild fashion_shop_hanging.png) rechts über der Laterne
    SC.projecting_sign(M, C["deco"], "Ausleger-Schild", (HW - 0.16, 0.0, 5.42), SC.sign_material("fashion_shop", "hanging"), 0.6,
                       0.6 * 478 / 512, outline=SB.round_outline(arch=0.12))


# --- Fürs Spiel: Kollision, Godot-Materialien, zusammengefasste .glb ---

GAME_GLB = os.path.join(ROOT, "assets", "models", "houses", "fashion_shop.glb")
# Feste Teile vor dem Haus (Mitte x, y, Größe x, y, Höhe): werden im Spiel zu Kollision und zu
# Hindernissen für Passanten (HouseFacade, Knoten "...-colonly")
OBSTACLES = {
    "Topf links": ((-HW + 0.38, -0.5), (0.5, 0.5), 0.5),
    "Topf rechts": ((HW - 0.38, -0.5), (0.5, 0.5), 0.5),
    "Zinkwanne": ((-1.15, -0.48), (0.5, 0.5), 0.35),
    "Topf Olive": ((1.12, -0.45), (0.42, 0.42), 0.45),
    "Kreidetafel": ((1.78, -0.6), (0.56, 0.42), 0.8),
}


def export_game(C, cols, path=GAME_GLB):
    """Kopie fürs Spiel aus dem gerade gebauten Haus (ohne Umgebung und Lichter)."""
    objs = [o for key, coll in C.items() if key not in ("env", "collision", "light") for o in coll.objects]
    return SC.export_objects(objs, cols, path)


# --- Schutz für selbst bearbeitete .blend ---

STAMP = os.path.join(os.path.dirname(BLEND), "fashion_shop_storybook.stamp")


# --- Ablauf ---

WIN_JITTER = []


def build_scene():
    """Ganzes Haus bauen (immer gleich: feste Zufallszahlen)."""
    RND.seed(1907)
    WIN_JITTER.clear()
    SC.GAME_MATERIALS.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    for x in WIN_X:
        WIN_JITTER.append((x, RND.uniform(-0.015, 0.015), RND.uniform(-1.4, 1.4)))
    M = SC.materials()
    root = SB.collection("Modegeschäft (Bilderbuch)")
    C = {k: SB.collection(v, root) for k, v in (("walls", "Mauern"), ("roof", "Dach"), ("windows", "Fenster"), ("shop", "Laden"),
                                                ("inside", "Innen"), ("pots", "Töpfe und Kübel"), ("deco", "Deko"), ("light", "Licht"))}
    C["env"] = SB.collection("Umgebung (nur Vorschau)")
    C["collision"] = SB.collection("Kollision (Spiel)", root)
    walls(M, C)
    eaves_cornice(M, C)
    roof(M, C)
    pediment(M, C)
    chimneys(M, C)
    upper_windows(M, C)
    dormers(M, C)
    shopfront(M, C)
    lanterns(M, C)
    # Warmes Zimmer hinter den oberen Fenstern (Fensterlicht als Blickfang)
    up = Body("Zimmer oben", M["in_dark"], C["inside"], seed=150, vary=0.04)
    up.box((0, 3.0, SHOP_TOP + 0.05), (W - 0.6, 5.4, 0.1), step=0.8, dent=0.003)
    up.box((0, 3.0, E - 0.4), (W - 0.6, 5.4, 0.1), step=0.8, dent=0.003)
    up.box((0, 2.4, (SHOP_TOP + E) / 2), (W - 0.6, 0.1, E - SHOP_TOP), step=0.8, dent=0.003)
    up.build()
    for x in WIN_X:
        add_light("Zimmerlicht", (x, 1.0, 5.2), 2700, 28, C["light"], radius=0.15)
    # Töpfe und Kübel vor dem Laden (Pflanzen kommen später), Kreidetafel mit Bild
    SC.pot(M, C["pots"], "Topf links", (-HW + 0.38, -0.5, 0.0), 0.24, 0.48, 521, style="classic")
    SC.pot(M, C["pots"], "Topf rechts", (HW - 0.38, -0.5, 0.0), 0.24, 0.48, 522, style="classic")
    SC.zinc_tub(M, C["pots"], "Zinkwanne", (-1.15, -0.48, 0.0), 531)
    SC.pot(M, C["pots"], "Topf Olive", (1.12, -0.45, 0.0), 0.2, 0.44, 532, style="tall", mat="pot_light")
    SC.chalkboard(M, C["deco"], (1.78, -0.6), -14, SC.sign_material("fashion_shop", "chalkboard"))
    house = [o for k, c in C.items() if k != "env" for o in c.objects]
    SC.settle(house, SETTLE, HW, E, RIDGE)
    cols = SC.colliders(C, OBSTACLES)
    SC.pavement(M, C)
    return M, C, cols


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if SC.edited_by_hand(BLEND, STAMP) and "--force" not in argv:
        print("Die .blend wurde in Blender bearbeitet – nichts überschrieben. Ins Spiel bringen mit\n"
              "  blender -b %s --python tools/blender/export_storybook.py\n"
              "Neu bauen (eigene Änderungen gehen verloren): ... build_storybook_shop.py -- --force" % os.path.relpath(BLEND, ROOT))
        return
    M, C, cols = build_scene()
    # Prüfung: jedes Teil ein geschlossener Körper (auch die Spiel-Datei besteht aus diesen Teilen)?
    open_parts = [(o.name, SB.non_manifold(o)) for c in C.values() for o in c.objects if o.type == "MESH"]
    bad = [(n, k) for n, k in open_parts if k]
    faces = sum(len(o.data.polygons) for c in C.values() for o in c.objects if o.type == "MESH")
    print("Teile: %d, Flächen: %d" % (len(open_parts), faces))
    print("Offene Kanten: %s" % (bad if bad else "keine – alles geschlossene Körper"))
    if "--no-game" not in argv:
        mapping = SC.write_game_materials()
        tris, parts = export_game(C, cols)
        SC.write_import_settings(mapping, GAME_GLB)
        print("Spiel: %s (%d Dreiecke, %d Netze)" % (GAME_GLB, tris, parts))
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    if "--render" in argv:
        quick = "--quick" in argv
        SC.setup_render(quick)
        s = 0.5 if quick else 1.0
        only = [a.split("=", 1)[1].split(",") for a in argv if a.startswith("--only=")]
        views = {
            "vorn": ((0.0, -13.5, 1.75), (0.0, 0.0, 5.3), 44, (1024, 1536)),
            "schraeg_links": ((-7.0, -9.5, 2.0), (0.2, 0.0, 4.6), 30, (1600, 1100)),
            "schraeg_rechts": ((7.0, -9.5, 2.0), (-0.2, 0.0, 4.6), 30, (1600, 1100)),
            "laden": ((1.4, -4.4, 1.6), (-0.1, 0.0, 1.9), 26, (1600, 1100)),
            "tuer": ((0.2, -2.6, 1.4), (0.0, 0.1, 1.3), 30, (1000, 1200)),
            "dach": ((3.2, -5.6, 8.9), (0.0, 1.6, 8.0), 32, (1600, 1100)),
            "gaube": ((1.0, -2.2, 8.4), (1.85, 0.7, 8.2), 35, (1200, 1000)),
            "ecke": ((3.7, -2.6, 2.6), (2.45, 0.0, 3.2), 32, (1100, 1400)),
            "schild": ((4.0, -1.2, 5.2), (2.55, -0.45, 5.0), 32, (1100, 1000)),
            "laterne": ((3.3, -1.6, 4.0), (2.5, -0.38, 4.1), 35, (1000, 1200)),
            "tafel": ((2.6, -2.0, 0.9), (1.78, -0.6, 0.45), 32, (1200, 1000)),
            "fenster": ((0.6, -2.4, 4.9), (0.0, 0.0, 4.75), 30, (1400, 1000)),
            "karte": ((0.1, -1.0, 1.7), (0.0, 0.3, 1.62), 40, (900, 700)),
            "toepfe": ((-0.4, -3.2, 1.2), (-0.6, -0.5, 0.3), 30, (1400, 1000)),
        }
        for name, (cam, target, lens, res) in views.items():
            if only and name not in only[0]:
                continue
            SC.render(name, cam, target, lens, (int(res[0] * s), int(res[1] * s)))
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
    with open(STAMP, "w") as f:
        f.write(SC.blend_fingerprint(BLEND) + "\n")
    print("Gespeichert:", BLEND)


if __name__ == "__main__":
    main()
