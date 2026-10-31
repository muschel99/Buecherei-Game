"""Pub "The Ink & Ivy" im Bilderbuch-Stil – eigenes Modell nach dem Vorlagebild der Entwicklerin:
ziegelroter Backstein mit hellen Bögen über den Fenstern, flaschengrüne Ladenfront mit großen
Sprossenfenstern und verglaster Tür, Schild und rundes Hängeschild (Bilder der Entwicklerin),
Zahnschnitt-Gesims, Blumenkästen (noch ohne Pflanzen), Bistrotische mit Stühlen, Kreidetafel,
Terrakotta-Töpfe; dahinter eine warme Gaststube (rote Wände, Tresen, Flaschenregal, Sitznischen).

Unabhängig von den bisherigen Modellen (der alte Pub aus build_street.py ist ersetzt).

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_storybook_pub.py
    blender -b --factory-startup --python tools/blender/build_storybook_pub.py -- --render [--quick] [--only=vorn,…]

Ergebnis:
    assets/models/source/houses/pub_storybook.blend   zum Anschauen und Weiterbauen (Einzelteile)
    assets/models/houses/pub.glb (+ .import)         fürs Spiel (Knoten "Model" in scenes/world/houses/pub.tscn)
    assets/materials/storybook/*.tres                Godot-Materialien (gemeinsam mit dem Modegeschäft)
    screenshots/blender/storybook/pub_*.png          Bilder (mit --render)
Schilder = Bilder der Entwicklerin: assets/textures/signs/pub_fascia.png, pub_hanging.png,
pub_chalkboard.png (werden nie verändert – Bild austauschen genügt).

Jedes Teil ist ein geschlossener Körper mit weichen Kanten (am Ende steht die Zahl offener Kanten).
Maße wie der Pub im Spiel: 5,6 m breit, 8 m tief; Lage und Kollision bleiben (HouseFacade).
"""

import bpy
import math
import os
import random
import sys
import zlib

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
import build_storybook_shop as FS  # noqa: E402
import storybook_common as SC  # noqa: E402
import storybook_greenery as GR  # noqa: E402
import storybook_lib as SB  # noqa: E402
from storybook_common import add_bevel, add_light, front_matrix  # noqa: E402
from storybook_lib import Body  # noqa: E402

ROOT = SC.ROOT
BLEND = os.path.join(ROOT, "assets", "models", "source", "houses", "pub_storybook.blend")
STAMP = os.path.join(os.path.dirname(BLEND), "pub_storybook.stamp")
GAME_GLB = os.path.join(ROOT, "assets", "models", "houses", "pub.glb")

W, D = 5.6, 8.0
HW = W / 2
E = 6.55                          # Oberkante Gesims (Traufe); höher als der Haustyp (6,25), damit
                                  # die Fensterbögen frei unter dem Zahnschnitt sitzen
PITCH = 37.0
EAVES_Y = -0.18
RIDGE_Y = D / 2
RIDGE = E + (RIDGE_Y - EAVES_Y) * math.tan(math.radians(PITCH))
SLOPE = (RIDGE_Y - EAVES_Y) / math.cos(math.radians(PITCH))
SHOP_TOP = 3.62                   # Oberkante Ladengesims
PIL = 0.34                        # Breite der Pilaster
FASCIA_W = W - 2 * PIL
FASCIA_H = FASCIA_W * 239 / 2048  # Seitenverhältnis wie das Bild pub_fascia.png
FASCIA_Z = 3.12
HEAD = 2.78                       # Oberkante der Schaufenster
SILL = 0.62
TRANSOM = 2.22
DOOR_HALF = 0.52
WIN_X = (-1.75, 0.0, 1.75)        # Fenster im Obergeschoss
WIN_W, WIN_Z0, WIN_H = 0.98, 4.12, 1.48
WIN_RISE = 0.08                   # flacher Bogen oben am Fenster (Scheitel WIN_H + WIN_RISE)

# Wölbung dieses Hauses (anders als beim Modegeschäft)
SETTLE = {"wave": 0.02, "wavelength": 3.0, "lean": -0.003, "roof_sag": 0.06, "ridge_tilt": -0.04, "eaves_sag": 0.03}

RND = random.Random(1888)
WIN_JITTER = []


def side_matrix(y, z, turn=0.0):
    """Ebene der freien Seitenwand (x = -HW, zur Gasse): lokal x = nach vorn (-y), y = oben,
    z = nach außen (-x)."""
    m = Matrix(((0, 0, -1, 0), (-1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    return Matrix.Translation((-HW, y, z)) @ m @ Matrix.Rotation(math.radians(turn), 4, "Z")


# --- Mauern, Gesims, Dach ---

SIDE_WINDOWS = [("Seitenfenster Gaststube", 2.2, 0.8, 1.1, 1.6), ("Seitenfenster oben 1", 1.6, WIN_Z0, 0.9, 1.4),
                ("Seitenfenster oben 2", 4.6, WIN_Z0, 0.9, 1.4)]


def walls(M, C):
    # Front oben: Backstein, Fensteröffnungen genau in der Ebene der leicht schiefen Fenster
    b = Body("Fassade oben (Backstein)", M["pub_brick"], C["walls"], seed=1, vary=0.03)
    b.box((0, 0.15, (SHOP_TOP - 0.15 + E) / 2), (W, 0.3, E - SHOP_TOP + 0.15), step=0.22, dent=0.007, dent_scale=1.5)
    wall = b.build()
    outline = [(-WIN_W / 2, 0.0), (WIN_W / 2, 0.0)] + SB.arc_points(WIN_W / 2, WIN_H, WIN_RISE)
    cuts = [SB.slab_cutter(outline, front_matrix(x + dx, WIN_Z0, 0.0, t)) for x, dx, t in WIN_JITTER]
    SB.boolean_cut(wall, cuts)
    add_bevel(wall, 0.012)
    # Freie Seitenwand (zur Gasse) mit Fenstern, Brandwand rechts, Rückwand, Giebel
    b = Body("Seitenwand Gasse", M["pub_side"], C["walls"], seed=2, vary=0.04)
    b.box((-HW + 0.15, D / 2, E / 2), (0.3, D, E), step=0.4, dent=0.006)
    side = b.build()
    cuts = [SB.cutter((0, h / 2, 0), (w, h, 1.0), matrix=side_matrix(y, z)) for _, y, z, w, h in SIDE_WINDOWS]
    SB.boolean_cut(side, cuts)
    add_bevel(side, 0.01)
    b = Body("Brandwand, Rückwand und Giebel", M["pub_side"], C["walls"], seed=3, vary=0.04, bevel=0.01)
    b.box((HW - 0.15, D / 2, E / 2), (0.3, D, E), step=0.4, dent=0.006)
    b.box((0, D - 0.15, E / 2), (W - 0.6, 0.3, E), step=0.5, dent=0.006)
    for sx in (-1, 1):
        # Giebel 12 mm hinter der Außenfläche der Wand (kein Flimmern im Überlappungsstreifen)
        m = Matrix.Translation((sx * HW - (0.3 if sx > 0 else -0.012), 0, 0)) @ Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
        b.slab([(0.0, E - 0.05), (D, E - 0.05), (RIDGE_Y, RIDGE + 0.04)], 0.288, m, dent=0.006)
    b.build()
    # Ladenwand hinter der Front (zwischen Pilastern und Gaststube): unten bis zum Gesims
    b = Body("Mauer hinter dem Laden", M["pub_side"], C["walls"], seed=4, vary=0.03, bevel=0.008)
    b.box((0, 0.2, SHOP_TOP - 0.25), (W - 0.6, 0.12, 0.5), step=0.4, dent=0.003)
    b.build()


def brick_arches(M, C):
    """Flache Bögen über den Fenstern im hellen Material des Gesimses (jeder Stein etwas anders)."""
    b = Body("Fensterbögen", M["trim"], C["walls"], seed=5, vary=0.1, bevel=0.006)
    hx = WIN_W / 2
    big_r = (hx * hx + WIN_RISE * WIN_RISE) / (2 * WIN_RISE)
    cy = WIN_H + WIN_RISE - big_r
    for x, dx, t in WIN_JITTER:
        fm = front_matrix(x + dx, WIN_Z0, 0.0, t)
        # Steine strahlenförmig auf einem Kreis um denselben Mittelpunkt wie der Fensterbogen:
        # die Unterkante des Bogens liegt genau auf der runden Oberkante des Fensters
        r = big_r + 0.135
        half = math.asin((hx + 0.15) / r)
        n = 11
        for k in range(n):
            a = -half + 2 * half * (k + 0.5) / n
            lx, ly = r * math.sin(a), cy + r * math.cos(a)
            m = fm @ Matrix.Translation((lx, ly, 0.035)) @ Matrix.Rotation(-a, 4, "Z")
            b.box((0, 0, 0), (2 * r * math.sin(half / n) * 0.94, 0.26 * RND.uniform(0.97, 1.03), 0.07), step=1, dent=0.003, matrix=m)
        # Fensterbank aus Stein
        sm = front_matrix(x + dx, WIN_Z0, 0.0, t)
        b2 = b
        b2.box((0, -0.04, 0.07), (WIN_W + 0.18, 0.08, 0.16), step=0.4, dent=0.003, matrix=sm)
    b.build()


def cornice(M, C):
    """Zahnschnitt-Gesims (cremefarben) unter der Traufe, Dachrinne, Fallrohr links."""
    b = Body("Traufgesims", M["trim"], C["walls"], seed=6, vary=0.04, bevel=0.01)
    b.box((0, 0.0, E - 0.42), (W + 0.04, 0.14, 0.1), step=0.3, dent=0.004)
    x = -HW + 0.08
    while x < HW - 0.07:
        b.box((x, -0.07, E - 0.3), (0.075 * RND.uniform(0.92, 1.08), 0.09, 0.12), step=1, dent=0.003, turn=(0, RND.uniform(-2, 2), 0))
        x += 0.16
    b.box((0, -0.05, E - 0.18), (W + 0.06, 0.22, 0.1), step=0.3, dent=0.004)
    b.box((0, -0.09, E - 0.07), (W + 0.1, 0.32, 0.12), step=0.3, dent=0.004)
    b.build()
    g = Body("Dachrinne und Fallrohr", M["bottle_dark"], C["roof"], seed=7, vary=0.04)
    g.tube([(-HW - 0.04, -0.27, E + 0.03), (0, -0.28, E + 0.01), (HW + 0.04, -0.27, E + 0.03)], 0.05, segs=10, round_ends=True)
    px = -HW + 0.12
    g.tube([(px, -0.27, E), (px, -0.12, E - 0.25), (px, -0.09, E - 0.6), (px, -0.09, 0.15),
            (px, -0.18, 0.03)], 0.036, segs=10, smooth=2, round_ends=True)
    for z in (1.2, 2.6, 4.2, 5.4):
        g.lathe([(0.0, 0.0), (0.05, 0.0), (0.052, 0.02), (0.05, 0.04), (0.0, 0.04)], (px, -0.09, z), segs=12)
    g.build()


def roof(M, C):
    a = math.radians(PITCH)

    def roof_point(x, s, h=0.0):
        return Vector((x, EAVES_Y + s * math.cos(a) - h * math.sin(a), E + s * math.sin(a) + h * math.cos(a)))
    b = Body("Dachflächen", M["slate"], C["roof"], seed=8, vary=0.04, bevel=0.01)
    front = Matrix.Translation(roof_point(0, SLOPE / 2, -0.09)) @ Matrix.Rotation(a, 4, "X")
    b.box((0, 0, 0), (W + 0.24, SLOPE, 0.16), step=0.3, dent=0.006, matrix=front)
    c = roof_point(0, SLOPE / 2, -0.09)
    back = Matrix.Translation((0, 2 * RIDGE_Y - c.y, c.z)) @ Matrix.Rotation(-a, 4, "X")
    b.box((0, 0, 0), (W + 0.24, SLOPE, 0.16), step=0.4, dent=0.006, matrix=back)
    b.build()
    # Schieferplatten in Reihen: versetzt, jede etwas anders breit und schief
    t = Body("Schieferplatten", M["slate"], C["roof"], seed=9, vary=0.12, bevel=0.005)
    cx_ch = HW - 0.75
    row, s = 0, 0.03
    while s < SLOPE - 0.12:
        x = -HW - 0.1 + (0.14 if row % 2 else 0.0)
        while x < HW + 0.1:
            tw = 0.28 * RND.uniform(0.85, 1.12)
            cx = x + tw / 2
            sy = EAVES_Y + (s + 0.15) * math.cos(a)
            if not (abs(cx - cx_ch) < 0.42 and 2.15 < sy < 3.2) and abs(cx) < HW + 0.1:
                m = Matrix.Translation(roof_point(cx, s + 0.15, 0.012)) @ Matrix.Rotation(a - math.radians(RND.uniform(2.5, 5.0)), 4, "X") @ \
                    Matrix.Rotation(math.radians(RND.uniform(-2.0, 2.0)), 4, "Z")
                t.box((0, 0, 0), (tw - 0.012, 0.32, 0.02), step=1, dent=0.003, matrix=m)
            x += tw
        s += 0.21
        row += 1
    t.build()
    r = Body("First", M["slate"], C["roof"], seed=10, vary=0.06)
    r.tube([(-HW - 0.1, RIDGE_Y, RIDGE + 0.04), (0, RIDGE_Y, RIDGE + 0.06), (HW + 0.1, RIDGE_Y, RIDGE + 0.04)], 0.08, segs=12,
           wobble=0.03, round_ends=True)
    r.build()
    # Schornstein (Backstein) mit Abdeckung und zwei Töpfen
    y = 2.7
    base = E + (y - EAVES_Y) * math.tan(a) - 0.4
    top = base + 1.9
    tt = RND.uniform(-1.2, 1.2)
    ch = Body("Schornstein", M["pub_brick"], C["roof"], seed=11, vary=0.04, bevel=0.012)
    ch.box((cx_ch, y, (base + top) / 2), (0.7, 0.9, top - base), step=0.25, dent=0.006, turn=(tt, RND.uniform(-1, 1), 0))
    ch.build()
    cp = Body("Schornstein Abdeckung", M["trim"], C["roof"], seed=12, bevel=0.012)
    cp.box((cx_ch + tt * 0.01, y, top + 0.04), (0.82, 1.02, 0.09), step=0.3, dent=0.004, turn=(tt, 0, 0))
    cp.build()
    pots = Body("Schornstein Töpfe", M["terra"], C["roof"], seed=13, vary=0.1, bevel=0.004)
    for k, dy in enumerate((-0.2, 0.2)):
        h = 0.36 + 0.07 * k
        pots.lathe([(0.0, 0.0), (0.11, 0.0), (0.095, h * 0.7), (0.112, h * 0.8), (0.11, h), (0.075, h), (0.0, h - 0.02)],
                   (cx_ch + tt * 0.012, y + dy, top + 0.08), segs=16, dent=0.003, turn=(RND.uniform(-3, 3), RND.uniform(-3, 3)))
    pots.build()


# --- Fenster oben, Blumenkästen ---

def upper_windows(M, C):
    for k, (x, dx, t) in enumerate(WIN_JITTER):
        fm = arched_window(M, C, "Fenster %d" % (k + 1), front_matrix(x + dx, WIN_Z0, 0.0, t), WIN_W, WIN_H, WIN_RISE)
        box(M, C, "Blumenkasten Fenster %d" % (k + 1), fm, WIN_W + 0.08, 41 + k)
    for name, y, z, w, h in SIDE_WINDOWS:
        fm = FS.window(M, C, name, 0, 0, w, h, 0, panes=(2, 2) if z > 1 else (3, 2), surround=False, hood=False,
                       frame="bottle", fm=side_matrix(y, z), curtains=z > 1)
        sill = Body(name + " Bank", M["trim"], C["walls"], seed=int(y * 10), vary=0.04, bevel=0.008)
        sill.box((0, -0.04, 0.07), (w + 0.16, 0.08, 0.15), step=0.4, dent=0.003, matrix=fm)
        sill.build()


def arched_window(M, C, name, fm, w, hs, rise):
    """Schiebefenster mit flachem Bogen oben (passend zum Steinbogen): Rahmen, Bogen-Kopfstück,
    Mittelsprosse, Glas und Vorhänge – alles geschlossene Körper in der Ebene fm."""
    hx, back, f = w / 2, -0.12, 0.065
    seed = zlib.crc32(name.encode()) % 1000
    b = Body(name + " Rahmen", M["bottle"], C["windows"], seed=seed, vary=0.03, bevel=0.006)

    def lbox(c, sz):
        b.box(c, sz, step=0.3, dent=0.002, matrix=fm)
    lbox((-hx + f / 2, (hs - 0.04) / 2, back), (f, hs - 0.04, 0.07))
    lbox((hx - f / 2, (hs - 0.04) / 2, back), (f, hs - 0.04, 0.07))
    lbox((0, f / 2, back), (w - 2 * f, f, 0.07))
    # Bogen-Kopfstück: Band zwischen äußerem und innerem Bogen (2 mm dicker als die Pfosten)
    low = hs - 0.06
    head = (SB.arc_points(hx, hs, rise) + [(-hx, low), (-hx + f, low)]
            + list(reversed(SB.arc_points(hx, hs, rise, f))) + [(hx - f, low), (hx, low)])
    b.slab(head, 0.074, fm @ Matrix.Translation((0, 0, back - 0.037)), dent=0.002)
    # Kämpfer zwischen unterem und oberem Flügel, Mittelsprossen
    lbox((0, hs / 2, back + 0.012), (w - 2 * f, 0.055, 0.075))
    lbox((0, (f + hs / 2) / 2, back - 0.005), (0.026, hs / 2 - f, 0.045))
    top = hs + rise - f + 0.01
    lbox((0, (hs / 2 + top) / 2, back + 0.009), (0.026, top - hs / 2, 0.045))
    b.build()
    g = Body(name + " Glas", M["glass"], C["windows"], seed=1)
    g.slab([(-hx + 0.01, 0.01), (hx - 0.01, 0.01)] + SB.arc_points(hx, hs, rise, 0.01), 0.006,
           fm @ Matrix.Translation((0, 0, back - 0.033)), dent=0.0)
    g.build()
    c = Body(name + " Vorhänge", M["curtain"], C["windows"], seed=seed + 7, vary=0.05)
    for side in (-1, 1):
        cw = w * RND.uniform(0.26, 0.34)
        x0 = side * hx - (cw if side > 0 else 0) + side * 0.02
        folds = RND.randint(4, 6)
        origin = fm @ Vector((x0, 0.02, back - 0.12))
        u = fm.to_3x3() @ Vector((cw, 0, 0))
        v = fm.to_3x3() @ Vector((0, hs + rise - 0.06, 0))   # bis in den Bogen
        c.sheet(origin, u, v, 16, 10, 0.008,
                offset=lambda uu, vv, f_=folds: 0.025 * math.sin(uu * math.pi * f_) * (0.6 + 0.4 * vv))
    c.build()
    return fm


def box(M, C, name, fm, width, seed):
    """Blumenkasten (dunkelgrün) auf zwei Eisenkonsolen vor dem Fenster – noch ohne Pflanzen."""
    SC.planter_box(M, C["pots"], name, fm @ Matrix.Translation((0, -0.2, 0)), width, 0.2, 0.2, seed, gap=0.09, mat="bottle_dark")
    k = Body(name + " Konsolen", M["lamp_iron"], C["pots"], seed=seed + 5, bevel=0.003)
    for sx in (-width / 2 + 0.14, width / 2 - 0.14):
        k.tube([fm @ Vector((sx, -0.38, 0.0)), fm @ Vector((sx, -0.2, 0.26)), fm @ Vector((sx, -0.2, 0.0))], 0.009, segs=6,
               round_ends=True)
    k.build()


# --- Ladenfront ---

def shopfront(M, C):
    f = Body("Ladenfront", M["bottle"], C["shop"], seed=20, vary=0.04, bevel=0.012)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * HW, sx * (HW - PIL)))
        cx = (x0 + x1) / 2
        f.box((cx, -0.1, HEAD / 2), (PIL, 0.2, HEAD), step=0.25, dent=0.004)                 # Pilaster
        f.box((cx, -0.12, 0.17), (PIL + 0.06, 0.24, 0.34), step=0.3, dent=0.004)           # Sockel
        for (px0, px1, pz0, pz1) in ((x0 + 0.06, x0 + 0.09, 0.5, 2.4), (x1 - 0.09, x1 - 0.06, 0.5, 2.4),
                                     (x0 + 0.06, x1 - 0.06, 0.47, 0.5), (x0 + 0.06, x1 - 0.06, 2.4, 2.43)):
            f.box(((px0 + px1) / 2, -0.21, (pz0 + pz1) / 2), (px1 - px0, 0.025, pz1 - pz0), step=0.3, dent=0.002)
        f.box((cx, -0.16, HEAD + 0.08), (PIL + 0.08, 0.32, 0.16), step=0.3, dent=0.004)      # Kapitell
        f.box((cx, -0.18, FASCIA_Z), (PIL + 0.1, 0.36, FASCIA_H + 0.08), step=0.3, dent=0.004)
    # Kämpfer unter dem Schild und Gesims darüber
    f.box((0, -0.06, HEAD + 0.05), (W - 2 * PIL, 0.12, 0.1), step=0.3, dent=0.003)
    f.box((0, -0.17, SHOP_TOP - 0.12), (W + 0.06, 0.34, 0.12), step=0.3, dent=0.004)
    f.box((0, -0.21, SHOP_TOP - 0.03), (W + 0.12, 0.42, 0.08), step=0.3, dent=0.004)
    # Schildkasten: geschlossener Block von der Wand bis hinter das Schild (sonst Loch dahinter)
    f.box((0, -0.105, (HEAD + 0.02 + SHOP_TOP - 0.16) / 2), (FASCIA_W + 0.04, 0.45, SHOP_TOP - 0.16 - HEAD - 0.02),
          step=0.3, dent=0.003)
    f.build()
    # Schild: Bild der Entwicklerin (pub_fascia.png) über die ganze Breite zwischen den Pilastern
    s = Body("Ladenschild", SC.sign_material("pub", "fascia"), C["shop"], seed=21, vary=0.0)
    s.panel(front_matrix(0, FASCIA_Z - FASCIA_H / 2, -0.325, RND.uniform(-0.3, 0.3)) @ Matrix.Translation((0, FASCIA_H / 2, 0)),
            FASCIA_W - 0.02, FASCIA_H, 0.05)
    s.build()
    # Schaufenster links und rechts der Tür
    fr = Body("Schaufenster Rahmen", M["bottle"], C["shop"], seed=22, vary=0.03, bevel=0.008)
    gl = Body("Schaufenster Glas", M["glass"], C["shop"], seed=23)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * (HW - PIL), sx * (DOOR_HALF + 0.12)))
        cx, ww = (x0 + x1) / 2, x1 - x0
        fm = front_matrix(cx, 0, 0.0, RND.uniform(-0.4, 0.4))

        def fb(c, sz, step=0.3):
            fr.box(c, sz, step=step, dent=0.003, matrix=fm)
        fb((0, SILL / 2, 0.1), (ww, SILL, 0.16))                           # Brüstung
        for px in (-ww / 2 + 0.14, ww / 2 - 0.14):
            fb((px, SILL / 2, 0.19), (0.03, SILL - 0.22, 0.02))
        for pz in (0.11, SILL - 0.11):
            fb((0, pz, 0.19), (ww - 0.25, 0.03, 0.02))
        fb((0, SILL + 0.02, 0.12), (ww + 0.04, 0.07, 0.22))                 # Bank
        fb((-ww / 2 + 0.04, (SILL + HEAD) / 2, 0.06), (0.08, HEAD - SILL, 0.1))
        fb((ww / 2 - 0.04, (SILL + HEAD) / 2, 0.06), (0.08, HEAD - SILL, 0.1))
        fb((0, TRANSOM, 0.06), (ww - 0.08, 0.07, 0.1))                      # Kämpfer
        fb((0, (SILL + TRANSOM) / 2, 0.05), (0.05, TRANSOM - SILL, 0.07))   # Mittelpfosten
        n = 4
        for i in range(1, n):
            fb((-ww / 2 + 0.08 + (ww - 0.16) * i / n, (TRANSOM + HEAD) / 2, 0.05), (0.03, HEAD - TRANSOM, 0.06))
        gl.box((0, (SILL + HEAD) / 2, 0.03), (ww - 0.1, HEAD - SILL, 0.006), step=10, dent=0.0, matrix=fm)
    fr.build()
    gl.build()
    door(M, C)


def door(M, C):
    """Verglaste Tür in flacher Nische, Oberlicht mit Sprossen direkt über dem Türblatt (gleiche
    Ebene), Nische oben geschlossen, flache Steinplatte davor."""
    fm = front_matrix(0, 0, 0.0, RND.uniform(-0.5, 0.5))
    b = Body("Tür und Rahmen", M["bottle"], C["shop"], seed=30, vary=0.04, bevel=0.008)

    def fb(c, s, step=0.3):
        b.box(c, s, step=step, dent=0.003, matrix=fm)
    dz, lift = -0.28, 0.025
    top = 2.24 + lift + 0.04
    for sx in (-1, 1):
        # Pfosten breit genug, dass sie auch schief noch den Schaufensterrahmen überlappen
        fb((sx * (DOOR_HALF + 0.09), HEAD / 2, 0.0), (0.18, HEAD, 0.2))
        fb((sx * (DOOR_HALF - 0.02), HEAD / 2, -0.16), (0.04, HEAD, 0.28))
    # Nischendecke (von der Front bis hinter das Oberlicht) und Kämpfer oben am Oberlicht
    fb((0, HEAD - 0.02, -0.18), (2 * DOOR_HALF, 0.04, 0.36))
    fb((0, HEAD - 0.07, dz), (2 * DOOR_HALF - 0.02, 0.06, 0.06))
    for i in (1, 2):
        fb((-DOOR_HALF + 2 * DOOR_HALF * i / 3, (top + HEAD - 0.07) / 2, dz), (0.03, HEAD - 0.07 - top, 0.045))
    # Türblatt füllt die Zarge ganz aus (überlappt sie 5 mm), keine Lücke oben und seitlich
    for sx in (-1, 1):
        fb((sx * 0.41, 1.1 + lift, dz), (0.11, 2.2, 0.05))
    for z, h in ((0.17, 0.34), (0.98, 0.1), (2.15, 0.12)):
        fb((0, z + lift, dz), (0.72, h, 0.05))
    fb((0, 0.635 + lift, dz - 0.004), (0.72, 0.62, 0.04))
    fb((0, 0.62 + lift, dz + 0.028), (0.48, 0.38, 0.02))
    for i in (1,):
        fb((0, 1.55 + lift, dz), (0.03, 1.05, 0.045))
    fb((0, 1.55 + lift, dz), (0.7, 0.03, 0.045))
    b.build()
    z = Body("Türzarge", M["bottle_dark"], C["shop"], seed=31, vary=0.03, bevel=0.012)
    for sx in (-1, 1):
        z.box((sx * 0.5, 1.1 + lift, dz), (0.08, 2.2, 0.14), step=0.3, dent=0.002, matrix=fm)
    z.box((0, 2.24 + lift, dz), (1.08, 0.08, 0.14), step=0.3, dent=0.002, matrix=fm)
    z.build()
    g = Body("Tür Glas", M["glass"], C["shop"], seed=32)
    # Scheibe reicht ringsum in Rahmen und Riegel hinein (keine Spalten)
    g.box((0, 1.565 + lift, dz), (0.74, 1.13, 0.006), step=10, dent=0, matrix=fm)
    g.box((0, (top + HEAD - 0.07) / 2, dz), (2 * DOOR_HALF - 0.04, HEAD - 0.07 - top, 0.006), step=10, dent=0, matrix=fm)
    g.build()
    k = Body("Tür Griff und Briefschlitz", M["gold"], C["shop"], seed=33, bevel=0.003)
    k.blob(fm @ Vector((0.28, 1.02 + lift, dz + 0.06)), 0.03, subdiv=2, lump=0.05)
    k.box((0, 0.95 + lift, dz + 0.035), (0.26, 0.04, 0.02), step=1, dent=0.001, matrix=fm)
    k.build()
    st = Body("Türplatte", M["stone"], C["shop"], seed=34, vary=0.06, bevel=0.012)
    st.box((0, -0.06, 0.012), (1.2, 0.62, 0.025), step=0.3, dent=0.002)
    st.build()


# --- Gaststube ---

def taproom(M, C):
    """Warme Gaststube hinter den Fenstern: rote Wände über dunkler Holzvertäfelung, cremefarbene
    Decke, Tresen mit Messingstange, Flaschenregal an der Rückwand, Sitznischen mit grünem Leder,
    Tische mit Kerzen, Bilder, Pendelleuchten, Menütafel im Fenster."""
    xi, yb, ceil = HW - 0.3, 5.6, 3.25
    w = Body("Gaststube Wände", M["pub_wall_in"], C["inside"], seed=50, vary=0.03)
    w.box((0, yb, ceil / 2), (2 * xi, 0.1, ceil), step=0.6, dent=0.003)
    # Seitenwände bis dicht hinter die Schaufenster (sonst sieht man innen Backstein)
    y0 = 0.08
    w.box((xi - 0.05, (y0 + yb) / 2, ceil / 2), (0.1, yb - y0, ceil), step=0.6, dent=0.003)
    inner = w.build()
    cut = [SB.cutter((0, 0.8, 0), (1.1, 1.6, 1.0), matrix=side_matrix(2.2, 0.8))]
    w2 = Body("Gaststube Wand Gasse", M["pub_wall_in"], C["inside"], seed=51, vary=0.03)
    w2.box((-xi + 0.05, (y0 + yb) / 2, ceil / 2), (0.1, yb - y0, ceil), step=0.6, dent=0.003)
    side = w2.build()
    SB.boolean_cut(side, cut)
    c = Body("Gaststube Decke", M["pub_ceiling"], C["inside"], seed=52, vary=0.03)
    c.box((0, yb / 2 + 0.15, ceil + 0.05), (2 * xi, yb - 0.1, 0.1), step=0.6, dent=0.002)
    for y in (1.2, 2.6, 4.0):
        c.box((0, y, ceil - 0.06), (2 * xi, 0.14, 0.12), step=0.6, dent=0.002)
    c.build()
    mo = Body("Gaststube Deckenleiste", M["pub_wood_in"], C["inside"], seed=57, vary=0.04, bevel=0.01)
    mo.box((0, yb - 0.1, ceil - 0.08), (2 * xi, 0.12, 0.18), step=0.5, dent=0.002)
    for sx in (-1, 1):
        mo.box((sx * (xi - 0.06), yb / 2 + 0.15, ceil - 0.08), (0.12, yb - 0.1, 0.18), step=0.5, dent=0.002)
    # Sturz über den Fenstern (innen): schließt den Raum zur Front hin bis unter die Decke
    mo.box((0, 0.16, (HEAD + 0.04 + ceil + 0.1) / 2), (2 * xi + 0.1, 0.12, ceil + 0.1 - HEAD - 0.04), step=0.5, dent=0.002)
    mo.build()
    fl = Body("Gaststube Dielen", M["pub_wood_in"], C["inside"], seed=53, vary=0.1)
    x = -xi
    while x < xi - 0.01:
        bw = RND.uniform(0.15, 0.21)
        bw = min(bw, xi - x)
        fl.box((x + bw / 2, yb / 2 + 0.15, 0.04), (bw - 0.006, yb - 0.1, 0.08), step=0.8, dent=0.002)
        x += bw
    fl.build()
    # Vertäfelung unten rundherum
    v = Body("Gaststube Vertäfelung", M["pub_wood_in"], C["inside"], seed=54, vary=0.05)
    v.box((0, yb - 0.08, 0.55), (2 * xi, 0.05, 1.1), step=0.5, dent=0.002)
    for sx in (-1, 1):
        v.box((sx * (xi - 0.08), (y0 + 0.04 + yb - 0.1) / 2, 0.55), (0.05, yb - 0.14 - y0, 1.1), step=0.5, dent=0.002)
    panel = v.build()
    # Am Seitenfenster (Unterkante 0,8 m) endet die Vertäfelung; darüber ein Fensterbrett innen
    SB.boolean_cut(panel, [SB.cutter((0, 0.8, 0), (1.1, 1.6, 1.0), matrix=side_matrix(2.2, 0.8))])
    add_bevel(panel, 0.006)
    sill = Body("Gaststube Fensterbrett", M["pub_wood_in"], C["inside"], seed=58, vary=0.05, bevel=0.006)
    sill.box((-xi + 0.06, 2.2, 0.78), (0.24, 1.26, 0.04), step=0.4, dent=0.002)
    sill.build()
    # Tresen und Flaschenregal an der Rückwand
    t = Body("Tresen", M["pub_wood_in"], C["inside"], seed=55, vary=0.06, bevel=0.012)
    t.box((0.3, 4.75, 0.55), (3.4, 0.6, 1.1), step=0.4, dent=0.003)
    t.box((0.3, 4.72, 1.13), (3.55, 0.72, 0.06), step=0.4, dent=0.003)
    for k in range(5):
        t.box((-1.2 + k * 0.75, 4.43, 0.6), (0.6, 0.03, 0.7), step=1, dent=0.002)
    for z in (1.5, 1.95, 2.4):
        t.box((0.3, yb - 0.2, z), (3.6, 0.28, 0.04), step=0.6, dent=0.002)
    t.build()
    rail = Body("Tresen Messing", M["brass_in"], C["inside"], seed=56)
    rail.tube([(-1.45, 4.38, 0.18), (2.05, 4.38, 0.18)], 0.02, segs=10, round_ends=True)
    for k in range(3):
        rail.lathe([(0.0, 0.0), (0.03, 0.0), (0.02, 0.2), (0.03, 0.32), (0.0, 0.34)], (-0.4 + k * 0.4, 4.7, 1.16), segs=12)
    rail.build()
    bottles = {k: Body("Flaschen %s" % k, M["bottle_" + k], C["inside"], seed=60 + i, vary=0.12)
               for i, k in enumerate(("amber", "green", "blue", "red", "cream"))}
    for z in (1.52, 1.97, 2.42):
        x = -1.4
        while x < 1.95:
            h = RND.uniform(0.2, 0.32)
            r = RND.uniform(0.03, 0.045)
            body = bottles[RND.choice(list(bottles))]
            body.lathe([(0.0, 0.0), (r, 0.0), (r, h * 0.6), (r * 0.4, h * 0.8), (r * 0.35, h), (0.0, h)], (x, yb - 0.2, z + 0.02), segs=10)
            x += 2 * r + RND.uniform(0.02, 0.06)
    for body in bottles.values():
        body.build()
    # Sitznischen mit grünem Leder an den Seiten, Tische mit Kerzen
    lb = Body("Sitzbänke Leder", M["leather"], C["inside"], seed=70, vary=0.06, bevel=0.03)
    wood = Body("Sitzbänke und Tische Holz", M["pub_wood_in"], C["inside"], seed=71, vary=0.06, bevel=0.01)
    candles = Body("Kerzen", M["candle"], C["inside"], seed=72)
    for sx in (-1, 1):
        for y in (1.4, 3.0):
            bx = sx * (xi - 0.3)
            lb.box((bx, y, 0.45), (0.5, 1.1, 0.12), step=0.3, dent=0.006)
            lb.box((sx * (xi - 0.1), y, 0.85), (0.14, 1.1, 0.75), step=0.3, dent=0.006)
            wood.box((bx, y, 0.2), (0.48, 1.06, 0.4), step=0.4, dent=0.003)
            tx = sx * (xi - 0.95)
            wood.lathe([(0.0, 0.0), (0.22, 0.0), (0.22, 0.03), (0.04, 0.05), (0.035, 0.7), (0.3, 0.72), (0.3, 0.76), (0.0, 0.76)],
                       (tx, y, 0.08), segs=24)
            candles.lathe([(0.0, 0.0), (0.02, 0.0), (0.02, 0.09), (0.0, 0.1)], (tx, y, 0.84), segs=10)
    lb.build()
    wood.build()
    candles.build()
    # Bilder an der Wand und Pendelleuchten
    pic = Body("Bilder", M["picture"], C["inside"], seed=73, vary=0.2, bevel=0.004)
    fr = Body("Bilderrahmen", M["brass_in"], C["inside"], seed=74, bevel=0.004)
    for sx in (-1, 1):
        for y in (1.4, 3.0):
            fr.box((sx * (xi - 0.03), y, 1.75), (0.03, 0.56, 0.44), step=1, dent=0.001)
            pic.box((sx * (xi - 0.05), y, 1.75), (0.02, 0.46, 0.34), step=1, dent=0.001)
    pic.build()
    fr.build()
    lamp = Body("Pendelleuchten", M["bulb"], C["inside"], seed=75)
    cord = Body("Pendelleuchten Kabel", M["iron"], C["inside"], seed=76)
    for x, y in ((-1.3, 1.6), (1.3, 1.6), (0.3, 4.0)):
        cord.tube([(x, y, ceil), (x, y, 2.45)], 0.006, segs=6, round_ends=True)
        lamp.lathe([(0.0, 0.0), (0.13, 0.03), (0.15, 0.12), (0.06, 0.22), (0.0, 0.24)], (x, y, 2.22), segs=18)
        add_light("Gaststube Licht", (x, y, 2.15), 2700, 55, C["light"], radius=0.08)
    lamp.build()
    cord.build()
    add_light("Gaststube Grundlicht", (0, 2.6, 3.0), 2700, 220, C["light"], kind="AREA", size=2.5)
    # Menütafel im linken Fenster (wie im Vorbild), schräg angelehnt
    mb = Body("Menütafel", M["chalkboard"], C["inside"], seed=77, bevel=0.006)
    mfr = Body("Menütafel Rahmen", M["pub_wood_in"], C["inside"], seed=78, bevel=0.006)
    ch = Body("Menütafel Schrift", M["chalk"], C["inside"], seed=79)
    mm = Matrix.Translation((-1.75, 0.45, SILL + 0.02)) @ Matrix.Rotation(math.radians(-12), 4, "X")
    mfr.box((0, 0, 0.5), (0.62, 0.04, 1.0), step=0.4, dent=0.002, matrix=mm)
    mb.box((0, -0.025, 0.5), (0.52, 0.012, 0.88), step=0.4, dent=0.001, matrix=mm)
    for k in range(5):
        ch.tube([mm @ Vector((-0.18, -0.034, 0.82 - k * 0.14)), mm @ Vector((0.12 + 0.05 * (k % 2), -0.034, 0.82 - k * 0.14))], 0.006,
                segs=6, round_ends=True)
    mb.build()
    mfr.build()
    ch.build()
    # Warmes Zimmer hinter den oberen Fenstern
    up = Body("Zimmer oben", M["in_dark"], C["inside"], seed=80, vary=0.04)
    up.box((0, 3.0, SHOP_TOP + 0.05), (W - 0.6, 5.4, 0.1), step=0.8, dent=0.003)
    up.box((0, 3.0, E - 0.5), (W - 0.6, 5.4, 0.1), step=0.8, dent=0.003)
    up.box((0, 5.5, (SHOP_TOP + E) / 2), (W - 0.6, 0.1, E - SHOP_TOP), step=0.8, dent=0.003)
    up.build()
    for x in WIN_X:
        add_light("Zimmerlicht", (x, 1.0, 5.0), 2700, 26, C["light"], radius=0.15)


# --- Vor dem Pub: Tische, Stühle, Töpfe, Tafel, Hängeschild ---

# Sitzhöhe der Stühle und Höhe der Tische, passend zu den Chibi-Figuren (seit Etappe 6c)
CHAIR_SEAT = 0.25
TABLE_TOP = 0.5


def bistro_table(M, C, name, x, y, seed):
    h = TABLE_TOP
    b = Body(name, M["lamp_iron"], C["deco"], seed=seed, bevel=0.006)
    b.lathe([(0.0, 0.0), (0.22, 0.0), (0.23, 0.015), (0.18, 0.04), (0.05, 0.06), (0.03, 0.12), (0.025, h - 0.04), (0.06, h - 0.01), (0.0, h)],
            (x, y, 0.0), segs=24)
    b.build()
    t = Body(name + " Platte", M["table_top"], C["deco"], seed=seed + 1, vary=0.05, bevel=0.01)
    t.lathe([(0.0, 0.0), (0.3, 0.0), (0.31, 0.015), (0.3, 0.035), (0.0, 0.036)], (x, y, h - 0.01), segs=32, dent=0.002)
    t.build()


def chair(M, C, name, x, y, yaw, seed):
    """Holzstuhl mit gebogener Lehne aus Sprossen (Lehne auf der Seite +y lokal)."""
    m = Matrix.Translation((x, y, 0)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
    seat = CHAIR_SEAT
    back = seat + 0.38
    b = Body(name, M["chair"], C["deco"], seed=seed, vary=0.06, bevel=0.008)
    b.box((0, 0, seat), (0.4, 0.38, 0.04), step=0.3, dent=0.002, matrix=m)
    for sx in (-0.16, 0.16):
        for sy in (-0.15, 0.15):
            top = back if sy > 0 else seat - 0.01
            b.tube([m @ Vector((sx * 1.02, sy * 1.05, 0.0)), m @ Vector((sx, sy, seat * 0.5)), m @ Vector((sx, sy, top))], 0.016, segs=8,
                   round_ends=True)
    b.box((0, 0.16, back - 0.04), (0.4, 0.05, 0.08), step=0.3, dent=0.002, matrix=m)
    for sx in (-0.08, 0.0, 0.08):
        b.tube([m @ Vector((sx, 0.16, seat + 0.02)), m @ Vector((sx, 0.17, back - 0.07))], 0.01, segs=6, round_ends=True)
    b.tube([m @ Vector((-0.16, 0.0, seat * 0.42)), m @ Vector((0.16, 0.0, seat * 0.42))], 0.01, segs=6, round_ends=True)
    b.build()


OBSTACLES = {
    "Tisch links": ((-1.75, -0.62), (1.05, 0.62), 0.9),
    "Tisch rechts": ((1.95, -0.62), (1.5, 0.62), 0.9),
    "Topf links": ((-0.95, -0.52), (0.5, 0.5), 0.5),
    "Topf rechts": ((0.95, -0.52), (0.5, 0.5), 0.5),
    "Kreidetafel": ((-2.52, -0.95), (0.56, 0.45), 0.85),
}


def outside(M, C):
    """Wie im Vorbild (von der Straße gesehen): links Kreidetafel und Tisch mit Stuhl, rechts
    Stuhl, Tisch, Stuhl; Töpfe neben der Tür; rundes Hängeschild rechts zum Nachbarhaus."""
    bistro_table(M, C, "Tisch links", -1.62, -0.62, 90)
    # Stühle neben den Tischen mit Blick zur Straße (seit Etappe 6c): vorn ist frei – so setzen sich
    # Passanten von vorn hin, ohne durch den Tisch zu gehen
    chair(M, C, "Stuhl links", -2.17, -0.6, 12, 92)
    bistro_table(M, C, "Tisch rechts", 1.95, -0.62, 94)
    chair(M, C, "Stuhl rechts 1", 1.4, -0.62, 12, 96)
    chair(M, C, "Stuhl rechts 2", 2.5, -0.64, -12, 98)
    # frei vor der Brüstung der Schaufenster (sonst steckt der Topf darin)
    SC.pot(M, C["pots"], "Topf links", (-0.95, -0.52, 0.0), 0.23, 0.46, 101, style="bowl", mat="pot")
    SC.pot(M, C["pots"], "Topf rechts", (0.95, -0.52, 0.0), 0.23, 0.46, 102, style="bowl", mat="pot_light")
    SC.chalkboard(M, C["deco"], (-2.52, -0.95), -12, SC.sign_material("pub", "chalkboard"))
    SC.projecting_sign(M, C["deco"], "Hängeschild", (HW - 0.15, 0.0, 5.45), SC.sign_material("pub", "hanging"), 0.64,
                       0.64 * 478 / 512, outline=SB.round_outline(48))


# --- Efeu ---

def pub_ivy(M, C):
    """Dichter Efeu („The Ink & Ivy“, Wunsch der Entwicklerin): wächst von der Gassenecke an der
    Seitenwand und am Eckpfeiler hoch, klettert über das Gesims und läuft als Girlande über das Schild
    (an den Enden hängen Ranken herab); Fenster, Tür, Hängeschild und Schrift bleiben frei.
    Wand-Koordinaten: u = x + HW entlang der Front (0 = Gassenecke), u < 0 = Seitenwand zur Gasse (Tiefe
    -u), v = Höhe."""
    rr = random.Random(1889)
    GR.plant_palette(M)
    p = GR.Plant(M, C["deco"], seed=1889)
    holes = [(PIL - 0.02, 0.0, W - PIL + 0.02, HEAD + 0.12),                                           # Schaufenster, Tür
             (HW - 1.3, FASCIA_Z - FASCIA_H / 2 - 0.02, HW + 1.3, FASCIA_Z + FASCIA_H / 2 + 0.02),    # Schrift
             (W - 0.8, 4.95, W, 6.0)]                                                                # Hängeschild
    for x in WIN_X:
        holes.append((x + HW - WIN_W / 2 - 0.14, WIN_Z0 - 0.45, x + HW + WIN_W / 2 + 0.14, WIN_Z0 + WIN_H + WIN_RISE + 0.3))
    for _, y, z, w, h in SIDE_WINDOWS:
        holes.append((-(y + w / 2 + 0.13), z - 0.17, -(y - w / 2 - 0.13), z + h + 0.25))

    def front_off(u, v):
        """Wie weit die Ladenfront an dieser Stelle vor der Backsteinwand steht (der Efeu liegt darauf)."""
        if v < HEAD - 0.05:
            if u < PIL + 0.03 or u > W - PIL - 0.03:
                return 0.24 if v < 0.36 else 0.2                              # Pilaster (unten mit Sockel)
            return 0.0
        if v < SHOP_TOP - 0.18:
            return 0.37 if PIL < u < W - PIL else 0.36                        # Schildkasten, Kapitell
        if v <= SHOP_TOP:
            return 0.42                                                       # Ladengesims
        return 0.0                                                            # darüber Backstein

    def to3d(u, v, w):
        if u < 0.0:
            # Seitenwand zur Gasse; dicht an der Ecke liegt sie neben den vorstehenden Teilen der Front
            fo = front_off(0.0, v) * max(0.0, 1.0 + u / 0.5)
            return (-HW - w, -u - fo, v)
        return (u - HW, -(front_off(u, v) + w), v)
    roots = [(-0.35, 0.0), (-1.25, 0.0), (0.15, 0.0), (-3.6, 0.0)]
    GR.wall_ivy(p, W, E - 0.35, holes, rr, to3d, roots, reach=(0.55, 1.0), wrap=(D - 1.0, 0.0), density=1.3, stems=(3, 5))
    # Girlande liegt oben auf dem Ladengesims (Gesims 0,42 m tief), Ranken hängen vorn über das Schild
    flat = lambda u, v, w: (u - HW, -w, v)  # noqa: E731
    top = SHOP_TOP + 0.03
    GR.garland(p, [[(0.05, top, 0.4), (0.6, top + 0.01, 0.4), (1.55, top, 0.38)]], flat, rr, kind="ivy", strands=4, density=1.3, hang=1.4)
    GR.garland(p, [[(1.55, top, 0.3), (2.8, top + 0.01, 0.28), (4.0, top, 0.3)]], flat, rr, kind="ivy", strands=2, density=1.0, hang=0.0)
    GR.garland(p, [[(4.0, top, 0.38), (4.6, top + 0.01, 0.4)]], flat, rr, kind="ivy", strands=2, density=1.0, hang=0.8)
    p.build()


# --- Ablauf ---

def build_scene():
    RND.seed(1888)
    FS.RND.seed(1888)
    WIN_JITTER.clear()
    SC.GAME_MATERIALS.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    for x in WIN_X:
        WIN_JITTER.append((x, RND.uniform(-0.015, 0.015), RND.uniform(-1.3, 1.3)))
    M = SC.materials()
    root = SB.collection("Pub (Bilderbuch)")
    C = {k: SB.collection(v, root) for k, v in (("walls", "Mauern"), ("roof", "Dach"), ("windows", "Fenster"), ("shop", "Ladenfront"),
                                                ("inside", "Gaststube und Zimmer"), ("pots", "Töpfe und Kästen"), ("deco", "Deko"),
                                                ("light", "Licht"))}
    C["env"] = SB.collection("Umgebung (nur Vorschau)")
    C["collision"] = SB.collection("Kollision (Spiel)", root)
    walls(M, C)
    brick_arches(M, C)
    cornice(M, C)
    roof(M, C)
    upper_windows(M, C)
    shopfront(M, C)
    taproom(M, C)
    outside(M, C)
    pub_ivy(M, C)
    house = [o for k, c in C.items() if k != "env" for o in c.objects]
    SC.settle(house, SETTLE, HW, E, RIDGE)
    cols = SC.colliders(C, OBSTACLES)
    SC.pavement(M, C, seed=310)
    return M, C, cols


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if SC.edited_by_hand(BLEND, STAMP) and "--force" not in argv:
        print("Die .blend wurde in Blender bearbeitet – nichts überschrieben. Ins Spiel bringen mit\n"
              "  blender -b %s --python tools/blender/export_storybook.py\n"
              "Neu bauen (eigene Änderungen gehen verloren): ... build_storybook_pub.py -- --force" % os.path.relpath(BLEND, ROOT))
        return
    M, C, cols = build_scene()
    open_parts = [(o.name, SB.non_manifold(o)) for c in C.values() for o in c.objects if o.type == "MESH"]
    bad = [(n, k) for n, k in open_parts if k]
    faces = sum(len(o.data.polygons) for c in C.values() for o in c.objects if o.type == "MESH")
    print("Teile: %d, Flächen: %d" % (len(open_parts), faces))
    print("Offene Kanten: %s" % (bad if bad else "keine – alles geschlossene Körper"))
    if "--no-game" not in argv:
        mapping = SC.write_game_materials()
        objs = [o for key, coll in C.items() if key not in ("env", "collision", "light") for o in coll.objects]
        tris, parts = SC.export_objects(objs, cols, GAME_GLB)
        SC.write_import_settings(mapping, GAME_GLB)
        print("Spiel: %s (%d Dreiecke, %d Netze)" % (GAME_GLB, tris, parts))
    if "--render" in argv:
        quick = "--quick" in argv
        SC.setup_render(quick)
        s = 0.5 if quick else 1.0
        only = [a.split("=", 1)[1].split(",") for a in argv if a.startswith("--only=")]
        views = {
            "pub_vorn": ((0.0, -12.5, 1.75), (0.0, 0.0, 4.3), 40, (1400, 1500)),
            "pub_schraeg": ((-6.5, -8.5, 2.0), (0.0, 0.5, 3.8), 30, (1600, 1100)),
            "pub_front": ((1.0, -5.2, 1.6), (0.0, 0.0, 1.9), 30, (1600, 1100)),
            "pub_tische": ((0.6, -3.0, 1.3), (1.9, -0.6, 0.6), 35, (1200, 1000)),
            "pub_schild": ((4.3, -1.6, 5.0), (2.65, -0.45, 5.0), 32, (1100, 1000)),
            "pub_stube": ((0.8, -1.6, 1.5), (0.1, 3.0, 1.5), 32, (1400, 1000)),
            "pub_oben": ((0.8, -3.0, 4.9), (0.0, 0.0, 5.0), 34, (1400, 1000)),
            "pub_unten": ((0.4, -1.3, 1.5), (0.0, 0.0, 2.9), 26, (1400, 1000)),
        }
        for name, (cam, target, lens, res) in views.items():
            if only and name not in only[0]:
                continue
            SC.render(name, cam, target, lens, (int(res[0] * s), int(res[1] * s)))
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
    with open(STAMP, "w") as f:
        f.write(SC.blend_fingerprint(BLEND) + "\n")
    print("Gespeichert:", BLEND)


if __name__ == "__main__":
    main()
